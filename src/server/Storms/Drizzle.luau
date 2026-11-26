--!strict
-- Drizzle (Mild): a soft, steady drizzle. Puddles slowly spread across the island around the
-- players (glassy pools in Workspace.DrizzlePuddles that clients dress with ripples). Every
-- so often one of them starts to stir: it bubbles and glows for a few seconds (attribute
-- "Stirring") and then a Fog Crawler hauls itself up out of the water.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	PuddleEvery = NumberRange.new(2.5, 4.5),
	MaxPuddles = 16,
	PuddleRadius = NumberRange.new(12, 70), -- around a random player
	PuddleSize = NumberRange.new(7, 15),
	StirEvery = NumberRange.new(7, 13),
	StirSeconds = 2.6, -- bubbling warning before something climbs out
	StirRange = 80, -- only puddles this close to a player stir
	LingerSeconds = 20, -- puddles dry up a while after the storm
}

local Drizzle = {}

local active = false
local generation = 0
local puddles: { BasePart } = {}
local folder: Folder? = nil
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function landHit(x: number, z: number): RaycastResult?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit
	end
	return nil
end

local function randomPlayerRoot(): BasePart?
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function addPuddle()
	if not folder then
		return
	end
	local root = randomPlayerRoot()
	if not root then
		return
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.PuddleRadius.Min, S.PuddleRadius.Max)
		local hit = landHit(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
		-- only on fairly flat ground
		if hit and hit.Normal.Y > 0.9 then
			if #puddles >= S.MaxPuddles then
				local old = table.remove(puddles, 1)
				if old then
					old:Destroy()
				end
			end
			local size = rng:NextNumber(S.PuddleSize.Min, S.PuddleSize.Max)
			local p = Instance.new("Part")
			p.Name = "Puddle"
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(0.12, 0.5, 0.5)
			p.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(30, 42, 55)
			p.Transparency = 0.12
			p.Reflectance = 0.25
			p:SetAttribute("TargetSize", size)
			p.Parent = folder
			table.insert(puddles, p)
			return
		end
	end
end

local function stir()
	local candidates = {}
	for _, p in puddles do
		if p.Parent and p:GetAttribute("Stirring") ~= true then
			for _, pl in Players:GetPlayers() do
				local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and (root.Position - p.Position).Magnitude < S.StirRange then
					table.insert(candidates, p)
					break
				end
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local p = candidates[rng:NextInteger(1, #candidates)]
	p:SetAttribute("Stirring", true)
	task.delay(S.StirSeconds, function()
		if not p.Parent then
			return
		end
		p:SetAttribute("Stirring", false)
		if EnemyService.Spawn("FogCrawler", p.Position) then
			Remotes.event("StormEvent"):FireAllClients("PuddleBurst", p.Position)
		end
	end)
end

function Drizzle.Start()
	active = true
	generation += 1
	local mine = generation
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "DrizzlePuddles"
		f.Parent = Workspace
		folder = f
	end
	task.spawn(function()
		while active and generation == mine do
			task.wait(rng:NextNumber(S.StirEvery.Min, S.StirEvery.Max))
			if active and generation == mine then
				stir()
			end
		end
	end)
	while active and generation == mine do
		addPuddle()
		task.wait(rng:NextNumber(S.PuddleEvery.Min, S.PuddleEvery.Max))
	end
end

function Drizzle.Stop()
	active = false
	local mine = generation
	task.delay(S.LingerSeconds, function()
		if active or generation ~= mine then
			return
		end
		for _, p in puddles do
			p:Destroy()
		end
		table.clear(puddles)
	end)
end

return Drizzle
