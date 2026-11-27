--!strict
-- Waterspout (Catastrophic): funnels drop out of the cloud base far out at sea and come
-- snaking in across the water, then right over the island, tearing through the trees. Up to three
-- at once (StormEvent "Spouts", every half second: id, position, heading). Get caught in the open
-- beside one and it snatches you up (StormEvent "SpoutGrab" to that player: the client whirls you
-- up the column and flings you out, since players own their physics). If one notices someone
-- close by it can swing round and come for them. Passing over the lighthouse rattles the lamp.
-- But they've sucked up whole schools of fish, and once over land they rain them down.

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
	Every = NumberRange.new(11, 17),
	FirstAfter = 4,
	MaxSpouts = 3,
	SpawnOut = 950, -- from the island centre
	Speed = NumberRange.new(15, 22),
	Wander = 0.5, -- radians of weave
	Life = 95, -- seconds, or once it's this far past the island
	GrabRadius = 16,
	GrabDamage = 15,
	DropDamage = 10, -- when it lets go
	GrabCooldown = 7,
	NoticeRange = 160, -- may swing round for someone this close
	NoticeChance = 0.45,
	TowerHit = 8, -- lamp fuel lost when one crosses the lighthouse
	FishEvery = 1.6, -- seconds, while over land
	FishPerSpout = 5,
}

type Spout = {
	id: number,
	pos: Vector3,
	heading: number,
	speed: number,
	born: number,
	phase: number,
	hitTower: boolean,
	noticed: boolean,
	fish: number,
	nextFish: number,
}

local Waterspout = {}

local active = false
local generation = 0
local rng = Random.new()
local spouts: { Spout } = {}
local nextId = 0
local grabbed: { [Player]: number } = {}

local function overLand(pos: Vector3): (boolean, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	local hit = Workspace:Raycast(Vector3.new(pos.X, 200, pos.Z), Vector3.new(0, -400, 0), params)
	if hit and hit.Material ~= Enum.Material.Water then
		return true, hit.Position
	end
	return false, nil
end

local function roofed(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) ~= nil
end

local function newSpout()
	local c = Config.World.IslandCenter
	local a = (Workspace:GetAttribute("DebugSpoutAngle") :: number?) or rng:NextNumber(0, math.pi * 2)
	local start = Vector3.new(c.X + math.cos(a) * S.SpawnOut, 0, c.Z + math.sin(a) * S.SpawnOut)
	-- aim somewhere across the island
	local aim = Vector3.new(c.X + rng:NextNumber(-260, 260), 0, c.Z + rng:NextNumber(-260, 260))
	local d = aim - start
	nextId += 1
	table.insert(spouts, {
		id = nextId,
		pos = start,
		heading = math.atan2(d.Z, d.X),
		speed = rng:NextNumber(S.Speed.Min, S.Speed.Max),
		born = os.clock(),
		phase = rng:NextNumber(0, 10),
		hitTower = false,
		noticed = false,
		fish = 0,
		nextFish = 0,
	})
end

local function grab(p: Player, s: Spout)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	grabbed[p] = os.clock()
	hum:TakeDamage(S.GrabDamage)
	Remotes.event("StormEvent"):FireClient(p, "SpoutGrab", { id = s.id })
	task.delay(2.4, function()
		if active and hum.Parent and hum.Health > 0 then
			hum:TakeDamage(S.DropDamage)
		end
	end)
end

local function step(dt: number)
	local c = Config.World.IslandCenter
	local island = Vector3.new(c.X, 0, c.Z)
	local tower = Config.World.TowerCenter
	for i = #spouts, 1, -1 do
		local s = spouts[i]
		local age = os.clock() - s.born
		-- weave as it goes
		local h = s.heading + math.sin(age * 0.35 + s.phase) * S.Wander
		s.pos += Vector3.new(math.cos(h), 0, math.sin(h)) * s.speed * dt
		local fromIsland = (s.pos - island).Magnitude
		if age > S.Life or (age > 20 and fromIsland > S.SpawnOut + 60) then
			table.remove(spouts, i)
			continue
		end
		-- it notices someone
		if not s.noticed then
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local off = Vector3.new(root.Position.X - s.pos.X, 0, root.Position.Z - s.pos.Z)
					if off.Magnitude < S.NoticeRange and off.Magnitude > S.GrabRadius * 2 then
						s.noticed = true
						if rng:NextNumber() < S.NoticeChance then
							s.heading = math.atan2(off.Z, off.X)
							s.speed *= 1.25
							Remotes.notify(p, "The waterspout has turned... it's coming for you!", "Alarm")
						end
						break
					end
				end
			end
		end
		-- snatching people up
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and hum and hum.Health > 0 and (not grabbed[p] or os.clock() - grabbed[p] > S.GrabCooldown) then
				local d = Vector3.new(root.Position.X - s.pos.X, 0, root.Position.Z - s.pos.Z).Magnitude
				if d < S.GrabRadius and root.Position.Y < 60 and not roofed(char :: Model, root) then
					grab(p, s)
				end
			end
		end
		-- across the lighthouse
		if not s.hitTower and Vector3.new(s.pos.X - tower.X, 0, s.pos.Z - tower.Z).Magnitude < 30 then
			s.hitTower = true
			LightService.DrainFuel(S.TowerHit)
			Remotes.event("StormEvent"):FireAllClients("SpoutTower", { at = s.pos })
			Remotes.notify(nil, "The waterspout tore across the lighthouse! The lamp is guttering!", "Alarm")
		end
		-- raining fish over land
		if s.fish < S.FishPerSpout and os.clock() >= s.nextFish then
			s.nextFish = os.clock() + S.FishEvery
			local land = overLand(s.pos)
			if land then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(18, 45)
				local ok, ground = overLand(s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				if ok and ground then
					local item = ResourceService.SpawnItem("Fish", ground + Vector3.new(0, 2, 0))
					if item then
						s.fish += 1
						Remotes.event("StormEvent"):FireAllClients("SpoutFish", { from = s.pos, to = ground })
					end
				end
			end
		end
	end
end

local function broadcast()
	local list = {}
	for _, s in spouts do
		table.insert(list, { id = s.id, x = s.pos.X, z = s.pos.Z, speed = s.speed })
	end
	Remotes.event("StormEvent"):FireAllClients("Spouts", { list = list, t = Workspace:GetServerTimeNow() })
end

function Waterspout.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(spouts)
	table.clear(grabbed)
	task.spawn(function()
		local nextSpout = os.clock() + S.FirstAfter
		local nextSend = 0
		while active and generation == mine do
			local dt = task.wait(0.1)
			if os.clock() >= nextSpout then
				nextSpout = os.clock() + rng:NextNumber(S.Every.Min, S.Every.Max)
				if #spouts < S.MaxSpouts then
					newSpout()
					Remotes.notify(nil, "A WATERSPOUT has dropped out of the clouds!", "Alarm")
				end
			end
			step(dt)
			if os.clock() >= nextSend then
				nextSend = os.clock() + 0.5
				broadcast()
			end
		end
	end)
end

function Waterspout.Stop()
	active = false
	table.clear(spouts)
	broadcast()
end

return Waterspout
