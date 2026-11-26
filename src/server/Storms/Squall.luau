--!strict
-- Squall (Mild): rain comes in bands. Every so often a wall of heavy rain forms out at sea and
-- sweeps right across the island (StormEvent "SquallBand": where it starts, which way it goes,
-- how fast and how thick). Inside the band it pours. When it rolls over the lighthouse it
-- douses the lamp, and creatures ride in under it: anyone the band catches has a Fog Crawler
-- come out of the rain behind them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	Every = NumberRange.new(12, 18),
	Reach = 750, -- bands start this far upwind of the island centre and travel twice as far
	Speed = NumberRange.new(28, 38),
	Thickness = NumberRange.new(140, 200),
	Douse = 6, -- lamp fuel lost when a band rolls over the lighthouse
	CrawlerBehind = 22, -- studs behind a caught player that the crawler appears
}

local Squall = {}

type Band = { start: Vector3, dir: Vector3, speed: number, thick: number, t0: number, doused: boolean, caught: { [Player]: boolean } }

local active = false
local generation = 0
local bands: { Band } = {}
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

-- how far `pos` is from the middle of the band, along the band's direction of travel
local function offset(b: Band, pos: Vector3, now: number): number
	local front = b.start + b.dir * b.speed * (now - b.t0)
	return (pos - front):Dot(b.dir)
end

local function newBand()
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local c = Config.World.IslandCenter
	local b: Band = {
		start = Vector3.new(c.X, 0, c.Z) - dir * S.Reach,
		dir = dir,
		speed = rng:NextNumber(S.Speed.Min, S.Speed.Max),
		thick = rng:NextNumber(S.Thickness.Min, S.Thickness.Max),
		t0 = Workspace:GetServerTimeNow(),
		doused = false,
		caught = {},
	}
	table.insert(bands, b)
	Remotes.event("StormEvent"):FireAllClients("SquallBand", { start = b.start, dir = b.dir, speed = b.speed, thick = b.thick, t0 = b.t0 })
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for i = #bands, 1, -1 do
		local b = bands[i]
		if b.speed * (now - b.t0) > S.Reach * 2 + b.thick then
			table.remove(bands, i)
		else
			if not b.doused and math.abs(offset(b, LightService.GetCenter(), now)) < b.thick / 2 then
				b.doused = true
				LightService.DrainFuel(S.Douse)
				Remotes.notify(nil, `The squall is pouring over the lighthouse! The lamp lost {S.Douse} fuel.`, "Alarm")
			end
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if not b.caught[p] and root and root:IsA("BasePart") and math.abs(offset(b, root.Position, now)) < b.thick / 2 then
					b.caught[p] = true
					-- something comes in with the rain, just behind you
					local behind = root.Position - b.dir * S.CrawlerBehind
					local at = landAt(behind.X, behind.Z)
					if at then
						EnemyService.Spawn("FogCrawler", at)
					end
				end
			end
		end
	end
end

function Squall.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(bands)
	task.spawn(function()
		while active and generation == mine do
			step()
			task.wait(0.25)
		end
	end)
	task.wait(2)
	while active and generation == mine do
		newBand()
		task.wait(rng:NextNumber(S.Every.Min, S.Every.Max))
	end
end

function Squall.Stop()
	active = false
end

return Squall
