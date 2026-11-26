--!strict
-- Rolling Thunder (Mild): a bruised purple-and-orange dusk. Thunder rolls (StormEvent
-- "Thunder"): a chain of flashes races across the clouds and the ground rumbles under you.
-- Then the lightning picks someone (StormEvent "StaticStrike"): a crackling ring of static
-- lights up on the ground where they stand. If it's you, your own body crackles and the edges
-- of the world flicker blue: move! A forked orange-white bolt hits the spot, flings anyone
-- there off their feet, and leaves the grass burning in a scorched circle.
-- Textures: Blender (RollingThunder: flame, smoke) + Lucky Lightning spark/glow + Golden Rain mote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local CORE = Color3.fromRGB(255, 245, 225)
local ARC = Color3.fromRGB(255, 170, 110)
local STATIC = Color3.fromRGB(150, 190, 255)
local FIRE = Color3.fromRGB(255, 140, 40)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local rumble = 0

	Common.clouds(ctx, { Cover = 0.9, Density = 0.85, Color = Color3.fromRGB(95, 70, 95) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 230, 225),
		Saturation = 0.15,
		Brightness = -0.02,
		Contrast = 0.22,
		Bloom = 1.1,
		BloomThreshold = 0.95,
	})
	Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 500,
		Size = ns(0, 0.35, 1, 0.35),
		Squash = ns(0, 1.6, 1, 1.6),
		Brightness = 1,
		Color = ColorSequence.new(Color3.fromRGB(220, 200, 210)),
		Speed = NumberRange.new(80, 95),
		Slant = Vector3.new(6, 0, 3),
	})
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ThunderFlash"
	flash.Parent = Lighting
	local static = Instance.new("ColorCorrectionEffect")
	static.Name = "StaticTingle"
	static.Parent = Lighting
	table.insert(ctx.cleanup, function()
		task.delay(Common.FADE, function()
			flash:Destroy()
			static:Destroy()
		end)
	end)
	local function flashScreen(strength: number, tint: Color3)
		flash.Brightness = 0.32 * strength
		flash.TintColor = tint
		Common.tween(flash, 0.4, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
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

	local function fire(at: Vector3, seconds: number, radius: number)
		local scorch = Common.part(ctx, "Scorch", Vector3.new(0.15, radius * 2, radius * 2))
		scorch.Shape = Enum.PartType.Cylinder
		scorch.Material = Enum.Material.SmoothPlastic
		scorch.Color = Color3.fromRGB(20, 12, 8)
		scorch.Transparency = 0.25
		scorch.CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local box = Common.part(ctx, "Flames", Vector3.new(radius * 1.6, 0.5, radius * 1.6))
		box.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0))
		local flames = emitter(box, {
			Texture = Common.tex(ctx, "Flame"),
			EmissionDirection = Enum.NormalId.Top,
			Brightness = 3,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 120, 60)),
			Size = ns(0, 1.6, 0.4, 2.6, 1, 0.4),
			Transparency = ns(0, 0.1, 0.7, 0.3, 1, 1),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(3, 7),
			SpreadAngle = Vector2.new(10, 10),
			Rate = 60,
		})
		local embers = emitter(box, {
			Texture = Common.tex(ctx, "Mote"),
			EmissionDirection = Enum.NormalId.Top,
			Brightness = 4,
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 70, 20)),
			Size = ns(0, 0.3, 1, 0),
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(5, 12),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(1, 3, 0),
			Rate = 25,
		})
		local smoke = emitter(box, {
			Texture = Common.tex(ctx, "Smoke"),
			EmissionDirection = Enum.NormalId.Top,
			LightEmission = 0,
			LightInfluence = 1,
			Color = ColorSequence.new(Color3.fromRGB(60, 55, 55), Color3.fromRGB(120, 115, 115)),
			Size = ns(0, 3, 1, 12),
			Transparency = ns(0, 0.4, 1, 1),
			Lifetime = NumberRange.new(2.5, 4),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(15, 15),
			RotSpeed = NumberRange.new(-20, 20),
			Rotation = NumberRange.new(0, 360),
			Rate = 8,
		})
		local light = Instance.new("PointLight")
		light.Color = FIRE
		light.Range = radius * 4
		light.Brightness = 3
		light.Parent = box
		local conn = RunService.RenderStepped:Connect(function()
			light.Brightness = 2.5 + math.sin(os.clock() * 23) * 0.6 + math.sin(os.clock() * 37) * 0.4
		end)
		task.delay(seconds, function()
			conn:Disconnect()
			flames.Rate = 0
			embers.Rate = 0
			smoke.Rate = 3
			Common.tween(light, 1.5, { Brightness = 0 })
			task.delay(4, function()
				box:Destroy()
			end)
			Common.tween(scorch, 12, { Transparency = 1 })
			task.delay(12, function()
				scorch:Destroy()
			end)
		end)
	end

	local function staticStrike(data: { [string]: any })
		local at = data.at :: Vector3
		local warn = tonumber(data.warn) or 1.6
		local radius = tonumber(data.radius) or 6
		local me = data.target == Players.LocalPlayer.UserId
		-- the ring of static on the ground
		local ring = Common.part(ctx, "StaticRing", Vector3.new(0.2, radius * 2, radius * 2))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = STATIC
		ring.Transparency = 0.75
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local crackle = emitter(ring, {
			Texture = Common.tex(ctx, "Spark"),
			Brightness = 6,
			Color = ColorSequence.new(Color3.new(1, 1, 1), STATIC),
			Size = ns(0, 1.2, 1, 2.4),
			Transparency = ns(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.08, 0.16),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			Rate = 40,
		})
		-- your own body crackles if it's you
		local aura: ParticleEmitter? = nil
		if me then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				aura = emitter(root, {
					Texture = Common.tex(ctx, "Spark"),
					Brightness = 5,
					Color = ColorSequence.new(STATIC),
					Size = ns(0, 0.8, 1, 1.6),
					Transparency = ns(0, 0, 1, 1),
					Lifetime = NumberRange.new(0.06, 0.12),
					Speed = NumberRange.new(0),
					Rotation = NumberRange.new(0, 360),
					Rate = 60,
				})
			end
		end
		local t0 = os.clock()
		local conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / warn, 0, 1)
			ring.Transparency = 0.75 - 0.5 * k + math.sin(os.clock() * 30) * 0.08
			crackle.Rate = 40 + 120 * k
			if me then
				static.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 220, 255), (0.5 + 0.5 * math.sin(os.clock() * 25)) * k)
				static.Contrast = 0.2 * k
			end
		end)
		task.delay(warn, function()
			conn:Disconnect()
			ring:Destroy()
			if aura then
				aura:Destroy()
			end
			static.TintColor = Color3.new(1, 1, 1)
			static.Contrast = 0
			-- the strike
			flicker(bolt(at, 400, 1.7, Random.new(math.floor(at.X * 13 + at.Z)), ARC), 0.25, 0.5)
			flashScreen(1, Color3.fromRGB(255, 225, 200))
			local holder = Common.part(ctx, "StrikeBurst", Vector3.one)
			holder.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
			emitter(holder, {
				Texture = Common.tex(ctx, "Spark"),
				Brightness = 8,
				Color = ColorSequence.new(CORE, ARC),
				Size = ns(0, 6, 1, 10),
				Transparency = ns(0, 0, 1, 1),
				Lifetime = NumberRange.new(0.15, 0.3),
				Speed = NumberRange.new(0),
				Rotation = NumberRange.new(0, 360),
			}):Emit(14)
			emitter(holder, {
				Texture = Common.tex(ctx, "Mote"),
				Brightness = 5,
				Color = ColorSequence.new(CORE, FIRE),
				Size = ns(0, 0.6, 1, 0),
				Lifetime = NumberRange.new(0.6, 1.2),
				Speed = NumberRange.new(16, 34),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, -30, 0),
				Drag = 1.5,
			}):Emit(70)
			local light = Instance.new("PointLight")
			light.Color = ARC
			light.Range = 100
			light.Brightness = 10
			light.Parent = holder
			Common.tween(light, 0.6, { Brightness = 0 })
			task.delay(2, function()
				holder:Destroy()
			end)
			fire(at, tonumber(data.fire) or 10, radius)
			local camera = Workspace.CurrentCamera
			if camera then
				rumble = math.max(rumble, math.clamp(1.4 - (camera.CFrame.Position - at).Magnitude / 110, 0.2, 1.3))
			end
			-- thrown off your feet if you were still on the spot
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and hum then
				local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
				if flat.Magnitude < radius and math.abs(root.Position.Y - at.Y) < 10 then
					hum:ChangeState(Enum.HumanoidStateType.FallingDown)
					root.AssemblyLinearVelocity += (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 38 + Vector3.new(0, 26, 0)
					task.delay(1.2, function()
						if hum.Health > 0 then
							hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						end
					end)
				end
			end
		end)
	end

	local function thunder(data: { [string]: any })
		local dir = (data.dir :: Vector3).Unit
		local strength = tonumber(data.strength) or 1
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local origin = camera.CFrame.Position
		-- a chain of flashes rolling across the clouds, then the rumble
		task.spawn(function()
			for i = -2, 2 do
				local spot = origin + side * (i * 180) + dir * 450 + Vector3.new(0, 0, 0)
				if rnd:NextNumber() < 0.5 then
					flicker(bolt(spot, 420, 3, rnd, Color3.fromRGB(200, 140, 255)), 0.05, 0.25)
				end
				flashScreen(0.35 * strength, if i % 2 == 0 then Color3.fromRGB(255, 200, 170) else Color3.fromRGB(220, 190, 255))
				rumble = math.max(rumble, 0.35 * strength + (i + 2) * 0.08)
				task.wait(0.22)
			end
		end)
	end

	table.insert(ctx.onFrame, function(dt)
		if rumble > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.035 * rumble, (rnd:NextNumber() - 0.5) * 0.035 * rumble, 0)
			end
			rumble = math.max(0, rumble - dt * 1.2)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "StaticStrike" and typeof(data.at) == "Vector3" then
			staticStrike(data)
		elseif kind == "Thunder" and typeof(data.dir) == "Vector3" then
			thunder(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
