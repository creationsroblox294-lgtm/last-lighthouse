--!strict
-- High Tide (Moderate): the sea swells up over the island. The flood level (Workspace
-- attribute "FloodLevel", in studs above the normal sea) creeps up over the first half
-- minute and drowns the beaches and low ground; clients draw the floodwater, slow anyone
-- wading through it and drag them seaward. Things rise out of the flood: every so often a
-- Drowned climbs up out of the water near someone standing in it. When the storm ends, the
-- water drains away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	MaxLevel = 6.5,
	RiseSeconds = 30,
	RecedeSeconds = 12,
	RiseEvery = NumberRange.new(6, 10), -- a Drowned comes up out of the flood
	RiseDistance = NumberRange.new(12, 28),
	SeaLevel = 0,
}

local HighTide = {}

local active = false
local generation = 0
local level = 0
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = true

local function groundY(x: number, z: number): number?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	return if hit then hit.Position.Y else nil
end

local function setLevel(v: number)
	level = v
	Workspace:SetAttribute("FloodLevel", if v > 0.01 then S.SeaLevel + v else nil)
end

local function riseFromFlood()
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and root.Position.Y < S.SeaLevel + level + 3 then
			for _ = 1, 6 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(S.RiseDistance.Min, S.RiseDistance.Max)
				local x, z = root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r
				local y = groundY(x, z)
				-- somewhere under the floodwater
				if y and y < S.SeaLevel + level - 0.5 then
					if EnemyService.Spawn("Drowned", Vector3.new(x, y, z)) then
						Remotes.event("StormEvent"):FireAllClients("FloodRise", Vector3.new(x, S.SeaLevel + level, z))
					end
					break
				end
			end
			return -- one at a time
		end
	end
end

function HighTide.Start()
	active = true
	generation += 1
	local mine = generation
	local t0 = os.clock()
	task.spawn(function()
		while active and generation == mine do
			local k = math.clamp((os.clock() - t0) / S.RiseSeconds, 0, 1)
			setLevel(S.MaxLevel * (k * k * (3 - 2 * k)))
			task.wait(0.25)
		end
	end)
	task.wait(8)
	while active and generation == mine do
		riseFromFlood()
		task.wait(rng:NextNumber(S.RiseEvery.Min, S.RiseEvery.Max))
	end
end

function HighTide.Stop()
	active = false
	local mine = generation
	local from = level
	task.spawn(function()
		local t0 = os.clock()
		while not active and generation == mine do
			local k = math.clamp((os.clock() - t0) / S.RecedeSeconds, 0, 1)
			setLevel(from * (1 - k))
			if k >= 1 then
				break
			end
			task.wait(0.25)
		end
	end)
end

return HighTide
