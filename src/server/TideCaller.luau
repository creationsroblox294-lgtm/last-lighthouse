--!strict
-- TideCaller: the Great Storm boss (every 10th storm).
-- Rises out of the sea north of the cliff and sends waves that drain the lamp and batter
-- the lamp room. It can only be weakened by holding the beam on its eyes; a hit stuns it
-- and delays the next wave. The storm doesn't end until it's beaten (or MaxStormSeconds pass,
-- then it sinks back without a reward). Beating it leaves whale oil by the ramp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local LightService = require(script.Parent:WaitForChild("LightService"))
local BuildService = require(script.Parent:WaitForChild("BuildService"))
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))

local TC = Config.TideCaller
local TideCaller = {}

local bossState: Configuration
local model: Model? = nil
local eyes: { BasePart } = {}
local active = false
local health = 0
local maxHealth = 0
local nextWave = 0
local stunnedUntil = 0

local SUNK = Vector3.new(0, -60, 0)
local EYE_COLOR = Color3.fromRGB(190, 255, 120)

local function publish()
	bossState:SetAttribute("Active", active)
	bossState:SetAttribute("Health", math.max(0, math.ceil(health)))
	bossState:SetAttribute("MaxHealth", maxHealth)
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local hd = false -- true when the Blender model is used (it animates its own rise and sink)

local function setAnim(name: string, speed: number?, restart: boolean?)
	local m = model
	if not m or not hd then
		return
	end
	m:SetAttribute("AnimSpeed", speed or 1)
	m:SetAttribute("Anim", name)
	if restart then
		m:SetAttribute("AnimRestart", ((m:GetAttribute("AnimRestart") or 0) :: number) + 1)
	end
end

-- Realistic sculpted model from Blender (ReplicatedStorage.CreatureModels.TideCaller)
local function buildHD(template: Model): Model
	local base = Config.World.BossPosition
	local m = Instance.new("Model")
	m.Name = "TideCaller"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local v = template:Clone()
	v.Name = "Visual"
	for _, d in v:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local box, size = v:GetBoundingBox()
	local bottom = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * box.Rotation -- pivot looks forward
	local pivotFromBottom = bottom:ToObjectSpace(v:GetPivot())
	-- about 30% of the body sits below the waterline; it faces the lighthouse (+Z)
	local studsPerMetre = size.Y / 12.3
	local waterBottom = Vector3.new(base.X, base.Y - size.Y * 0.3, base.Z)
	v:PivotTo(CFrame.lookAt(waterBottom, waterBottom + Vector3.new(0, 0, 1)) * pivotFromBottom)
	v.Parent = m
	local body = v:FindFirstChild("Body")
	m.PrimaryPart = if body and body:IsA("BasePart") then body else nil
	table.clear(eyes)
	for _, x in { -0.85, 0.85 } do
		local eye = part(m, Vector3.new(4, 4, 4), CFrame.new(base + Vector3.new(x * studsPerMetre, 6.9 * studsPerMetre - size.Y * 0.3 + 3.7 * studsPerMetre, 2.4 * studsPerMetre)), EYE_COLOR, Enum.Material.Neon, Enum.PartType.Ball)
		eye.Name = "Eye"
		eye.Transparency = 1
		local glow = Instance.new("PointLight")
		glow.Name = "EyeGlow"
		glow.Color = EYE_COLOR
		glow.Range = 40
		glow.Brightness = 3
		glow.Parent = eye
		table.insert(eyes, eye)
	end
	m:SetAttribute("Creature", "TideCaller")
	m:SetAttribute("Anim", "Rise")
	m:SetAttribute("AnimSpeed", 0.35)
	local runtime = Workspace:FindFirstChild("Runtime")
	m.Parent = (runtime and runtime:FindFirstChild("Enemies")) or runtime or Workspace
	return m
end

local function build(): Model
	local folder = ReplicatedStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild("TideCaller")
	hd = template ~= nil and template:IsA("Model")
	if hd then
		return buildHD(template :: Model)
	end
	local m = Instance.new("Model")
	m.Name = "TideCaller"
	local base = Config.World.BossPosition
	local skin = Color3.fromRGB(22, 40, 50)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local body = part(m, Vector3.new(50, 34, 34), CFrame.new(base + Vector3.new(0, 5, 0)) * upright, skin, Enum.Material.Slate, Enum.PartType.Cylinder)
	body.Name = "Body"
	m.PrimaryPart = body
	part(m, Vector3.new(30, 30, 30), CFrame.new(base + Vector3.new(0, 32, 4)), skin, Enum.Material.Slate, Enum.PartType.Ball).Name = "Head"
	table.clear(eyes)
	for _, x in { -6, 6 } do
		local eye = part(m, Vector3.new(6, 6, 6), CFrame.new(base + Vector3.new(x, 36, 17)), EYE_COLOR, Enum.Material.Neon, Enum.PartType.Ball)
		eye.Name = "Eye"
		table.insert(eyes, eye)
	end
	for i = 1, 4 do
		local a = math.rad(-60 + (i - 1) * 40)
		local pos = base + Vector3.new(math.sin(a) * 26, 12, math.cos(a) * 18)
		part(m, Vector3.new(40, 5, 5), CFrame.new(pos) * CFrame.Angles(0, -a, math.rad(70)), skin, Enum.Material.Slate, Enum.PartType.Cylinder).Name = "Tentacle"
	end
	m:PivotTo(m:GetPivot() + SUNK)
	m.Parent = Workspace:FindFirstChild("Runtime") or Workspace
	return m
end

-- Rise (or sink) over a few seconds
local function move(m: Model, offset: Vector3, seconds: number)
	local steps = math.floor(seconds / 0.05)
	local start = m:GetPivot()
	for i = 1, steps do
		if not m.Parent then
			return
		end
		m:PivotTo(start + offset * (i / steps))
		task.wait(0.05)
	end
end

local function despawn(sink: boolean)
	active = false
	publish()
	local m = model
	model = nil
	if m then
		if sink and hd then
			m:SetAttribute("AnimSpeed", 0.5)
			m:SetAttribute("Anim", "Sink")
			task.delay(4.2, function()
				m:Destroy()
			end)
		elseif sink then
			task.spawn(function()
				move(m, SUNK, 4)
				m:Destroy()
			end)
		else
			m:Destroy()
		end
	end
end

local function defeat()
	despawn(true)
	Remotes.notify(nil, "The Tide Caller sinks back into the deep! It left whale oil by the ramp.", "Good")
	ResourceService.SpawnItem("WhaleOil", Config.World.RampBottom + Vector3.new(0, 0, 8))
end

local function spawnBoss()
	if active then
		return
	end
	local players = math.max(1, #Players:GetPlayers())
	maxHealth = math.floor(TC.Health * (1 + TC.ExtraPlayerHealth * (players - 1)))
	health = maxHealth
	active = true
	nextWave = os.clock() + TC.WaveEverySeconds + 6
	stunnedUntil = 0
	local m = build()
	model = m
	publish()
	Remotes.notify(nil, "The Tide Caller rises! Aim the beam at its eyes!", "Alarm")
	StormDirector.HoldStorm("TideCaller", function()
		return active
	end, TC.MaxStormSeconds)
	if hd then
		task.delay(5.8, function()
			if model == m and active then
				setAnim("Idle", 1)
			end
		end)
	else
		task.spawn(function()
			move(m, -SUNK, 6)
		end)
	end
end

local function tick(dt: number)
	if not active then
		return
	end
	local t = os.clock()
	local extra = TC.EyeHalfWidthDegrees - Config.Light.BeamHalfWidthDegrees
	local hit = false
	for _, eye in eyes do
		if LightService.IsInBeam(eye.Position, extra) then
			hit = true
		end
	end
	for _, eye in eyes do
		eye.Color = if hit then Color3.new(1, 1, 1) else EYE_COLOR
		local glow = eye:FindFirstChild("EyeGlow")
		if glow and glow:IsA("PointLight") then
			glow.Color = eye.Color
		end
	end
	if hit and t >= stunnedUntil then
		setAnim("Recoil", 1, true) -- flinches each time a new beam hit lands
	elseif not hit and t >= stunnedUntil and model and model:GetAttribute("Anim") == "Recoil" then
		setAnim("Idle", 1)
	end
	if hit then
		health -= TC.EyeBeamDamagePerSecond * dt
		stunnedUntil = t + TC.StunAfterBeamHitSeconds
		publish()
		if health <= 0 then
			defeat()
			return
		end
	end
	if t >= nextWave then
		if t < stunnedUntil then
			nextWave = t + 2
		else
			nextWave = t + TC.WaveEverySeconds
			LightService.DrainFuel(TC.WaveFuelDrain)
			BuildService.DamageFloor("LampRoom", TC.WaveTowerDamage)
			Remotes.notify(nil, "A huge wave crashes into the lighthouse!", "Wave")
			setAnim("Slam", 1, true)
			task.delay(1.6, function()
				if active and os.clock() >= stunnedUntil then
					setAnim("Idle", 1)
				end
			end)
		end
	end
end

function TideCaller.Start()
	bossState = SharedState.get("Boss")
	publish()
	StormDirector.PhaseChanged:Connect(function(info)
		if info.phase == "Storm" and info.isGreatStorm then
			spawnBoss()
		elseif info.phase ~= "Storm" and active then
			despawn(true)
			if info.phase == "Dawn" then
				Remotes.notify(nil, "The Tide Caller slips back into the fog...", nil)
			end
		end
	end)
	StormDirector.RunReset:Connect(function()
		despawn(false)
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
end

return TideCaller
