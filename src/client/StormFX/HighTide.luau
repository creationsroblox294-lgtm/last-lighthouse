--!strict
-- High Tide (Moderate): a heaving grey-green sea under a low sky and heavy rain. The sea
-- creeps up over the island (Workspace attribute "FloodLevel"): a glassy, foam-streaked flood
-- slides over the beaches and into the low ground. Wading through it is slow, the current drags
-- you out towards the open sea, the water splashes and rings around your legs, and if your
-- head goes under the world turns murky. Where something is coming up out of the flood
-- (StormEvent "FloodRise") the water boils dark and bursts open.
-- Textures: Bountiful Tide foam + Golden Rain drop/splash/ripple + Drizzle bubble.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local SEA = Color3.fromRGB(45, 95, 100)
local FOAM = Color3.fromRGB(215, 235, 230)
local CENTRE = Vector3.new(10, 0, 190) -- Config.World.IslandCenter (the current pulls away from it)
local SLOW = 0.4 -- fraction of your walking speed the water takes away

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local terrain = Workspace.Terrain
	local shake = 0

	local before = { WaterWaveSize = terrain.WaterWaveSize, WaterWaveSpeed = terrain.WaterWaveSpeed, WaterColor = terrain.WaterColor }
	Common.tween(terrain, Common.FADE, { WaterWaveSize = 0.8, WaterWaveSpeed = 22, WaterColor = SEA })
	table.insert(ctx.cleanup, function()
		Common.tween(terrain, Common.FADE, before)
	end)
	Common.clouds(ctx, { Cover = 0.93, Density = 0.8, Color = Color3.fromRGB(95, 110, 110) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(220, 238, 235),
		Saturation = -0.2,
		Brightness = -0.02,
		Contrast = 0.15,
		Bloom = 0.5,
		BloomThreshold = 1.2,
	})
	Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1300,
		Size = ns(0, 0.4, 1, 0.4),
		Squash = ns(0, 1.6, 1, 1.6),
		Brightness = 1.1,
		Color = ColorSequence.new(Color3.fromRGB(200, 215, 215)),
		Speed = NumberRange.new(80, 95),
		Slant = Vector3.new(6, 0, 3),
	})

	-- the flood: a huge glassy sheet of seawater with foam streaks drifting across it
	local flood = Common.part(ctx, "Flood", Vector3.new(4000, 1, 4000))
	flood.Material = Enum.Material.Glass
	flood.Color = SEA
	flood.Transparency = 1
	flood.Reflectance = 0.25
	local foam = Instance.new("Texture")
	foam.Texture = Common.tex(ctx, "Foam")
	foam.Face = Enum.NormalId.Top
	foam.StudsPerTileU = 36
	foam.StudsPerTileV = 36
	foam.Color3 = FOAM
	foam.Transparency = 1
	foam.Parent = flood
	local shown = 0 -- how visible the flood is (it fades in as it rises)

	-- splashing around your legs while you wade
	local wade = Instance.new("ParticleEmitter")
	wade.Texture = Common.tex(ctx, "Splash")
	wade.Color = ColorSequence.new(FOAM)
	wade.LightEmission = 0.3
	wade.LightInfluence = 0.6
	wade.Size = ns(0, 0.8, 1, 2)
	wade.Transparency = ns(0, 0.3, 1, 1)
	wade.Lifetime = NumberRange.new(0.3, 0.5)
	wade.Speed = NumberRange.new(3, 6)
	wade.SpreadAngle = Vector2.new(60, 60)
	wade.EmissionDirection = Enum.NormalId.Top
	wade.Acceleration = Vector3.new(0, -30, 0)
	wade.Rate = 0
	local wadeHolder = Common.part(ctx, "Wade", Vector3.new(3, 0.2, 3))
	wade.Parent = wadeHolder
	local rings = Instance.new("ParticleEmitter")
	rings.Texture = Common.tex(ctx, "Ripple")
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rings.EmissionDirection = Enum.NormalId.Top
	rings.Color = ColorSequence.new(FOAM)
	rings.LightEmission = 0.3
	rings.Size = ns(0, 1, 1, 5)
	rings.Transparency = ns(0, 0.3, 1, 1)
	rings.Lifetime = NumberRange.new(0.8, 1.2)
	rings.Speed = NumberRange.new(0.01)
	rings.Rate = 0
	rings.Parent = wadeHolder

	-- under the water
	local murk = Instance.new("ColorCorrectionEffect")
	murk.Name = "FloodMurk"
	murk.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "FloodBlur"
	blur.Size = 0
	blur.Parent = Lighting
	table.insert(ctx.cleanup, function()
		task.delay(Common.FADE, function()
			murk:Destroy()
			blur:Destroy()
		end)
	end)

	local function rise(at: Vector3)
		local holder = Common.part(ctx, "FloodRise", Vector3.new(6, 0.2, 6))
		holder.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Texture = Common.tex(ctx, "Bubble")
		bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 200, 190))
		bubbles.LightEmission = 0.3
		bubbles.Size = ns(0, 0.4, 1, 1.4)
		bubbles.Lifetime = NumberRange.new(0.4, 0.8)
		bubbles.Speed = NumberRange.new(2, 5)
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.Rate = 0
		bubbles.Parent = holder
		bubbles:Emit(40)
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = Common.tex(ctx, "Splash")
		burst.Color = ColorSequence.new(Color3.fromRGB(25, 45, 45), FOAM)
		burst.LightInfluence = 0.6
		burst.Size = ns(0, 2, 1, 7)
		burst.Transparency = ns(0, 0.05, 1, 1)
		burst.Lifetime = NumberRange.new(0.6, 1)
		burst.Speed = NumberRange.new(14, 26)
		burst.SpreadAngle = Vector2.new(35, 35)
		burst.EmissionDirection = Enum.NormalId.Top
		burst.Acceleration = Vector3.new(0, -45, 0)
		burst.Rate = 0
		burst.Parent = holder
		task.delay(0.3, function()
			burst:Emit(45)
		end)
		local ring = Common.part(ctx, "RiseRing", Vector3.new(0.2, 2, 2))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(120, 200, 180)
		ring.Transparency = 0.4
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Common.tween(ring, 1, { Size = Vector3.new(0.1, 22, 22), Transparency = 1 })
		local camera = Workspace.CurrentCamera
		if camera then
			shake = math.max(shake, math.clamp(1 - (camera.CFrame.Position - at).Magnitude / 60, 0, 0.8))
		end
		task.delay(2.5, function()
			holder:Destroy()
			ring:Destroy()
		end)
	end

	local level = 0
	local scroll = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local want = tonumber(Workspace:GetAttribute("FloodLevel")) or -2
		level += (want - level) * math.min(1, dt * 1.5)
		local up = want > 0
		shown += ((if up then 1 else 0) - shown) * math.min(1, dt * 0.8)
		flood.CFrame = CFrame.new(camPos.X, level - 0.5, camPos.Z)
		flood.Transparency = 1 - 0.75 * shown * ramp
		foam.Transparency = 1 - 0.2 * shown * ramp
		scroll += dt
		foam.OffsetStudsU = scroll * 4
		foam.OffsetStudsV = scroll * 2.5

		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local depth = if root and root:IsA("BasePart") then level - (root.Position.Y - 3) else -1
		if root and root:IsA("BasePart") and hum and hum.Health > 0 and depth > 0 and up then
			-- wading: the water drags at you and the current pulls you out to sea
			local wadeK = math.clamp(depth / 3, 0, 1)
			local move = hum.MoveDirection
			local out = Vector3.new(root.Position.X - CENTRE.X, 0, root.Position.Z - CENTRE.Z)
			out = if out.Magnitude > 1 then out.Unit else Vector3.xAxis
			root.CFrame += (-move * hum.WalkSpeed * SLOW * wadeK + out * 2.5 * wadeK) * dt * ramp
			wadeHolder.CFrame = CFrame.new(root.Position.X, level + 0.1, root.Position.Z)
			wade.Rate = (5 + 30 * move.Magnitude) * wadeK
			rings.Rate = 2 + 4 * move.Magnitude
		else
			wade.Rate = 0
			rings.Rate = 0
		end
		-- under the water?
		local under = up and camPos.Y < level
		murk.TintColor = if under then Color3.fromRGB(120, 180, 170) else Color3.new(1, 1, 1)
		murk.Brightness = if under then -0.15 else 0
		blur.Size = if under then 10 else 0
		if shake > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
			end
			shake = math.max(0, shake - dt * 2)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "FloodRise" and typeof(data) == "Vector3" then
			rise(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
