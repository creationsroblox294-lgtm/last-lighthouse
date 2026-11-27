--!strict
-- FlareController: what a flare-gun shot looks like, for everyone.
--   1. The shooter raises the gun, it kicks back on the shot (muzzle flash, smoke puff, sparks).
--   2. A red flare round climbs on an arc, leaving a thick smoke trail and spitting sparks.
--   3. At the top it pops, a little parachute opens, and the flare burns bright red,
--      swinging under the canopy and drifting down while it lights up the ground.
-- The server fires FlareFired(at, shooter); everything here is visual only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local FlareController = {}

local TEX = {
	Glow = "rbxassetid://105240361456761",
	Smoke = "rbxassetid://118122779843195",
	Spark = "rbxassetid://105240361456761",
}
local SOUND = {
	Shot = "rbxassetid://94383590611028",
	ShotAlt = "rbxassetid://3634981288",
	Fizz = "rbxassetid://71438605239854",
}

local RED = Color3.fromRGB(255, 70, 45)
local HOT = Color3.fromRGB(255, 205, 150)

-- where the muzzle sits in the flare gun's Handle space (see CombatService HOLD.Flare)
local MUZZLE = CFrame.new(0, 0.73, -1.95)

local BURN_SECONDS = 12
local SPEED = 115
local GRAVITY = 55

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function folder(): Instance
	return Workspace:FindFirstChild("Runtime") or Workspace
end

local function sound(id: string, parent: Instance, volume: number, pitch: number?, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = 400
	s.RollOffMinDistance = 15
	s.Parent = parent
	s:Play()
	return s
end

local function anchoredPart(size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	return p
end

local function smokeEmitter(parent: Instance, rate: number, life: number, size0: number, size1: number, tint: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.Smoke
	e.Color = ColorSequence.new(tint, Color3.fromRGB(150, 150, 155))
	e.LightEmission = 0.05
	e.LightInfluence = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 1.5
	e.Acceleration = Vector3.new(0, 1.2, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size0),
		NumberSequenceKeypoint.new(1, size1),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = parent
	return e
end

local function sparkEmitter(parent: Instance, rate: number, speed: number, fall: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.Spark
	e.Color = ColorSequence.new(HOT, RED)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.3, 0.8)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -fall, 0)
	e.Drag = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Parent = parent
	return e
end

-- A bright ball that swells and fades (muzzle flash, the pop at the top)
local function flash(at: Vector3, size: number, seconds: number, lightRange: number)
	local p = anchoredPart(Vector3.one * size * 0.3, HOT, Enum.Material.Neon, Enum.PartType.Ball)
	p.Position = at
	local glow = Instance.new("BillboardGui")
	glow.Size = UDim2.fromScale(size * 2.2, size * 2.2)
	glow.LightInfluence = 0
	glow.AlwaysOnTop = false
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = TEX.Glow
	img.ImageColor3 = Color3.fromRGB(255, 150, 90)
	img.Parent = glow
	glow.Parent = p
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 90)
	light.Range = lightRange
	light.Brightness = 8
	light.Parent = p
	p.Parent = folder()
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / seconds
		if k >= 1 then
			conn:Disconnect()
			p:Destroy()
			return
		end
		local e = smoothstep(k)
		p.Size = Vector3.one * size * (0.3 + e * 0.9)
		p.Transparency = e
		img.ImageTransparency = e
		light.Brightness = 8 * (1 - e)
	end)
end

-- Sparks/smoke burst that is left behind in the world
local function burst(at: Vector3, sparks: number, smoke: number, sparkSpeed: number)
	local holder = anchoredPart(Vector3.one * 0.1, RED, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.Position = at
	holder.Parent = folder()
	if sparks > 0 then
		local s = sparkEmitter(holder, 0, sparkSpeed, 25)
		s:Emit(sparks)
	end
	if smoke > 0 then
		local m = smokeEmitter(holder, 0, 2.2, 1, 4, Color3.fromRGB(230, 225, 220))
		m:Emit(smoke)
	end
	Debris:AddItem(holder, 3)
end

-- The shooter's gun: raise, kick on the shot, settle, lower. Returns the fire time.
local RAISE = 0.14
local function animateGun(tool: Tool)
	local character = tool.Parent
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local grip = hand and hand:FindFirstChild("RightGrip")
	if not (grip and grip:IsA("JointInstance")) then
		return
	end
	local base = tool.Grip
	local t0 = os.clock()
	-- angle (degrees, nose up) over time
	local function angle(t: number): number
		if t < RAISE then
			return 65 * smoothstep(t / RAISE)
		elseif t < RAISE + 0.05 then
			return 65 + 20 * ((t - RAISE) / 0.05) -- recoil kick
		elseif t < RAISE + 0.35 then
			return 85 - 20 * smoothstep((t - RAISE - 0.05) / 0.3)
		elseif t < 1.05 then
			return 65
		elseif t < 1.45 then
			return 65 * (1 - smoothstep((t - 1.05) / 0.4))
		end
		return 0
	end
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if not grip.Parent or tool.Parent ~= character then
			conn:Disconnect()
			return
		end
		local kickBack = if t > RAISE and t < RAISE + 0.2 then 0.25 * (1 - (t - RAISE) / 0.2) else 0
		grip.C1 = CFrame.Angles(math.rad(-angle(t)), 0, 0) * CFrame.new(0, 0, -kickBack) * base
		if t >= 1.45 then
			grip.C1 = base
			conn:Disconnect()
		end
	end)
end

-- Small camera shake for the person who fired
local function shake(seconds: number, strength: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = os.clock()
	local name = "FlareShake" .. tostring(t0)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local k = (os.clock() - t0) / seconds
		if k >= 1 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local a = strength * (1 - k)
		cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * a), math.rad((math.random() - 0.5) * a), 0)
	end)
end

-- The burning flare under its parachute
local function hang(at: Vector3, drift: Vector3)
	local model = Instance.new("Model")
	model.Name = "Flare"
	local core = anchoredPart(Vector3.new(0.5, 0.9, 0.5), RED, Enum.Material.Neon)
	core.Name = "Core"
	local tube = anchoredPart(Vector3.new(0.45, 0.6, 0.45), Color3.fromRGB(60, 25, 20), Enum.Material.SmoothPlastic)
	tube.Name = "Tube"
	local canopy = anchoredPart(Vector3.new(4.4, 1.7, 4.4), Color3.fromRGB(235, 230, 220), Enum.Material.Fabric, Enum.PartType.Ball)
	canopy.Name = "Canopy"
	canopy.CastShadow = true
	-- flatten the bottom half of the canopy away with a cylinder rim
	local rim = anchoredPart(Vector3.new(0.12, 3.25, 3.25), Color3.fromRGB(200, 60, 45), Enum.Material.Fabric, Enum.PartType.Cylinder)
	rim.Name = "Rim"
	for _, p in { core, tube, canopy, rim } do
		p.Parent = model
	end
	-- lines from the canopy edge to the flare
	local att = Instance.new("Attachment")
	att.Parent = tube
	local lines = {}
	for i = 1, 4 do
		local a = Instance.new("Attachment")
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		a.Position = Vector3.new(math.cos(ang) * 1.5, -0.1, math.sin(ang) * 1.5)
		a.Parent = canopy
		local beam = Instance.new("Beam")
		beam.Attachment0 = a
		beam.Attachment1 = att
		beam.Width0 = 0.05
		beam.Width1 = 0.05
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.fromRGB(220, 215, 205))
		beam.LightInfluence = 1
		beam.Transparency = NumberSequence.new(0.1)
		beam.Parent = canopy
		table.insert(lines, beam)
	end
	-- glow and light
	local glow = Instance.new("BillboardGui")
	glow.Size = UDim2.fromScale(9, 9)
	glow.LightInfluence = 0
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = TEX.Glow
	img.ImageColor3 = RED
	img.Parent = glow
	glow.Parent = core
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 70
	light.Brightness = 5
	light.Shadows = true
	light.Parent = core
	local smoke = smokeEmitter(core, 22, 3.2, 0.8, 5, Color3.fromRGB(255, 160, 140))
	smoke.Acceleration = Vector3.new(0, 2.5, 0)
	local drip = sparkEmitter(core, 35, 4, 40)
	local fizz = sound(SOUND.Fizz, core, 0.7, 0.85, true)
	model.Parent = folder()

	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= BURN_SECONDS + 1.5 then
			conn:Disconnect()
			model:Destroy()
			return
		end
		-- open the canopy over the first 0.4s, then drift down with a gentle swing
		local open = smoothstep(t / 0.4)
		local fall = math.min(t, 1) * 0.5 * 9 + math.max(0, t - 1) * 2.6
		local pos = at + drift * t - Vector3.new(0, fall, 0)
		local swing = math.sin(t * 1.7) * math.rad(10)
		local twist = t * 0.4
		local top = CFrame.new(pos) * CFrame.Angles(0, twist, 0) * CFrame.Angles(swing, 0, swing * 0.6)
		canopy.Size = Vector3.new(0.4 + 4.0 * open, 0.3 + 1.4 * open, 0.4 + 4.0 * open)
		canopy.CFrame = top * CFrame.new(0, 3.8, 0)
		rim.Size = Vector3.new(0.12, 0.3 + 4.1 * open, 0.3 + 4.1 * open)
		rim.CFrame = canopy.CFrame * CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		tube.CFrame = top * CFrame.new(0, 0.3, 0)
		core.CFrame = top * CFrame.new(0, -0.2, 0)
		for _, a in canopy:GetChildren() do
			if a:IsA("Attachment") then
				local ang = math.atan2(a.Position.Z, a.Position.X)
				a.Position = Vector3.new(math.cos(ang) * 2.05 * open, -0.1, math.sin(ang) * 2.05 * open)
			end
		end
		-- burn: flicker, then die out over the last 1.5s
		local life = if t < BURN_SECONDS then 1 else 1 - (t - BURN_SECONDS) / 1.5
		local flicker = 0.8 + 0.2 * math.noise(t * 9, 0.3) + 0.1 * math.sin(t * 31)
		light.Brightness = 5.5 * flicker * life
		light.Range = 60 + 10 * flicker
		img.ImageTransparency = 1 - 0.85 * life * flicker
		core.Transparency = 1 - life
		smoke.Rate = 22 * life
		drip.Rate = 35 * life
		fizz.Volume = 0.7 * life
		if life <= 0.5 then
			for _, b in lines do
				b.Transparency = NumberSequence.new(1 - life * 2)
			end
			canopy.Transparency = 1 - life * 2
			rim.Transparency = canopy.Transparency
			tube.Transparency = canopy.Transparency
		end
	end)
end

-- Fire one flare
local function fire(at: Vector3, shooter: Player?)
	local character = shooter and shooter.Character
	local tool = character and character:FindFirstChild("Flare")
	local mine = shooter == Players.LocalPlayer
	local handle = tool and tool:IsA("Tool") and tool:FindFirstChild("Handle")
	if tool and tool:IsA("Tool") then
		animateGun(tool)
	end
	task.delay(if handle then RAISE else 0, function()
		-- muzzle and aim at the moment of the shot
		local origin: Vector3
		local dir: Vector3
		if handle and handle:IsA("BasePart") and handle.Parent then
			local m = handle.CFrame * MUZZLE
			origin = m.Position
			dir = m.LookVector
			-- flares go up: steep, so it bursts over the shooter's area
			if dir.Y < 0.88 then
				local flat = Vector3.new(dir.X, 0, dir.Z)
				flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
				dir = (flat * 0.42 + Vector3.new(0, 0.9, 0)).Unit
			end
		else
			origin = at - Vector3.new(0, 7, 0)
			dir = Vector3.new(0, 1, 0)
		end

		-- shot: flash, smoke puff, sparks, sound
		flash(origin, 2.2, 0.18, 30)
		burst(origin, 25, 6, 14)
		local snd = anchoredPart(Vector3.one * 0.1, RED, Enum.Material.SmoothPlastic)
		snd.Transparency = 1
		snd.Position = origin
		snd.Parent = folder()
		local shot = sound(SOUND.Shot, snd, 0.9)
		task.delay(0.3, function()
			if not shot.IsLoaded or shot.TimeLength == 0 then
				sound(SOUND.ShotAlt, snd, 0.9)
			end
		end)
		Debris:AddItem(snd, 4)
		if mine then
			shake(0.25, 2.2)
		end

		-- the round: climbs on an arc with a smoke trail
		local round = anchoredPart(Vector3.new(0.35, 0.35, 0.8), RED, Enum.Material.Neon)
		round.CFrame = CFrame.lookAt(origin, origin + dir)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.18, 0.3)
		a0.Parent = round
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.18, 0.3)
		a1.Parent = round
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Texture = TEX.Smoke
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Lifetime = 1.4
		trail.MinLength = 0.1
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 6),
		})
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 140, 110), Color3.fromRGB(190, 185, 185))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.LightEmission = 0.2
		trail.FaceCamera = true
		trail.Parent = round
		local rLight = Instance.new("PointLight")
		rLight.Color = RED
		rLight.Range = 25
		rLight.Brightness = 4
		rLight.Parent = round
		local rSmoke = smokeEmitter(round, 70, 2.4, 0.6, 3.5, Color3.fromRGB(235, 200, 190))
		local rSparks = sparkEmitter(round, 60, 6, 20)
		round.Parent = folder()

		local pos = origin
		local vel = dir * SPEED
		local t0 = os.clock()
		local last = t0
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local dt = math.min(now - last, 1 / 20)
			last = now
			vel -= Vector3.new(0, GRAVITY * dt, 0)
			vel *= 1 - 0.35 * dt
			pos += vel * dt
			round.CFrame = CFrame.lookAt(pos, pos + vel)
			if vel.Y <= 4 or now - t0 > 2.2 then
				conn:Disconnect()
				rSmoke.Enabled = false
				rSparks.Enabled = false
				round.Transparency = 1
				rLight.Enabled = false
				Debris:AddItem(round, 2)
				-- pop and hang
				flash(pos, 5, 0.35, 60)
				burst(pos, 50, 10, 22)
				local pop = anchoredPart(Vector3.one * 0.1, RED, Enum.Material.SmoothPlastic)
				pop.Transparency = 1
				pop.Position = pos
				pop.Parent = folder()
				sound(SOUND.Shot, pop, 0.5, 1.6)
				Debris:AddItem(pop, 3)
				local h = Vector3.new(vel.X, 0, vel.Z) * 0.08
				hang(pos, h)
			end
		end)
	end)
end

function FlareController.Start()
	Remotes.event("FlareFired").OnClientEvent:Connect(function(at: Vector3, shooter: Player?)
		fire(at, shooter)
	end)
end

return FlareController
