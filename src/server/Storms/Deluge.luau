--!strict
-- The Deluge (Catastrophic): rain like the sky has split open, and the water will not stop
-- rising. The flood (Workspace "DelugeLevel", the height of its surface) climbs in surges
-- (StormEvent "DelugeSurge") until it has swallowed the whole island and the lighthouse's ground
-- floor, then drains away at the very end. In the flood you float (each client buoys its own
-- character) and the current drags you out to sea. Get your head under and your breath runs out
-- (player attribute "Breath", 1 = full), then you drown. The Drowned swim up out of the murk.
-- And now and then something takes hold of a swimmer and drags them under (StormEvent "Undertow").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	Top = 25, -- highest the flood gets (ground floor ceiling is 27, the island tops out at 23)
	PeakAt = 0.72, -- fraction of the storm it reaches the top
	DrainAt = 0.86, -- when it starts going down
	SurgeEvery = NumberRange.new(7, 11),
	RiseSpeed = 1.6, -- studs a second while a surge comes in
	DrainSpeed = 4,
	BreathSeconds = 12,
	DrownDamage = 10, -- per second with no breath left
	UndertowEvery = NumberRange.new(9, 14),
	UndertowSeconds = 2.6,
	UndertowDamage = 7, -- per second while held under
	DrownedEvery = NumberRange.new(8, 12),
}

local Deluge = {}

local active = false
local generation = 0
local rng = Random.new()

local function stormEndsAt(): number?
	for _, d in ReplicatedStorage:GetDescendants() do
		if d:IsA("Configuration") and d.Name == "Storm" then
			return d:GetAttribute("PhaseEndsAt") :: number?
		end
	end
	return nil
end

local function inFlood(p: Player, level: number): (BasePart?, Humanoid?)
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and hum and hum.Health > 0 and root.Position.Y < level + 0.5 then
		return root, hum
	end
	return nil, nil
end

function Deluge.Start()
	active = true
	generation += 1
	local mine = generation
	local now0 = Workspace:GetServerTimeNow()
	local ends = stormEndsAt() or (now0 + 180)
	local length = math.max(40, ends - now0)
	local peakAt = now0 + length * S.PeakAt
	local drainAt = now0 + length * S.DrainAt
	-- how many surges it takes to get to the top
	local surges = math.max(3, math.floor((length * S.PeakAt - 4) / ((S.SurgeEvery.Min + S.SurgeEvery.Max) / 2)))
	local stepUp = S.Top / surges
	Workspace:SetAttribute("DelugeLevel", 0)
	task.spawn(function()
		local level, target = 0, 0
		local nextSurge = os.clock() + 4
		local nextUndertow = os.clock() + 10
		local nextDrowned = os.clock() + 8
		local held: { [Player]: number } = {}
		while active and generation == mine do
			local dt = task.wait(0.2)
			local now = Workspace:GetServerTimeNow()
			if now >= drainAt then
				target = 0
			elseif os.clock() >= nextSurge and target < S.Top then
				nextSurge = os.clock() + rng:NextNumber(S.SurgeEvery.Min, S.SurgeEvery.Max)
				target = math.min(S.Top, target + stepUp)
				if now >= peakAt then
					target = S.Top
				end
				Remotes.event("StormEvent"):FireAllClients("DelugeSurge", { to = target })
				if target >= S.Top then
					Remotes.notify(nil, "The whole island is under water! Get to the top floors!", "Alarm")
				elseif target > 8 then
					Remotes.notify(nil, "The water is still rising...", "Alarm")
				end
			end
			local speed = if target < level then S.DrainSpeed else S.RiseSpeed
			level += math.clamp(target - level, -speed * dt, speed * dt)
			Workspace:SetAttribute("DelugeLevel", level)

			-- breath and drowning
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local head = char and char:FindFirstChild("Head")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if head and head:IsA("BasePart") and hum and hum.Health > 0 then
					local breath = (p:GetAttribute("Breath") :: number?) or 1
					local under = head.Position.Y < level - 0.3 or (held[p] ~= nil and os.clock() < held[p])
					if under then
						breath = math.max(0, breath - dt / S.BreathSeconds)
						if breath <= 0 then
							hum:TakeDamage(S.DrownDamage * dt)
						end
					else
						breath = math.min(1, breath + dt / 3)
					end
					p:SetAttribute("Breath", if breath >= 1 then nil else breath)
				end
			end

			-- something in the water takes hold of a swimmer
			if level > 3 and os.clock() >= nextUndertow then
				nextUndertow = os.clock() + rng:NextNumber(S.UndertowEvery.Min, S.UndertowEvery.Max)
				local swimmers = {}
				for _, p in Players:GetPlayers() do
					local root = inFlood(p, level)
					if root and not LightService.IsPointLit(root.Position) and not held[p] then
						table.insert(swimmers, p)
					end
				end
				if #swimmers > 0 then
					local p = swimmers[rng:NextInteger(1, #swimmers)]
					local root = inFlood(p, level)
					held[p] = os.clock() + S.UndertowSeconds
					Remotes.event("StormEvent"):FireAllClients("Undertow", { uid = p.UserId, at = root and root.Position, seconds = S.UndertowSeconds })
				end
			end
			for p, untilT in held do
				local _, hum = inFlood(p, level + 12)
				if os.clock() >= untilT or not hum then
					held[p] = nil
				elseif hum then
					hum:TakeDamage(S.UndertowDamage * dt)
				end
			end

			-- the Drowned come up out of the murk around swimmers
			if level > 3 and os.clock() >= nextDrowned then
				nextDrowned = os.clock() + rng:NextNumber(S.DrownedEvery.Min, S.DrownedEvery.Max)
				for _, p in Players:GetPlayers() do
					local root = inFlood(p, level)
					if root then
						local a = rng:NextNumber(0, math.pi * 2)
						EnemyService.Spawn("Drowned", root.Position + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28))
					end
				end
			end
		end
	end)
	Remotes.notify(nil, "The rain is coming down in sheets... and the sea is climbing the beach.", "Alarm")
end

function Deluge.Stop()
	active = false
	Workspace:SetAttribute("DelugeLevel", nil)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Breath", nil)
	end
end

return Deluge
