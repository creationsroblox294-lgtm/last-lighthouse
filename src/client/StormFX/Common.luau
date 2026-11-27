--!strict
-- Shared building blocks for storm visuals (StormFX/<StormId> modules use these).
-- Every effect follows the camera, fades in over FADE seconds and cleans up after itself.
--
-- Flow: the fade in/out is eased (smoothstep), a slow gusting wind (ctx.gust) sways every
-- falling / floating particle so nothing moves in straight lines, sky changes (clouds, grade)
-- follow the same eased ramp, and lightning is drawn with soft glowing beams instead of blocks.
-- StormFXController starts a storm's look at a low level during the Warning (it rolls in) and
-- lets it fade out at dawn.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Common = {}

Common.FADE = 8

-- Soft textures made for the storms (see assets/fx; used when a storm has no texture of its own)
Common.TEX = {
	SoftGlow = "rbxassetid://105240361456761",
	SoftRing = "rbxassetid://140406055990704",
	BoltBeam = "rbxassetid://100276400296878", -- soft across the width, even along the length
	Wisp = "rbxassetid://118122779843195",
	Streak = "rbxassetid://129570712436307",
}
Common.FALLBACK = Common.TEX.SoftGlow

-- Fired with a world position whenever a lightning bolt appears (players flinch)
Common.Flashed = Instance.new("BindableEvent")

export type Ctx = {
	folder: Folder,
	textures: { [string]: string },
	ramp: number, -- 0..1 fade-in (eased)
	gust: Vector3, -- the slowly turning, gusting wind (length ~0..1.3)
	time: number,
	cleanup: { () -> () },
	finalize: { () -> () }, -- after the fade-out has finished
	onFrame: { (dt: number, camPos: Vector3, ramp: number) -> () },
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
Common.smooth = smooth

-- A smooth wind that wanders and gusts (same for everyone on the client)
function Common.gustAt(t: number): Vector3
	local x = math.noise(t * 0.07, 3.1) + 0.6 * math.noise(t * 0.31, 8.4)
	local z = math.noise(t * 0.07, 17.7) + 0.6 * math.noise(t * 0.29, 2.2)
	local surge = 0.65 + 0.55 * math.noise(t * 0.18, 41.3)
	return Vector3.new(x, 0, z) * surge
end

function Common.ns(...: number): NumberSequence
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(keys)
end

function Common.tween(inst: Instance, seconds: number, goal: { [string]: any }): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
	t:Play()
	return t
end

function Common.part(ctx: Ctx, name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = ctx.folder
	return p
end

function Common.tex(ctx: Ctx, key: string): string
	return ctx.textures[key] or (Common.TEX :: any)[key] or Common.FALLBACK
end

-- A sheet above the camera that emits falling particles.
-- opts: Texture, Rate, Speed (NumberRange), Size, Lifetime, Squash, Brightness, Color,
-- Transparency, Slant (Vector3 acceleration), Height, Width, Orientation, LightEmission
function Common.fall(ctx: Ctx, name: string, opts: { [string]: any }): ParticleEmitter
	local width = opts.Width or 150
	local sheet = Common.part(ctx, name .. "Sheet", Vector3.new(width, 1, width))
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = opts.Texture or Common.FALLBACK
	-- FacingCameraWorldUp + a positive Squash keeps tall textures (rain streaks) upright
	e.Orientation = opts.Orientation or Enum.ParticleOrientation.FacingCameraWorldUp
	e.Color = opts.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = opts.LightEmission or 0.6
	e.LightInfluence = opts.LightInfluence or 0
	e.Brightness = opts.Brightness or 1
	e.Size = opts.Size or Common.ns(0, 0.5, 1, 0.5)
	if opts.Squash then
		e.Squash = opts.Squash
	end
	e.Transparency = opts.Transparency or Common.ns(0, 1, 0.08, 0.1, 0.9, 0.1, 1, 1)
	e.Lifetime = opts.Lifetime or NumberRange.new(1.6, 1.9)
	e.Speed = opts.Speed or NumberRange.new(50, 60)
	e.Acceleration = opts.Slant or Vector3.zero
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = opts.Spread or Vector2.new(3, 3)
	e.RotSpeed = opts.RotSpeed or NumberRange.new(0)
	e.Rotation = opts.Rotation or NumberRange.new(0)
	e.Rate = 0
	e.Parent = sheet
	local rate = opts.Rate or 800
	local height = opts.Height or 55
	local offset = opts.Offset or Vector3.zero
	local slant: Vector3 = opts.Slant or Vector3.zero
	local sway: number = opts.Sway or 14 -- how much the gusts push the fall around
	table.insert(ctx.onFrame, function(_dt, camPos, ramp)
		local push = ctx.gust * sway
		-- the sheet sits a little upwind so the slanted fall still lands around the camera
		sheet.CFrame = CFrame.new(camPos + Vector3.new(0, height, 0) + offset - push * 0.6)
		e.Acceleration = slant + push
		e.Rate = rate * ramp
	end)
	return e
end

-- A box around the camera that emits floating particles (motes, dust, snow flurries...)
function Common.around(ctx: Ctx, name: string, size: Vector3, opts: { [string]: any }): ParticleEmitter
	local box = Common.part(ctx, name .. "Box", size)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = opts.Texture or Common.FALLBACK
	e.LightEmission = opts.LightEmission or 1
	e.LightInfluence = opts.LightInfluence or 0
	e.Brightness = opts.Brightness or 1
	e.Color = opts.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = opts.Size or Common.ns(0, 0, 0.2, 0.35, 0.8, 0.35, 1, 0)
	e.Transparency = opts.Transparency or Common.ns(0, 1, 0.2, 0.25, 0.8, 0.25, 1, 1)
	e.Lifetime = opts.Lifetime or NumberRange.new(4, 7)
	e.Speed = opts.Speed or NumberRange.new(0.6, 1.6)
	e.SpreadAngle = opts.Spread or Vector2.new(180, 180)
	e.Acceleration = opts.Acceleration or Vector3.zero
	e.RotSpeed = opts.RotSpeed or NumberRange.new(-20, 20)
	e.Rotation = opts.Rotation or NumberRange.new(0, 360)
	if opts.Orientation then
		e.Orientation = opts.Orientation
	end
	e.Drag = opts.Drag or 0.35
	e.Rate = 0
	e.Parent = box
	local rate = opts.Rate or 20
	local offset = opts.Offset or Vector3.new(0, -2, 0)
	local base: Vector3 = opts.Acceleration or Vector3.zero
	local sway: number = opts.Sway or 2.5 -- motes drift and curl with the gusts
	table.insert(ctx.onFrame, function(_dt, camPos, ramp)
		box.CFrame = CFrame.new(camPos + offset)
		e.Acceleration = base + ctx.gust * sway
		e.Rate = rate * ramp
	end)
	return e
end

-- Impacts: emits from random ground / water points near the camera.
-- onLand(material, emitAt) is called per impact; return value ignored.
function Common.impacts(ctx: Ctx, perSecond: number, radius: number, onHit: (Enum.Material) -> ())
	local anchor = Common.part(ctx, "ImpactAnchor", Vector3.one)
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local rnd = Random.new()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local clock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		clock += dt * perSecond * ramp
		local filter = { ctx.folder :: Instance }
		local character = Players.LocalPlayer.Character
		if character then
			table.insert(filter, character)
		end
		params.FilterDescendantsInstances = filter
		local n = 0
		while clock >= 1 and n < 12 do
			clock -= 1
			n += 1
			local a = rnd:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rnd:NextNumber()) * radius
			local from = camPos + Vector3.new(math.cos(a) * r, 40, math.sin(a) * r)
			local hit = Workspace:Raycast(from, Vector3.new(0, -140, 0), params)
			if hit then
				anchor.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.15, 0))
				onHit(hit.Material)
			end
		end
		clock = math.min(clock, 2)
	end)
	return att
end

-- Tint and thicken the sky's clouds for the storm, and put them back afterwards. Follows the
-- eased ramp, so the sky rolls in and clears with the storm.
function Common.clouds(ctx: Ctx, goal: { [string]: any })
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		return
	end
	local before = { Cover = clouds.Cover, Density = clouds.Density, Color = clouds.Color }
	local function apply(k: number)
		if goal.Cover then
			clouds.Cover = before.Cover + (goal.Cover - before.Cover) * k
		end
		if goal.Density then
			clouds.Density = before.Density + (goal.Density - before.Density) * k
		end
		if goal.Color then
			clouds.Color = before.Color:Lerp(goal.Color, k)
		end
	end
	table.insert(ctx.onFrame, function(_dt, _camPos, ramp)
		apply(ramp)
	end)
	table.insert(ctx.finalize, function()
		apply(0)
	end)
end

-- A post-processing grade that rolls in and back out with the storm.
-- grade: { Tint, Saturation, Brightness, Contrast, Bloom, BloomThreshold, BloomSize, Rays, RaysSpread, Blur }
function Common.grade(ctx: Ctx, grade: { [string]: any })
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StormGrade"
	cc.Parent = Lighting
	local made: { Instance } = { cc }
	local tint: Color3 = grade.Tint or Color3.new(1, 1, 1)
	local bloom: BloomEffect? = nil
	if grade.Bloom then
		local b = Instance.new("BloomEffect")
		b.Name = "StormBloom"
		b.Intensity = 0
		b.Size = grade.BloomSize or 30
		b.Threshold = 2
		b.Parent = Lighting
		bloom = b
		table.insert(made, b)
	end
	local rays: SunRaysEffect? = nil
	if grade.Rays then
		local r = Instance.new("SunRaysEffect")
		r.Name = "StormRays"
		r.Intensity = 0
		r.Spread = grade.RaysSpread or 0.6
		r.Parent = Lighting
		rays = r
		table.insert(made, r)
	end
	local blur: BlurEffect? = nil
	if grade.Blur then
		local b = Instance.new("BlurEffect")
		b.Name = "StormBlur"
		b.Size = 0
		b.Parent = Lighting
		blur = b
		table.insert(made, b)
	end
	local function apply(k: number)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
		cc.Saturation = (grade.Saturation or 0) * k
		cc.Brightness = (grade.Brightness or 0) * k
		cc.Contrast = (grade.Contrast or 0) * k
		if bloom then
			bloom.Intensity = grade.Bloom * k
			bloom.Threshold = 2 + ((grade.BloomThreshold or 1) - 2) * k
		end
		if rays then
			rays.Intensity = grade.Rays * k
		end
		if blur then
			blur.Size = grade.Blur * k
		end
	end
	apply(0)
	table.insert(ctx.onFrame, function(_dt, _camPos, ramp)
		apply(ramp)
	end)
	table.insert(ctx.finalize, function()
		for _, m in made do
			m:Destroy()
		end
	end)
end

-- One glowing lightning segment from a to b: a soft white core and a coloured halo, drawn
-- with camera-facing beams (round, no hard edges). Returns an invisible holder part; its
-- Transparency and LocalTransparencyModifier drive the beams, so storm code can flicker and
-- fade it like a normal part.
function Common.boltSegment(ctx: Ctx, a: Vector3, b: Vector3, w: number, core: Color3, halo: Color3, haloAlpha: number?): BasePart
	local dir = b - a
	local len = dir.Magnitude
	local holder = Instance.new("Part")
	holder.Name = "Bolt"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Size = Vector3.new(0.001, 0.001, 0.001)
	holder.Material = Enum.Material.SmoothPlastic
	holder.CFrame = CFrame.lookAt((a + b) / 2, b + Vector3.new(0, 0.001, 0))
	-- overlap the joints a little so a jagged bolt reads as one line
	local reach = len / 2 + w * 0.3
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, reach)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -reach)
	a1.Parent = holder
	local function beam(width: number, color: Color3, base: number, bright: number): Beam
		local bm = Instance.new("Beam")
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.FaceCamera = true
		bm.Texture = Common.TEX.BoltBeam
		bm.TextureMode = Enum.TextureMode.Stretch
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Brightness = bright
		bm.Color = ColorSequence.new(color)
		bm.Width0 = width
		bm.Width1 = width
		bm.Segments = 1
		bm.Transparency = NumberSequence.new(base)
		bm:SetAttribute("Base", base)
		bm.Parent = holder
		return bm
	end
	local beams = {
		beam(w * 2, core, 0, 5),
		beam(w * 7, halo, haloAlpha or 0.55, 2),
	}
	local function sync()
		local v = 1 - (1 - holder.Transparency) * (1 - holder.LocalTransparencyModifier)
		for _, bm in beams do
			local base = bm:GetAttribute("Base") :: number
			bm.Transparency = NumberSequence.new(base + (1 - base) * v)
		end
	end
	holder:GetPropertyChangedSignal("Transparency"):Connect(sync)
	holder:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(sync)
	holder.Transparency = 0
	holder.Parent = ctx.folder
	sync()
	Common.Flashed:Fire(b)
	return holder
end

-- The lamp part in the lamp room, if streamed in
function Common.lamp(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local lighthouse = map and map:FindFirstChild("Lighthouse")
	local lampRoom = lighthouse and lighthouse:FindFirstChild("LampRoom")
	local lamp = lampRoom and lampRoom:FindFirstChild("Lamp")
	return if lamp and lamp:IsA("BasePart") then lamp else nil
end

-- Run a storm's build(ctx). Returns stop(instant?) (fades it out and cleans up; instant tears
-- it down this frame), setLevel(0..1) (how strong the look is: StormFXController uses a low
-- level during the Warning) and getRaw() (the un-eased ramp, to hand over to a rebuild).
-- startRaw lets a rebuilt storm pick up exactly where the previous one was.
function Common.run(
	textures: { [string]: any }?,
	build: (Ctx) -> (),
	level: number?,
	startRaw: number?
): ((boolean?) -> (), (number) -> (), () -> number)
	local folder = Instance.new("Folder")
	folder.Name = "StormFX"
	folder.Parent = Workspace
	local tex: { [string]: string } = {}
	for k, v in textures or {} do
		if typeof(v) == "string" and v ~= "" then
			tex[k] = v
		end
	end
	local ctx: Ctx = {
		folder = folder,
		textures = tex,
		ramp = 0,
		gust = Vector3.zero,
		time = 0,
		cleanup = {},
		finalize = {},
		onFrame = {},
	}
	build(ctx)
	local stopping = false
	local target = level or 1
	local raw = startRaw or 0
	ctx.ramp = smooth(raw)
	local conn = RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local goal = if stopping then 0 else target
		-- glide toward the goal: the ramp eases in and out instead of starting and stopping hard
		local step = dt / Common.FADE
		raw = if raw < goal then math.min(goal, raw + step) else math.max(goal, raw - step)
		ctx.ramp = smooth(raw)
		ctx.time += dt
		ctx.gust = Common.gustAt(os.clock())
		local pos = camera.CFrame.Position
		for _, f in ctx.onFrame do
			f(dt, pos, ctx.ramp)
		end
	end)
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		conn:Disconnect()
		for _, f in ctx.finalize do
			pcall(f)
		end
		folder:Destroy()
	end
	local function stop(instant: boolean?)
		stopping = true
		for _, f in ctx.cleanup do
			task.spawn(f)
		end
		if instant then
			finish()
		else
			task.delay(Common.FADE * math.max(raw, 0.01) + 1, finish)
		end
	end
	local function setLevel(v: number)
		target = math.clamp(v, 0, 1)
	end
	return stop, setLevel, function()
		return raw
	end
end

return Common
