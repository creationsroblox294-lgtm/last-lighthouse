--!strict
-- IntroWave: the giant wave in the intro, reshaped every frame (works everywhere: plain parts).
--
-- The wave is 8 overlapping segments across its width; each segment is a ribbon of strips
-- that follow its cross-section (travelling toward -Z): a long gentle back slope rises to the
-- crest, then a steep concave front face falls to the sea, and as it builds the lip throws
-- forward over the face (a breaking wave). Each segment's height, lean and lip wander with
-- noise, so the crest is uneven along its length, and small ripples run over every strip.
-- Colour shades from deep teal at the foot to pale green near the crest and white foam on
-- the lip. A streaky water texture scrolls up the surface so the water visibly flows, and
-- spray and mist are blown off the lip by emitters riding the crest.
--
--   local wave = IntroWave.new(parent, centerX, seaY)
--   wave:update(height, frontZ, curl, time)            -- every frame
--   wave:destroy()

local IntroWave = {}
IntroWave.__index = IntroWave

local WIDTH = 640 -- studs along X
local SEGS = 8 -- segments across
local OVERLAP = 14 -- studs each segment overlaps the next (hides the seams)
local BACK = 12 -- profile points on the back slope
local FRONT = 20 -- profile points on the front face (the side you see)
local MAX_H = 52
local BACK_LEN = 110
local THICK = 1.6
local SMOKE = "rbxassetid://118122779843195"
local STREAKS = "rbxassetid://70735693296785" -- assets/fx/WaveStreaks.png: flowing foam veins

type Strip = { part: Part, tex: Texture }
type Wave = typeof(setmetatable(
	{} :: {
		folder: Folder,
		strips: { { Strip } },
		centerX: number,
		seaY: number,
		holder: Part,
		sprays: { Attachment },
		emitters: { ParticleEmitter },
	},
	IntroWave
))

local DEEP = Color3.fromRGB(14, 74, 96)
local MID = Color3.fromRGB(28, 132, 154)
local LIGHT = Color3.fromRGB(116, 204, 208)
local FOAM = Color3.fromRGB(236, 248, 250)

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- colour by height on the wave (0 = sea, 1 = crest) and whether it's the front face
local function shade(hk: number, front: boolean, curl: number): Color3
	local c = DEEP:Lerp(MID, smooth(hk * 1.5))
	c = c:Lerp(LIGHT, smooth((hk - 0.5) / 0.5) * 0.75)
	if front then
		-- white water just under the lip, more of it as the wave breaks
		local f = smooth((hk - (0.8 - 0.25 * curl)) / 0.2)
		c = c:Lerp(FOAM, math.clamp(f, 0, 0.95))
	elseif hk > 0.93 then
		c = c:Lerp(FOAM, (hk - 0.93) / 0.07 * 0.6)
	end
	return c
end

function IntroWave.new(parent: Instance, centerX: number, seaY: number): Wave?
	local folder = Instance.new("Folder")
	folder.Name = "IntroWave"
	local strips: { { Strip } } = {}
	local segW = WIDTH / SEGS + OVERLAP
	for s = 1, SEGS do
		local row: { Strip } = {}
		for i = 1, BACK + FRONT - 1 do
			local p = Instance.new("Part")
			p.Name = "Water"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.22
			p.Transparency = 0.06
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Size = Vector3.new(segW, THICK, 1)
			local tex = Instance.new("Texture")
			tex.Face = Enum.NormalId.Top
			tex.Texture = STREAKS
			tex.StudsPerTileU = 46
			tex.StudsPerTileV = 34
			tex.Transparency = 0.35
			tex.Parent = p
			p.Parent = folder
			table.insert(row, { part = p, tex = tex })
		end
		strips[s] = row
	end
	folder.Parent = parent

	-- spray blown off the lip, and mist hanging in front of the face
	local holder = Instance.new("Part")
	holder.Name = "WaveSpray"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(centerX, seaY, 0)
	holder.Parent = folder
	local sprays: { Attachment } = {}
	local emitters: { ParticleEmitter } = {}
	for i = 1, 14 do
		local a = Instance.new("Attachment")
		a.Parent = holder
		table.insert(sprays, a)
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255), Color3.fromRGB(190, 215, 225))
		e.LightInfluence = 1
		e.LightEmission = 0.1
		e.Rate = 0
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(10, 22)
		e.SpreadAngle = Vector2.new(25, 35)
		e.EmissionDirection = Enum.NormalId.Front -- toward -Z: thrown ahead of the wave
		e.Acceleration = Vector3.new(0, -10, 0)
		e.Drag = 0.8
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.6, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Parent = a
		table.insert(emitters, e)
		-- every third one also throws a fine mist off the top
		if i % 3 == 0 then
			local m = e:Clone()
			m.Speed = NumberRange.new(3, 7)
			m.Lifetime = NumberRange.new(2.5, 4)
			m.Acceleration = Vector3.new(0, 1.5, 0)
			m.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
			m.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			m.Parent = a
			table.insert(emitters, m)
		end
	end

	return setmetatable({
		folder = folder,
		strips = strips,
		centerX = centerX,
		seaY = seaY,
		holder = holder,
		sprays = sprays,
		emitters = emitters,
	}, IntroWave)
end

-- the cross-section of one segment: points (z back from the front foot, y up), back foot first
local function profile(H: number, over: number, x: number, time: number): { Vector2 }
	local pts: { Vector2 } = {}
	local F = H * 0.55 -- the crest sits this far behind the front foot (before curling)
	local crestZ = F - over
	for r = 1, BACK do
		local k = (r - 1) / (BACK - 1)
		local y = H * smooth(k) ^ 1.15
		local z = crestZ + (1 - k) ^ 1.3 * BACK_LEN
		table.insert(pts, Vector2.new(z, y))
	end
	for r = 1, FRONT do
		local k = r / FRONT
		local y = H * (1 - k) ^ 1.7
		local z = crestZ + (0 - crestZ) * (1 - (1 - k) ^ 2.2)
		-- the face bulges forward under the curling lip
		z -= over * 0.35 * math.sin(math.min(k * 3.2, math.pi)) * (1 - k)
		table.insert(pts, Vector2.new(z, y))
	end
	-- ripples running up the surface
	for i, p in pts do
		local fade = math.clamp(p.Y / math.max(H, 1), 0, 1)
		local ripple = math.sin(p.X * 0.3 - time * 6 + x * 0.04) * 0.35 + math.noise(x / 30, p.X / 9, time * 1.5) * 0.5
		pts[i] = Vector2.new(p.X, p.Y + ripple * (0.3 + 0.7 * fade))
	end
	return pts
end

-- height: crest height (studs), frontZ: world Z of the front foot, curl 0..1: how far the lip
-- has thrown over the face, time: seconds (drives ripples, the wandering crest, the flow)
function IntroWave.update(self: Wave, height: number, frontZ: number, curl: number, time: number)
	height = math.min(height, MAX_H)
	local segW = WIDTH / SEGS
	for s, row in self.strips do
		local x = -WIDTH / 2 + (s - 0.5) * segW
		local nx = x / 90
		-- this stretch's own height, lean and lip, wandering over time
		local H = height * (0.84 + 0.28 * math.noise(nx, time * 0.25, 1.7) + 0.06 * math.sin(s * 1.9 + time * 1.3))
		local lead = 6 * math.noise(nx * 0.7, 3.1, time * 0.2)
		local over = curl * H * 0.62 * (0.75 + 0.5 * math.noise(nx * 1.3, time * 0.4, 9))
		local pts = profile(H, over, x, time)
		local front = BACK -- strips after this index are on the front face
		local along = 0 -- distance along the surface so far: the streaks run on unbroken
		for i, st in row do
			local a, b = pts[i], pts[i + 1]
			local wa = Vector3.new(self.centerX + x, self.seaY + a.Y, frontZ + a.X - lead)
			local wb = Vector3.new(self.centerX + x, self.seaY + b.Y, frontZ + b.X - lead)
			local d = wb - wa
			local len = d.Magnitude
			if len < 0.05 then
				st.part.Transparency = 1
				continue
			end
			local t = d / len
			local up = Vector3.xAxis:Cross(t) -- the strip's outer face (+Y) points out of the water
			local mid = (wa + wb) / 2 - up * (THICK / 2)
			st.part.Size = Vector3.new(st.part.Size.X, THICK, len + 0.7)
			st.part.CFrame = CFrame.lookAt(mid, mid + t, up)
			local hk = math.clamp((a.Y + b.Y) / 2 / math.max(H, 1), 0, 1)
			st.part.Color = shade(hk, i >= front, curl)
			st.part.Transparency = 0.06
			-- the water streaks flow up the face and over the top, continuous from strip to strip
			st.tex.OffsetStudsV = (along - time * 14) % st.tex.StudsPerTileV
			st.tex.OffsetStudsU = (x + math.sin(time * 0.7 + s) * 3) % st.tex.StudsPerTileU
			along += len
		end
	end
	-- spray rides the crest
	local n = #self.sprays
	for i, a in self.sprays do
		local x = -WIDTH * 0.35 + (i - 1) / (n - 1) * WIDTH * 0.7
		local nx = x / 90
		local H = height * (0.84 + 0.28 * math.noise(nx, time * 0.25, 1.7))
		local over = curl * H * 0.62
		a.WorldPosition = Vector3.new(self.centerX + x, self.seaY + H, frontZ + H * 0.55 - over)
	end
	local rate = math.clamp(height / 30, 0, 1) * (25 + curl * 60)
	for _, e in self.emitters do
		e.Rate = rate
	end
end

function IntroWave.destroy(self: Wave)
	self.folder:Destroy()
end

return IntroWave
