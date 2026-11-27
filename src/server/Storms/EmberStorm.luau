--!strict
-- Ember Storm (Severe): dry lightning and a hot wind (Workspace attribute "WindDir"). Lightning
-- sets pines alight (StormEvent "TreeStrike"; burning trees carry the attribute "Burning"), and
-- fire spreads from tree to tree, mostly downwind. Standing near a burning tree scorches you.
-- Anyone can beat a fire out (a hold prompt on the burning tree) before it spreads; left alone, a
-- tree burns down to nothing (it regrows later, like a felled tree) and drops a little charcoal
-- wood. Sparks blown off the fires (StormEvent "Embers") land as spot fires on the ground around
-- players, which burn for a few seconds and scorch anyone standing in them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))

local S = {
	StrikeEvery = NumberRange.new(9, 15),
	FirstStrike = 5,
	MaxBurning = 14,
	SpreadEvery = 3.5,
	SpreadChance = 0.35,
	SpreadRange = 32,
	BurnSeconds = 28,
	HeatRadius = 11,
	HeatDamage = 4, -- per second
	BeatHold = 2.5,
	SpotEvery = NumberRange.new(5, 9),
	SpotRadius = 6,
	SpotSeconds = 7,
	SpotDamage = 5, -- per second standing in one
	SafeFromLight = 30, -- no strikes this close to the lighthouse
}

local EmberStorm = {}

local active = false
local generation = 0
local rng = Random.new()
local windDir = Vector3.new(1, 0, 0)
type Fire = { tree: Model, since: number, prompt: ProximityPrompt }
local fires: { [Model]: Fire } = {}
type Spot = { at: Vector3, untilT: number }
local spots: { Spot } = {}

local function grove(): Instance?
	local map = Workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("PineGrove")
end

local function standing(tree: Instance): boolean
	local trunk = tree:FindFirstChild("Trunk")
	return tree:IsA("Model") and trunk ~= nil and trunk:IsA("BasePart") and trunk.Transparency < 0.5 and tree:GetAttribute("Felled") ~= true
end

local function count(): number
	local n = 0
	for _ in fires do
		n += 1
	end
	return n
end

local function extinguish(tree: Model)
	local f = fires[tree]
	if not f then
		return
	end
	fires[tree] = nil
	tree:SetAttribute("Burning", nil)
	f.prompt:Destroy()
end

local function ignite(tree: Model)
	if fires[tree] or not standing(tree) or count() >= S.MaxBurning then
		return
	end
	local trunk = tree:FindFirstChild("Trunk") :: BasePart
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "BeatOut"
	pr.ActionText = "Beat out the fire"
	pr.ObjectText = "Burning tree"
	pr.HoldDuration = S.BeatHold
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = trunk
	pr.Triggered:Connect(function(player: Player)
		if fires[tree] then
			extinguish(tree)
			Remotes.event("StormEvent"):FireAllClients("FireOut", { tree = tree })
			Remotes.notify(player, "You beat the fire out!", "Good")
		end
	end)
	fires[tree] = { tree = tree, since = os.clock(), prompt = pr }
	tree:SetAttribute("Burning", true)
end

local function strike()
	local g = grove()
	if not g then
		return
	end
	local light = LightService.GetCenter()
	-- favour trees near players, so the fire is something they have to deal with
	local candidates = {}
	for _, t in g:GetChildren() do
		if standing(t) and not fires[t :: Model] then
			local p = (t :: Model):GetPivot().Position
			if Vector3.new(p.X - light.X, 0, p.Z - light.Z).Magnitude > S.SafeFromLight then
				local w = 1
				for _, pl in Players:GetPlayers() do
					local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and (root.Position - p).Magnitude < 120 then
						w = 6
					end
				end
				for _ = 1, w do
					table.insert(candidates, t)
				end
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local tree = candidates[rng:NextInteger(1, #candidates)] :: Model
	ignite(tree)
	Remotes.event("StormEvent"):FireAllClients("TreeStrike", { tree = tree, at = tree:GetPivot().Position })
end

local function spread()
	local g = grove()
	if not g then
		return
	end
	local burning = {}
	for tree in fires do
		table.insert(burning, tree)
	end
	for _, tree in burning do
		if rng:NextNumber() < S.SpreadChance then
			local p = tree:GetPivot().Position
			local best: Model?, bestScore = nil, -math.huge
			for _, t in g:GetChildren() do
				if t ~= tree and standing(t) and not fires[t :: Model] then
					local q = (t :: Model):GetPivot().Position
					local off = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
					local d = off.Magnitude
					if d < S.SpreadRange and d > 0.1 then
						-- downwind and close is likeliest
						local score = off.Unit:Dot(windDir) * 1.5 - d / S.SpreadRange + rng:NextNumber(0, 0.8)
						if score > bestScore then
							best, bestScore = t :: Model, score
						end
					end
				end
			end
			if best then
				ignite(best)
			end
		end
	end
end

local function burnDown()
	for tree, f in fires do
		if os.clock() - f.since > S.BurnSeconds then
			local at = tree:GetPivot().Position
			ResourceService.FellTree(tree) -- (felled first, so clients see it go rather than recover)
			extinguish(tree)
			Remotes.event("StormEvent"):FireAllClients("BurntDown", { at = at })
			ResourceService.SpawnItem("Wood", at + Vector3.new(rng:NextNumber(-3, 3), 2, rng:NextNumber(-3, 3)))
		end
	end
end

local function spotFire()
	-- sparks from a burning tree land near a player out in the open
	if count() == 0 then
		return
	end
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not LightService.IsPointLit(root.Position) and rng:NextNumber() < 0.6 then
			local a = rng:NextNumber(0, math.pi * 2)
			local at = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, 14)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { Workspace.Terrain }
			local hit = Workspace:Raycast(at + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
			if hit and hit.Material ~= Enum.Material.Water then
				table.insert(spots, { at = hit.Position, untilT = os.clock() + S.SpotSeconds })
				Remotes.event("StormEvent"):FireAllClients("Embers", { at = hit.Position, seconds = S.SpotSeconds, radius = S.SpotRadius })
			end
		end
	end
end

local function heat(dt: number)
	local now = os.clock()
	for i = #spots, 1, -1 do
		if now > spots[i].untilT then
			table.remove(spots, i)
		end
	end
	local trunks = {}
	for tree in fires do
		table.insert(trunks, tree:GetPivot().Position)
	end
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and hum and hum.Health > 0 then
			local hot = false
			for _, t in trunks do
				if Vector3.new(root.Position.X - t.X, 0, root.Position.Z - t.Z).Magnitude < S.HeatRadius then
					hot = true
					hum:TakeDamage(S.HeatDamage * dt)
					break
				end
			end
			for _, s in spots do
				if (root.Position - s.at).Magnitude < S.SpotRadius + 2 then
					hot = true
					hum:TakeDamage(S.SpotDamage * dt)
					break
				end
			end
			p:SetAttribute("Scorched", if hot then true else nil)
		end
	end
end

function EmberStorm.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(spots)
	local a = rng:NextNumber(0, math.pi * 2)
	windDir = Vector3.new(math.cos(a), 0, math.sin(a))
	Workspace:SetAttribute("WindDir", windDir)
	task.spawn(function()
		local lastSpread = os.clock()
		local nextSpot = os.clock() + 8
		while active and generation == mine do
			local dt = task.wait(0.25)
			heat(dt)
			if os.clock() - lastSpread > S.SpreadEvery then
				lastSpread = os.clock()
				spread()
				burnDown()
			end
			if os.clock() >= nextSpot then
				nextSpot = os.clock() + rng:NextNumber(S.SpotEvery.Min, S.SpotEvery.Max)
				spotFire()
			end
		end
	end)
	task.wait(S.FirstStrike)
	while active and generation == mine do
		strike()
		task.wait(rng:NextNumber(S.StrikeEvery.Min, S.StrikeEvery.Max))
	end
end

function EmberStorm.Stop()
	active = false
	local all = {}
	for tree in fires do
		table.insert(all, tree)
	end
	for _, tree in all do
		extinguish(tree)
	end
	table.clear(spots)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Scorched", nil)
	end
	Workspace:SetAttribute("WindDir", nil)
end

return EmberStorm
