--!strict
-- Starfall (Blessed): a clear violet night full of stars. Meteors (StormEvent "Meteor") blaze
-- down with fiery trails onto a pulsing warning ring, then hit with a flash, a shockwave,
-- sparks and a camera shake, leaving a glowing star shard. Shooting stars cross the far sky.
-- Textures: Blender, LastLighthouseAssets/storms/Storms_FX.blend (Starfall renders).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local ICE = Color3.fromRGB(150, 210, 255)
local VIOLET = Color3.fromRGB(160, 110, 255)
local WHITE = Color3.new(1, 1, 1)
local FIRE = Color3.fromRGB(255, 160, 80)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local shake = 0

	-- starlight twinkling around you and drifting slowly down
	Common.around(ctx, "Starlight", Vector3.new(90, 30, 90), {
		Texture = Common.tex(ctx, "Star"),
		Rate = 35,
		Brightness = 3,
		Size = ns(0, 0, 0.3, 0.6, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0, 0.4),
		Rotation = NumberRange.new(0, 45),
		RotSpeed = NumberRange.new(-60, 60),
		Offset = Vector3.new(0, 4, 0),
	})
	Common.fall(ctx, "StarDust", {
		Texture = Common.tex(ctx, "Star"),
		Rate = 60,
		Speed = NumberRange.new(3, 7),
		Lifetime = NumberRange.new(6, 9),
		Size = ns(0, 0.25, 0.5, 0.4, 1, 0.15),
		Transparency = ns(0, 1, 0.15, 0.2, 0.85, 0.2, 1, 1),
		Brightness = 3,
		LightEmission = 1,
		Spread = Vector2.new(30, 30),
		Height = 45,
		Width = 120,
		Color = ColorSequence.new(WHITE, ICE),
	})

	-- more stars in the sky, a violet night grade
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		local before = sky.StarCount
		sky.StarCount = 5000
		table.insert(ctx.cleanup, function()
			task.delay(Common.FADE, function()
				sky.StarCount = before
			end)
		end)
	end
	Common.clouds(ctx, { Cover = 0.35, Density = 0.3, Color = Color3.fromRGB(140, 120, 220) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 215, 255),
		Saturation = 0.25,
		Brightness = 0.03,
		Contrast = 0.12,
		Bloom = 1.4,
		BloomThreshold = 0.85,
		BloomSize = 40,
	})

	local function neon(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
		local p = Common.part(ctx, name, size)
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 0
		if shape then
			p.Shape = shape
		end
		return p
	end

	local function burst(at: Vector3, texture: string, count: number, size: NumberSequence, speed: NumberRange, life: NumberRange, color: ColorSequence)
		local holder = Common.part(ctx, "Burst", Vector3.one)
		holder.CFrame = CFrame.new(at)
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 4
		e.Color = color
		e.Size = size
		e.Transparency = ns(0, 0, 0.7, 0.2, 1, 1)
		e.Lifetime = life
		e.Speed = speed
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -20, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.Rate = 0
		e.Parent = holder
		e:Emit(count)
		task.delay(life.Max + 0.2, function()
			holder:Destroy()
		end)
	end

	local function meteor(target: Vector3, seconds: number, seed: number)
		local r = Random.new(seed)
		local fromDir = Vector3.new(r:NextNumber(-1, 1), 0, r:NextNumber(-1, 1)).Unit
		local start = target + fromDir * r:NextNumber(90, 150) + Vector3.new(0, r:NextNumber(220, 280), 0)

		-- warning ring on the ground, pulsing and closing in
		local ring = neon("WarnRing", Vector3.new(0.15, 14, 14), ICE, Enum.PartType.Cylinder)
		ring.CFrame = CFrame.new(target + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.6
		local inner = neon("WarnCore", Vector3.new(0.2, 4, 4), WHITE, Enum.PartType.Cylinder)
		inner.CFrame = ring.CFrame
		inner.Transparency = 0.5
		local glow = Instance.new("PointLight")
		glow.Color = ICE
		glow.Range = 14
		glow.Brightness = 1
		glow.Parent = ring

		-- the meteor: white-hot head, comet trail, sparks and a light
		local head = neon("Meteor", Vector3.new(3.6, 3.6, 3.6), WHITE, Enum.PartType.Ball)
		head.CFrame = CFrame.new(start)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1.8, 0)
		a0.Parent = head
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1.8, 0)
		a1.Parent = head
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.9
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.3, ICE),
			ColorSequenceKeypoint.new(0.7, VIOLET),
			ColorSequenceKeypoint.new(1, FIRE),
		})
		trail.Transparency = ns(0, 0, 0.6, 0.4, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.1)
		trail.Parent = head
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Common.tex(ctx, "Meteor")
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Brightness = 5
		sparks.Size = ns(0, 3, 1, 1)
		sparks.Transparency = ns(0, 0, 1, 1)
		sparks.Lifetime = NumberRange.new(0.3, 0.5)
		sparks.Speed = NumberRange.new(2, 6)
		sparks.SpreadAngle = Vector2.new(25, 25)
		sparks.Rate = 80
		sparks.Parent = head
		local light = Instance.new("PointLight")
		light.Color = ICE
		light.Range = 60
		light.Brightness = 6
		light.Shadows = true
		light.Parent = head

		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local eased = k * k -- speeds up as it falls
			local pos = start:Lerp(target, eased)
			head.CFrame = CFrame.lookAt(pos, target) * CFrame.Angles(math.rad(90), 0, 0)
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * (10 + k * 25))
			local s = 14 - 9 * k
			ring.Size = Vector3.new(0.15, s, s)
			ring.Transparency = 0.65 - 0.35 * pulse * k
			glow.Brightness = 0.5 + 3 * k
			if k >= 1 then
				conn:Disconnect()
				head:Destroy()
				ring:Destroy()
				inner:Destroy()
				-- impact: flash, shockwave, sparks, dust and a shake
				burst(target + Vector3.new(0, 2, 0), Common.tex(ctx, "Flash"), 3, ns(0, 6, 0.3, 16, 1, 22), NumberRange.new(0), NumberRange.new(0.35, 0.45), ColorSequence.new(WHITE, ICE))
				burst(target + Vector3.new(0, 1, 0), Common.tex(ctx, "Star"), 40, ns(0, 1.2, 1, 0), NumberRange.new(25, 55), NumberRange.new(0.6, 1.2), ColorSequence.new(WHITE, VIOLET))
				burst(target + Vector3.new(0, 1, 0), Common.tex(ctx, "Meteor"), 18, ns(0, 2, 1, 0.5), NumberRange.new(30, 60), NumberRange.new(0.4, 0.8), ColorSequence.new(FIRE, ICE))
				local wave = neon("Shockwave", Vector3.new(0.2, 2, 2), ICE, Enum.PartType.Cylinder)
				wave.CFrame = CFrame.new(target + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
				Common.tween(wave, 0.6, { Size = Vector3.new(0.2, 46, 46), Transparency = 1 })
				local flash = Instance.new("PointLight")
				flash.Color = ICE
				flash.Range = 60
				flash.Brightness = 8
				flash.Parent = wave
				Common.tween(flash, 0.7, { Brightness = 0 })
				task.delay(0.8, function()
					wave:Destroy()
				end)
				local camera = Workspace.CurrentCamera
				if camera then
					local d = (camera.CFrame.Position - target).Magnitude
					shake = math.max(shake, math.clamp(1.4 - d / 120, 0, 1.4))
				end
			end
		end)
	end

	-- distant shooting stars streaking across the sky
	local nextShooting = os.clock() + 1
	table.insert(ctx.onFrame, function(_dt, camPos, ramp)
		if ramp < 0.5 or os.clock() < nextShooting then
			return
		end
		nextShooting = os.clock() + rnd:NextNumber(0.6, 1.8)
		local a = rnd:NextNumber(0, math.pi * 2)
		local from = camPos + Vector3.new(math.cos(a) * 500, rnd:NextNumber(180, 320), math.sin(a) * 500)
		local dir = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.5, -0.2), rnd:NextNumber(-1, 1)).Unit
		local star = neon("ShootingStar", Vector3.new(1.6, 1.6, 1.6), WHITE, Enum.PartType.Ball)
		local b0 = Instance.new("Attachment")
		b0.Position = Vector3.new(0, 0.8, 0)
		b0.Parent = star
		local b1 = Instance.new("Attachment")
		b1.Position = Vector3.new(0, -0.8, 0)
		b1.Parent = star
		local tr = Instance.new("Trail")
		tr.Attachment0 = b0
		tr.Attachment1 = b1
		tr.Lifetime = 0.45
		tr.LightEmission = 1
		tr.FaceCamera = true
		tr.Color = ColorSequence.new(WHITE, VIOLET)
		tr.Transparency = ns(0, 0, 1, 1)
		tr.Parent = star
		local t0 = os.clock()
		local life = rnd:NextNumber(0.8, 1.4)
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			star.CFrame = CFrame.new(from + dir * t * 420)
			star.Transparency = math.clamp((t / life - 0.7) / 0.3, 0, 1)
			if t >= life then
				conn:Disconnect()
				star:Destroy()
			end
		end)
	end)

	-- camera shake from nearby impacts
	table.insert(ctx.onFrame, function(dt)
		if shake > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
			end
			shake = math.max(0, shake - dt * 2.2)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Meteor" and typeof(data) == "table" and typeof(data.target) == "Vector3" then
			meteor(data.target, tonumber(data.seconds) or 2.2, tonumber(data.seed) or 1)
		elseif kind == "ShardTaken" and typeof(data) == "Vector3" then
			burst(data + Vector3.new(0, 1.5, 0), Common.tex(ctx, "Star"), 25, ns(0, 1, 1, 0), NumberRange.new(6, 14), NumberRange.new(0.5, 1), ColorSequence.new(WHITE, ICE))
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
