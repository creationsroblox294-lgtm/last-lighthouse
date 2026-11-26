--!strict
-- Shared building blocks for storm visuals (StormFX/<StormId> modules use these).
-- Every effect follows the camera, fades in over FADE seconds and cleans up after itself.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Common = {}

Common.FADE = 5
Common.FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"

export type Ctx = {
	folder: Folder,
	textures: { [string]: string },
	ramp: number, -- 0..1 fade-in
	cleanup: { () -> () },
	onFrame: { (dt: number, camPos: Vector3, ramp: number) -> () },
}

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
	return ctx.textures[key] or Common.FALLBACK
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
	table.insert(ctx.onFrame, function(_dt, camPos, ramp)
		sheet.CFrame = CFrame.new(camPos + Vector3.new(0, height, 0) + offset)
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
	e.Rate = 0
	e.Parent = box
	local rate = opts.Rate or 20
	local offset = opts.Offset or Vector3.new(0, -2, 0)
	table.insert(ctx.onFrame, function(_dt, camPos, ramp)
		box.CFrame = CFrame.new(camPos + offset)
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

-- Tint and thicken the sky's clouds for the storm, and put them back afterwards.
function Common.clouds(ctx: Ctx, goal: { [string]: any })
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		return
	end
	local before = { Cover = clouds.Cover, Density = clouds.Density, Color = clouds.Color }
	Common.tween(clouds, Common.FADE, goal)
	table.insert(ctx.cleanup, function()
		Common.tween(clouds, Common.FADE, before)
	end)
end

-- A post-processing grade that fades in and back out.
-- grade: { Tint, Saturation, Brightness, Contrast, Bloom, BloomThreshold, BloomSize, Rays, RaysSpread, Blur }
function Common.grade(ctx: Ctx, grade: { [string]: any })
	local F = Common.FADE
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StormGrade"
	cc.Parent = Lighting
	Common.tween(cc, F, {
		TintColor = grade.Tint or Color3.new(1, 1, 1),
		Saturation = grade.Saturation or 0,
		Brightness = grade.Brightness or 0,
		Contrast = grade.Contrast or 0,
	})
	local made: { Instance } = { cc }
	local bloom: BloomEffect? = nil
	if grade.Bloom then
		local b = Instance.new("BloomEffect")
		b.Name = "StormBloom"
		b.Intensity = 0
		b.Size = grade.BloomSize or 30
		b.Threshold = 2
		b.Parent = Lighting
		Common.tween(b, F, { Intensity = grade.Bloom, Threshold = grade.BloomThreshold or 1 })
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
		Common.tween(r, F, { Intensity = grade.Rays })
		rays = r
		table.insert(made, r)
	end
	local blur: BlurEffect? = nil
	if grade.Blur then
		local b = Instance.new("BlurEffect")
		b.Name = "StormBlur"
		b.Size = 0
		b.Parent = Lighting
		Common.tween(b, F, { Size = grade.Blur })
		blur = b
		table.insert(made, b)
	end
	table.insert(ctx.cleanup, function()
		Common.tween(cc, F, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 })
		if bloom then
			Common.tween(bloom, F, { Intensity = 0 })
		end
		if rays then
			Common.tween(rays, F, { Intensity = 0 })
		end
		if blur then
			Common.tween(blur, F, { Size = 0 })
		end
		task.delay(F + 1, function()
			for _, m in made do
				m:Destroy()
			end
		end)
	end)
end

-- The lamp part in the lamp room, if streamed in
function Common.lamp(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local lighthouse = map and map:FindFirstChild("Lighthouse")
	local lampRoom = lighthouse and lighthouse:FindFirstChild("LampRoom")
	local lamp = lampRoom and lampRoom:FindFirstChild("Lamp")
	return if lamp and lamp:IsA("BasePart") then lamp else nil
end

-- Run a storm's build(ctx) and return a stop() that fades it out
function Common.run(textures: { [string]: any }?, build: (Ctx) -> ()): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "StormFX"
	folder.Parent = Workspace
	local tex: { [string]: string } = {}
	for k, v in textures or {} do
		if typeof(v) == "string" and v ~= "" then
			tex[k] = v
		end
	end
	local ctx: Ctx = { folder = folder, textures = tex, ramp = 0, cleanup = {}, onFrame = {} }
	build(ctx)
	local stopping = false
	local conn = RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		if stopping then
			ctx.ramp = math.max(0, ctx.ramp - dt / Common.FADE)
		else
			ctx.ramp = math.min(1, ctx.ramp + dt / Common.FADE)
		end
		local pos = camera.CFrame.Position
		for _, f in ctx.onFrame do
			f(dt, pos, ctx.ramp)
		end
	end)
	return function()
		stopping = true
		for _, f in ctx.cleanup do
			task.spawn(f)
		end
		task.delay(Common.FADE + 2, function()
			conn:Disconnect()
			folder:Destroy()
		end)
	end
end

return Common
