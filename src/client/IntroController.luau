--!strict
-- IntroController: the intro cutscene, played live in the engine so it stars the player's
-- own Roblox avatar. A clone of your character stands in the rowboat at a bright sunset,
-- the storm rolls in, lightning, a giant wave flips the boat, and you wake face down on the
-- island's south beach and get up to see the lighthouse. Skippable. When it ends the server
-- puts the real character on that beach (IntroService).

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
local WAVE, FLIP = 16, 17.6
local FADE_OUT, BEACH = 18.6, 20.4
local STAND, TITLE, FINISH = 24.4, 25.6, 30.5

local SEA_Y = 0
local BOAT_START = Vector3.new(34, SEA_Y, 830) -- far out: the island is only a smudge in the haze
local BOAT_SPEED = 2.2 -- studs/s, heading north toward the island

local CAPTIONS = {
	{ 0.8, 5.4, "One last evening on the water..." },
	{ 6.6, 9.6, "Then the sky turned black." },
	{ 15.9, 18.4, "The sea rose like a wall." },
	{ 21.4, 24.8, "...and you wake on a strange shore." },
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
	density = 0.26,
	haze = 1.1,
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

-- a copy of the player's own avatar to act out the scene
local function makeActor(): (Model?, number)
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
	actor.PrimaryPart = root
	local standHeight = if hum.RigType == Enum.HumanoidRigType.R15 then hum.HipHeight + root.Size.Y / 2 else 3
	return actor, standHeight
end

local function playAnim(actor: Model, id: string): AnimationTrack?
	local hum = actor:FindFirstChildOfClass("Humanoid")
	if not hum then
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
		track.Looped = true
		track:Play(0.3)
		return track
	end
	return nil
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

	local actor, standHeight = makeActor()
	controls(false)
	local boat, boatFloat, boatFloor = makeBoat()

	local scene = Instance.new("Folder")
	scene.Name = "IntroScene"
	boat.Parent = scene
	if actor then
		actor.Parent = scene
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

	local isR15 = false
	if actor then
		local h = actor:FindFirstChildOfClass("Humanoid")
		isR15 = h ~= nil and h.RigType == Enum.HumanoidRigType.R15
	end
	local idle = if actor then playAnim(actor, if isR15 then "rbxassetid://507766388" else "rbxassetid://180435571") else nil
	local fallTrack: AnimationTrack? = nil

	local finished = false
	local skipped = false
	ui.skip.Activated:Connect(function()
		skipped = true
	end)

	local seed = math.random() * 100
	local nextBolt = 1
	local lastFlash = -10
	local flipCF: CFrame? = nil
	local onBeach = false
	-- Studio testing: set workspace attribute IntroSkipTo (seconds) to start part-way in
	local skipTo = Workspace:GetAttribute("IntroSkipTo")
	local t0 = os.clock() - (if typeof(skipTo) == "number" and RunService:IsStudio() then skipTo else 0)
	while nextBolt <= #LIGHTNING and LIGHTNING[nextBolt] < os.clock() - t0 do
		nextBolt += 1
	end

	RunService:BindToRenderStep("IntroCutscene", Enum.RenderPriority.Camera.Value + 1, function()
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
			black = smooth((t - FADE_OUT) / 0.7)
		elseif t >= BEACH and t < BEACH + 1.6 then
			black = 1 - smooth((t - BEACH) / 1.6)
		elseif t > FINISH - 0.8 then
			black = smooth((t - (FINISH - 0.8)) / 0.8)
		end
		ui.fade.BackgroundTransparency = 1 - black
		local capAlpha = 0
		for _, c in CAPTIONS do
			local a, b = c[1] :: number, c[2] :: number
			if t >= a and t <= b then
				ui.caption.Text = c[3] :: string
				capAlpha = math.min(clamp01((t - a) / 0.5), clamp01((b - t) / 0.5))
			end
		end
		ui.caption.TextTransparency = 1 - capAlpha
		ui.caption.TextStrokeTransparency = 1 - capAlpha * 0.6
		local titleAlpha = math.min(clamp01((t - TITLE) / 1.0), clamp01((FINISH - 0.6 - t) / 0.6))
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

		if t < BEACH then
			---------------------------------------------------------------- at sea
			local s = smooth((t - STORM_IN) / (STORM_FULL - STORM_IN))
			applyLook(SUNSET, STORM, s, flash)
			rain.Rate = s * 1100

			local z = BOAT_START.Z - BOAT_SPEED * t
			local amp = lerp(1, 6, s)
			local bob = math.sin(t * lerp(1.4, 2.6, s)) * lerp(0.2, 0.7, s)
			local pitch = math.rad(math.sin(t * lerp(1.1, 2.1, s) + 0.7) * amp * 1.4)
			local roll = math.rad(math.sin(t * lerp(0.9, 1.8, s) + 2.1) * amp * 2.4)
			local flipK = smooth((t - FLIP) / 1.1)
			roll += flipK * math.rad(170)
			bob -= flipK * 2.5
			local boatCF = CFrame.new(BOAT_START.X, SEA_Y + boatFloat + 0.35 + bob, z) * CFrame.Angles(pitch, 0, roll)
			boat:PivotTo(boatCF)
			local seatCF = boatCF * CFrame.new(0, boatFloor + standHeight, 2)

			if actor then
				if t < FLIP then
					actor:PivotTo(seatCF)
				else
					if not flipCF then
						flipCF = seatCF
						if idle then
							idle:Stop(0.2)
						end
						fallTrack = playAnim(actor, if isR15 then "rbxassetid://507767968" else "rbxassetid://180436148")
					end
					local k = t - FLIP
					local base = flipCF :: CFrame
					actor:PivotTo(CFrame.new(base.Position + Vector3.new(-5 * k, 7 * k - 9 * k * k, -4 * k)) * base.Rotation * CFrame.Angles(-k * 3, 0, k * 2.2))
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

			-- camera
			local boatPos = boatCF.Position
			local cam: CFrame
			if t < STORM_IN then
				local a = math.rad(200) + t * 0.16
				local eye = boatPos + Vector3.new(math.sin(a) * 24, 7 + t * 0.3, math.cos(a) * 24)
				cam = CFrame.lookAt(eye, boatPos + Vector3.new(0, 3, 0))
			elseif t < STORM_FULL then
				local k = smooth((t - STORM_IN) / 3)
				local eye = boatPos + Vector3.new(lerp(22, 14, k), lerp(10, 6, k), lerp(-18, 12, k))
				cam = CFrame.lookAt(eye, boatPos + Vector3.new(0, lerp(3, 5, k), 0))
			elseif t < WAVE then
				local k = (t - STORM_FULL) / (WAVE - STORM_FULL)
				local eye = boatPos + Vector3.new(lerp(13, 8, k), 5, lerp(12, 9, k))
				cam = CFrame.lookAt(eye, boatPos + Vector3.new(0, 4, -2))
			else
				local eye = Vector3.new(boatPos.X + 16, SEA_Y + 5, z - 28)
				cam = CFrame.lookAt(eye, Vector3.new(boatPos.X, SEA_Y + 7 + (t - WAVE) * 3, z + 8))
			end
			local shake = s * (if t > WAVE then 1.1 else 0.45)
			cam *= CFrame.Angles(
				math.noise(t * 6, seed) * shake * 0.08,
				math.noise(seed, t * 6) * shake * 0.08,
				math.noise(t * 5, seed, 3) * shake * 0.06
			)
			camera.CFrame = cam
			camera.FieldOfView = if t > WAVE then lerp(70, 82, clamp01((t - WAVE) / 2)) else 70
		else
			---------------------------------------------------------------- the beach
			if not onBeach then
				onBeach = true
				boat:Destroy()
				wave:Destroy()
				foam:Destroy()
				rain.Rate = 0
				if fallTrack then
					fallTrack:Stop(0)
				end
			end
			applyLook(DAWN, DAWN, 1, 0)
			local up = smooth((t - STAND) / 1.4)
			if actor then
				if t > STAND and idle and not idle.IsPlaying then
					idle:Play(0.4)
				end
				actor:PivotTo(proneCF:Lerp(standCF, up))
			end
			local cam: CFrame
			if t < STAND + 0.6 then
				-- low and close by your head as you come round
				local k = (t - BEACH) / (STAND + 0.6 - BEACH)
				local head = headGround + Vector3.new(0, 0.8, 0)
				local eye = head + right * lerp(6.5, 5, k) + towardTower * lerp(3, 2, k) + Vector3.new(0, lerp(3, 3.6, k), 0)
				cam = CFrame.lookAt(eye, head:Lerp(beachGround, 0.5))
			else
				-- crane up behind you to reveal the lighthouse
				local k = smooth((t - STAND - 0.6) / (FINISH - STAND - 1.2))
				local body = standCF.Position
				local eye = body - towardTower * lerp(5, 14, k) + right * lerp(4, 3, k) + Vector3.new(0, lerp(1.5, 12, k), 0)
				cam = CFrame.lookAt(eye, body:Lerp(lamp, lerp(0.05, 0.45, k)))
			end
			camera.CFrame = cam
			camera.FieldOfView = 70
		end
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
