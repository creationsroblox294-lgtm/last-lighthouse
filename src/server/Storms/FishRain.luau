--!strict
-- Fish Rain (Blessed): a waterspout out at sea sucks up whole schools and drops them on the
-- island. Every second or two a fish falls near a player (StormEvent "FishDrop": a marker on
-- the ground, then the fish tumbles out of the sky and lands 1.6 s later) and becomes a real
-- Fish item to carry home. Sometimes a whole school comes down at once, and about one fish in
-- seven is golden: take it for 3 fish in storage and some lamp fuel.

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
	EverySeconds = NumberRange.new(0.9, 1.8),
	FallSeconds = 1.6,
	NearRadius = NumberRange.new(8, 45),
	SchoolChance = 0.2, -- a whole school lands at once
	SchoolSize = NumberRange.new(4, 6),
	GoldenChance = 0.1,
	GoldenFish = 3, -- added to storage
	GoldenFuel = 6,
	MaxGolden = 6,
	GoldenLingerSeconds = 45,
	SpoutDistance = 760, -- from the island centre, out at sea
}

local FishRain = {}

local active = false
local generation = 0
local golden: { Model } = {}
local folder: Folder? = nil
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

local function removeGolden(m: Model)
	local i = table.find(golden, m)
	if i then
		table.remove(golden, i)
	end
	m:Destroy()
end

local function spawnGolden(at: Vector3)
	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local template = assets and assets:FindFirstChild("Fish")
	if not (template and template:IsA("Model")) or not folder then
		return
	end
	if #golden >= S.MaxGolden then
		removeGolden(golden[1])
	end
	local m = template:Clone()
	m.Name = "GoldenFish"
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name ~= "Eye" then
				p.Color = if p.Name == "Body" then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(255, 150, 40)
				p.Material = Enum.Material.Neon
			end
			p.Anchored = true
			p.CanCollide = false
		end
	end
	m:ScaleTo(m:GetScale() * 1.4)
	m:PivotTo(CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(90)))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 80)
	light.Range = 14
	light.Brightness = 3
	local body = m:FindFirstChild("Body") or m:FindFirstChildWhichIsA("BasePart")
	if body then
		light.Parent = body
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take golden fish"
		prompt.ObjectText = "Golden fish"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player: Player)
			if not m.Parent then
				return
			end
			local pos = m:GetPivot().Position
			removeGolden(m)
			ResourceService.AddStorage("Fish", S.GoldenFish)
			LightService.AddFuel(S.GoldenFuel)
			Remotes.event("StormEvent"):FireAllClients("GoldenTaken", pos)
			Remotes.notify(player, `Golden fish! +{S.GoldenFish} fish in storage, +{S.GoldenFuel} lamp fuel`, "Good")
		end)
	end
	m.Parent = folder
	table.insert(golden, m)
end

local function drop(target: Vector3, isGolden: boolean)
	Remotes.event("StormEvent"):FireAllClients("FishDrop", {
		at = target,
		seconds = S.FallSeconds,
		golden = isGolden,
		seed = rng:NextInteger(1, 1e6),
	})
	task.delay(S.FallSeconds, function()
		if isGolden then
			spawnGolden(target)
		else
			ResourceService.SpawnItem("Fish", target)
		end
	end)
end

local function nearPlayer(): Vector3?
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.NearRadius.Min, S.NearRadius.Max)
		local at = landAt(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
		if at then
			return at
		end
	end
	return nil
end

function FishRain.Start()
	active = true
	generation += 1
	local mine = generation
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "GoldenFish"
		f.Parent = Workspace
		folder = f
	end
	-- the waterspout stands somewhere out at sea for the whole storm
	local a = rng:NextNumber(0, math.pi * 2)
	local c = Config.World.IslandCenter
	Workspace:SetAttribute("FishRainSpout", Vector3.new(c.X + math.cos(a) * S.SpoutDistance, 0, c.Z + math.sin(a) * S.SpoutDistance))
	while active and generation == mine do
		local at = nearPlayer()
		if at then
			if rng:NextNumber() < S.SchoolChance then
				for i = 1, rng:NextInteger(S.SchoolSize.Min, S.SchoolSize.Max) do
					local spot = landAt(at.X + rng:NextNumber(-7, 7), at.Z + rng:NextNumber(-7, 7)) or at
					task.delay(i * 0.12, drop, spot, rng:NextNumber() < S.GoldenChance)
				end
			else
				drop(at, rng:NextNumber() < S.GoldenChance)
			end
		end
		task.wait(rng:NextNumber(S.EverySeconds.Min, S.EverySeconds.Max))
	end
end

function FishRain.Stop()
	active = false
	Workspace:SetAttribute("FishRainSpout", nil)
	local left = table.clone(golden)
	task.delay(S.GoldenLingerSeconds, function()
		for _, m in left do
			if m.Parent then
				removeGolden(m)
			end
		end
	end)
end

return FishRain
