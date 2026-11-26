--!strict
-- Lucky Lightning (Blessed): a dry, electric violet dusk with no rain. Heat lightning flickers
-- through the clouds and far-off bolts fork down to the sea. Lucky clovers and stray sparks
-- drift on the air. Each strike (StormEvent "Bolt") first crackles at its target with a glowing
-- column, then a forked bolt slams down: it flickers, lights up the whole island, shakes the
-- camera and bursts into sparks. Trees explode into wood chips, embers and a puff of clovers;
-- a bolt on the lighthouse wraps the lamp in a golden charge.
-- Textures: Blender (LuckyLightning: spark, clover, glow) + Starfall flash + Golden Rain mote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local CORE = Color3.fromRGB(245, 245, 255)
local ARC = Color3.fromRGB(150, 160, 255)
local VIOLET = Color3.fromRGB(190, 120, 255)
local LUCK = Color3.fromRGB(110, 255, 140)
local GOLD = Color3.fromRGB(255, 215, 90)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local shake = 0

	Common.clouds(ctx, { Cover = 0.85, Density = 0.8, Color = Color3.fromRGB(70, 55, 110) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(230, 225, 255),
		Saturation = 0.3,
		Brightness = 0,
		Contrast = 0.25,
		Bloom = 1.3,
		BloomThreshold = 0.9,
		BloomSize = 36,
	})
	-- the flash: a second grade that spikes bright for every strike
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "LightningFlash"
	flash.Parent = Lighting
	table.insert(ctx.cleanup, function()
		task.delay(Common.FADE, function()
			flash:Destroy()
		end)
	end)
	local function flashScreen(strength: number)
		flash.Brightness = 0.35 * strength
		flash.TintColor = Color3.fromRGB(225, 225, 255)
		Common.tween(flash, 0.35, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	end

	-- lucky clovers and stray sparks on the wind
	Common.around(ctx, "Clovers", Vector3.new(100, 30, 100), {
		Texture = Common.tex(ctx, "Clover"),
		Rate = 14,
		Brightness = 3,
		Color = ColorSequence.new(LUCK, GOLD),
		Size = ns(0, 0, 0.15, 0.7, 0.85, 0.7, 1, 0),
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(1.2, 0.3, 0.6),
		RotSpeed = NumberRange.new(-60, 60),
	})
	Common.around(ctx, "Sparks", Vector3.new(80, 25, 80), {
		Texture = Common.tex(ctx, "Spark"),
		Rate = 20,
		Brightness = 6,
		Color = ColorSequence.new(CORE, ARC),
		Size = ns(0, 0, 0.1, 1.1, 0.3, 0, 1, 0),
		Transparency = ns(0, 0, 1, 0.2),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
	})

	-- a forked bolt from the sky down to `to`; returns the parts so the caller can light it
	local function bolt(to: Vector3, height: number, thickness: number, r: Random): { BasePart }
		local parts: { BasePart } = {}
		local function segment(a: Vector3, b: Vector3, w: number)
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt((a + b) / 2, b)
			local core = Common.part(ctx, "BoltCore", Vector3.new(w, w, len))
			core.Material = Enum.Material.Neon
			core.Color = CORE
			core.Transparency = 0
			core.CFrame = cf
			local halo = Common.part(ctx, "BoltHalo", Vector3.new(w * 4, w * 4, len))
			halo.Material = Enum.Material.Neon
			halo.Color = ARC
			halo.Transparency = 0.68
			halo.CFrame = cf
			table.insert(parts, core)
			table.insert(parts, halo)
		end
		local function path(from: Vector3, target: Vector3, w: number, steps: number, depth: number)
			local prev = from
			for i = 1, steps do
				local t = i / steps
				local p = from:Lerp(target, t)
				if i < steps then
					local jag = (1 - t * 0.6) * (target - from).Magnitude * 0.06
					p += Vector3.new(r:NextNumber(-jag, jag), r:NextNumber(-jag, jag) * 0.3, r:NextNumber(-jag, jag))
				end
				segment(prev, p, w * (1 - t * 0.5))
				if depth > 0 and i < steps - 1 and r:NextNumber() < 0.28 then
					local away = Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-0.9, -0.3), r:NextNumber(-1, 1)).Unit
					path(p, p + away * (target - from).Magnitude * r:NextNumber(0.15, 0.3), w * 0.5, 5, depth - 1)
				end
				prev = p
			end
		end
		local from = to + Vector3.new(r:NextNumber(-60, 60), height, r:NextNumber(-60, 60))
		path(from, to, thickness, 14, 2)
		return parts
	end

	local function flicker(parts: { BasePart }, fade: number)
		local function setVis(v: boolean)
			for _, p in parts do
				if p.Parent then
					p.LocalTransparencyModifier = if v then 0 else 1
				end
			end
		end
		task.spawn(function()
			task.wait(0.06)
			setVis(false)
			task.wait(0.05)
			setVis(true)
			task.wait(0.04)
			setVis(false)
			task.wait(0.04)
			setVis(true)
			task.wait(0.22) -- hold the full bolt for a moment
			for _, p in parts do
				if p.Parent then
					Common.tween(p, fade, { Transparency = 1 })
				end
			end
			task.wait(fade + 0.1)
			for _, p in parts do
				p:Destroy()
			end
		end)
	end

	local function burstAt(at: Vector3, kind: string)
		local holder = Common.part(ctx, "BoltBurst", Vector3.one)
		holder.CFrame = CFrame.new(at)
		local function emit(tex: string, n: number, props: { [string]: any })
			local e = Instance.new("ParticleEmitter")
			e.Texture = tex
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Rate = 0
			for k, v in props do
				(e :: any)[k] = v
			end
			e.Parent = holder
			e:Emit(n)
		end
		emit(Common.tex(ctx, "Spark"), 14, {
			Brightness = 8,
			Color = ColorSequence.new(CORE, ARC),
			Size = ns(0, 6, 1, 10),
			Transparency = ns(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
		})
		emit(Common.tex(ctx, "Flash"), 3, {
			Brightness = 6,
			Color = ColorSequence.new(ARC),
			Size = ns(0, 10, 1, 26),
			Transparency = ns(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.45),
			Speed = NumberRange.new(0),
		})
		emit(Common.tex(ctx, "Mote"), 60, {
			Brightness = 5,
			Color = ColorSequence.new(CORE, VIOLET),
			Size = ns(0, 0.6, 1, 0),
			Lifetime = NumberRange.new(0.5, 1.1),
			Speed = NumberRange.new(14, 34),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -30, 0),
			Drag = 1.5,
		})
		if kind == "tree" then
			emit("rbxasset://textures/particles/sparkles_main.dds", 40, { -- wood chips
				LightEmission = 0,
				LightInfluence = 1,
				Color = ColorSequence.new(Color3.fromRGB(150, 100, 55), Color3.fromRGB(90, 60, 30)),
				Size = ns(0, 0.8, 1, 0.5),
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(18, 36),
				SpreadAngle = Vector2.new(70, 70),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -50, 0),
				RotSpeed = NumberRange.new(-400, 400),
			})
			emit(Common.tex(ctx, "Mote"), 50, { -- embers
				Brightness = 4,
				Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 80, 30)),
				Size = ns(0, 0.35, 1, 0),
				Lifetime = NumberRange.new(1, 2.2),
				Speed = NumberRange.new(4, 12),
				SpreadAngle = Vector2.new(60, 60),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, 4, 0),
			})
			emit(Common.tex(ctx, "Clover"), 18, { -- the luck spilling out
				Brightness = 4,
				Color = ColorSequence.new(LUCK, GOLD),
				Size = ns(0, 1.2, 1, 0.4),
				Lifetime = NumberRange.new(1.5, 2.5),
				Speed = NumberRange.new(6, 14),
				SpreadAngle = Vector2.new(80, 80),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -3, 0),
				Drag = 1,
				RotSpeed = NumberRange.new(-120, 120),
			})
		elseif kind == "lamp" then
			emit(Common.tex(ctx, "Spark"), 30, {
				Brightness = 8,
				Color = ColorSequence.new(GOLD, CORE),
				Size = ns(0, 3, 1, 6),
				Transparency = ns(0, 0, 1, 1),
				Lifetime = NumberRange.new(0.2, 0.5),
				Speed = NumberRange.new(0, 4),
				Rotation = NumberRange.new(0, 360),
			})
			local ring = Common.part(ctx, "Supercharge", Vector3.new(0.4, 4, 4))
			ring.Shape = Enum.PartType.Cylinder
			ring.Material = Enum.Material.Neon
			ring.Color = GOLD
			ring.Transparency = 0.1
			ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
			Common.tween(ring, 1, { Size = Vector3.new(0.2, 90, 90), Transparency = 1 })
			task.delay(1.2, function()
				ring:Destroy()
			end)
		end
		local light = Instance.new("PointLight")
		light.Color = if kind == "lamp" then GOLD else ARC
		light.Range = 120
		light.Brightness = 10
		light.Shadows = true
		light.Parent = holder
		Common.tween(light, 0.6, { Brightness = 0 })
		task.delay(2.5, function()
			holder:Destroy()
		end)
	end

	local function charge(target: Vector3, seconds: number, kind: string)
		-- the target crackles and a faint column of light reaches up for the bolt
		local holder = Common.part(ctx, "BoltCharge", Vector3.one)
		holder.CFrame = CFrame.new(target)
		local crackle = Instance.new("ParticleEmitter")
		crackle.Texture = Common.tex(ctx, "Spark")
		crackle.Color = ColorSequence.new(if kind == "lamp" then GOLD else CORE, ARC)
		crackle.LightEmission = 1
		crackle.LightInfluence = 0
		crackle.Brightness = 6
		crackle.Size = ns(0, 1.5, 1, 3)
		crackle.Transparency = ns(0, 0, 1, 1)
		crackle.Lifetime = NumberRange.new(0.08, 0.16)
		crackle.Speed = NumberRange.new(0)
		crackle.Rotation = NumberRange.new(0, 360)
		crackle.Rate = 30
		crackle.Parent = holder
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 90, 0)
		a1.Parent = holder
		local column = Instance.new("Beam")
		column.Attachment0 = a0
		column.Attachment1 = a1
		column.Texture = Common.tex(ctx, "Glow")
		column.LightEmission = 1
		column.LightInfluence = 0
		column.Brightness = 2
		column.Color = ColorSequence.new(if kind == "lamp" then GOLD else ARC)
		column.Width0 = 4
		column.Width1 = 1
		column.FaceCamera = true
		column.Transparency = ns(0, 0.9, 1, 1)
		column.Parent = holder
		local t0 = os.clock()
		local conn = game:GetService("RunService").RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local tr = 0.95 - 0.6 * k + math.sin(os.clock() * 40) * 0.05
			column.Transparency = ns(0, tr, 1, 1)
			crackle.Rate = 30 + 90 * k
		end)
		task.delay(seconds, function()
			conn:Disconnect()
			holder:Destroy()
		end)
	end

	local function strike(data: { [string]: any })
		local target = data.target :: Vector3
		local kind = tostring(data.kind)
		local seconds = tonumber(data.seconds) or 1.1
		local r = Random.new(tonumber(data.seed) or 1)
		charge(target, seconds, kind)
		task.delay(seconds, function()
			local parts = bolt(target, 380, if kind == "lamp" then 2.2 else 1.6, r)
			flicker(parts, 0.5)
			local foot = if typeof(data.foot) == "Vector3" then data.foot else target
			burstAt(if kind == "tree" then foot :: Vector3 else target, kind)
			flashScreen(if kind == "lamp" then 1.4 else 1)
			-- a ground strike throws you clear if you were standing on it (players own their physics)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local hitAt = if kind == "tree" then foot :: Vector3 else target
			if kind ~= "lamp" and root and root:IsA("BasePart") then
				local flat = Vector3.new(root.Position.X - hitAt.X, 0, root.Position.Z - hitAt.Z)
				if flat.Magnitude < 7 and math.abs(root.Position.Y - hitAt.Y) < 12 then
					root.AssemblyLinearVelocity += (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 40 + Vector3.new(0, 25, 0)
				end
			end
			local camera = Workspace.CurrentCamera
			if camera then
				local dist = (camera.CFrame.Position - target).Magnitude
				shake = math.max(shake, math.clamp(1.4 - dist / 120, 0.15, 1.2))
			end
		end)
	end

	-- heat lightning: flickers in the clouds and far-off forks over the sea
	local nextFlicker = 0.5
	local clock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		clock += dt
		nextFlicker -= dt
		if nextFlicker <= 0 and ramp > 0.5 then
			nextFlicker = rnd:NextNumber(0.6, 2)
			local a = rnd:NextNumber(0, math.pi * 2)
			local d = rnd:NextNumber(350, 700)
			local far = Vector3.new(camPos.X + math.cos(a) * d, 0, camPos.Z + math.sin(a) * d)
			if rnd:NextNumber() < 0.55 then
				flicker(bolt(far, 420, 3, rnd), 0.25)
				flashScreen(0.35)
			else
				flashScreen(0.18) -- just the clouds lighting up
			end
		end
		if shake > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.04 * shake, (rnd:NextNumber() - 0.5) * 0.04 * shake, 0)
			end
			shake = math.max(0, shake - dt * 2.5)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Bolt" and typeof(data) == "table" and typeof(data.target) == "Vector3" then
			strike(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
