--!strict
-- Builds the crafting table on the lighthouse's ground floor, against the east wall under the
-- window: a heavy plank workbench with a vise, a lantern, tools, scrap and a half-made harpoon
-- head on top, and rope and scrap on the shelf below. Run in Studio (command bar / MCP).
-- CraftingService finds it as Map.Lighthouse.GroundFloor.CraftingTable and puts the prompt on "Top".

local ground = workspace.Map.Lighthouse.GroundFloor
local old = ground:FindFirstChild("CraftingTable")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "CraftingTable"

local FLOOR = 8.0 -- top of the ground floor
local CX, CZ = 0.67, 149 -- bench centre; its length runs along Z, the front faces -X (the room)
local LEN, DEPTH, HEIGHT = 5.2, 2.6, 3.05

local OAK = Color3.fromRGB(122, 86, 54)
local DARK_OAK = Color3.fromRGB(86, 58, 36)
local IRON = Color3.fromRGB(62, 64, 70)
local STEEL = Color3.fromRGB(150, 156, 164)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(CX + x, FLOOR + y, CZ + z)
end
local function deco(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

-- the bench
local top = part("Top", Vector3.new(DEPTH, 0.36, LEN), at(0, HEIGHT - 0.18, 0), OAK, Enum.Material.Wood)
for i, x in { -0.86, 0, 0.86 } do
	-- plank seams
	deco(part("Seam" .. i, Vector3.new(0.04, 0.02, LEN - 0.02), at(x + 0.43, HEIGHT + 0.005, 0), DARK_OAK, Enum.Material.Wood))
end
for _, x in { -1.05, 1.05 } do
	for _, z in { -2.25, 2.25 } do
		part("Leg", Vector3.new(0.42, HEIGHT - 0.36, 0.42), at(x, (HEIGHT - 0.36) / 2, z), DARK_OAK, Enum.Material.Wood)
	end
end
part("Apron", Vector3.new(0.14, 0.42, LEN - 0.3), at(-1.2, HEIGHT - 0.57, 0), DARK_OAK, Enum.Material.Wood)
part("Shelf", Vector3.new(DEPTH - 0.5, 0.16, LEN - 0.6), at(0, 0.62, 0), OAK, Enum.Material.Wood)
for _, z in { -2.25, 2.25 } do
	part("Stretcher", Vector3.new(DEPTH - 0.3, 0.22, 0.22), at(0, 0.62, z), DARK_OAK, Enum.Material.Wood)
end

-- vise on the front corner
local vy = HEIGHT + 0.22
part("ViseBody", Vector3.new(0.6, 0.42, 0.62), at(-1.0, vy, 2.05), IRON, Enum.Material.Metal)
part("ViseJaw", Vector3.new(0.18, 0.42, 0.62), at(-1.48, vy, 2.05), IRON, Enum.Material.Metal)
deco(part("ViseScrew", Vector3.new(0.7, 0.1, 0.1), at(-1.75, vy - 0.05, 2.05), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder))
deco(part("ViseHandle", Vector3.new(0.07, 0.07, 0.8), at(-2.05, vy - 0.05, 2.05), STEEL, Enum.Material.Metal))
-- a harpoon head clamped in the vise, half made
deco(part("HarpoonBlank", Vector3.new(0.12, 0.7, 0.16), at(-1.24, vy + 0.5, 2.05) * CFrame.Angles(0, 0, math.rad(8)), STEEL, Enum.Material.Metal))
local barb = part("HarpoonBarb", Vector3.new(0.08, 0.3, 0.3), at(-1.2, vy + 0.82, 2.05) * CFrame.Angles(math.rad(45), 0, 0), STEEL, Enum.Material.Metal)
deco(barb)

-- tools and odds and ends on top
local y0 = HEIGHT
deco(part("SawBlade", Vector3.new(0.9, 0.03, 2.0), at(0.2, y0 + 0.02, -1.4) * CFrame.Angles(0, math.rad(18), 0), STEEL, Enum.Material.Metal))
deco(part("SawHandle", Vector3.new(0.5, 0.12, 0.55), at(0.36, y0 + 0.06, -0.32) * CFrame.Angles(0, math.rad(18), 0), DARK_OAK, Enum.Material.Wood))
deco(part("MalletHead", Vector3.new(0.75, 0.38, 0.38), at(-0.4, y0 + 0.19, 0.55), Color3.fromRGB(150, 110, 70), Enum.Material.Wood, Enum.PartType.Cylinder))
deco(part("MalletShaft", Vector3.new(0.09, 0.09, 1.1), at(-0.4, y0 + 0.08, 1.15), DARK_OAK, Enum.Material.Wood))
deco(part("PlaneBody", Vector3.new(0.4, 0.28, 1.0), at(0.75, y0 + 0.14, 0.9), Color3.fromRGB(140, 100, 62), Enum.Material.Wood))
deco(part("PlaneKnob", Vector3.new(0.22, 0.22, 0.22), at(0.75, y0 + 0.36, 0.6), DARK_OAK, Enum.Material.Wood, Enum.PartType.Ball))
deco(part("PlaneBlade", Vector3.new(0.3, 0.06, 0.12), at(0.75, y0 + 0.31, 0.95) * CFrame.Angles(math.rad(-40), 0, 0), STEEL, Enum.Material.Metal))
for i = 1, 3 do
	-- scrap plates waiting to be beaten into shape
	deco(part("ScrapPlate" .. i, Vector3.new(0.7 - i * 0.08, 0.05, 0.8 - i * 0.1), at(0.6 + i * 0.03, y0 + 0.03 + i * 0.05, -0.5 + i * 0.05) * CFrame.Angles(0, math.rad(i * 23), 0), Color3.fromRGB(112, 104, 96), Enum.Material.CorrodedMetal))
end
for i = 1, 6 do
	deco(part("Nail" .. i, Vector3.new(0.32, 0.04, 0.04), at(-0.7 + (i % 3) * 0.12, y0 + 0.02, -0.4 + i * 0.07) * CFrame.Angles(0, math.rad(i * 37), 0), STEEL, Enum.Material.Metal))
end
-- a sketch of the next lens, weighed down by the nails
local paper = part("Plan", Vector3.new(0.9, 0.02, 1.2), at(-0.55, y0 + 0.012, -1.1) * CFrame.Angles(0, math.rad(-8), 0), Color3.fromRGB(226, 212, 178), Enum.Material.SmoothPlastic)
deco(paper)

-- lantern at the back corner: the bench's own warm light
local lanternBase = part("LanternBase", Vector3.new(0.5, 0.08, 0.5), at(0.9, y0 + 0.04, -2.1), IRON, Enum.Material.Metal)
deco(lanternBase)
local glass = part("LanternGlass", Vector3.new(0.4, 0.6, 0.4), at(0.9, y0 + 0.38, -2.1), Color3.fromRGB(255, 196, 120), Enum.Material.Glass)
glass.Transparency = 0.35
deco(glass)
local flame = part("LanternFlame", Vector3.new(0.12, 0.22, 0.12), at(0.9, y0 + 0.32, -2.1), Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
deco(flame)
deco(part("LanternCap", Vector3.new(0.5, 0.1, 0.5), at(0.9, y0 + 0.73, -2.1), IRON, Enum.Material.Metal))
deco(part("LanternRing", Vector3.new(0.05, 0.3, 0.3), at(0.9, y0 + 0.9, -2.1), IRON, Enum.Material.Metal, Enum.PartType.Cylinder))
local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(255, 180, 110)
light.Brightness = 1.6
light.Range = 12
light.Shadows = true
light.Parent = flame

-- on the shelf: a rope coil, scrap and a small keg
deco(part("RopeCoil", Vector3.new(0.3, 1.1, 1.1), at(-0.2, 0.86, -1.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 168, 120), Enum.Material.Fabric, Enum.PartType.Cylinder))
deco(part("RopeHole", Vector3.new(0.32, 0.5, 0.5), at(-0.2, 0.87, -1.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 52, 34), Enum.Material.Fabric, Enum.PartType.Cylinder))
deco(part("ShelfScrap", Vector3.new(0.9, 0.3, 0.7), at(0.3, 0.85, 0.3) * CFrame.Angles(0, math.rad(20), math.rad(6)), Color3.fromRGB(112, 104, 96), Enum.Material.CorrodedMetal))
deco(part("Keg", Vector3.new(1.0, 0.75, 0.75), at(0.1, 1.08, 1.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 76, 46), Enum.Material.Wood, Enum.PartType.Cylinder))
for _, dy in { -0.3, 0.3 } do
	deco(part("KegHoop", Vector3.new(0.08, 0.8, 0.8), at(0.1, 1.08 + dy, 1.5) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.Metal, Enum.PartType.Cylinder))
end

-- wood shavings on the floor in front
for i = 1, 7 do
	local s = part("Shaving" .. i, Vector3.new(0.25, 0.02, 0.12), at(-1.6 - (i % 3) * 0.35, 0.01, -1.6 + i * 0.45) * CFrame.Angles(0, math.rad(i * 51), 0), Color3.fromRGB(214, 176, 124), Enum.Material.Wood)
	deco(s)
end

model.PrimaryPart = top
model.Parent = ground
return "built CraftingTable with " .. #model:GetChildren() .. " parts"
