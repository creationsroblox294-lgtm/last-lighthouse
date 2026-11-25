--!nocheck
-- Lighthouse builder (run from the Studio command bar / MCP in Edit mode).
-- Octagonal stone tower on a railed plinth, red glass lantern + dome, stone gallery,
-- spiral staircases between levels and furnished rooms.
-- Keeps every name gameplay scripts look for:
--   Map.Lighthouse.GroundFloor { StorageCrateA, StorageCrateB, Wall* }
--   Map.Lighthouse.BunkRoom    { FoodStorage, SpawnLocation, Wall* }
--   Map.Lighthouse.LampRoom    { Lamp(+PointLight), BeamControl, FuelTank, Wall* }
-- Usage: local B = require(ServerStorage.LHBuilder:Clone()); B.run("shell") ... (see STAGES)

local B = {}

local C = Vector3.new(55, 0, -80) -- tower axis; Y values below are absolute
local TAN = math.tan(math.rad(22.5))
local COS = math.cos(math.rad(22.5))
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
local MAT = Enum.Material

local F0, F1, F2 = 36.2, 52.2, 68.4 -- floor tops: ground, bunk, lamp room

local COL = {
	stoneLight = Color3.fromRGB(178, 176, 170),
	stoneBand = Color3.fromRGB(150, 149, 145),
	stoneDark = Color3.fromRGB(96, 98, 102),
	quoin = Color3.fromRGB(132, 133, 135),
	trim = Color3.fromRGB(232, 230, 224),
	plaster = Color3.fromRGB(238, 229, 210),
	wainscot = Color3.fromRGB(96, 60, 36),
	woodFloor = Color3.fromRGB(128, 84, 52),
	darkWood = Color3.fromRGB(66, 42, 27),
	midWood = Color3.fromRGB(142, 98, 62),
	brass = Color3.fromRGB(196, 156, 74),
	iron = Color3.fromRGB(42, 44, 46),
	red = Color3.fromRGB(170, 24, 26),
	teal = Color3.fromRGB(36, 104, 112),
	glass = Color3.fromRGB(205, 228, 236),
	cream = Color3.fromRGB(242, 234, 216),
	doorGreen = Color3.fromRGB(34, 76, 50),
	brick = Color3.fromRGB(132, 70, 52),
	warm = Color3.fromRGB(255, 196, 130),
}

---------------------------------------------------------------------------
-- primitives
---------------------------------------------------------------------------
local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(1, 1, 1)
	p.Material = mat or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cyl(parent, name, len, dia, cf, color, mat, extra)
	extra = extra or {}
	extra.Shape = Enum.PartType.Cylinder
	return P(parent, name, Vector3.new(len, dia, dia), cf, color, mat, extra)
end

local function vcyl(parent, name, y0, y1, dia, x, z, color, mat, extra)
	return cyl(parent, name, y1 - y0, dia, CFrame.new(C.X + x, (y0 + y1) / 2, C.Z + z) * UP, color, mat, extra)
end

local function ball(parent, name, dia, cf, color, mat, extra)
	extra = extra or {}
	extra.Shape = Enum.PartType.Ball
	return P(parent, name, Vector3.new(dia, dia, dia), cf, color, mat, extra)
end

local function M(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function at(x, y, z)
	return CFrame.new(C.X + x, y, C.Z + z)
end

-- a point on the wall of face k (outward normal angle k*45°), u along the face, looking inward
local function wallCF(k, a, u, y)
	return CFrame.new(C.X, y, C.Z) * CFrame.Angles(0, math.rad(k * 45), 0) * CFrame.new(u, 0, a)
end

local function light(parent, range, brightness, color, shadows)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color or COL.warm
	l.Shadows = shadows ~= false
	l.Parent = parent
	return l
end

---------------------------------------------------------------------------
-- walls
---------------------------------------------------------------------------
-- face frame: origin at bottom centre of face (mid-thickness), X tangent, Y up the slant, Z outward
local function faceFrame(k, a, y0, alpha)
	return CFrame.new(C.X, y0, C.Z) * CFrame.Angles(0, math.rad(k * 45), 0) * CFrame.new(0, 0, a) * CFrame.Angles(-alpha, 0, 0)
end

local function panel(parent, name, f, w, h, t, op, color, mat)
	local function piece(u0, u1, v0, v1)
		if u1 - u0 < 0.05 or v1 - v0 < 0.05 then
			return
		end
		P(parent, name, Vector3.new(u1 - u0, v1 - v0, t), f * CFrame.new((u0 + u1) / 2, (v0 + v1) / 2, 0), color, mat)
	end
	if not op then
		piece(-w / 2, w / 2, 0, h)
		return
	end
	local ou0, ou1 = op.u - op.w / 2, op.u + op.w / 2
	local ov0, ov1 = op.v, math.min(op.v + op.h, h)
	piece(-w / 2, ou0, 0, h)
	piece(ou1, w / 2, 0, h)
	piece(ou0, ou1, 0, ov0)
	piece(ou0, ou1, ov1, h)
end

-- 8-sided ring. aBot/aTop = OUTER apothems at y0 / y0+H. openings[k] = {u, v, w, h}
local function ring(parent, name, y0, H, aBot, aTop, t, color, mat, openings)
	local alpha = math.atan((aBot - aTop) / H)
	local hs = H / math.cos(alpha)
	local amid = (aBot + aTop) / 2 - t / 2
	local w = 2 * amid * TAN
	local frames = {}
	for k = 0, 7 do
		local f = faceFrame(k, aBot - t / 2, y0, alpha)
		frames[k] = f
		panel(parent, name, f, w, hs, t, openings and openings[k], color, mat)
	end
	return frames, alpha
end

local function pilasters(parent, name, y0, H, aBot, aTop, size, color, mat)
	local beta = math.atan((aBot - aTop) / COS / H)
	local hs = H / math.cos(beta)
	for k = 0, 7 do
		local R = aBot / COS
		local cf = CFrame.new(C.X, y0, C.Z)
			* CFrame.Angles(0, math.rad(k * 45 + 22.5), 0)
			* CFrame.new(0, 0, R - size * 0.3)
			* CFrame.Angles(-beta, 0, 0)
			* CFrame.new(0, hs / 2, 0)
		P(parent, name, Vector3.new(size, hs, size), cf, color, mat)
	end
end

local function windowTrim(parent, f, op, t, white)
	local m = M(parent, "Window")
	local u, v, w, h = op.u, op.v, op.w, op.h
	local d = t + 0.5
	local fr = 0.3
	local function px(sx, sy, sz, x, y, z, col, mat, extra)
		return P(m, "Frame", Vector3.new(sx, sy, sz), f * CFrame.new(x, y, z), col, mat, extra)
	end
	px(fr, h, d, u - w / 2 + fr / 2, v + h / 2, -0.1, white, MAT.Wood)
	px(fr, h, d, u + w / 2 - fr / 2, v + h / 2, -0.1, white, MAT.Wood)
	px(w, fr, d, u, v + h - fr / 2, -0.1, white, MAT.Wood)
	px(w, fr, d, u, v + fr / 2, -0.1, white, MAT.Wood)
	px(0.16, h, 0.2, u, v + h / 2, 0, white, MAT.Wood)
	px(w, 0.16, 0.2, u, v + h * 0.62, 0, white, MAT.Wood)
	px(w - 0.2, h - 0.2, 0.08, u, v + h / 2, 0, COL.glass, MAT.Glass, { Transparency = 0.55, CanCollide = false, CastShadow = false })
	px(w + 0.9, 0.35, 0.9, u, v - 0.1, t / 2 + 0.25, COL.trim, MAT.Concrete) -- outside sill
	px(w + 0.4, 0.25, 0.7, u, v + 0.05, -t / 2 - 0.45, COL.trim, MAT.Wood) -- inside sill (sits on lining)
	return m
end

---------------------------------------------------------------------------
-- octagonal slabs (CSG) with stair holes
---------------------------------------------------------------------------
local function octSlab(parent, name, a, yTop, t, color, mat, cutters)
	local cf = at(0, yTop - t / 2, 0)
	local b1 = P(workspace, name, Vector3.new(2 * a, t, 2 * a), cf, color, mat)
	local b2 = P(workspace, name, Vector3.new(2 * a, t, 2 * a), cf * CFrame.Angles(0, math.rad(45), 0), color, mat)
	local u = b1:IntersectAsync({ b2 }) -- two squares intersected = octagon
	b1:Destroy()
	b2:Destroy()
	if cutters and #cutters > 0 then
		u.Parent = workspace
		local cut = u:SubtractAsync(cutters)
		u:Destroy()
		u = cut
		for _, c in cutters do
			c:Destroy()
		end
	end
	u.Name = name
	u.UsePartColor = true
	u.Color = color
	u.Material = mat
	u.Anchored = true
	pcall(function()
		u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	end)
	u.Parent = parent
	return u
end

-- steps 1..15 at angle th + s*(i-12)*24°; hole covers steps 8.5..15.5
local STEP_DEG = 24
local function holeAngles(k, s)
	return k * 45 + s * (8.5 - 12) * STEP_DEG, k * 45 + s * (15.5 - 12) * STEP_DEG
end

local function stairCutters(px, pz, R, k, s, yTop)
	local list = {}
	local a0, a1 = holeAngles(k, s)
	local n = math.ceil(math.abs(a1 - a0) / 5)
	for j = 0, n do
		local phi = math.rad(a0 + (a1 - a0) * j / n)
		local cf = at(px, yTop, pz) * CFrame.Angles(0, phi, 0) * CFrame.new(0, 0, (R + 0.6) / 2)
		table.insert(list, P(workspace, "Cut", Vector3.new(1.0, 6, R + 0.6), cf))
	end
	table.insert(list, cyl(workspace, "Cut", 6, 2.4, at(px, yTop, pz) * UP))
	return list
end

local function railBetween(parent, p0, p1, dia, color, mat)
	local len = (p1 - p0).Magnitude
	return cyl(parent, "Rail", len, dia, CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0), color, mat)
end

local function spiral(parent, px, pz, yBase, H, R, k, s)
	local m = M(parent, "SpiralStair")
	local N = 16
	local rise = H / N
	vcyl(m, "Newel", yBase, yBase + H + 3.6, 0.9, px, pz, COL.darkWood, MAT.Wood)
	ball(m, "NewelCap", 1.2, at(px, yBase + H + 3.7, pz), COL.brass, MAT.Metal)
	local prevTop
	for i = 1, N - 1 do
		local phi = math.rad(k * 45 + s * (i - 12) * STEP_DEG)
		local yTop = yBase + i * rise
		local base = at(px, yTop, pz) * CFrame.Angles(0, phi, 0)
		P(m, "Step", Vector3.new(2.15, 1.1, R - 0.3), base * CFrame.new(0, -0.55, (R + 0.3) / 2), COL.midWood, MAT.Wood)
		P(m, "Nosing", Vector3.new(2.15, 0.12, R - 0.3), base * CFrame.new(0, 0.02, (R + 0.3) / 2), COL.darkWood, MAT.Wood, { CanCollide = false })
		local post = (base * CFrame.new(0, 0, R - 0.25)).Position
		vcyl(m, "Baluster", yTop, yTop + 3.1, 0.18, post.X - C.X, post.Z - C.Z, COL.iron, MAT.Metal, { CanCollide = false })
		local top = post + Vector3.new(0, 3.1, 0)
		if prevTop then
			railBetween(m, prevTop, top, 0.32, COL.darkWood, MAT.Wood)
		end
		prevTop = top
	end
	-- invisible guard on the open outer edge so nobody slips off mid-climb
	for i = 1, N - 1, 2 do
		local phi = math.rad(k * 45 + s * (i - 12) * STEP_DEG)
		local cf = at(px, yBase + i * rise + 2, pz) * CFrame.Angles(0, phi, 0) * CFrame.new(0, 0, R + 0.05)
		P(m, "Guard", Vector3.new(4.2, 4, 0.2), cf, Color3.new(1, 1, 1), MAT.SmoothPlastic, { Transparency = 1, CastShadow = false })
	end
	return m
end

-- railing around the stairwell on the floor above
local function wellRail(parent, px, pz, R, k, s, yTop)
	local m = M(parent, "WellRail")
	local a0, a1 = holeAngles(k, s)
	local rr = R + 0.75
	-- edge along the start of the hole (drop is deepest here)
	local phi0 = math.rad(a0)
	local edge = at(px, yTop, pz) * CFrame.Angles(0, phi0, 0) * CFrame.new(-s * 0.7, 0, 0)
	local pts = {}
	for j = 0, 3 do
		local p = (edge * CFrame.new(0, 0, 0.6 + (rr - 0.6) * j / 3)).Position
		table.insert(pts, p)
	end
	-- outer arc
	local n = 8
	local arc = {}
	for j = 0, n do
		local phi = math.rad(a0 + (a1 - a0) * j / n)
		table.insert(arc, (at(px, yTop, pz) * CFrame.Angles(0, phi, 0) * CFrame.new(0, 0, rr)).Position)
	end
	local function line(list)
		for idx, p in list do
			vcyl(m, "Post", yTop, yTop + 3, 0.3, p.X - C.X, p.Z - C.Z, COL.darkWood, MAT.Wood)
			if idx > 1 then
				local q = list[idx - 1]
				railBetween(m, q + Vector3.new(0, 3, 0), p + Vector3.new(0, 3, 0), 0.32, COL.darkWood, MAT.Wood)
				railBetween(m, q + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1.5, 0), 0.16, COL.iron, MAT.Metal)
				P(m, "Guard", Vector3.new(0.2, 3, (p - q).Magnitude), CFrame.lookAt((p + q) / 2 + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1.5, 0)), Color3.new(1, 1, 1), MAT.SmoothPlastic, { Transparency = 1, CastShadow = false })
			end
		end
	end
	line(pts)
	line(arc)
	return m
end

---------------------------------------------------------------------------
-- furniture
---------------------------------------------------------------------------
local function legs4(m, cf, sx, sz, h, dia, col)
	for _, q in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		P(m, "Leg", Vector3.new(dia, h, dia), cf * CFrame.new(q[1] * sx, h / 2, q[2] * sz), col, MAT.Wood)
	end
end

local function armchair(parent, cf, col)
	local m = M(parent, "Armchair")
	legs4(m, cf, 1.25, 1.15, 0.5, 0.3, COL.darkWood)
	P(m, "Seat", Vector3.new(3, 1.0, 2.8), cf * CFrame.new(0, 1.0, 0), col, MAT.Fabric)
	P(m, "Cushion", Vector3.new(2.2, 0.45, 2.3), cf * CFrame.new(0, 1.7, -0.2), col:Lerp(Color3.new(1, 1, 1), 0.08), MAT.Fabric)
	P(m, "Back", Vector3.new(3, 2.9, 0.6), cf * CFrame.new(0, 2.7, 1.15) * CFrame.Angles(math.rad(10), 0, 0), col, MAT.Fabric)
	P(m, "ArmL", Vector3.new(0.5, 0.9, 2.8), cf * CFrame.new(-1.3, 1.95, 0), col, MAT.Fabric)
	P(m, "ArmR", Vector3.new(0.5, 0.9, 2.8), cf * CFrame.new(1.3, 1.95, 0), col, MAT.Fabric)
	return m
end

local function chair(parent, cf)
	local m = M(parent, "Chair")
	legs4(m, cf, 0.65, 0.65, 1.6, 0.22, COL.darkWood)
	P(m, "Seat", Vector3.new(1.7, 0.25, 1.7), cf * CFrame.new(0, 1.7, 0), COL.midWood, MAT.Wood)
	P(m, "Pad", Vector3.new(1.4, 0.15, 1.4), cf * CFrame.new(0, 1.88, 0), Color3.fromRGB(120, 34, 38), MAT.Fabric)
	P(m, "Back", Vector3.new(1.7, 2.0, 0.2), cf * CFrame.new(0, 2.85, 0.78), COL.midWood, MAT.Wood)
	return m
end

local function roundTable(parent, cf, dia)
	local m = M(parent, "Table")
	cyl(m, "Top", 0.25, dia, cf * CFrame.new(0, 2.9, 0) * UP, COL.midWood, MAT.Wood)
	cyl(m, "Cloth", 0.05, dia * 0.6, cf * CFrame.new(0, 3.05, 0) * UP, COL.cream, MAT.Fabric, { CanCollide = false })
	cyl(m, "Stem", 2.6, 0.5, cf * CFrame.new(0, 1.5, 0) * UP, COL.darkWood, MAT.Wood)
	cyl(m, "Foot", 0.3, 1.8, cf * CFrame.new(0, 0.15, 0) * UP, COL.darkWood, MAT.Wood)
	return m
end

local function candle(parent, cf, withLight)
	cyl(parent, "Candle", 0.7, 0.25, cf * CFrame.new(0, 0.35, 0) * UP, COL.cream, MAT.SmoothPlastic, { CanCollide = false })
	local flame = ball(parent, "Flame", 0.22, cf * CFrame.new(0, 0.82, 0), Color3.fromRGB(255, 190, 90), MAT.Neon, { CanCollide = false, CastShadow = false })
	if withLight then
		light(flame, withLight.range, withLight.brightness)
	end
end

local function rug(parent, cf, w, d, col, border, name)
	local m = M(parent, name or "Rug")
	P(m, "Border", Vector3.new(w, 0.06, d), cf * CFrame.new(0, 0.03, 0), border, MAT.Fabric, { CanCollide = false })
	P(m, "Field", Vector3.new(w - 0.8, 0.07, d - 0.8), cf * CFrame.new(0, 0.04, 0), col, MAT.Fabric, { CanCollide = false })
	P(m, "Medallion", Vector3.new((w - 0.8) * 0.4, 0.08, (d - 0.8) * 0.4), cf * CFrame.new(0, 0.045, 0) * CFrame.Angles(0, math.rad(45), 0), border, MAT.Fabric, { CanCollide = false })
	return m
end

local function painting(parent, cf, w, h, seed)
	local m = M(parent, "Painting")
	P(m, "Frame", Vector3.new(w + 0.5, h + 0.5, 0.18), cf, COL.brass, MAT.Metal, { CanCollide = false })
	local r = Random.new(seed)
	local sky = Color3.fromHSV(r:NextNumber(0.52, 0.62), r:NextNumber(0.25, 0.5), r:NextNumber(0.7, 0.9))
	local sea = Color3.fromHSV(r:NextNumber(0.5, 0.58), 0.6, r:NextNumber(0.35, 0.5))
	P(m, "Sky", Vector3.new(w, h * 0.55, 0.06), cf * CFrame.new(0, h * 0.225, -0.1), sky, MAT.SmoothPlastic, { CanCollide = false })
	P(m, "Sea", Vector3.new(w, h * 0.45, 0.06), cf * CFrame.new(0, -h * 0.275, -0.1), sea, MAT.SmoothPlastic, { CanCollide = false })
	P(m, "Ship", Vector3.new(w * 0.18, h * 0.22, 0.04), cf * CFrame.new(r:NextNumber(-w * 0.25, w * 0.25), -h * 0.02, -0.13), Color3.fromRGB(240, 236, 226), MAT.SmoothPlastic, { CanCollide = false })
	return m
end

local function sconce(parent, cf)
	local m = M(parent, "Sconce")
	P(m, "Plate", Vector3.new(0.6, 1.0, 0.1), cf, COL.brass, MAT.Metal, { CanCollide = false })
	P(m, "Arm", Vector3.new(0.12, 0.12, 0.7), cf * CFrame.new(0, -0.2, -0.35), COL.brass, MAT.Metal, { CanCollide = false })
	cyl(m, "Cup", 0.15, 0.5, cf * CFrame.new(0, -0.15, -0.7) * UP, COL.brass, MAT.Metal, { CanCollide = false })
	candle(m, cf * CFrame.new(0, -0.1, -0.7), { range = 11, brightness = 0.7 })
	cyl(m, "Shade", 0.9, 0.7, cf * CFrame.new(0, 0.55, -0.7) * UP, COL.glass, MAT.Glass, { Transparency = 0.6, CanCollide = false, CastShadow = false })
	return m
end

local function chandelier(parent, pos, ceilingY)
	local m = M(parent, "Chandelier")
	if typeof(pos) == "CFrame" then
		pos = pos.Position
	end
	local cf = CFrame.new(pos)
	P(m, "Chain", Vector3.new(0.12, ceilingY - pos.Y, 0.12), CFrame.new(pos + Vector3.new(0, (ceilingY - pos.Y) / 2, 0)), COL.brass, MAT.Metal, { CanCollide = false })
	ball(m, "Hub", 0.7, cf, COL.brass, MAT.Metal, { CanCollide = false })
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local arm = cf * CFrame.Angles(0, a, 0)
		P(m, "Arm", Vector3.new(0.12, 0.12, 1.6), arm * CFrame.new(0, 0, -0.8), COL.brass, MAT.Metal, { CanCollide = false })
		cyl(m, "Cup", 0.12, 0.45, arm * CFrame.new(0, 0.05, -1.6) * UP, COL.brass, MAT.Metal, { CanCollide = false })
		candle(m, arm * CFrame.new(0, 0.1, -1.6), nil)
	end
	light(m.Hub, 26, 1.3, COL.warm, true)
	return m
end

local function bookshelf(parent, cf, w, h)
	local m = M(parent, "Bookshelf")
	local d = 1.4
	P(m, "Back", Vector3.new(w, h, 0.15), cf * CFrame.new(0, h / 2, d / 2 - 0.08), COL.darkWood, MAT.Wood)
	P(m, "SideL", Vector3.new(0.2, h, d), cf * CFrame.new(-w / 2 + 0.1, h / 2, 0), COL.darkWood, MAT.Wood)
	P(m, "SideR", Vector3.new(0.2, h, d), cf * CFrame.new(w / 2 - 0.1, h / 2, 0), COL.darkWood, MAT.Wood)
	P(m, "Crown", Vector3.new(w + 0.3, 0.3, d + 0.2), cf * CFrame.new(0, h + 0.15, 0), COL.darkWood, MAT.Wood)
	local shelves = math.floor(h / 1.5)
	local r = Random.new(w * 100 + h)
	for i = 0, shelves - 1 do
		local y = 0.15 + i * (h - 0.3) / shelves
		P(m, "Shelf", Vector3.new(w - 0.3, 0.15, d - 0.15), cf * CFrame.new(0, y, 0), COL.darkWood, MAT.Wood)
		local x = -w / 2 + 0.35
		while x < w / 2 - 0.5 do
			local bw = r:NextNumber(0.18, 0.32)
			local bh = r:NextNumber(0.85, 1.2)
			local col = Color3.fromHSV(r:NextNumber(), r:NextNumber(0.35, 0.65), r:NextNumber(0.3, 0.6))
			P(m, "Book", Vector3.new(bw, bh, 0.9), cf * CFrame.new(x + bw / 2, y + 0.08 + bh / 2, 0.05) * CFrame.Angles(0, 0, r:NextNumber(-0.04, 0.04)), col, MAT.SmoothPlastic, { CanCollide = false })
			x += bw + 0.03
			if r:NextNumber() < 0.08 then
				x += 0.5
			end
		end
	end
	return m
end

local function bed(parent, cf, blanket)
	local m = M(parent, "Bed")
	-- head at +Z (against the wall), foot at -Z
	legs4(m, cf, 1.9, 3.3, 1.0, 0.35, COL.darkWood)
	P(m, "Frame", Vector3.new(4.2, 0.6, 7.2), cf * CFrame.new(0, 1.2, 0), COL.midWood, MAT.Wood)
	P(m, "Mattress", Vector3.new(3.9, 0.7, 6.8), cf * CFrame.new(0, 1.85, 0), COL.cream, MAT.Fabric)
	P(m, "Blanket", Vector3.new(4.05, 0.35, 4.6), cf * CFrame.new(0, 2.1, -1.1), blanket, MAT.Fabric)
	P(m, "Fold", Vector3.new(4.05, 0.3, 0.8), cf * CFrame.new(0, 2.35, 1.0), COL.cream, MAT.Fabric)
	for _, x in { -0.95, 0.95 } do
		P(m, "Pillow", Vector3.new(1.6, 0.5, 1.0), cf * CFrame.new(x, 2.45, 2.65) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(250, 248, 240), MAT.Fabric)
	end
	P(m, "Headboard", Vector3.new(4.4, 4.2, 0.4), cf * CFrame.new(0, 2.6, 3.65), COL.darkWood, MAT.Wood)
	P(m, "HeadPanel", Vector3.new(3.6, 2.2, 0.1), cf * CFrame.new(0, 3.2, 3.42), COL.midWood, MAT.Wood)
	P(m, "Footboard", Vector3.new(4.4, 2.4, 0.35), cf * CFrame.new(0, 1.7, -3.6), COL.darkWood, MAT.Wood)
	return m
end

local function nightstand(parent, cf)
	local m = M(parent, "Nightstand")
	P(m, "Body", Vector3.new(1.8, 2.2, 1.6), cf * CFrame.new(0, 1.1, 0), COL.darkWood, MAT.Wood)
	P(m, "Drawer", Vector3.new(1.4, 0.6, 0.05), cf * CFrame.new(0, 1.5, -0.82), COL.midWood, MAT.Wood)
	ball(m, "Knob", 0.15, cf * CFrame.new(0, 1.5, -0.88), COL.brass, MAT.Metal)
	-- oil lamp
	cyl(m, "LampBase", 0.5, 0.7, cf * CFrame.new(0, 2.45, 0) * UP, COL.brass, MAT.Metal)
	local glass = cyl(m, "LampGlass", 0.9, 0.55, cf * CFrame.new(0, 3.15, 0) * UP, Color3.fromRGB(255, 226, 170), MAT.Glass, { Transparency = 0.35, CastShadow = false })
	ball(m, "LampFlame", 0.25, cf * CFrame.new(0, 3.1, 0), Color3.fromRGB(255, 190, 90), MAT.Neon, { CastShadow = false })
	light(glass, 12, 0.8)
	return m
end

---------------------------------------------------------------------------
-- stages
---------------------------------------------------------------------------
local STAGES = {}
local root

local function floorModel(name)
	return root:FindFirstChild(name) or M(root, name)
end

-- section geometry
local A = { y0 = 35, H = 17, a = 14, t = 1.6 } -- ground floor shell (plain)
local Bs = { y0 = 52.8, H = 13.2, aBot = 13.4, aTop = 12.6, t = 1.6 } -- bunk shell (tapered, block stone)
local function aB(y)
	return Bs.aBot - (y - Bs.y0) * (Bs.aBot - Bs.aTop) / Bs.H
end

local GROUND_STAIR = { x = 4.24, z = -4.24, R = 4.5, k = 3, s = -1 }
local UPPER_STAIR = { x = -2.83, z = -2.83, R = 3.8, k = 5, s = 1 }

local DOOR = { u = 0, w = 6, h = 9 }

function STAGES.shell()
	local g = floorModel("GroundFloor")
	local b = floorModel("BunkRoom")
	-- ground floor: plain light stone with a flared foot
	local gOpen = {
		[0] = { u = 0, v = F0 - A.y0, w = DOOR.w, h = DOOR.h },
		[1] = { u = 0, v = F0 + 4 - A.y0, w = 3, h = 5.4 },
		[2] = { u = 0, v = F0 + 4 - A.y0, w = 3, h = 5.4 },
		[4] = { u = 0, v = F0 + 4 - A.y0, w = 3, h = 5.4 },
		[7] = { u = 0, v = F0 + 4 - A.y0, w = 3, h = 5.4 },
	}
	local frames = ring(g, "WallStone", A.y0, A.H, A.a, A.a, A.t, COL.stoneLight, MAT.Concrete, gOpen)
	for k, op in gOpen do
		if k ~= 0 then
			windowTrim(g, frames[k], op, A.t, COL.trim)
		end
	end
	ring(g, "WallFoot", 34.8, 1.8, 14.7, 14.5, 1.4, COL.stoneBand, MAT.Concrete, { [0] = { u = 0, v = 0, w = DOOR.w, h = 3 } })
	pilasters(g, "WallQuoin", 36.6, 14.8, A.a, A.a, 1.3, COL.stoneBand, MAT.Concrete)
	ring(g, "WallBand", 51.4, 1.4, 14.6, 14.6, 1.2, COL.stoneBand, MAT.Concrete)
	task.wait()

	-- bunk floor: tapered dark block stone
	local bOpen = {}
	for _, k in { 0, 2, 4, 6 } do
		bOpen[k] = { u = 0, v = F1 + 4 - Bs.y0, w = 2.8, h = 5.2 }
	end
	frames = ring(b, "WallStone", Bs.y0, Bs.H, Bs.aBot, Bs.aTop, Bs.t, COL.stoneDark, MAT.Brick, bOpen)
	for k, op in bOpen do
		windowTrim(b, frames[k], op, Bs.t, COL.trim)
	end
	pilasters(b, "WallQuoin", Bs.y0, Bs.H, Bs.aBot, Bs.aTop, 1.4, COL.quoin, MAT.Brick)
	-- corbelled cornice under the gallery
	ring(b, "WallCornice", 66, 0.8, 13.2, 13.2, 1.4, COL.stoneBand, MAT.Concrete)
	ring(b, "WallCornice", 66.8, 0.6, 14.0, 14.0, 1.6, COL.stoneBand, MAT.Concrete)
	for k = 0, 7 do -- corbel blocks
		for _, u in { -3.6, -1.2, 1.2, 3.6 } do
			P(b, "WallCorbel", Vector3.new(0.8, 1.2, 1.4), wallCF(k, 13.3, u, 65.8), COL.stoneBand, MAT.Concrete)
		end
	end
	task.wait()

	-- interior linings (plaster over dark wainscot)
	local gl = {}
	for k, op in gOpen do
		gl[k] = { u = op.u, v = op.v - (F0 - A.y0), w = op.w, h = op.h }
	end
	local ai = A.a - A.t
	ring(g, "Lining", F0, 51.2 - F0, ai, ai, 0.25, COL.plaster, MAT.Plaster, gl)
	ring(g, "Wainscot", F0, 3.6, ai - 0.25, ai - 0.25, 0.2, COL.wainscot, MAT.Wood, { [0] = { u = 0, v = 0, w = DOOR.w, h = 4 } })
	ring(g, "ChairRail", F0 + 3.6, 0.3, ai - 0.2, ai - 0.2, 0.35, COL.darkWood, MAT.Wood, { [0] = { u = 0, v = 0, w = DOOR.w, h = 1 } })
	ring(g, "Crown", 50.6, 0.6, ai - 0.25, ai - 0.25, 0.4, COL.darkWood, MAT.Wood)
	local bl = {}
	for k, op in bOpen do
		bl[k] = { u = 0, v = 4, w = 2.8, h = 5.2 }
	end
	local bb, bt = aB(F1) - Bs.t, aB(67.4) - Bs.t
	ring(b, "Lining", F1, 67.4 - F1, bb, bt, 0.25, COL.plaster, MAT.Plaster, bl)
	local slope = (bb - bt) / (67.4 - F1)
	ring(b, "Wainscot", F1, 3.6, bb - 0.25, bb - 0.25 - 3.6 * slope, 0.2, COL.wainscot, MAT.Wood)
	ring(b, "ChairRail", F1 + 3.6, 0.3, bb - 0.2 - 3.6 * slope, bb - 0.2 - 3.9 * slope, 0.35, COL.darkWood, MAT.Wood)
	ring(b, "Crown", 66.8, 0.6, bt - 0.25 + 0.6 * slope, bt - 0.25, 0.4, COL.darkWood, MAT.Wood)
	return "shell ok"
end

function STAGES.floors()
	local g = floorModel("GroundFloor")
	local b = floorModel("BunkRoom")
	local l = floorModel("LampRoom")
	octSlab(g, "Floor", 13.4, F0, 1, COL.woodFloor, MAT.WoodPlanks)
	local gs = GROUND_STAIR
	octSlab(b, "Floor", 13.0, F1, 1, COL.woodFloor, MAT.WoodPlanks, stairCutters(gs.x, gs.z, gs.R, gs.k, gs.s, F1))
	task.wait()
	local us = UPPER_STAIR
	octSlab(l, "GalleryDeck", 14.9, F2, 1, COL.stoneBand, MAT.Concrete, stairCutters(us.x, us.z, us.R, us.k, us.s, F2))
	octSlab(l, "Floor", 9.0, F2 + 0.1, 0.1, COL.woodFloor, MAT.WoodPlanks, stairCutters(us.x, us.z, us.R, us.k, us.s, F2))
	task.wait()
	spiral(g, gs.x, gs.z, F0, F1 - F0, gs.R, gs.k, gs.s)
	wellRail(b, gs.x, gs.z, gs.R, gs.k, gs.s, F1)
	spiral(b, us.x, us.z, F1, F2 - F1, us.R, us.k, us.s)
	wellRail(l, us.x, us.z, us.R, us.k, us.s, F2 + 0.1)
	return "floors ok"
end

function STAGES.lantern()
	local l = floorModel("LampRoom")
	local roof = floorModel("Roof")
	-- gallery balustrade
	local bal = M(l, "Balustrade")
	for k = 0, 7 do
		local a = 14.3
		local w = 2 * a * TAN
		local f = faceFrame(k, a, F2, 0)
		P(bal, "Plinth", Vector3.new(w, 0.5, 0.9), f * CFrame.new(0, 0.25, 0), COL.stoneBand, MAT.Concrete)
		P(bal, "TopRail", Vector3.new(w, 0.5, 1.0), f * CFrame.new(0, 3.05, 0), COL.stoneBand, MAT.Concrete)
		local n = math.floor(w / 1.0)
		for i = 1, n - 1 do
			local u = -w / 2 + i * w / n
			cyl(bal, "Baluster", 2.3, 0.5, f * CFrame.new(u, 1.65, 0) * UP, COL.trim, MAT.Concrete)
		end
		P(bal, "Guard", Vector3.new(w, 4, 0.4), f * CFrame.new(0, 2, 0), Color3.new(1, 1, 1), MAT.SmoothPlastic, { Transparency = 1, CastShadow = false })
		local R = a / COS
		P(bal, "Post", Vector3.new(1.1, 3.7, 1.1), CFrame.new(C.X, F2, C.Z) * CFrame.Angles(0, math.rad(k * 45 + 22.5), 0) * CFrame.new(0, 1.85, R), COL.stoneBand, MAT.Concrete)
	end
	task.wait()
	-- lantern: red metal base, glazing, top ring
	local la, lt = 9.5, 0.6
	ring(l, "WallLantern", F2, 2.6, la, la, lt, COL.red, MAT.Metal)
	local gy0, gy1 = F2 + 2.6, F2 + 9.6
	local gw = 2 * (la - 0.3) * TAN
	for k = 0, 7 do
		local f = faceFrame(k, la - 0.3, gy0, 0)
		P(l, "Glass", Vector3.new(gw, gy1 - gy0, 0.12), f * CFrame.new(0, (gy1 - gy0) / 2, 0), COL.glass, MAT.Glass, { Transparency = 0.62, CastShadow = false })
		P(l, "WallMullionH", Vector3.new(gw, 0.25, 0.35), f * CFrame.new(0, (gy1 - gy0) / 2, 0), COL.red, MAT.Metal)
		P(l, "WallMullionV", Vector3.new(0.22, gy1 - gy0, 0.35), f * CFrame.new(0, (gy1 - gy0) / 2, 0), COL.red, MAT.Metal)
		local R = la / COS
		P(l, "WallFrame", Vector3.new(0.55, gy1 - gy0, 0.55), CFrame.new(C.X, gy0, C.Z) * CFrame.Angles(0, math.rad(k * 45 + 22.5), 0) * CFrame.new(0, (gy1 - gy0) / 2, R - 0.3), COL.red, MAT.Metal)
	end
	ring(l, "WallLantern", gy1, 1.2, la + 0.2, la + 0.2, 0.8, COL.red, MAT.Metal)
	-- little red rail around the lantern
	for k = 0, 7 do
		local a = la + 1.2
		local f = faceFrame(k, a, F2, 0)
		P(l, "LanternRail", Vector3.new(2 * a * TAN, 0.18, 0.18), f * CFrame.new(0, 3.4, 0), COL.red, MAT.Metal)
		P(l, "LanternRailPost", Vector3.new(0.18, 3.4, 0.18), CFrame.new(C.X, F2, C.Z) * CFrame.Angles(0, math.rad(k * 45 + 22.5), 0) * CFrame.new(0, 1.7, a / COS), COL.red, MAT.Metal)
	end
	task.wait()
	-- roof plate, dome, vent, finial, spire
	local top = gy1 + 1.2
	octSlab(roof, "RoofSlab", la + 0.9, top + 0.5, 0.5, COL.red, MAT.Metal)
	local domeBall = ball(workspace, "Dome", 2 * (la + 0.1), at(0, top + 0.5, 0), COL.red, MAT.Metal)
	local cutter = P(workspace, "Cut", Vector3.new(30, 15, 30), at(0, top + 0.5 - 7.5, 0))
	local dome = domeBall:SubtractAsync({ cutter })
	domeBall:Destroy()
	cutter:Destroy()
	dome.Name = "Dome"
	dome.UsePartColor = true
	dome.Color = COL.red
	dome.Material = MAT.Metal
	dome.Reflectance = 0.08
	dome.Parent = roof
	local apex = top + 0.5 + la + 0.1
	vcyl(roof, "Vent", apex - 0.4, apex + 0.9, 2.4, 0, 0, COL.red, MAT.Metal)
	ball(roof, "Finial", 1.7, at(0, apex + 1.6, 0), COL.red, MAT.Metal)
	vcyl(roof, "Spire", apex + 2.2, apex + 8, 0.3, 0, 0, COL.iron, MAT.Metal)
	-- dome ribs
	for k = 0, 7 do
		for j = 0, 7 do
			local a0, a1 = math.rad(j * 11), math.rad((j + 1) * 11)
			local r = la + 0.15
			local p0 = at(0, top + 0.5, 0) * CFrame.Angles(0, math.rad(k * 45), 0) * CFrame.new(0, r * math.sin(a0), r * math.cos(a0))
			local p1 = at(0, top + 0.5, 0) * CFrame.Angles(0, math.rad(k * 45), 0) * CFrame.new(0, r * math.sin(a1), r * math.cos(a1))
			railBetween(roof, p0.Position, p1.Position, 0.3, Color3.fromRGB(140, 18, 20), MAT.Metal)
		end
	end
	return "lantern ok"
end

function STAGES.lamp(old)
	local l = floorModel("LampRoom")
	-- pedestal + fresnel lens around the lamp
	vcyl(l, "LampPedestal", F2 + 0.1, F2 + 3.2, 3.2, 0, 0, COL.iron, MAT.Metal)
	vcyl(l, "PedestalTrim", F2 + 3.0, F2 + 3.3, 3.6, 0, 0, COL.brass, MAT.Metal)
	vcyl(l, "PedestalFoot", F2 + 0.1, F2 + 0.5, 3.8, 0, 0, COL.brass, MAT.Metal)
	local lamp = old and old:Clone() or ball(nil, "Lamp", 2.6, at(0, 75, 0), Color3.fromRGB(255, 221, 140), MAT.Neon)
	lamp.Name = "Lamp"
	lamp.Shape = Enum.PartType.Ball
	lamp.Size = Vector3.new(2.6, 2.6, 2.6)
	lamp.CFrame = at(0, 75, 0)
	lamp.CanCollide = false
	lamp.CastShadow = false
	if not lamp:FindFirstChildOfClass("PointLight") then
		local pl = light(lamp, 60, 3, Color3.fromRGB(255, 221, 140), false)
		pl.Name = "LampLight"
	end
	lamp.Parent = l
	for i = 0, 9 do
		local y = 72.3 + i * 0.6
		local dia = 5.0 - math.abs(i - 4.5) * 0.28
		cyl(l, "LensRing", 0.3, dia, at(0, y, 0) * UP, Color3.fromRGB(220, 236, 230), MAT.Glass, { Transparency = 0.45, CanCollide = false, CastShadow = false })
	end
	for k = 0, 3 do
		local cf = at(0, 75, 0) * CFrame.Angles(0, math.rad(k * 90 + 45), 0) * CFrame.new(0, 0, 2.55)
		P(l, "LensFrame", Vector3.new(0.18, 6.4, 0.18), cf, COL.brass, MAT.Metal, { CanCollide = false })
	end
	vcyl(l, "LensCap", 78.2, 78.6, 4.2, 0, 0, COL.brass, MAT.Metal)
	ball(l, "LensKnob", 0.7, at(0, 78.9, 0), COL.brass, MAT.Metal)

	-- fuel tank (brass, on legs)
	local tank = vcyl(l, "FuelTank", F2 + 1.0, F2 + 4.4, 2.4, 5.4, -3.2, COL.brass, MAT.Metal)
	vcyl(tank, "Band", F2 + 1.6, F2 + 1.9, 2.55, 5.4, -3.2, COL.darkWood, MAT.Metal)
	vcyl(tank, "Band", F2 + 3.5, F2 + 3.8, 2.55, 5.4, -3.2, COL.darkWood, MAT.Metal)
	ball(tank, "Dome", 2.3, at(5.4, F2 + 4.4, -3.2), COL.brass, MAT.Metal, { CanCollide = false })
	for _, q in { { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } } do
		vcyl(tank, "Leg", F2 + 0.1, F2 + 1.0, 0.25, 5.4 + q[1], -3.2 + q[2], COL.iron, MAT.Metal)
	end
	railBetween(tank, at(5.4, F2 + 4.0, -3.2).Position, at(1.2, 72.6, -1.0).Position, 0.25, COL.brass, MAT.Metal)

	-- beam control console with a ship's wheel
	local console = P(l, "BeamControl", Vector3.new(1.8, 3.2, 1.4), at(4.9, F2 + 0.1 + 1.6, 4.0) * CFrame.Angles(0, math.rad(45 + 180), 0), COL.darkWood, MAT.Wood)
	local wheelCF = console.CFrame * CFrame.new(0, 1.2, -0.95)
	cyl(console, "Wheel", 0.18, 2.4, wheelCF * CFrame.Angles(0, math.rad(90), 0), COL.midWood, MAT.Wood, { CanCollide = false })
	cyl(console, "Hub", 0.4, 0.5, wheelCF * CFrame.Angles(0, math.rad(90), 0), COL.brass, MAT.Metal, { CanCollide = false })
	for i = 0, 7 do
		P(console, "Spoke", Vector3.new(0.12, 1.6, 0.12), wheelCF * CFrame.Angles(0, 0, math.rad(i * 22.5)), COL.midWood, MAT.Wood, { CanCollide = false })
	end
	P(console, "Gauge", Vector3.new(0.8, 0.8, 0.1), console.CFrame * CFrame.new(0, 1.62, -0.3) * CFrame.Angles(math.rad(-60), 0, 0), Color3.fromRGB(240, 232, 210), MAT.SmoothPlastic, { CanCollide = false })
	return "lamp ok"
end

function STAGES.ground()
	local g = floorModel("GroundFloor")
	local ai = A.a - A.t - 0.25
	-- fireplace on the -X wall (face 6)
	local fp = M(g, "Fireplace")
	local base = wallCF(6, ai - 1.0, 0, F0)
	P(fp, "Breast", Vector3.new(6.2, 5.6, 2.0), base * CFrame.new(0, 2.8, 0), COL.brick, MAT.Brick)
	P(fp, "Firebox", Vector3.new(3.4, 2.8, 0.1), base * CFrame.new(0, 1.6, -1.02), Color3.fromRGB(22, 16, 14), MAT.Slate, { CanCollide = false })
	P(fp, "Mantel", Vector3.new(7.0, 0.45, 2.6), base * CFrame.new(0, 5.6, -0.2), COL.darkWood, MAT.Wood)
	P(fp, "Chimney", Vector3.new(4.6, 51.2 - F0 - 5.8, 1.6), base * CFrame.new(0, 5.8 + (51.2 - F0 - 5.8) / 2, 0.2), COL.brick, MAT.Brick)
	P(fp, "Hearth", Vector3.new(7.2, 0.25, 2.4), base * CFrame.new(0, 0.12, -1.9), Color3.fromRGB(90, 88, 86), MAT.Slate)
	for i, x in { -0.6, 0.6 } do
		cyl(fp, "Log", 2.2, 0.45, base * CFrame.new(x * 0.3, 0.5 + i * 0.2, -0.7) * CFrame.Angles(0, math.rad(90 + x * 20), 0), COL.darkWood, MAT.Wood, { CanCollide = false })
	end
	local ember = P(fp, "Embers", Vector3.new(2, 0.2, 0.8), base * CFrame.new(0, 0.35, -0.7), Color3.fromRGB(255, 110, 40), MAT.Neon, { CanCollide = false, CastShadow = false })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = ember
	light(ember, 20, 1.6, Color3.fromRGB(255, 150, 70), true)
	painting(fp, base * CFrame.new(0, 8.4, -0.85), 3.6, 2.6, 11)
	candle(fp, base * CFrame.new(-2.8, 5.82, -0.6), nil)
	candle(fp, base * CFrame.new(2.8, 5.82, -0.6), nil)

	-- sitting area
	rug(g, at(-7.0, F0, 0), 6.5, 8.5, Color3.fromRGB(120, 32, 36), Color3.fromRGB(196, 160, 96), "HearthRug")
	armchair(g, at(-5.6, F0, -3.0) * CFrame.Angles(0, math.rad(90 + 25), 0), Color3.fromRGB(46, 74, 62))
	armchair(g, at(-5.6, F0, 3.0) * CFrame.Angles(0, math.rad(90 - 25), 0), Color3.fromRGB(46, 74, 62))
	local side = roundTable(g, at(-6.6, F0, 0), 1.8)
	side:ScaleTo(0.8)
	candle(g, at(-6.6, F0 + 2.35, 0), { range = 8, brightness = 0.6 })

	-- dining table by the front windows (face 1)
	rug(g, at(6.6, F0, 6.0) * CFrame.Angles(0, math.rad(45), 0), 7, 7, Color3.fromRGB(38, 60, 96), Color3.fromRGB(210, 190, 140), "DiningRug")
	roundTable(g, at(6.6, F0, 6.0), 3.6)
	for _, a in { 0, 90, 180, 270 } do
		local cf = at(6.6, F0, 6.0) * CFrame.Angles(0, math.rad(a + 45), 0) * CFrame.new(0, 0, 2.5)
		chair(g, cf)
	end
	candle(g, at(6.6, F0 + 3.05, 6.0), { range = 9, brightness = 0.6 })

	-- storage: two sea chests (gameplay), workbench, barrels
	local function chest(name, cf, label)
		local c = P(g, name, Vector3.new(4.2, 2.6, 2.6), cf * CFrame.new(0, 1.3, 0), COL.midWood, MAT.WoodPlanks)
		P(c, "Lid", Vector3.new(4.3, 0.5, 2.7), cf * CFrame.new(0, 2.75, 0), COL.darkWood, MAT.WoodPlanks)
		for _, x in { -1.5, 1.5 } do
			P(c, "Band", Vector3.new(0.25, 3.05, 2.75), cf * CFrame.new(x, 1.5, 0), COL.brass, MAT.Metal, { CanCollide = false })
		end
		P(c, "Lock", Vector3.new(0.5, 0.6, 0.1), cf * CFrame.new(0, 2.3, -1.36), COL.brass, MAT.Metal, { CanCollide = false })
		return c
	end
	chest("StorageCrateA", wallCF(4, ai - 1.5, -2.6, F0), "Store")
	chest("StorageCrateB", wallCF(5, ai - 1.5, 0, F0), "Take")
	local bench = P(g, "CraftingBench", Vector3.new(5, 0.4, 2.4), wallCF(7, ai - 1.4, 0, F0 + 3.0), COL.midWood, MAT.WoodPlanks)
	legs4(g, wallCF(7, ai - 1.4, 0, F0), 2.2, 0.95, 2.8, 0.35, COL.darkWood)
	P(bench, "Vise", Vector3.new(0.8, 0.6, 0.8), wallCF(7, ai - 1.4, 1.8, F0 + 3.5), COL.iron, MAT.Metal, { CanCollide = false })
	P(bench, "Pegboard", Vector3.new(5, 3, 0.15), wallCF(7, ai - 0.1, 0, F0 + 5.2), COL.midWood, MAT.Wood, { CanCollide = false })
	for i = -2, 2 do
		P(bench, "Tool", Vector3.new(0.2, 1.4 + (i % 2) * 0.5, 0.15), wallCF(7, ai - 0.25, i * 0.9, F0 + 5.2), COL.iron, MAT.Metal, { CanCollide = false })
	end
	for i, u in { -4.2, -3.2 } do
		vcyl(g, "Barrel", F0, F0 + 3.0, 2.0, (wallCF(1, ai - 1.2, u + 7.9, F0).Position - C).X, (wallCF(1, ai - 1.2, u + 7.9, F0).Position - C).Z, COL.midWood, MAT.WoodPlanks)
	end
	-- coat rack by the door
	local rack = wallCF(0, ai - 0.6, -4.4, F0)
	vcyl(g, "CoatRack", F0, F0 + 6, 0.3, (rack.Position - C).X, (rack.Position - C).Z, COL.darkWood, MAT.Wood)
	P(g, "Coat", Vector3.new(1.2, 2.4, 0.7), rack * CFrame.new(0, 4.6, -0.35), Color3.fromRGB(40, 52, 70), MAT.Fabric, { CanCollide = false })

	-- door leaves (open inward), lights, art
	for _, s in { -1, 1 } do
		local f = faceFrame(0, A.a - A.t / 2, F0, 0)
		P(g, "DoorLeaf", Vector3.new(0.25, DOOR.h - 0.2, 3), f * CFrame.new(s * (DOOR.w / 2 + 0.2), (DOOR.h - 0.2) / 2, -A.t / 2 - 1.75), COL.doorGreen, MAT.WoodPlanks, { CanCollide = false })
	end
	chandelier(g, at(-1.5, 48.2, 4.0), 51.2)
	for _, spec in { { 2, -3.5 }, { 2, 3.5 }, { 7, -3.6 }, { 4, 2.2 } } do
		sconce(g, wallCF(spec[1], ai - 0.05, spec[2], F0 + 7.2))
	end
	painting(g, wallCF(2, ai - 0.1, 0, F0 + 11.5), 3.2, 2.4, 3)
	painting(g, wallCF(6, ai - 0.1, 3.8, F0 + 7.5), 1.6, 2.2, 7)
	painting(g, wallCF(5, ai - 0.1, 0, F0 + 7.8), 2.6, 1.9, 5)
	return "ground ok"
end

function STAGES.bunk(oldSpawn)
	local b = floorModel("BunkRoom")
	local ai = aB(F1) - Bs.t - 0.25
	bed(b, wallCF(7, ai - 3.85, 0, F1), Color3.fromRGB(128, 30, 36))
	bed(b, wallCF(1, ai - 3.85, 0, F1), Color3.fromRGB(34, 62, 104))
	local bunkA = b:FindFirstChild("Bed")
	nightstand(b, wallCF(0, ai - 1.0, -3.4, F1) * CFrame.Angles(0, 0, 0))
	nightstand(b, wallCF(0, ai - 1.0, 3.4, F1))
	-- spawn rug between the beds
	local spawn = oldSpawn and oldSpawn:Clone() or Instance.new("SpawnLocation")
	spawn.Name = "BunkSpawn"
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	spawn.Anchored = true
	spawn.Size = Vector3.new(4.6, 0.2, 3.6)
	spawn.CFrame = at(0, F1 + 0.1, 6.6)
	spawn.Material = MAT.Fabric
	spawn.Color = Color3.fromRGB(150, 120, 70)
	spawn.CanCollide = true
	spawn.Parent = b
	P(b, "SpawnRugField", Vector3.new(3.8, 0.05, 2.8), at(0, F1 + 0.22, 6.6), Color3.fromRGB(110, 34, 38), MAT.Fabric, { CanCollide = false })

	-- pantry sideboard under the +X window (gameplay: FoodStorage)
	local sbCF = wallCF(2, ai - 0.9, 0.6, F1)
	local food = P(b, "FoodStorage", Vector3.new(4.6, 3.0, 1.6), sbCF * CFrame.new(0, 1.5, 0), COL.darkWood, MAT.Wood)
	for _, x in { -1.15, 1.15 } do
		P(food, "Door", Vector3.new(2.1, 2.2, 0.06), sbCF * CFrame.new(x, 1.5, -0.82), COL.midWood, MAT.Wood, { CanCollide = false })
		ball(food, "Knob", 0.15, sbCF * CFrame.new(x * 0.2, 1.6, -0.88), COL.brass, MAT.Metal, { CanCollide = false })
	end
	P(food, "Top", Vector3.new(4.9, 0.2, 1.8), sbCF * CFrame.new(0, 3.1, 0), COL.midWood, MAT.Wood, { CanCollide = false })
	cyl(food, "Bowl", 0.4, 1.4, sbCF * CFrame.new(-1.2, 3.4, 0) * UP, Color3.fromRGB(220, 214, 200), MAT.SmoothPlastic, { CanCollide = false })
	for i = 0, 2 do
		P(food, "Fish", Vector3.new(1.1, 0.25, 0.4), sbCF * CFrame.new(1.0, 3.32 + i * 0.22, (i - 1) * 0.3) * CFrame.Angles(0, math.rad(i * 25), 0), Color3.fromRGB(150, 160, 170), MAT.SmoothPlastic, { CanCollide = false })
	end

	-- writing desk under the -X window, reading corner under the back window
	local dk = wallCF(6, ai - 1.1, 0.4, F1)
	P(b, "Desk", Vector3.new(4, 0.3, 2), dk * CFrame.new(0, 2.8, 0), COL.midWood, MAT.Wood)
	legs4(b, dk, 1.8, 0.8, 2.65, 0.3, COL.darkWood)
	P(b, "Book", Vector3.new(1.3, 0.15, 1.0), dk * CFrame.new(-0.6, 3.0, 0.1) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(250, 244, 228), MAT.SmoothPlastic, { CanCollide = false })
	candle(b, dk * CFrame.new(1.3, 2.95, 0.3), { range = 8, brightness = 0.6 })
	chair(b, dk * CFrame.new(0, 0, -1.6) * CFrame.Angles(0, math.rad(180), 0))
	bookshelf(b, wallCF(5, ai - 0.75, 0, F1), 4.6, 7.2)
	rug(b, at(1.0, F1, 0.5), 7, 5.5, Color3.fromRGB(122, 36, 40), Color3.fromRGB(205, 175, 110), "BunkRug")
	armchair(b, wallCF(4, ai - 2.6, 2.4, F1) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(110, 34, 40))

	chandelier(b, at(3.4, 64.6, 3.6), 67.4)
	for _, spec in { { 3, 0 }, { 7, 2.6 }, { 1, -2.6 }, { 6, -3.3 } } do
		sconce(b, wallCF(spec[1], aB(F1 + 7) - Bs.t - 0.3, spec[2], F1 + 7.2))
	end
	painting(b, wallCF(7, aB(F1 + 9) - Bs.t - 0.35, 0, F1 + 9.4), 3.0, 2.2, 21)
	painting(b, wallCF(1, aB(F1 + 9) - Bs.t - 0.35, 0, F1 + 9.4), 3.0, 2.2, 22)
	painting(b, wallCF(3, aB(F1 + 9) - Bs.t - 0.35, 0, F1 + 9.0), 2.0, 2.6, 23)
	return "bunk ok"
end

function STAGES.exterior(oldBase)
	local base = floorModel("Base")
	local plinth = oldBase and oldBase:FindFirstChild("Plinth")
	if plinth then
		plinth = plinth:Clone()
	else
		plinth = cyl(nil, "Plinth", 3, 32, at(0, 34.3, 0) * UP, COL.stoneBand, MAT.Slate)
	end
	plinth.Material = MAT.Slate
	plinth.Color = Color3.fromRGB(150, 150, 146)
	plinth.Parent = base
	cyl(base, "PlinthRim", 0.4, 32.6, at(0, 35.6, 0) * UP, Color3.fromRGB(170, 168, 162), MAT.Concrete)
	-- teal guard railing with a gap for the path to the door (+Z)
	local rail = M(base, "Railing")
	local r = 15.6
	local posts = {}
	for deg = 14, 346, 12 do
		local p = at(0, 35.8, 0) * CFrame.Angles(0, math.rad(deg), 0) * CFrame.new(0, 0, r)
		table.insert(posts, p.Position)
		vcyl(rail, "Post", 35.8, 39.2, 0.3, p.X - C.X, p.Z - C.Z, COL.teal, MAT.Metal)
	end
	for i = 2, #posts do
		railBetween(rail, posts[i - 1] + Vector3.new(0, 3.3, 0), posts[i] + Vector3.new(0, 3.3, 0), 0.28, COL.teal, MAT.Metal)
		railBetween(rail, posts[i - 1] + Vector3.new(0, 1.8, 0), posts[i] + Vector3.new(0, 1.8, 0), 0.2, COL.teal, MAT.Metal)
	end
	-- door surround + lamp
	local g = floorModel("GroundFloor")
	local f = faceFrame(0, A.a, F0, 0)
	for _, s in { -1, 1 } do
		P(g, "DoorSurround", Vector3.new(0.9, DOOR.h + 0.6, 0.6), f * CFrame.new(s * (DOOR.w / 2 + 0.45), (DOOR.h + 0.6) / 2 - 0.1, 0.15), COL.stoneBand, MAT.Concrete)
	end
	P(g, "DoorLintel", Vector3.new(DOOR.w + 2.6, 1.1, 0.8), f * CFrame.new(0, DOOR.h + 0.5, 0.2), COL.stoneBand, MAT.Concrete)
	P(g, "DoorKeystone", Vector3.new(1.0, 1.5, 0.9), f * CFrame.new(0, DOOR.h + 0.6, 0.3), COL.trim, MAT.Concrete)
	P(g, "DoorStep", Vector3.new(DOOR.w + 1.4, 0.35, 1.6), f * CFrame.new(0, -0.25, 0.9), COL.stoneBand, MAT.Concrete)
	local lampCF = f * CFrame.new(DOOR.w / 2 + 2.0, 7.2, 0.5)
	local lb = P(g, "DoorLamp", Vector3.new(0.9, 1.3, 0.9), lampCF, Color3.fromRGB(255, 214, 150), MAT.Neon, { CanCollide = false, CastShadow = false })
	P(g, "DoorLampCap", Vector3.new(1.2, 0.3, 1.2), lampCF * CFrame.new(0, 0.8, 0), COL.iron, MAT.Metal, { CanCollide = false })
	P(g, "DoorLampArm", Vector3.new(0.2, 0.2, 0.9), lampCF * CFrame.new(0, 0.6, -0.5), COL.iron, MAT.Metal, { CanCollide = false })
	light(lb, 16, 1.2, COL.warm, true)
	return "exterior ok"
end

function B.run(stage, ...)
	local map = workspace:WaitForChild("Map")
	root = map:FindFirstChild("Lighthouse")
	if not root then
		root = Instance.new("Model")
		root.Name = "Lighthouse"
		root.Parent = map
	end
	return STAGES[stage](...)
end

return B
