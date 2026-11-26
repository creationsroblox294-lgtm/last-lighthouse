--!strict
-- Golden Rain (Blessed): glowing gold rain with glints, golden splashes on land, ripples on
-- water, light motes drifting up, sparkles, the lamp sparkling as it refuels, and a warm grade.
-- Textures: Blender, LastLighthouseAssets/storms/Storms_FX.blend (GoldenRain renders).

local Common = require(script.Parent:WaitForChild("Common"))
local ns = Common.ns

return function(ctx: Common.Ctx)
	-- heavy golden rain, with big bright glints mixed in
	Common.fall(ctx, "GoldenDrops", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1900,
		Speed = NumberRange.new(50, 62),
		Size = ns(0, 0.75, 1, 0.75),
		Squash = ns(0, 1.6, 1, 1.6),
		Brightness = 3,
		LightEmission = 0.9,
		Slant = Vector3.new(3, 0, 1.5),
		Offset = Vector3.new(-6, 0, -3),
	})
	Common.fall(ctx, "Glints", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 170,
		Speed = NumberRange.new(38, 46),
		Size = ns(0, 1.3, 1, 1.3),
		Squash = ns(0, 1.8, 1, 1.8),
		Brightness = 5,
		LightEmission = 1,
		Slant = Vector3.new(3, 0, 1.5),
		Offset = Vector3.new(-6, 0, -3),
	})
	-- falling stars: big spinning gold sparkles drifting down through the rain
	Common.fall(ctx, "FallingStars", {
		Texture = Common.tex(ctx, "Sparkle"),
		Rate = 45,
		Speed = NumberRange.new(10, 18),
		Lifetime = NumberRange.new(3.5, 5),
		Size = ns(0, 1.2, 0.5, 2, 1, 1.4),
		Transparency = ns(0, 1, 0.1, 0, 0.85, 0, 1, 1),
		Brightness = 6,
		LightEmission = 1,
		RotSpeed = NumberRange.new(-120, 120),
		Rotation = NumberRange.new(0, 90),
		Spread = Vector2.new(8, 8),
		Height = 60,
		Width = 120,
	})
	-- glowing embers floating down slowly
	Common.fall(ctx, "Embers", {
		Texture = Common.tex(ctx, "Mote"),
		Rate = 90,
		Speed = NumberRange.new(5, 10),
		Lifetime = NumberRange.new(5, 8),
		Size = ns(0, 0.3, 0.5, 0.45, 1, 0.2),
		Transparency = ns(0, 1, 0.1, 0.1, 0.85, 0.1, 1, 1),
		Brightness = 4,
		LightEmission = 1,
		Spread = Vector2.new(25, 25),
		Slant = Vector3.new(1.5, 0, 0.8),
		Height = 45,
		Width = 110,
	})

	-- small motes rising around you, and sparkles that pop and fade
	Common.around(ctx, "Motes", Vector3.new(70, 18, 70), {
		Texture = Common.tex(ctx, "Mote"),
		Rate = 30,
		Brightness = 2,
		Size = ns(0, 0, 0.2, 0.2, 0.8, 0.2, 1, 0),
		Acceleration = Vector3.new(0.4, 0.8, 0),
	})
	local sparkles = Common.around(ctx, "Sparkles", Vector3.new(70, 18, 70), {
		Texture = Common.tex(ctx, "Sparkle"),
		Rate = 40,
		Brightness = 3,
		Size = ns(0, 0, 0.15, 0.8, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0, 0.3),
		Rotation = NumberRange.new(0, 45),
	})

	-- splashes on land, ripples on water
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Texture = Common.tex(ctx, "Splash")
	splash.LightEmission = 0.9
	splash.LightInfluence = 0
	splash.Brightness = 1.8
	splash.Size = ns(0, 0.4, 0.3, 1.1, 1, 1.3)
	splash.Transparency = ns(0, 0.1, 0.5, 0.3, 1, 1)
	splash.Lifetime = NumberRange.new(0.28, 0.36)
	splash.Speed = NumberRange.new(0)
	splash.Rate = 0
	local ripple = splash:Clone()
	ripple.Name = "Ripple"
	ripple.Texture = Common.tex(ctx, "Ripple")
	ripple.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ripple.Speed = NumberRange.new(0.01)
	ripple.EmissionDirection = Enum.NormalId.Top
	ripple.SpreadAngle = Vector2.zero
	ripple.Size = ns(0, 0.3, 1, 3.2)
	ripple.Transparency = ns(0, 0.15, 1, 1)
	ripple.Lifetime = NumberRange.new(0.8, 1.1)
	local rnd = Random.new()
	local att = Common.impacts(ctx, 70, 45, function(material)
		if material == Enum.Material.Water then
			ripple:Emit(1)
			if rnd:NextNumber() < 0.4 then
				splash:Emit(1)
			end
		else
			splash:Emit(1)
			if rnd:NextNumber() < 0.25 then
				ripple:Emit(1)
			end
		end
	end)
	splash.Parent = att
	ripple.Parent = att

	-- the lamp sparkles while the rain refuels it
	local lamp = Common.lamp()
	if lamp then
		local e = sparkles:Clone()
		e.Name = "GoldenRefuel"
		e.Size = ns(0, 0, 0.2, 2.2, 1, 0)
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(2, 6)
		e.Rate = 14
		e.Parent = lamp
		table.insert(ctx.cleanup, function()
			e.Rate = 0
			task.delay(2, function()
				e:Destroy()
			end)
		end)
	end

	-- thick glowing gold clouds and a warm, bright grade
	Common.clouds(ctx, { Cover = 0.85, Density = 0.7, Color = Color3.fromRGB(255, 196, 110) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 226, 170),
		Saturation = 0.3,
		Brightness = 0.06,
		Contrast = 0.1,
		Bloom = 1.3,
		BloomThreshold = 0.9,
		BloomSize = 36,
		Rays = 0.22,
	})
end
