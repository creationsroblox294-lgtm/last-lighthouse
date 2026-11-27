--!strict
-- PropsPass: swaps the old part-built lanterns and the harbour bell for the Blender models
-- (assets/props: ShipLantern.fbx -> asset 89765255194301, ShipBell.fbx -> 113361678155578).
-- Run in Studio after the builders (BuildLobby, BuildKeepersLocker, BuildCraftingTable).
--   - ReplicatedStorage.Assets.ShipLantern: the template (parts Brass / Glass / Flame + PointLight).
--     KeeperService also uses it for the belt lanterns.
--   - Lobby lantern posts (keeps each lantern's light and Flicker so LobbyController still swings
--     and flickers them), the boats' lanterns, the Locker's shelf (one colour each) and hanging
--     lanterns, the crafting table's lantern, and the island's Old Dock / Floor 3 lanterns.
--   - Lobby.Props.Bell becomes the brass ship bell (same name, so it still sways).

local InsertService = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")

local assets = RS:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = RS
if not assets:FindFirstChild("ShipLantern") then
	local m = InsertService:LoadAsset(89765255194301)
	local model = Instance.new("Model")
	model.Name = "ShipLantern"
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") then
			local p = d:Clone()
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			local role = string.match(p.Name, "_(%w+)$") or p.Name
			p.Name = role
			if role == "Brass" then
				p.Material, p.Color, p.CastShadow = Enum.Material.Metal, Color3.fromRGB(184, 136, 62), true
			elseif role == "Glass" then
				p.Material, p.Color, p.Transparency = Enum.Material.Glass, Color3.fromRGB(255, 214, 150), 0.45
			elseif role == "Flame" then
				p.Material, p.Color = Enum.Material.Neon, Color3.fromRGB(255, 170, 70)
				local l = Instance.new("PointLight")
				l.Color, l.Brightness, l.Range, l.Shadows = Color3.fromRGB(255, 180, 110), 1.5, 14, true
				l.Parent = p
			end
			p.Parent = model
		end
	end
	model.PrimaryPart = model:FindFirstChild("Brass") :: BasePart
	model.Parent = assets
	m:Destroy()
end
local T = assets:FindFirstChild("ShipLantern") :: Model
local _, TS = T:GetBoundingBox()

-- one ship lantern standing on bottomY at (x, z), h studs tall, replacing `olds`
local function swap(parent: Instance, olds: { BasePart }, x: number, bottomY: number, z: number, h: number, glass: Color3?, flame: Color3?)
	local m = T:Clone()
	m:ScaleTo(h / TS.Y)
	local bb, bs = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(x - bb.X, bottomY + bs.Y / 2 - bb.Y, z - bb.Z))
	local g, f = m:FindFirstChild("Glass") :: BasePart, m:FindFirstChild("Flame") :: BasePart
	if glass then
		g.Color = glass
	end
	if flame then
		f.Color = flame
	end
	local fl = f:FindFirstChildOfClass("PointLight") :: PointLight
	for _, o in olds do
		local ol = o:FindFirstChildOfClass("PointLight")
		if ol then
			fl.Range, fl.Brightness, fl.Color, fl.Shadows = ol.Range, ol.Brightness, ol.Color, ol.Shadows
		end
		local flick = o:GetAttribute("Flicker")
		if flick then
			f:SetAttribute("Flicker", flick)
		end
	end
	for _, p in m:GetChildren() do
		p.Parent = parent
	end
	m:Destroy()
	for _, o in olds do
		o:Destroy()
	end
end
local function bottomOf(p: BasePart): number
	return p.Position.Y - p.Size.Y / 2
end

local lobby = workspace:FindFirstChild("Lobby") or game.ServerStorage.Parked:FindFirstChild("Lobby")
local map = workspace:FindFirstChild("Map") or game.ServerStorage.Parked:FindFirstChild("Map")

-- lantern posts: hang from the arm (the model's Pivot attribute)
for _, lan in lobby.Lanterns:GetChildren() do
	local frame = lan:FindFirstChild("Frame")
	local glassPart = lan:FindFirstChild("Glass")
	if lan:IsA("Model") and frame and glassPart then
		local pivot = lan:GetAttribute("Pivot") :: Vector3
		local h = 1.66
		swap(lan, { frame :: BasePart, glassPart :: BasePart }, pivot.X, pivot.Y + 0.1 - h, pivot.Z, h)
	end
end
for _, b in lobby.Boats:GetChildren() do
	local l = b:FindFirstChild("Lantern", true)
	if l and l:IsA("BasePart") then
		swap(l.Parent :: Instance, { l }, l.Position.X, bottomOf(l), l.Position.Z, math.max(1.1, l.Size.Y * 1.35))
	end
end
local locker = lobby:FindFirstChild("KeepersLocker")
if locker then
	for i = 1, 4 do
		local b, g, f, c = locker:FindFirstChild("LanternBase" .. i), locker:FindFirstChild("LanternGlass" .. i), locker:FindFirstChild("LanternFlame" .. i), locker:FindFirstChild("LanternCap" .. i)
		if b and g and f and c then
			local col = (f :: BasePart).Color
			swap(locker, { b :: BasePart, g :: BasePart, f :: BasePart, c :: BasePart }, (b :: BasePart).Position.X, bottomOf(b :: BasePart), (b :: BasePart).Position.Z, 1.0, col:Lerp(Color3.new(1, 1, 1), 0.25), col)
		end
	end
	for _, g in locker:GetChildren() do
		if g.Name == "HangGlass" and g:IsA("BasePart") then
			local olds = { g }
			for _, c in locker:GetChildren() do
				if c.Name == "HangFlame" and c:IsA("BasePart") and (c.Position - g.Position).Magnitude < 0.5 then
					table.insert(olds, c)
				end
			end
			swap(locker, olds, g.Position.X, g.Position.Y + g.Size.Y / 2 + 0.25 - 1.05, g.Position.Z, 1.05)
		end
	end
end
local bench = map:FindFirstChild("CraftingTable", true)
if bench and bench:FindFirstChild("LanternBase") then
	local olds = {}
	for _, n in { "LanternBase", "LanternGlass", "LanternFlame", "LanternCap", "LanternRing" } do
		local p = bench:FindFirstChild(n)
		if p then
			table.insert(olds, p)
		end
	end
	local base = bench:FindFirstChild("LanternBase") :: BasePart
	swap(bench, olds, base.Position.X, bottomOf(base), base.Position.Z, 1.05)
end
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "Lantern" and d.Parent and (d.Parent.Name == "OldDock" or d.Parent.Name == "Floor3Decor") then
		local olds = { d }
		local cap = d.Parent:FindFirstChild("LanternCap")
		if cap and d.Parent.Name == "Floor3Decor" then
			table.insert(olds, cap :: BasePart)
		end
		swap(d.Parent, olds, d.Position.X, bottomOf(d), d.Position.Z, math.max(1.0, d.Size.Y * 1.3))
	end
end

-- the harbour bell
local bell = lobby.Props:FindFirstChild("Bell")
if bell and bell:IsA("Part") then
	local m = InsertService:LoadAsset(113361678155578)
	local mesh = (m:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart):Clone()
	m:Destroy()
	mesh.Size *= 1.75 / mesh.Size.X
	mesh.Name = "Bell"
	mesh.Material, mesh.Color = Enum.Material.Metal, Color3.fromRGB(190, 140, 62)
	mesh.Anchored, mesh.CanCollide = true, false
	local top = bell.Position.Y + bell.Size.Y / 2
	mesh.CFrame = CFrame.new(bell.Position.X, top + 0.2 - mesh.Size.Y / 2, bell.Position.Z) * bell.CFrame.Rotation
	mesh.Parent = bell.Parent
	bell:Destroy()
end
return "props pass done"
