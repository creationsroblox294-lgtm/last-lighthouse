--!strict
-- Morning Mist (Mild): thick mist hugs the ground at dawn and figures appear in it. Every few
-- seconds a hooded shape is seen standing out in the mist near a player (StormEvent "Phantom").
-- Most of them are only shapes in the vapour and dissolve when you get close, but some are
-- real: a Fog Mimic rises out of the mist there instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	Every = NumberRange.new(5, 9),
	Distance = NumberRange.new(25, 50), -- from a random player
	RealChance = 0.3,
}

local MorningMist = {}

local active = false
local generation = 0
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function landAt(x: number, z: number): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function appear()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.Distance.Min, S.Distance.Max)
		local at = landAt(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
		if at then
			local real = rng:NextNumber() < S.RealChance and EnemyService.Spawn("FogMimic", at) ~= nil
			Remotes.event("StormEvent"):FireAllClients("Phantom", { at = at, real = real, seed = rng:NextInteger(1, 1e6) })
			return
		end
	end
end

function MorningMist.Start()
	active = true
	generation += 1
	local mine = generation
	while active and generation == mine do
		appear()
		task.wait(rng:NextNumber(S.Every.Min, S.Every.Max))
	end
end

function MorningMist.Stop()
	active = false
end

return MorningMist
