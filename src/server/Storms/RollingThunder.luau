--!strict
-- Rolling Thunder (Mild): thunder rolls across the island (StormEvent "Thunder") and lightning
-- hunts the players. Every few seconds the air around one player starts to crackle (StormEvent
-- "StaticStrike": a ring marks the spot they're standing on): they have a moment to get clear
-- before the bolt hits that spot. Being caught hurts, and every strike sets the ground on fire
-- for a while: the flames burn anyone, player or creature, who stands in them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = {
	StrikeEvery = NumberRange.new(5, 9),
	Warn = 1.6, -- seconds to move away
	HitRadius = 6,
	HitDamage = 25,
	FireRadius = 6,
	FireSeconds = 10,
	FireDamage = 4, -- every half second
	ThunderEvery = NumberRange.new(5, 10),
}

local RollingThunder = {}

type Fire = { at: Vector3, untilT: number }

local active = false
local generation = 0
local fires: { Fire } = {}
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function groundAt(pos: Vector3): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function hurtNear(at: Vector3, radius: number, damage: number, playersToo: boolean)
	local runtime = Workspace:FindFirstChild("Runtime")
	local enemies = runtime and runtime:FindFirstChild("Enemies")
	if enemies then
		for _, m in enemies:GetChildren() do
			if m.Name ~= "Fish" and m:IsA("Model") then
				local hum = m:FindFirstChildOfClass("Humanoid")
				local root = m:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and root and root:IsA("BasePart") then
					local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
					if flat.Magnitude < radius then
						hum:TakeDamage(damage)
					end
				end
			end
		end
	end
	if playersToo then
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and hum and hum.Health > 0 then
				local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
				if flat.Magnitude < radius and math.abs(root.Position.Y - at.Y) < 10 then
					hum:TakeDamage(damage)
				end
			end
		end
	end
end

local function strike()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local at = groundAt(root.Position)
	if not at then
		return -- out over the water: the storm loses track of them
	end
	Remotes.event("StormEvent"):FireAllClients("StaticStrike", { at = at, target = p.UserId, warn = S.Warn, radius = S.HitRadius, fire = S.FireSeconds })
	task.delay(S.Warn, function()
		hurtNear(at, S.HitRadius, S.HitDamage, true)
		table.insert(fires, { at = at, untilT = os.clock() + S.FireSeconds })
	end)
end

function RollingThunder.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(fires)
	-- the fires burn
	task.spawn(function()
		while active and generation == mine do
			local now = os.clock()
			for i = #fires, 1, -1 do
				local f = fires[i]
				if now > f.untilT then
					table.remove(fires, i)
				else
					hurtNear(f.at, S.FireRadius, S.FireDamage, true)
				end
			end
			task.wait(0.5)
		end
	end)
	-- thunder rolling across the sky
	task.spawn(function()
		while active and generation == mine do
			task.wait(rng:NextNumber(S.ThunderEvery.Min, S.ThunderEvery.Max))
			if active and generation == mine then
				local a = rng:NextNumber(0, math.pi * 2)
				Remotes.event("StormEvent"):FireAllClients("Thunder", { dir = Vector3.new(math.cos(a), 0, math.sin(a)), strength = rng:NextNumber(0.5, 1) })
			end
		end
	end)
	task.wait(3)
	while active and generation == mine do
		strike()
		task.wait(rng:NextNumber(S.StrikeEvery.Min, S.StrikeEvery.Max))
	end
end

function RollingThunder.Stop()
	active = false
end

return RollingThunder
