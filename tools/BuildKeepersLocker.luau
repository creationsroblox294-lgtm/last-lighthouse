--!strict
-- Builds the Keeper's Locker in the harbor: a covered market stall by the spawn, with a counter
-- (KeeperService puts the "Open" prompt on Lobby.KeepersLocker.Counter), a striped awning, a
-- carved sign, the four lanterns lit up on a shelf, an oilskin coat on a peg and a chest of brass.
-- Run in Studio (command bar / MCP), then tools/PropsPass.luau to swap in the Blender ship lanterns.

local lobby = workspace.Lobby
local old = lobby:FindFirstChild("KeepersLocker")
if old then
	old:Destroy()
end
local model = Instance.new("Model")
model.Name = "KeepersLocker"

local SPOT = Vector3.new(3338, 0, -21) -- beside the walk from the spawn to the dock, clear of the lamp posts
local hit = workspace:Raycast(SPOT + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0))
local groundY = if hit then hit.Position.Y else 6.5
-- the stall faces +Z, toward the path
local base = CFrame.new(SPOT.X, groundY, SPOT.Z)

local OAK = Color3.fromRGB(116, 80, 50)
local DARK = Color3.fromRGB(70, 46, 30)
local BRASS = Color3.fromRGB(200, 156, 72)
local NAVY = Color3.fromRGB(34, 52, 86)
local CREAM = Color3.fromRGB(232, 220, 190)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = base * cf
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
local function deco(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

-- floor and frame
part("Deck", Vector3.new(11, 0.5, 7), CFrame.new(0, 0.25, 0), OAK, Enum.Material.WoodPlanks)
for _, x in { -5.2, 5.2 } do
	for _, z in { -3.2, 3.2 } do
		part("Post", Vector3.new(0.55, 9, 0.55), CFrame.new(x, 4.75, z), DARK, Enum.Material.Wood)
	end
end
part("BackWall", Vector3.new(10.4, 7.5, 0.35), CFrame.new(0, 4.25, -3.1), OAK, Enum.Material.WoodPlanks)

-- the counter, with a brass rail
local counter = part("Counter", Vector3.new(9, 3.2, 1.4), CFrame.new(0, 2.1, 2.3), DARK, Enum.Material.Wood)
part("CounterTop", Vector3.new(9.4, 0.25, 1.8), CFrame.new(0, 3.82, 2.3), OAK, Enum.Material.Wood)
deco(part("BrassRail", Vector3.new(9.2, 0.14, 0.14), CFrame.new(0, 3.0, 3.05), BRASS, Enum.Material.Metal))
-- a ledger and a pile of brass coins on the counter
deco(part("Ledger", Vector3.new(1.1, 0.16, 0.8), CFrame.new(-2.2, 4.03, 2.2) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(110, 40, 36), Enum.Material.Fabric))
for i = 1, 7 do
	deco(part("Coin" .. i, Vector3.new(0.08, 0.36, 0.36), CFrame.new(1.6 + (i % 3) * 0.3, 3.98 + math.floor(i / 3) * 0.08, 2.1 + (i % 2) * 0.25) * CFrame.Angles(0, 0, math.rad(90)), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder))
end

-- striped awning, tilted toward the path
local stripes = 8
for i = 1, stripes do
	local x = -5.5 + (i - 0.5) * (11 / stripes)
	deco(part("Awning" .. i, Vector3.new(11 / stripes, 0.12, 8), CFrame.new(x, 9.3, 0.4) * CFrame.Angles(math.rad(12), 0, 0), if i % 2 == 0 then CREAM else NAVY, Enum.Material.Fabric))
	-- scalloped edge
	deco(part("Flap" .. i, Vector3.new(11 / stripes - 0.1, 0.7, 0.08), CFrame.new(x, 8.15, 4.35), if i % 2 == 0 then CREAM else NAVY, Enum.Material.Fabric))
end

-- the sign
-- hung under the front of the awning on two chains, at eye level
local sign = part("Sign", Vector3.new(6.2, 1.25, 0.25), CFrame.new(0, 7.15, 3.95), DARK, Enum.Material.Wood)
for _, x in { -2.6, 2.6 } do
	deco(part("SignChain", Vector3.new(0.07, 0.75, 0.07), CFrame.new(x, 8.1, 3.95), Color3.fromRGB(60, 60, 64), Enum.Material.Metal))
end
deco(sign)
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = Vector2.new(700, 150)
	sg.LightInfluence = 0.4
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Fondamento
	t.Text = "KEEPER'S LOCKER"
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(240, 196, 100)
	t.TextStrokeTransparency = 0.3
	t.Parent = sg
	sg.Parent = sign
end

-- shelf of lanterns on the back wall, each lit in its own colour
part("Shelf", Vector3.new(8, 0.25, 0.9), CFrame.new(0, 5.6, -2.55), OAK, Enum.Material.Wood)
local colours = { Color3.fromRGB(255, 176, 96), Color3.fromRGB(96, 255, 214), Color3.fromRGB(186, 110, 255), Color3.fromRGB(255, 222, 120) }
for i, c in colours do
	local x = -3 + (i - 1) * 2
	deco(part("LanternBase" .. i, Vector3.new(0.6, 0.1, 0.6), CFrame.new(x, 5.78, -2.55), BRASS, Enum.Material.Metal))
	local glass = part("LanternGlass" .. i, Vector3.new(0.5, 0.75, 0.5), CFrame.new(x, 6.2, -2.55), c, Enum.Material.Glass)
	glass.Transparency = 0.35
	deco(glass)
	local flame = part("LanternFlame" .. i, Vector3.new(0.16, 0.3, 0.16), CFrame.new(x, 6.15, -2.55), c, Enum.Material.Neon)
	deco(flame)
	deco(part("LanternCap" .. i, Vector3.new(0.6, 0.12, 0.6), CFrame.new(x, 6.63, -2.55), BRASS, Enum.Material.Metal))
	local light = Instance.new("PointLight")
	light.Color = c
	light.Brightness = 1.2
	light.Range = 7
	light.Parent = flame
end

-- an oilskin coat on a peg and a keeper's cap
deco(part("Peg", Vector3.new(0.12, 0.12, 0.5), CFrame.new(4.2, 4.6, -2.7), BRASS, Enum.Material.Metal))
deco(part("CoatBody", Vector3.new(1.5, 2.4, 0.4), CFrame.new(4.2, 3.3, -2.75), Color3.fromRGB(214, 170, 48), Enum.Material.SmoothPlastic))
deco(part("CoatCollar", Vector3.new(1.6, 0.35, 0.5), CFrame.new(4.2, 4.45, -2.7), Color3.fromRGB(190, 148, 40), Enum.Material.SmoothPlastic))
deco(part("Cap", Vector3.new(0.9, 0.35, 0.9), CFrame.new(-4.2, 4.9, -2.6), NAVY, Enum.Material.Fabric, Enum.PartType.Cylinder))

-- a chest of brass beside the stall
local chestCF = CFrame.new(6.6, 0.95, 2.2) * CFrame.Angles(0, math.rad(-20), 0)
part("Chest", Vector3.new(2.2, 1.4, 1.4), chestCF, DARK, Enum.Material.Wood)
deco(part("ChestBand", Vector3.new(2.25, 1.45, 0.16), chestCF, BRASS, Enum.Material.Metal))
deco(part("ChestLid", Vector3.new(2.2, 0.2, 1.4), chestCF * CFrame.new(0, 0.85, -0.55) * CFrame.Angles(math.rad(-60), 0, 0) * CFrame.new(0, 0, 0.6), OAK, Enum.Material.Wood))
deco(part("ChestCoins", Vector3.new(1.9, 0.2, 1.1), chestCF * CFrame.new(0, 0.62, 0), BRASS, Enum.Material.Metal))

-- lanterns hanging from the front corners
for _, x in { -5.2, 5.2 } do
	deco(part("HookChain", Vector3.new(0.06, 0.9, 0.06), CFrame.new(x, 7.6, 3.6), Color3.fromRGB(60, 60, 64), Enum.Material.Metal))
	local g = part("HangGlass", Vector3.new(0.55, 0.8, 0.55), CFrame.new(x, 6.8, 3.6), Color3.fromRGB(255, 190, 110), Enum.Material.Glass)
	g.Transparency = 0.3
	deco(g)
	local f = part("HangFlame", Vector3.new(0.16, 0.3, 0.16), CFrame.new(x, 6.75, 3.6), Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
	deco(f)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 110)
	light.Brightness = 1.4
	light.Range = 14
	light.Shadows = true
	light.Parent = f
end

model.PrimaryPart = counter
model.Parent = lobby
return `built KeepersLocker ({#model:GetChildren()} parts) at ground {groundY}`
