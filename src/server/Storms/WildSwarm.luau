--!strict
-- Wild Swarm (Moderate): the forest animals are frenzied. The snakes, spiders and bats in the
-- canopy drop on anyone under the trees far more often and from further away
-- (TreeAnimalService.SetFrenzy). And every so often a huge swarm of bats boils up out of the
-- pines and streams across the island (StormEvent "BatSwarm": where it starts, which way it
-- flies, how fast): anyone caught in the open as it passes is mobbed (StormEvent "BatsHit" to
-- that player), and if it pours over the lighthouse the bats mob the lamp and smother it
-- (StormEvent "BatsLamp").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local TreeAnimalService = require(Server:WaitForChild("TreeAnimalService"))

local S = {
	Every = NumberRange.new(16, 24),
	FirstAfter = 6,
	Speed = NumberRange.new(48, 60),
	Travel = 900, -- studs a swarm flies before it scatters
	Radius = 34, -- how close to the heart of the swarm counts as caught in it
	Swing = math.rad(40), -- how far off a beeline for the lighthouse a swarm can fly
	HitDamage = 10,
	LampDrain = 4,
}

local WildSwarm = {}

type Swarm = { start: Vector3, dir: Vector3, speed: number, t0: number, hit: { [Player]: boolean }, lamp: boolean }

local active = false
local generation = 0
local swarms: { Swarm } = {}
local rng = Random.new()

local function sheltered(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) ~= nil
end

local function randomTree(): Model?
	local map = Workspace:FindFirstChild("Map")
	local grove = map and map:FindFirstChild("PineGrove")
	if not grove then
		return nil
	end
	local trees = {}
	for _, t in grove:GetChildren() do
		local trunk = t:FindFirstChild("Trunk")
		if t:IsA("Model") and trunk and trunk:IsA("BasePart") and trunk.Transparency < 0.5 then
			table.insert(trees, t)
		end
	end
	return if #trees > 0 then trees[rng:NextInteger(1, #trees)] else nil
end

local function newSwarm()
	local tree = randomTree()
	if not tree then
		return
	end
	local from = tree:GetPivot().Position
	local trunk = tree:FindFirstChild("Trunk") :: BasePart
	from = Vector3.new(from.X, trunk.Position.Y + trunk.Size.Y / 2 + 4, from.Z)
	local toLight = LightService.GetCenter() - from
	toLight = Vector3.new(toLight.X, 0, toLight.Z)
	local a = (if toLight.Magnitude > 1 then math.atan2(toLight.Z, toLight.X) else rng:NextNumber(0, math.pi * 2)) + rng:NextNumber(-S.Swing, S.Swing)
	local s: Swarm = {
		start = from,
		dir = Vector3.new(math.cos(a), 0, math.sin(a)),
		speed = rng:NextNumber(S.Speed.Min, S.Speed.Max),
		t0 = Workspace:GetServerTimeNow(),
		hit = {},
		lamp = false,
	}
	table.insert(swarms, s)
	Remotes.event("StormEvent"):FireAllClients("BatSwarm", { start = s.start, dir = s.dir, speed = s.speed, t0 = s.t0 })
	Remotes.notify(nil, "A swarm of bats is pouring out of the trees!", "Alarm")
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for i = #swarms, 1, -1 do
		local s = swarms[i]
		local travelled = s.speed * (now - s.t0)
		if travelled > S.Travel then
			table.remove(swarms, i)
		else
			local heart = s.start + s.dir * travelled
			local flat = Vector3.new(heart.X, 0, heart.Z)
			local light = LightService.GetCenter()
			if not s.lamp and (Vector3.new(light.X, 0, light.Z) - flat).Magnitude < S.Radius + 10 then
				s.lamp = true
				LightService.DrainFuel(S.LampDrain)
				Remotes.event("StormEvent"):FireAllClients("BatsLamp", nil)
				Remotes.notify(nil, `The bats are mobbing the lamp! It lost {S.LampDrain} fuel.`, "Alarm")
			end
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not s.hit[p] and char and root and root:IsA("BasePart") and hum and hum.Health > 0 then
					local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - flat).Magnitude
					if d < S.Radius and not sheltered(char, root) then
						s.hit[p] = true
						hum:TakeDamage(S.HitDamage)
						Remotes.event("StormEvent"):FireClient(p, "BatsHit", { dir = s.dir })
					end
				end
			end
		end
	end
end

function WildSwarm.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(swarms)
	TreeAnimalService.SetFrenzy(true)
	task.spawn(function()
		while active and generation == mine do
			step()
			task.wait(0.2)
		end
	end)
	task.wait(S.FirstAfter)
	while active and generation == mine do
		newSwarm()
		task.wait(rng:NextNumber(S.Every.Min, S.Every.Max))
	end
end

function WildSwarm.Stop()
	active = false
	table.clear(swarms)
	TreeAnimalService.SetFrenzy(false)
end

return WildSwarm
