--!strict
-- TreeAnimalService: snakes, spiders and bats hiding in the forest canopy.
-- When a player walks under the trees (away from the lighthouse), an animal picks a tree
-- near them, rustles (the client shows a warning ring where it will land) and drops.
--   Step out of the ring -> it misses, lands, and runs off.
--   Stay in it          -> it latches on: damage over time, slowed, tap Space/screen to
--                          shake it off (or it lets go by itself after a few seconds).
-- Models come from ReplicatedStorage.CreatureModels.<Kind> (Blender, clips Hang / Drop /
-- Latch / Land / Flee) and are animated by CreatureController. A blocky stand-in is
-- used if a model is missing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Movement = require(script.Parent:WaitForChild("Movement"))

local A = Config.TreeAnimals
local W = Config.World
local TreeAnimalService = {}

type Animal = {
	kind: string,
	model: Model,
	fix: CFrame, -- model pivot relative to a "forward = -Z, up = +Y" frame at its centre
	target: Player,
	state: string,
	shakes: number,
	weld: WeldConstraint?,
}

local rng = Random.new()
local active: { [Player]: Animal } = {}
local nextTry: { [Player]: number } = {}
local folder: Instance
local frenzy = false -- Wild Swarm: they drop far more often, from further away
local warnRemote: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include

local function groundAt(p: Vector3): Vector3
	groundRay.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 40, p.Z), Vector3.new(0, -120, 0), groundRay)
	return if hit then hit.Position else p
end

local function setAnim(a: Animal, clip: string, speed: number?)
	a.model:SetAttribute("Anim", clip)
	a.model:SetAttribute("AnimSpeed", speed or 1)
	a.model:SetAttribute("AnimRestart", ((a.model:GetAttribute("AnimRestart") :: number?) or 0) + 1)
end

-- blocky stand-in so the system works before the Blender models exist
local function standIn(kind: string): Model
	local m = Instance.new("Model")
	local colors = { Snake = Color3.fromRGB(70, 120, 50), Spider = Color3.fromRGB(40, 30, 30), Bat = Color3.fromRGB(60, 45, 50) }
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = if kind == "Snake" then Vector3.new(0.8, 0.8, 5) else Vector3.new(1.6, 1, 1.8)
	body.Color = colors[kind] or Color3.new(0.2, 0.2, 0.2)
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = m
	m.PrimaryPart = body
	return m
end

local function build(kind: string): (Model, CFrame)
	local templates = ReplicatedStorage:FindFirstChild("CreatureModels")
	local template = templates and templates:FindFirstChild(kind)
	local m = Instance.new("Model")
	m.Name = kind
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local v: Model
	if template and template:IsA("Model") then
		v = template:Clone()
		m:SetAttribute("Creature", kind)
	else
		v = standIn(kind)
	end
	v.Name = "Visual"
	for _, d in v:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	-- reference frame = the Body mesh (its -Z is the animal's head); the imported model's
	-- bounding box can come back rotated, so it is not used here
	local body = v:FindFirstChild("Body", true)
	local ref = if body and body:IsA("BasePart") then body.CFrame else v:GetBoundingBox()
	local fix = ref:ToObjectSpace(v:GetPivot())
	v.Parent = m
	if body and body:IsA("BasePart") then
		m.PrimaryPart = body
	end
	return m, fix
end

local function place(a: Animal, cf: CFrame)
	a.model:PivotTo(cf * a.fix)
end

local function nearestTree(pos: Vector3): Model?
	local map = Workspace:FindFirstChild("Map")
	local grove = map and map:FindFirstChild("PineGrove")
	if not grove then
		return nil
	end
	local best, bestD = nil, if frenzy then A.TreeSearchRadius * 1.6 else A.TreeSearchRadius
	for _, tree in grove:GetChildren() do
		local trunk = tree:FindFirstChild("Trunk")
		-- chopped trees are hidden (transparent) until they regrow
		if tree:IsA("Model") and trunk and trunk:IsA("BasePart") and trunk.Transparency < 0.5 then
			local p = tree:GetPivot().Position
			local d = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
			if d > 4 and d < bestD then
				best, bestD = tree, d
			end
		end
	end
	return best
end

local function cleanup(a: Animal)
	if active[a.target] == a then
		active[a.target] = nil
	end
	if a.target.Parent then
		a.target:SetAttribute("Latched", nil)
		local character = a.target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			Movement.SetBase(humanoid, Config.Resources.WalkSpeed)
		end
	end
	a.model:Destroy()
end

local function flee(a: Animal, from: Vector3)
	a.state = "Flee"
	setAnim(a, "Flee", 1.2)
	local away = Vector3.new(from.X - W.TowerCenter.X, 0, from.Z - W.TowerCenter.Z)
	if away.Magnitude < 1 then
		away = Vector3.new(1, 0, 0)
	end
	away = (away.Unit + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))).Unit
	local start = groundAt(from)
	local goal = groundAt(start + away * A.FleeDistance)
	local fly = a.kind == "Bat"
	local t0 = os.clock()
	local dur = A.FleeSeconds
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		if not a.model.Parent or k >= 1 then
			conn:Disconnect()
			cleanup(a)
			return
		end
		local p = start:Lerp(goal, k)
		if fly then
			p += Vector3.new(0, 3 + k * 22, 0)
		end
		local dir = Vector3.new(goal.X - start.X, 0, goal.Z - start.Z).Unit
		place(a, CFrame.lookAt(p, p + dir))
	end)
end

local function release(a: Animal, shookOff: boolean)
	if a.state ~= "Latch" then
		return
	end
	if a.weld then
		a.weld:Destroy()
		a.weld = nil
	end
	for _, d in a.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	a.target:SetAttribute("Latched", nil)
	local character = a.target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 then
		Movement.SetBase(humanoid, Config.Resources.WalkSpeed)
	end
	if shookOff then
		Remotes.notify(a.target, `You flung the {string.lower(a.kind)} off!`, "Good")
	end
	local from = if root and root:IsA("BasePart") then root.Position + root.CFrame.LookVector * 3 else a.model:GetPivot().Position
	flee(a, from)
end

local function latch(a: Animal)
	local character = a.target.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (head and head:IsA("BasePart") and humanoid) then
		flee(a, a.model:GetPivot().Position)
		return
	end
	a.state = "Latch"
	a.shakes = 0
	setAnim(a, "Latch", 1)
	local offsets: { [string]: CFrame } = {
		Snake = CFrame.new(0, -0.6, 0) * CFrame.Angles(0, math.pi, 0), -- coiled round the shoulders
		Spider = CFrame.new(0, 0.2, -0.75), -- clinging to the face
		Bat = CFrame.new(0, 1.0, 0), -- flapping on the head
	}
	place(a, head.CFrame * (offsets[a.kind] or CFrame.new()))
	for _, d in a.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	local primary = a.model.PrimaryPart
	if primary then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = primary
		weld.Parent = primary
		a.weld = weld
		-- the rest of the visual rides on the primary part
		for _, d in a.model:GetDescendants() do
			if d:IsA("BasePart") and d ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	local stats = (A.Kinds :: any)[a.kind]
	Movement.SetBase(humanoid, A.LatchedWalkSpeed)
	a.target:SetAttribute("Latched", a.kind)
	a.target:SetAttribute("LatchShakes", stats.Shakes)
	Remotes.notify(a.target, `A {string.lower(a.kind)} got you! Tap Space / the screen to shake it off!`, "Alarm")
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if a.state ~= "Latch" or not a.model.Parent then
			conn:Disconnect()
			return
		end
		if humanoid.Health <= 0 or not character.Parent then
			conn:Disconnect()
			release(a, false)
			return
		end
		humanoid:TakeDamage(stats.DamagePerSecond * dt)
		if os.clock() - t0 >= stats.LatchSeconds then
			conn:Disconnect()
			release(a, false)
		end
	end)
end

local function drop(player: Player, kind: string, tree: Model, root: BasePart)
	local stats = (A.Kinds :: any)[kind]
	local model, fix = build(kind)
	local a: Animal = { kind = kind, model = model, fix = fix, target = player, state = "Hang", shakes = 0, weld = nil }
	active[player] = a

	-- perch in the lower canopy on the side facing the player
	local treePos = tree:GetPivot().Position
	local toPlayer = Vector3.new(root.Position.X - treePos.X, 0, root.Position.Z - treePos.Z)
	toPlayer = if toPlayer.Magnitude > 0.1 then toPlayer.Unit else Vector3.new(1, 0, 0)
	local trunk = tree:FindFirstChild("Trunk") :: BasePart
	local perchY = trunk.Position.Y + trunk.Size.Y / 2 - 1
	local perch = Vector3.new(treePos.X, perchY, treePos.Z) + toPlayer * stats.PerchOut
	place(a, CFrame.lookAt(perch, perch + toPlayer))
	setAnim(a, "Hang", 1)
	model.Parent = folder

	-- aim at where the player is standing now: they get WarnSeconds to step away
	local land = groundAt(root.Position)
	warnRemote:FireAllClients(kind, tree, land, stats.WarnSeconds)
	task.wait(stats.WarnSeconds)
	if not model.Parent then
		return
	end

	a.state = "Drop"
	setAnim(a, "Drop", 1)
	local from = model:GetPivot() * fix:Inverse()
	local to = CFrame.lookAt(land + Vector3.new(0, 1.2, 0), land + Vector3.new(0, 1.2, 0) + toPlayer)
	local t0 = os.clock()
	while os.clock() - t0 < stats.DropSeconds do
		local k = (os.clock() - t0) / stats.DropSeconds
		local eased = k * k -- falls, speeding up
		local p = from.Position:Lerp(to.Position, eased)
		if kind == "Bat" then
			-- swoops in an arc instead of falling straight
			p += Vector3.new(0, math.sin(k * math.pi) * 2, 0) + toPlayer * math.sin(k * math.pi) * -3
		end
		place(a, CFrame.lookAt(p, p + toPlayer))
		local character = player.Character
		local r = character and character:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and (r.Position - p).Magnitude < stats.CatchRadius + 1.5 and k > 0.55 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if not model.Parent then
		return
	end

	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hit = false
	if r and r:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		local flat = Vector3.new(r.Position.X - land.X, 0, r.Position.Z - land.Z).Magnitude
		hit = flat <= stats.CatchRadius and math.abs(r.Position.Y - land.Y) < 7
	end
	if hit then
		latch(a)
	else
		a.state = "Land"
		place(a, to)
		setAnim(a, "Land", 1)
		task.wait(0.7)
		if model.Parent then
			flee(a, land)
		end
	end
end

local function trySpawn(player: Player)
	if active[player] or player:GetAttribute("Grabbed") == true then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return
	end
	local flat = Vector3.new(root.Position.X - W.TowerCenter.X, 0, root.Position.Z - W.TowerCenter.Z)
	if flat.Magnitude < A.SafeRadius or root.Position.Y > W.TowerCenter.Y + 14 then
		return -- in the lighthouse yard or up the tower
	end
	-- only while walking on the ground (not swimming, not mid-jump)
	if humanoid.FloorMaterial == Enum.Material.Air or humanoid.FloorMaterial == Enum.Material.Water then
		return
	end
	local tree = nearestTree(root.Position)
	if not tree then
		return
	end
	local kinds = {}
	for name, stats in A.Kinds :: any do
		for _ = 1, stats.Weight do
			table.insert(kinds, name)
		end
	end
	local kind = kinds[rng:NextInteger(1, #kinds)]
	task.spawn(drop, player, kind, tree, root)
end

function TreeAnimalService.Start()
	local runtime = Workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = Workspace
	local enemies = runtime:FindFirstChild("Enemies")
	if not enemies then
		local e = Instance.new("Folder")
		e.Name = "Enemies"
		e.Parent = runtime
		enemies = e
	end
	folder = enemies :: Instance
	warnRemote = Remotes.event("AnimalWarn")

	Remotes.event("Struggle").OnServerEvent:Connect(function(player: Player)
		local a = active[player]
		if not a or a.state ~= "Latch" then
			return
		end
		a.shakes += 1
		local needed = (A.Kinds :: any)[a.kind].Shakes
		player:SetAttribute("LatchShakes", math.max(0, needed - a.shakes))
		if a.shakes >= needed then
			release(a, true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local a = active[player]
		if a then
			cleanup(a)
		end
		nextTry[player] = nil
	end)

	local fast = RunService:IsStudio() and Workspace:GetAttribute("DebugAnimalsFast") == true
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for _, player in Players:GetPlayers() do
				local due = nextTry[player]
				if not due then
					nextTry[player] = t + (if fast then 3 else A.FirstDelay)
				elseif t >= due then
					nextTry[player] = t + (if fast then 6 elseif frenzy then rng:NextNumber(5, 9) else rng:NextNumber(A.MinInterval, A.MaxInterval))
					trySpawn(player)
				end
			end
		end
	end)

end

-- Wild Swarm turns this on for the length of the storm
function TreeAnimalService.SetFrenzy(on: boolean)
	frenzy = on
	if on then
		local t = now()
		for _, player in Players:GetPlayers() do
			nextTry[player] = math.min(nextTry[player] or math.huge, t + rng:NextNumber(2, 5))
		end
	end
end

return TreeAnimalService
