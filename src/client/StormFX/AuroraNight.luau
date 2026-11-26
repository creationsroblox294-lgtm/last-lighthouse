--!strict
-- Aurora Night (Blessed): a deep starry night with huge aurora curtains rippling across the
-- whole sky, green at the hem and fading through teal into violet and pink. Stars twinkle in
-- the air, the light shifts slowly between green and violet, and aurora wisps (server parts in
-- Workspace.AuroraWisps) glow and trail colour. Taking one (StormEvent "WispTaken") sends out
-- a ring of aurora light.
-- Textures: Blender (Storms_FX AuroraNight: curtain, wisp, twinkle).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local GREEN = Color3.fromRGB(90, 255, 160)
local TEAL = Color3.fromRGB(60, 230, 255)
local VIOLET = Color3.fromRGB(190, 110, 255)
local PINK = Color3.fromRGB(255, 110, 200)

-- the curtains: { angle around the camera (deg), distance, height, length, width, phase }
local CURTAINS = {
	{ -20, 520, 230, 900, 260, 0 },
	{ 35, 620, 290, 1000, 300, 1.7 },
	{ 95, 560, 250, 850, 240, 3.1 },
	{ 160, 650, 300, 1000, 300, 4.4 },
	{ 215, 540, 240, 900, 250, 5.2 },
	{ 280, 600, 280, 950, 280, 2.3 },
	{ 0, 300, 380, 700, 220, 0.9 }, -- one right overhead
}

return function(ctx: Common.Ctx)
	-- more stars
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		local before = sky.StarCount
		sky.StarCount = 6000
		table.insert(ctx.cleanup, function()
			task.delay(Common.FADE, function()
				sky.StarCount = before
			end)
		end)
	end
	Common.clouds(ctx, { Cover = 0.3, Density = 0.25, Color = Color3.fromRGB(70, 60, 120) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(225, 255, 240),
		Saturation = 0.45,
		Brightness = 0.03,
		Contrast = 0.15,
		Bloom = 1.4,
		BloomThreshold = 0.95,
		BloomSize = 40,
	})

	-- the aurora: beams that follow the camera so the curtains always fill the sky
	local holder = Common.part(ctx, "AuroraHolder", Vector3.one)
	local beams: { { beam: Beam, a0: Attachment, a1: Attachment, spec: { number } } } = {}
	for _, c in CURTAINS do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = holder
		a1.Parent = holder
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = Common.tex(ctx, "Curtain")
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = 0.03
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 3
		b.FaceCamera = true
		b.Segments = 40
		b.Width0 = c[5]
		b.Width1 = c[5] * 0.8
		b.Color = ColorSequence.new(Color3.new(1, 1, 1))
		b.Transparency = ns(0, 1, 0.15, 0.15, 0.85, 0.15, 1, 1)
		b.Parent = holder
		table.insert(beams, { beam = b, a0 = a0, a1 = a1, spec = c })
	end

	-- twinkling stars hanging in the air around you
	Common.around(ctx, "Twinkles", Vector3.new(110, 40, 110), {
		Texture = Common.tex(ctx, "Twinkle"),
		Rate = 45,
		Brightness = 5,
		Color = ColorSequence.new(TEAL, VIOLET),
		Size = ns(0, 0, 0.5, 1.1, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(0, 0.3),
		RotSpeed = NumberRange.new(-30, 30),
		Offset = Vector3.new(0, 8, 0),
	})
	Common.around(ctx, "Glow", Vector3.new(90, 10, 90), {
		Texture = Common.tex(ctx, "Wisp"),
		Rate = 18,
		Brightness = 2,
		Color = ColorSequence.new(GREEN, PINK),
		Size = ns(0, 0, 0.2, 0.7, 0.8, 0.7, 1, 0),
		Acceleration = Vector3.new(0, 0.8, 0),
	})

	-- the light slowly breathes between green and violet
	local shift = Instance.new("ColorCorrectionEffect")
	shift.Name = "AuroraShift"
	shift.Parent = Lighting
	table.insert(ctx.cleanup, function()
		Common.tween(shift, Common.FADE, { TintColor = Color3.new(1, 1, 1) })
		task.delay(Common.FADE + 1, function()
			shift:Destroy()
		end)
	end)

	-- dress the server's wisps with light, glow and trails
	local dressed: { [Instance]: boolean } = {}
	local function dress(part: Instance)
		if dressed[part] or not part:IsA("BasePart") then
			return
		end
		dressed[part] = true
		local hue = tonumber(part:GetAttribute("Hue")) or 0
		local col = if hue < 0.4 then GREEN elseif hue < 0.7 then TEAL else VIOLET
		part.Color = col
		local light = Instance.new("PointLight")
		light.Color = col
		light.Range = 18
		light.Brightness = 3
		light.Parent = part
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = Common.tex(ctx, "Wisp")
		glow.Color = ColorSequence.new(col, PINK)
		glow.LightEmission = 1
		glow.LightInfluence = 0
		glow.Brightness = 3
		glow.Size = ns(0, 3, 1, 0)
		glow.Transparency = ns(0, 0.2, 1, 1)
		glow.Lifetime = NumberRange.new(0.8, 1.4)
		glow.Speed = NumberRange.new(0)
		glow.Rate = 30
		glow.LockedToPart = false
		glow.Parent = part
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Common.tex(ctx, "Twinkle")
		sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), col)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Brightness = 4
		sparks.Size = ns(0, 0, 0.3, 0.8, 1, 0)
		sparks.Transparency = ns(0, 0, 1, 1)
		sparks.Lifetime = NumberRange.new(0.6, 1.2)
		sparks.Speed = NumberRange.new(1, 3)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Rate = 10
		sparks.Parent = part
	end
	local function watch(folder: Instance)
		for _, p in folder:GetChildren() do
			dress(p)
		end
		local conn = folder.ChildAdded:Connect(dress)
		table.insert(ctx.cleanup, function()
			conn:Disconnect()
		end)
	end
	local wispFolder = Workspace:FindFirstChild("AuroraWisps")
	if wispFolder then
		watch(wispFolder)
	else
		local conn: RBXScriptConnection
		conn = Workspace.ChildAdded:Connect(function(c)
			if c.Name == "AuroraWisps" then
				conn:Disconnect()
				watch(c)
			end
		end)
		table.insert(ctx.cleanup, function()
			conn:Disconnect()
		end)
	end

	local function burst(at: Vector3)
		-- a ring of aurora light rolling out over the ground, plus a shower of stars
		local ring = Common.part(ctx, "AuroraPulse", Vector3.new(0.4, 4, 4))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = GREEN
		ring.Transparency = 0.2
		ring.CFrame = CFrame.new(at - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Common.tween(ring, 0.8, { Size = Vector3.new(0.2, 54, 54), Transparency = 1, Color = VIOLET })
		local holder2 = Common.part(ctx, "AuroraBurst", Vector3.one)
		holder2.CFrame = CFrame.new(at)
		local stars = Instance.new("ParticleEmitter")
		stars.Texture = Common.tex(ctx, "Twinkle")
		stars.Color = ColorSequence.new(GREEN, VIOLET)
		stars.LightEmission = 1
		stars.LightInfluence = 0
		stars.Brightness = 6
		stars.Size = ns(0, 2, 1, 0)
		stars.Lifetime = NumberRange.new(0.8, 1.4)
		stars.Speed = NumberRange.new(10, 22)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Drag = 3
		stars.Rate = 0
		stars.Parent = holder2
		stars:Emit(70)
		local column = Instance.new("ParticleEmitter")
		column.Texture = Common.tex(ctx, "Wisp")
		column.Color = ColorSequence.new(GREEN, PINK)
		column.LightEmission = 1
		column.LightInfluence = 0
		column.Brightness = 4
		column.Size = ns(0, 3, 1, 0)
		column.Lifetime = NumberRange.new(1, 1.6)
		column.Speed = NumberRange.new(20, 40)
		column.SpreadAngle = Vector2.new(6, 6)
		column.EmissionDirection = Enum.NormalId.Top
		column.Rate = 0
		column.Parent = holder2
		column:Emit(40)
		local light = Instance.new("PointLight")
		light.Color = GREEN
		light.Range = 40
		light.Brightness = 8
		light.Parent = holder2
		Common.tween(light, 1.2, { Brightness = 0 })
		task.delay(2, function()
			ring:Destroy()
			holder2:Destroy()
		end)
	end

	local clock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		clock += dt
		holder.CFrame = CFrame.new(camPos.X, 0, camPos.Z)
		for _, b in beams do
			local c = b.spec
			local ang = math.rad(c[1]) + math.sin(clock * 0.05 + c[6]) * 0.08
			local center = Vector3.new(math.cos(ang), 0, math.sin(ang)) * c[2]
			local along = Vector3.new(-math.sin(ang), 0, math.cos(ang)) * (c[4] / 2)
			local h = c[3] + math.sin(clock * 0.3 + c[6]) * 15
			-- (this end order keeps the green hem at the bottom of the curtain)
			b.a0.Position = center + along + Vector3.new(0, h + 20, 0)
			b.a1.Position = center - along + Vector3.new(0, h, 0)
			-- the curtain ripples: its curve sways back and forth
			b.beam.CurveSize0 = math.sin(clock * 0.45 + c[6]) * 260
			b.beam.CurveSize1 = math.sin(clock * 0.37 + c[6] * 1.3) * 260
			local flicker = 0.15 + 0.12 * math.sin(clock * 1.3 + c[6] * 2) + (1 - ramp) * 0.85
			b.beam.Transparency = ns(0, 1, 0.15, flicker, 0.85, flicker, 1, 1)
		end
		local k = (math.sin(clock * 0.25) + 1) / 2
		shift.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(215, 255, 230):Lerp(Color3.fromRGB(240, 215, 255), k), ramp)
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "WispTaken" and typeof(data) == "Vector3" then
			burst(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
