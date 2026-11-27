--!strict
-- Sandstorm Surge (Moderate): a hot, howling wind off the beaches (Workspace attribute
-- "WindDir"). The beaches themselves are deadly: anyone standing on sand is flayed by it. And
-- every so often a surge comes: a towering wall of sand (StormEvent "SandSurge": where it
-- starts, which way it goes, how fast) that races in off the sea and right across the island.
-- Anyone it catches out in the open is bowled over and battered (StormEvent "SurgeHit" to that
-- player); it scours the lamp as it passes the lighthouse; and once it's gone it has stripped
-- the beaches bare, uncovering scrap and oil in the sand (items with attribute "Unearthed").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))

local S = {
	Every = NumberRange.new(24, 34),
	FirstAfter = 8,
	Reach = 800, -- surges start this far out from the island centre and travel twice as far
	Speed = NumberRange.new(55, 70),
	Swing = math.rad(35), -- how far a surge's heading can stray from the wind
	HitDamage = 12,
	Scour = 4, -- lamp fuel lost when a surge rolls over the lighthouse
	BeachDamage = 1.5, -- per half second while standing on sand
	Unearth = NumberRange.new(2, 3), -- items uncovered on the beaches after each surge
	BeachRing = NumberRange.new(470, 640), -- where to look for sand to uncover them in
}

local SandstormSurge = {}

type Surge = { start: Vector3, dir: Vector3, speed: number, t0: number, scoured: boolean, hit: { [Player]: boolean } }

local active = false
local generation = 0
local surges: { Surge } = {}
local windDir = Vector3.new(1, 0, 0)
local warned: { [Player]: number } = {}
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function sheltered(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 80, 0), params) ~= nil
end

local function front(s: Surge, now: number): Vector3
	return s.start + s.dir * s.speed * (now - s.t0)
end

local function unearth()
	local c = Config.World.IslandCenter
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local want = rng:NextInteger(S.Unearth.Min, S.Unearth.Max)
	local found = 0
	for _ = 1, 40 do
		if found >= want then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.BeachRing.Min, S.BeachRing.Max)
		local hit = Workspace:Raycast(Vector3.new(c.X + math.cos(a) * r, 400, c.Z + math.sin(a) * r), Vector3.new(0, -800, 0), ground)
		if hit and hit.Material == Enum.Material.Sand then
			local item = ResourceService.SpawnItem(if rng:NextNumber() < 0.5 then "Scrap" else "Oil", hit.Position + Vector3.new(0, 1.5, 0))
			if item then
				item:SetAttribute("Unearthed", true)
				found += 1
			end
		end
	end
	if found > 0 then
		Remotes.notify(nil, "The surge stripped the beaches bare. Something is glinting in the sand...", "Good")
	end
end

local function newSurge()
	local a = math.atan2(windDir.Z, windDir.X) + rng:NextNumber(-S.Swing, S.Swing)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local c = Config.World.IslandCenter
	local s: Surge = {
		start = Vector3.new(c.X, 0, c.Z) - dir * S.Reach,
		dir = dir,
		speed = rng:NextNumber(S.Speed.Min, S.Speed.Max),
		t0 = Workspace:GetServerTimeNow(),
		scoured = false,
		hit = {},
	}
	table.insert(surges, s)
	Remotes.event("StormEvent"):FireAllClients("SandSurge", { start = s.start, dir = s.dir, speed = s.speed, t0 = s.t0 })
	Remotes.notify(nil, "A SAND SURGE is coming! Get under a roof!", "Alarm")
end

local function step(dt: number)
	local now = Workspace:GetServerTimeNow()
	for i = #surges, 1, -1 do
		local s = surges[i]
		local travelled = s.speed * (now - s.t0)
		if travelled > S.Reach * 2 then
			table.remove(surges, i)
			unearth()
		else
			local f = front(s, now)
			if not s.scoured and (LightService.GetCenter() - f):Dot(s.dir) < 0 then
				s.scoured = true
				LightService.DrainFuel(S.Scour)
				Remotes.notify(nil, `The surge scoured the lighthouse! The lamp lost {S.Scour} fuel.`, "Alarm")
			end
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not s.hit[p] and char and root and root:IsA("BasePart") and hum and hum.Health > 0 and (root.Position - f):Dot(s.dir) < 0 then
					s.hit[p] = true
					local covered = sheltered(char, root)
					if not covered then
						hum:TakeDamage(S.HitDamage)
					end
					Remotes.event("StormEvent"):FireClient(p, "SurgeHit", { dir = s.dir, sheltered = covered })
				end
			end
		end
	end
	-- the beaches flay you
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and hum.FloorMaterial == Enum.Material.Sand then
			hum:TakeDamage(S.BeachDamage * dt / 0.5)
			local now2 = os.clock()
			if not warned[p] or now2 - warned[p] > 20 then
				warned[p] = now2
				Remotes.notify(p, "The blowing sand is flaying you! Get off the beach!", "Alarm")
			end
		end
	end
end

function SandstormSurge.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(surges)
	local a = rng:NextNumber(0, math.pi * 2)
	windDir = Vector3.new(math.cos(a), 0, math.sin(a))
	Workspace:SetAttribute("WindDir", windDir)
	task.spawn(function()
		local last = os.clock()
		while active and generation == mine do
			task.wait(0.5)
			local t = os.clock()
			step(t - last)
			last = t
		end
	end)
	task.wait(S.FirstAfter)
	while active and generation == mine do
		newSurge()
		task.wait(rng:NextNumber(S.Every.Min, S.Every.Max))
	end
end

function SandstormSurge.Stop()
	active = false
	table.clear(surges)
	table.clear(warned)
	Workspace:SetAttribute("WindDir", nil)
end

return SandstormSurge
