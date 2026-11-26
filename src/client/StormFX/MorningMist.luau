--!strict
-- Morning Mist (Mild): a soft pink-and-gold dawn. Thick mist rolls knee-deep across the
-- island, catching the sunrise, with dew glittering in it and sunbeams cutting through. Then
-- the figures come (StormEvent "Phantom"): hooded shapes (Blender model) standing silent out in
-- the mist, turning to watch you, two pale points of light in the hood. Walk towards one and
-- it dissolves into vapour... unless it was real, and a Fog Mimic steps out of the mist instead.
-- Textures: Blender (Drizzle haze) + Fish Rain glint + Golden Rain mote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local MIST = Color3.fromRGB(255, 235, 228)
local GOLD = Color3.fromRGB(255, 210, 140)
local EYES = Color3.fromRGB(200, 230, 255)

return function(ctx: Common.Ctx)
	-- the mist: thick, low and lit by the sunrise
	for i, spec in { { -5, 3, 34, 22, 40 }, { -3, 4, 22, 14, 26 } } do
		Common.around(ctx, "GroundMist" .. i, Vector3.new(150, spec[2], 150), {
			Texture = Common.tex(ctx, "Haze"),
			Rate = spec[3],
			LightEmission = 0.15,
			LightInfluence = 1,
			Brightness = 1.4,
			Color = ColorSequence.new(MIST),
			Size = ns(0, spec[4], 1, spec[5]),
			Transparency = ns(0, 1, 0.25, 0.55, 0.75, 0.55, 1, 1),
			Lifetime = NumberRange.new(12, 16),
			Speed = NumberRange.new(0.3, 1),
			Acceleration = Vector3.new(0.4, 0, 0.2),
			RotSpeed = NumberRange.new(-6, 6),
			Offset = Vector3.new(0, spec[1], 0),
		})
	end
	Common.around(ctx, "Dew", Vector3.new(60, 6, 60), {
		Texture = Common.tex(ctx, "Glint"),
		Rate = 30,
		Brightness = 3,
		Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD),
		Size = ns(0, 0, 0.5, 0.45, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0),
		Offset = Vector3.new(0, -4, 0),
	})
	Common.around(ctx, "Motes", Vector3.new(80, 20, 80), {
		Texture = Common.tex(ctx, "Mote"),
		Rate = 14,
		Brightness = 2,
		Color = ColorSequence.new(GOLD),
		Size = ns(0, 0, 0.2, 0.2, 0.8, 0.2, 1, 0),
	})
	Common.clouds(ctx, { Cover = 0.45, Density = 0.35, Color = Color3.fromRGB(255, 190, 200) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 238, 232),
		Saturation = 0.15,
		Brightness = 0.03,
		Contrast = 0.05,
		Bloom = 1,
		BloomThreshold = 1,
		BloomSize = 40,
		Rays = 0.5,
		RaysSpread = 0.8,
	})
	-- a cold shiver: the colour drains for a moment when a figure first appears
	local shiver = Instance.new("ColorCorrectionEffect")
	shiver.Name = "MistShiver"
	shiver.Parent = Lighting
	table.insert(ctx.cleanup, function()
		task.delay(Common.FADE, function()
			shiver:Destroy()
		end)
	end)

	local function template(): Model?
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local m = assets and assets:FindFirstChild("Phantom")
		return if m and m:IsA("Model") then m else nil
	end

	local function dissolve(fig: Model, feet: BasePart, seconds: number)
		for _, p in fig:GetDescendants() do
			if p:IsA("BasePart") then
				Common.tween(p, seconds, { Transparency = 1 })
			end
		end
		local puff = feet:FindFirstChild("Puff")
		if puff and puff:IsA("ParticleEmitter") then
			puff:Emit(14)
		end
		task.delay(seconds + 0.2, function()
			fig:Destroy()
			feet:Destroy()
		end)
	end

	local function phantom(at: Vector3, real: boolean, seed: number)
		local t = template()
		if not t then
			return
		end
		local r = Random.new(seed)
		local fig = t:Clone()
		for _, p in fig:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Transparency = 1
			end
		end
		local body = fig:FindFirstChild("Body") :: BasePart?
		local eyes = fig:FindFirstChild("Eyes") :: BasePart?
		local feet = Common.part(ctx, "PhantomFeet", Vector3.new(4, 1, 4))
		feet.CFrame = CFrame.new(at)
		local puff = Instance.new("ParticleEmitter")
		puff.Name = "Puff"
		puff.Texture = Common.tex(ctx, "Haze")
		puff.Color = ColorSequence.new(MIST)
		puff.LightInfluence = 1
		puff.LightEmission = 0.1
		puff.Size = ns(0, 4, 1, 10)
		puff.Transparency = ns(0, 0.5, 1, 1)
		puff.Lifetime = NumberRange.new(2, 3)
		puff.Speed = NumberRange.new(1, 3)
		puff.SpreadAngle = Vector2.new(180, 40)
		puff.Rate = 3
		puff.Parent = feet
		fig.Parent = ctx.folder
		-- fade in out of the mist
		if body then
			Common.tween(body, 2, { Transparency = 0.12 })
		end
		if eyes then
			eyes.Material = Enum.Material.Neon
			eyes.Color = EYES
			Common.tween(eyes, 2.5, { Transparency = 0.1 })
		end
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - at).Magnitude < 90 then
			shiver.Saturation = -0.35
			shiver.Contrast = 0.1
			Common.tween(shiver, 2.5, { Saturation = 0, Contrast = 0 })
		end
		local born = os.clock()
		local life = if real then 1.4 else r:NextNumber(12, 18)
		local facing = r:NextNumber(0, math.pi * 2)
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt)
			if not fig.Parent then
				conn:Disconnect()
				return
			end
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local dist = math.huge
			if root and root:IsA("BasePart") then
				local d = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
				dist = d.Magnitude
				-- it slowly turns to watch you
				local want = math.atan2(-d.X, -d.Z)
				local diff = (want - facing + math.pi) % (2 * math.pi) - math.pi
				facing += diff * math.min(1, dt * 0.8)
			end
			-- a slight sway, as if it were drifting with the mist
			local t = os.clock() - born
			fig:PivotTo(CFrame.new(at + Vector3.new(0, math.sin(t * 0.9) * 0.15, 0)) * CFrame.Angles(0, facing, math.sin(t * 0.6) * 0.03))
			if eyes and r:NextNumber() < dt * 0.6 then
				eyes.LocalTransparencyModifier = 1 -- a blink
				task.delay(0.12, function()
					eyes.LocalTransparencyModifier = 0
				end)
			end
			if dist < 18 or t > life then
				conn:Disconnect()
				dissolve(fig, feet, if real then 0.4 else 1.4)
			end
		end)
	end

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Phantom" and typeof(data) == "table" and typeof(data.at) == "Vector3" then
			phantom(data.at, data.real == true, tonumber(data.seed) or 1)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
