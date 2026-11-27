--!strict
-- LobbyController: the harbor at dusk, on the player's side.
--
-- Look and life (all local, nothing replicates):
--   dusk lighting and sea, boats rocking at their moorings, lanterns flickering and swinging,
--   buoys bobbing with blinking lights, the ship's bell swaying, gulls circling and gliding,
--   fish leaping out of the water, the far lighthouse sweeping its beam through the mist,
--   waves and gull calls.
-- Parties:
--   step onto an empty boat and you create its party: pick Solo, 2, 3 or 4 sailors. Others
--   can then join until it's full; when it's full it sets sail after a short countdown.
--   A sign over each boat shows its party (size, who's aboard, the countdown); when you're
--   aboard a panel shows the same with "Leave boat" (and "Party size" for the leader).
--   When a boat casts off it rows out to sea (carrying its passengers) and your screen
--   fades out on the way to the lighthouse.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UISkin = require(script.Parent:WaitForChild("UISkin"))

local LobbyController = {}

local player = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local made: { Instance } = {}
local restore: { () -> () } = {}

local SOUND = {
	Waves = "rbxassetid://136110984304606",
	Gulls = "rbxassetid://9112870701",
}
local SMOKE = "rbxassetid://118122779843195"

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function keep(inst: Instance): Instance
	table.insert(made, inst)
	return inst
end

---------------------------------------------------------------------------
-- Dusk: lighting, sky glow and the sea (put back when the game starts)
---------------------------------------------------------------------------
local function setProps(obj: Instance, props: { [string]: any })
	local old: { [string]: any } = {}
	for k, v in props do
		old[k] = (obj :: any)[k];
		(obj :: any)[k] = v
	end
	table.insert(restore, function()
		for k, v in old do
			pcall(function()
				(obj :: any)[k] = v
			end)
		end
	end)
end

local function dusk()
	setProps(Lighting, {
		-- the sun is just above the sea, straight out past the end of the dock
		ClockTime = 17.78,
		GeographicLatitude = 38,
		Brightness = 2.8,
		Ambient = Color3.fromRGB(70, 62, 80),
		OutdoorAmbient = Color3.fromRGB(150, 118, 128),
		ColorShift_Top = Color3.fromRGB(255, 170, 110),
		ColorShift_Bottom = Color3.fromRGB(60, 40, 80),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.8,
		ExposureCompensation = 0.2,
		FogEnd = 100000,
	})
	-- our own atmosphere / colour grade / bloom / sun rays; the game's ones are hidden meanwhile
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("PostEffect") or c:IsA("Sky") then
			if c:IsA("PostEffect") then
				local was = c.Enabled
				c.Enabled = false
				table.insert(restore, function()
					c.Enabled = was
				end)
			elseif c:IsA("Atmosphere") then
				local parent = c.Parent
				c.Parent = nil
				table.insert(restore, function()
					c.Parent = parent
				end)
			end
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Name = "LobbyAtmosphere"
	atm.Density = 0.3
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(255, 184, 140)
	atm.Decay = Color3.fromRGB(120, 86, 128)
	atm.Glare = 2.2
	atm.Haze = 1.6
	atm.Parent = Lighting
	keep(atm)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LobbyGrade"
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.15
	cc.TintColor = Color3.fromRGB(255, 238, 226)
	cc.Parent = Lighting
	keep(cc)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "LobbyBloom"
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	keep(bloom)
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "LobbyRays"
	rays.Intensity = 0.12
	rays.Spread = 0.6
	rays.Parent = Lighting
	keep(rays)
	local terrain = Workspace.Terrain
	setProps(terrain, {
		WaterColor = Color3.fromRGB(32, 70, 92),
		WaterTransparency = 0.45,
		WaterReflectance = 0.75,
		WaterWaveSize = 0.32,
		WaterWaveSpeed = 9,
	})
end

---------------------------------------------------------------------------
-- Gulls: built from parts (body, head, beak, two-piece wings that flap and glide)
---------------------------------------------------------------------------
type Gull = { model: Model, body: BasePart, wings: { { root: BasePart, tip: BasePart, side: number } }, center: Vector3, radius: number, height: number, speed: number, phase: number, flap: number }

local function gullPart(model: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function makeGull(center: Vector3, radius: number, height: number, speed: number, phase: number, parent: Instance): Gull
	local model = Instance.new("Model")
	model.Name = "Gull"
	local white = Color3.fromRGB(238, 236, 232)
	local grey = Color3.fromRGB(150, 156, 164)
	local body = gullPart(model, "Body", Vector3.new(0.7, 0.62, 1.9), white, Enum.PartType.Ball)
	gullPart(model, "Head", Vector3.new(0.5, 0.5, 0.55), white, Enum.PartType.Ball)
	gullPart(model, "Beak", Vector3.new(0.12, 0.12, 0.4), Color3.fromRGB(240, 190, 60))
	gullPart(model, "Tail", Vector3.new(0.5, 0.08, 0.5), grey)
	local wings = {}
	for _, side in { -1, 1 } do
		local root = gullPart(model, "WingRoot", Vector3.new(1.4, 0.08, 0.7), grey)
		local tip = gullPart(model, "WingTip", Vector3.new(1.4, 0.06, 0.5), Color3.fromRGB(60, 62, 66))
		table.insert(wings, { root = root, tip = tip, side = side })
	end
	model.PrimaryPart = body
	model.Parent = parent
	return { model = model, body = body, wings = wings, center = center, radius = radius, height = height, speed = speed, phase = phase, flap = math.random() * 10 }
end

local function poseGull(g: Gull, t: number)
	local a = g.phase + t * g.speed / g.radius
	local wob = math.sin(t * 0.37 + g.phase) * 6
	local pos = g.center + Vector3.new(math.cos(a) * g.radius, g.height + wob + math.sin(t * 0.9 + g.phase) * 1.5, math.sin(a) * g.radius)
	local ahead = g.center + Vector3.new(math.cos(a + 0.05) * g.radius, g.height + wob, math.sin(a + 0.05) * g.radius)
	local bank = math.rad(-22)
	local cf = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, bank)
	-- flap in bursts, then glide with wings held out
	local cycle = (t + g.flap) % 6
	local flapping = cycle < 2.2
	local wingAngle = if flapping then math.sin(t * 11 + g.flap) * math.rad(38) else math.rad(6 + math.sin(t * 1.3) * 3)
	g.body.CFrame = cf
	local head = g.model:FindFirstChild("Head") :: BasePart
	local beak = g.model:FindFirstChild("Beak") :: BasePart
	local tail = g.model:FindFirstChild("Tail") :: BasePart
	head.CFrame = cf * CFrame.new(0, 0.25, -1.0)
	beak.CFrame = cf * CFrame.new(0, 0.2, -1.4)
	tail.CFrame = cf * CFrame.new(0, 0.05, 1.05)
	for _, w in g.wings do
		local s = w.side
		local shoulder = cf * CFrame.new(s * 0.3, 0.12, -0.1)
		local rootCF = shoulder * CFrame.Angles(0, 0, s * wingAngle) * CFrame.new(s * 0.7, 0, 0)
		w.root.CFrame = rootCF
		local elbow = rootCF * CFrame.new(s * 0.7, 0, 0)
		w.tip.CFrame = elbow * CFrame.Angles(0, s * math.rad(12), s * wingAngle * 0.6) * CFrame.new(s * 0.7, 0, 0.1)
	end
end

---------------------------------------------------------------------------
-- Leaping fish (a small silver fish arcs out of the water with a splash)
---------------------------------------------------------------------------
local function splash(at: Vector3, parent: Instance)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.5, 0.2, 0.5)
	p.Position = at
	p.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(Color3.fromRGB(230, 236, 240))
	e.LightInfluence = 1
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -18, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	e:Emit(14)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

local function leapFish(from: Vector3, parent: Instance)
	local fish = Instance.new("Part")
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.Shape = Enum.PartType.Ball
	fish.Size = Vector3.new(0.35, 0.55, 1.5)
	fish.Material = Enum.Material.Metal
	fish.Color = Color3.fromRGB(176, 186, 196)
	fish.Reflectance = 0.2
	fish.Parent = parent
	local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	local dist = 5 + math.random() * 4
	local h = 2.5 + math.random() * 1.8
	local dur = 0.9
	splash(from, parent)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		if k >= 1 then
			conn:Disconnect()
			splash(from + dir * dist, parent)
			fish:Destroy()
			return
		end
		local pos = from + dir * dist * k + Vector3.new(0, 4 * h * k * (1 - k), 0)
		local vel = dir * dist + Vector3.new(0, 4 * h * (1 - 2 * k), 0)
		fish.CFrame = CFrame.lookAt(pos, pos + vel) * CFrame.Angles(0, 0, math.sin(k * 20) * 0.4)
	end)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
type Ui = {
	gui: ScreenGui,
	aboard: Frame,
	aboardTitle: TextLabel,
	aboardInfo: TextLabel,
	leave: TextButton,
	change: TextButton,
	picker: Frame,
	pickerInfo: TextLabel,
	sizes: { TextButton },
	fade: Frame,
	fadeText: TextLabel,
	hint: TextLabel,
}

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, font: Enum.Font, maxSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Color3.fromRGB(255, 240, 210)
	l.TextStrokeColor3 = Color3.fromRGB(20, 14, 10)
	l.TextStrokeTransparency = 0.4
	l.ZIndex = 3
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	l.Parent = parent
	return l
end

local function makeUi(): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	-- title plate and a hint
	local title = Instance.new("ImageLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Image = Config.UI.Title
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 52)
	title.Size = UDim2.fromScale(0.34, 0.34 * 239 / 1024)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1024 / 239
	aspect.Parent = title
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(460, 108)
	maxSize.Parent = title
	title.Parent = gui
	local hint = label(gui, "Step onto an empty boat to start a party (1-4 sailors), or join one with room", UDim2.new(0.7, 0, 0, 26), UDim2.new(0.15, 0, 0, 162), Enum.Font.GothamBold, 20)
	hint.TextTransparency = 0.05
	-- aboard panel (bottom centre)
	local aboard = Instance.new("Frame")
	aboard.Name = "Aboard"
	aboard.AnchorPoint = Vector2.new(0.5, 1)
	aboard.Position = UDim2.new(0.5, 0, 1, -28)
	aboard.Size = UDim2.new(0, 430, 0, 150)
	aboard.BackgroundTransparency = 1
	aboard.Visible = false
	UISkin.panel(aboard)
	local aboardTitle = label(aboard, "BOAT 1", UDim2.new(0.86, 0, 0, 34), UDim2.new(0.07, 0, 0, 14), Enum.Font.GothamBlack, 30, Color3.fromRGB(255, 214, 120))
	local aboardInfo = label(aboard, "", UDim2.new(0.86, 0, 0, 26), UDim2.new(0.07, 0, 0, 50), Enum.Font.GothamBold, 22)
	local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, maxText: number): TextButton
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = pos
		b.Size = size
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.TextScaled = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxText
		c.Parent = b
		b.ZIndex = 3
		b.Parent = parent
		UISkin.button(b)
		return b
	end
	local leave = button(aboard, "Leave boat", UDim2.new(0, 170, 0, 48), UDim2.new(0.5, -92, 0, 86), 22)
	leave.Name = "Leave"
	local change = button(aboard, "Party size", UDim2.new(0, 170, 0, 48), UDim2.new(0.5, 92, 0, 86), 22)
	change.Name = "ChangeSize"
	aboard.Parent = gui
	-- the big PLAY button: hop into a party that has room, or take a free boat
	local play = Instance.new("TextButton")
	play.Name = "Play"
	play.AnchorPoint = Vector2.new(0.5, 1)
	play.Position = UDim2.new(0.5, 0, 1, -30)
	play.Size = UDim2.fromOffset(300, 84)
	play.BackgroundColor3 = Color3.fromRGB(86, 196, 96)
	play.AutoButtonColor = true
	play.Font = Enum.Font.GothamBlack
	play.Text = "PLAY"
	play.TextScaled = true
	play.TextColor3 = Color3.new(1, 1, 1)
	play.TextStrokeColor3 = Color3.fromRGB(14, 46, 18)
	play.TextStrokeTransparency = 0
	play.ZIndex = 4
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 12)
	playCorner.Parent = play
	local playStroke = Instance.new("UIStroke")
	playStroke.Color = Color3.fromRGB(20, 40, 18)
	playStroke.Thickness = 4
	playStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playStroke.Parent = play
	local playGrad = Instance.new("UIGradient")
	playGrad.Rotation = 90
	playGrad.Color = ColorSequence.new(Color3.fromRGB(170, 255, 160), Color3.fromRGB(90, 170, 80))
	playGrad.Parent = play
	local playPad = Instance.new("UIPadding")
	playPad.PaddingTop = UDim.new(0, 12)
	playPad.PaddingBottom = UDim.new(0, 10)
	playPad.Parent = play
	local playScale = Instance.new("UIScale")
	playScale.Parent = play
	play.Parent = gui
	-- party picker (the boat's leader): how many sailors?
	local picker = Instance.new("Frame")
	picker.Name = "PartyPicker"
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.fromScale(0.5, 0.5)
	picker.Size = UDim2.new(0, 520, 0, 250)
	picker.BackgroundTransparency = 1
	picker.Visible = false
	UISkin.panel(picker)
	label(picker, "CREATE YOUR PARTY", UDim2.new(0.86, 0, 0, 36), UDim2.new(0.07, 0, 0, 18), Enum.Font.GothamBlack, 32, Color3.fromRGB(255, 214, 120))
	local pickerInfo = label(picker, "How many sailors on this boat?", UDim2.new(0.86, 0, 0, 24), UDim2.new(0.07, 0, 0, 58), Enum.Font.GothamBold, 21)
	local sizes: { TextButton } = {}
	for n = 1, Config.Lobby.PartySize do
		local x = (n - (Config.Lobby.PartySize + 1) / 2) * 112
		local b = button(picker, if n == 1 then "Solo" else tostring(n), UDim2.new(0, 100, 0, 72), UDim2.new(0.5, x, 0, 100), 30)
		b.Name = "Size" .. n
		table.insert(sizes, b)
	end
	local note = label(picker, "Others can join until it's full, then you set sail.", UDim2.new(0.86, 0, 0, 20), UDim2.new(0.07, 0, 0, 190), Enum.Font.Gotham, 17, Color3.fromRGB(200, 210, 225))
	note.Name = "Note"
	picker.Parent = gui
	-- fade to black when your boat leaves
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.ZIndex = 20
	fade.Parent = gui
	local fadeText = label(fade, "Rowing out to the lighthouse...", UDim2.new(0.8, 0, 0, 40), UDim2.new(0.1, 0, 0.48, 0), Enum.Font.GothamBold, 30)
	fadeText.ZIndex = 21
	fadeText.TextTransparency = 1
	fadeText.TextStrokeTransparency = 1
	gui.Parent = player:WaitForChild("PlayerGui")
	keep(gui)
	return {
		gui = gui,
		aboard = aboard,
		play = play,
		playScale = playScale,
		aboardTitle = aboardTitle,
		aboardInfo = aboardInfo,
		leave = leave,
		change = change,
		picker = picker,
		pickerInfo = pickerInfo,
		sizes = sizes,
		fade = fade,
		fadeText = fadeText,
		hint = hint,
	}
end

-- Sign over each boat: name, sailors aboard (as lamp dots) and the countdown
type Sign = { gui: BillboardGui, title: TextLabel, count: TextLabel, time: TextLabel, dots: { Frame } }
local function makeSign(boat: Model): Sign?
	local board = boat:FindFirstChild("Sign")
	if not (board and board:IsA("BasePart")) then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "BoatSign"
	bb.Size = UDim2.fromScale(8, 3.9) -- studs, so it shrinks with distance like a real sign
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.MaxDistance = 110
	bb.LightInfluence = 0
	bb.Adornee = board
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundTransparency = 1
	back.Parent = bb
	UISkin.panel(back)
	local number = boat:GetAttribute("Number") or 1
	local title = label(back, `BOAT {number}`, UDim2.fromScale(0.8, 0.26), UDim2.fromScale(0.1, 0.1), Enum.Font.GothamBlack, 60, Color3.fromRGB(255, 214, 120))
	local count = label(back, "Free boat", UDim2.fromScale(0.8, 0.18), UDim2.fromScale(0.1, 0.37), Enum.Font.GothamBold, 44)
	local time = label(back, "Step aboard to start a party", UDim2.fromScale(0.8, 0.15), UDim2.fromScale(0.1, 0.56), Enum.Font.Gotham, 36, Color3.fromRGB(200, 210, 225))
	local dots = {}
	for i = 1, Config.Lobby.PartySize do
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0)
		d.Size = UDim2.fromScale(0.13, 0.13)
		d.SizeConstraint = Enum.SizeConstraint.RelativeYY
		d.Position = UDim2.fromScale(0.5 + (i - (Config.Lobby.PartySize + 1) / 2) * 0.1, 0.75)
		d.BackgroundColor3 = Color3.fromRGB(60, 56, 50)
		d.BorderSizePixel = 0
		d.ZIndex = 3
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = d
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(196, 150, 70)
		stroke.Thickness = 1.5
		stroke.Parent = d
		d.Parent = back
		table.insert(dots, d)
	end
	bb.Parent = player:WaitForChild("PlayerGui")
	keep(bb)
	return { gui = bb, title = title, count = count, time = time, dots = dots }
end

---------------------------------------------------------------------------
-- Start / stop
---------------------------------------------------------------------------
function LobbyController.Start()
	local lobby = Workspace:WaitForChild("Lobby")
	dusk()
	local ui = makeUi()
	local fx = Instance.new("Folder")
	fx.Name = "LobbyLife"
	fx.Parent = Workspace
	keep(fx)

	-- ambience
	local waves = Instance.new("Sound")
	waves.Name = "LobbyWaves"
	waves.SoundId = SOUND.Waves
	waves.Looped = true
	waves.Volume = 0.45
	waves.Parent = SoundService
	waves:Play()
	keep(waves)
	local gulls = Instance.new("Sound")
	gulls.Name = "LobbyGulls"
	gulls.SoundId = SOUND.Gulls
	gulls.Looped = true
	gulls.Volume = 0.18
	gulls.Parent = SoundService
	gulls:Play()
	keep(gulls)

	-- collect what moves
	type BoatInfo = { model: Model, base: CFrame, offsets: { [BasePart]: CFrame }, phase: number, sign: Sign?, castAt: number }
	local boats: { BoatInfo } = {}
	local boatFolder = lobby:WaitForChild("Boats")
	for _, m in boatFolder:GetChildren() do
		if m:IsA("Model") then
			local hull = m:FindFirstChild("Hull")
			if hull and hull:IsA("BasePart") then
				local base = hull.CFrame
				local offsets = {}
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") and p.Name ~= "Zone" and p.Name ~= "Exit" and p.Name ~= "Sign" and p.Name ~= "Gangplank" then
						offsets[p] = base:ToObjectSpace(p.CFrame)
					end
				end
				table.insert(boats, { model = m, base = base, offsets = offsets, phase = math.random() * 10, sign = makeSign(m), castAt = 0 })
			end
		end
	end
	type Swing = { model: Model, pivot: Vector3, offsets: { [BasePart]: CFrame }, phase: number }
	local swings: { Swing } = {}
	local flickers: { { light: PointLight, base: number, phase: number, part: BasePart } } = {}
	local buoys: { { model: Model, base: Vector3, offsets: { [BasePart]: CFrame }, phase: number } } = {}
	local blinkers: { { part: BasePart, phase: number } } = {}
	for _, d in lobby:GetDescendants() do
		if d:IsA("Model") and d.Name == "Lantern" then
			local pivot = d:GetAttribute("Pivot")
			if typeof(pivot) == "Vector3" then
				local offsets = {}
				for _, p in d:GetChildren() do
					if p:IsA("BasePart") then
						offsets[p] = CFrame.new(pivot):ToObjectSpace(p.CFrame)
					end
				end
				table.insert(swings, { model = d, pivot = pivot, offsets = offsets, phase = math.random() * 10 })
			end
		elseif d:IsA("Model") and d.Name == "Buoy" then
			local base = d:GetAttribute("Base")
			local body = d.PrimaryPart
			if typeof(base) == "Vector3" and body then
				local offsets = {}
				for _, p in d:GetChildren() do
					if p:IsA("BasePart") then
						offsets[p] = body.CFrame:ToObjectSpace(p.CFrame)
					end
				end
				table.insert(buoys, { model = d, base = base, offsets = offsets, phase = math.random() * 10 })
			end
		elseif d:IsA("PointLight") and d.Parent and d.Parent:IsA("BasePart") and typeof(d.Parent:GetAttribute("Flicker")) == "number" then
			table.insert(flickers, { light = d, base = d.Parent:GetAttribute("Flicker") :: number, phase = math.random() * 100, part = d.Parent :: BasePart })
		elseif d:IsA("BasePart") and typeof(d:GetAttribute("Blink")) == "number" then
			table.insert(blinkers, { part = d, phase = d:GetAttribute("Blink") :: number })
		end
	end
	local pads: { BasePart } = {}
	for _, d in lobby:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "PadGlow" then
			table.insert(pads, d)
		end
	end
	local bell = lobby:FindFirstChild("Bell", true) :: BasePart?
	local bellBase = if bell then bell.CFrame else CFrame.new()
	local beamRig = lobby:FindFirstChild("BeamRig", true) :: BasePart?
	local beamBase = if beamRig then beamRig.CFrame else CFrame.new()

	-- gulls circling over the harbor and out over the water
	local L = Config.Lobby.Center
	local flock: { Gull } = {}
	for i = 1, 6 do
		local c = L + Vector3.new(-20 - math.random() * 90, 0, (math.random() - 0.5) * 120)
		table.insert(flock, makeGull(c, 25 + math.random() * 40, 22 + math.random() * 18, 14 + math.random() * 6, math.random() * 6.28, fx))
	end
	local nextFish = os.clock() + 3

	-- passengers being carried by a departing boat: character -> offset from the hull
	local carried: { [Model]: { boat: BoatInfo, offset: CFrame } } = {}
	local myCastOff = 0
	local pickerOpen = false -- the leader pressed "Party size" to change it

	local function boatCFrame(b: BoatInfo, t: number, clock: number): CFrame
		-- rocking at the mooring
		local bob = math.sin(clock * 1.1 + b.phase) * 0.18 + math.sin(clock * 0.53 + b.phase * 2) * 0.1
		local roll = math.sin(clock * 0.8 + b.phase) * math.rad(2.2)
		local pitch = math.sin(clock * 0.6 + b.phase * 1.7) * math.rad(1.2)
		local cf = b.base * CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, roll)
		if b.castAt > 0 then
			-- row out: ease away from the dock, swing the bow out to sea, keep going into the mist
			local s = math.max(0, t - b.castAt)
			local out = 0.5 * 2.2 * math.min(s, 3) ^ 2 / 3 + math.max(0, s - 3) * 4.4
			local turn = smoothstep(s / 4) * math.rad(if b.base.Position.Z < Config.Lobby.Center.Z then 14 else -14)
			cf = cf * CFrame.new(0, 0, -out) * CFrame.Angles(0, turn, 0)
			-- in its last seconds it sinks out of sight into the fog, then reappears at the dock
			if s > 11 then
				cf = cf * CFrame.new(0, -(s - 11) * 3, 0)
			end
		end
		return cf
	end

	-- boat attributes -> signs, panel and cast-off
	local function refresh()
		local mine = player:GetAttribute("Boat")
		local shown = false
		local picking = false
		for _, b in boats do
			local m = b.model
			local count = (m:GetAttribute("Count") or 0) :: number
			local leaves = (m:GetAttribute("LeavesAt") or 0) :: number
			local castAt = (m:GetAttribute("CastOffAt") or 0) :: number
			local cap = (m:GetAttribute("Capacity") or 0) :: number -- 0: the leader is still choosing
			local leader = (m:GetAttribute("Leader") or 0) :: number
			local leaderName = (m:GetAttribute("LeaderName") or "") :: string
			local left = math.max(0, math.ceil(leaves - now()))
			local need = math.max(0, cap - count)
			if b.sign then
				local sign = b.sign
				if castAt > 0 then
					sign.count.Text = `Party of {cap}`
					sign.time.Text = "Casting off!"
				elseif leader == 0 then
					sign.count.Text = "Free boat"
					sign.time.Text = "Step aboard to start a party"
				elseif cap == 0 then
					sign.count.Text = `{leaderName}'s boat`
					sign.time.Text = "Choosing the party size..."
				else
					sign.count.Text = `Party of {cap}  ·  {count}/{cap} aboard`
					sign.time.Text = if leaves > 0 then `Sets sail in {left}s` elseif need == 1 then "Room for 1 more!" else `Room for {need} more!`
				end
				-- one lamp per seat in the party; lit when taken
				local seats = if cap > 0 then cap else Config.Lobby.PartySize
				for i, d in sign.dots do
					d.Visible = i <= seats
					d.Position = UDim2.fromScale(0.5 + (i - (seats + 1) / 2) * 0.1, 0.75)
					d.BackgroundColor3 = if i <= count then Color3.fromRGB(255, 196, 90) else Color3.fromRGB(60, 56, 50)
				end
			end
			if mine == m.Name then
				shown = true
				local isLeader = leader == player.UserId
				local number = m:GetAttribute("Number") or ""
				if cap == 0 then
					ui.aboardTitle.Text = `BOAT {number}`
					ui.aboardInfo.Text = if isLeader then "Choose how many sailors" else `{leaderName} is choosing the party size`
				else
					ui.aboardTitle.Text = `BOAT {number}  ·  {count}/{cap} aboard`
					ui.aboardInfo.Text = if castAt > 0
						then "Casting off!"
						elseif leaves > 0 then `Setting sail in {left}s`
						elseif need == 1 then "Waiting for 1 more sailor..."
						else `Waiting for {need} more sailors...`
				end
				ui.leave.Visible = castAt == 0
				-- the leader can change the size until the boat leaves
				ui.change.Visible = isLeader and castAt == 0 and cap > 0
				ui.leave.Position = if ui.change.Visible then UDim2.new(0.5, -92, 0, 86) else UDim2.new(0.5, 0, 0, 86)
				if isLeader and castAt == 0 and (cap == 0 or pickerOpen) then
					picking = true
					ui.pickerInfo.Text = if cap == 0 then "How many sailors on this boat?" else `Change the party size ({count} aboard now)`
					for n, btn in ui.sizes do
						local ok = n >= count
						btn.Active = ok
						btn.AutoButtonColor = false
						local lbl = btn:FindFirstChild("Label")
						if lbl and lbl:IsA("TextLabel") then
							lbl.TextTransparency = if ok then 0 else 0.6
						end
					end
				end
			end
			-- a boat starting to cast off
			if castAt > 0 and b.castAt == 0 then
				b.castAt = castAt
				-- carry everyone listed as aboard
				local ids = string.split((m:GetAttribute("Passengers") or "") :: string, ",")
				for _, id in ids do
					local p = Players:GetPlayerByUserId(tonumber(id) or 0)
					local character = p and p.Character
					if character then
						task.delay(0.3, function()
							-- the server seats them first; then they ride along
							local hull = m:FindFirstChild("Hull") :: BasePart
							carried[character] = { boat = b, offset = hull.CFrame:ToObjectSpace(character:GetPivot()) }
						end)
					end
					if p == player then
						myCastOff = castAt
					end
				end
			elseif castAt == 0 and b.castAt > 0 then
				-- back at the dock: let go of anyone still carried
				for character, c in carried do
					if c.boat == b then
						carried[character] = nil
					end
				end
				b.castAt = 0
			end
		end
		ui.aboard.Visible = shown and not picking
		ui.picker.Visible = picking
		if not picking then
			pickerOpen = false
		end
		ui.hint.Visible = not shown
		ui.play.Visible = not shown and not picking and myCastOff == 0
	end

	table.insert(connections, ui.play.Activated:Connect(function()
		Remotes.event("QuickPlay"):FireServer()
	end))
	table.insert(connections, ui.leave.Activated:Connect(function()
		Remotes.event("LeaveBoat"):FireServer()
	end))
	table.insert(connections, ui.change.Activated:Connect(function()
		pickerOpen = true
		refresh()
	end))
	for n, btn in ui.sizes do
		table.insert(connections, btn.Activated:Connect(function()
			if not btn.Active then
				return
			end
			pickerOpen = false
			Remotes.event("ChooseParty"):FireServer(n)
		end))
	end

	local lastRefresh = 0
	local start = os.clock()
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local clock = os.clock() - start
		local t = now()
		if clock - lastRefresh > 0.1 then
			lastRefresh = clock
			refresh()
		end
		-- boats
		for _, b in boats do
			local cf = boatCFrame(b, t, clock)
			for p, off in b.offsets do
				p.CFrame = cf * off
			end
			if b.castAt > 0 and t - b.castAt > 12 then
				-- out of sight in the fog: hide until it's reset
				for p in b.offsets do
					p.LocalTransparencyModifier = 1
				end
			else
				for p in b.offsets do
					p.LocalTransparencyModifier = 0
				end
			end
		end
		for character, c in carried do
			if character.Parent then
				local hull = c.boat.model:FindFirstChild("Hull") :: BasePart
				character:PivotTo(hull.CFrame * c.offset)
			else
				carried[character] = nil
			end
		end
		-- lanterns swing a little on their hooks
		for _, s in swings do
			local a = math.sin(clock * 1.3 + s.phase) * math.rad(5)
			local b2 = math.sin(clock * 0.9 + s.phase * 1.3) * math.rad(3)
			local cf = CFrame.new(s.pivot) * CFrame.Angles(a, 0, b2)
			for p, off in s.offsets do
				p.CFrame = cf * off
			end
		end
		-- the PLAY button breathes; the boats' boarding pads glow (white: free, gold: room in a party)
		ui.playScale.Scale = 1 + math.sin(clock * 3) * 0.03
		for _, pad in pads do
			local boat = pad.Parent :: Instance
			local count = boat:GetAttribute("Count") or 0
			local cap = boat:GetAttribute("Capacity") or 0
			local free = count == 0
			local room = cap > 0 and count < cap
			pad.Transparency = if free or room then 0.1 + (math.sin(clock * 3.2) * 0.5 + 0.5) * 0.45 else 0.85
			pad.Color = if room then Color3.fromRGB(255, 206, 110) else Color3.fromRGB(255, 240, 214)
		end
		-- flames flicker
		for _, f in flickers do
			local n = math.noise(clock * 3.2, f.phase) * 0.5 + math.noise(clock * 9, f.phase + 7) * 0.2
			f.light.Brightness = f.base * (0.85 + n)
		end
		-- buoys ride the swell and blink
		for _, bu in buoys do
			local bob = math.sin(clock * 1.2 + bu.phase) * 0.35
			local tilt = CFrame.Angles(math.sin(clock * 0.9 + bu.phase) * math.rad(8), 0, math.cos(clock * 0.7 + bu.phase) * math.rad(8))
			local cf = CFrame.new(bu.base + Vector3.new(0, bob, 0)) * tilt
			for p, off in bu.offsets do
				p.CFrame = cf * off
			end
		end
		for _, bl in blinkers do
			bl.part.Transparency = if ((clock + bl.phase) % 3) < 0.4 then 0 else 0.85
		end
		-- the bell sways in the breeze
		if bell then
			bell.CFrame = bellBase * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.sin(clock * 1.6) * math.rad(6), 0, 0) * CFrame.new(0, -0.9, 0)
		end
		-- the far lighthouse beam turns
		if beamRig then
			beamRig.CFrame = beamBase * CFrame.Angles(0, clock * math.rad(28), 0)
		end
		-- gulls
		for _, g in flock do
			poseGull(g, clock)
		end
		-- now and then a fish jumps near the dock
		if os.clock() > nextFish then
			nextFish = os.clock() + 4 + math.random() * 7
			local spot = L + Vector3.new(-10 - math.random() * 70, 0.2, (math.random() - 0.5) * 70)
			leapFish(spot, fx)
		end
		-- my boat is leaving: fade out on the way
		if myCastOff > 0 then
			local s = t - myCastOff
			local k = smoothstep((s - 1.8) / (Config.Lobby.CastOffSeconds - 1.9))
			ui.fade.BackgroundTransparency = 1 - k
			ui.fadeText.TextTransparency = 1 - smoothstep((s - 2.2) / 1.2)
			ui.fadeText.TextStrokeTransparency = 0.4 + 0.6 * (1 - smoothstep((s - 2.2) / 1.2))
		end
	end))
	-- keep the gull calls varied
	task.spawn(function()
		while gulls.Parent do
			task.wait(6)
			TweenService:Create(gulls, TweenInfo.new(4), { Volume = 0.08 + math.random() * 0.18 }):Play()
		end
	end)
end

function LobbyController.Stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, inst in made do
		inst:Destroy()
	end
	table.clear(made)
	for i = #restore, 1, -1 do
		restore[i]()
	end
	table.clear(restore)
end

return LobbyController
