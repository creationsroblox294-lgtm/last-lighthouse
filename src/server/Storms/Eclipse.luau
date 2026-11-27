--!strict
-- Eclipse Storm (Catastrophic): in the middle of the day the moon slides over the sun. The
-- timeline goes out as Workspace attributes (server times): "EclipseContact" (it starts to
-- bite), "EclipseTotal" (totality: night falls in an instant), "EclipseTotalEnd" (the diamond
-- ring: a blinding flash) and "EclipseClear". In totality the lamp gutters (LightService radius
-- scale) and the dark fills with eyes and crawlers. Worst of all, everyone caught outside the
-- light grows a shadow: it rises behind them and follows exactly where they walked, a little
-- slower than walking pace (StormEvent "Shadows", 5 a second: who, where). Let it catch you and
-- it drains you. Step into the lamp light and it burns away (StormEvent "ShadowBurn"); the
-- diamond ring burns them all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	ContactAfter = 6, -- seconds into the storm
	TotalAt = 0.3, -- fractions of the storm
	TotalEnd = 0.8,
	ClearAt = 0.95,
	GutterScale = 0.72, -- lamp radius in totality
	ShadowSpeed = 13, -- walking is 16, carrying 12
	ShadowLag = 0.9, -- seconds behind your steps it aims for
	ShadowRise = 2.5, -- it rises where you were this long ago
	ShadowReach = 3.5,
	ShadowDrain = 12, -- per second while it has you
	ShadowAgain = 6, -- seconds before a burned shadow can rise again
	CrawlEvery = NumberRange.new(6, 9),
	CrawlDistance = 40,
}

type Shadow = { pos: Vector3, burnedAt: number? }

local Eclipse = {}

local active = false
local generation = 0
local rng = Random.new()
local trails: { [Player]: { { t: number, p: Vector3 } } } = {}
local shadows: { [Player]: Shadow } = {}
local burned: { [Player]: number } = {}

local function stormEndsAt(): number?
	for _, d in ReplicatedStorage:GetDescendants() do
		if d:IsA("Configuration") and d.Name == "Storm" then
			return d:GetAttribute("PhaseEndsAt") :: number?
		end
	end
	return nil
end

local function trailAt(p: Player, ago: number): Vector3?
	local trail = trails[p]
	if not trail or #trail == 0 then
		return nil
	end
	local want = os.clock() - ago
	for i = #trail, 1, -1 do
		if trail[i].t <= want then
			return trail[i].p
		end
	end
	return trail[1].p
end

local function burnAll()
	for p, _ in shadows do
		Remotes.event("StormEvent"):FireAllClients("ShadowBurn", { uid = p.UserId })
		burned[p] = os.clock()
	end
	table.clear(shadows)
end

function Eclipse.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(trails)
	table.clear(shadows)
	table.clear(burned)
	local now0 = Workspace:GetServerTimeNow()
	local ends = stormEndsAt() or (now0 + 180)
	local length = math.max(40, ends - now0)
	local contact = now0 + S.ContactAfter
	local total = now0 + math.max(S.ContactAfter + 10, length * S.TotalAt)
	local totalEnd = now0 + length * S.TotalEnd
	local clear = now0 + length * S.ClearAt
	Workspace:SetAttribute("EclipseContact", contact)
	Workspace:SetAttribute("EclipseTotal", total)
	Workspace:SetAttribute("EclipseTotalEnd", totalEnd)
	Workspace:SetAttribute("EclipseClear", clear)
	task.delay(S.ContactAfter, function()
		if active and generation == mine then
			Remotes.notify(nil, "The sun is going dark... the moon is crossing it!", "Alarm")
		end
	end)
	task.spawn(function()
		local inTotality = false
		local nextCrawl = 0
		local nextSend = 0
		while active and generation == mine do
			local dt = task.wait(0.1)
			local now = Workspace:GetServerTimeNow()
			-- remember where everyone walked
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local trail = trails[p] or {}
					trails[p] = trail
					table.insert(trail, { t = os.clock(), p = root.Position - Vector3.new(0, 2.5, 0) })
					while #trail > 60 do
						table.remove(trail, 1)
					end
				end
			end
			local totality = now >= total and now < totalEnd
			if totality and not inTotality then
				inTotality = true
				LightService.SetRadiusScale(S.GutterScale)
				nextCrawl = os.clock() + 3
				Remotes.notify(nil, "TOTALITY. Stay in the light... something is following you.", "Alarm")
			elseif not totality and inTotality then
				inTotality = false
				LightService.SetRadiusScale(1)
				burnAll()
				Remotes.event("StormEvent"):FireAllClients("DiamondRing", {})
			end
			if not inTotality then
				continue
			end
			-- shadows rise behind anyone out of the light, follow their steps, and feed
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local alive = root and root:IsA("BasePart") and hum and hum.Health > 0
				local lit = alive and LightService.IsPointLit((root :: BasePart).Position)
				local s = shadows[p]
				if not alive or lit then
					if s then
						shadows[p] = nil
						burned[p] = os.clock()
						Remotes.event("StormEvent"):FireAllClients("ShadowBurn", { uid = p.UserId })
					end
				elseif not s then
					if not burned[p] or os.clock() - burned[p] > S.ShadowAgain then
						local from = trailAt(p, S.ShadowRise)
						if from then
							shadows[p] = { pos = from }
						end
					end
				else
					local aim = trailAt(p, S.ShadowLag) or (root :: BasePart).Position
					local to = aim - s.pos
					local stepLen = S.ShadowSpeed * dt
					if to.Magnitude > 80 then
						s.pos = trailAt(p, S.ShadowRise) or s.pos -- lost you: it rises again behind you
					elseif to.Magnitude > stepLen then
						s.pos += to.Unit * stepLen
					else
						s.pos = aim
					end
					local here = (root :: BasePart).Position
					if Vector3.new(here.X - s.pos.X, 0, here.Z - s.pos.Z).Magnitude < S.ShadowReach then
						(hum :: Humanoid):TakeDamage(S.ShadowDrain * dt)
					end
				end
			end
			for p, _ in shadows do
				if p.Parent == nil then
					shadows[p] = nil
				end
			end
			if os.clock() >= nextSend then
				nextSend = os.clock() + 0.2
				local list = {}
				for p, s in shadows do
					table.insert(list, { uid = p.UserId, x = s.pos.X, y = s.pos.Y, z = s.pos.Z })
				end
				Remotes.event("StormEvent"):FireAllClients("Shadows", { list = list })
			end
			-- crawlers out of the dark
			if os.clock() >= nextCrawl then
				nextCrawl = os.clock() + rng:NextNumber(S.CrawlEvery.Min, S.CrawlEvery.Max)
				for _, p in Players:GetPlayers() do
					local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and not LightService.IsPointLit(root.Position) then
						local a = rng:NextNumber(0, math.pi * 2)
						EnemyService.Spawn("FogCrawler", root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * S.CrawlDistance)
					end
				end
			end
		end
	end)
end

function Eclipse.Stop()
	active = false
	LightService.SetRadiusScale(1)
	burnAll()
	Remotes.event("StormEvent"):FireAllClients("Shadows", { list = {} })
	for _, k in { "EclipseContact", "EclipseTotal", "EclipseTotalEnd", "EclipseClear" } do
		Workspace:SetAttribute(k, nil)
	end
end

return Eclipse
