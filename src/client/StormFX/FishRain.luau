--!strict
-- Fish Rain (Blessed): a bright, silvery shower under a rainbow. Far out at sea a towering
-- waterspout twists up into the clouds, flinging spray. Fish (Blender model) tumble out of the
-- sky glinting in the light (StormEvent "FishDrop"), each with a shimmering marker where it
-- will land, and hit the ground in a splash of water and sparkles. Golden fish blaze as they
-- fall and land in a burst of gold; taking one (StormEvent "GoldenTaken") showers gold again.
-- Textures: Blender (FishRain: rainbow, spray, glint) + Golden Rain drop/splash/ripple.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local WATER = Color3.fromRGB(190, 230, 255)
local SILVER = Color3.fromRGB(210, 225, 240)
local GOLD = Color3.fromRGB(255, 200, 60)

return function(ctx: Common.Ctx)
	local rnd = Random.new()

	-- silvery rain, glints in the air, a soft bright grade
	Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1700,
		Size = ns(0, 0.5, 1, 0.5),
		Squash = ns(0, 1.6, 1, 1.6),
		Brightness = 1.6,
		Color = ColorSequence.new(WATER),
		Speed = NumberRange.new(70, 85),
		Slant = Vector3.new(6, 0, 3),
	})
	Common.around(ctx, "Glints", Vector3.new(100, 40, 100), {
		Texture = Common.tex(ctx, "Glint"),
		Rate = 30,
		Brightness = 4,
		Color = ColorSequence.new(Color3.new(1, 1, 1), WATER),
		Size = ns(0, 0, 0.5, 0.9, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.5),
		RotSpeed = NumberRange.new(-90, 90),
	})
	Common.clouds(ctx, { Cover = 0.88, Density = 0.75, Color = Color3.fromRGB(95, 110, 140) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(225, 238, 255),
		Saturation = 0.35,
		Brightness = 0.02,
		Contrast = 0.22,
		Bloom = 1.1,
		BloomThreshold = 0.95,
		Rays = 0.45,
	})
	-- raindrops splashing on the ground around you
	local splashFx = Instance.new("ParticleEmitter")
	splashFx.Texture = Common.tex(ctx, "Splash")
	splashFx.Color = ColorSequence.new(WATER)
	splashFx.LightEmission = 0.5
	splashFx.Size = ns(0, 0.4, 1, 1.2)
	splashFx.Transparency = ns(0, 0.3, 1, 1)
	splashFx.Lifetime = NumberRange.new(0.25, 0.4)
	splashFx.Speed = NumberRange.new(0)
	splashFx.Rate = 0
	local splashes = Common.impacts(ctx, 60, 40, function()
		splashFx:Emit(1)
	end)
	splashFx.Parent = splashes

	-- the rainbow: a huge arc that hangs in the sky away from the spout side
	local sky = Common.part(ctx, "RainbowHolder", Vector3.one)
	local r0 = Instance.new("Attachment")
	local r1 = Instance.new("Attachment")
	r0.Parent = sky
	r1.Parent = sky
	local rainbow = Instance.new("Beam")
	rainbow.Attachment0 = r0
	rainbow.Attachment1 = r1
	rainbow.Texture = Common.tex(ctx, "Rainbow")
	rainbow.TextureMode = Enum.TextureMode.Stretch
	rainbow.LightEmission = 1
	rainbow.LightInfluence = 0
	rainbow.Brightness = 3
	rainbow.FaceCamera = true
	rainbow.Segments = 60
	rainbow.Width0 = 70
	rainbow.Width1 = 70
	rainbow.Parent = sky
	r0.Axis = Vector3.yAxis -- curve the beam upward into an arch
	r1.Axis = Vector3.yAxis

	-- the waterspout, far out at sea
	local spoutAt: Vector3? = Workspace:GetAttribute("FishRainSpout") :: Vector3?
	local spout = Common.part(ctx, "Waterspout", Vector3.one)
	local spoutBeams: { Beam } = {}
	local top = Instance.new("Attachment")
	top.Parent = spout
	for i = 1, 4 do
		local base = Instance.new("Attachment")
		base.Parent = spout
		local b = Instance.new("Beam")
		b.Attachment0 = base
		b.Attachment1 = top
		b.Texture = Common.tex(ctx, "Spray")
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 90
		b.TextureSpeed = -1.2 - i * 0.3 -- spray racing upward
		b.LightEmission = 0.4
		b.LightInfluence = 0.3
		b.Brightness = 2
		b.Color = ColorSequence.new(Color3.fromRGB(215, 235, 250), Color3.fromRGB(150, 175, 205))
		b.Transparency = ns(0, 0.25, 0.7, 0.35, 1, 0.9)
		b.FaceCamera = true
		b.Segments = 30
		b.Width0 = 60 - i * 6
		b.Width1 = 260 - i * 20
		b.Parent = spout
		table.insert(spoutBeams, b)
	end
	local skirt = Instance.new("ParticleEmitter")
	skirt.Texture = Common.tex(ctx, "Splash")
	skirt.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	skirt.LightEmission = 0.3
	skirt.Size = ns(0, 35, 1, 100)
	skirt.Transparency = ns(0, 0.3, 1, 1)
	skirt.Lifetime = NumberRange.new(2, 3.5)
	skirt.Speed = NumberRange.new(25, 45)
	skirt.SpreadAngle = Vector2.new(70, 70)
	skirt.EmissionDirection = Enum.NormalId.Top
	skirt.Acceleration = Vector3.new(0, -12, 0)
	skirt.Rotation = NumberRange.new(0, 360)
	skirt.RotSpeed = NumberRange.new(-30, 30)
	skirt.Rate = 30
	skirt.Parent = spout
	local spoutFish = Instance.new("ParticleEmitter") -- glints of fish whirling up the column
	spoutFish.Texture = Common.tex(ctx, "Glint")
	spoutFish.LightEmission = 1
	spoutFish.LightInfluence = 0
	spoutFish.Brightness = 5
	spoutFish.Size = ns(0, 10, 1, 5)
	spoutFish.Lifetime = NumberRange.new(4, 6)
	spoutFish.Speed = NumberRange.new(50, 80)
	spoutFish.SpreadAngle = Vector2.new(8, 8)
	spoutFish.EmissionDirection = Enum.NormalId.Top
	spoutFish.Rate = 12
	spoutFish.Parent = spout

	-- a falling fish
	local function fishTemplate(): Model?
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local m = assets and assets:FindFirstChild("Fish")
		return if m and m:IsA("Model") then m else nil
	end

	local function burst(at: Vector3, golden: boolean)
		local holder = Common.part(ctx, "FishSplash", Vector3.one)
		holder.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
		local water = Instance.new("ParticleEmitter")
		water.Texture = Common.tex(ctx, "Splash")
		water.Color = ColorSequence.new(if golden then GOLD else WATER)
		water.LightEmission = 0.6
		water.Size = ns(0, 1, 1, 3.5)
		water.Transparency = ns(0, 0.1, 1, 1)
		water.Lifetime = NumberRange.new(0.4, 0.7)
		water.Speed = NumberRange.new(8, 16)
		water.SpreadAngle = Vector2.new(50, 50)
		water.EmissionDirection = Enum.NormalId.Top
		water.Acceleration = Vector3.new(0, -40, 0)
		water.Rate = 0
		water.Parent = holder
		water:Emit(if golden then 40 else 18)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Common.tex(ctx, "Glint")
		sparks.Color = ColorSequence.new(if golden then GOLD else Color3.new(1, 1, 1))
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Brightness = if golden then 7 else 4
		sparks.Size = ns(0, if golden then 2.2 else 1.2, 1, 0)
		sparks.Lifetime = NumberRange.new(0.5, 0.9)
		sparks.Speed = NumberRange.new(6, if golden then 22 else 12)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Drag = 2
		sparks.Rate = 0
		sparks.Parent = holder
		sparks:Emit(if golden then 50 else 14)
		local ring = Common.part(ctx, "FishRipple", Vector3.new(0.2, 1, 1))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = if golden then GOLD else WATER
		ring.Transparency = 0.3
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Common.tween(ring, 0.6, { Size = Vector3.new(0.1, if golden then 20 else 9, if golden then 20 else 9), Transparency = 1 })
		if golden then
			local light = Instance.new("PointLight")
			light.Color = GOLD
			light.Range = 30
			light.Brightness = 6
			light.Parent = holder
			Common.tween(light, 1.2, { Brightness = 0 })
		end
		task.delay(1.5, function()
			holder:Destroy()
			ring:Destroy()
		end)
	end

	local function fishDrop(at: Vector3, seconds: number, golden: boolean, seed: number)
		local r = Random.new(seed)
		-- a shimmering marker where it will land
		local mark = Common.part(ctx, "FishMark", Vector3.new(0.2, 5, 5))
		mark.Shape = Enum.PartType.Cylinder
		mark.Material = Enum.Material.Neon
		mark.Color = if golden then GOLD else WATER
		mark.Transparency = 0.6
		mark.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Common.tween(mark, seconds, { Size = Vector3.new(0.2, 1.5, 1.5), Transparency = 0.2 })
		local template = fishTemplate()
		local fish: Model? = nil
		if template then
			local f = template:Clone()
			for _, p in f:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					if golden and p.Name ~= "Eye" then
						p.Color = if p.Name == "Body" then GOLD else Color3.fromRGB(255, 150, 40)
						p.Material = Enum.Material.Neon
					end
				end
			end
			if golden then
				f:ScaleTo(f:GetScale() * 1.4)
			end
			local body = f:FindFirstChild("Body")
			if body then
				local trail = Instance.new("ParticleEmitter")
				trail.Texture = Common.tex(ctx, "Glint")
				trail.Color = ColorSequence.new(if golden then GOLD else SILVER)
				trail.LightEmission = 1
				trail.LightInfluence = 0
				trail.Brightness = if golden then 6 else 3
				trail.Size = ns(0, if golden then 1.6 else 0.9, 1, 0)
				trail.Lifetime = NumberRange.new(0.3, 0.6)
				trail.Speed = NumberRange.new(0)
				trail.Rate = if golden then 60 else 25
				trail.Parent = body
				local drip = Instance.new("ParticleEmitter")
				drip.Texture = Common.tex(ctx, "Drop")
				drip.Color = ColorSequence.new(WATER)
				drip.LightEmission = 0.4
				drip.Size = ns(0, 0.3, 1, 0.2)
				drip.Lifetime = NumberRange.new(0.3, 0.5)
				drip.Speed = NumberRange.new(2, 5)
				drip.SpreadAngle = Vector2.new(180, 180)
				drip.Rate = 20
				drip.Parent = body
				if golden then
					local light = Instance.new("PointLight")
					light.Color = GOLD
					light.Range = 22
					light.Brightness = 4
					light.Parent = body
				end
			end
			f.Parent = ctx.folder
			fish = f
		end
		local height = 110
		local drift = Vector3.new(r:NextNumber(-25, 25), 0, r:NextNumber(-25, 25))
		local spinA, spinB = r:NextNumber(4, 9), r:NextNumber(2, 6)
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local fall = k * k -- accelerating down
			local pos = at + drift * (1 - k) + Vector3.new(0, height * (1 - fall) + 0.6, 0)
			local t = os.clock() - t0
			if fish then
				fish:PivotTo(CFrame.new(pos) * CFrame.Angles(t * spinA, t * spinB, math.sin(t * 7) * 0.6))
			end
			if k >= 1 then
				conn:Disconnect()
				if fish then
					fish:Destroy()
				end
				mark:Destroy()
				burst(at, golden)
			end
		end)
	end

	local clock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		clock += dt
		-- rainbow: an arch on the far side of the island from the spout
		sky.CFrame = CFrame.new(camPos.X, 0, camPos.Z)
		local away = Vector3.new(1, 0, 0)
		if spoutAt then
			local d = Vector3.new(camPos.X - spoutAt.X, 0, camPos.Z - spoutAt.Z)
			if d.Magnitude > 1 then
				away = d.Unit
			end
		end
		local side = Vector3.new(-away.Z, 0, away.X)
		local center = away * 650
		r0.Position = center - side * 420 + Vector3.new(0, -20, 0)
		r1.Position = center + side * 420 + Vector3.new(0, -20, 0)
		rainbow.CurveSize0 = 520
		rainbow.CurveSize1 = -520
		local shimmer = 0.35 + 0.1 * math.sin(clock * 0.8) + (1 - ramp) * 0.65
		rainbow.Transparency = ns(0, 1, 0.12, shimmer, 0.88, shimmer, 1, 1)
		-- the waterspout twists: the beam bases circle around the foot of the column
		if spoutAt then
			spout.CFrame = CFrame.new(spoutAt)
			top.Position = Vector3.new(math.sin(clock * 0.3) * 50, 600, math.cos(clock * 0.25) * 50)
			for i, b in spoutBeams do
				local a = clock * (1.4 + i * 0.2) + i * 1.6
				local base = b.Attachment0 :: Attachment
				base.Position = Vector3.new(math.cos(a) * 6, 2, math.sin(a) * 6)
				b.CurveSize0 = math.sin(clock * 0.9 + i) * 60
				b.CurveSize1 = math.cos(clock * 0.7 + i) * 90
			end
			skirt.Rate = 30 * ramp
			spoutFish.Rate = 12 * ramp
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "FishDrop" and typeof(data) == "table" and typeof(data.at) == "Vector3" then
			fishDrop(data.at, tonumber(data.seconds) or 1.6, data.golden == true, tonumber(data.seed) or 1)
		elseif kind == "GoldenTaken" and typeof(data) == "Vector3" then
			burst(data, true)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
