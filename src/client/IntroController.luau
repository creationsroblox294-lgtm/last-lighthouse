--!strict
-- IntroController: the intro cutscene, played live in the engine so it stars the player's
-- own Roblox avatar. A clone of your character stands in the rowboat at a bright sunset,
-- the storm rolls in, lightning, a giant wave flips the boat, and you wake face down on the
-- island's south beach and get up to see the lighthouse. Skippable. When it ends the server
-- puts the real character on that beach (IntroService).

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FogController = require(script.Parent:WaitForChild("FogController"))

local IntroController = {}
local player = Players.LocalPlayer

-- timeline (seconds)
local STORM_IN, STORM_FULL = 6, 9
local WAVE, FLIP = 15.6, 17.4
local FADE_OUT, BEACH = 18.8, 20.6
local GETUP, TITLE, FINISH = 22.2, 28.5, 34

local SEA_Y = 0
local BOAT_START = Vector3.new(34, SEA_Y, 1250) -- far out: the island is only a smudge in the haze
local BOAT_SPEED = 2.2 -- studs/s, heading north toward the island

local CAPTIONS = {
	{ 0.8, 5.4, "One last evening on the water..." },
	{ 6.6, 9.6, "Then the sky turned black." },
	{ 15.4, 18.4, "The sea rose like a wall." },
	{ 21.2, 24.6, "...and you wake on a strange shore." },
}
local LIGHTNING = { 7.4, 9.8, 11.3, 12.6, 13.9, 15.1, 16.4 }

-- three looks the scene blends between; all of them punchy and saturated
type Look = {
	clock: number,
	bright: number,
	ambient: Color3,
	outdoor: Color3,
	exposure: number,
	density: number,
	haze: number,
	fog: Color3,
	decay: Color3,
	glare: number,
	sat: number,
	contrast: number,
	tint: Color3,
	water: Color3,
	waves: number,
}
local SUNSET: Look = {
	clock = 17.75,
	bright = 3.2,
	ambient = Color3.fromRGB(150, 105, 125),
	outdoor = Color3.fromRGB(200, 140, 120),
	exposure = 0.25,
	density = 0.3,
	haze = 1.6,
	fog = Color3.fromRGB(255, 165, 115),
	decay = Color3.fromRGB(255, 110, 120),
	glare = 0.8,
	sat = 0.5,
	contrast = 0.12,
	tint = Color3.fromRGB(255, 236, 222),
	water = Color3.fromRGB(18, 150, 170),
	waves = 0.25,
}
local STORM: Look = {
	clock = 17.75,
	bright = 1.8,
	ambient = Color3.fromRGB(105, 115, 175),
	outdoor = Color3.fromRGB(125, 140, 200),
	exposure = 0.35,
	density = 0.42,
	haze = 2.2,
	fog = Color3.fromRGB(95, 120, 190),
	decay = Color3.fromRGB(120, 80, 170),
	glare = 0,
	sat = 0.55,
	contrast = 0.22,
	tint = Color3.fromRGB(200, 225, 255),
	water = Color3.fromRGB(20, 110, 150),
	waves = 1.2,
}
local DAWN: Look = {
	clock = 7.1,
	bright = 3.4,
	ambient = Color3.fromRGB(165, 150, 150),
	outdoor = Color3.fromRGB(190, 175, 165),
	exposure = 0.2,
	density = 0.08, -- clear morning air: the lighthouse is ~580 studs away
	haze = 0.3,
	fog = Color3.fromRGB(255, 210, 170),
	decay = Color3.fromRGB(255, 175, 160),
	glare = 0.5,
	sat = 0.45,
	contrast = 0.1,
	tint = Color3.fromRGB(255, 244, 232),
	water = Color3.fromRGB(25, 160, 170),
	waves = 0.15,
}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- freeze the real character while the film plays; restores what it changed
local frozen: { [string]: number }? = nil
local function controls(enabled: boolean)
	local scripts = player:FindFirstChild("PlayerScripts")
	local moduleScript = scripts and scripts:FindFirstChild("PlayerModule")
	if moduleScript then
		pcall(function()
			local c = (require(moduleScript :: any) :: any):GetControls()
			if enabled then
				c:Enable()
			else
				c:Disable()
			end
		end)
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if not enabled and not frozen then
		frozen = { walk = hum.WalkSpeed, jump = hum.JumpPower, height = hum.JumpHeight }
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	elseif enabled and frozen then
		hum.WalkSpeed = frozen.walk
		hum.JumpPower = frozen.jump
		hum.JumpHeight = frozen.height
		frozen = nil
	end
end

local function label(parent: Instance, font: Enum.Font, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = Color3.fromRGB(255, 246, 230)
	l.TextStrokeColor3 = Color3.fromRGB(40, 20, 30)
	l.TextTransparency = 1
	l.TextStrokeTransparency = 1
	l.ZIndex = 5
	l.Parent = parent
	return l
end

local function makeGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	for i = 0, 1 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, i)
		bar.Position = UDim2.fromScale(0, i)
		bar.Size = UDim2.fromScale(1, 0.1)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 4
		bar.Parent = gui
	end
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.ZIndex = 8
	fade.Parent = gui
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(225, 235, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 7
	flash.Parent = gui
	local caption = label(gui, Enum.Font.Merriweather, 30)
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 0.9, -18)
	caption.Size = UDim2.new(0.8, 0, 0, 40)
	local title = label(gui, Enum.Font.FredokaOne, 72)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.3)
	title.Size = UDim2.new(0.9, 0, 0, 90)
	title.Text = "THE LAST LIGHTHOUSE"
	title.TextColor3 = Color3.fromRGB(255, 214, 120)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(110, 35, 25)
	stroke.Transparency = 1
	stroke.Parent = title
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -24, 1, -24)
	skip.Size = UDim2.fromOffset(130, 44)
	skip.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	skip.BackgroundTransparency = 0.3
	skip.TextColor3 = Color3.fromRGB(255, 236, 200)
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 20
	skip.Text = "Skip  >>"
	skip.ZIndex = 10
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = skip
	skip.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		gui = gui,
		fade = fade,
		flash = flash,
		caption = caption,
		title = title,
		titleStroke = stroke,
		skip = skip,
	}
end

local function noCollide(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
end

-- a copy of the player's own avatar to act out the scene (kept unparented; cloned per scene)
local function makeTemplate(): (Model?, number)
	local character = player.Character or player.CharacterAdded:Wait()
	local t0 = os.clock()
	while not player:HasAppearanceLoaded() and os.clock() - t0 < 6 do
		task.wait(0.1)
	end
	character:WaitForChild("HumanoidRootPart", 5)
	character.Archivable = true
	local actor = character:Clone()
	if not actor then
		return nil, 3
	end
	actor.Name = "IntroActor"
	for _, d in actor:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") or d:IsA("Tool") then
			d:Destroy()
		end
	end
	noCollide(actor)
	local root = actor:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = actor:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		actor:Destroy()
		return nil, 3
	end
	root.Anchored = true
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.EvaluateStateMachine = false
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	actor.PrimaryPart = root
	local standHeight = if hum.RigType == Enum.HumanoidRigType.R15 then hum.HipHeight + root.Size.Y / 2 else 3
	return actor, standHeight
end

local function loadTrack(actor: Model, id: string, looped: boolean): AnimationTrack?
	local hum = actor:FindFirstChildOfClass("Humanoid")
	if not hum or id == "" then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local made = Instance.new("Animator")
		made.Parent = hum
		animator = made
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = looped
		return track
	end
	return nil
end

-- how far the lowest body part sits below the root, measured along `up`; keeping the root
-- that far above a floor keeps the animated body resting on it (feet, knees or chest)
local function lowestBelowRoot(actor: Model, root: BasePart, up: Vector3): number
	local best = math.huge
	local origin = root.Position
	for _, p in actor:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local cf, s = p.CFrame, p.Size
			local ext = 0.5 * (math.abs(cf.XVector:Dot(up)) * s.X + math.abs(cf.YVector:Dot(up)) * s.Y + math.abs(cf.ZVector:Dot(up)) * s.Z)
			local h = (cf.Position - origin):Dot(up) - ext
			if h < best then
				best = h
			end
		end
	end
	return if best == math.huge then -3 else best
end

-- turn the rig into a physics ragdoll and throw it
local function ragdoll(actor: Model, velocity: Vector3, spin: Vector3)
	local hum = actor:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0)
			end
		end
	end
	for _, m in actor:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local joint = Instance.new("BallSocketConstraint")
			joint.Attachment0 = a0
			joint.Attachment1 = a1
			joint.LimitsEnabled = true
			joint.UpperAngle = if m.Name == "Neck" then 35 else 70
			joint.TwistLimitsEnabled = true
			joint.TwistLowerAngle = -40
			joint.TwistUpperAngle = 40
			joint.Parent = m.Part0
			m.Enabled = false
		end
	end
	for _, p in actor:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = p.Name == "HumanoidRootPart" or p.Parent ~= actor
			p.AssemblyLinearVelocity = velocity
			p.AssemblyAngularVelocity = spin
		end
	end
end

-- returns the boat, how high its pivot floats above the sea, and where its floor is
-- relative to the pivot (the oar makes collision raycasts useless here)
local function makeBoat(): (Model, number, number)
	-- ReplicatedStorage.IntroAssets.Rowboat is a copy of the dock's boat (the one in the map
	-- may not be streamed in), kept at the dock's position so its float height carries over
	local assets = ReplicatedStorage:FindFirstChild("IntroAssets")
	local source = assets and assets:FindFirstChild("Rowboat")
	local boat: Model
	local float, floor = 0.3, 0.3
	if source and source:IsA("Model") and source:FindFirstChildWhichIsA("BasePart", true) then
		source.Archivable = true
		boat = source:Clone()
		-- keep the same float height it has at the dock (water there is at y = 0)
		float = source:GetBoundingBox().Position.Y
		floor = 0.35 - float
	else
		-- not streamed in: a simple stand-in hull
		boat = Instance.new("Model")
		local wood = Color3.fromRGB(150, 95, 55)
		local function plank(size: Vector3, cf: CFrame)
			local p = Instance.new("Part")
			p.Size = size
			p.CFrame = cf
			p.Color = wood
			p.Material = Enum.Material.WoodPlanks
			p.Parent = boat
		end
		plank(Vector3.new(5, 0.6, 16), CFrame.new(0, 0, 0))
		plank(Vector3.new(0.6, 2, 16), CFrame.new(-2.7, 1, 0))
		plank(Vector3.new(0.6, 2, 16), CFrame.new(2.7, 1, 0))
		plank(Vector3.new(6, 2, 0.6), CFrame.new(0, 1, 8))
		plank(Vector3.new(6, 2, 0.6), CFrame.new(0, 1, -8))
	end
	boat.Name = "IntroBoat"
	for _, d in boat:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("ProximityPrompt") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	noCollide(boat)
	local cf = boat:GetBoundingBox()
	boat.WorldPivot = CFrame.new(cf.Position)
	return boat, float, floor
end

local function groundAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else pos
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function bolt(parent: Instance, ground: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Bolt"
	local a = ground + Vector3.new(math.random(-20, 20), 190, math.random(-20, 20))
	local segments = 9
	for i = 1, segments do
		local k = i / segments
		local b = a:Lerp(ground, 1 / (segments - i + 1))
		if i < segments then
			b += Vector3.new(math.random(-9, 9), 0, math.random(-9, 9))
		end
		local len = (b - a).Magnitude
		part({
			Size = Vector3.new(0.7 - k * 0.3, 0.7 - k * 0.3, len),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(205, 225, 255),
			Parent = folder,
		})
		a = b
	end
	local glow = Instance.new("PointLight")
	glow.Range = 60
	glow.Brightness = 6
	glow.Color = Color3.fromRGB(200, 220, 255)
	glow.Parent = folder:FindFirstChildWhichIsA("BasePart")
	folder.Parent = parent
	task.delay(0.18, function()
		folder:Destroy()
	end)
end

function IntroController.Start()
	local intro = Config.Intro :: any
	if not intro or intro.Enabled == false then
		return
	end
	local ui = makeGui()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	-- hide the game's own HUD while the film plays
	local hidden: { ScreenGui } = {}
	for _, g in (player:WaitForChild("PlayerGui")):GetChildren() do
		if g:IsA("ScreenGui") and g ~= ui.gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end

	local template, standHeight = makeTemplate()
	controls(false)
	-- wait (a little) for the sea out by the boat to stream in
	do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain }
		params.IgnoreWater = false
		local w = os.clock()
		while os.clock() - w < 8 do
			local hit = Workspace:Raycast(BOAT_START + Vector3.new(0, 60, -20), Vector3.new(0, -120, 0), params)
			if hit and hit.Material == Enum.Material.Water then
				break
			end
			task.wait(0.2)
		end
	end
	local boat, boatFloat, boatFloor = makeBoat()
	local isR15 = false
	if template then
		local h = template:FindFirstChildOfClass("Humanoid")
		isR15 = h ~= nil and h.RigType == Enum.HumanoidRigType.R15
	end
	local anims = intro.Animations or {}
	local ids = {
		row = if isR15 then anims.Row or "" else anims.IdleR6 or "",
		brace = if isR15 then anims.Brace or "" else anims.IdleR6 or "",
		getUp = if isR15 then anims.GetUp or "" else "",
		idle = if isR15 then anims.IdleR15 or "" else anims.IdleR6 or "",
	}
	-- fetch the animations before the film starts so nobody T-poses on frame one
	do
		local list = {}
		for _, id in ids do
			if id ~= "" then
				local a = Instance.new("Animation")
				a.AnimationId = id
				table.insert(list, a)
			end
		end
		local done = false
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
			done = true
		end)
		local w = os.clock()
		while not done and os.clock() - w < 4 do
			task.wait(0.1)
		end
	end

	local scene = Instance.new("Folder")
	scene.Name = "IntroScene"
	boat.Parent = scene
	local seaActor = if template then template:Clone() else nil
	if seaActor then
		seaActor.Parent = scene
	end
	local seaRoot = seaActor and seaActor.PrimaryPart
	local rowTrack = seaActor and loadTrack(seaActor, ids.row, true)
	local braceTrack = seaActor and loadTrack(seaActor, ids.brace, true)
	if rowTrack then
		rowTrack:Play(0)
	end

	local rainCloud = part({ Size = Vector3.new(140, 1, 140), Transparency = 1, Parent = scene })
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
	rain.LightEmission = 0.3
	rain.Transparency = NumberSequence.new(0.35)
	rain.Size = NumberSequence.new(0.22)
	rain.Squash = NumberSequence.new(3)
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Lifetime = NumberRange.new(1.1)
	rain.Speed = NumberRange.new(80, 100)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(8, 8)
	rain.Rate = 0
	rain.Parent = rainCloud
	local wave = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(900, 20, 20),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 160, 185),
		Reflectance = 0.25,
		Transparency = 1,
		Parent = scene,
	})
	-- white foam riding the crest
	local foam = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(900, 6, 6),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(235, 250, 255),
		Transparency = 1,
		Parent = scene,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(0.8, 1.4)
	spray.Speed = NumberRange.new(6, 14)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Rate = 0
	spray.Parent = wave
	scene.Parent = Workspace

	-- take over the look; FogController hands it back when we are done
	FogController.Hold(true)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local terrain = Workspace.Terrain
	local saved = {
		glare = if atmosphere then atmosphere.Glare else 0,
		offset = if atmosphere then atmosphere.Offset else 0,
		waveSize = terrain.WaterWaveSize,
		waveSpeed = terrain.WaterWaveSpeed,
		waterColor = terrain.WaterColor,
		reflect = terrain.WaterReflectance,
	}
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "IntroGrade"
	grade.Parent = Lighting

	local function applyLook(a: Look, b: Look, k: number, flashBoost: number)
		Lighting.ClockTime = lerp(a.clock, b.clock, k)
		Lighting.Brightness = lerp(a.bright, b.bright, k) + flashBoost * 4
		Lighting.Ambient = a.ambient:Lerp(b.ambient, k)
		Lighting.OutdoorAmbient = a.outdoor:Lerp(b.outdoor, k)
		Lighting.ExposureCompensation = lerp(a.exposure, b.exposure, k)
		if atmosphere then
			atmosphere.Density = lerp(a.density, b.density, k)
			atmosphere.Haze = lerp(a.haze, b.haze, k)
			atmosphere.Color = a.fog:Lerp(b.fog, k)
			atmosphere.Decay = a.decay:Lerp(b.decay, k)
			atmosphere.Glare = lerp(a.glare, b.glare, k)
			atmosphere.Offset = 0.15
		end
		grade.Saturation = lerp(a.sat, b.sat, k)
		grade.Contrast = lerp(a.contrast, b.contrast, k)
		grade.TintColor = a.tint:Lerp(b.tint, k)
		grade.Brightness = flashBoost * 0.5
		local water = a.water:Lerp(b.water, k)
		terrain.WaterColor = water
		terrain.WaterWaveSize = lerp(a.waves, b.waves, k)
		terrain.WaterWaveSpeed = lerp(10, 28, k)
		terrain.WaterReflectance = 0.6
	end

	local camera = Workspace.CurrentCamera
	local beachGround = groundAt(Config.World.IntroBeach)
	local tower = Config.World.TowerCenter
	local lamp = Config.World.LampPosition
	local towardTower = (Vector3.new(tower.X, 0, tower.Z) - Vector3.new(beachGround.X, 0, beachGround.Z)).Unit
	local standPos = beachGround + Vector3.new(0, standHeight, 0)
	local standCF = CFrame.lookAt(standPos, standPos + towardTower)
	-- face down along the slope of the sand: head toward the tower, back to the sky
	local headGround = groundAt(beachGround + towardTower * 2.2)
	local feetGround = groundAt(beachGround - towardTower * 2.2)
	local along = (headGround - feetGround).Unit
	local right = standCF.RightVector
	local back = right:Cross(along).Unit
	local proneCF = CFrame.fromMatrix((headGround + feetGround) / 2 + back * 0.6, right, along, back)

	local beachUp = Vector3.yAxis

	local finished = false
	local skipped = false
	ui.skip.Activated:Connect(function()
		skipped = true
	end)

	local seed = math.random() * 100
	local nextBolt = 1
	local lastFlash = -10
	local thrown = false
	local onBeach = false
	local beachActor: Model? = nil
	local beachRoot: BasePart? = nil
	local getUpTrack: AnimationTrack? = nil
	local idleTrack: AnimationTrack? = nil
	local getUpStarted = false
	local idleStarted = false
	local lift = standHeight -- root height above the floor, eased toward what the pose needs
	local camCF: CFrame? = nil
	local fov = 70
	-- Studio testing: set workspace attribute IntroSkipTo (seconds) to start part-way in
	local skipTo = Workspace:GetAttribute("IntroSkipTo")
	local t0 = os.clock() - (if typeof(skipTo) == "number" and RunService:IsStudio() then skipTo else 0)
	while nextBolt <= #LIGHTNING and LIGHTNING[nextBolt] < os.clock() - t0 do
		nextBolt += 1
	end

	-- the boat's pose at time t: gentle swell at sunset, rough seas in the storm, flipped by the wave
	local function boatAt(t: number, s: number): CFrame
		local z = BOAT_START.Z - BOAT_SPEED * t
		local n1 = math.noise(t * 0.35, seed)
		local n2 = math.noise(seed, t * 0.5)
		local bob = math.sin(t * lerp(1.3, 2.4, s)) * lerp(0.2, 0.65, s) + n1 * 0.25 * s
		local pitch = math.rad(math.sin(t * lerp(1.0, 1.9, s) + 0.7) * lerp(1.2, 7, s) + n2 * 4 * s)
		local roll = math.rad(math.sin(t * lerp(0.8, 1.6, s) + 2.1) * lerp(2, 12, s) + n1 * 6 * s)
		local flipK = smooth((t - FLIP) / 1.1)
		roll += flipK * math.rad(170)
		bob -= flipK * 2.5
		return CFrame.new(BOAT_START.X, SEA_Y + boatFloat + 0.35 + bob, z) * CFrame.Angles(pitch, 0, roll)
	end

	RunService:BindToRenderStep("IntroCutscene", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if finished then
			return
		end
		local t = os.clock() - t0
		local holdAt = Workspace:GetAttribute("IntroHoldAt") -- Studio testing: freeze frame
		if typeof(holdAt) == "number" and RunService:IsStudio() then
			t = math.min(t, holdAt)
		end
		camera.CameraType = Enum.CameraType.Scriptable

		-- fades and captions
		local black = 0
		if t < 1.2 then
			black = 1 - t / 1.2
		elseif t > FADE_OUT and t < BEACH then
			black = smooth((t - FADE_OUT) / 0.8)
		elseif t >= BEACH and t < BEACH + 1.8 then
			black = 1 - smooth((t - BEACH) / 1.8)
		elseif t > FINISH - 0.9 then
			black = smooth((t - (FINISH - 0.9)) / 0.9)
		end
		ui.fade.BackgroundTransparency = 1 - black
		local capAlpha = 0
		for _, c in CAPTIONS do
			local a, b = c[1] :: number, c[2] :: number
			if t >= a and t <= b then
				ui.caption.Text = c[3] :: string
				capAlpha = math.min(clamp01((t - a) / 0.6), clamp01((b - t) / 0.6))
			end
		end
		ui.caption.TextTransparency = 1 - capAlpha
		ui.caption.TextStrokeTransparency = 1 - capAlpha * 0.6
		local titleAlpha = math.min(clamp01((t - TITLE) / 1.2), clamp01((FINISH - 0.7 - t) / 0.7))
		ui.title.TextTransparency = 1 - titleAlpha
		ui.titleStroke.Transparency = 1 - titleAlpha
		ui.title.Position = UDim2.fromScale(0.5, 0.3 - 0.02 * clamp01((t - TITLE) / 4))

		-- lightning
		if nextBolt <= #LIGHTNING and t >= LIGHTNING[nextBolt] then
			nextBolt += 1
			lastFlash = t
			local bz = BOAT_START.Z - BOAT_SPEED * t
			local ang = math.random() * math.pi * 2
			bolt(scene, Vector3.new(BOAT_START.X + math.cos(ang) * math.random(50, 110), SEA_Y, bz - math.abs(math.sin(ang)) * math.random(40, 110)))
		end
		local flash = math.max(0, 1 - (t - lastFlash) / 0.3)
		ui.flash.BackgroundTransparency = 1 - flash * 0.55

		local target: CFrame
		local targetFov = 70
		local follow = 3 -- how quickly the camera eases onto its shot (per second)
		if t < BEACH then
			---------------------------------------------------------------- at sea
			local s = smooth((t - STORM_IN) / (STORM_FULL - STORM_IN))
			applyLook(SUNSET, STORM, s, flash)
			rain.Rate = s * 1100

			local boatCF = boatAt(t, s)
			boat:PivotTo(boatCF)
			local z = boatCF.Z
			-- the floor between the benches; you sit facing the stern, as rowers do
			local floorCF = boatCF * CFrame.new(0, boatFloor, 1.5) * CFrame.Angles(0, math.pi, 0)

			if seaActor and seaRoot then
				if t < FLIP then
					-- swap from rowing to bracing as the storm takes hold
					if rowTrack and braceTrack and s > 0.35 and rowTrack.IsPlaying then
						rowTrack:Stop(0.8)
						braceTrack:Play(0.8)
					end
					seaRoot.CFrame = floorCF * CFrame.new(0, lift, 0)
					local need = -lowestBelowRoot(seaActor, seaRoot, floorCF.UpVector)
					lift += (need - lift) * (1 - math.exp(-dt * 10))
				elseif not thrown then
					thrown = true
					local fling = boatCF.RightVector * -16 + Vector3.new(0, 26, 0) + boatCF.LookVector * -5
					ragdoll(seaActor, fling, Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(4, 9)))
				end
			end

			-- the wave: a wall of water rolling in from behind
			if t >= WAVE then
				local w = t - WAVE
				local d = math.min(22 + 26 * w, 70)
				local front = z + 58 - 38 * w
				wave.Size = Vector3.new(900, d, d)
				wave.CFrame = CFrame.new(BOAT_START.X, SEA_Y + d * 0.12, front + d / 2)
				wave.Transparency = 0.05
				foam.Size = Vector3.new(900, d * 0.3, d * 0.3)
				foam.CFrame = CFrame.new(BOAT_START.X, SEA_Y + d * 0.55, front + d * 0.42)
				foam.Transparency = 0.15
				spray.Rate = 220
			end

			-- camera: one continuous move, eased so shot changes glide instead of cutting
			local level = CFrame.new(boatCF.Position) -- ignore the boat's roll for framing
			if t < STORM_IN then
				local a = math.rad(200) + t * 0.12
				local eye = level.Position + Vector3.new(math.sin(a) * 23, 6.5 + t * 0.25, math.cos(a) * 23)
				target = CFrame.lookAt(eye, level.Position + Vector3.new(0, 2.5, 0))
			elseif t < WAVE - 2.5 then
				-- drift in over the bow, looking past you toward the stern and the darkening sea
				local k = smooth((t - STORM_IN) / (WAVE - 2.5 - STORM_IN))
				local eye = level.Position + Vector3.new(lerp(14, 4, k), lerp(8, 5, k), lerp(-16, -10, k))
				target = CFrame.lookAt(eye, level.Position + Vector3.new(0, lerp(3, 3.5, k), lerp(0, 8, k)))
			elseif t < FLIP then
				-- low over the bow: the wave rises behind the boat
				local k = smooth((t - (WAVE - 2.5)) / (FLIP - WAVE + 2.5))
				local eye = level.Position + Vector3.new(lerp(4, 7, k), lerp(5, 3.5, k), lerp(-10, -16, k))
				target = CFrame.lookAt(eye, level.Position + Vector3.new(0, lerp(3.5, 12, k), 10))
				targetFov = lerp(70, 80, k)
			else
				-- pull back and up as you are thrown into the water
				local k = smooth((t - FLIP) / 1.4)
				local eye = Vector3.new(BOAT_START.X + lerp(7, 14, k), SEA_Y + lerp(3.5, 10, k), z - lerp(16, 26, k))
				local look = if seaRoot then seaRoot.Position:Lerp(level.Position, 0.5) else level.Position
				target = CFrame.lookAt(eye, look)
				targetFov = 82
			end
			local shake = s * (if t > WAVE then 1.0 else 0.35)
			target *= CFrame.Angles(
				math.noise(t * 3, seed) * shake * 0.06,
				math.noise(seed, t * 3) * shake * 0.06,
				math.noise(t * 2.5, seed, 3) * shake * 0.05
			)
			follow = if t > FLIP then 5 else 3
		else
			---------------------------------------------------------------- the beach
			if not onBeach then
				onBeach = true
				boat:Destroy()
				wave:Destroy()
				foam:Destroy()
				rain.Rate = 0
				if seaActor then
					seaActor:Destroy()
					seaActor = nil
				end
				if template then
					beachActor = template:Clone()
					local ba = beachActor :: Model
					beachRoot = ba.PrimaryPart
					ba.Parent = scene
					getUpTrack = loadTrack(ba, ids.getUp, false)
					idleTrack = loadTrack(ba, ids.idle, true)
					if getUpTrack then
						-- frame one of the get-up clip is the unconscious pose: hold it
						getUpTrack:Play(0)
						getUpTrack:AdjustSpeed(0)
						getUpTrack.TimePosition = 0
					end
					lift = 1
				end
				camCF = nil -- new scene: no easing from the sea
			end
			applyLook(DAWN, DAWN, 1, 0)

			if not getUpStarted and t >= GETUP and getUpTrack then
				getUpStarted = true
				getUpTrack:AdjustSpeed(1)
			end
			local getUpEnd = GETUP + (if getUpTrack and getUpTrack.Length > 0 then getUpTrack.Length else 4.6)
			if not idleStarted and idleTrack and (t >= getUpEnd - 0.4 or not getUpTrack) and t >= GETUP then
				idleStarted = true
				idleTrack:Play(0.6)
			end

			local ba, br = beachActor, beachRoot
			if ba and br then
				if getUpTrack then
					-- the animation poses the body; we keep its lowest point on the sand
					br.CFrame = CFrame.new(beachGround + beachUp * lift) * standCF.Rotation
					local need = -lowestBelowRoot(ba, br, beachUp)
					lift += (need - lift) * (1 - math.exp(-dt * 12))
				else
					-- R6 avatars: no get-up clip, so tip the whole body up instead
					local up = smooth((t - GETUP) / 1.6)
					br.CFrame = proneCF:Lerp(standCF, up)
				end
			end

			-- one continuous move: low beside you while you lie there, round behind you and up
			-- as you stand, then a flight over the forest to the lighthouse
			local right = standCF.RightVector
			local arcEnd = GETUP + 4.8
			local a = smooth((t - (GETUP + 0.6)) / (arcEnd - GETUP - 0.6))
			local theta = lerp(0, math.rad(70), a)
			local dir = right * math.cos(theta) - towardTower * math.sin(theta)
			local radius = lerp(lerp(6.8, 6.2, clamp01((t - BEACH) / 2)), 11, a)
			local rise = smooth((t - GETUP) / 3.5) -- your head comes up off the sand
			local body = beachGround + towardTower * lerp(1.2, 0, rise) + Vector3.new(0, lerp(0.7, 3.4, rise), 0)
			local arcEye = body + dir * radius + Vector3.new(0, lerp(2.4, 9, a ^ 1.4), 0)
			local fly = smooth((t - arcEnd) / (FINISH - 0.5 - arcEnd))
			local towerFlat = Vector3.new(tower.X, lamp.Y - 30, tower.Z)
			local flyEnd = towerFlat - towardTower * 120 + right * 25
			local eye = arcEye:Lerp(flyEnd, fly) + Vector3.new(0, 45 * math.sin(fly * math.pi) * 0.8, 0)
			target = CFrame.lookAt(eye, body:Lerp(lamp, math.max(a ^ 4 * 0.02, fly ^ 0.6)))
			targetFov = lerp(70, 62, fly)
			follow = 2.2
		end

		if camCF == nil then
			camCF = target
		else
			camCF = (camCF :: CFrame):Lerp(target, 1 - math.exp(-dt * follow))
		end
		fov += (targetFov - fov) * (1 - math.exp(-dt * 3))
		camera.CFrame = camCF :: CFrame
		camera.FieldOfView = fov
		rainCloud.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 50, 0))

		if t >= FINISH or skipped then
			finished = true
		end
	end)

	while not finished do
		task.wait()
	end
	RunService:UnbindFromRenderStep("IntroCutscene")

	-- wrap up: black, hand the world back, wake up for real on the beach
	ui.skip.Visible = false
	ui.caption.TextTransparency = 1
	ui.caption.TextStrokeTransparency = 1
	ui.title.TextTransparency = 1
	ui.titleStroke.Transparency = 1
	ui.flash.BackgroundTransparency = 1
	if skipped then
		TweenService:Create(ui.fade, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		task.wait(0.3)
	end
	ui.fade.BackgroundTransparency = 0
	scene:Destroy()
	if template then
		template:Destroy()
	end
	grade:Destroy()
	if atmosphere then
		atmosphere.Glare = saved.glare
		atmosphere.Offset = saved.offset
	end
	terrain.WaterWaveSize = saved.waveSize
	terrain.WaterWaveSpeed = saved.waveSpeed
	terrain.WaterColor = saved.waterColor
	terrain.WaterReflectance = saved.reflect
	FogController.Hold(false)

	Remotes.event("IntroDone"):FireServer()
	task.wait(0.5)
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	for _, g in hidden do
		g.Enabled = true
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	controls(true)
	TweenService:Create(ui.fade, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	task.wait(1.3)
	ui.gui:Destroy()
end

return IntroController
