--!strict
-- Thunderhead (Moderate): a towering supercell sits over the island and lightning is
-- everywhere. Bolts strike near players every second or two (StormEvent "Strike": a small
-- ring of static marks the spot a moment before). Anyone carrying scrap metal is a lightning
-- rod: bolts go for them far more often. Now and then the cloud unloads (StormEvent
-- "Barrage"): a ring of bolts hammers down around every player at once. Bolts that hit the
-- lighthouse knock fuel out of the lamp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))

local S = {
	StrikeEvery = NumberRange.new(0.9, 2.2),
	Warn = 1.0,
	Radius = 6,
	Damage = 20,
	Near = NumberRange.new(10, 70),
	RodChance = 0.55, -- a scrap carrier gets aimed at directly this often
	LampChance = 0.04,
	LampDrain = 4,
	BarrageEvery = NumberRange.new(18, 26),
	BarrageWarnSeconds = 2.5, -- the cloud lights up before it unloads
	BarrageBolts = NumberRange.new(6, 9),
	BarrageRadius = NumberRange.new(6, 26),
}

local Thunderhead = {}

local active = false
local generation = 0
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function landAt(x: number, z: number): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	return if hit then hit.Position else nil
end

local function hurt(at: Vector3)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and hum and hum.Health > 0 then
			local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
			if flat.Magnitude < S.Radius and math.abs(root.Position.Y - at.Y) < 12 then
				hum:TakeDamage(S.Damage)
			end
		end
	end
	local runtime = Workspace:FindFirstChild("Runtime")
	local enemies = runtime and runtime:FindFirstChild("Enemies")
	if enemies then
		for _, m in enemies:GetChildren() do
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if m.Name ~= "Fish" and hum and root and root:IsA("BasePart") and (root.Position - at).Magnitude < S.Radius * 1.5 then
				hum:TakeDamage(S.Damage * 2)
			end
		end
	end
end

local function bolt(at: Vector3, warn: number, rod: boolean)
	Remotes.event("StormEvent"):FireAllClients("Strike", { at = at, warn = warn, radius = S.Radius, rod = rod, seed = rng:NextInteger(1, 1e6) })
	task.delay(warn, hurt, at)
end

local function randomRoot(): (Player?, BasePart?)
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil, nil
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return p, if root and root:IsA("BasePart") then root else nil
end

local function strike()
	-- the lighthouse
	if rng:NextNumber() < S.LampChance then
		local c = LightService.GetCenter()
		Remotes.event("StormEvent"):FireAllClients("LampStruck", { at = c + Vector3.new(0, 60, 0), warn = S.Warn })
		task.delay(S.Warn, function()
			LightService.DrainFuel(S.LampDrain)
			Remotes.notify(nil, `Lightning hit the lighthouse! The lamp lost {S.LampDrain} fuel.`, "Alarm")
		end)
		return
	end
	-- a lightning rod: someone carrying scrap
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if ResourceService.Has(p, "Scrap") and root and root:IsA("BasePart") and rng:NextNumber() < S.RodChance then
			local at = landAt(root.Position.X, root.Position.Z)
			if at then
				bolt(at, S.Warn, true)
				return
			end
		end
	end
	local _, root = randomRoot()
	if not root then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(S.Near.Min, S.Near.Max)
	local at = landAt(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
	if at then
		bolt(at, S.Warn, false)
	end
end

local function barrage()
	Remotes.event("StormEvent"):FireAllClients("Barrage", { warn = S.BarrageWarnSeconds })
	Remotes.notify(nil, "The Thunderhead is about to unload! Get under cover!", "Alarm")
	task.wait(S.BarrageWarnSeconds)
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local centre = root.Position
			local n = rng:NextInteger(S.BarrageBolts.Min, S.BarrageBolts.Max)
			for i = 1, n do
				local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local r = rng:NextNumber(S.BarrageRadius.Min, S.BarrageRadius.Max)
				local at = landAt(centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r)
				if at then
					task.delay(i * 0.18, bolt, at, 1.1, false)
				end
			end
		end
	end
end

function Thunderhead.Start()
	active = true
	generation += 1
	local mine = generation
	task.spawn(function()
		while active and generation == mine do
			task.wait(rng:NextNumber(S.BarrageEvery.Min, S.BarrageEvery.Max))
			if active and generation == mine then
				barrage()
			end
		end
	end)
	task.wait(2)
	while active and generation == mine do
		strike()
		task.wait(rng:NextNumber(S.StrikeEvery.Min, S.StrikeEvery.Max))
	end
end

function Thunderhead.Stop()
	active = false
end

return Thunderhead
