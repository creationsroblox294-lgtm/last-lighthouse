--!strict
-- Sea Breeze (Mild): a strong, steady wind off the sea (Workspace attribute "WindDir"), with
-- gusts every few seconds (StormEvent "Gust": a short warning while the wind roars up, then a
-- few seconds of shove). Each client pushes its own character, since players own their own
-- physics: anyone out in the open gets shoved downwind, and a rogue gust can knock you flat.
-- Shelter (anything overhead) keeps you safe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local S = {
	GustEvery = NumberRange.new(6, 11),
	WarnSeconds = 1.3,
	GustSeconds = 2.6,
	Strength = NumberRange.new(0.6, 1),
	RogueChance = 0.25, -- a rogue gust: much stronger, can knock players down
	RogueStrength = 1.5,
	Veer = 0.35, -- radians the wind can swing for a gust
}

local SeaBreeze = {}

local active = false
local generation = 0
local rng = Random.new()

function SeaBreeze.Start()
	active = true
	generation += 1
	local mine = generation
	local a = rng:NextNumber(0, math.pi * 2)
	local base = Vector3.new(math.cos(a), 0, math.sin(a))
	Workspace:SetAttribute("WindDir", base)
	local event = Remotes.event("StormEvent")
	while active and generation == mine do
		task.wait(rng:NextNumber(S.GustEvery.Min, S.GustEvery.Max))
		if not (active and generation == mine) then
			break
		end
		local veer = rng:NextNumber(-S.Veer, S.Veer)
		local dir = Vector3.new(math.cos(a + veer), 0, math.sin(a + veer))
		local rogue = rng:NextNumber() < S.RogueChance
		event:FireAllClients("Gust", {
			dir = dir,
			warn = S.WarnSeconds,
			seconds = S.GustSeconds,
			strength = if rogue then S.RogueStrength else rng:NextNumber(S.Strength.Min, S.Strength.Max),
			rogue = rogue,
		})
	end
end

function SeaBreeze.Stop()
	active = false
	Workspace:SetAttribute("WindDir", nil)
end

return SeaBreeze
