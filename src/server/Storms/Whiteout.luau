--!strict
-- Whiteout (Severe): a blizzard out of season. The cold gets into anyone outside (player
-- attribute "Chill", 0..1: it rises out in the open and falls under a roof or in the lamp's
-- light) and once you're frozen through it hurts. Every so often the snow closes in completely
-- (Workspace attribute "WhiteoutUntil", a server time): you can't see your own hand, and
-- something walks out of the white. Before it reaches you, its tracks do (StormEvent "Tracks":
-- clawed footprints appearing one by one in the snow, walking straight at a player); then a
-- Fog Crawler steps out of the white where they end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	ChillSeconds = 22,
	WarmSeconds = 6,
	FreezeDamage = 3, -- per second, frozen through
	PulseEvery = NumberRange.new(20, 30),
	FirstPulse = 10,
	PulseSeconds = 7,
	TracksFrom = 45, -- studs away the tracks start
	TrackStep = 3.2, -- studs between prints
	TrackPace = 0.32, -- seconds between prints
}

local Whiteout = {}

local active = false
local generation = 0
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include

local function groundAt(p: Vector3): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 40, p.Z), Vector3.new(0, -100, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function exposed(char: Model, root: BasePart): boolean
	if LightService.IsPointLit(root.Position) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
end

local function tracks(p: Player)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local from = root.Position + dir * S.TracksFrom
	local to = root.Position + dir * 6 -- they stop just short of you
	local g0, g1 = groundAt(from), groundAt(to)
	if not (g0 and g1) then
		return
	end
	local steps = math.floor((g0 - g1).Magnitude / S.TrackStep)
	Remotes.event("StormEvent"):FireClient(p, "Tracks", { from = g0, to = g1, steps = steps, pace = S.TrackPace })
	task.delay(steps * S.TrackPace + 0.3, function()
		if active then
			EnemyService.Spawn("FogCrawler", g1 + Vector3.new(0, 1, 0))
		end
	end)
end

local function pulse()
	Workspace:SetAttribute("WhiteoutUntil", Workspace:GetServerTimeNow() + S.PulseSeconds)
	Remotes.notify(nil, "The snow's closing in... you can't see a thing.", "Alarm")
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if char and root and root:IsA("BasePart") and not LightService.IsPointLit(root.Position) then
			task.delay(rng:NextNumber(0.5, 2), function()
				if active then
					tracks(p)
				end
			end)
		end
	end
end

function Whiteout.Start()
	active = true
	generation += 1
	local mine = generation
	task.spawn(function()
		local tick = 0
		while active and generation == mine do
			local dt = task.wait(0.5)
			tick += dt
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if char and root and root:IsA("BasePart") and hum and hum.Health > 0 then
					local chill = (p:GetAttribute("Chill") :: number?) or 0
					if exposed(char, root) then
						chill = math.min(1, chill + dt / S.ChillSeconds)
					else
						chill = math.max(0, chill - dt / S.WarmSeconds)
					end
					p:SetAttribute("Chill", chill)
					if chill >= 1 and tick >= 1 then
						hum:TakeDamage(S.FreezeDamage)
					end
				end
			end
			if tick >= 1 then
				tick = 0
			end
		end
	end)
	task.wait(S.FirstPulse)
	while active and generation == mine do
		pulse()
		task.wait(rng:NextNumber(S.PulseEvery.Min, S.PulseEvery.Max))
	end
end

function Whiteout.Stop()
	active = false
	Workspace:SetAttribute("WhiteoutUntil", nil)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Chill", nil)
	end
end

return Whiteout
