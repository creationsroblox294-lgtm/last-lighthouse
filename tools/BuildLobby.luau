--!nocheck
-- BuildLobby: builds Workspace.Lobby, the harbor at dusk where players gather before a run.
-- Run once in Studio (Edit) with the command bar or execute_luau. Re-running replaces it.
--
-- Layout (L = Config.Lobby.Center = 3200, 0, 0; the sea is to the west, -X):
--   beach and huts on the east (+X), a long dock running west with 4 rowboats (2 each side),
--   lantern posts, a campfire on the sand, and the lighthouse island far out in the fog.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local L = Vector3.new(3200, 0, 0)
local Terrain = Workspace.Terrain

local old = Workspace:FindFirstChild("Lobby")
if old then
	old:Destroy()
end
local lobby = Instance.new("Model")
lobby.Name = "Lobby"

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or lobby
	return f
end
local fDock = folder("Dock")
local fBoats = folder("Boats")
local fHuts = folder("Huts")
local fLights = folder("Lanterns")
local fProps = folder("Props")
local fFar = folder("FarLighthouse")
local fFx = folder("Ambience")

local WOOD = Color3.fromRGB(118, 84, 58)
local WOOD_DARK = Color3.fromRGB(78, 56, 40)
local WOOD_LIGHT = Color3.fromRGB(150, 112, 78)
local WARM = Color3.fromRGB(255, 176, 92)

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function wood(size: Vector3, cf: CFrame, parent: Instance, color: Color3?): BasePart
	return part({ Size = size, CFrame = cf, Material = Enum.Material.WoodPlanks, Color = color or WOOD }, parent)
end

---------------------------------------------------------------------------
-- Terrain: sea, beach, grassy rise and hills behind
---------------------------------------------------------------------------
local function world(x: number, y: number, z: number): Vector3
	return L + Vector3.new(x, y, z)
end
-- clear the area first
Terrain:FillBlock(CFrame.new(world(150, 40, 0)), Vector3.new(1700, 160, 1500), Enum.Material.Air)
-- the sea
Terrain:FillBlock(CFrame.new(world(-150, -20, 0)), Vector3.new(1600, 40, 1500), Enum.Material.Water)
-- sea floor
Terrain:FillBlock(CFrame.new(world(-150, -44, 0)), Vector3.new(1600, 8, 1500), Enum.Material.Sand)
-- beach: a slope from under the water up to the grass
for i = 0, 15 do
	local x = 45 + i * 6
	local top = -7 + i * 0.85
	Terrain:FillBlock(CFrame.new(world(x, (top - 40) / 2, 0)), Vector3.new(7, top + 40, 700), Enum.Material.Sand)
end
-- land behind the beach
Terrain:FillBlock(CFrame.new(world(330, -17, 0)), Vector3.new(380, 46, 700), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(world(345, 5.5, 0)), Vector3.new(350, 1, 700), Enum.Material.Grass)
-- grassy hills and rocks closing the bay in on both sides
for _, h in {
	{ 260, -30, -330, 120 },
	{ 330, -25, 300, 130 },
	{ 470, -20, -120, 110 },
	{ 470, -18, 140, 120 },
	{ 120, -45, -380, 95 },
	{ 120, -45, 380, 95 },
} do
	Terrain:FillBall(world(h[1], h[2], h[3]), h[4], Enum.Material.Grass)
end
for _, r in {
	{ 40, -6, -150, 14 },
	{ 25, -8, -190, 18 },
	{ 40, -6, 160, 15 },
	{ 15, -9, 205, 20 },
	{ 70, 0, -235, 22 },
	{ 70, 0, 240, 24 },
} do
	Terrain:FillBall(world(r[1], r[2], r[3]), r[4], Enum.Material.Rock)
end
Terrain.WaterWaveSize = 0.3
Terrain.WaterWaveSpeed = 9

---------------------------------------------------------------------------
-- Dock: runs west from the beach, with a T-head at the end
---------------------------------------------------------------------------
local DECK_Y = 3.2
local DOCK_START = 105 -- x where the dock leaves the beach
local DOCK_END = -15
local i = 0
for x = DOCK_START, DOCK_END, -1.6 do
	i += 1
	local shade = if i % 3 == 0 then WOOD_LIGHT elseif i % 3 == 1 then WOOD else Color3.fromRGB(132, 96, 66)
	wood(Vector3.new(1.5, 0.35, 10), CFrame.new(world(x, DECK_Y, 0)) * CFrame.Angles(0, math.rad((i % 2) * 0.6 - 0.3), 0), fDock, shade)
end
-- T-head
for z = -24, 24, 1.6 do
	i += 1
	local shade = if i % 2 == 0 then WOOD_LIGHT else WOOD
	wood(Vector3.new(12, 0.35, 1.5), CFrame.new(world(DOCK_END - 6, DECK_Y, z)), fDock, shade)
end
-- stringers under the planks
for _, z in { -4.4, 0, 4.4 } do
	wood(Vector3.new(DOCK_START - DOCK_END + 2, 0.6, 0.6), CFrame.new(world((DOCK_START + DOCK_END) / 2, DECK_Y - 0.5, z)), fDock, WOOD_DARK)
end
wood(Vector3.new(0.6, 0.6, 50), CFrame.new(world(DOCK_END - 1, DECK_Y - 0.5, 0)), fDock, WOOD_DARK)
wood(Vector3.new(0.6, 0.6, 50), CFrame.new(world(DOCK_END - 11, DECK_Y - 0.5, 0)), fDock, WOOD_DARK)
-- pilings
local function piling(x: number, z: number, height: number?)
	local h = height or 16
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.1, 1.1),
		CFrame = CFrame.new(world(x, DECK_Y + 1.2 - h / 2, z)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = WOOD_DARK,
	}, fDock)
	-- rope wrap near the top
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 1.25, 1.25),
		CFrame = CFrame.new(world(x, DECK_Y + 0.6, z)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(196, 170, 120),
	}, fDock)
end
for x = DOCK_START - 5, DOCK_END, -12 do
	piling(x, -5.4)
	piling(x, 5.4)
end
for z = -24, 24, 8 do
	piling(DOCK_END - 12.4, z)
end
-- a low rope rail along the T-head's far edge
for z = -24, 16, 8 do
	part({
		Size = Vector3.new(0.2, 0.2, 8),
		CFrame = CFrame.new(world(DOCK_END - 12.4, DECK_Y + 1.6, z + 4)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(196, 170, 120),
	}, fDock)
end
-- beach steps where the dock meets the sand
for s = 0, 2 do
	wood(Vector3.new(2, 0.4, 10), CFrame.new(world(DOCK_START + 1.5 + s * 2, DECK_Y - 0.6 - s * 0.7, 0)), fDock, WOOD)
end

---------------------------------------------------------------------------
-- Boats: 4 rowboats moored along the dock, bows to the sea
---------------------------------------------------------------------------
local source = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("OldDock") and Workspace.Map.OldDock:FindFirstChild("Rowboat")
assert(source, "Map.OldDock.Rowboat is needed as the boat model")
local SPOTS = {
	{ name = "Boat1", x = 70, side = -1 },
	{ name = "Boat2", x = 35, side = -1 },
	{ name = "Boat3", x = 70, side = 1 },
	{ name = "Boat4", x = 35, side = 1 },
}
for n, spot in SPOTS do
	local boat = Instance.new("Model")
	boat.Name = spot.name
	boat:SetAttribute("Number", n)
	local hull = source.Boat_LP:Clone()
	hull.Name = "Hull"
	hull.Anchored = true
	hull.CanCollide = false
	-- boat long axis = Z in the mesh; turn it so the bow faces west (-X)
	local z = spot.side * 12
	-- high enough that the sea doesn't show inside the hull
	local base = CFrame.new(world(spot.x, 2.9, z)) * CFrame.Angles(0, math.rad(90), 0)
	hull.CFrame = base
	hull.Parent = boat
	-- invisible floor to stand on, and low side walls so nobody slides off
	local deck = part({ Name = "Deck", Size = Vector3.new(5.2, 0.4, 17), CFrame = base * CFrame.new(0, -1.6, 0), Transparency = 1 }, boat)
	for _, sx in { -1, 1 } do
		part({ Name = "Side", Size = Vector3.new(0.3, 3, 17), CFrame = base * CFrame.new(sx * 2.9, -0.2, 0), Transparency = 1 }, boat)
	end
	-- benches the party sits on (also the seat positions used when the boat leaves)
	local seats = folder("Seats", boat)
	for s, zz in { -5.2, -1.6, 1.8, 5.2 } do
		local bench = wood(Vector3.new(5, 0.35, 1.1), base * CFrame.new(0, -0.6, zz), boat, WOOD_LIGHT)
		bench.Name = "Bench"
		bench.CanCollide = false
		local seat = Instance.new("Attachment")
		seat.Name = "Seat" .. s
		seat.CFrame = CFrame.new(if s % 2 == 0 then 1.1 else -1.1, 0.4, 0) * CFrame.Angles(0, math.rad(180), 0)
		seat.Parent = bench
		local ref = Instance.new("ObjectValue")
		ref.Name = "Seat" .. s
		ref.Value = seat
		ref.Parent = seats
	end
	-- oars resting across the gunwales
	for _, sx in { -1, 1 } do
		local oar = wood(Vector3.new(0.3, 0.3, 9), base * CFrame.new(sx * 3.1, 0.6, 1.5) * CFrame.Angles(0, math.rad(sx * 12), 0), boat, WOOD_LIGHT)
		oar.Name = "Oar"
		oar.CanCollide = false
		local blade = wood(Vector3.new(0.15, 1.1, 2.2), oar.CFrame * CFrame.new(0, 0, 4.4), boat, WOOD_LIGHT)
		blade.Name = "OarBlade"
		blade.CanCollide = false
	end
	-- bow lantern
	local pole = wood(Vector3.new(0.25, 3.2, 0.25), base * CFrame.new(0, 0.9, -9.2), boat, WOOD_DARK)
	pole.Name = "LanternPole"
	pole.CanCollide = false
	local lamp = part({
		Name = "Lantern",
		Size = Vector3.new(0.7, 0.9, 0.7),
		CFrame = base * CFrame.new(0, 2.9, -9.2),
		Material = Enum.Material.Neon,
		Color = WARM,
		CanCollide = false,
	}, boat)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 14
	light.Brightness = 1.4
	light.Shadows = true
	light.Parent = lamp
	lamp:SetAttribute("Flicker", 1.4)
	-- zone: who is aboard (server checks player positions against this box)
	part({ Name = "Zone", Size = Vector3.new(6.5, 8, 19), CFrame = base * CFrame.new(0, 1.5, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, boat)
	-- where people are put back on the dock (leaving the boat, or a failed launch)
	part({
		Name = "Exit",
		Size = Vector3.new(2, 1, 2),
		CFrame = CFrame.new(world(spot.x, DECK_Y + 3, spot.side * 2.5)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, boat)
	-- gangplank from the dock down into the boat
	local gp = wood(Vector3.new(3, 0.3, 5), CFrame.new(world(spot.x, DECK_Y - 0.55, spot.side * 7.2)) * CFrame.Angles(math.rad(spot.side * 10), 0, 0), boat, WOOD_LIGHT)
	gp.Name = "Gangplank"
	-- mooring rope to the dock
	local a0 = Instance.new("Attachment")
	a0.Parent = hull
	a0.CFrame = CFrame.new(0, 0.8, -8)
	local post = wood(Vector3.new(0.7, 2, 0.7), CFrame.new(world(spot.x - 7, DECK_Y + 1, spot.side * 4.6)), fDock, WOOD_DARK)
	local a1 = Instance.new("Attachment")
	a1.Parent = post
	a1.Position = Vector3.new(0, 0.6, 0)
	local rope = Instance.new("RopeConstraint")
	rope.Name = "Mooring"
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Length = 8
	rope.Visible = true
	rope.Color = BrickColor.new("Burlap")
	rope.Thickness = 0.15
	rope.Parent = boat
	-- sign over the boat (the client fills in the text)
	local signPost = wood(Vector3.new(0.4, 6, 0.4), CFrame.new(world(spot.x + 6, DECK_Y + 3, spot.side * 4.6)), fDock, WOOD_DARK)
	local board = wood(Vector3.new(0.3, 1.6, 4), CFrame.new(world(spot.x + 6, DECK_Y + 5.6, spot.side * 4.6)), boat, WOOD_LIGHT)
	board.Name = "Sign"
	signPost.Name = "SignPost"
	boat:SetAttribute("BaseCFrame", base)
	boat.PrimaryPart = hull
	boat.Parent = fBoats
end

---------------------------------------------------------------------------
-- Lantern posts along the dock and the beach path
---------------------------------------------------------------------------
local function lanternPost(at: Vector3, height: number?)
	local h = height or 7
	local post = wood(Vector3.new(0.5, h, 0.5), CFrame.new(at + Vector3.new(0, h / 2, 0)), fLights, WOOD_DARK)
	post.Name = "Post"
	local arm = wood(Vector3.new(0.3, 0.3, 1.6), CFrame.new(at + Vector3.new(0, h - 0.3, 0.7)), fLights, WOOD_DARK)
	arm.Name = "Arm"
	-- hanging lantern (swings a little on the client)
	local lantern = Instance.new("Model")
	lantern.Name = "Lantern"
	local pivot = at + Vector3.new(0, h - 0.5, 1.4)
	local frame = part({
		Name = "Frame",
		Size = Vector3.new(0.9, 1.2, 0.9),
		CFrame = CFrame.new(pivot - Vector3.new(0, 0.9, 0)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(40, 38, 36),
		Transparency = 0.15,
		CanCollide = false,
	}, lantern)
	local glass = part({
		Name = "Glass",
		Size = Vector3.new(0.7, 0.9, 0.7),
		CFrame = frame.CFrame,
		Material = Enum.Material.Neon,
		Color = WARM,
		CanCollide = false,
	}, lantern)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 20
	light.Brightness = 1.6
	light.Shadows = true
	light.Parent = glass
	glass:SetAttribute("Flicker", 1.6)
	lantern:SetAttribute("Pivot", pivot)
	lantern.PrimaryPart = glass
	lantern.Parent = fLights
end
for x = DOCK_START - 8, DOCK_END + 4, -22 do
	lanternPost(world(x, DECK_Y + 0.2, -5.6))
	lanternPost(world(x - 11, DECK_Y + 0.2, 5.6))
end
lanternPost(world(DOCK_END - 12, DECK_Y + 0.2, -24.5))
lanternPost(world(DOCK_END - 12, DECK_Y + 0.2, 24.5))
local function groundAt(x: number, z: number): number
	local r = Workspace:Raycast(world(x, 80, z), Vector3.new(0, -200, 0))
	return if r then r.Position.Y else 5
end
for _, p in { { 125, -20 }, { 150, 20 }, { 185, -35 }, { 200, 45 } } do
	lanternPost(world(p[1], groundAt(p[1], p[2]), p[2]))
end

---------------------------------------------------------------------------
-- Fishing huts on the shore
---------------------------------------------------------------------------
local function hut(cf: CFrame, w: number, d: number, h: number, roof: Color3, name: string)
	local m = Instance.new("Model")
	m.Name = name
	-- floor
	wood(Vector3.new(w + 1, 0.6, d + 1), cf * CFrame.new(0, 0.3, 0), m, WOOD_DARK)
	-- plank walls (vertical boards)
	local function wall(len: number, at: CFrame)
		local n = math.floor(len / 1.2)
		for k = 0, n - 1 do
			local shade = if k % 3 == 0 then WOOD_LIGHT elseif k % 3 == 1 then WOOD else Color3.fromRGB(128, 92, 62)
			wood(Vector3.new(1.18, h, 0.4), at * CFrame.new(-len / 2 + 0.6 + k * 1.2, h / 2 + 0.6, 0), m, shade)
		end
	end
	wall(w, cf * CFrame.new(0, 0, -d / 2))
	wall(w, cf * CFrame.new(0, 0, d / 2))
	wall(d, cf * CFrame.new(-w / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	wall(d, cf * CFrame.new(w / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	-- corner posts
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		wood(Vector3.new(0.7, h + 0.4, 0.7), cf * CFrame.new(c[1] * w / 2, h / 2 + 0.6, c[2] * d / 2), m, WOOD_DARK)
	end
	-- door (on the -X side, facing the sea)
	wood(Vector3.new(0.3, h * 0.72, 2.6), cf * CFrame.new(-w / 2 - 0.25, h * 0.36 + 0.6, 0), m, Color3.fromRGB(70, 48, 34))
	-- glowing windows
	for _, s in { -1, 1 } do
		local win = part({
			Size = Vector3.new(0.2, 1.6, 1.8),
			CFrame = cf * CFrame.new(-w / 2 - 0.25, h * 0.6 + 0.6, s * (d / 2 - 2)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 190, 110),
		}, m)
		local l = Instance.new("PointLight")
		l.Color = WARM
		l.Range = 12
		l.Brightness = 1.2
		l.Parent = win
		win:SetAttribute("Flicker", 1.2)
		-- shutters
		for _, ss in { -1, 1 } do
			wood(Vector3.new(0.2, 1.8, 0.9), win.CFrame * CFrame.new(-0.15, 0, ss * 1.35), m, Color3.fromRGB(80, 105, 120))
		end
	end
	-- pitched roof
	local rise = w * 0.42
	local slope = math.sqrt((w / 2) ^ 2 + rise ^ 2)
	local ang = math.atan2(rise, w / 2)
	for _, s in { -1, 1 } do
		part({
			Size = Vector3.new(slope + 1.2, 0.5, d + 2),
			CFrame = cf * CFrame.new(s * w / 4, h + 0.6 + rise / 2, 0) * CFrame.Angles(0, 0, -s * ang),
			Material = Enum.Material.Slate,
			Color = roof,
		}, m)
	end
	-- gables
	for _, s in { -1, 1 } do
		for k = 0, 3 do
			local ww = w * (1 - k / 4)
			wood(Vector3.new(ww, rise / 4, 0.4), cf * CFrame.new(0, h + 0.6 + rise / 8 + k * rise / 4, s * d / 2), m, WOOD)
		end
	end
	-- chimney with smoke
	local chim = part({
		Size = Vector3.new(1.6, rise + 3, 1.6),
		CFrame = cf * CFrame.new(w / 4, h + rise / 2 + 2, d / 4),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(110, 102, 96),
	}, m)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, (rise + 3) / 2, 0)
	top.Parent = chim
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxassetid://118122779843195"
	smoke.Color = ColorSequence.new(Color3.fromRGB(190, 180, 180), Color3.fromRGB(120, 115, 125))
	smoke.LightInfluence = 1
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Speed = NumberRange.new(1.5, 2.5)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = Vector3.new(-0.6, 0.3, 0.2)
	smoke.Drag = 0.4
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-15, 15)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 7) })
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = top
	-- porch with a barrel and a hanging net
	wood(Vector3.new(3, 0.4, d), cf * CFrame.new(-w / 2 - 1.8, 0.4, 0), m, WOOD)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 1.6, 1.6),
		CFrame = cf * CFrame.new(-w / 2 - 2, 1.7, d / 2 - 1.2) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(105, 70, 45),
	}, m)
	local net = part({
		Size = Vector3.new(0.1, h * 0.7, d * 0.45),
		CFrame = cf * CFrame.new(w / 2 + 0.3, h * 0.5 + 0.6, 0),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(70, 90, 80),
		Transparency = 0.35,
	}, m)
	net.Name = "Net"
	m.Parent = fHuts
end
local function ground(x: number, z: number): number
	local r = Workspace:Raycast(world(x, 80, z), Vector3.new(0, -200, 0))
	return if r then r.Position.Y else 5
end
hut(CFrame.new(world(150, ground(150, -60) - 0.2, -60)) * CFrame.Angles(0, math.rad(8), 0), 12, 14, 9, Color3.fromRGB(70, 82, 96), "HutA")
hut(CFrame.new(world(160, ground(160, 62) - 0.2, 62)) * CFrame.Angles(0, math.rad(-12), 0), 14, 12, 10, Color3.fromRGB(122, 58, 46), "HutB")
hut(CFrame.new(world(205, ground(205, 8) - 0.2, 8)) * CFrame.Angles(0, math.rad(2), 0), 16, 16, 11, Color3.fromRGB(64, 92, 78), "HutC")

---------------------------------------------------------------------------
-- Props: crates, barrels, rope coils, buoys, a bell, nets, the campfire
---------------------------------------------------------------------------
local function crate(at: CFrame, s: number)
	local c = wood(Vector3.new(s, s, s), at, fProps, Color3.fromRGB(140, 104, 66))
	c.Material = Enum.Material.WoodPlanks
	for _, e in { -1, 1 } do
		wood(Vector3.new(s + 0.1, 0.25, 0.25), at * CFrame.new(0, e * (s / 2 - 0.12), s / 2), fProps, WOOD_DARK)
		wood(Vector3.new(s + 0.1, 0.25, 0.25), at * CFrame.new(0, e * (s / 2 - 0.12), -s / 2), fProps, WOOD_DARK)
	end
end
local function barrel(at: Vector3)
	local b = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 1.9, 1.9),
		CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(112, 74, 46),
	}, fProps)
	for _, y in { -0.75, 0.75 } do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 2, 2),
			CFrame = b.CFrame * CFrame.new(y, 0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 62),
		}, fProps)
	end
end
local function coil(at: Vector3)
	for k = 0, 3 do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 2.2 - k * 0.15, 2.2 - k * 0.15),
			CFrame = CFrame.new(at + Vector3.new(0, 0.15 + k * 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(196, 170, 120),
		}, fProps)
	end
end
crate(CFrame.new(world(98, DECK_Y + 1.2, -3)) * CFrame.Angles(0, math.rad(12), 0), 2)
crate(CFrame.new(world(96.5, DECK_Y + 1.2, -3.6)) * CFrame.Angles(0, math.rad(-6), 0), 2)
crate(CFrame.new(world(97.2, DECK_Y + 3.2, -3.3)) * CFrame.Angles(0, math.rad(30), 0), 2)
barrel(world(52, DECK_Y + 0.2, 3.5))
barrel(world(50, DECK_Y + 0.2, 3.6))
coil(world(18, DECK_Y + 0.2, -3.6))
coil(world(-20, DECK_Y + 0.2, 18))
crate(CFrame.new(world(-23, DECK_Y + 1.7, -18)) * CFrame.Angles(0, math.rad(22), 0), 3)
barrel(world(-25, DECK_Y + 0.2, -14))
crate(CFrame.new(world(130, ground(130, -40) + 1.5, -40)) * CFrame.Angles(0, math.rad(40), 0), 3)
barrel(world(138, ground(138, 40), 40))
barrel(world(140, ground(140, 42.5), 42.5))
-- ship's bell on a frame at the head of the dock
do
	local bx = world(DOCK_START - 2, DECK_Y + 0.2, -6.2)
	wood(Vector3.new(0.5, 6, 0.5), CFrame.new(bx + Vector3.new(-1.3, 3, 0)), fProps, WOOD_DARK)
	wood(Vector3.new(0.5, 6, 0.5), CFrame.new(bx + Vector3.new(1.3, 3, 0)), fProps, WOOD_DARK)
	wood(Vector3.new(3.4, 0.5, 0.6), CFrame.new(bx + Vector3.new(0, 6, 0)), fProps, WOOD_DARK)
	local bell = part({
		Name = "Bell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 2, 1.8),
		CFrame = CFrame.new(bx + Vector3.new(0, 4.7, 0)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(176, 136, 64),
		Reflectance = 0.1,
	}, fProps)
	bell:SetAttribute("Swing", true)
end
-- buoys out in the water (bob on the client)
for k, b in { { -40, -40 }, { -60, 30 }, { -95, -10 }, { -30, 60 }, { -120, 55 }, { -80, -70 } } do
	local buoy = Instance.new("Model")
	buoy.Name = "Buoy"
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = CFrame.new(world(b[1], 0.3, b[2])),
		Material = Enum.Material.SmoothPlastic,
		Color = if k % 2 == 0 then Color3.fromRGB(220, 60, 45) else Color3.fromRGB(235, 230, 220),
		CanCollide = false,
	}, buoy)
	local mast = part({
		Name = "Mast",
		Size = Vector3.new(0.25, 2.4, 0.25),
		CFrame = CFrame.new(world(b[1], 2.4, b[2])),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 70, 72),
		CanCollide = false,
	}, buoy)
	local tip = part({
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = CFrame.new(world(b[1], 3.7, b[2])),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 110, 80),
		CanCollide = false,
	}, buoy)
	tip:SetAttribute("Blink", k * 0.7)
	buoy.PrimaryPart = body
	buoy:SetAttribute("Base", body.Position)
	buoy.Parent = fProps
	local _ = mast
end
-- campfire on the beach with log benches
do
	local c = world(118, ground(118, 26), 26)
	for k = 0, 7 do
		local a = k * math.pi / 4
		part({
			Size = Vector3.new(1.3, 0.9, 1),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 2.4, 0.35, math.sin(a) * 2.4)) * CFrame.Angles(0, -a, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(95, 92, 90),
		}, fProps)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.3
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 0.55, 0.55),
			CFrame = CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, math.rad(25)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 46, 30),
		}, fProps)
	end
	local fire = part({ Name = "Campfire", Size = Vector3.new(1.5, 0.5, 1.5), CFrame = CFrame.new(c + Vector3.new(0, 0.8, 0)), Transparency = 1, CanCollide = false }, fProps)
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = "rbxassetid://105240361456761"
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 150)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 130, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 40, 20)),
	})
	flames.LightEmission = 1
	flames.Rate = 45
	flames.Lifetime = NumberRange.new(0.5, 0.9)
	flames.Speed = NumberRange.new(3, 5)
	flames.SpreadAngle = Vector2.new(10, 10)
	flames.Acceleration = Vector3.new(0, 3, 0)
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flames.Parent = fire
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxassetid://105240361456761"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 70))
	embers.LightEmission = 1
	embers.Rate = 8
	embers.Lifetime = NumberRange.new(1.5, 3)
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0.4, 1, 0)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	embers.Parent = fire
	local fl = Instance.new("PointLight")
	fl.Color = Color3.fromRGB(255, 150, 70)
	fl.Range = 22
	fl.Brightness = 2.2
	fl.Shadows = true
	fl.Parent = fire
	fire:SetAttribute("Flicker", 2.2)
	for k = 0, 2 do
		local a = k * 2.1 + 0.4
		local logc = c + Vector3.new(math.cos(a) * 6.5, 0.6, math.sin(a) * 6.5)
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 1.2, 1.2),
			CFrame = CFrame.new(logc) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(96, 66, 44),
		}, fProps)
	end
end

---------------------------------------------------------------------------
-- The lighthouse island far out in the fog (the beam sweeps on the client)
---------------------------------------------------------------------------
do
	local base = world(-620, 0, 140)
	Terrain:FillBlock(CFrame.new(base + Vector3.new(0, -20, 0)), Vector3.new(220, 40, 220), Enum.Material.Water)
	Terrain:FillBall(base + Vector3.new(0, -28, 0), 48, Enum.Material.Rock)
	Terrain:FillBall(base + Vector3.new(20, -20, -10), 30, Enum.Material.Grass)
	local towerH = 70
	for k = 0, 6 do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(towerH / 7, 12 - k * 0.6, 12 - k * 0.6),
			CFrame = CFrame.new(base + Vector3.new(0, 14 + k * towerH / 7 + towerH / 14, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.SmoothPlastic,
			Color = if k % 2 == 0 then Color3.fromRGB(225, 220, 210) else Color3.fromRGB(170, 50, 45),
		}, fFar)
	end
	local top = base + Vector3.new(0, 14 + towerH + 3, 0)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(top - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42) }, fFar)
	local lamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(top), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 236, 180) }, fFar)
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(7, 4, 7), CFrame = CFrame.new(top + Vector3.new(0, 3.5, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42) }, fFar)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Range = 60
	light.Brightness = 3
	light.Parent = lamp
	-- the beam: a spinning arm with two wide Beams (the client spins BeamRig)
	local rig = part({ Name = "BeamRig", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(top), Transparency = 1, CanCollide = false, CanQuery = false }, fFar)
	for _, dir in { 1, -1 } do
		local a0 = Instance.new("Attachment")
		a0.Parent = rig
		a0.Position = Vector3.new(0, 0, 0)
		a0.Axis = Vector3.new(dir, 0, 0)
		local a1 = Instance.new("Attachment")
		a1.Parent = rig
		a1.Position = Vector3.new(dir * 420, -8, 0)
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 5
		beam.Width1 = 70
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Brightness = 2
		beam.Texture = "rbxassetid://105240361456761"
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 238, 190))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.6, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Segments = 2
		beam.Parent = rig
	end
end

---------------------------------------------------------------------------
-- Ambience: fireflies over the grass, mist rolling over the water, splashes at the pilings
---------------------------------------------------------------------------
local function emitterPart(name: string, cf: CFrame, size: Vector3): BasePart
	return part({ Name = name, Size = size, CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, fFx)
end
do
	local ff = emitterPart("Fireflies", CFrame.new(world(170, 9, 0)), Vector3.new(90, 6, 160))
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Texture = "rbxassetid://105240361456761"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 255, 150))
	e.LightEmission = 1
	e.Rate = 14
	e.Lifetime = NumberRange.new(4, 7)
	e.Speed = NumberRange.new(0.2, 0.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = ff
	local mist = emitterPart("SeaMist", CFrame.new(world(-180, 3, 0)), Vector3.new(260, 2, 500))
	local m = Instance.new("ParticleEmitter")
	m.Shape = Enum.ParticleEmitterShape.Box
	m.Texture = "rbxassetid://118122779843195"
	m.Color = ColorSequence.new(Color3.fromRGB(220, 200, 215))
	m.LightInfluence = 1
	m.Rate = 6
	m.Lifetime = NumberRange.new(14, 20)
	m.Speed = NumberRange.new(1, 2)
	m.EmissionDirection = Enum.NormalId.Right
	m.SpreadAngle = Vector2.new(20, 5)
	m.Rotation = NumberRange.new(0, 360)
	m.RotSpeed = NumberRange.new(-5, 5)
	m.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 30) })
	m.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1) })
	m.Parent = mist
	for x = DOCK_START - 5, DOCK_END, -24 do
		for _, z in { -5.4, 5.4 } do
			local sp = emitterPart("Splash", CFrame.new(world(x, 0.3, z)), Vector3.new(1.5, 0.2, 1.5))
			local s = Instance.new("ParticleEmitter")
			s.Texture = "rbxassetid://118122779843195"
			s.Color = ColorSequence.new(Color3.fromRGB(235, 240, 245))
			s.LightInfluence = 1
			s.Rate = 1.2
			s.Lifetime = NumberRange.new(0.6, 1)
			s.Speed = NumberRange.new(3, 5)
			s.SpreadAngle = Vector2.new(30, 30)
			s.Acceleration = Vector3.new(0, -14, 0)
			s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4) })
			s.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
			s.Parent = sp
		end
	end
end

---------------------------------------------------------------------------
-- Spawn: on the beach at the head of the dock, facing the boats and the sea
---------------------------------------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.CFrame = CFrame.new(world(122, ground(122, 0) + 0.4, 0)) * CFrame.Angles(0, math.rad(90), 0)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = lobby

---------------------------------------------------------------------------
-- Greenery: grass on the land behind the beach (Terrain.Decoration makes it sway), a sand
-- path up to the big hut, and trees from ServerStorage.TreeLibrary on the slopes
---------------------------------------------------------------------------
Terrain:ReplaceMaterial(Region3.new(world(170, -20, -360), world(540, 40, 360)):ExpandToGrid(4), 4, Enum.Material.Sand, Enum.Material.Grass)
Terrain:ReplaceMaterial(Region3.new(world(140, -20, -360), world(172, 40, -80)):ExpandToGrid(4), 4, Enum.Material.Sand, Enum.Material.Grass)
Terrain:ReplaceMaterial(Region3.new(world(140, -20, 90), world(172, 40, 360)):ExpandToGrid(4), 4, Enum.Material.Sand, Enum.Material.Grass)
Terrain:FillBlock(CFrame.new(world(185, 6.5, 4)), Vector3.new(40, 3, 7), Enum.Material.Sand)
local lib = game:GetService("ServerStorage"):FindFirstChild("TreeLibrary")
if lib then
	local trees = folder("Trees")
	local onlyTerrain = RaycastParams.new()
	onlyTerrain.FilterType = Enum.RaycastFilterType.Include
	onlyTerrain.FilterDescendantsInstances = { Terrain }
	local spots = {
		{ "Oak", 235, -70, 0.8 }, { "Pine", 250, 40, 0.9 }, { "Willow", 225, 95, 0.75 }, { "Oak2", 265, -20, 0.85 },
		{ "OldTree", 190, -100, 0.9 }, { "Pine", 290, 80, 1.0 }, { "Pine", 300, -60, 1.1 }, { "Oak", 320, 10, 1.0 },
		{ "Pine", 215, -130, 0.95 }, { "Oak2", 205, 120, 0.85 }, { "Pine", 340, -110, 1.2 }, { "Pine", 350, 120, 1.15 },
		{ "Willow", 180, 150, 0.7 }, { "OldTree", 280, -140, 0.85 }, { "Pine", 120, -170, 0.9 }, { "Pine", 130, 175, 0.95 },
	}
	for k, s in spots do
		local src = lib:FindFirstChild(s[1])
		local hit = Workspace:Raycast(world(s[2], 150, s[3]), Vector3.new(0, -300, 0), onlyTerrain)
		if src and src:IsA("Model") and hit and hit.Position.Y > 2 then
			local m = src:Clone()
			m:ScaleTo(m:GetScale() * s[4])
			local cf, size = m:GetBoundingBox()
			local bottom = cf.Position.Y - size.Y / 2
			local pivot = m:GetPivot()
			m:PivotTo(CFrame.new(hit.Position.X, pivot.Position.Y - bottom + hit.Position.Y - 0.3, hit.Position.Z) * CFrame.Angles(0, math.rad(k * 47), 0))
			m.Parent = trees
		end
	end
end

-- the whole harbor streams to every player at once (it's small, and the client animates it)
lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
lobby.Parent = Workspace
local _ = ReplicatedStorage
return "Lobby built"
