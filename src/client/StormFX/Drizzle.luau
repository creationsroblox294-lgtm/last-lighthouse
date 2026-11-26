--!strict
-- Drizzle (Mild): a hushed, silvery afternoon. Fine rain hangs in the air like a veil, soft
-- haze drifts low over the grass, and puddles (server parts in Workspace.DrizzlePuddles)
-- spread across the ground, shimmering with rings. When a puddle stirs (attribute
-- "Stirring"), it darkens to a sickly glow, bubbles and churns, and then something bursts out
-- of it (StormEvent "PuddleBurst") in a spray of black water.
-- Textures: Blender (Drizzle: bubble, haze) + Golden Rain drop/splash/ripple.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local RAIN = Color3.fromRGB(200, 220, 240)
local POOL = Color3.fromRGB(30, 42, 55)
local SICK = Color3.fromRGB(90, 255, 170)

return function(ctx: Common.Ctx)
	local shake = 0
	local rnd = Random.new()

	-- a fine veil of drizzle: lots of tiny, slow drops drifting at a slant
	Common.fall(ctx, "Drizzle", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1500,
		Size = ns(0, 0.15, 1, 0.15),
		Squash = ns(0, 1, 1, 1),
		Brightness = 1.2,
		Color = ColorSequence.new(RAIN),
		Speed = NumberRange.new(38, 48),
		Lifetime = NumberRange.new(2.4, 2.8),
		Slant = Vector3.new(5, 0, 2),
		Transparency = ns(0, 1, 0.1, 0.55, 0.9, 0.55, 1, 1),
	})
	-- low haze rolling over the ground
	Common.around(ctx, "Haze", Vector3.new(140, 4, 140), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 10,
		LightEmission = 0.1,
		LightInfluence = 0.8,
		Brightness = 1,
		Color = ColorSequence.new(Color3.fromRGB(215, 225, 235)),
		Size = ns(0, 18, 1, 34),
		Transparency = ns(0, 1, 0.3, 0.82, 0.7, 0.82, 1, 1),
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0.6, 0, 0.3),
		Offset = Vector3.new(0, -3, 0),
	})
	-- tiny splashes and rings on the ground all around you
	local hits = Instance.new("ParticleEmitter")
	hits.Texture = Common.tex(ctx, "Ripple")
	hits.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	hits.EmissionDirection = Enum.NormalId.Top
	hits.Color = ColorSequence.new(RAIN)
	hits.LightEmission = 0.4
	hits.Size = ns(0, 0.2, 1, 1.4)
	hits.Transparency = ns(0, 0.4, 1, 1)
	hits.Lifetime = NumberRange.new(0.5, 0.7)
	hits.Speed = NumberRange.new(0.01)
	hits.Rate = 0
	local anchor = Common.impacts(ctx, 70, 40, function()
		hits:Emit(1)
	end)
	hits.Parent = anchor
	Common.clouds(ctx, { Cover = 0.82, Density = 0.55, Color = Color3.fromRGB(185, 195, 210) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(225, 235, 248),
		Saturation = -0.15,
		Brightness = 0.02,
		Contrast = 0.08,
		Bloom = 0.7,
		BloomThreshold = 1.1,
	})

	-- dress the puddles
	local dressed: { [Instance]: boolean } = {}
	local function dress(p: Instance)
		if dressed[p] or not p:IsA("BasePart") then
			return
		end
		dressed[p] = true
		local size = tonumber(p:GetAttribute("TargetSize")) or 10
		Common.tween(p, 4, { Size = Vector3.new(0.12, size, size) })
		-- the puddle's own frame has its X axis pointing up; emit flat rings and bubbles from it
		local rings = Instance.new("ParticleEmitter")
		rings.Texture = Common.tex(ctx, "Ripple")
		rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		rings.EmissionDirection = Enum.NormalId.Right
		rings.Color = ColorSequence.new(RAIN)
		rings.LightEmission = 0.5
		rings.Size = ns(0, 0.3, 1, 2.2)
		rings.Transparency = ns(0, 0.3, 1, 1)
		rings.Lifetime = NumberRange.new(0.7, 1)
		rings.Speed = NumberRange.new(0.01)
		rings.Rate = size * 1.5
		rings.Parent = p
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Texture = Common.tex(ctx, "Bubble")
		bubbles.EmissionDirection = Enum.NormalId.Right
		bubbles.Color = ColorSequence.new(SICK)
		bubbles.LightEmission = 0.8
		bubbles.Brightness = 2
		bubbles.Size = ns(0, 0.2, 0.7, 0.9, 1, 1.2)
		bubbles.Transparency = ns(0, 0.2, 0.85, 0.2, 1, 1)
		bubbles.Lifetime = NumberRange.new(0.4, 0.8)
		bubbles.Speed = NumberRange.new(1, 3)
		bubbles.Rate = 0
		bubbles.Parent = p
		local glow = Instance.new("PointLight")
		glow.Color = SICK
		glow.Range = 0
		glow.Brightness = 3
		glow.Parent = p
		local stirConn = p:GetAttributeChangedSignal("Stirring"):Connect(function()
			if p:GetAttribute("Stirring") == true then
				-- something is coming up: the pool darkens and glows, bubbles and churns
				p.Material = Enum.Material.Neon -- the water itself starts to glow
				p.Color = Color3.fromRGB(10, 25, 20)
				Common.tween(p, 2.4, { Color = Color3.fromRGB(40, 170, 100), Transparency = 0.05 })
				Common.tween(glow, 2.4, { Range = size * 2.2 })
				bubbles.Rate = size * 8
				rings.Rate = size * 6
				local camera = Workspace.CurrentCamera
				if camera and (camera.CFrame.Position - p.Position).Magnitude < 60 then
					task.delay(1.6, function()
						shake = math.max(shake, 0.35) -- a rumble under your feet
					end)
				end
			else
				p.Material = Enum.Material.Glass
				p.Color = POOL
				p.Transparency = 0.12
				Common.tween(glow, 2, { Range = 0 })
				bubbles.Rate = 0
				rings.Rate = size * 1.5
			end
		end)
		table.insert(ctx.cleanup, function()
			stirConn:Disconnect()
		end)
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
	local existing = Workspace:FindFirstChild("DrizzlePuddles")
	if existing then
		watch(existing)
	else
		local conn: RBXScriptConnection
		conn = Workspace.ChildAdded:Connect(function(c)
			if c.Name == "DrizzlePuddles" then
				conn:Disconnect()
				watch(c)
			end
		end)
		table.insert(ctx.cleanup, function()
			conn:Disconnect()
		end)
	end

	local function burst(at: Vector3)
		local holder = Common.part(ctx, "PuddleBurst", Vector3.one)
		holder.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
		local water = Instance.new("ParticleEmitter")
		water.Texture = Common.tex(ctx, "Splash")
		water.Color = ColorSequence.new(Color3.fromRGB(30, 50, 45), Color3.fromRGB(70, 120, 100))
		water.LightEmission = 0.2
		water.LightInfluence = 0.6
		water.Size = ns(0, 2, 1, 6)
		water.Transparency = ns(0, 0.05, 1, 1)
		water.Lifetime = NumberRange.new(0.6, 1)
		water.Speed = NumberRange.new(16, 30)
		water.SpreadAngle = Vector2.new(35, 35)
		water.EmissionDirection = Enum.NormalId.Top
		water.Acceleration = Vector3.new(0, -45, 0)
		water.Rate = 0
		water.Parent = holder
		water:Emit(45)
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = Common.tex(ctx, "Haze")
		mist.Color = ColorSequence.new(Color3.fromRGB(60, 90, 80))
		mist.LightEmission = 0
		mist.LightInfluence = 0.8
		mist.Size = ns(0, 6, 1, 16)
		mist.Transparency = ns(0, 0.4, 1, 1)
		mist.Lifetime = NumberRange.new(1.5, 2.5)
		mist.Speed = NumberRange.new(3, 6)
		mist.SpreadAngle = Vector2.new(180, 30)
		mist.Rate = 0
		mist.Parent = holder
		mist:Emit(10)
		local light = Instance.new("PointLight")
		light.Color = SICK
		light.Range = 30
		light.Brightness = 6
		light.Parent = holder
		Common.tween(light, 1, { Brightness = 0 })
		local camera = Workspace.CurrentCamera
		if camera then
			local dist = (camera.CFrame.Position - at).Magnitude
			shake = math.max(shake, math.clamp(1 - dist / 70, 0, 0.9))
		end
		task.delay(3, function()
			holder:Destroy()
		end)
	end

	table.insert(ctx.onFrame, function(dt)
		if shake > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
			end
			shake = math.max(0, shake - dt * 2)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "PuddleBurst" and typeof(data) == "Vector3" then
			burst(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
