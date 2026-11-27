--!strict
-- HollowService: the Hollow, a tall pale stalker that arrives after storm 12.
-- It never fights head-on. Between storms (calm, warning, dawn) it walks out of the fog,
-- stalks the most isolated player outside the light, grabs them and drags them to the fog edge.
--   Reaching the fog edge = the victim is lost (dies).
--   Released by: 3 harpoon hits, a flare, the lighthouse beam, struggling (tap ~12 times),
--   or the victim being dragged into the light while the lamp is above half fuel.
-- One victim per appearance. The model is anchored and moved by the server; clients
-- animate it through the Creature/Anim attributes (CreatureController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local LightService = require(script.Parent:WaitForChild("LightService"))

local H = Config.Hollow
local HollowService = {}

type State = "Dormant" | "Emerging" | "Stalking" | "Hunting" | "Dragging" | "Retreating"

local state: State = "Dormant"
local model: Model? = nil
local visual: Model? = nil
local pivotFromGround = CFrame.identity
local pos = Vector3.zero
local facing = Vector3.new(0, 0, -1)
local target: Player? = nil
local victim: Player? = nil
local grabWeld: WeldConstraint? = nil
local anchor: Part? = nil
local stateSince = 0
local nextAppear = math.huge
local hits = 0
local struggles = 0
local appearedThisPhase = false
local stateObj: Instance? = nil

local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include

local function now(): number
	return os.clock()
end

local function groundAt(p: Vector3): Vector3
	ray.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(p.X, 120, p.Z), Vector3.new(0, -200, 0), ray)
	return if hit then Vector3.new(p.X, math.max(hit.Position.Y, 0), p.Z) else Vector3.new(p.X, 4, p.Z)
end

local function setAnim(name: string, speed: number?)
	local m = model
	if m then
		if m:GetAttribute("Anim") ~= name then
			m:SetAttribute("Anim", name)
		end
		m:SetAttribute("AnimSpeed", speed or 1)
	end
end

local function setState(s: State)
	state = s
	stateSince = now()
	local obj = stateObj
	if obj then
		obj:SetAttribute("State", s)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function lightProtects(p: Vector3): boolean
	return LightService.IsPointLit(p) and LightService.GetFuel() / Config.Light.MaxFuel > H.LightSafeFuelFraction
end

local function place()
	local m = model
	if not m then
		return
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	m:PivotTo(CFrame.lookAt(pos, pos + flat.Unit) * pivotFromGround)
	local a = anchor
	if a then
		-- the victim hangs from the Hollow's right hand, in front of its chest
		a.CFrame = CFrame.lookAt(pos, pos + flat.Unit) * CFrame.new(1.2, 5.2, -2.2)
	end
end

local function despawn()
	local m = model
	if m then
		m:Destroy()
	end
	model = nil
	visual = nil
	local a = anchor
	if a then
		a:Destroy()
	end
	anchor = nil
	target = nil
	setState("Dormant")
	nextAppear = now() + Random.new():NextNumber(H.MinInterval, H.MaxInterval)
end

local function spawnAt(p: Vector3)
	local folder = ReplicatedStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild("Hollow")
	if not template or not template:IsA("Model") then
		warn("[HollowService] ReplicatedStorage.CreatureModels.Hollow missing")
		return
	end
	local runtime = Workspace:FindFirstChild("Runtime")
	local enemies = runtime and runtime:FindFirstChild("Enemies")
	local m = Instance.new("Model")
	m.Name = "Hollow"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local v = template:Clone()
	v.Name = "Visual"
	for _, d in v:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	-- ground-relative pivot: feet on the ground, centred
	local box, size = v:GetBoundingBox()
	local groundCF = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * box.Rotation -- keep the model's own facing (its pivot looks forward)
	pivotFromGround = groundCF:ToObjectSpace(v:GetPivot())
	v.Parent = m
	m:SetAttribute("Creature", "Hollow")
	m:SetAttribute("Anim", "Emerge")
	m:SetAttribute("AnimSpeed", 1)
	m.PrimaryPart = v:FindFirstChild("Body") :: BasePart?
	m.Parent = enemies or Workspace
	model = m
	visual = v
	pos = groundAt(p)
	facing = (Vector3.new(0, pos.Y, 0) - pos)
	place()
	hits = 0
	setState("Emerging")
	setAnim("Emerge", 1)
	Remotes.notify(nil, "The lights flicker... something tall is watching from the treeline.", "Alarm")
end

-- the most isolated living player outside the protecting light
local function pickTarget(): Player?
	local best: Player? = nil
	local bestScore = -math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not lightProtects(root.Position) and player:GetAttribute("Lost") ~= true then
			local nearest = math.huge
			for _, other in Players:GetPlayers() do
				local r2 = other ~= player and rootOf(other)
				if r2 then
					nearest = math.min(nearest, (r2.Position - root.Position).Magnitude)
				end
			end
			local c = LightService.GetCenter()
			local fromTower = Vector2.new(root.Position.X - c.X, root.Position.Z - c.Z).Magnitude
			local score = math.min(nearest, 200) + fromTower * 0.5
			if score > bestScore then
				best = player
				bestScore = score
			end
		end
	end
	return best
end

local function lairPoint(near: Vector3?): Vector3
	local best = H.Lairs[1]
	if near then
		local d = math.huge
		for _, l in H.Lairs do
			local dist = (l - near).Magnitude
			if dist < d then
				d = dist
				best = l
			end
		end
	else
		best = H.Lairs[math.random(1, #H.Lairs)]
	end
	return best
end

local function release(reason: string)
	local v = victim
	if v then
		local w = grabWeld
		if w then
			w:Destroy()
		end
		grabWeld = nil
		local character = v.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.PlatformStand = false
		end
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = facing.Unit * -20 + Vector3.new(0, 18, 0)
			pcall(function()
				root:SetNetworkOwner(v)
			end)
		end
		v:SetAttribute("Grabbed", false)
		if reason ~= "" then
			Remotes.notify(v, reason, "Good")
		end
	end
	victim = nil
	struggles = 0
	setState("Retreating")
	setAnim("Recoil", 1)
end

local function grab(player: Player)
	local root = rootOf(player)
	local a = anchor
	if not root then
		return
	end
	if not a then
		local part = Instance.new("Part")
		part.Name = "HollowGrip"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.new(0.5, 0.5, 0.5)
		part.Parent = model
		anchor = part
		a = part
	end
	place()
	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
	end
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.CFrame = (a :: Part).CFrame
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = root
	w.Parent = a
	grabWeld = w
	victim = player
	struggles = 0
	player:SetAttribute("Grabbed", true)
	setState("Dragging")
	setAnim("Drag", 1)
	Remotes.notify(player, "The Hollow has you! Struggle! (tap Space / the screen)", "Alarm")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.notify(other, `The Hollow took {player.DisplayName}! Harpoon it, flare it or turn the beam on it!`, "Alarm")
		end
	end
end

local function moveToward(goal: Vector3, speed: number, dt: number)
	local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = flat.Magnitude
	if dist > 0.1 then
		local step = math.min(dist, speed * dt)
		facing = facing:Lerp(flat.Unit, math.min(1, dt * 5))
		pos = groundAt(pos + flat.Unit * step)
	end
	place()
	return dist
end

local function fogEdgePoint(from: Vector3): Vector3
	local c = LightService.GetCenter()
	local dir = Vector3.new(from.X - c.X, 0, from.Z - c.Z)
	if dir.Magnitude < 1 then
		dir = Vector3.new(1, 0, 0)
	end
	local p = Vector3.new(c.X, 0, c.Z) + dir.Unit * H.FogEdgeRadius
	return Vector3.new(p.X, from.Y, p.Z)
end

local function update(dt: number)
	local t = now()
	if state == "Dormant" then
		return
	end
	if not model then
		state = "Dormant"
		return
	end
	-- the beam always drives it off
	if LightService.IsInBeam(pos, 6) and state ~= "Retreating" then
		if victim then
			release("The beam burned it! You're free.")
		else
			setState("Retreating")
			setAnim("Recoil", 1)
		end
		return
	end
	if state == "Emerging" then
		if t - stateSince > H.EmergeSeconds then
			target = pickTarget()
			setState("Stalking")
		end
	elseif state == "Stalking" or state == "Hunting" then
		local tgt = target
		local root = tgt and rootOf(tgt)
		if not root or lightProtects(root.Position) then
			target = pickTarget()
			if not target then
				if t - stateSince > H.GiveUpSeconds then
					setState("Retreating")
				end
				setAnim("Idle", 1)
				place()
			end
			return
		end
		local dist = (root.Position - pos).Magnitude
		if state == "Stalking" and dist < H.HuntDistance then
			setState("Hunting")
			Remotes.notify(tgt, "Footsteps behind you. RUN to the light!", "Alarm")
		end
		local speed = if state == "Hunting" then H.RunSpeed else H.StalkSpeed
		setAnim(if state == "Hunting" then "Run" else "Stalk", speed / (if state == "Hunting" then 20 else 8))
		moveToward(root.Position, speed, dt)
		if dist < H.GrabRange and tgt then
			setAnim("Grab", 1)
			grab(tgt)
		end
	elseif state == "Dragging" then
		local v = victim
		local root = v and rootOf(v)
		if not v or not root then
			release("")
			return
		end
		if lightProtects(pos) then
			release("The light forced it to drop you!")
			return
		end
		local goal = fogEdgePoint(pos)
		local dist = moveToward(goal, H.DragSpeed, dt)
		if dist < 3 then
			local humanoid = v.Character and v.Character:FindFirstChildOfClass("Humanoid")
			local w = grabWeld
			if w then
				w:Destroy()
			end
			grabWeld = nil
			victim = nil
			v:SetAttribute("Grabbed", false)
			if humanoid then
				humanoid.Health = 0
			end
			Remotes.notify(nil, `{v.DisplayName} was dragged into the fog...`, "Alarm")
			setState("Retreating")
		end
	elseif state == "Retreating" then
		if t - stateSince < 1.2 then
			place()
			return
		end
		setAnim("Run", 1.1)
		local dist = moveToward(fogEdgePoint(pos), H.RunSpeed * 1.2, dt)
		if dist < 4 then
			despawn()
		end
	end
end

local function phaseAllows(): boolean
	local info = StormDirector.GetInfo()
	local p = info.phase
	if p ~= "Calm" and p ~= "Warning" and p ~= "Dawn" then
		return false
	end
	local forced = RunService:IsStudio() and Workspace:GetAttribute("DebugHollowNow") == true
	return forced or info.currentStorm > H.ArrivesAfterStorm
end

-- public hooks ---------------------------------------------------------------

function HollowService.GetModel(): Model?
	return model
end

function HollowService.GetPosition(): Vector3?
	return if model then pos else nil
end

-- harpoon: true if the Hollow was hit
function HollowService.TryHarpoon(origin: Vector3, look: Vector3, range: number, cone: number): boolean
	if not model or state == "Dormant" or state == "Retreating" then
		return false
	end
	local offset = (pos + Vector3.new(0, 5, 0)) - origin
	if offset.Magnitude > range + 4 then
		return false
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 3 and flatLook.Magnitude > 0 and flat.Unit:Dot(flatLook.Unit) < math.cos(math.rad(cone)) then
		return false
	end
	hits += 1
	local m = model
	if m then
		m:SetAttribute("AnimRestart", (m:GetAttribute("AnimRestart") or 0) :: number + 1)
	end
	if hits >= H.HitsToDriveOff then
		if victim then
			release("The harpoons drove it off!")
		else
			setState("Retreating")
			setAnim("Recoil", 1)
		end
	else
		setAnim("Recoil", 1.4)
		task.delay(0.6, function()
			if state == "Dragging" then
				setAnim("Drag", 1)
			end
		end)
	end
	return true
end

-- flare: drives it off if close enough
function HollowService.Flare(from: Vector3): boolean
	if not model or state == "Dormant" then
		return false
	end
	if (pos - from).Magnitude > H.FlareRange then
		return false
	end
	if victim then
		release("The flare blinded it! You're free.")
	else
		setState("Retreating")
		setAnim("Recoil", 1)
	end
	return true
end

function HollowService.Start()
	local folder = ReplicatedStorage:FindFirstChild("State")
	local obj = folder and folder:FindFirstChild("Hollow")
	if not obj and folder then
		local c = Instance.new("Configuration")
		c.Name = "Hollow"
		c.Parent = folder
		obj = c
	end
	stateObj = obj
	setState("Dormant")

	Remotes.event("Struggle").OnServerEvent:Connect(function(player: Player)
		if player ~= victim or state ~= "Dragging" then
			return
		end
		struggles += 1
		if struggles >= H.StrugglesToEscape then
			release("You tore free!")
		end
	end)

	StormDirector.PhaseChanged:Connect(function(info)
		appearedThisPhase = false
		if info.phase == "Storm" or info.phase == "Lost" then
			if victim then
				release("")
			end
			if model then
				despawn()
			end
		end
		if nextAppear == math.huge or info.phase == "Calm" then
			local fast = RunService:IsStudio() and Workspace:GetAttribute("DebugHollowNow") == true
			nextAppear = now() + (if fast then 4 else Random.new():NextNumber(H.MinInterval, H.MaxInterval) * 0.5)
		end
	end)
	StormDirector.RunReset:Connect(function()
		if victim then
			release("")
		end
		if model then
			despawn()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player == victim then
			victim = nil
			setState("Retreating")
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if state == "Dormant" then
			if not appearedThisPhase and now() >= nextAppear and phaseAllows() then
				local tgt = pickTarget()
				if tgt then
					local root = rootOf(tgt)
					appearedThisPhase = not (RunService:IsStudio() and Workspace:GetAttribute("DebugHollowNow") == true)
					spawnAt(lairPoint(root and root.Position))
					target = tgt
				end
			end
			return
		end
		update(dt)
	end)
end

return HollowService
