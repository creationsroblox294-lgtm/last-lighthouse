--!strict
-- Builds the harbor's leaderboards and the boats' glowing boarding pads. Run in Studio.
--   Lobby.Boards.Board_<Stat>: three roofed wooden notice boards beside the path from the
--     spawn to the dock (Furthest Storm, Brass Earned, Lights Kept). Their Face part carries
--     a SurfaceGui "BoardGui" with a title and Rows.Row1..8 (Rank / Name / Value) that
--     LeaderboardService fills, and a "You" row each client fills for itself.
--   Lobby.Boats.BoatN.PadGlow*: a glowing outline on each boat's deck, so it's obvious where
--     to step in to start or join a party. LobbyController pulses it.

local lobby = workspace.Lobby
local Config = require(game.ReplicatedStorage.Shared.Config)

local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
local SANS = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local OAK = Color3.fromRGB(104, 70, 44)
local DARK = Color3.fromRGB(62, 42, 28)
local BRASS = Color3.fromRGB(200, 156, 72)
local NAVY = Color3.fromRGB(20, 30, 48)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function text(parent: Instance, name: string, t: string, size: UDim2, pos: UDim2, font: Font, color: Color3, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.FontFace = font
	l.Text = t
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

---------------------------------------------------------------------------
-- Leaderboards
---------------------------------------------------------------------------
local old = lobby:FindFirstChild("Boards")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Boards"
folder.Parent = lobby

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }

local Z = 32 -- across the path from the Keeper's Locker (clear of the woodpile); the boards face it (-Z)
for i, b in Config.Keeper.Boards :: { any } do
	local x = 3342 - (i - 1) * 11 -- first board on the left as you look at them
	local hit = workspace:Raycast(Vector3.new(x, 80, Z), Vector3.new(0, -200, 0), rp)
	local y = if hit then hit.Position.Y else 7
	local base = CFrame.new(x, y, Z) * CFrame.Angles(0, math.rad(if i == 1 then 14 elseif i == 3 then -14 else 0), 0)
	local m = Instance.new("Model")
	m.Name = "Board_" .. b.Stat
	for _, sx in { -4.1, 4.1 } do
		part(m, "Post", Vector3.new(0.6, 11, 0.6), base * CFrame.new(sx, 5.5, 0), DARK, Enum.Material.Wood)
	end
	part(m, "Back", Vector3.new(8.4, 8.6, 0.4), base * CFrame.new(0, 6.0, 0.25), OAK, Enum.Material.WoodPlanks)
	local face = part(m, "Face", Vector3.new(7.6, 7.8, 0.1), base * CFrame.new(0, 6.0, -0.02), NAVY, Enum.Material.SmoothPlastic)
	for _, sy in { 1.65, 10.35 } do
		part(m, "Rail", Vector3.new(8.6, 0.25, 0.5), base * CFrame.new(0, sy, -0.05), BRASS, Enum.Material.Metal)
	end
	-- little peaked roof
	for _, s in { -1, 1 } do
		part(m, "Roof", Vector3.new(4.9, 0.3, 2.2), base * CFrame.new(s * 2.25, 11.25, 0) * CFrame.Angles(0, 0, math.rad(-s * 18)), DARK, Enum.Material.WoodPlanks)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "BoardGui"
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 620)
	sg.LightInfluence = 0.15
	sg.Brightness = 1.4
	sg.Parent = face
	text(sg, "Title", b.Title, UDim2.new(0.9, 0, 0, 62), UDim2.new(0.05, 0, 0, 14), SERIF, Color3.fromRGB(255, 214, 120))
	text(sg, "Sub", "TOP KEEPERS  ·  ALL SERVERS", UDim2.new(0.9, 0, 0, 24), UDim2.new(0.05, 0, 0, 80), SANS, Color3.fromRGB(170, 190, 215))
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.new(0.05, 0, 0, 118)
	rows.Size = UDim2.new(0.9, 0, 0, 8 * 52)
	rows.Parent = sg
	for r = 1, 8 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. r
		row.BackgroundColor3 = if r % 2 == 1 then Color3.fromRGB(30, 44, 68) else Color3.fromRGB(24, 36, 56)
		row.BackgroundTransparency = 0.1
		row.BorderSizePixel = 0
		row.Position = UDim2.new(0, 0, 0, (r - 1) * 52)
		row.Size = UDim2.new(1, 0, 0, 48)
		row.Parent = rows
		local medal = if r == 1 then Color3.fromRGB(255, 205, 90) elseif r == 2 then Color3.fromRGB(205, 214, 226) elseif r == 3 then Color3.fromRGB(214, 150, 92) else Color3.fromRGB(150, 165, 185)
		text(row, "Rank", "#" .. r, UDim2.new(0.13, 0, 0.8, 0), UDim2.new(0.02, 0, 0.1, 0), SERIF, medal)
		text(row, "Name", "—", UDim2.new(0.6, 0, 0.7, 0), UDim2.new(0.17, 0, 0.15, 0), SANS, Color3.fromRGB(240, 236, 224), Enum.TextXAlignment.Left)
		text(row, "Value", "", UDim2.new(0.2, 0, 0.7, 0), UDim2.new(0.78, 0, 0.15, 0), SERIF, Color3.fromRGB(255, 214, 120), Enum.TextXAlignment.Right)
	end
	local you = text(sg, "You", "", UDim2.new(0.9, 0, 0, 34), UDim2.new(0.05, 0, 0, 560), SANS, Color3.fromRGB(150, 230, 200))
	you.TextXAlignment = Enum.TextXAlignment.Left
	m.PrimaryPart = face
	m.Parent = folder
end

---------------------------------------------------------------------------
-- Glowing boarding pads on each boat
---------------------------------------------------------------------------
for _, boat in lobby.Boats:GetChildren() do
	if not boat:IsA("Model") then
		continue
	end
	for _, c in boat:GetChildren() do
		if c.Name == "PadGlow" then
			c:Destroy()
		end
	end
	local zone = boat:FindFirstChild("Zone") :: BasePart?
	local deck = boat:FindFirstChild("Deck") :: BasePart?
	if not (zone and deck) then
		continue
	end
	local top = deck.Position.Y + deck.Size.Y / 2 + 0.06
	-- the zone is rotated; work in its space (X across the boat, Z along it)
	local cf = CFrame.new(zone.Position.X, top, zone.Position.Z) * zone.CFrame.Rotation
	local w, l = zone.Size.X * 0.62, zone.Size.Z * 0.72
	local t = 0.28
	local edges = {
		{ Vector3.new(w, 0.08, t), CFrame.new(0, 0, l / 2) },
		{ Vector3.new(w, 0.08, t), CFrame.new(0, 0, -l / 2) },
		{ Vector3.new(t, 0.08, l), CFrame.new(w / 2, 0, 0) },
		{ Vector3.new(t, 0.08, l), CFrame.new(-w / 2, 0, 0) },
	}
	for _, e in edges do
		local p = part(boat, "PadGlow", e[1], cf * e[2], Color3.fromRGB(255, 236, 190), Enum.Material.Neon)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 0.15
	end
end
return "boards and pads built"
