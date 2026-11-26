--!strict
-- Gale (Moderate): a howling wind that never lets up (Workspace attribute "WindDir"; each
-- client leans its own character into it, since players own their physics). Debris (Blender
-- planks and branches) is flung across the island at players (StormEvent "Debris": it tumbles
-- in from upwind and hits whoever is still where it was aimed). And anyone carrying something
-- out in the open can have it torn out of their hands and blown away downwind.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local ResourceService = require(Server:WaitForChild("ResourceService"))

local S = {
	DebrisEvery = NumberRange.new(2.5, 5),
	DebrisFrom = 140, -- studs upwind it comes from
	DebrisSeconds = 2.2, -- flight time, so it can be seen coming
	HitRadius = 5,
	HitDamage = 14,
	SnatchEvery = 4, -- seconds between snatch checks
	SnatchChance = 0.3, -- chance an exposed carrier loses their load each check
	SnatchDistance = NumberRange.new(18, 32),
}

local Gale = {}

local active = false
local generation = 0
local rng = Random.new()
local windDir = Vector3.new(1, 0, 0)

local function exposed(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
end

local function fling()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local side = Vector3.new(-windDir.Z, 0, windDir.X)
	local to = root.Position + side * rng:NextNumber(-4, 4)
	local from = to - windDir * S.DebrisFrom + side * rng:NextNumber(-30, 30) + Vector3.new(0, rng:NextNumber(25, 45), 0)
	Remotes.event("StormEvent"):FireAllClients("Debris", {
		from = from,
		to = to,
		seconds = S.DebrisSeconds,
		kind = if rng:NextNumber() < 0.5 then "Plank" else "Branch",
		seed = rng:NextInteger(1, 1e6),
		radius = S.HitRadius,
	})
	task.delay(S.DebrisSeconds, function()
		for _, pl in Players:GetPlayers() do
			local char = pl.Character
			local rr = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if rr and rr:IsA("BasePart") and hum and hum.Health > 0 and (rr.Position - to).Magnitude < S.HitRadius then
				hum:TakeDamage(S.HitDamage)
			end
		end
	end)
end

local function snatch()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local kind = ResourceService.GetCarried(p)
		if kind and char and root and root:IsA("BasePart") and exposed(char, root) and rng:NextNumber() < S.SnatchChance then
			local to = root.Position + windDir * rng:NextNumber(S.SnatchDistance.Min, S.SnatchDistance.Max)
			Remotes.event("StormEvent"):FireAllClients("Snatch", { from = root.Position, to = to })
			ResourceService.DropCarried(p, to)
			Remotes.notify(p, `The wind tore the {string.lower(kind)} out of your hands!`, "Alarm")
		end
	end
end

function Gale.Start()
	active = true
	generation += 1
	local mine = generation
	local a = rng:NextNumber(0, math.pi * 2)
	windDir = Vector3.new(math.cos(a), 0, math.sin(a))
	Workspace:SetAttribute("WindDir", windDir)
	task.spawn(function()
		while active and generation == mine do
			task.wait(S.SnatchEvery)
			if active and generation == mine then
				snatch()
			end
		end
	end)
	task.wait(2)
	while active and generation == mine do
		fling()
		task.wait(rng:NextNumber(S.DebrisEvery.Min, S.DebrisEvery.Max))
	end
end

function Gale.Stop()
	active = false
	Workspace:SetAttribute("WindDir", nil)
end

return Gale
