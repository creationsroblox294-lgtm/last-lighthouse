--!strict
-- Starfall (Blessed): meteors streak down all storm long. Each one is announced to clients
-- (StormEvent "Meteor") with a warning ring on the ground, lands 2.2 s later, hurts anyone
-- standing right where it hits, and leaves a glowing star shard (Blender model). Taking a
-- shard tops up the lamp. Shards fade out a while after the storm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	EverySeconds = NumberRange.new(1.3, 2.6),
	VolleyChance = 0.22, -- sometimes a whole cluster comes down at once
	VolleySize = NumberRange.new(3, 6),
	FallSeconds = 2.2, -- warning ring to impact
	NearPlayerChance = 0.65, -- otherwise anywhere on the island
	NearRadius = NumberRange.new(10, 70),
	HitRadius = 7,
	HitDamage = 20,
	MaxShards = 12,
	ShardFuel = 8,
	ShardLingerSeconds = 40, -- after the storm ends
}

local Starfall = {}

local active = false
local generation = 0
local shards: { Model } = {}
local folder: Folder? = nil
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function groundAt(x: number, z: number): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function pickTarget(): Vector3?
	for _ = 1, 12 do
		local x, z
		local players = Players:GetPlayers()
		if #players > 0 and rng:NextNumber() < S.NearPlayerChance then
			local p = players[rng:NextInteger(1, #players)]
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(S.NearRadius.Min, S.NearRadius.Max)
				x, z = root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r
			end
		end
		if not x then
			local c = Config.World.IslandCenter
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * Config.World.IslandRadius * 0.9
			x, z = c.X + math.cos(a) * r, c.Z + math.sin(a) * r
		end
		local pos = groundAt(x :: number, z :: number)
		if pos then
			return pos
		end
	end
	return nil
end

local function shardTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local m = assets and assets:FindFirstChild("StarShard")
	return if m and m:IsA("Model") then m else nil
end

local function removeShard(m: Model)
	local i = table.find(shards, m)
	if i then
		table.remove(shards, i)
	end
	m:Destroy()
end

local function spawnShard(pos: Vector3)
	local template = shardTemplate()
	if not template or not folder then
		return
	end
	if #shards >= S.MaxShards then
		removeShard(shards[1])
	end
	local m = template:Clone()
	local yaw = rng:NextNumber(0, math.pi * 2)
	local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), yaw, rng:NextNumber(-0.25, 0.25))
	-- the template's pivot sits at the base of the crystal cluster
	m:PivotTo(CFrame.new(pos - Vector3.new(0, 0.5, 0)) * tilt)
	local primary = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take star shard"
		prompt.ObjectText = "Star shard"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = primary
		prompt.Triggered:Connect(function(player: Player)
			if not m.Parent then
				return
			end
			removeShard(m)
			LightService.AddFuel(S.ShardFuel)
			Remotes.event("StormEvent"):FireAllClients("ShardTaken", pos)
			Remotes.notify(player, `Star shard: +{S.ShardFuel} lamp fuel`, "Good")
		end)
	end
	m.Parent = folder
	table.insert(shards, m)
end

local function impact(pos: Vector3)
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			if (root.Position - pos).Magnitude <= S.HitRadius then
				humanoid:TakeDamage(S.HitDamage)
			end
		end
	end
	spawnShard(pos)
end

function Starfall.Start()
	active = true
	generation += 1
	local mine = generation
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "StarShards"
		f.Parent = Workspace
		folder = f
	end
	local event = Remotes.event("StormEvent")
	while active and generation == mine do
		local count = if rng:NextNumber() < S.VolleyChance then rng:NextInteger(S.VolleySize.Min, S.VolleySize.Max) else 1
		for i = 1, count do
			local target = pickTarget()
			if target then
				local fallTime = S.FallSeconds + (i - 1) * rng:NextNumber(0.15, 0.4)
				event:FireAllClients("Meteor", { target = target, seconds = fallTime, seed = rng:NextInteger(1, 1e6) })
				task.delay(fallTime, function()
					impact(target)
				end)
			end
		end
		task.wait(rng:NextNumber(S.EverySeconds.Min, S.EverySeconds.Max))
	end
end

function Starfall.Stop()
	active = false
	local left = table.clone(shards)
	task.delay(S.ShardLingerSeconds, function()
		for _, m in left do
			if m.Parent then
				removeShard(m)
			end
		end
	end)
end

return Starfall
