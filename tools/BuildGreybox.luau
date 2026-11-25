-- The Last Lighthouse: greybox builder
--
-- How to run: open the place in Studio, open View > Command Bar,
-- paste this whole file in and press Enter.
-- It deletes and rebuilds Workspace.Map, so it is safe to run again.
--
-- Layout (1 stud = 1 unit, sea level y = 0):
--   Lighthouse cliff  north-east  (55, 35, -80)  tower on top, ramp down to the south
--   Pine grove        west        (-70, 5, -20)
--   Wreck Beach       south-west  (-95, 3, 95)
--   Tide pools        east        (110, 3, 40)
--   Old dock          south       (-20, 4, 165)  opens at storm 5

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local recording = ChangeHistoryService:TryBeginRecording("Build Last Lighthouse greybox")

local oldMap = Workspace:FindFirstChild("Map")
if oldMap then
	oldMap:Destroy()
end
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

local rng = Random.new(1847) -- fixed seed: rebuilds look the same

local C = {
	sand = Color3.fromRGB(214, 196, 150),
	grass = Color3.fromRGB(88, 120, 72),
	rock = Color3.fromRGB(105, 105, 112),
	wood = Color3.fromRGB(125, 92, 62),
	darkWood = Color3.fromRGB(82, 60, 42),
	white = Color3.fromRGB(236, 233, 226),
	red = Color3.fromRGB(170, 45, 40),
	pine = Color3.fromRGB(45, 82, 56),
	pool = Color3.fromRGB(60, 125, 145),
	metal = Color3.fromRGB(92, 97, 104),
	lamp = Color3.fromRGB(255, 221, 140),
	glass = Color3.fromRGB(190, 220, 235),
}
local M = Enum.Material

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in pairs(props) do
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Upright cylinder: height along Y
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function cylinder(parent, name, height, diameter, pos, color, material, props)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * UPRIGHT, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function zone(parent, name, size, pos, attrs)
	local cf = if typeof(pos) == "CFrame" then pos else CFrame.new(pos)
	local z = part(parent, name, size, cf, Color3.new(1, 1, 1), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	if attrs then
		for key, value in pairs(attrs) do
			z:SetAttribute(key, value)
		end
	end
	return z
end

local map = Instance.new("Folder")
map.Name = "Map"

---------------------------------------------------------------------------
-- Sea (terrain water) and island base
---------------------------------------------------------------------------
local terrain = Workspace.Terrain
terrain:Clear()
terrain:FillBlock(CFrame.new(0, -30, 0), Vector3.new(1200, 12, 1200), M.Sand) -- seabed
terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(1200, 24, 1200), M.Water) -- surface at y = 0

local island = folder("Island", map)
cylinder(island, "Beach", 8, 300, Vector3.new(0, -1, 0), C.sand, M.Sand) -- top y = 3
cylinder(island, "Grass", 6, 220, Vector3.new(-10, 2, -15), C.grass, M.Grass) -- top y = 5

---------------------------------------------------------------------------
-- Lighthouse cliff + ramp
---------------------------------------------------------------------------
local cliff = folder("LighthouseCliff", map)
part(cliff, "Cliff", Vector3.new(70, 40, 70), CFrame.new(55, 15, -80), C.rock, M.Slate) -- top y = 35
part(cliff, "CliffRockA", Vector3.new(30, 28, 26), CFrame.new(95, 9, -60) * CFrame.Angles(0, math.rad(20), 0), C.rock, M.Slate)
part(cliff, "CliffRockB", Vector3.new(26, 22, 30), CFrame.new(20, 6, -110) * CFrame.Angles(0, math.rad(-15), 0), C.rock, M.Slate)
-- Ramp from the grass (south) up to the cliff top. High end faces the cliff.
local ramp = Instance.new("WedgePart")
ramp.Name = "Ramp"
ramp.Anchored = true
ramp.Size = Vector3.new(16, 30, 80)
ramp.CFrame = CFrame.new(55, 20, 5) * CFrame.Angles(0, math.rad(180), 0)
ramp.Color = C.rock
ramp.Material = M.Slate
ramp.Parent = cliff

---------------------------------------------------------------------------
-- The lighthouse: 3 floors, each a Model (health bars come later)
---------------------------------------------------------------------------
local TOWER = Vector3.new(55, 35, -80) -- centre of the tower's base, on the cliff top
local lighthouse = model("Lighthouse", map)

local function at(x, y, z)
	return CFrame.new(TOWER + Vector3.new(x, y, z))
end

-- Floor slab with a 4x4 ladder hole in the -X/-Z corner
local function slab(parent, baseY, color, withHole)
	if withHole then
		part(parent, "Floor", Vector3.new(26, 1, 21), at(0, baseY + 0.5, 2.5), color, M.WoodPlanks)
		part(parent, "FloorEdge", Vector3.new(21, 1, 5), at(2.5, baseY + 0.5, -10.5), color, M.WoodPlanks)
	else
		part(parent, "Floor", Vector3.new(26, 1, 26), at(0, baseY + 0.5, 0), color, M.WoodPlanks)
	end
end

-- Four walls, optional doorway in the south (+Z) wall
local function walls(parent, baseY, height, color, material, transparency, door)
	local h = height - 1
	local y = baseY + 1 + h / 2
	local props = { Transparency = transparency }
	part(parent, "WallNorth", Vector3.new(26, h, 1), at(0, y, -12.5), color, material, props)
	part(parent, "WallEast", Vector3.new(1, h, 24), at(12.5, y, 0), color, material, props)
	part(parent, "WallWest", Vector3.new(1, h, 24), at(-12.5, y, 0), color, material, props)
	if door then
		local doorH = 10
		part(parent, "WallSouthLeft", Vector3.new(10, h, 1), at(-8, y, 12.5), color, material, props)
		part(parent, "WallSouthRight", Vector3.new(10, h, 1), at(8, y, 12.5), color, material, props)
		part(parent, "WallSouthTop", Vector3.new(6, h - doorH, 1), at(0, baseY + 1 + doorH + (h - doorH) / 2, 12.5), color, material, props)
	else
		part(parent, "WallSouth", Vector3.new(26, h, 1), at(0, y, 12.5), color, material, props)
	end
end

local function ladder(parent, baseY, height)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Anchored = true
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = at(-11, baseY + 1 + height / 2, -11)
	truss.Color = C.metal
	truss.Parent = parent
	return truss
end

-- Ground floor: storage, crafting bench, the door
local ground = model("GroundFloor", lighthouse)
slab(ground, 0, C.darkWood, false)
walls(ground, 0, 16, C.white, M.Concrete, 0, true)
ladder(ground, 0, 16)
part(ground, "CraftingBench", Vector3.new(8, 3, 4), at(6, 2.5, -9), C.wood, M.Wood)
part(ground, "StorageCrateA", Vector3.new(4, 4, 4), at(9, 3, 4), C.wood, M.WoodPlanks)
part(ground, "StorageCrateB", Vector3.new(4, 4, 4), at(9, 3, -1), C.wood, M.WoodPlanks)
zone(ground, "StorageZone", Vector3.new(8, 6, 12), at(8, 4, 2))

-- Bunk room: respawn point and food storage
local bunk = model("BunkRoom", lighthouse)
slab(bunk, 16, C.darkWood, true)
walls(bunk, 16, 16, C.red, M.Concrete, 0, false)
ladder(bunk, 16, 16)
part(bunk, "BunkA", Vector3.new(4, 2, 8), at(8, 18, -6), C.wood, M.Fabric)
part(bunk, "BunkB", Vector3.new(4, 2, 8), at(8, 18, 6), C.wood, M.Fabric)
part(bunk, "FoodStorage", Vector3.new(4, 3, 3), at(-8, 18.5, 8), C.wood, M.WoodPlanks)
local spawnPad = Workspace:FindFirstChildOfClass("SpawnLocation") or Instance.new("SpawnLocation")
spawnPad.Name = "BunkSpawn"
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(6, 1, 6)
spawnPad.CFrame = at(0, 17.5, 2)
spawnPad.Color = C.wood
spawnPad.Material = M.Fabric
spawnPad.Duration = 0
spawnPad.Parent = bunk

-- Lamp room: the lamp and the fuel tank
local lampRoom = model("LampRoom", lighthouse)
slab(lampRoom, 32, C.metal, true)
walls(lampRoom, 32, 12, C.glass, M.Glass, 0.6, false)
cylinder(lampRoom, "LampPedestal", 4, 6, TOWER + Vector3.new(0, 35, 0), C.metal, M.Metal)
local lamp = part(lampRoom, "Lamp", Vector3.new(6, 6, 6), at(0, 40, 0), C.lamp, M.Neon)
lamp.Shape = Enum.PartType.Ball
local glow = Instance.new("PointLight")
glow.Name = "LampLight"
glow.Range = 60
glow.Brightness = 3
glow.Color = C.lamp
glow.Shadows = true
glow.Parent = lamp
cylinder(lampRoom, "FuelTank", 6, 4, TOWER + Vector3.new(8, 36, 8), C.metal, M.DiamondPlate)

-- Roof
local roof = model("Roof", lighthouse)
part(roof, "RoofSlab", Vector3.new(28, 1, 28), at(0, 44.5, 0), C.red, M.Metal)
cylinder(roof, "RoofCap", 4, 20, TOWER + Vector3.new(0, 47, 0), C.red, M.Metal)
cylinder(roof, "Spire", 6, 1, TOWER + Vector3.new(0, 52, 0), C.metal, M.Metal)

-- Outside the door: where barricades and lamp posts will go later
zone(lighthouse, "SafeCircleCenter", Vector3.new(2, 2, 2), TOWER + Vector3.new(0, 40, 0))

---------------------------------------------------------------------------
-- Pine grove: wood, rope plants, hidden chests
---------------------------------------------------------------------------
local grove = folder("PineGrove", map)
local GROVE = Vector3.new(-70, 5, -20)
for i = 1, 16 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(6, 42)
	local base = GROVE + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
	local h = rng:NextNumber(18, 28)
	local tree = model(`Pine{i}`, grove)
	cylinder(tree, "Trunk", h, 2.4, base + Vector3.new(0, h / 2, 0), C.darkWood, M.Wood)
	cylinder(tree, "NeedlesLow", h * 0.3, h * 0.45, base + Vector3.new(0, h * 0.45, 0), C.pine, M.Grass)
	cylinder(tree, "NeedlesMid", h * 0.25, h * 0.32, base + Vector3.new(0, h * 0.68, 0), C.pine, M.Grass)
	cylinder(tree, "NeedlesTop", h * 0.2, h * 0.18, base + Vector3.new(0, h * 0.88, 0), C.pine, M.Grass)
	tree:SetAttribute("Resource", "Wood")
end
for i = 1, 5 do
	local pos = GROVE + Vector3.new(rng:NextNumber(-35, 35), 0.75, rng:NextNumber(-35, 35))
	local plant = part(grove, `RopePlant{i}`, Vector3.new(2, 1.5, 2), CFrame.new(pos), Color3.fromRGB(120, 140, 70), M.Grass)
	plant:SetAttribute("Resource", "Rope")
end
part(grove, "HiddenChestA", Vector3.new(3, 2, 2), CFrame.new(GROVE + Vector3.new(-38, 1, 12)), C.wood, M.WoodPlanks)
part(grove, "HiddenChestB", Vector3.new(3, 2, 2), CFrame.new(GROVE + Vector3.new(18, 1, -40)), C.wood, M.WoodPlanks)

---------------------------------------------------------------------------
-- Wreck Beach: wreckage washes up here; the Drowned climb out here
---------------------------------------------------------------------------
local beach = folder("WreckBeach", map)
local WRECK = Vector3.new(-95, 3, 95)
for i = 1, 8 do
	local pos = WRECK + Vector3.new(rng:NextNumber(-22, 22), 0.4, rng:NextNumber(-22, 22))
	part(beach, `Plank{i}`, Vector3.new(rng:NextNumber(6, 12), 0.8, 1.6), CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-8, 8))), C.wood, M.WoodPlanks)
end
for i = 1, 3 do
	local pos = WRECK + Vector3.new(rng:NextNumber(-18, 18), 2.5, rng:NextNumber(-18, 18))
	local barrel = cylinder(beach, `OilBarrel{i}`, 4, 3, pos, Color3.fromRGB(70, 60, 45), M.Metal)
	barrel:SetAttribute("Resource", "Oil")
end
part(beach, "WreckCrate", Vector3.new(4, 4, 4), CFrame.new(WRECK + Vector3.new(6, 2, -8)) * CFrame.Angles(0, math.rad(25), 0), C.wood, M.WoodPlanks)
part(beach, "BrokenHull", Vector3.new(18, 6, 8), CFrame.new(WRECK + Vector3.new(-14, 1.5, 26)) * CFrame.Angles(math.rad(-14), math.rad(35), math.rad(10)), C.darkWood, M.WoodPlanks)
zone(beach, "WreckageSpawnZone", Vector3.new(50, 4, 50), WRECK + Vector3.new(0, 2, 0), { Purpose = "Wreckage" })
zone(beach, "DrownedSpawnZone", Vector3.new(60, 4, 12), WRECK + Vector3.new(-10, 0, 45), { Purpose = "DrownedSpawn" })

---------------------------------------------------------------------------
-- Tide pools: fish, crabs, shells
---------------------------------------------------------------------------
local pools = folder("TidePools", map)
local POOLS = Vector3.new(110, 3, 40)
for i = 1, 5 do
	local pos = POOLS + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20))
	local d = rng:NextNumber(6, 11)
	local pool = cylinder(pools, `Pool{i}`, 0.6, d, pos + Vector3.new(0, 0.1, 0), C.pool, M.Glass, { Transparency = 0.25, CanCollide = false })
	pool:SetAttribute("Resource", "Fish")
	for r = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local rockPos = pos + Vector3.new(math.cos(a) * d * 0.55, 0.8, math.sin(a) * d * 0.55)
		part(pools, `Pool{i}Rock{r}`, Vector3.new(rng:NextNumber(1.5, 3), rng:NextNumber(1, 2), rng:NextNumber(1.5, 3)), CFrame.new(rockPos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), C.rock, M.Slate)
	end
end

---------------------------------------------------------------------------
-- Old dock: fishing spot, rowboat build spot (opens at storm 5)
---------------------------------------------------------------------------
local dock = folder("OldDock", map)
dock:SetAttribute("UnlockStorm", 5)
local DOCK_X = -20
part(dock, "Deck", Vector3.new(10, 1, 60), CFrame.new(DOCK_X, 3.5, 165), C.wood, M.WoodPlanks)
for z = 140, 190, 10 do
	for _, side in ipairs({ -4.5, 4.5 }) do
		cylinder(dock, `Post_{z}_{side}`, 28, 1.4, Vector3.new(DOCK_X + side, -10.5, z), C.darkWood, M.Wood)
	end
end
zone(dock, "FishingSpot", Vector3.new(10, 4, 6), Vector3.new(DOCK_X, 6, 192), { Purpose = "Fishing" })
zone(dock, "RowboatBuildSpot", Vector3.new(8, 4, 14), Vector3.new(DOCK_X + 10, 1, 178), { Purpose = "Rowboat" })

---------------------------------------------------------------------------
-- Fog edge marker: the fog wall starts here and creeps in every 10 storms
---------------------------------------------------------------------------
local fog = folder("Fog", map)
zone(fog, "FogEdge", Vector3.new(2, 2, 2), Vector3.new(0, 0, 0), { StartRadius = 230, ShrinkPer10Storms = 8 })

map.Parent = Workspace

Workspace:SetAttribute("DebugFastCycle", Workspace:GetAttribute("DebugFastCycle") or false)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print("[Greybox] Built Workspace.Map")
