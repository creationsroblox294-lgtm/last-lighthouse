--!strict
-- Bountiful Tide (Blessed): a glowing turquoise dusk. The sea lights up and fills with drifting
-- bioluminescent sparks. Waves (StormEvent "TideWave") rise out at sea as glassy turquoise
-- crests full of foam and gold glints, roll onto the beach and crash in a burst of spray.
-- Opening a treasure chest (StormEvent "ChestOpened") throws out a fountain of gold.
-- Textures: Blender (Storms_FX.blend: BountifulTide foam, GoldenRain sparkle + mote).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local TEAL = Color3.fromRGB(60, 235, 220)
local FOAM = Color3.fromRGB(235, 255, 252)
local GOLD = Color3.fromRGB(255, 205, 90)
local PINK = Color3.fromRGB(255, 110, 215)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local shake = 0
	local terrain = Workspace.Terrain

	-- the sea glows turquoise for the storm
	local waterBefore = { WaterColor = terrain.WaterColor, WaterTransparency = terrain.WaterTransparency, WaterReflectance = terrain.WaterReflectance }
	Common.tween(terrain, Common.FADE, { WaterColor = Color3.fromRGB(0, 200, 190), WaterTransparency = 0.55, WaterReflectance = 0.9 })
	table.insert(ctx.cleanup, function()
		Common.tween(terrain, Common.FADE, waterBefore)
	end)

	-- bioluminescent sparks drifting just above the waterline, and gold glints in the air
	Common.around(ctx, "SeaGlow", Vector3.new(120, 4, 120), {
		Texture = Common.tex(ctx, "Sparkle"),
		Rate = 160,
		Brightness = 6,
		Color = ColorSequence.new(TEAL, PINK),
		Size = ns(0, 0, 0.3, 0.8, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(0, 1),
		Offset = Vector3.new(0, -4, 0),
	})
	Common.around(ctx, "GoldGlints", Vector3.new(80, 20, 80), {
		Texture = Common.tex(ctx, "Mote"),
		Rate = 60,
		Brightness = 3,
		Size = ns(0, 0, 0.2, 0.3, 0.8, 0.3, 1, 0),
		Acceleration = Vector3.new(0.6, 0.5, 0),
	})
	-- glowing orbs lifting off the sea, teal and pink
	Common.around(ctx, "Lanterns", Vector3.new(140, 6, 140), {
		Texture = Common.tex(ctx, "Mote"),
		Rate = 40,
		Brightness = 4,
		Color = ColorSequence.new(TEAL, PINK),
		Size = ns(0, 0, 0.15, 0.9, 0.85, 0.7, 1, 0),
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(1, 2.5),
		Acceleration = Vector3.new(0, 1.2, 0),
		Offset = Vector3.new(0, -6, 0),
	})
	Common.clouds(ctx, { Cover = 0.7, Density = 0.6, Color = Color3.fromRGB(255, 140, 170) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 238, 240),
		Saturation = 0.6,
		Brightness = 0.05,
		Contrast = 0.16,
		Bloom = 1.2,
		BloomThreshold = 1.15,
		Rays = 0.25,
	})

	local function emitter(parent: Instance, texture: string, props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.LightEmission = 0.8
		e.LightInfluence = 0
		e.Rate = 0
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = parent
		return e
	end

	local function wave(at: Vector3, out: Vector3, seconds: number)
		local side = Vector3.new(-out.Z, 0, out.X)
		local length = 84
		local base = at - Vector3.new(0, 1.5, 0)
		local start = base + out * 95
		local finish = base + out * 3
		-- a curling wave: a long sloped back, a steep glassy face toward the beach, a rolled lip on
		-- top lined with a glowing bioluminescent seam, and a crest of foam and gold riding it
		local back = Instance.new("WedgePart")
		back.Name = "TideBack"
		back.Anchored = true
		back.CanCollide = false
		back.CanQuery = false
		back.CanTouch = false
		back.CastShadow = false
		back.Material = Enum.Material.Glass
		back.Color = Color3.fromRGB(0, 105, 150)
		back.Transparency = 0.12
		back.Reflectance = 0.25
		back.Parent = ctx.folder
		local lip = Common.part(ctx, "TideLip", Vector3.new(length, 2, 2))
		lip.Shape = Enum.PartType.Cylinder
		lip.Material = Enum.Material.Glass
		lip.Color = Color3.fromRGB(40, 215, 225)
		lip.Transparency = 0.1
		lip.Reflectance = 0.3
		local seam = Common.part(ctx, "TideSeam", Vector3.new(length, 0.5, 0.5))
		seam.Material = Enum.Material.Neon
		seam.Color = TEAL
		seam.Transparency = 0.15
		local glow = Instance.new("PointLight")
		glow.Color = TEAL
		glow.Range = 40
		glow.Brightness = 3
		glow.Parent = seam
		-- foam and gold riding along the top of the crest (wider than the wave, to hide its ends)
		local foamBox = Common.part(ctx, "TideFoam", Vector3.new(length + 14, 1, 3))
		local foam = emitter(foamBox, Common.tex(ctx, "Foam"), {
			Brightness = 1.1,
			Color = ColorSequence.new(FOAM, TEAL),
			Size = ns(0, 2.5, 1, 6),
			Transparency = ns(0, 0.15, 0.6, 0.4, 1, 1),
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(4, 12),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -10, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			Rate = 250,
		})
		local mist = emitter(foamBox, Common.tex(ctx, "Foam"), {
			LightEmission = 0.5,
			Brightness = 1,
			Color = ColorSequence.new(Color3.fromRGB(180, 255, 245)),
			Size = ns(0, 4, 1, 12),
			Transparency = ns(0, 0.6, 1, 1),
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(50, 50),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			Rate = 40,
		})
		local gold = emitter(foamBox, Common.tex(ctx, "Sparkle"), {
			LightEmission = 1,
			Brightness = 5,
			Size = ns(0, 0, 0.3, 1.3, 1, 0),
			Transparency = ns(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(1, 5),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 45),
			Rate = 120,
		})
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local rise = math.sin(k * math.pi * 0.85) -- swells, then starts to break
			local h = 2 + 15 * rise
			local pos = start:Lerp(finish, k * k * (3 - 2 * k))
			-- local +Z points at the beach, -Z out to sea
			local frame = CFrame.fromMatrix(pos, side, Vector3.yAxis)
			back.Size = Vector3.new(length, h, h * 2.4)
			back.CFrame = frame * CFrame.new(0, h / 2, -h * 1.2)
			local r = h * 0.62
			lip.Size = Vector3.new(length, r, r)
			lip.CFrame = frame * CFrame.new(0, h - r * 0.2, r * 0.35)
			seam.CFrame = frame * CFrame.new(0, h - r * 0.65, r * 0.55)
			foamBox.Size = Vector3.new(length + 14, 1, r)
			foamBox.CFrame = frame * CFrame.new(0, h + r * 0.2, r * 0.2)
			foam.Rate = 200 + 250 * k
			if k >= 1 then
				conn:Disconnect()
				foam.Rate = 0
				mist.Rate = 0
				gold.Rate = 0
				-- the crash: the wave collapses into a wall of spray along the beach, gold flung
				-- up, a turquoise flash and a shake
				for _, p in { back, lip, seam } do
					Common.tween(p, 0.45, { Transparency = 1, Size = p.Size * Vector3.new(1, 0.15, 1.4) })
				end
				foam.Speed = NumberRange.new(20, 38)
				foam.SpreadAngle = Vector2.new(30, 30)
				foam.Size = ns(0, 4, 1, 9)
				foam.Lifetime = NumberRange.new(0.9, 1.5)
				foam.Acceleration = Vector3.new(0, -28, 0) - out * 6
				foam:Emit(220)
				mist:Emit(30)
				gold.Speed = NumberRange.new(12, 26)
				gold.Acceleration = Vector3.new(0, -20, 0)
				gold:Emit(140)
				local flash = Instance.new("PointLight")
				flash.Color = TEAL
				flash.Range = 60
				flash.Brightness = 7
				flash.Parent = foamBox
				Common.tween(flash, 1.2, { Brightness = 0 })
				local camera = Workspace.CurrentCamera
				if camera then
					local dist = (camera.CFrame.Position - finish).Magnitude
					shake = math.max(shake, math.clamp(1 - dist / 140, 0, 1))
				end
				task.delay(2.2, function()
					back:Destroy()
					lip:Destroy()
					seam:Destroy()
					foamBox:Destroy()
				end)
			end
		end)
	end

	local function goldFountain(at: Vector3)
		local holder = Common.part(ctx, "GoldFountain", Vector3.one)
		holder.CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0))
		local coins = emitter(holder, Common.tex(ctx, "Sparkle"), {
			LightEmission = 1,
			Brightness = 5,
			Color = ColorSequence.new(GOLD),
			Size = ns(0, 1.2, 1, 0.2),
			Transparency = ns(0, 0, 0.8, 0.1, 1, 1),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(14, 26),
			SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -35, 0),
			Rotation = NumberRange.new(0, 90),
			RotSpeed = NumberRange.new(-300, 300),
		})
		coins:Emit(60)
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 30
		light.Brightness = 6
		light.Parent = holder
		Common.tween(light, 1.5, { Brightness = 0 })
		task.delay(2, function()
			holder:Destroy()
		end)
	end

	table.insert(ctx.onFrame, function(dt)
		if shake > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.025 * shake, (rnd:NextNumber() - 0.5) * 0.025 * shake, 0)
			end
			shake = math.max(0, shake - dt * 1.8)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "TideWave" and typeof(data) == "table" and typeof(data.at) == "Vector3" and typeof(data.out) == "Vector3" then
			wave(data.at, data.out, tonumber(data.seconds) or 2)
		elseif kind == "ChestOpened" and typeof(data) == "Vector3" then
			goldFountain(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
