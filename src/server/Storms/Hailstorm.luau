--!strict
-- Hailstorm (Mild): hard, cold hail. Anyone out in the open takes a little damage every couple
-- of seconds (anything overhead is shelter). Every so often a giant hailstone comes down near
-- a player (StormEvent "GiantHail": its shadow grows on the ground for a few seconds first):
-- it hurts anyone it lands on, and leaves a chunk of ice that slowly melts away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = {
	StingEvery = 1.5,
	StingDamage = 2,
	GiantEvery = NumberRange.new(7, 12),
	GiantFall = 2.8, -- shadow warning before it lands
	GiantRadius = 9,
	GiantDamage = 28,
	NearRadius = NumberRange.new(6, 35),
	ChunkMeltSeconds = 18,
}

local Hailstorm = {}

local active = false
local generation = 0
local rng = Random.new()
local folder: Folder? = nil

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

local function exposed(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { char }
	if folder then
		table.insert(skip, folder)
	end
	params.FilterDescendantsInstances = skip
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
end

local function sting()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and root and root:IsA("BasePart") and hum and hum.Health > 0 and exposed(char, root) then
			hum:TakeDamage(S.StingDamage)
		end
	end
end

local function chunk(at: Vector3)
	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local template = assets and assets:FindFirstChild("Hailstone")
	if not (template and template:IsA("Model")) or not folder then
		return
	end
	local m = template:Clone()
	m:PivotTo(CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = true
		end
	end
	m.Parent = folder
	-- it melts away
	task.spawn(function()
		local steps = 30
		local start = m:GetScale()
		for i = 1, steps do
			task.wait(S.ChunkMeltSeconds / steps)
			if not m.Parent then
				return
			end
			m:ScaleTo(math.max(0.05, start * (1 - i / steps)))
		end
		m:Destroy()
	end)
end

local function giant()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.NearRadius.Min, S.NearRadius.Max)
		local at = landAt(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
		if at then
			Remotes.event("StormEvent"):FireAllClients("GiantHail", { at = at, seconds = S.GiantFall, radius = S.GiantRadius })
			task.delay(S.GiantFall, function()
				for _, pl in Players:GetPlayers() do
					local char = pl.Character
					local rr = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if rr and rr:IsA("BasePart") and hum and hum.Health > 0 then
						local flat = Vector3.new(rr.Position.X - at.X, 0, rr.Position.Z - at.Z)
						if flat.Magnitude < S.GiantRadius and math.abs(rr.Position.Y - at.Y) < 14 then
							hum:TakeDamage(S.GiantDamage)
						end
					end
				end
				chunk(at)
			end)
			return
		end
	end
end

function Hailstorm.Start()
	active = true
	generation += 1
	local mine = generation
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "HailChunks"
		f.Parent = Workspace
		folder = f
	end
	task.spawn(function()
		while active and generation == mine do
			task.wait(S.StingEvery)
			if active and generation == mine then
				sting()
			end
		end
	end)
	while active and generation == mine do
		task.wait(rng:NextNumber(S.GiantEvery.Min, S.GiantEvery.Max))
		if active and generation == mine then
			giant()
		end
	end
end

function Hailstorm.Stop()
	active = false
end

return Hailstorm
