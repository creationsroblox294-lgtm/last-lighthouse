--!strict
-- Bountiful Tide (Blessed): glowing waves keep rolling onto the beaches all storm long.
-- Each wave is announced to clients (StormEvent "TideWave": where it lands and which way it
-- comes from), crashes 2 s later, shoves anyone standing in the surf, and leaves loot on the
-- sand: oil, scrap and wood to carry, and sometimes a treasure chest (Blender model) that
-- fills the lighthouse storage when opened. Waves favour beaches near players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local ResourceService = require(Server:WaitForChild("ResourceService"))

local S = {
	EverySeconds = NumberRange.new(2.5, 4.5),
	FollowUpChance = 0.35, -- a second wave rides in right behind the first
	RollSeconds = 2, -- wave appears out at sea -> crashes on the beach
	NearPlayerChance = 0.7, -- waves pick the beach closest to a random player
	ItemsPerWave = NumberRange.new(2, 4),
	ItemKinds = { "Oil", "Oil", "Scrap", "Scrap", "Wood" },
	ChestChance = 0.35,
	MaxChests = 4,
	ChestLoot = { { Oil = 3, Scrap = 2 }, { Scrap = 4, Wood = 4 }, { Oil = 2, Wood = 3, Scrap = 2 }, { Oil = 5 } },
	SurfPush = 45, -- studs/s shove for players caught by the wave
	ChestLingerSeconds = 60,
}

local BountifulTide = {}

type Shore = { pos: Vector3, out: Vector3 } -- a beach point and the direction out to sea

local active = false
local generation = 0
local shores: { Shore } = {}
local chests: { Model } = {}
local folder: Folder? = nil
local rng = Random.new()

local wet = RaycastParams.new()
wet.FilterType = Enum.RaycastFilterType.Include
wet.IgnoreWater = false

local function surface(x: number, z: number): RaycastResult?
	wet.FilterDescendantsInstances = { Workspace.Terrain }
	return Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), wet)
end

-- Walk out from the island centre in many directions; the last land point before the sea is
-- a beach.
local function findShores()
	if #shores > 0 then
		return
	end
	local c = Config.World.IslandCenter
	for deg = 0, 357, 3 do
		local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
		local lastLand: Vector3? = nil
		for r = 150, 1500, 8 do
			local p = c + dir * r
			local hit = surface(p.X, p.Z)
			if not hit then
				break
			end
			if hit.Material == Enum.Material.Water then
				if lastLand then
					table.insert(shores, { pos = lastLand, out = dir })
				end
				break
			end
			lastLand = hit.Position
		end
	end
end

local function pickShore(): Shore?
	if #shores == 0 then
		return nil
	end
	local players = Players:GetPlayers()
	if #players > 0 and rng:NextNumber() < S.NearPlayerChance then
		local p = players[rng:NextInteger(1, #players)]
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local best, bestD = shores[1], math.huge
			for _, s in shores do
				local d = (s.pos - root.Position).Magnitude + rng:NextNumber(0, 40)
				if d < bestD then
					best, bestD = s, d
				end
			end
			return best
		end
	end
	return shores[rng:NextInteger(1, #shores)]
end

local function chestTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local m = assets and assets:FindFirstChild("TreasureChest")
	return if m and m:IsA("Model") then m else nil
end

local function removeChest(m: Model)
	local i = table.find(chests, m)
	if i then
		table.remove(chests, i)
	end
	m:Destroy()
end

local function spawnChest(pos: Vector3, facing: Vector3)
	local template = chestTemplate()
	if not template or not folder then
		return
	end
	if #chests >= S.MaxChests then
		removeChest(chests[1])
	end
	local m = template:Clone()
	local hit = surface(pos.X, pos.Z)
	local groundY = if hit then hit.Position.Y else pos.Y
	-- tilted a little, half sunk in the wet sand, facing inland
	local look = CFrame.lookAt(Vector3.new(pos.X, groundY, pos.Z), Vector3.new(pos.X, groundY, pos.Z) - facing)
	m:PivotTo(look * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.12, 0.12)) + Vector3.new(0, -0.15, 0))
	local loot = S.ChestLoot[rng:NextInteger(1, #S.ChestLoot)]
	local primary = m:FindFirstChild("Wood") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open treasure chest"
		prompt.ObjectText = "Treasure chest"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = primary
		prompt.Triggered:Connect(function(player: Player)
			if not m.Parent then
				return
			end
			local where = m:GetPivot().Position
			removeChest(m)
			local parts = {}
			for kind, n in loot do
				ResourceService.AddStorage(kind, n)
				table.insert(parts, `{n} {string.lower(kind)}`)
			end
			Remotes.event("StormEvent"):FireAllClients("ChestOpened", where)
			Remotes.notify(nil, `{player.DisplayName} opened a treasure chest: {table.concat(parts, ", ")} added to storage!`, "Good")
		end)
	end
	m.Parent = folder
	table.insert(chests, m)
end

local function crash(shore: Shore)
	-- shove anyone in the surf inland, like a big wave would
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local flat = Vector3.new(root.Position.X - shore.pos.X, 0, root.Position.Z - shore.pos.Z)
			if flat.Magnitude < 28 then
				root.AssemblyLinearVelocity += -shore.out * S.SurfPush + Vector3.new(0, 18, 0)
			end
		end
	end
	-- loot scattered along the tide line, a little inland
	local side = Vector3.new(-shore.out.Z, 0, shore.out.X)
	for _ = 1, rng:NextInteger(S.ItemsPerWave.Min, S.ItemsPerWave.Max) do
		local at = shore.pos - shore.out * rng:NextNumber(4, 14) + side * rng:NextNumber(-18, 18)
		ResourceService.SpawnItem(S.ItemKinds[rng:NextInteger(1, #S.ItemKinds)], at)
	end
	if rng:NextNumber() < S.ChestChance then
		spawnChest(shore.pos - shore.out * rng:NextNumber(6, 10) + side * rng:NextNumber(-8, 8), shore.out)
	end
end

function BountifulTide.Start()
	active = true
	generation += 1
	local mine = generation
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "TreasureChests"
		f.Parent = Workspace
		folder = f
	end
	findShores()
	local event = Remotes.event("StormEvent")
	while active and generation == mine do
		local shore = pickShore()
		if shore then
			event:FireAllClients("TideWave", { at = shore.pos, out = shore.out, seconds = S.RollSeconds })
			task.delay(S.RollSeconds, function()
				crash(shore)
			end)
			if rng:NextNumber() < S.FollowUpChance then
				task.delay(1.4, function()
					if active and generation == mine then
						event:FireAllClients("TideWave", { at = shore.pos, out = shore.out, seconds = S.RollSeconds })
						task.delay(S.RollSeconds, function()
							crash(shore)
						end)
					end
				end)
			end
		end
		task.wait(rng:NextNumber(S.EverySeconds.Min, S.EverySeconds.Max))
	end
end

function BountifulTide.Stop()
	active = false
	local left = table.clone(chests)
	task.delay(S.ChestLingerSeconds, function()
		for _, m in left do
			if m.Parent then
				removeChest(m)
			end
		end
	end)
end

return BountifulTide
