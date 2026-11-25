--!nocheck
-- Island dressing (Edit mode): rolling grassy hills, a winding creek to the beach,
-- stylised palms + blocky broadleaf trees (choppable, in Map.PineGrove), ferns, rocks, haze.
-- Keeps the lighthouse cliff, ramp, tide pools, wreck beach and dock untouched.
local I = {}

local T = workspace.Terrain
local MAT = Enum.Material
local rng = Random.new(20261125)

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- distance from a point to an axis-aligned box in XZ (0 inside)
local function boxDist(x, z, x0, x1, z0, z1)
	local dx = math.max(x0 - x, 0, x - x1)
	local dz = math.max(z0 - z, 0, z - z1)
	return math.sqrt(dx * dx + dz * dz)
end

local STREAM = {
	Vector2.new(-18, -96), Vector2.new(-34, -70), Vector2.new(-28, -42), Vector2.new(-42, -14),
	Vector2.new(-38, 14), Vector2.new(-52, 40), Vector2.new(-46, 66), Vector2.new(-58, 92),
	Vector2.new(-54, 118), Vector2.new(-62, 150),
}

local function streamDist(x, z)
	local p = Vector2.new(x, z)
	local best = math.huge
	for i = 2, #STREAM do
		local a, b = STREAM[i - 1], STREAM[i]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (a + ab * t - p).Magnitude)
	end
	return best
end
I.streamDist = streamDist

-- how far from anything that must stay flat
local function featureDist(x, z)
	return math.min(
		boxDist(x, z, 0, 100, -140, -22), -- lighthouse cliff
		boxDist(x, z, 38, 72, -40, 62), -- ramp corridor
		Vector2.new(x - 106, z - 42).Magnitude - 30, -- tide pools
		Vector2.new(x + 96, z - 112).Magnitude - 38, -- wreck beach
		boxDist(x, z, -45, 12, 125, 220) -- dock
	)
end
I.featureDist = featureDist

local function hillHeight(x, z)
	local r = Vector2.new(x, z).Magnitude
	local w = 1 - smooth((r - 62) / 40)
	w *= smooth((featureDist(x, z) - 4) / 22)
	w *= smooth((streamDist(x, z) - 7) / 16)
	if w <= 0 then
		return 6
	end
	local n = math.noise(x / 58, z / 58, 1.7) * 0.65 + math.noise(x / 23, z / 23, 7.3) * 0.35
	return 6 + math.max(0, n + 0.3) * 20 * w
end
I.hillHeight = hillHeight

function I.terrain()
	local count = 0
	for x = -128, 128, 4 do
		for z = -128, 128, 4 do
			local h = hillHeight(x, z)
			if h > 7 then
				T:FillBlock(CFrame.new(x, (4 + h) / 2, z), Vector3.new(4, h - 4, 4), MAT.Grass)
				count += 1
			end
		end
		task.wait()
	end
	return count
end

function I.stream()
	local pts = {}
	for i = 2, #STREAM do
		local a, b = STREAM[i - 1], STREAM[i]
		local n = math.ceil((b - a).Magnitude / 2)
		for j = 0, n - 1 do
			table.insert(pts, a:Lerp(b, j / n))
		end
	end
	for _, p in pts do
		T:FillBall(Vector3.new(p.X, 0.5, p.Y), 6.5, MAT.Sand)
	end
	task.wait()
	for i, p in pts do
		local wob = math.noise(i / 9, 3.1) * 1.2
		T:FillBall(Vector3.new(p.X, 6.5, p.Y), 4.6 + wob, MAT.Air)
		T:FillBall(Vector3.new(p.X, 1.2, p.Y), 4.1 + wob, MAT.Water)
	end
	task.wait()
	-- small pond at the source
	T:FillBall(Vector3.new(-18, 6.5, -96), 9, MAT.Air)
	T:FillBall(Vector3.new(-18, 0.6, -96), 8.6, MAT.Water)
	return #pts
end

---------------------------------------------------------------------------
-- vegetation
---------------------------------------------------------------------------
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = { T }

local function ground(x, z)
	local r = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), ray)
	if r then
		return r.Position.Y, r.Material
	end
	return nil, nil
end

local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
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

local LEAF = MAT.LeafyGrass
local function leafColor()
	return Color3.fromHSV(rng:NextNumber(0.27, 0.33), rng:NextNumber(0.5, 0.68), rng:NextNumber(0.42, 0.58))
end

local function palm(parent, pos, scale)
	local m = Instance.new("Model")
	m.Name = "Palm"
	local dir = rng:NextNumber(0, math.pi * 2)
	local horiz = Vector3.new(math.cos(dir), 0, math.sin(dir))
	local H = rng:NextNumber(17, 22) * scale
	local lean = rng:NextNumber(0.15, 0.4) * H
	local segs = 9
	local trunkCol = Color3.fromRGB(180, 122, 96)
	local function pt(t)
		return pos + Vector3.new(0, t * H, 0) + horiz * lean * t * t
	end
	local first
	for i = 1, segs do
		local a, b = pt((i - 1) / segs), pt(i / segs)
		local w = (1.6 - 0.6 * i / segs) * scale
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, 0, i * 0.4)
		local p = P(m, i == 1 and "Trunk" or "TrunkSeg", Vector3.new(w, w, (b - a).Magnitude * 1.08), cf, trunkCol:Lerp(Color3.fromRGB(140, 92, 72), (i % 2) * 0.35), MAT.Wood)
		first = first or p
	end
	local cf = CFrame.new(pt(1))
	local top = cf.Position
	for i = 1, 3 do
		local a = i * 2.1
		P(m, "Coconut", Vector3.new(0.8, 0.8, 0.8) * scale, CFrame.new(top + Vector3.new(math.cos(a) * 0.7, -0.6, math.sin(a) * 0.7) * scale), Color3.fromRGB(92, 70, 40), MAT.Wood, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
	local fronds = 9
	for f = 1, fronds do
		local yaw = f / fronds * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local col = leafColor()
		local c = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(rng:NextNumber(8, 32)), 0, 0)
		local len = rng:NextNumber(3.2, 4.0) * scale
		for k = 1, 3 do
			local width = (2.2 - k * 0.45) * scale
			P(m, "Frond", Vector3.new(width, 0.15, len), c * CFrame.new(0, 0, -len / 2), col, LEAF, { CanCollide = false, CastShadow = true })
			c = c * CFrame.new(0, 0, -len) * CFrame.Angles(math.rad(-22 - k * 6), 0, 0)
			len *= 0.85
		end
	end
	m.PrimaryPart = first
	m.Parent = parent
	return m
end

local function broadleaf(parent, pos, scale)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local trunkH = rng:NextNumber(11, 16) * scale
	local w = 1.6 * scale
	local trunkCol = Color3.fromRGB(112, 62, 52)
	local tilt = CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 6.28), rng:NextNumber(-0.08, 0.08))
	local base = CFrame.new(pos) * tilt
	P(m, "Trunk", Vector3.new(w, trunkH, w), base * CFrame.new(0, trunkH / 2 - 0.5, 0), trunkCol, MAT.Wood)
	local crown = (base * CFrame.new(0, trunkH, 0)).Position
	for b = 1, 3 do
		local yaw = b * 2.1 + rng:NextNumber(-0.4, 0.4)
		local blen = rng:NextNumber(4, 6) * scale
		local bc = base * CFrame.new(0, trunkH * rng:NextNumber(0.6, 0.85), 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-50), 0, 0)
		P(m, "Branch", Vector3.new(w * 0.55, blen, w * 0.55), bc * CFrame.new(0, blen / 2, 0), trunkCol, MAT.Wood, { CanCollide = false })
		local tip = (bc * CFrame.new(0, blen, 0)).Position
		for k = 1, 3 do
			local s = rng:NextNumber(5, 8) * scale
			P(m, "Leaves", Vector3.new(s, s * 0.45, s * rng:NextNumber(0.8, 1.2)), CFrame.new(tip + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-0.5, 1.5), rng:NextNumber(-2, 2)) * scale) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), leafColor(), LEAF, { CanCollide = false })
		end
	end
	for k = 1, 4 do
		local s = rng:NextNumber(7, 10) * scale
		P(m, "Leaves", Vector3.new(s, s * 0.45, s), CFrame.new(crown + Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(0, 2.5), rng:NextNumber(-2.5, 2.5)) * scale) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(-0.25, 0.25)), leafColor(), LEAF, { CanCollide = false })
	end
	m.PrimaryPart = m.Trunk
	m.Parent = parent
	return m
end

local function fern(parent, pos, scale)
	local m = Instance.new("Model")
	m.Name = "Fern"
	local col = leafColor()
	for f = 1, 7 do
		local c = CFrame.new(pos) * CFrame.Angles(0, f / 7 * 6.28 + rng:NextNumber(-0.3, 0.3), 0) * CFrame.Angles(math.rad(rng:NextNumber(35, 60)), 0, 0)
		P(m, "Leaf", Vector3.new(0.9 * scale, 0.1, 3.2 * scale), c * CFrame.new(0, 0, -1.5 * scale), col, LEAF, { CanCollide = false, CastShadow = false })
	end
	m.Parent = parent
	return m
end

local function rock(parent, pos, s)
	return P(parent, "Rock", Vector3.new(s * rng:NextNumber(0.8, 1.4), s * rng:NextNumber(0.5, 0.8), s), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)), Color3.fromRGB(58, 62, 74), MAT.Slate)
end

local function okSpot(x, z, minFeature, minStream)
	if featureDist(x, z) < minFeature or streamDist(x, z) < minStream then
		return false
	end
	if Vector2.new(x - 55, z + 80).Magnitude < 40 then
		return false
	end
	return true
end

function I.vegetation()
	local map = workspace.Map
	local grove = map:FindFirstChild("PineGrove")
	-- replace the old pines with the new trees (still choppable: models with a Trunk inside PineGrove)
	for _, c in grove:GetChildren() do
		if c:IsA("Model") and c.Name:match("^Pine") then
			c:Destroy()
		end
	end
	local deco = map:FindFirstChild("Jungle") or Instance.new("Folder")
	deco.Name = "Jungle"
	deco.Parent = map
	local placed = {}
	local function far(x, z, d)
		for _, p in placed do
			if (p - Vector2.new(x, z)).Magnitude < d then
				return false
			end
		end
		return true
	end
	local nPalm, nTree, tries = 0, 0, 0
	-- broadleaf trees inland and in the grove
	while nTree < 34 and tries < 4000 do
		tries += 1
		local x, z = rng:NextNumber(-120, 120), rng:NextNumber(-120, 110)
		local r = Vector2.new(x, z).Magnitude
		local inGrove = x < -25 and x > -120 and z > -60 and z < 25
		if (r < 95 or inGrove) and okSpot(x, z, 6, 8) and far(x, z, inGrove and 11 or 15) then
			local y, mat = ground(x, z)
			if y and mat == MAT.Grass then
				broadleaf(grove, Vector3.new(x, y, z), rng:NextNumber(0.85, 1.25))
				table.insert(placed, Vector2.new(x, z))
				nTree += 1
			end
		end
		if tries % 40 == 0 then
			task.wait()
		end
	end
	-- palms: dense near the shore, a few inland
	tries = 0
	while nPalm < 60 and tries < 6000 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = if rng:NextNumber() < 0.75 then rng:NextNumber(85, 135) else rng:NextNumber(30, 90)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if okSpot(x, z, 4, 7) and far(x, z, 9) then
			local y, mat = ground(x, z)
			if y and y > 4 and (mat == MAT.Grass or mat == MAT.Sand) then
				local parent = if nPalm % 2 == 0 then grove else deco
				palm(parent, Vector3.new(x, y - 0.3, z), rng:NextNumber(0.9, 1.3))
				table.insert(placed, Vector2.new(x, z))
				nPalm += 1
			end
		end
		if tries % 40 == 0 then
			task.wait()
		end
	end
	-- ferns + rocks
	local nF, nR = 0, 0
	for i = 1, 900 do
		local x, z = rng:NextNumber(-140, 140), rng:NextNumber(-140, 140)
		if okSpot(x, z, 2, 5.5) then
			local y, mat = ground(x, z)
			if y and mat == MAT.Grass and nF < 110 then
				fern(deco, Vector3.new(x, y, z), rng:NextNumber(0.8, 1.4))
				nF += 1
			elseif y and (mat == MAT.Sand or mat == MAT.Grass) and nR < 70 and rng:NextNumber() < 0.5 then
				rock(deco, Vector3.new(x, y + 0.1, z), rng:NextNumber(0.8, 2.2))
				nR += 1
			end
		end
		if i % 60 == 0 then
			task.wait()
		end
	end
	return string.format("trees %d palms %d ferns %d rocks %d", nTree, nPalm, nF, nR)
end

function I.atmosphere()
	local L = game:GetService("Lighting")
	local atm = L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", L)
	atm.Density = 0.33
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(205, 224, 236)
	atm.Decay = Color3.fromRGB(110, 150, 175)
	atm.Glare = 0.25
	atm.Haze = 1.6
	T.Decoration = true
	T:SetMaterialColor(MAT.Grass, Color3.fromRGB(84, 132, 58))
	T:SetMaterialColor(MAT.LeafyGrass, Color3.fromRGB(88, 140, 60))
	T:SetMaterialColor(MAT.Sand, Color3.fromRGB(196, 196, 178))
	T.WaterColor = Color3.fromRGB(46, 112, 170)
	T.WaterTransparency = 0.55
	return "atm ok"
end

return I
