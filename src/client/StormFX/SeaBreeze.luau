--!strict
-- Sea Breeze (Mild): a bright, blustery day. Wind lines race across the island, leaves whirl
-- past, grass and clouds stream downwind and the sea is full of whitecaps. Every gust
-- (StormEvent "Gust") roars up first: the wind lines thicken and the view starts to sway.
-- Then it hits: anyone out in the open is shoved downwind, and a rogue gust knocks you off
-- your feet. Anything over your head keeps you sheltered.
-- Textures: Blender (SeaBreeze: leaf, streak).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local LEAVES = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 170, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 190, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 120, 60)),
})

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local terrain = Workspace.Terrain
	local camera = Workspace.CurrentCamera
	local windDir: Vector3 = (Workspace:GetAttribute("WindDir") :: Vector3?) or Vector3.new(1, 0, 0)
	local gust = 0 -- 0 calm .. 1+ full gust (drives every effect)
	local sway = 0
	local shake = 0

	-- whitecaps, streaming grass and clouds
	local before = { WaterWaveSize = terrain.WaterWaveSize, WaterWaveSpeed = terrain.WaterWaveSpeed }
	Common.tween(terrain, Common.FADE, { WaterWaveSize = 0.6, WaterWaveSpeed = 26 })
	local windBefore = Workspace.GlobalWind
	table.insert(ctx.cleanup, function()
		Common.tween(terrain, Common.FADE, before)
		Workspace.GlobalWind = windBefore
	end)
	Common.clouds(ctx, { Cover = 0.6, Density = 0.45, Color = Color3.fromRGB(245, 248, 255) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(245, 250, 255),
		Saturation = 0.25,
		Brightness = 0.03,
		Contrast = 0.14,
		Bloom = 0.8,
		BloomThreshold = 1.1,
		Rays = 0.2,
	})

	-- the wind sheet: a box upwind of the camera whose top face points downwind
	local sheet = Common.part(ctx, "WindSheet", Vector3.new(160, 1, 50))
	local function emitter(props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.LightInfluence = 0
		e.EmissionDirection = Enum.NormalId.Top
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = sheet
		return e
	end
	local lines = emitter({
		Texture = Common.tex(ctx, "Streak"),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		LightEmission = 0.6,
		Brightness = 2,
		Color = ColorSequence.new(Color3.fromRGB(240, 248, 255)),
		Size = ns(0, 0.35, 1, 0.35),
		Squash = ns(0, -2.5, 1, -2.5),
		Transparency = ns(0, 1, 0.15, 0.55, 0.85, 0.55, 1, 1),
		Lifetime = NumberRange.new(1.4, 1.9),
		Speed = NumberRange.new(60, 85),
		SpreadAngle = Vector2.new(4, 4),
		Rate = 60,
	})
	local leaves = emitter({
		Texture = Common.tex(ctx, "Leaf"),
		LightInfluence = 0.8,
		LightEmission = 0.1,
		Color = LEAVES,
		Size = ns(0, 0.6, 1, 0.6),
		Lifetime = NumberRange.new(2.5, 3.5),
		Speed = NumberRange.new(22, 38),
		SpreadAngle = Vector2.new(15, 25),
		Acceleration = Vector3.new(0, -2, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-400, 400),
		Rate = 18,
	})

	local function sheltered(root: BasePart, character: Model): boolean
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, ctx.folder }
		return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 50, 0), params) ~= nil
	end

	local function onGust(data: { [string]: any })
		local dir = (data.dir :: Vector3).Unit
		local warn = tonumber(data.warn) or 1.3
		local seconds = tonumber(data.seconds) or 2.6
		local strength = tonumber(data.strength) or 1
		local rogue = data.rogue == true
		task.spawn(function()
			-- the roar: the wind swings round and builds
			local t0 = os.clock()
			while os.clock() - t0 < warn do
				local k = (os.clock() - t0) / warn
				windDir = windDir:Lerp(dir, 0.1).Unit
				gust = math.max(gust, k * 0.6 * strength)
				task.wait()
			end
			-- the hit
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			local exposed = root and root:IsA("BasePart") and hum and hum.Health > 0 and not sheltered(root, character :: Model)
			if rogue and exposed and hum then
				hum:ChangeState(Enum.HumanoidStateType.FallingDown)
				shake = math.max(shake, 1)
				task.delay(1.3, function()
					if hum.Parent and hum.Health > 0 then
						hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
				end)
			end
			local h0 = os.clock()
			while os.clock() - h0 < seconds do
				local k = (os.clock() - h0) / seconds
				gust = strength * (1 - k * 0.6)
				if exposed and root and root:IsA("BasePart") then
					local push = dir * (26 * strength) + Vector3.new(0, if rogue then 7 else 3, 0)
					local v = root.AssemblyLinearVelocity
					-- shove downwind, but don't keep stacking speed forever
					if v:Dot(dir) < 45 * strength then
						root.AssemblyLinearVelocity = v + push * 0.25
					end
				end
				shake = math.max(shake, 0.25 * strength)
				task.wait(0.2)
			end
			gust = 0
		end)
	end

	local baseFov = camera and camera.FieldOfView or 70
	table.insert(ctx.cleanup, function()
		local cam = Workspace.CurrentCamera
		if cam then
			Common.tween(cam, 1, { FieldOfView = baseFov })
		end
	end)
	local clock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		clock += dt
		local side = Vector3.new(-windDir.Z, 0, windDir.X)
		sheet.CFrame = CFrame.fromMatrix(camPos - windDir * 70 + Vector3.new(0, 8, 0), side, windDir)
		local g = math.clamp(gust, 0, 1.6)
		lines.Rate = (60 + 340 * g) * ramp
		leaves.Rate = (18 + 90 * g) * ramp
		lines.Speed = NumberRange.new(60 + 40 * g, 85 + 50 * g)
		Workspace.GlobalWind = windDir * (25 + 70 * g) * ramp
		-- the view leans and sways with the wind
		sway += dt * (1 + g * 3)
		local cam = Workspace.CurrentCamera
		if cam then
			cam.FieldOfView = baseFov + 6 * g * ramp
			local roll = math.sin(sway * 1.7) * 0.004 * (1 + g * 4) * ramp
			cam.CFrame *= CFrame.Angles(0, 0, roll)
			if shake > 0.01 then
				cam.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
				shake = math.max(0, shake - dt * 2)
			end
		end
		gust = math.max(0, gust - dt * 0.15)
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Gust" and typeof(data) == "table" and typeof(data.dir) == "Vector3" then
			onGust(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
