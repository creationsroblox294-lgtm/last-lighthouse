--!strict
-- StormFXController: the look of each storm type (StormTypes) on this client.
-- Built so far: Golden Rain.
--   * glowing golden rain (Blender-rendered drop texture), golden splashes and ripples on
--     the ground and water around you, drifting light motes and sparkles
--   * a warm gold grade: atmosphere, colour correction, bloom and sun rays
--   * the lamp sparkles while the rain refuels it
-- Textures come from StormTypes[...].Textures (rendered in Blender, Storms_FX.blend).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StormState = require(Shared:WaitForChild("StormState"))
local StormTypes = require(Shared:WaitForChild("StormTypes"))

local StormFXController = {}

type FX = { stop: () -> () }

local function tween(inst: Instance, seconds: number, goal: { [string]: any })
	local t = TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
	t:Play()
	return t
end

local function invisiblePart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	return p
end

local function ns(...: number): NumberSequence
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(keys)
end

---------------------------------------------------------------------------- Golden Rain
local function goldenRain(def: StormTypes.StormType): FX
	local given = (def :: any).Textures or {}
	local tex: { [string]: string } = {}
	for k, v in given do
		if typeof(v) == "string" and v ~= "" then
			tex[k] = v
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "GoldenRainFX"
	folder.Parent = Workspace

	-- the rain: falls from a sheet that follows the camera
	local cloud = invisiblePart("GoldCloud", Vector3.new(150, 1, 150))
	cloud.Parent = folder
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "GoldenDrops"
	rain.Texture = tex.Drop or "rbxasset://textures/particles/sparkles_main.dds"
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Color = ColorSequence.new(Color3.new(1, 1, 1))
	rain.LightEmission = 0.85
	rain.LightInfluence = 0
	rain.Brightness = 2.2
	rain.Size = ns(0, 0.55, 1, 0.55)
	rain.Squash = ns(0, 1.6, 1, 1.6)
	rain.Transparency = ns(0, 1, 0.08, 0.05, 0.9, 0.05, 1, 1)
	rain.Lifetime = NumberRange.new(1.6, 1.9)
	rain.Speed = NumberRange.new(48, 58)
	rain.Acceleration = Vector3.new(3, 0, 1.5) -- a light slant
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(3, 3)
	rain.Rate = 0
	rain.Parent = cloud
	-- glints: a few big slow drops that catch the light
	local glints = rain:Clone()
	glints.Name = "Glints"
	glints.Size = ns(0, 0.9, 1, 0.9)
	glints.Speed = NumberRange.new(36, 42)
	glints.Brightness = 3.5
	glints.Rate = 0
	glints.Parent = cloud

	-- motes drifting up around you, and sparkles that pop and fade
	local around = invisiblePart("GoldAround", Vector3.new(70, 18, 70))
	around.Parent = folder
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = tex.Mote or "rbxasset://textures/particles/sparkles_main.dds"
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Brightness = 1.6
	motes.Size = ns(0, 0, 0.2, 0.35, 0.8, 0.35, 1, 0)
	motes.Transparency = ns(0, 1, 0.2, 0.25, 0.8, 0.25, 1, 1)
	motes.Lifetime = NumberRange.new(4, 7)
	motes.Speed = NumberRange.new(0.6, 1.6)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0.4, 0.8, 0)
	motes.RotSpeed = NumberRange.new(-20, 20)
	motes.Rate = 0
	motes.Parent = around
	local sparkles = motes:Clone()
	sparkles.Name = "Sparkles"
	sparkles.Texture = tex.Sparkle or motes.Texture
	sparkles.Size = ns(0, 0, 0.15, 0.7, 1, 0)
	sparkles.Transparency = ns(0, 0, 1, 1)
	sparkles.Lifetime = NumberRange.new(0.5, 0.9)
	sparkles.Speed = NumberRange.new(0, 0.3)
	sparkles.Rotation = NumberRange.new(0, 45)
	sparkles.Rate = 0
	sparkles.Parent = around

	-- splashes and ripples: emitted at random ground / water points near the camera
	local splashAt = invisiblePart("SplashAnchor", Vector3.new(1, 1, 1))
	splashAt.Parent = folder
	local att = Instance.new("Attachment")
	att.Parent = splashAt
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Texture = tex.Splash or "rbxasset://textures/particles/sparkles_main.dds"
	splash.Orientation = Enum.ParticleOrientation.FacingCamera
	splash.LightEmission = 0.9
	splash.LightInfluence = 0
	splash.Brightness = 1.8
	splash.Size = ns(0, 0.4, 0.3, 1.1, 1, 1.3)
	splash.Transparency = ns(0, 0.1, 0.5, 0.3, 1, 1)
	splash.Lifetime = NumberRange.new(0.28, 0.36)
	splash.Speed = NumberRange.new(0)
	splash.Rate = 0
	splash.Parent = att
	local ripple = splash:Clone()
	ripple.Name = "Ripple"
	ripple.Texture = tex.Ripple or splash.Texture
	ripple.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ripple.Speed = NumberRange.new(0.01) -- just to give it an up direction
	ripple.EmissionDirection = Enum.NormalId.Top
	ripple.SpreadAngle = Vector2.zero
	ripple.Size = ns(0, 0.3, 1, 3.2)
	ripple.Transparency = ns(0, 0.15, 1, 1)
	ripple.Lifetime = NumberRange.new(0.8, 1.1)
	ripple.Parent = att

	-- the lamp sparkles while the rain refuels it
	local map = Workspace:FindFirstChild("Map")
	local lighthouse = map and map:FindFirstChild("Lighthouse")
	local lampRoom = lighthouse and lighthouse:FindFirstChild("LampRoom")
	local lamp = lampRoom and lampRoom:FindFirstChild("Lamp")
	local lampFx: ParticleEmitter? = nil
	if lamp and lamp:IsA("BasePart") then
		local e = sparkles:Clone()
		e.Name = "GoldenRefuel"
		e.Size = ns(0, 0, 0.2, 2.2, 1, 0)
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 14
		e.Parent = lamp
		lampFx = e
	end

	-- the gold grade (layered on top of the storm look from FogController)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GoldenRainGrade"
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GoldenRainBloom"
	bloom.Intensity = 0
	bloom.Size = 30
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "GoldenRainRays"
	rays.Intensity = 0
	rays.Spread = 0.6
	rays.Parent = Lighting
	local FADE = 5
	tween(cc, FADE, { TintColor = Color3.fromRGB(255, 236, 196), Saturation = 0.18, Brightness = 0.04, Contrast = 0.06 })
	tween(bloom, FADE, { Intensity = 0.9, Threshold = 0.95 })
	tween(rays, FADE, { Intensity = 0.12 })

	local rnd = Random.new()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	params.IgnoreWater = false

	local ramp = 0
	local splashClock = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		ramp = math.min(1, ramp + dt / FADE)
		local pos = camera.CFrame.Position
		cloud.CFrame = CFrame.new(pos + Vector3.new(-6, 55, -3))
		around.CFrame = CFrame.new(pos + Vector3.new(0, -2, 0))
		rain.Rate = 1100 * ramp
		glints.Rate = 60 * ramp
		motes.Rate = 22 * ramp
		sparkles.Rate = 18 * ramp

		-- ~40 splashes a second on whatever the rain hits around you
		splashClock += dt * 40 * ramp
		local filter = { folder :: Instance }
		local character = game:GetService("Players").LocalPlayer.Character
		if character then
			table.insert(filter, character)
		end
		params.FilterDescendantsInstances = filter
		while splashClock >= 1 do
			splashClock -= 1
			local a = rnd:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rnd:NextNumber()) * 45
			local from = pos + Vector3.new(math.cos(a) * r, 40, math.sin(a) * r)
			local hit = Workspace:Raycast(from, Vector3.new(0, -140, 0), params)
			if hit then
				splashAt.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.15, 0))
				if hit.Material == Enum.Material.Water then
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
			end
		end
	end)

	return {
		stop = function()
			conn:Disconnect()
			rain.Rate = 0
			glints.Rate = 0
			motes.Rate = 0
			sparkles.Rate = 0
			if lampFx then
				lampFx.Rate = 0
			end
			tween(cc, FADE, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 })
			tween(bloom, FADE, { Intensity = 0 })
			tween(rays, FADE, { Intensity = 0 })
			task.delay(FADE + 2, function()
				folder:Destroy()
				cc:Destroy()
				bloom:Destroy()
				rays:Destroy()
				if lampFx then
					lampFx:Destroy()
				end
			end)
		end,
	}
end

local BUILDERS: { [string]: (StormTypes.StormType) -> FX } = {
	GoldenRain = goldenRain,
}

-- Is a custom-weather storm on right now? (WeatherController skips its plain rain)
function StormFXController.HasCustomRain(id: string?): boolean
	return id ~= nil and BUILDERS[id] ~= nil
end

function StormFXController.Start()
	local state = StormState.get()
	local active: FX? = nil
	local activeId: string? = nil

	local function refresh()
		local phase = state:GetAttribute("Phase")
		local id = state:GetAttribute("StormType")
		local want: string? = nil
		if phase == "Storm" and typeof(id) == "string" and BUILDERS[id] then
			want = id
		end
		if want == activeId then
			return
		end
		if active then
			active.stop()
			active = nil
		end
		activeId = want
		if want then
			active = BUILDERS[want](StormTypes.Get(want))
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refresh)
	state:GetAttributeChangedSignal("StormType"):Connect(refresh)
	refresh()
end

return StormFXController
