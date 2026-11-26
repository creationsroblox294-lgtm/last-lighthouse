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
	EnemyHealthMultiplier: number?, -- scales the health of creatures spawned during the storm
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
		ClockTime = 17.9, -- low golden-hour sun
		Brightness = 2.6,
		Exposure = 0.3,
		Ambient = Color3.fromRGB(190, 140, 80),
		FogDensity = 0.4,
		FogHaze = 2.6,
		FogColor = Color3.fromRGB(255, 180, 90),
	},
	-- rendered in Blender (LastLighthouseAssets/storms/Storms_FX.blend)
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Splash = "rbxassetid://113883163440180",
		Sparkle = "rbxassetid://83247130952036",
		Ripple = "rbxassetid://136329093448726",
		Mote = "rbxassetid://72567132198596",
	},
})
add({
	Id = "Starfall",
	Name = "Starfall",
	Tier = "Blessed",
	Built = true,
	Forecast = "Strange lights streak across the evening sky.",
	Blurb = "Starfall! Meteors are raining down. Dodge the rings and grab the star shards for the lamp!",
	Color = Color3.fromRGB(170, 200, 255),
	DrainMultiplier = 2, -- gentler than a normal storm
	EnemyMultiplier = 0.7,
	-- a clear violet night (Storms/Starfall drops the meteors; StormFX/Starfall draws them)
	Look = {
		ClockTime = 21.5,
		Brightness = 1.6,
		Exposure = 0.3,
		Ambient = Color3.fromRGB(110, 110, 170),
		FogDensity = 0.26,
		FogHaze = 1.2,
		FogColor = Color3.fromRGB(120, 105, 210),
	},
	Textures = {
		Meteor = "rbxassetid://133073372860432",
		Flash = "rbxassetid://139636482279050",
		Star = "rbxassetid://126403501619669",
	},
})
add({
	Id = "BountifulTide",
	Name = "Bountiful Tide",
	Tier = "Blessed",
	Built = true,
	Forecast = "The tide smells of tar and treasure.",
	Blurb = "Bountiful Tide! Glowing waves are washing loot and treasure chests onto the beaches!",
	Color = Color3.fromRGB(70, 235, 215),
	DrainMultiplier = 1.6,
	EnemyMultiplier = 0.6,
	-- a glowing turquoise dusk (Storms/BountifulTide rolls the waves in; StormFX/BountifulTide draws them)
	Look = {
		ClockTime = 17.85,
		Brightness = 2.6,
		Exposure = 0.2,
		Ambient = Color3.fromRGB(170, 140, 175),
		FogDensity = 0.24,
		FogHaze = 2.2,
		FogColor = Color3.fromRGB(255, 150, 160),
	},
	Textures = {
		Foam = "rbxassetid://119411769037011",
		Sparkle = "rbxassetid://83247130952036",
		Mote = "rbxassetid://72567132198596",
	},
})
add({
	Id = "AuroraNight",
	Name = "Aurora Night",
	Tier = "Blessed",
	Built = true,
	Forecast = "The sky shimmers green to the north.",
	Blurb = "Aurora Night! The creatures are weak tonight. Touch the aurora wisps for fuel, health and a burst of light!",
	Color = Color3.fromRGB(110, 255, 180),
	DrainMultiplier = 1.5,
	EnemyMultiplier = 0.7,
	EnemyHealthMultiplier = 0.5,
	-- a clear, deep night (Storms/AuroraNight floats the wisps; StormFX/AuroraNight draws the sky)
	Look = {
		ClockTime = 0.5,
		Brightness = 1.4,
		Exposure = 0.25,
		Ambient = Color3.fromRGB(70, 120, 110),
		FogDensity = 0.12,
		FogHaze = 0.6,
		FogColor = Color3.fromRGB(40, 90, 100),
	},
	Textures = {
		Curtain = "rbxassetid://112320412004363",
		Wisp = "rbxassetid://136848610196771",
		Twinkle = "rbxassetid://95153044084608",
	},
})
add({
	Id = "FishRain",
	Name = "Fish Rain",
	Tier = "Blessed",
	Built = true,
	Forecast = "A waterspout is dancing out at sea...",
	Blurb = "Fish Rain! The waterspout is dropping fish all over the island. Grab them, and look out for golden ones!",
	Color = Color3.fromRGB(150, 210, 255),
	DrainMultiplier = 1.6,
	EnemyMultiplier = 0.65,
	-- a bright silver shower under a rainbow (Storms/FishRain drops the fish; StormFX/FishRain draws them)
	Look = {
		ClockTime = 16.6,
		Brightness = 2.4,
		Exposure = 0.15,
		Ambient = Color3.fromRGB(110, 125, 150),
		FogDensity = 0.22,
		FogHaze = 1.4,
		FogColor = Color3.fromRGB(120, 145, 175),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Splash = "rbxassetid://113883163440180",
		Glint = "rbxassetid://117341182317330",
		Rainbow = "rbxassetid://139694757984300",
		Spray = "rbxassetid://73237222095974",
	},
})
add({
	Id = "LuckyLightning",
	Name = "Lucky Lightning",
	Tier = "Blessed",
	Built = true,
	Forecast = "Dry thunder, and the air smells of pine.",
	Blurb = "Lucky Lightning! Bolts are splitting trees into firewood and frying creatures. Don't stand where it crackles!",
	Color = Color3.fromRGB(190, 170, 255),
	DrainMultiplier = 1.7,
	EnemyMultiplier = 0.75,
	-- a dry, electric violet dusk (Storms/LuckyLightning aims the bolts; StormFX/LuckyLightning draws them)
	Look = {
		ClockTime = 19,
		Brightness = 2.2,
		Exposure = 0.3,
		Ambient = Color3.fromRGB(130, 110, 175),
		FogDensity = 0.3,
		FogHaze = 1.5,
		FogColor = Color3.fromRGB(90, 70, 140),
	},
	Textures = {
		Spark = "rbxassetid://124288772478718",
		Clover = "rbxassetid://85096880326443",
		Glow = "rbxassetid://133210713162638",
		Flash = "rbxassetid://139636482279050",
		Mote = "rbxassetid://72567132198596",
	},
})

----------------------------------------------------------------- Mild
add({
	Id = "Drizzle",
	Name = "Drizzle",
	Tier = "Mild",
	Built = true,
	Forecast = "Light clouds rolling in.",
	Blurb = "Just a drizzle... but keep an eye on the puddles.",
	Color = Color3.fromRGB(170, 195, 220),
	DrainMultiplier = 2.4,
	EnemyMultiplier = 0.85,
	-- a hushed silver afternoon (Storms/Drizzle spreads the puddles; StormFX/Drizzle draws them)
	Look = {
		ClockTime = 15,
		Brightness = 1.8,
		Exposure = 0.05,
		Ambient = Color3.fromRGB(125, 135, 150),
		FogDensity = 0.38,
		FogHaze = 2,
		FogColor = Color3.fromRGB(170, 180, 195),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Splash = "rbxassetid://113883163440180",
		Ripple = "rbxassetid://136329093448726",
		Bubble = "rbxassetid://83414063738231",
		Haze = "rbxassetid://97891709522639",
	},
})
add({
	Id = "SeaBreeze",
	Name = "Sea Breeze",
	Tier = "Mild",
	Built = true,
	Forecast = "The wind is picking up a little.",
	Blurb = "Sea Breeze! Mind your footing: the gusts can knock you flat. Get under cover when it roars.",
	Color = Color3.fromRGB(150, 220, 255),
	DrainMultiplier = 2.5,
	EnemyMultiplier = 0.85,
	-- a bright, blustery day (Storms/SeaBreeze times the gusts; StormFX/SeaBreeze draws them and pushes you)
	Look = {
		ClockTime = 11,
		Brightness = 3,
		Exposure = 0.15,
		Ambient = Color3.fromRGB(140, 160, 180),
		FogDensity = 0.2,
		FogHaze = 0.8,
		FogColor = Color3.fromRGB(190, 215, 240),
	},
	Textures = {
		Leaf = "rbxassetid://105999470506423",
		Streak = "rbxassetid://134764319364715",
	},
})
add({
	Id = "MorningMist",
	Name = "Morning Mist",
	Tier = "Mild",
	Built = true,
	Forecast = "Mist is creeping in low over the water.",
	Blurb = "Morning Mist... there are figures standing in it. Not all of them are only mist.",
	Color = Color3.fromRGB(255, 200, 190),
	DrainMultiplier = 2.5,
	EnemyMultiplier = 0.8,
	-- a soft pink-and-gold dawn (Storms/MorningMist places the figures; StormFX/MorningMist draws them)
	Look = {
		ClockTime = 6.4,
		Brightness = 2.4,
		Exposure = 0.2,
		Ambient = Color3.fromRGB(170, 145, 150),
		FogDensity = 0.3,
		FogHaze = 2,
		FogColor = Color3.fromRGB(255, 205, 195),
	},
	Textures = {
		Haze = "rbxassetid://97891709522639",
		Glint = "rbxassetid://117341182317330",
		Mote = "rbxassetid://72567132198596",
	},
})
add({
	Id = "Hailstorm",
	Name = "Hailstorm",
	Tier = "Mild",
	Built = true,
	Forecast = "The air has turned sharp and cold.",
	Blurb = "Hail! It stings out in the open, so stay under cover, and watch for shadows on the ground.",
	Color = Color3.fromRGB(190, 225, 255),
	DrainMultiplier = 2.6,
	EnemyMultiplier = 0.8,
	-- a bitter steel-blue afternoon (Storms/Hailstorm drops the giant stones; StormFX/Hailstorm draws the hail)
	Look = {
		ClockTime = 16,
		Brightness = 1.7,
		Exposure = 0,
		Ambient = Color3.fromRGB(120, 135, 160),
		FogDensity = 0.34,
		FogHaze = 1.6,
		FogColor = Color3.fromRGB(160, 175, 200),
	},
	Textures = {
		Pellet = "rbxassetid://128143376871068",
		Frost = "rbxassetid://75634646301252",
		Splash = "rbxassetid://113883163440180",
	},
})
add({
	Id = "Squall",
	Name = "Squall",
	Tier = "Mild",
	Built = true,
	Forecast = "Dark bands of rain on the horizon.",
	Blurb = "Squall! Walls of rain are sweeping the island. Watch the horizon, and watch your back when one hits.",
	Color = Color3.fromRGB(160, 190, 180),
	DrainMultiplier = 2.4,
	EnemyMultiplier = 0.8,
	-- a sullen grey-green day (Storms/Squall drives the bands; StormFX/Squall draws the rain walls)
	Look = {
		ClockTime = 14.5,
		Brightness = 1.6,
		Exposure = 0,
		Ambient = Color3.fromRGB(115, 130, 125),
		FogDensity = 0.3,
		FogHaze = 1.6,
		FogColor = Color3.fromRGB(140, 155, 150),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Splash = "rbxassetid://113883163440180",
		Sheet = "rbxassetid://94100520771589",
	},
})
add({
	Id = "RollingThunder",
	Name = "Rolling Thunder",
	Tier = "Mild",
	Built = true,
	Forecast = "Distant thunder.",
	Blurb = "Rolling Thunder! When the air around you starts to crackle, MOVE. The strikes set the ground on fire.",
	Color = Color3.fromRGB(255, 170, 130),
	DrainMultiplier = 2.6,
	EnemyMultiplier = 0.8,
	-- a bruised purple-and-orange dusk (Storms/RollingThunder aims the strikes; StormFX/RollingThunder draws them)
	Look = {
		ClockTime = 18.4,
		Brightness = 1.8,
		Exposure = 0.1,
		Ambient = Color3.fromRGB(130, 100, 115),
		FogDensity = 0.32,
		FogHaze = 1.8,
		FogColor = Color3.fromRGB(170, 115, 120),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Spark = "rbxassetid://124288772478718",
		Mote = "rbxassetid://72567132198596",
		Flame = "rbxassetid://70612468476990",
		Smoke = "rbxassetid://79085558579719",
	},
})

----------------------------------------------------------------- Moderate
add({
	Id = "Gale",
	Name = "Gale",
	Tier = "Moderate",
	Built = true,
	Forecast = "The barometer is dropping fast. Wind incoming.",
	Blurb = "Gale! The wind is throwing debris across the island. Hold on to what you carry and stay out of the open.",
	Color = Color3.fromRGB(150, 185, 170),
	DrainMultiplier = 3,
	EnemyMultiplier = 1,
	-- a howling slate-green storm (Storms/Gale throws the debris and snatches loads; StormFX/Gale draws it and leans on you)
	Look = {
		ClockTime = 15.5,
		Brightness = 1.5,
		Exposure = -0.05,
		Ambient = Color3.fromRGB(105, 120, 115),
		FogDensity = 0.36,
		FogHaze = 1.8,
		FogColor = Color3.fromRGB(120, 135, 130),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Streak = "rbxassetid://134764319364715",
		Leaf = "rbxassetid://105999470506423",
	},
})
add({
	Id = "Thunderhead",
	Name = "Thunderhead",
	Tier = "Moderate",
	Built = true,
	Forecast = "A towering cloud is building.",
	Blurb = "Thunderhead! Lightning everywhere. Drop any scrap you're carrying: metal draws the bolts.",
	Color = Color3.fromRGB(170, 180, 255),
	DrainMultiplier = 3,
	EnemyMultiplier = 0.9,
	-- a dark blue-violet supercell (Storms/Thunderhead aims the bolts; StormFX/Thunderhead draws the cloud and bolts)
	Look = {
		ClockTime = 17,
		Brightness = 1.4,
		Exposure = -0.05,
		Ambient = Color3.fromRGB(95, 100, 135),
		FogDensity = 0.34,
		FogHaze = 1.6,
		FogColor = Color3.fromRGB(95, 100, 140),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Spark = "rbxassetid://124288772478718",
		Mote = "rbxassetid://72567132198596",
	},
})
add({
	Id = "HighTide",
	Name = "High Tide",
	Tier = "Moderate",
	Built = true,
	Forecast = "The sea is swelling.",
	Blurb = "High Tide! The sea is flooding the island. Get to high ground. Things are coming up out of the water.",
	Color = Color3.fromRGB(110, 190, 180),
	DrainMultiplier = 3,
	EnemyMultiplier = 0.9,
	-- a heaving grey-green flood (Storms/HighTide raises the water; StormFX/HighTide draws it and drags you)
	Look = {
		ClockTime = 16.5,
		Brightness = 1.5,
		Exposure = -0.05,
		Ambient = Color3.fromRGB(100, 120, 120),
		FogDensity = 0.36,
		FogHaze = 1.8,
		FogColor = Color3.fromRGB(115, 140, 140),
	},
	Textures = {
		Drop = "rbxassetid://109078171013574",
		Splash = "rbxassetid://113883163440180",
		Ripple = "rbxassetid://136329093448726",
		Foam = "rbxassetid://119411769037011",
		Bubble = "rbxassetid://83414063738231",
	},
})
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
