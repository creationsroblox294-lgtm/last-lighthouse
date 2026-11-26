--!strict
-- EnemyService: the fog creatures. They spawn at the fog edge (the beach rim) during storms
-- and take damage from the light and the beam.
--   Fog Crawler (storm 1+): fast swarms. Only attack players outside the light; they circle
--                           the edge of the light, waiting for it to shrink. Burned inside it.
--   The Drowned (storm 2+): slow and tough. Climb out at Wreck Beach and pound on the walls.
--                           The light only slows them.
--   Night Gull  (storm 3+): circles high above and dives at anyone outside the light.
--   Fog Mimic   (storm 4+): looks like a lost survivor; reveals itself and lunges up close.
--   Last Keeper (storm 5+): slow and very tough, calls Fog Crawlers out of the fog.
-- Every storm keeps all the earlier kinds and adds the next (Config.Enemies.Order).
-- When the lamp has been dark for 15 s (LightService.IsSwarming) everything rushes the tower.
-- Special storms: Red Tide = twice the Drowned, Calm Night = no creatures.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local LightService = require(script.Parent:WaitForChild("LightService"))
local BuildService = require(script.Parent:WaitForChild("BuildService"))

local E = Config.Enemies
local W = Config.World
local EnemyService = {}

type Enemy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	stats: any,
	lastAttack: number,
	stunnedUntil: number,
	orbit: number,
	anim: string,
	animSpeed: number,
	attackUntil: number,
	flinchUntil: number,
	flinchCooldown: number,
	data: { [string]: any },
}

local enemies: { Enemy } = {}
local folder: Folder
local rng = Random.new()
local quota: { [string]: number } = {}
local spawnLoopRunning = false

---------------------------------------------------------------------------
-- Models (greybox shapes for now; Blender models replace these later)
---------------------------------------------------------------------------
local function weld(root: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = root.CFrame * offset
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
	part.Parent = root.Parent
end

local function piece(size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	return p
end

local function newBody(name: string, pos: Vector3, rootSize: Vector3, hipHeight: number, stats: any): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- body and mesh arrive together
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = rootSize
	root.Transparency = 1
	root.CFrame = CFrame.new(pos + Vector3.new(0, hipHeight + rootSize.Y / 2, 0))
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- no legs: float at HipHeight
	humanoid.HipHeight = hipHeight
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid.Parent = model
	model.PrimaryPart = root
	return model, humanoid, root
end

-- Realistic model from Blender (ReplicatedStorage.CreatureModels.<kind>), welded to the
-- invisible humanoid root so physics/AI stay simple. Returns false if no model is available.
local function attachVisual(model: Model, root: BasePart, kind: string, groundOffset: number): boolean
	local folder = ReplicatedStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild(kind)
	if not template or not template:IsA("Model") then
		return false
	end
	local visual = template:Clone()
	visual.Name = "Visual"
	local box, size = visual:GetBoundingBox()
	local pivotFromBox = box:ToObjectSpace(visual:GetPivot())
	local groundY = root.Position.Y - groundOffset
	local target = CFrame.new(root.Position.X, groundY + size.Y / 2, root.Position.Z) * root.CFrame.Rotation
	visual:PivotTo(target * pivotFromBox)
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
	visual.Parent = model
	model:SetAttribute("Creature", kind)
	model:SetAttribute("Anim", "Idle")
	model:SetAttribute("AnimSpeed", 1)
	return true
end

local function buildCrawler(pos: Vector3): (Model, Humanoid, BasePart)
	local model, humanoid, root = newBody("FogCrawler", pos, Vector3.new(2.5, 1.4, 2.5), 2.2, E.FogCrawler)
	if attachVisual(model, root, "FogCrawler", 2.2 + 0.7) then
		return model, humanoid, root
	end
	weld(root, piece(Vector3.new(3.2, 3.2, 3.2), Color3.fromRGB(18, 18, 24), Enum.Material.SmoothPlastic, Enum.PartType.Ball), CFrame.new(0, -0.6, 0))
	for _, x in { -0.6, 0.6 } do
		weld(root, piece(Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(x, -0.2, -1.4))
	end
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		weld(root, piece(Vector3.new(0.4, 1.6, 0.4), Color3.fromRGB(30, 30, 38), Enum.Material.SmoothPlastic),
			CFrame.new(math.cos(a) * 1.2, 0.5, math.sin(a) * 1.2) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6))
	end
	return model, humanoid, root
end

local function buildDrowned(pos: Vector3): (Model, Humanoid, BasePart)
	local model, humanoid, root = newBody("Drowned", pos, Vector3.new(2, 2, 1), 2.8, E.Drowned)
	if attachVisual(model, root, "Drowned", 2.8 + 1) then
		-- climbs out of the surf first
		model:SetAttribute("Anim", "Emerge")
		model:SetAttribute("SpawnedAt", os.clock())
		return model, humanoid, root
	end
	local skin = Color3.fromRGB(45, 72, 78)
	weld(root, piece(Vector3.new(2.6, 3, 1.4), skin, Enum.Material.Slate), CFrame.new(0, 1.5, 0))
	weld(root, piece(Vector3.new(1.7, 1.7, 1.7), skin, Enum.Material.Slate, Enum.PartType.Ball), CFrame.new(0, 3.8, -0.1))
	for _, x in { -0.4, 0.4 } do
		weld(root, piece(Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(200, 255, 245), Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(x, 3.95, -0.8))
	end
	for _, x in { -1.75, 1.75 } do
		weld(root, piece(Vector3.new(0.8, 3.4, 0.8), skin, Enum.Material.Slate), CFrame.new(x, 1, -0.5) * CFrame.Angles(math.rad(25), 0, 0))
	end
	for _, x in { -0.6, 0.6 } do
		weld(root, piece(Vector3.new(0.9, 2, 0.9), Color3.fromRGB(35, 55, 60), Enum.Material.Slate), CFrame.new(x, -1.8, 0))
	end
	return model, humanoid, root
end

local function buildGull(pos: Vector3): (Model, Humanoid, BasePart)
	local stats = E.NightGull
	local model, humanoid, root = newBody("NightGull", pos, Vector3.new(3, 1, 3), stats.FlyHeight, stats)
	if attachVisual(model, root, "NightGull", 0.55) then
		model:SetAttribute("Anim", "Glide")
		return model, humanoid, root
	end
	weld(root, piece(Vector3.new(6, 0.4, 2), Color3.fromRGB(200, 200, 205), Enum.Material.SmoothPlastic), CFrame.new())
	return model, humanoid, root
end

local function buildMimic(pos: Vector3): (Model, Humanoid, BasePart)
	local model, humanoid, root = newBody("FogMimic", pos, Vector3.new(2, 2, 1), 2.2, E.FogMimic)
	if attachVisual(model, root, "FogMimic", 2.2 + 1) then
		return model, humanoid, root
	end
	weld(root, piece(Vector3.new(1.8, 5, 1), Color3.fromRGB(90, 95, 100), Enum.Material.SmoothPlastic), CFrame.new(0, 0.5, 0))
	return model, humanoid, root
end

local function buildKeeper(pos: Vector3): (Model, Humanoid, BasePart)
	local model, humanoid, root = newBody("LastKeeper", pos, Vector3.new(3, 3, 2), 3, E.LastKeeper)
	if attachVisual(model, root, "LastKeeper", 3 + 1.5) then
		return model, humanoid, root
	end
	weld(root, piece(Vector3.new(3, 7, 2), Color3.fromRGB(40, 50, 60), Enum.Material.Slate), CFrame.new(0, 1, 0))
	return model, humanoid, root
end

---------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------
local function insideCliff(p: Vector3): boolean
	return p.X > 12 and p.X < 105 and p.Z > -128 and p.Z < -38
end

local function groundAt(p: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(Vector3.new(p.X, 80, p.Z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position else Vector3.new(p.X, 3, p.Z)
end

local landRay = RaycastParams.new()
landRay.FilterType = Enum.RaycastFilterType.Include

local function onLand(p: Vector3): boolean
	landRay.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(p.X, 150, p.Z), Vector3.new(0, -300, 0), landRay)
	return hit ~= nil and hit.Material ~= Enum.Material.Water and hit.Position.Y > 2
end

-- A point on land in the fog ring around the lighthouse
local function fogEdgePoint(): Vector3
	local c = W.TowerCenter
	for _ = 1, 24 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = E.SpawnRadius * rng:NextNumber(0.85, 1.1)
		local p = Vector3.new(c.X + math.cos(a) * r, 0, c.Z + math.sin(a) * r)
		if not insideCliff(p) and onLand(p) then
			return groundAt(p)
		end
	end
	return groundAt(W.RampBottom + Vector3.new(0, 0, E.SpawnRadius * 0.8))
end

local function drownedPoint(): Vector3
	local map = Workspace:FindFirstChild("Map")
	local beach = map and map:FindFirstChild("WreckBeach")
	local zone = beach and beach:FindFirstChild("DrownedSpawnZone")
	if zone and zone:IsA("BasePart") then
		local p = zone.Position + Vector3.new(rng:NextNumber(-0.5, 0.5) * zone.Size.X, 0, rng:NextNumber(-0.5, 0.5) * zone.Size.Z)
		-- Climb out right at the water's edge (on the sand, not in the sea)
		local flat = Vector3.new(p.X - W.IslandCenter.X, 0, p.Z - W.IslandCenter.Z)
		if flat.Magnitude > W.IslandRadius - 6 then
			p = W.IslandCenter + flat.Unit * (W.IslandRadius - 6)
		end
		return groundAt(p)
	end
	return fogEdgePoint()
end

local function removeEnemy(e: Enemy)
	local index = table.find(enemies, e)
	if index then
		table.remove(enemies, index)
	end
	if e.model:GetAttribute("Creature") then
		-- play the death animation, then sink away
		e.model:SetAttribute("AnimSpeed", 1)
		e.model:SetAttribute("Anim", "Death")
		e.humanoid.WalkSpeed = 0
		task.delay(2.2, function()
			for _, d in e.model:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					d.Transparency = 0.5
				end
			end
		end)
		Debris:AddItem(e.model, 3)
		return
	end
	for _, d in e.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.6)
		end
	end
	Debris:AddItem(e.model, 1)
end

function EnemyService.Spawn(kind: string, at: Vector3?): Enemy?
	if #enemies >= E.MaxAlive then
		return nil
	end
	local stats = (E :: any)[kind]
	if not stats then
		return nil
	end
	local model, humanoid, root
	if kind == "Drowned" then
		model, humanoid, root = buildDrowned(at or drownedPoint())
	elseif kind == "NightGull" then
		model, humanoid, root = buildGull(at or fogEdgePoint())
	elseif kind == "FogMimic" then
		model, humanoid, root = buildMimic(at or fogEdgePoint())
	elseif kind == "LastKeeper" then
		model, humanoid, root = buildKeeper(at or fogEdgePoint())
	else
		model, humanoid, root = buildCrawler(at or fogEdgePoint())
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local c = LightService.GetCenter()
	local e: Enemy = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = kind,
		stats = stats,
		lastAttack = 0,
		stunnedUntil = 0,
		orbit = math.atan2(root.Position.Z - c.Z, root.Position.X - c.X),
		anim = "Idle",
		animSpeed = 1,
		attackUntil = 0,
		flinchUntil = 0,
		flinchCooldown = 0,
		data = {},
	}
	humanoid.Died:Connect(function()
		removeEnemy(e)
	end)
	table.insert(enemies, e)
	return e
end

function EnemyService.ClearAll()
	for i = #enemies, 1, -1 do
		removeEnemy(enemies[i])
	end
	table.clear(quota)
end

local function countFor(stats: any, storm: number, players: number): number
	if storm < stats.FirstStorm then
		return 0
	end
	local n = stats.CountBase + stats.CountPerStorm * (storm - stats.FirstStorm)
	n *= 1 + E.PlayerScale * math.max(0, players - 1)
	return math.floor(n + 0.5)
end

local function spawnLoop()
	if spawnLoopRunning then
		return
	end
	spawnLoopRunning = true
	local idx = 0
	while StormDirector.GetPhase() == "Storm" do
		local swarming = LightService.IsSwarming()
		-- next kind (round robin through Order) that still has creatures to send
		local kind: string? = nil
		for _ = 1, #E.Order do
			idx = idx % #E.Order + 1
			local k = E.Order[idx]
			if (quota[k] or 0) > 0 then
				kind = k
				break
			end
		end
		if kind then
			if EnemyService.Spawn(kind) then
				quota[kind] -= 1
			end
		elseif swarming then
			EnemyService.Spawn("FogCrawler")
		end
		task.wait(if swarming then E.SwarmSpawnInterval else E.SpawnInterval)
	end
	spawnLoopRunning = false
end

---------------------------------------------------------------------------
-- Behaviour
---------------------------------------------------------------------------
-- Creatures below the cliff take the ramp to reach anything on top of it
local function routeTo(e: Enemy, goal: Vector3): Vector3
	local pos = e.root.Position
	if goal.Y > W.CliffTopY - 6 and pos.Y < W.CliffTopY - 6 then
		local bottom, top = W.RampBottom, W.RampTop
		local approach = bottom + Vector3.new(0, 0, 12)
		-- In the corridor from the approach point up the ramp: keep climbing
		local onRamp = math.abs(pos.X - bottom.X) < 7 and pos.Z < approach.Z + 2 and pos.Z > top.Z
		if onRamp or (pos - approach).Magnitude < 6 then
			return top
		end
		return approach
	end
	return goal
end

type Target = { humanoid: Humanoid, root: BasePart, distance: number }

local function nearestPlayer(pos: Vector3, onlyOutsideLight: boolean, maxDistance: number): Target?
	local best: Target? = nil
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			if not onlyOutsideLight or not LightService.IsPointLit(root.Position) then
				local d = (root.Position - pos).Magnitude
				if d <= maxDistance and (not best or d < best.distance) then
					best = { humanoid = humanoid, root = root, distance = d }
				end
			end
		end
	end
	return best
end

local function ready(e: Enemy, t: number): boolean
	if t - e.lastAttack >= e.stats.AttackCooldown then
		e.lastAttack = t
		return true
	end
	return false
end

-- Smash a barricade in the way; returns true if busy with one
local function hitBarricade(e: Enemy, t: number): boolean
	local barricade = BuildService.GetBarricadeNear(e.root.Position, 7)
	if not barricade then
		return false
	end
	e.humanoid:MoveTo(barricade.Position)
	if ready(e, t) then
		BuildService.DamageBarricade(barricade, e.stats.StructureDamage or e.stats.Damage)
		e.attackUntil = t + 1.0
		e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
	end
	return true
end

local function attackTower(e: Enemy, t: number)
	if hitBarricade(e, t) then
		return
	end
	local door = W.DoorFront
	if (e.root.Position - door).Magnitude <= 9 then
		e.humanoid:MoveTo(door)
		if ready(e, t) then
			BuildService.DamageTower(e.stats.StructureDamage or e.stats.Damage)
			e.attackUntil = t + 1.0
			e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
		end
	else
		e.humanoid:MoveTo(routeTo(e, door))
	end
end

local function crawlerThink(e: Enemy, dt: number, t: number)
	local pos = e.root.Position
	local swarming = LightService.IsSwarming()
	if LightService.IsPointLit(pos) then
		if t >= e.flinchCooldown then
			e.flinchUntil = t + 0.6
			e.flinchCooldown = t + 1.6
		end
		e.humanoid:TakeDamage(e.stats.LightDamagePerSecond * dt)
		local c = LightService.GetCenter()
		local out = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
		if out.Magnitude < 1 then
			out = Vector3.new(1, 0, 0)
		end
		e.humanoid:MoveTo(pos + out.Unit * 20)
		return
	end
	local target = nearestPlayer(pos, not swarming, 250)
	if target then
		if target.distance <= e.stats.AttackRange then
			if ready(e, t) then
				target.humanoid:TakeDamage(e.stats.Damage)
				e.attackUntil = t + 0.9
				-- restart the strike animation for every bite
				e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
			end
			e.humanoid:MoveTo(target.root.Position)
		elseif not hitBarricade(e, t) then
			e.humanoid:MoveTo(routeTo(e, target.root.Position))
		end
		return
	end
	if swarming then
		attackTower(e, t)
		return
	end
	-- Lurk: circle just outside the edge of the light
	e.orbit += dt * 0.15
	local c = LightService.GetCenter()
	local r = math.max(LightService.GetRadius(), 20) + 12
	e.humanoid:MoveTo(Vector3.new(c.X + math.cos(e.orbit) * r, pos.Y, c.Z + math.sin(e.orbit) * r))
end

local function drownedThink(e: Enemy, _dt: number, t: number)
	local pos = e.root.Position
	local lit = LightService.IsPointLit(pos)
	e.humanoid.WalkSpeed = e.stats.Speed * (if lit then e.stats.LightSlowFactor else 1)
	if lit and t >= e.flinchCooldown then
		-- the light makes it reel back for a moment
		e.flinchUntil = t + 0.8
		e.flinchCooldown = t + 4
	end
	local spawnedAt = e.model:GetAttribute("SpawnedAt")
	if typeof(spawnedAt) == "number" and t - spawnedAt < 2.6 then
		e.humanoid:MoveTo(pos) -- still climbing out
		return
	end
	local target = nearestPlayer(pos, false, 10)
	if target then
		e.humanoid:MoveTo(target.root.Position)
		if target.distance <= e.stats.AttackRange and ready(e, t) then
			target.humanoid:TakeDamage(e.stats.Damage)
			e.attackUntil = t + 1.0
			e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
		end
		return
	end
	attackTower(e, t)
end

local function fleeLight(e: Enemy, dt: number, t: number)
	local pos = e.root.Position
	if t >= e.flinchCooldown then
		e.flinchUntil = t + 0.6
		e.flinchCooldown = t + 1.6
	end
	e.humanoid:TakeDamage(e.stats.LightDamagePerSecond * dt)
	local c = LightService.GetCenter()
	local out = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z)
	if out.Magnitude < 1 then
		out = Vector3.new(1, 0, 0)
	end
	e.humanoid:MoveTo(pos + out.Unit * 20)
end

local function circleLight(e: Enemy, dt: number, extra: number)
	e.orbit += dt * 0.15
	local c = LightService.GetCenter()
	local r = math.max(LightService.GetRadius(), 20) + extra
	e.humanoid:MoveTo(Vector3.new(c.X + math.cos(e.orbit) * r, e.root.Position.Y, c.Z + math.sin(e.orbit) * r))
end

local function gullThink(e: Enemy, dt: number, t: number)
	local s = e.stats
	local pos = e.root.Position
	local h = e.humanoid
	local wantHeight = s.FlyHeight
	if LightService.IsPointLit(pos) then
		h.HipHeight += (s.FlyHeight - h.HipHeight) * math.min(1, dt * 2)
		fleeLight(e, dt, t)
		return
	end
	local climbing = t < (e.data.climbUntil or 0)
	local target = if climbing then nil else nearestPlayer(pos, not LightService.IsSwarming(), 200)
	if target then
		local flat = Vector3.new(target.root.Position.X - pos.X, 0, target.root.Position.Z - pos.Z).Magnitude
		if flat < s.DiveRange then
			-- dive: drop toward the player's head
			wantHeight = math.max(2.5, math.min(s.FlyHeight, flat * 0.4))
			h:MoveTo(target.root.Position)
			if target.distance <= s.AttackRange + 1 and ready(e, t) then
				target.humanoid:TakeDamage(s.Damage)
				e.attackUntil = t + 0.8
				e.data.climbUntil = t + 2.5
				e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
			end
		else
			h:MoveTo(target.root.Position)
		end
	elseif LightService.IsSwarming() then
		attackTower(e, t)
	else
		circleLight(e, dt, 25)
	end
	h.HipHeight += (wantHeight - h.HipHeight) * math.min(1, dt * 3)
end

local function mimicThink(e: Enemy, dt: number, t: number)
	local s = e.stats
	local pos = e.root.Position
	if LightService.IsPointLit(pos) then
		fleeLight(e, dt, t)
		return
	end
	if t < (e.data.revealUntil or 0) then
		e.humanoid:MoveTo(pos) -- standing still while it changes shape
		return
	end
	local target = nearestPlayer(pos, not LightService.IsSwarming(), 250)
	if not e.data.revealed then
		-- shuffle toward the nearest player like a lost survivor, then show what it is
		if target and target.distance <= s.RevealRange then
			e.data.revealed = true
			e.data.revealUntil = t + 1.4
			e.data.forceAnim = "Reveal"
			e.data.forceUntil = t + 1.4
			e.humanoid.WalkSpeed = s.RevealSpeed
			return
		end
		if target then
			e.humanoid:MoveTo(target.root.Position)
		else
			circleLight(e, dt, 18)
		end
		return
	end
	if target then
		e.humanoid:MoveTo(target.root.Position)
		if target.distance <= s.AttackRange and ready(e, t) then
			target.humanoid:TakeDamage(s.Damage)
			e.attackUntil = t + 0.9
			e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
		end
	elseif LightService.IsSwarming() then
		attackTower(e, t)
	else
		circleLight(e, dt, 14)
	end
end

local function keeperThink(e: Enemy, _dt: number, t: number)
	local s = e.stats
	local pos = e.root.Position
	local lit = LightService.IsPointLit(pos)
	e.humanoid.WalkSpeed = s.Speed * (if lit then s.LightSlowFactor else 1)
	-- raise the lantern and call crawlers out of the fog
	if t >= (e.data.nextSummon or (t + s.SummonEvery * 0.5)) then
		if not e.data.nextSummon then
			e.data.nextSummon = t + s.SummonEvery * 0.5
		else
			e.data.nextSummon = t + s.SummonEvery
			e.data.forceAnim = "Summon"
			e.data.forceUntil = t + 1.6
			for i = 1, s.SummonCount do
				local a = rng:NextNumber(0, math.pi * 2)
				EnemyService.Spawn("FogCrawler", groundAt(pos + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)))
			end
		end
	end
	if t < (e.data.forceUntil or 0) then
		e.humanoid:MoveTo(pos)
		return
	end
	local target = nearestPlayer(pos, false, 14)
	if target then
		e.humanoid:MoveTo(target.root.Position)
		if target.distance <= s.AttackRange and ready(e, t) then
			target.humanoid:TakeDamage(s.Damage)
			e.attackUntil = t + 1.2
			e.model:SetAttribute("AnimRestart", (e.model:GetAttribute("AnimRestart") or 0) + 1)
		end
		return
	end
	attackTower(e, t)
end

-- Which Blender clip should this creature play right now?
-- per creature: clip names and the ground speed (studs/s) the move cycle was animated at
local CLIPS = {
	FogCrawler = { flinch = "Flinch", attack = "Lunge", move = "Crawl", moveSpeed = 2.5, maxRate = 4.5 },
	Drowned = { flinch = "Stagger", attack = "Pound", move = "Shamble", moveSpeed = 3.4, maxRate = 2.6 },
	NightGull = { flinch = "Screech", attack = "Dive", move = "Fly", idle = "Glide", moveSpeed = 12, maxRate = 2 },
	FogMimic = { flinch = "Idle", attack = "Lunge", move = "Walk", moveSpeed = 4, maxRate = 3.5 },
	LastKeeper = { flinch = "Idle", attack = "Swing", move = "Walk", moveSpeed = 3, maxRate = 2 },
}
local function updateAnim(e: Enemy, t: number)
	local kind = e.model:GetAttribute("Creature")
	local clips = typeof(kind) == "string" and CLIPS[kind]
	if not clips then
		return
	end
	local anim, speed = clips.idle or "Idle", 1
	local spawnedAt = e.model:GetAttribute("SpawnedAt")
	if e.data.forceAnim and t < (e.data.forceUntil or 0) then
		anim = e.data.forceAnim
	elseif typeof(spawnedAt) == "number" and t - spawnedAt < 2.6 then
		anim = "Emerge"
	elseif t < e.flinchUntil then
		anim = clips.flinch
	elseif t < e.attackUntil then
		anim = clips.attack
	else
		local v = e.root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z).Magnitude
		if flat > 1.5 then
			anim = clips.move
			speed = math.clamp(flat / clips.moveSpeed, 0.6, clips.maxRate)
		end
	end
	if anim ~= e.anim then
		e.anim = anim
		e.model:SetAttribute("Anim", anim)
	end
	if math.abs(speed - e.animSpeed) > 0.15 then
		e.animSpeed = speed
		e.model:SetAttribute("AnimSpeed", speed)
	end
end

local function tick(dt: number)
	local t = os.clock()
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		if not e.model.Parent or e.humanoid.Health <= 0 then
			removeEnemy(e)
			continue
		end
		local pos = e.root.Position
		if pos.Y < -30 then
			e.humanoid.Health = 0
			continue
		end
		if LightService.IsInBeam(pos) then
			e.humanoid:TakeDamage(Config.Light.BeamDamagePerSecond * dt)
			e.stunnedUntil = t + Config.Light.BeamStunSeconds
		end
		if t < e.stunnedUntil then
			e.humanoid:MoveTo(pos)
			continue
		end
		if e.kind == "Drowned" then
			drownedThink(e, dt, t)
		elseif e.kind == "NightGull" then
			gullThink(e, dt, t)
		elseif e.kind == "FogMimic" then
			mimicThink(e, dt, t)
		elseif e.kind == "LastKeeper" then
			keeperThink(e, dt, t)
		else
			crawlerThink(e, dt, t)
		end
		updateAnim(e, t)
	end
end

---------------------------------------------------------------------------
-- Public helpers (combat)
---------------------------------------------------------------------------
-- Nearest living creature in front of origin, within range and a cone
function EnemyService.FindTarget(origin: Vector3, look: Vector3, range: number, coneDegrees: number): Humanoid?
	local best: Humanoid? = nil
	local bestDist = range
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return nil
	end
	flatLook = flatLook.Unit
	local cosLimit = math.cos(math.rad(coneDegrees))
	for _, e in enemies do
		if e.humanoid.Health > 0 then
			local offset = e.root.Position - origin
			local dist = offset.Magnitude
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if dist <= bestDist and (flat.Magnitude < 3 or flat.Unit:Dot(flatLook) >= cosLimit) then
				best = e.humanoid
				bestDist = dist
			end
		end
	end
	return best
end

function EnemyService.Count(): number
	return #enemies
end

function EnemyService.Start()
	local runtime = Workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = Workspace
	-- reuse the folder if FishService made it first (one Enemies folder for the animator)
	local f = runtime:FindFirstChild("Enemies")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Enemies"
		f.Parent = runtime
	end
	folder = f :: Folder

	StormDirector.PhaseChanged:Connect(function(info)
		if info.phase == "Storm" then
			local players = math.max(1, #Players:GetPlayers())
			local special = info.specialStorm
			for _, kind in E.Order do
				quota[kind] = countFor((E :: any)[kind], info.currentStorm, players)
			end
			if special == "RedTide" then
				quota.Drowned = math.max(2, quota.Drowned * 2)
			elseif special == "CalmNight" then
				table.clear(quota)
			end
			task.spawn(spawnLoop)
		elseif info.phase == "Dawn" or info.phase == "Lost" or info.phase == "Won" then
			EnemyService.ClearAll()
		end
	end)
	StormDirector.RunReset:Connect(EnemyService.ClearAll)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(E.Tick)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
end

return EnemyService
