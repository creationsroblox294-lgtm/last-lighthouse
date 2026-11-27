--!strict
-- Red Tide (Severe): the sea has turned to blood. The water burns: anyone in it (swimming, or
-- wading in the shallows) takes heavy damage every second. The Drowned climb out of the red
-- water onto the beaches nearest the players. And every so often the tide surges (StormEvent
-- "RedSurge": a stretch of shore, which way is inland, how far it reaches): the red water
-- swells for a couple of seconds and then rolls up the beach, and anyone it catches is burned
-- and stained (player attribute "Stained": they keep burning for a few seconds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	WaterDamage = 7, -- per second in the red water
	SurgeEvery = NumberRange.new(14, 22),
	FirstSurge = 8,
	SurgeWarn = 2.2, -- seconds the water swells before it comes
	SurgeWidth = 80,
	SurgeReach = 55, -- how far up the beach it runs
	SurgeDamage = 14,
	StainSeconds = 5,
	StainDamage = 3, -- per second while stained
	DrownedEvery = NumberRange.new(12, 18),
	DrownedCount = 2,
	ShoreSearch = 200, -- how far from a player to look for the water's edge
}

local RedTide = {}

local active = false
local generation = 0
local rng = Random.new()
local warned: { [Player]: number } = {}

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function surfaceAt(x: number, z: number): RaycastResult?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	return Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), ground)
end

local function isWater(x: number, z: number): boolean
	local hit = surfaceAt(x, z)
	return hit == nil or hit.Material == Enum.Material.Water
end

-- the nearest water's edge to `from`: the last dry point before the sea, and which way is inland
local function shoreNear(from: Vector3): (Vector3?, Vector3?)
	local best: Vector3?, bestDir: Vector3?, bestD = nil, nil, math.huge
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local lastDry: Vector3? = nil
		for d = 0, S.ShoreSearch, 6 do
			local p = from + dir * d
			if isWater(p.X, p.Z) then
				if lastDry and d < bestD then
					local hit = surfaceAt(lastDry.X, lastDry.Z)
					best, bestDir, bestD = if hit then hit.Position else lastDry, -dir, d
				end
				break
			end
			lastDry = p
		end
	end
	return best, bestDir
end

local function randomShore(): (Vector3?, Vector3?)
	local c = Config.World.IslandCenter
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		-- walk in from the open sea until we hit land
		for d = 800, 100, -8 do
			local p = Vector3.new(c.X, 0, c.Z) + dir * d
			local hit = surfaceAt(p.X, p.Z)
			if hit and hit.Material ~= Enum.Material.Water then
				return hit.Position, -dir
			end
		end
	end
	return nil, nil
end

local function inRedWater(char: Model, root: BasePart, hum: Humanoid): boolean
	if hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial == Enum.Material.Water then
		return true
	end
	-- wading: feet below the surface with water under them
	if root.Position.Y < 3 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		params.IgnoreWater = false
		local hit = Workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
		return hit ~= nil and hit.Material == Enum.Material.Water
	end
	return false
end

local function surge()
	-- aim at a player out on the island if there is one, otherwise anywhere
	local candidates = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(candidates, root.Position)
		end
	end
	local at: Vector3?, inland: Vector3? = nil, nil
	if #candidates > 0 and rng:NextNumber() < 0.75 then
		at, inland = shoreNear(candidates[rng:NextInteger(1, #candidates)])
	end
	if not at then
		at, inland = randomShore()
	end
	if not (at and inland) then
		return
	end
	local shore: Vector3, dir: Vector3 = at, inland
	Remotes.event("StormEvent"):FireAllClients("RedSurge", { at = shore, dir = dir, width = S.SurgeWidth, reach = S.SurgeReach, warn = S.SurgeWarn })
	task.delay(S.SurgeWarn, function()
		if not active then
			return
		end
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and hum and hum.Health > 0 then
				local rel = root.Position - shore
				local up = rel:Dot(dir)
				local across = math.abs(rel:Dot(side))
				if up > -20 and up < S.SurgeReach and across < S.SurgeWidth / 2 and root.Position.Y < shore.Y + 14 then
					hum:TakeDamage(S.SurgeDamage)
					p:SetAttribute("Stained", Workspace:GetServerTimeNow() + S.StainSeconds)
					Remotes.notify(p, "The red tide caught you! It burns!", "Alarm")
				end
			end
		end
	end)
end

function RedTide.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(warned)
	-- the burning water, and the stain
	task.spawn(function()
		while active and generation == mine do
			task.wait(0.5)
			local now = Workspace:GetServerTimeNow()
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if char and root and root:IsA("BasePart") and hum and hum.Health > 0 then
					if inRedWater(char, root, hum) then
						hum:TakeDamage(S.WaterDamage * 0.5)
						p:SetAttribute("Stained", now + S.StainSeconds)
						if not warned[p] or os.clock() - warned[p] > 15 then
							warned[p] = os.clock()
							Remotes.notify(p, "The water is burning you! Get out of the sea!", "Alarm")
						end
					else
						local stained = p:GetAttribute("Stained") :: number?
						if stained then
							if now < stained then
								hum:TakeDamage(S.StainDamage * 0.5)
							else
								p:SetAttribute("Stained", nil)
							end
						end
					end
				end
			end
		end
	end)
	-- the Drowned climb out of the red water near the players
	task.spawn(function()
		task.wait(5)
		while active and generation == mine do
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local at = shoreNear(root.Position)
					if at then
						for _ = 1, S.DrownedCount do
							EnemyService.Spawn("Drowned", at + Vector3.new(rng:NextNumber(-12, 12), 1, rng:NextNumber(-12, 12)))
						end
						Remotes.event("StormEvent"):FireAllClients("DrownedRise", { at = at })
					end
				end
			end
			task.wait(rng:NextNumber(S.DrownedEvery.Min, S.DrownedEvery.Max))
		end
	end)
	task.wait(S.FirstSurge)
	while active and generation == mine do
		surge()
		task.wait(rng:NextNumber(S.SurgeEvery.Min, S.SurgeEvery.Max))
	end
end

function RedTide.Stop()
	active = false
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Stained", nil)
	end
end

return RedTide
