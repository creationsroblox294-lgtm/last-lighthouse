--!strict
-- IntroWaveMesh: the intro's giant wave as a skinned mesh animated in Blender.
--
-- ReplicatedStorage.IntroAssets.Wave holds the mesh (MeshPart "Body", 400 studs wide, with 4 bone
-- chains of 11 bones running from the back foot over the crest and lip to the front foot) and
-- Shared.WaveAnimData holds the bone paths of the "Break" animation (swell -> steep face ->
-- pitching lip -> barrel -> collapse, 4 s). Every frame we place the mesh, sample the paths
-- (Catmull-Rom between the 10 fps samples) and set each bone's Transform: moved along its path
-- and turned with the surface's slope, so the sheet bends exactly as it did in Blender.
-- Spray rides the lip bones; whitewater blows out of the foot as it collapses.
--
--   local wave = IntroWaveMesh.new(parent, centerX, seaY, hitZ)  -- nil if the asset is missing
--   wave:update(w)        -- w = seconds since the wave appeared
--   wave:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IntroWaveMesh = {}
IntroWaveMesh.__index = IntroWaveMesh

local SMOKE = "rbxassetid://118122779843195"
local CHAINS, BONES = 4, 11
local LIP = 30 -- metres ahead of the wave's origin where the lip comes down
local SPEED = 24 -- studs/s the wave rolls forward
local START = 0.2 -- animation time when the wave appears
local RATE = 1.3 -- animation seconds per cutscene second
local HIT_AT = 1.8 -- cutscene seconds after appearing when the lip lands on the boat

type Track = { rest: Vector2, samples: { Vector2 } } -- (y, z) in Blender metres
type Bone_ = { bone: Bone, rest: CFrame, track: Track, chain: number, k: number }
export type WaveMesh = typeof(setmetatable(
	{} :: {
		model: Model,
		body: MeshPart,
		bones: { Bone_ },
		tracks: { { Track } },
		fps: number,
		duration: number,
		centerX: number,
		seaY: number,
		hitZ: number,
		origin: Vector3, -- Blender origin in the mesh's space
		lipFx: { ParticleEmitter },
		footFx: { ParticleEmitter },
	},
	IntroWaveMesh
))

local function parseTrack(s: string): Track
	local nums = {}
	for n in string.gmatch(s, "%S+") do
		table.insert(nums, tonumber(n) :: number)
	end
	local samples = {}
	for i = 3, #nums - 1, 2 do
		table.insert(samples, Vector2.new(nums[i], nums[i + 1]))
	end
	return { rest = Vector2.new(nums[1], nums[2]), samples = samples }
end

local function catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: number): Vector2
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local function sample(track: Track, pos: number): Vector2
	local s = track.samples
	local n = #s
	pos = math.clamp(pos, 0, n - 1)
	local i = math.floor(pos) + 1
	local f = pos - (i - 1)
	return catmull(s[math.max(i - 1, 1)], s[i], s[math.min(i + 1, n)], s[math.min(i + 2, n)], f)
end

-- slope angle of the sheet at bone k from its neighbours, in the mesh's Y/Z plane
-- (Blender (y, z) -> mesh (z, y)); rotating about mesh X by the change in this angle turns the bone
local function slope(points: { Vector2 }, k: number): number
	local a = points[math.max(k - 1, 1)]
	local b = points[math.min(k + 1, #points)]
	local d = b - a
	-- mesh-space tangent is (0, d.Y, d.X); angle measured like CFrame.Angles(phi, 0, 0) turns it
	return math.atan2(-d.Y, d.X)
end

local function emitter(parent: Instance, lifetime: NumberRange, speed: NumberRange, size0: number, size1: number, dir: Enum.NormalId, accel: Vector3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255), Color3.fromRGB(190, 215, 225))
	e.LightInfluence = 1
	e.LightEmission = 0.1
	e.Rate = 0
	e.Lifetime = lifetime
	e.Speed = speed
	e.SpreadAngle = Vector2.new(30, 40)
	e.EmissionDirection = dir
	e.Acceleration = accel
	e.Drag = 0.8
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = parent
	return e
end

function IntroWaveMesh.new(parent: Instance, centerX: number, seaY: number, hitZ: number): WaveMesh?
	local assets = ReplicatedStorage:FindFirstChild("IntroAssets")
	local template = assets and assets:FindFirstChild("Wave")
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local dataModule = shared and shared:FindFirstChild("WaveAnimData")
	if not (template and template:IsA("Model") and dataModule and dataModule:IsA("ModuleScript")) then
		return nil
	end
	local data = require(dataModule) :: any
	local model = template:Clone()
	local body = model:FindFirstChild("Body", true)
	if not (body and body:IsA("MeshPart")) then
		model:Destroy()
		return nil
	end
	local root = body:FindFirstChild("Root")
	if not (root and root:IsA("Bone")) then
		model:Destroy()
		return nil
	end

	local tracks: { { Track } } = {}
	for c = 1, CHAINS do
		local row = {}
		for part in string.gmatch(data.chains[c], "[^|]+") do
			table.insert(row, parseTrack(part))
		end
		tracks[c] = row
	end

	local bones: { Bone_ } = {}
	local lipFx, footFx = {}, {}
	for c = 1, CHAINS do
		for k = 1, BONES do
			local b = root:FindFirstChild(string.format("C%d_%d", c - 1, k - 1))
			if b and b:IsA("Bone") then
				table.insert(bones, { bone = b, rest = root.CFrame * b.CFrame, track = tracks[c][k], chain = c, k = k })
				if k == 8 then
					-- spray torn off the lip and thrown ahead (-Z), plus mist off the top
					table.insert(lipFx, emitter(b, NumberRange.new(1.2, 2.2), NumberRange.new(10, 24), 3, 12, Enum.NormalId.Front, Vector3.new(0, -10, 0)))
					table.insert(lipFx, emitter(b, NumberRange.new(2.5, 4), NumberRange.new(3, 7), 8, 24, Enum.NormalId.Top, Vector3.new(0, 1.5, 0)))
				elseif k == 10 then
					table.insert(footFx, emitter(b, NumberRange.new(1.5, 2.8), NumberRange.new(14, 30), 6, 20, Enum.NormalId.Front, Vector3.new(0, 4, 0)))
				end
			end
		end
	end

	-- where Blender's origin sits in the mesh: Root's rest position (Blender (x, y, z) -> mesh (-x, z, y))
	local origin = root.CFrame.Position
	body.Anchored = true
	model.Parent = parent

	local self = setmetatable({
		model = model,
		body = body,
		bones = bones,
		tracks = tracks,
		fps = data.fps,
		duration = data.duration,
		centerX = centerX,
		seaY = seaY,
		hitZ = hitZ,
		origin = origin,
		lipFx = lipFx,
		footFx = footFx,
	}, IntroWaveMesh)
	-- out of sight (deep under the sea) until the cutscene's first update(w)
	body.CFrame = CFrame.new(centerX, seaY - 400, hitZ)
	return self
end

-- w: seconds since the wave appeared in the cutscene
function IntroWaveMesh.update(self: WaveMesh, w: number)
	local a = math.clamp(START + w * RATE, 0, self.duration) -- animation time
	local pos = a * self.fps -- fractional sample index

	-- roll forward: the lip (LIP metres ahead of Blender's origin) lands on hitZ at HIT_AT
	local originZ = self.hitZ + LIP + SPEED * (HIT_AT - w)
	self.body.CFrame = CFrame.new(self.centerX, self.seaY - self.origin.Y, originZ - self.origin.Z)

	-- current and rest points of every chain, for the slopes
	for c = 1, CHAINS do
		local row = self.tracks[c]
		local now, rest = table.create(BONES), table.create(BONES)
		for k = 1, BONES do
			now[k] = sample(row[k], pos)
			rest[k] = row[k].rest
		end
		for _, b in self.bones do
			if b.chain == c then
				local p, r = now[b.k], rest[b.k]
				local move = Vector3.new(0, p.Y - r.Y, p.X - r.X) -- Blender (dy, dz) -> mesh (0, dz, dy)
				local turn = slope(now, b.k) - slope(rest, b.k)
				local want = CFrame.new(b.rest.Position + move) * CFrame.Angles(turn, 0, 0) * b.rest.Rotation
				b.bone.Transform = b.rest:Inverse() * want
			end
		end
	end

	-- spray: the lip feathers as it steepens, tears off as it pitches, whitewater on the collapse
	local pitch = math.clamp((a - 1.3) / 0.6, 0, 1) * (1 - math.clamp((a - 3.4) / 0.5, 0, 1))
	local collapse = math.clamp((a - 2.9) / 0.5, 0, 1)
	for i, e in self.lipFx do
		e.Rate = if i % 2 == 1 then 70 * pitch else 14 * pitch
	end
	for _, e in self.footFx do
		e.Rate = 90 * collapse
	end
end

function IntroWaveMesh.destroy(self: WaveMesh)
	self.model:Destroy()
end

return IntroWaveMesh
