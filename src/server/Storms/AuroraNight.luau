--!strict
-- Aurora Night (Blessed): the sky burns green and violet and the creatures come out weak
-- (half health, see EnemyHealthMultiplier). Aurora wisps drift down and float around the
-- island near players. Touching one restores lamp fuel and health and sets off an aurora
-- pulse that scorches creatures nearby (StormEvent "WispTaken").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	EverySeconds = NumberRange.new(1.6, 3),
	MaxWisps = 10,
	SpawnRadius = NumberRange.new(18, 55), -- around a random player
	PickupRadius = 5,
	Fuel = 4,
	Heal = 15,
	PulseRadius = 26,
	PulseDamage = 35,
	LifeSeconds = 35,
}

local AuroraNight = {}

type Wisp = { part: BasePart, home: Vector3, born: number, phase: number }

local active = false
local generation = 0
local wisps: { Wisp } = {}
local folder: Folder? = nil
local rng = Random.new()
local heartbeat: RBXScriptConnection? = nil

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function groundY(x: number, z: number): number?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position.Y
	end
	return nil
end

local function removeWisp(i: number)
	local w = wisps[i]
	table.remove(wisps, i)
	w.part:Destroy()
end

local function spawnWisp()
	if not folder then
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(S.SpawnRadius.Min, S.SpawnRadius.Max)
	local x, z = root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r
	local y = groundY(x, z)
	if not y then
		return
	end
	if #wisps >= S.MaxWisps then
		removeWisp(1)
	end
	-- the server keeps a plain invisible marker; clients draw the glowing wisp around it
	local part = Instance.new("Part")
	part.Name = "AuroraWisp"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.6, 1.6, 1.6)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(120, 255, 190)
	part.Transparency = 0.2
	part.CastShadow = false
	part:SetAttribute("Hue", rng:NextNumber())
	local home = Vector3.new(x, y + 3.5, z)
	part.CFrame = CFrame.new(home + Vector3.new(0, 30, 0))
	part.Parent = folder
	table.insert(wisps, { part = part, home = home, born = os.clock(), phase = rng:NextNumber(0, 10) })
end

local function pulse(at: Vector3)
	local runtime = Workspace:FindFirstChild("Runtime")
	local enemies = runtime and runtime:FindFirstChild("Enemies")
	if not enemies then
		return
	end
	for _, m in enemies:GetChildren() do
		if m.Name ~= "Fish" and m:IsA("Model") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and root and root:IsA("BasePart") and (root.Position - at).Magnitude < S.PulseRadius then
				hum:TakeDamage(S.PulseDamage)
			end
		end
	end
end

local function step()
	local now = os.clock()
	for i = #wisps, 1, -1 do
		local w = wisps[i]
		local age = now - w.born
		if age > S.LifeSeconds or not w.part.Parent then
			removeWisp(i)
		else
			-- drift down out of the sky, then bob and wander lazily around home
			local t = now + w.phase
			local descend = math.max(0, 1 - age / 2.5)
			local pos = w.home + Vector3.new(math.sin(t * 0.7) * 3, math.sin(t * 1.9) * 0.8 + descend * descend * 30, math.cos(t * 0.5) * 3)
			w.part.CFrame = CFrame.new(pos)
			if age > 1.5 then
				for _, p in Players:GetPlayers() do
					local char = p.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if root and root:IsA("BasePart") and hum and hum.Health > 0 and (root.Position - pos).Magnitude < S.PickupRadius then
						removeWisp(i)
						LightService.AddFuel(S.Fuel)
						hum.Health = math.min(hum.MaxHealth, hum.Health + S.Heal)
						pulse(pos)
						Remotes.event("StormEvent"):FireAllClients("WispTaken", pos)
						Remotes.notify(p, `Aurora wisp: +{S.Fuel} lamp fuel, +{S.Heal} health`, "Good")
						break
					end
				end
			end
		end
	end
end

function AuroraNight.Start()
	active = true
	generation += 1
	local mine = generation
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "AuroraWisps"
		f.Parent = Workspace
		folder = f
	end
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
	while active and generation == mine do
		spawnWisp()
		task.wait(rng:NextNumber(S.EverySeconds.Min, S.EverySeconds.Max))
	end
end

function AuroraNight.Stop()
	active = false
	local mine = generation
	-- the last wisps fade out a little after dawn
	task.delay(10, function()
		if active or generation ~= mine then
			return
		end
		for i = #wisps, 1, -1 do
			removeWisp(i)
		end
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end)
end

return AuroraNight
