--!strict
-- Hurricane (Severe): the wind never stops and never comes from the same way twice: it swings
-- slowly round the compass (Workspace attributes "WindDir" and "WindStrength", 0..1+). Debris
-- is flung across the island at players (StormEvent "Debris", the same as the Gale). Then,
-- part way through, the eye arrives (Workspace attributes "HurricaneEyeAt" / "HurricaneEyeEnd",
-- server times, and "HurricaneTrack", the way the storm is moving): the wind drops to nothing,
-- the rain stops and the sky opens. It doesn't last. The back of the eyewall hits all at once
-- with the wind from the other way and stronger than before (StormEvent "BackWall"): anyone
-- caught in the open is thrown down and hurt, and the lamp takes a battering.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	EyeAt = 0.42, -- fraction of the way through the storm the eye arrives
	EyeSeconds = NumberRange.new(14, 22), -- how long the calm lasts (shorter in short storms)
	EyeFraction = 0.18, -- ...and at most this fraction of the storm
	TurnRate = math.rad(4), -- radians per second the wind swings round
	DebrisEvery = NumberRange.new(3, 5.5),
	DebrisFrom = 160,
	DebrisSeconds = 2,
	HitRadius = 6,
	HitDamage = 13,
	BackWallDamage = 12,
	BackWallDrain = 6,
}

local Hurricane = {}

local active = false
local generation = 0
local rng = Random.new()
local windDir = Vector3.new(1, 0, 0)
local strength = 1

local function exposed(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
end

local function stormEndsAt(): number?
	for _, d in ReplicatedStorage:GetDescendants() do
		if d:IsA("Configuration") and d.Name == "Storm" then
			return d:GetAttribute("PhaseEndsAt") :: number?
		end
	end
	return nil
end

local function fling()
	local players = Players:GetPlayers()
	if #players == 0 or strength < 0.3 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and root and root:IsA("BasePart")) or not exposed(char, root) then
		return
	end
	local side = Vector3.new(-windDir.Z, 0, windDir.X)
	local to = root.Position + side * rng:NextNumber(-4, 4)
	local from = to - windDir * S.DebrisFrom + side * rng:NextNumber(-40, 40) + Vector3.new(0, rng:NextNumber(25, 50), 0)
	Remotes.event("StormEvent"):FireAllClients("Debris", {
		from = from,
		to = to,
		seconds = S.DebrisSeconds,
		kind = if rng:NextNumber() < 0.5 then "Plank" else "Branch",
		seed = rng:NextInteger(1, 1e6),
		radius = S.HitRadius,
	})
	task.delay(S.DebrisSeconds, function()
		for _, pl in Players:GetPlayers() do
			local c = pl.Character
			local rr = c and c:FindFirstChild("HumanoidRootPart")
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if rr and rr:IsA("BasePart") and hum and hum.Health > 0 and (rr.Position - to).Magnitude < S.HitRadius then
				hum:TakeDamage(S.HitDamage)
			end
		end
	end)
end

function Hurricane.Start()
	active = true
	generation += 1
	local mine = generation
	local now0 = Workspace:GetServerTimeNow()
	local ends = stormEndsAt() or (now0 + 180)
	local length = math.max(30, ends - now0)
	local eyeAt = now0 + length * S.EyeAt
	local eyeLen = math.min(rng:NextNumber(S.EyeSeconds.Min, S.EyeSeconds.Max), length * S.EyeFraction)
	local eyeEnd = eyeAt + eyeLen
	local a0 = rng:NextNumber(0, math.pi * 2)
	local turn = S.TurnRate * (if rng:NextNumber() < 0.5 then 1 else -1)
	local track = rng:NextNumber(0, math.pi * 2)
	Workspace:SetAttribute("HurricaneEyeAt", eyeAt)
	Workspace:SetAttribute("HurricaneEyeEnd", eyeEnd)
	Workspace:SetAttribute("HurricaneTrack", Vector3.new(math.cos(track), 0, math.sin(track)))
	local phase = "Front"
	-- the wind
	task.spawn(function()
		while active and generation == mine do
			local now = Workspace:GetServerTimeNow()
			local a = a0 + turn * (now - now0)
			if now >= eyeEnd then
				a += math.pi -- the back of the storm blows the other way
			end
			windDir = Vector3.new(math.cos(a), 0, math.sin(a))
			if now < eyeAt - 4 then
				strength = 1
			elseif now < eyeAt then
				strength = math.max(0, (eyeAt - now) / 4) -- dying away into the eye
			elseif now < eyeEnd then
				strength = 0
			else
				strength = 1.3
			end
			Workspace:SetAttribute("WindDir", windDir)
			Workspace:SetAttribute("WindStrength", strength)
			if phase == "Front" and now >= eyeAt then
				phase = "Eye"
				Remotes.notify(nil, "The wind's stopped... we're in the eye. It's coming back.", "Alarm")
			elseif phase == "Eye" and now >= eyeEnd - 4 then
				phase = "Warn"
				Remotes.notify(nil, "The other side of the eyewall is coming!", "Alarm")
			elseif phase == "Warn" and now >= eyeEnd then
				phase = "Back"
				Remotes.event("StormEvent"):FireAllClients("BackWall", { dir = windDir })
				LightService.DrainFuel(S.BackWallDrain)
				for _, p in Players:GetPlayers() do
					local char = p.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if char and root and root:IsA("BasePart") and hum and hum.Health > 0 and exposed(char, root) then
						hum:TakeDamage(S.BackWallDamage)
					end
				end
				Remotes.notify(nil, "HERE IT COMES!", "Alarm")
			end
			task.wait(0.25)
		end
	end)
	-- debris
	while active and generation == mine do
		fling()
		task.wait(rng:NextNumber(S.DebrisEvery.Min, S.DebrisEvery.Max) / math.max(0.6, strength))
	end
end

function Hurricane.Stop()
	active = false
	for _, k in { "WindDir", "WindStrength", "HurricaneEyeAt", "HurricaneEyeEnd", "HurricaneTrack" } do
		Workspace:SetAttribute(k, nil)
	end
end

return Hurricane
