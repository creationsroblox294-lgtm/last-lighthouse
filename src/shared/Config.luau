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
	IslandCenter = Vector3.new(10, 3, 190), -- the island is twice as wide again (tools/MapScale.luau)
	IslandRadius = 620,
	TowerCenter = Vector3.new(-10, 6.8, 150), -- base of the tower, in the middle of the island
	LampPosition = Vector3.new(-10, 95.4, 150),
	RampBottom = Vector3.new(-10, 7, 190), -- path in front of the door (supply drops land here)
	RampTop = Vector3.new(-10, 8, 174),
	DoorFront = Vector3.new(-10, 8.3, 162),
	CliffTopY = 1000, -- no cliff: disables the old ramp routing
	IntroBeach = Vector3.new(-10, 8, 714), -- where you wash up after the intro cutscene (south beach)
	BossPosition = Vector3.new(90, 0, -500), -- open sea north of the tower, clear of the dock
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
	BeamRange = 640, -- the tower is inland now: the beam has to reach the sea
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
	MaxAlive = 60,
	SpawnInterval = 1.6,
	SwarmSpawnInterval = 0.8,
	SpawnRadius = 280, -- creatures walk out of the fog this far from the lighthouse
	PlayerScale = 0.35, -- each extra player adds 35% more creatures (fuel drain doesn't change)
	-- every storm keeps all the creatures from earlier storms and adds the next kind
	Order = { "FogCrawler", "Drowned", "NightGull", "FogMimic", "LastKeeper" },
	FogCrawler = {
		Health = 30,
		Speed = 15,
		Damage = 10,
		AttackRange = 5,
		AttackCooldown = 1,
		LightDamagePerSecond = 30,
		FirstStorm = 1,
		CountBase = 8,
		CountPerStorm = 1.5,
	},
	Drowned = {
		Health = 140,
		Speed = 8,
		Damage = 14,
		AttackRange = 6,
		AttackCooldown = 1.5,
		LightSlowFactor = 0.5,
		StructureDamage = 12,
		FirstStorm = 2,
		CountBase = 2,
		CountPerStorm = 0.5,
	},
	NightGull = { -- circles high up, dives at anyone outside the light
		Health = 40,
		Speed = 22,
		Damage = 8,
		AttackRange = 6,
		AttackCooldown = 1.2,
		LightDamagePerSecond = 20,
		FlyHeight = 16,
		DiveRange = 40,
		FirstStorm = 3,
		CountBase = 3,
		CountPerStorm = 0.5,
	},
	FogMimic = { -- looks like a lost survivor until you get close
		Health = 70,
		Speed = 9,
		RevealSpeed = 20,
		Damage = 18,
		AttackRange = 5,
		AttackCooldown = 1.4,
		LightDamagePerSecond = 15,
		RevealRange = 16,
		FirstStorm = 4,
		CountBase = 2,
		CountPerStorm = 0.3,
	},
	LastKeeper = { -- a drowned keeper with a lantern: tough, slow, calls crawlers out of the fog
		Health = 450,
		Speed = 7,
		Damage = 28,
		StructureDamage = 30,
		AttackRange = 7,
		AttackCooldown = 2.2,
		LightSlowFactor = 0.6,
		SummonEvery = 14,
		SummonCount = 2,
		FirstStorm = 5,
		CountBase = 1,
		CountPerStorm = 0.2,
	},
}

-- The Hollow: a stalker between storms (see HollowService)
Config.Hollow = {
	ArrivesAfterStorm = 6, -- first appears after storm 6 (one new threat every storm)
	MinInterval = 240, -- seconds between appearances
	MaxInterval = 480,
	EmergeSeconds = 3,
	GiveUpSeconds = 25, -- nobody outside the light: it leaves
	StalkSpeed = 9,
	RunSpeed = 21,
	DragSpeed = 8,
	HuntDistance = 45,
	GrabRange = 4.5,
	FogEdgeRadius = 320,
	LightSafeFuelFraction = 0.5, -- the lit area protects you only above half fuel
	HitsToDriveOff = 3,
	StrugglesToEscape = 12,
	FlareRange = 45,
	FlareCooldown = 40,
	Lairs = {
		Vector3.new(-140, 6, -210), -- grove
		Vector3.new(-46, 3, 130), -- dock
		Vector3.new(-208, 4, 92), -- wreck beach
		Vector3.new(250, 4, -110), -- tide pools
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
	-- fists: click / tap with nothing in your hands (PunchService)
	PunchDamage = 12,
	PunchRange = 6.5,
	PunchConeDegrees = 60,
	PunchCooldown = 0.4,
	-- right / left jab animations (R15), played alternately
	PunchAnimations = { "rbxassetid://102482521330056", "rbxassetid://136704472801616" },
	HarpoonDamage = 25,
	HarpoonRange = 32,
	HarpoonConeDegrees = 45,
	HarpoonCooldown = 0.6,
	HammerRange = 24,
}

---------------------------------------------------------------------------
-- Resources
---------------------------------------------------------------------------
-- Fish swimming in the sea around the island (FishService). Wade in or stand on the dock to catch them.
Config.Fish = {
	PerSchool = 5,
	RespawnSeconds = 25,
	CatchDistance = 12,
	SwimSpeed = 3,
	Depth = -1.6, -- just under the surface (water level is 0)
	-- school centres are set from Map.FishingWaters parts if present, else these
	Schools = {
		Vector3.new(-50, 0, -500), -- off the lighthouse dock
		Vector3.new(40, 0, -470),
		Vector3.new(-230, 0, -360),
		Vector3.new(350, 0, -270),
	},
}

Config.Resources = {
	Kinds = { "Wood", "Scrap", "Oil", "Fish" },
	StartStorage = { Wood = 6, Scrap = 2, Oil = 1, Fish = 1 },
	WreckagePerDawn = { Scrap = 3, Oil = 2, Wood = 3 },
	MaxGroundItems = 30,
	SupplyCrateChance = 0.25,
	TreeRegrowSeconds = 45,
	PunchesPerTree = 5, -- punches to knock a piece of wood off a tree
	FishCooldownSeconds = 15,
	FishHeal = 35,
	CookSeconds = 1.5, -- hold time at the fireplace
	CarryWalkSpeed = 12,
	WalkSpeed = 16,
}

-- Snakes, spiders and bats that drop out of the trees (TreeAnimalService)
Config.TreeAnimals = {
	FirstDelay = 40, -- seconds after joining before the first one
	MinInterval = 25, -- per player, between attempts
	MaxInterval = 50,
	TreeSearchRadius = 28, -- a tree this close to the player is needed
	SafeRadius = 45, -- none in the lighthouse yard
	LatchedWalkSpeed = 9,
	FleeDistance = 22,
	FleeSeconds = 2.5,
	Kinds = {
		Snake = { Weight = 3, WarnSeconds = 1.2, DropSeconds = 0.55, CatchRadius = 3.2, PerchOut = 2, DamagePerSecond = 6, LatchSeconds = 6, Shakes = 8 },
		Spider = { Weight = 3, WarnSeconds = 1.0, DropSeconds = 0.45, CatchRadius = 3.0, PerchOut = 1.5, DamagePerSecond = 5, LatchSeconds = 5, Shakes = 6 },
		Bat = { Weight = 2, WarnSeconds = 0.9, DropSeconds = 0.7, CatchRadius = 3.5, PerchOut = 3, DamagePerSecond = 4, LatchSeconds = 5, Shakes = 6 },
	},
}

-- Intro cutscene: played live in the engine with the player's own avatar (IntroController).
-- The Blender render of the same story is Cutscene_Intro.blend / IntroCutscene.mp4.
Config.Intro = {
	Enabled = true,
	FilmSet = Vector3.new(10, 10, 820), -- streamed in around here while the intro plays (sea, south beach, tower)
	-- R15 clips made with Studio's animation generator; R6 avatars fall back to the idle
	Animations = {
		Row = "rbxassetid://84418772295112", -- seated, rowing at sunset
		Brace = "rbxassetid://135528348986313", -- seated, gripping the sides in the storm
		GetUp = "rbxassetid://118813339032476", -- face down on the sand, pushes up, stands
		IdleR15 = "rbxassetid://507766388",
		IdleR6 = "rbxassetid://180435571",
	},
}

-- Minimap (MinimapController): a top-down render of the island (tools/stitch_map.py).
-- The image covers the world square MinX..MinX+Span, MinZ..MinZ+Span, north (-Z) up.
Config.Minimap = {
	Image = "rbxassetid://104506668850944",
	ImageSize = 1024, -- pixels
	MinX = -1050,
	MinZ = -900,
	Span = 2100,
	Zoom = 5, -- the corner map shows Span / Zoom = 420 studs across
}

-- Hold Shift to sprint (SprintService / SprintController)
Config.Sprint = {
	Multiplier = 1.65, -- 16 -> ~26 studs/s
	MaxStamina = 100,
	DrainPerSecond = 14, -- about 7 seconds of running from full
	RegenPerSecond = 20,
	RegenDelay = 0.8, -- seconds after you stop before stamina comes back
	MinToStart = 20, -- after running dry you need this much to sprint again
}

-- Forage plants (Map.Forage): pick and eat on the spot
Config.Forage = {
	Heal = { Carrot = 12, Berries = 8, Apple = 12, Mushroom = 6, Pumpkin = 18 },
	RegrowSeconds = 90,
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
		ClockTime = 13,
		Brightness = 3.4,
		Exposure = 0.35,
		Ambient = Color3.fromRGB(150, 155, 160),
		FogDensity = 0.12, -- the island is big: keep the tower visible from the shore
		FogHaze = 0.15,
		FogColor = Color3.fromRGB(215, 225, 232),
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
		ClockTime = 7.4,
		Brightness = 2.6,
		Exposure = 0.25,
		Ambient = Color3.fromRGB(150, 135, 125),
		FogDensity = 0.18,
		FogHaze = 0.8,
		FogColor = Color3.fromRGB(230, 190, 160),
	},
	Won = {
		ClockTime = 13,
		Brightness = 3.4,
		Exposure = 0.35,
		Ambient = Color3.fromRGB(150, 155, 160),
		FogDensity = 0.14,
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

-- UI art (ForgeGUI pieces cut out by tools/forge_cutout.py, see assets/ui). Slice rects are
-- in image pixels: left, top, right, bottom of the stretchable middle.
Config.UI = {
	Panel = "rbxassetid://116537048370739",
	PanelSlice = { 80, 55, 944, 175 },
	PanelHeight = 222,
	Bar = "rbxassetid://70671316398304",
	BarSlice = { 130, 75, 894, 155 },
	BarHeight = 229,
	BarInset = { 106, 60, 106, 57 },
	Porthole = "rbxassetid://116033756945071",
	PortholeHole = { 0.4874, 0.4954, 0.3341 }, -- opening centre x, y and radius (fractions of width)
	Close = "rbxassetid://106544436890645",
	Scroll = "rbxassetid://120339115701712",
	Title = "rbxassetid://71480370745486",
}

return Config
