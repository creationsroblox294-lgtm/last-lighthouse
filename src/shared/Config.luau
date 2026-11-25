--!strict
-- Tuning values shared by the server and the client.
-- Change numbers here rather than inside the code.

local Config = {}

-- Seconds per phase (design doc: calm ~3 min, warning 30 s, storm 2-3 min, dawn 20 s)
Config.PhaseDurations = {
	Calm = 180,
	Warning = 30,
	StormMin = 120,
	StormMax = 180,
	Dawn = 20,
}

-- Debug: make every phase last DebugPhaseSeconds.
-- Either set DebugFastCycle = true here, or (Studio only) tick the
-- DebugFastCycle attribute on Workspace in the Properties window.
Config.DebugFastCycle = false
Config.DebugPhaseSeconds = 10

Config.MaxStorms = 100
Config.GreatStormEvery = 10 -- every 10th storm is a Great Storm with a boss
Config.LastLightStartsAt = 91 -- storms 91-100: every storm is a Great Storm

Config.SpecialStormChance = 1 / 8
Config.SpecialStorms = { "SilentFog", "RedTide", "GhostShip", "CalmNight" }

-- How the world looks in each phase (used by the client's FogController)
Config.PhaseLook = {
	Calm = {
		ClockTime = 14,
		Brightness = 2.5,
		Ambient = Color3.fromRGB(110, 115, 125),
		FogDensity = 0.25,
		FogHaze = 0.5,
		FogColor = Color3.fromRGB(200, 205, 210),
	},
	Warning = {
		ClockTime = 16.5,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(90, 92, 105),
		FogDensity = 0.42,
		FogHaze = 2,
		FogColor = Color3.fromRGB(160, 165, 175),
	},
	Storm = {
		ClockTime = 18.4,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(40, 45, 60),
		FogDensity = 0.62,
		FogHaze = 6,
		FogColor = Color3.fromRGB(70, 80, 95),
	},
	Dawn = {
		ClockTime = 6.8,
		Brightness = 1.8,
		Ambient = Color3.fromRGB(120, 105, 100),
		FogDensity = 0.35,
		FogHaze = 1.5,
		FogColor = Color3.fromRGB(230, 190, 160),
	},
	Won = {
		ClockTime = 14,
		Brightness = 2.5,
		Ambient = Color3.fromRGB(110, 115, 125),
		FogDensity = 0.2,
		FogHaze = 0,
		FogColor = Color3.fromRGB(210, 215, 220),
	},
}

-- How long the look takes to blend into each phase
Config.LookTweenSeconds = {
	Calm = 6,
	Warning = 10,
	Storm = 6,
	Dawn = 4,
	Won = 6,
}

return Config
