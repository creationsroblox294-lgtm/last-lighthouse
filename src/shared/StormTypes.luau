--!strict
-- StormTypes: the 30 kinds of storm. StormDirector rolls one every night.
--
-- Tiers: Blessed (good luck), Mild, Moderate, Severe, Catastrophic.
-- Only types with Built = true can be rolled; the rest are listed so the
-- design lives in one place and they switch on as they are finished.
-- If the roll lands on a tier with nothing built yet, the night is an
-- ordinary storm ("Ordinary").

export type StormType = {
	Id: string,
	Name: string,
	Tier: string,
	Built: boolean,
	Forecast: string, -- barometer text during the calm
	Blurb: string, -- one line shown when the storm starts
	Color: Color3, -- HUD accent
	-- gameplay knobs read by the server (all optional)
	DrainMultiplier: number?, -- replaces Config.Light.StormDrainMultiplier
	RefuelPerSecond: number?, -- fuel added each second during the storm
	HealPerSecond: number?, -- health for players standing in the open
	EnemyMultiplier: number?, -- scales every creature quota
	Look: any?, -- optional sky/fog look for the storm phase (same fields as Config.PhaseLook)
	Textures: any?, -- particle textures for StormFXController
}

local StormTypes = {}

StormTypes.Tiers = { "Blessed", "Mild", "Moderate", "Severe", "Catastrophic" }

StormTypes.TierColor = {
	Blessed = Color3.fromRGB(255, 205, 90),
	Mild = Color3.fromRGB(150, 210, 255),
	Moderate = Color3.fromRGB(255, 190, 80),
	Severe = Color3.fromRGB(255, 110, 85),
	Catastrophic = Color3.fromRGB(200, 90, 255),
}

-- Chance of each tier, by storm number. Blessed can show up any night.
function StormTypes.TierWeights(stormNumber: number): { [string]: number }
	if stormNumber <= 3 then
		return { Blessed = 14, Mild = 86, Moderate = 0, Severe = 0, Catastrophic = 0 }
	elseif stormNumber <= 9 then
		return { Blessed = 12, Mild = 38, Moderate = 42, Severe = 8, Catastrophic = 0 }
	end
	return { Blessed = 10, Mild = 15, Moderate = 40, Severe = 30, Catastrophic = 5 }
end

local list: { StormType } = {}
local byId: { [string]: StormType } = {}

local function add(t: StormType)
	t.Color = t.Color or StormTypes.TierColor[t.Tier]
	table.insert(list, t)
	byId[t.Id] = t
end

local function planned(id: string, name: string, tier: string, forecast: string, blurb: string)
	add({ Id = id, Name = name, Tier = tier, Built = false, Forecast = forecast, Blurb = blurb, Color = StormTypes.TierColor[tier] })
end

-- The fallback when nothing in the rolled tier is built yet
add({
	Id = "Ordinary",
	Name = "Storm",
	Tier = "Mild",
	Built = true,
	Forecast = "A storm is gathering out at sea.",
	Blurb = "Keep the light burning.",
	Color = StormTypes.TierColor.Mild,
})

----------------------------------------------------------------- Blessed
add({
	Id = "GoldenRain",
	Name = "Golden Rain",
	Tier = "Blessed",
	Built = true,
	Forecast = "The barometer hums... the clouds glow gold on the horizon.",
	Blurb = "Golden Rain! The rain refills the lamp and heals you in the open.",
	Color = Color3.fromRGB(255, 205, 90),
	DrainMultiplier = 1, -- the lamp burns at its calm rate
	RefuelPerSecond = 0.3, -- and the rain tops it up (~+30 fuel over a storm)
	HealPerSecond = 1.5,
	EnemyMultiplier = 0.6,
	-- a warm, glowing evening instead of the usual dark storm sky
	Look = {
		ClockTime = 17.3,
		Brightness = 2.4,
		Exposure = 0.25,
		Ambient = Color3.fromRGB(170, 135, 90),
		FogDensity = 0.3,
		FogHaze = 1.8,
		FogColor = Color3.fromRGB(255, 196, 110),
	},
	-- rendered in Blender (LastLighthouseAssets/storms/Storms_FX.blend)
	Textures = {
		Drop = "",
		Splash = "",
		Sparkle = "",
		Ripple = "",
		Mote = "",
	},
})
planned("Starfall", "Starfall", "Blessed", "Strange lights streak across the evening sky.", "Starfall! Meteor shards are landing across the island.")
planned("BountifulTide", "Bountiful Tide", "Blessed", "The tide smells of tar and treasure.", "Bountiful Tide! The waves are washing up loot.")
planned("AuroraNight", "Aurora Night", "Blessed", "The sky shimmers green to the north.", "Aurora Night! The creatures are weak tonight.")
planned("FishRain", "Fish Rain", "Blessed", "A waterspout is dancing out at sea...", "Fish Rain! Free food is falling from the sky.")
planned("LuckyLightning", "Lucky Lightning", "Blessed", "Dry thunder, and the air smells of pine.", "Lucky Lightning! Bolts are splitting trees into wood.")

----------------------------------------------------------------- Mild
planned("Drizzle", "Drizzle", "Mild", "Light clouds rolling in.", "Just a drizzle.")
planned("SeaBreeze", "Sea Breeze", "Mild", "The wind is picking up a little.", "Sea Breeze: mind your footing.")
planned("MorningMist", "Morning Mist", "Mild", "Mist is creeping in low over the water.", "Mist hugs the ground.")
planned("Hailstorm", "Hailstorm", "Mild", "The air has turned sharp and cold.", "Hail! Stay under cover.")
planned("Squall", "Squall", "Mild", "Dark bands of rain on the horizon.", "Squall: rain comes in bursts.")
planned("RollingThunder", "Rolling Thunder", "Mild", "Distant thunder.", "Rolling Thunder: watch for strikes.")

----------------------------------------------------------------- Moderate
planned("Gale", "Gale", "Moderate", "The barometer is dropping fast. Wind incoming.", "Gale! Hold on to what you carry.")
planned("Thunderhead", "Thunderhead", "Moderate", "A towering cloud is building.", "Thunderhead! Lightning everywhere.")
planned("HighTide", "High Tide", "Moderate", "The sea is swelling.", "High Tide! The water is rising.")
planned("SilentFog", "Silent Fog", "Moderate", "Everything has gone very quiet.", "Silent Fog.")
planned("FreezingRain", "Freezing Rain", "Moderate", "The temperature is dropping.", "Freezing Rain! The ground is icy.")
planned("SandstormSurge", "Sandstorm Surge", "Moderate", "Sand is lifting off the beaches.", "Sandstorm Surge! Stay off the shore.")
planned("GhostShip", "Ghost Ship", "Moderate", "A bell is ringing out at sea...", "A Ghost Ship drifts offshore.")
planned("WildSwarm", "Wild Swarm", "Moderate", "The trees are rustling. Something is restless.", "Wild Swarm! The tree animals are frenzied.")

----------------------------------------------------------------- Severe
planned("RedTide", "Red Tide", "Severe", "The sea has turned a strange colour.", "Red Tide! Stay out of the water.")
planned("Hurricane", "Hurricane", "Severe", "The barometer has never been this low.", "HURRICANE!")
planned("BlackoutStorm", "Blackout Storm", "Severe", "Static is crackling in the air.", "Blackout! Lightning hit the lamp!")
planned("EmberStorm", "Ember Storm", "Severe", "Dry lightning and hot wind.", "Ember Storm! Fires are spreading.")
planned("Whiteout", "Whiteout", "Severe", "Snow clouds, out of season.", "Whiteout! Get inside.")

----------------------------------------------------------------- Catastrophic
planned("Maelstrom", "Maelstrom", "Catastrophic", "The sea is turning in circles.", "MAELSTROM!")
planned("Waterspout", "Waterspout", "Catastrophic", "Funnel clouds are forming.", "WATERSPOUTS!")
planned("Eclipse", "Eclipse Storm", "Catastrophic", "The sun is going dark.", "ECLIPSE!")
planned("Deluge", "The Deluge", "Catastrophic", "The water will not stop rising.", "THE DELUGE! Get to the top floors!")
planned("Cursed", "Cursed Storm", "Catastrophic", "???", "A Cursed Storm!")

StormTypes.List = list

function StormTypes.Get(id: string?): StormType
	return (id and byId[id]) or byId.Ordinary
end

-- Pick tonight's storm. forced = a type id to use instead (Studio testing).
function StormTypes.Roll(stormNumber: number, rng: Random, forced: string?): StormType
	if forced and byId[forced] then
		return byId[forced]
	end
	local weights = StormTypes.TierWeights(stormNumber)
	local total = 0
	for _, w in weights do
		total += w
	end
	local pick = rng:NextNumber() * total
	local tier = "Mild"
	for _, name in StormTypes.Tiers do
		pick -= weights[name] or 0
		if pick <= 0 then
			tier = name
			break
		end
	end
	local options = {}
	for _, t in list do
		if t.Built and t.Tier == tier and t.Id ~= "Ordinary" then
			table.insert(options, t)
		end
	end
	if #options == 0 then
		return byId.Ordinary
	end
	return options[rng:NextInteger(1, #options)]
end

return StormTypes
