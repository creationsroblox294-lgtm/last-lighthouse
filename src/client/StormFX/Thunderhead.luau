--!strict
-- Thunderhead (Moderate): a towering anvil-topped supercell (Blender model) hangs over the
-- island, lit from inside by constant flickering lightning, under a dark blue-violet sky and
-- driving rain. Bolts (StormEvent "Strike") strike all around, each marked a moment before by
-- a small ring of static; scrap carriers hear their load start to hum, and bolts aimed at them
-- glow red. When the cloud is about to unload (StormEvent "Barrage") its whole body lights up
-- and pulses faster and faster, the ground rumbles... and then the bolts come down in a ring.
-- Textures: Lucky Lightning spark + Golden Rain drop/mote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local CORE = Color3.fromRGB(240, 245, 255)
local ARC = Color3.fromRGB(150, 170, 255)
local ROD = Color3.fromRGB(255, 120, 80)
local INSIDE = Color3.fromRGB(190, 200, 255)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local rumble = 0
	local charge = 0 -- 0..1 while a barrage builds

	Common.clouds(ctx, { Cover = 0.97, Density = 0.9, Color = Color3.fromRGB(60, 60, 85) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 220, 255),
		Saturation = -0.15,
		Brightness = -0.03,
		Contrast = 0.25,
		Bloom = 1.2,
		BloomThreshold = 0.9,
		BloomSize = 36,
	})
	Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1500,
		Size = ns(0, 0.4, 1, 0.4),
		Squash = ns(0, 1.7, 1, 1.7),
		Brightness = 1.2,
		Color = ColorSequence.new(Color3.fromRGB(200, 210, 235)),
		Speed = NumberRange.new(85, 100),
		Slant = Vector3.new(5, 0, 2),
	})
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ThunderheadFlash"
	flash.Parent = Lighting
	table.insert(ctx.cleanup, function()
		task.delay(Common.FADE, function()
			flash:Destroy()
		end)
	end)
	local function flashScreen(strength: number)
		flash.Brightness = 0.35 * strength
		flash.TintColor = Color3.fromRGB(220, 225, 255)
		Common.tween(flash, 0.35, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	end

	-- the thunderhead itself
	local cloud: Model? = nil
	local lights: { PointLight } = {}
	do
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local t = assets and assets:FindFirstChild("Thunderhead")
		if t and t:IsA("Model") then
			local c = t:Clone()
			for _, p in c:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CastShadow = false
				end
			end
			local _, size = c:GetBoundingBox()
			local body = c:FindFirstChildWhichIsA("BasePart")
			if body then
				for i = 1, 6 do
					local holder = Instance.new("Attachment")
					holder.Position = Vector3.new(rnd:NextNumber(-0.35, 0.35) * size.X, rnd:NextNumber(-0.3, 0.4) * size.Y, rnd:NextNumber(-0.35, 0.35) * size.Z)
					holder.Parent = body
					local l = Instance.new("PointLight")
					l.Color = INSIDE
					l.Range = 60
					l.Brightness = 0
					l.Shadows = false
					l.Parent = holder
					table.insert(lights, l)
				end
			end
			c.Parent = ctx.folder
			cloud = c
		end
	end

	local function bolt(to: Vector3, height: number, thickness: number, r: Random, halo: Color3): { BasePart }
		local parts: { BasePart } = {}
		local function segment(a: Vector3, b: Vector3, w: number)
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt((a + b) / 2, b)
			local core = Common.part(ctx, "BoltCore", Vector3.new(w, w, len))
			core.Material = Enum.Material.Neon
			core.Color = CORE
			core.Transparency = 0
			core.CFrame = cf
			local glow = Common.part(ctx, "BoltHalo", Vector3.new(w * 4, w * 4, len))
			glow.Material = Enum.Material.Neon
			glow.Color = halo
			glow.Transparency = 0.7
			glow.CFrame = cf
			table.insert(parts, core)
			table.insert(parts, glow)
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
				if depth > 0 and i < steps - 1 and r:NextNumber() < 0.3 then
					local away = Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-0.9, -0.3), r:NextNumber(-1, 1)).Unit
					path(p, p + away * (target - from).Magnitude * r:NextNumber(0.15, 0.3), w * 0.5, 5, depth - 1)
				end
				prev = p
			end
		end
		path(to + Vector3.new(r:NextNumber(-50, 50), height, r:NextNumber(-50, 50)), to, thickness, 14, 2)
		return parts
	end

	local function flicker(parts: { BasePart }, hold: number, fade: number)
		task.spawn(function()
			for _, v in { false, true, false, true } do
				task.wait(0.05)
				for _, p in parts do
					p.LocalTransparencyModifier = if v then 0 else 1
				end
			end
			task.wait(hold)
			for _, p in parts do
				Common.tween(p, fade, { Transparency = 1 })
			end
			task.wait(fade + 0.1)
			for _, p in parts do
				p:Destroy()
			end
		end)
	end

	local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = 0
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = parent
		return e
	end

	local function impact(at: Vector3, radius: number, color: Color3)
		flicker(bolt(at, 380, 1.6, Random.new(math.floor(at.X * 7 + at.Z * 3)), color), 0.18, 0.4)
		flashScreen(0.8)
		local holder = Common.part(ctx, "StrikeBurst", Vector3.one)
		holder.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
		emitter(holder, {
			Texture = Common.tex(ctx, "Spark"),
			Brightness = 8,
			Color = ColorSequence.new(CORE, color),
			Size = ns(0, 5, 1, 9),
			Transparency = ns(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
		}):Emit(12)
		emitter(holder, {
			Texture = Common.tex(ctx, "Mote"),
			Brightness = 5,
			Color = ColorSequence.new(CORE, color),
			Size = ns(0, 0.5, 1, 0),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(14, 30),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -30, 0),
			Drag = 1.5,
		}):Emit(50)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 90
		light.Brightness = 9
		light.Parent = holder
		Common.tween(light, 0.5, { Brightness = 0 })
		task.delay(1.5, function()
			holder:Destroy()
		end)
		local camera = Workspace.CurrentCamera
		if camera then
			rumble = math.max(rumble, math.clamp(1.3 - (camera.CFrame.Position - at).Magnitude / 100, 0.15, 1.2))
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and hum then
			local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
			if flat.Magnitude < radius and math.abs(root.Position.Y - at.Y) < 12 then
				hum:ChangeState(Enum.HumanoidStateType.FallingDown)
				root.AssemblyLinearVelocity += (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 36 + Vector3.new(0, 24, 0)
				task.delay(1.1, function()
					if hum.Health > 0 then
						hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
				end)
			end
		end
	end

	local function strike(data: { [string]: any })
		local at = data.at :: Vector3
		local warn = tonumber(data.warn) or 1
		local radius = tonumber(data.radius) or 6
		local rod = data.rod == true
		local color = if rod then ROD else ARC
		local ring = Common.part(ctx, "StrikeRing", Vector3.new(0.2, radius * 2, radius * 2))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.8
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local crackle = emitter(ring, {
			Texture = Common.tex(ctx, "Spark"),
			Brightness = 6,
			Color = ColorSequence.new(Color3.new(1, 1, 1), color),
			Size = ns(0, 1, 1, 2),
			Transparency = ns(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.08, 0.15),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			Rate = 30,
		})
		-- the scrap in your hands hums when you're the lightning rod
		local aura: ParticleEmitter? = nil
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if rod and root and (root.Position - at).Magnitude < 8 then
			aura = emitter(root, {
				Texture = Common.tex(ctx, "Spark"),
				Brightness = 5,
				Color = ColorSequence.new(ROD),
				Size = ns(0, 0.7, 1, 1.4),
				Transparency = ns(0, 0, 1, 1),
				Lifetime = NumberRange.new(0.06, 0.12),
				Speed = NumberRange.new(0),
				Rotation = NumberRange.new(0, 360),
				Rate = 70,
			})
		end
		local t0 = os.clock()
		local conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / warn, 0, 1)
			ring.Transparency = 0.8 - 0.55 * k + math.sin(os.clock() * 30) * 0.06
			crackle.Rate = 30 + 100 * k
		end)
		task.delay(warn, function()
			conn:Disconnect()
			ring:Destroy()
			if aura then
				aura:Destroy()
			end
			impact(at, radius, color)
		end)
	end

	local function barrage(warn: number)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < warn do
				charge = (os.clock() - t0) / warn
				task.wait()
			end
			charge = 0
		end)
	end

	local nextFlicker = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		if cloud then
			-- it hangs over the island (well, over you), towering into the sky
			cloud:PivotTo(CFrame.new(camPos.X * 0.85 + 10 * 0.15, 470, camPos.Z * 0.85 + 190 * 0.15) * CFrame.Angles(0, os.clock() * 0.01, 0))
		end
		nextFlicker -= dt * (1 + charge * 8)
		if nextFlicker <= 0 and ramp > 0.3 then
			nextFlicker = rnd:NextNumber(0.15, 0.7)
			local l = lights[rnd:NextInteger(1, math.max(1, #lights))]
			if l then
				l.Brightness = rnd:NextNumber(4, 10) * (1 + charge)
				l.Range = 60 + 60 * charge
				task.delay(rnd:NextNumber(0.05, 0.15), function()
					l.Brightness = 0
				end)
			end
			if charge > 0.2 then
				flashScreen(0.2 + 0.4 * charge)
				rumble = math.max(rumble, 0.3 * charge)
			end
		end
		if rumble > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.035 * rumble, (rnd:NextNumber() - 0.5) * 0.035 * rumble, 0)
			end
			rumble = math.max(0, rumble - dt * 1.5)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Strike" and typeof(data.at) == "Vector3" then
			strike(data)
		elseif kind == "LampStruck" and typeof(data.at) == "Vector3" then
			task.delay(tonumber(data.warn) or 1, impact, data.at, 0, ARC)
		elseif kind == "Barrage" then
			barrage(tonumber(data.warn) or 2.5)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
