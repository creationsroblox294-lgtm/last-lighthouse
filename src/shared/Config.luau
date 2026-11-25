--!strict
-- Tuning values shared by the server and the client.
-- Change numbers here rather than inside the code.

local Config = {}

---------------------------------------------------------------------------
-- Storm cycle
---------------------------------------------------------------------------
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
Config.DebugStormSeconds = 45 -- storms run longer so fights can play out

-- MVP ships with 20 storms. Raise to 100 when the later updates land.
Config.MaxStorms = 20
Config.GreatStormEvery = 10 -- every 10th storm is a Great Storm with the Tide Caller
Config.LastLightStartsAt = 91 -- storms 91-100: every storm is a Great Storm
Config.LostScreenSeconds = 12 -- how long the "run lost" screen shows before a new run

Config.SpecialStormChance = 1 / 8
Config.SpecialStorms = { "SilentFog", "RedTide", "GhostShip", "CalmNight" }

---------------------------------------------------------------------------
-- World positions (match tools/BuildGreybox.luau)
---------------------------------------------------------------------------
Config.World = {
	IslandCenter = Vector3.new(0, 3, 0),
	TowerCenter = Vector3.new(55, 35, -80), -- base of the tower, on the cliff top
	LampPosition = Vector3.new(55, 75, -80),
	RampBottom = Vector3.new(55, 6, 48),
	RampTop = Vector3.new(55, 36, -50),
	DoorFront = Vector3.new(55, 36, -62),
	CliffTopY = 35,
	BossPosition = Vector3.new(55, 0, -190),
}

---------------------------------------------------------------------------
-- The lamp
---------------------------------------------------------------------------
Config.Light = {
	Tick = 0.2,
	MaxFuel = 100,
	StartFuel = 80,
	DrainPerSecond = 0.1, -- calm / warning / dawn
	StormDrainMultiplier = 3, -- design doc: fuel drains ~3x faster during storms
	LeakDrainMultiplier = 2, -- lamp room broken
	FuelValues = { Oil = 25, Wood = 8, WhaleOil = 60 },
	LensRadius = { 55, 70, 85 }, -- by lens tier
	MinRadiusFraction = 0.45, -- radius when the tank is nearly empty
	LowFuelFraction = 0.25,
	LightsOutGrace = 15, -- seconds of alarm before creatures swarm
	BeamRange = 130,
	BeamDegreesPerSecond = 40,
	BeamHalfWidthDegrees = 7,
	BeamDamagePerSecond = 20,
	BeamStunSeconds = 1.5,
	ManualAimDegreesPerSecond = 160,
	ManualAimMaxDistance = 22, -- studs from the lamp to keep control
}

---------------------------------------------------------------------------
-- Creatures
---------------------------------------------------------------------------
Config.Enemies = {
	Tick = 0.2,
	MaxAlive = 40,
	SpawnInterval = 2.5,
	SwarmSpawnInterval = 1,
	SpawnRadius = 140,
	PlayerScale = 0.35, -- each extra player adds 35% more creatures (fuel drain doesn't change)
	FogCrawler = {
		Health = 30,
		Speed = 15,
		Damage = 10,
		AttackRange = 5,
		AttackCooldown = 1,
		LightDamagePerSecond = 30,
		FirstStorm = 1,
		CountBase = 4,
		CountPerStorm = 0.8,
	},
	Drowned = {
		Health = 140,
		Speed = 8,
		Damage = 14,
		AttackRange = 6,
		AttackCooldown = 1.5,
		LightSlowFactor = 0.5,
		StructureDamage = 12,
		FirstStorm = 8,
		CountBase = 2,
		CountPerStorm = 0.35,
	},
}

Config.TideCaller = {
	Health = 900,
	ExtraPlayerHealth = 0.3,
	WaveEverySeconds = 9,
	WaveFuelDrain = 10,
	WaveTowerDamage = 15,
	StunAfterBeamHitSeconds = 3,
	EyeBeamDamagePerSecond = 45,
	EyeHalfWidthDegrees = 9,
	MaxStormSeconds = 240, -- if not beaten by then, it sinks back without a reward
}

---------------------------------------------------------------------------
-- Tower, building and combat
---------------------------------------------------------------------------
Config.Tower = {
	Floors = { "GroundFloor", "BunkRoom", "LampRoom" },
	FloorMaxHealth = 200,
	RepairAmount = 20,
	RepairCooldown = 0.8,
	BarricadeHealth = 120,
	BarricadeWoodCost = 3,
	BarricadeRepairAmount = 30,
}

Config.Combat = {
	HarpoonDamage = 25,
	HarpoonRange = 32,
	HarpoonConeDegrees = 45,
	HarpoonCooldown = 0.6,
	HammerRange = 24,
}

---------------------------------------------------------------------------
-- Resources
---------------------------------------------------------------------------
Config.Resources = {
	Kinds = { "Wood", "Scrap", "Oil", "Fish" },
	StartStorage = { Wood = 6, Scrap = 2, Oil = 1, Fish = 1 },
	WreckagePerDawn = { Scrap = 3, Oil = 2, Wood = 3 },
	MaxGroundItems = 30,
	SupplyCrateChance = 0.25,
	TreeRegrowSeconds = 45,
	FishCooldownSeconds = 15,
	FishHeal = 35,
	CarryWalkSpeed = 12,
	WalkSpeed = 16,
}

---------------------------------------------------------------------------
-- Players and progress
---------------------------------------------------------------------------
Config.Player = {
	CalmRespawnSeconds = 5,
}

Config.Progress = {
	XPPerStorm = 10,
	XPPerLevel = 100,
	DataStoreName = "PlayerData_v1",
	AutosaveSeconds = 120,
	-- Create the badges on the Creator Hub, then paste their IDs here (0 = off)
	Badges = {
		Storm10 = 0,
		Storm20 = 0,
	},
}

---------------------------------------------------------------------------
-- Look of each phase (client FogController)
---------------------------------------------------------------------------
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
	Lost = {
		ClockTime = 19,
		Brightness = 0.3,
		Ambient = Color3.fromRGB(30, 30, 40),
		FogDensity = 0.8,
		FogHaze = 8,
		FogColor = Color3.fromRGB(50, 55, 65),
	},
}

Config.LookTweenSeconds = {
	Calm = 6,
	Warning = 10,
	Storm = 6,
	Dawn = 4,
	Won = 6,
	Lost = 3,
}

return Config
