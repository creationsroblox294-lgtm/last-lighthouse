-- Studio tool (ServerStorage.Vegetation). Cartoon vegetation + forage plants (carrots,
-- berries, apples, mushrooms, pumpkins), flowers, grass tufts, rocks and logs.
-- Forage models get a Forage attribute and a PickPart for ForageService.
-- Placed in Map.Forage (pickable) and Map.Meadow (decoration).
local V = {}
local function part(parent, name, size, cf, color, mat, cls)
	local p = Instance.new(cls or "Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.Material = mat or Enum.Material.SmoothPlastic; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = size.Magnitude > 1.5; p.Parent = parent
	return p
end
local function jitter(c, rng, a) local k = 1 + rng:NextNumber(-a, a) return Color3.new(math.clamp(c.R*k,0,1), math.clamp(c.G*k,0,1), math.clamp(c.B*k,0,1)) end
local function base(pos, rng) return CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) end
local function pick(m, cf, size, kind)
	local p = part(m, "PickPart", size, cf, Color3.new(1, 1, 1))
	p.Transparency = 1; p.CanQuery = true
	m:SetAttribute("Forage", kind)
	return p
end

function V.carrots(pos, rng)
	local m = Instance.new("Model"); m.Name = "CarrotPatch"
	local b = base(pos, rng)
	part(m, "Soil", Vector3.new(6, 0.5, 4.5), b * CFrame.new(0, 0.1, 0), Color3.fromRGB(92, 64, 42))
	for i = 0, 2 do for j = 0, 1 do
		if rng:NextNumber() < 0.85 then
			local c = b * CFrame.new(-2 + i * 2, 0, -1 + j * 2) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
			part(m, "Carrot", Vector3.new(0.9, 0.7, 0.9), c * CFrame.new(0, 0.55, 0), Color3.fromRGB(235, 128, 36))
			part(m, "Top", Vector3.new(0.35, 1.3, 0.35), c * CFrame.new(-0.2, 1.4, 0) * CFrame.Angles(0, 0, 0.35), Color3.fromRGB(76, 150, 52))
			part(m, "Top", Vector3.new(0.35, 1.5, 0.35), c * CFrame.new(0.2, 1.5, 0.1) * CFrame.Angles(0.2, 0, -0.3), Color3.fromRGB(88, 164, 58))
		end
	end end
	pick(m, b * CFrame.new(0, 1, 0), Vector3.new(6, 2, 4.5), "Carrot")
	m.WorldPivot = b
	return m
end

function V.berryBush(pos, rng)
	local m = Instance.new("Model"); m.Name = "BerryBush"
	local b = base(pos, rng)
	local s = rng:NextNumber(3.6, 4.6)
	local green = jitter(Color3.fromRGB(40, 80, 38), rng, 0.08)
	part(m, "Leaf", Vector3.new(s, s * 0.8, s), b * CFrame.new(0, s * 0.38, 0), green)
	part(m, "Leaf", Vector3.new(s * 0.7, s * 0.6, s * 0.7), b * CFrame.new(s * 0.35, s * 0.3, s * 0.2) * CFrame.Angles(0, 0.7, 0), jitter(green, rng, 0.1))
	local berry = rng:NextNumber() < 0.6 and Color3.fromRGB(196, 32, 48) or Color3.fromRGB(70, 60, 190)
	for _ = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2); local h = rng:NextNumber(0.3, 0.75) * s
		part(m, "Berry", Vector3.new(0.55, 0.55, 0.55), b * CFrame.new(math.cos(a) * s * 0.52, h, math.sin(a) * s * 0.52), berry)
	end
	m:SetAttribute("BerryColor", berry)
	pick(m, b * CFrame.new(0, s * 0.4, 0), Vector3.new(s + 0.5, s, s + 0.5), "Berries")
	m.WorldPivot = b
	return m
end

function V.appleTree(pos, rng)
	local m = Instance.new("Model"); m.Name = "AppleTree"
	local b = base(pos, rng)
	local th = rng:NextNumber(9, 12)
	local stem = part(m, "Stem", Vector3.new(1.8, th, 1.8), b * CFrame.new(0, th / 2 - 0.4, 0), Color3.fromRGB(88, 60, 40))
	stem.CanCollide = true; stem.CanQuery = true
	local green = jitter(Color3.fromRGB(48, 90, 40), rng, 0.06)
	local c = b * CFrame.new(0, th + 2.5, 0)
	part(m, "Leaves", Vector3.new(10, 6, 10), c, green)
	part(m, "Leaves", Vector3.new(7, 4, 7), c * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(45), 0), jitter(green, rng, 0.08))
	for i = 1, 4 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		part(m, "Leaves", Vector3.new(5, 4, 5), c * CFrame.new(math.cos(a) * 4.6, rng:NextNumber(-1.2, 1), math.sin(a) * 4.6), jitter(green, rng, 0.1))
	end
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2); local r = rng:NextNumber(4.2, 5.4)
		part(m, "Apple", Vector3.new(0.8, 0.8, 0.8), c * CFrame.new(math.cos(a) * r, rng:NextNumber(-3, 1.5), math.sin(a) * r), Color3.fromRGB(206, 36, 36))
	end
	pick(m, b * CFrame.new(0, 3, 0), Vector3.new(5, 6, 5), "Apple")
	m.WorldPivot = b
	return m
end

function V.mushrooms(pos, rng)
	local m = Instance.new("Model"); m.Name = "Mushrooms"
	local b = base(pos, rng)
	local red = rng:NextNumber() < 0.65
	for _ = 1, rng:NextInteger(2, 4) do
		local o = b * CFrame.new(rng:NextNumber(-1.4, 1.4), 0, rng:NextNumber(-1.4, 1.4))
		local h = rng:NextNumber(0.8, 1.6); local w = h * rng:NextNumber(1.1, 1.5)
		part(m, "Stalk", Vector3.new(w * 0.35, h, w * 0.35), o * CFrame.new(0, h / 2, 0), Color3.fromRGB(236, 228, 210))
		part(m, "Cap", Vector3.new(w, w * 0.45, w), o * CFrame.new(0, h + w * 0.18, 0) * CFrame.Angles(0, math.rad(45), 0), red and Color3.fromRGB(200, 40, 36) or Color3.fromRGB(168, 120, 78))
		if red then part(m, "Spot", Vector3.new(w * 0.22, 0.12, w * 0.22), o * CFrame.new(w * 0.15, h + w * 0.42, 0), Color3.new(1, 1, 1)) end
	end
	pick(m, b * CFrame.new(0, 1, 0), Vector3.new(3.5, 2, 3.5), "Mushroom")
	m.WorldPivot = b
	return m
end

function V.pumpkins(pos, rng)
	local m = Instance.new("Model"); m.Name = "PumpkinPatch"
	local b = base(pos, rng)
	for _ = 1, rng:NextInteger(2, 3) do
		local o = b * CFrame.new(rng:NextNumber(-2.2, 2.2), 0, rng:NextNumber(-2.2, 2.2)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
		local s = rng:NextNumber(1.6, 2.4)
		part(m, "Pumpkin", Vector3.new(s, s * 0.8, s), o * CFrame.new(0, s * 0.4, 0), Color3.fromRGB(226, 120, 30))
		part(m, "Pumpkin", Vector3.new(s * 0.7, s * 0.82, s * 1.1), o * CFrame.new(0, s * 0.4, 0), Color3.fromRGB(240, 134, 38))
		part(m, "Stem", Vector3.new(0.3, 0.6, 0.3), o * CFrame.new(0, s * 0.85, 0), Color3.fromRGB(76, 110, 44))
		part(m, "Vine", Vector3.new(2.6, 0.2, 0.9), o * CFrame.new(s * 0.7, 0.1, 0.4) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(70, 128, 48))
	end
	pick(m, b * CFrame.new(0, 1, 0), Vector3.new(5, 2.5, 5), "Pumpkin")
	m.WorldPivot = b
	return m
end

local FLOWER = { Color3.fromRGB(240, 220, 70), Color3.fromRGB(236, 90, 120), Color3.fromRGB(250, 250, 250), Color3.fromRGB(150, 110, 230), Color3.fromRGB(250, 150, 60) }
function V.flowers(pos, rng)
	local m = Instance.new("Model"); m.Name = "Flowers"
	local b = base(pos, rng)
	local col = FLOWER[rng:NextInteger(1, #FLOWER)]
	for _ = 1, rng:NextInteger(3, 6) do
		local o = b * CFrame.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		local h = rng:NextNumber(0.8, 1.4)
		part(m, "Stem", Vector3.new(0.15, h, 0.15), o * CFrame.new(0, h / 2, 0), Color3.fromRGB(70, 130, 50))
		part(m, "Bloom", Vector3.new(0.5, 0.3, 0.5), o * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(45), 0), col)
	end
	m.WorldPivot = b
	return m
end

function V.tuft(pos, rng)
	local m = Instance.new("Model"); m.Name = "GrassTuft"
	local b = base(pos, rng)
	local g = jitter(Color3.fromRGB(70, 118, 48), rng, 0.12)
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(1.2, 2.4)
		part(m, "Blade", Vector3.new(0.3, h, 0.6), b * CFrame.new(rng:NextNumber(-0.6, 0.6), h / 2 - 0.1, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), jitter(g, rng, 0.1), nil, "WedgePart")
	end
	m.WorldPivot = b
	return m
end

function V.rock(pos, rng)
	local m = Instance.new("Model"); m.Name = "Rock"
	local b = base(pos, rng)
	local s = rng:NextNumber(1.5, 4)
	local g = jitter(Color3.fromRGB(120, 122, 126), rng, 0.1)
	local r = part(m, "Stone", Vector3.new(s * 1.3, s * 0.8, s), b * CFrame.new(0, s * 0.25, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), g, Enum.Material.Slate)
	r.CanCollide = s > 2.5; r.CanQuery = r.CanCollide
	part(m, "Stone", Vector3.new(s * 0.6, s * 0.5, s * 0.6), b * CFrame.new(s * 0.7, s * 0.15, s * 0.3), jitter(g, rng, 0.08), Enum.Material.Slate)
	m.WorldPivot = b
	return m
end

function V.log(pos, rng)
	local m = Instance.new("Model"); m.Name = "FallenLog"
	local b = base(pos, rng)
	local len = rng:NextNumber(7, 12)
	local l = part(m, "Log", Vector3.new(len, 1.8, 1.8), b * CFrame.new(0, 0.7, 0), Color3.fromRGB(92, 64, 44))
	l.CanCollide = true; l.CanQuery = true
	part(m, "End", Vector3.new(0.1, 1.5, 1.5), b * CFrame.new(len / 2 + 0.02, 0.7, 0), Color3.fromRGB(196, 160, 112))
	part(m, "Moss", Vector3.new(len * 0.5, 0.25, 1.4), b * CFrame.new(-len * 0.1, 1.65, 0), Color3.fromRGB(70, 120, 50))
	m.WorldPivot = b
	return m
end
return V
