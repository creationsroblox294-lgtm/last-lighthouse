--!strict
-- Cursed Storm (Catastrophic): the sky goes a bruised violet-green, a vast sigil (Blender) turns
-- slowly over the island, ash drifts UP, and green lightning flickers with no thunder. Out over
-- the sea a giant eye (Blender: sclera, slit iris, lid) hangs in the sky (Workspace "CursedEye");
-- it blinks, and its pupil follows YOU wherever you go. Each curse (StormEvent "Curse") is
-- announced in dripping letters and changes everything:
--   Hands   black clawed hands (Blender) claw up out of the ground around you; stand still and
--           they get you (StormEvent "Grabbed": you're slowed and the edges go black)
--   Float   gravity gives out (set here too, for your own physics); stones and leaves lift
--   Choke   the lamp's light turns a sickly green
--   Doubles / Keeper   the sky flashes and something new is on the island
--   Gaze    the eye fixes on one person: a green shaft of light pins them wherever they run; if
--           it burns them (StormEvent "GazeHit") the shaft flares
-- Textures: Blender (Cursed: sclera, iris, lid, hand, sigil) + Ember Storm ember, Rolling
-- Thunder smoke, Silent Fog vignette, Hurricane leaf.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local GREEN = Color3.fromRGB(110, 255, 140)
local VIOLET = Color3.fromRGB(150, 80, 200)
local EYE_SIZE = 1100

local TITLES = {
	Hands = "THE GROUND IS HUNGRY",
	Float = "THE SKY IS FALLING UP",
	Choke = "THE LAMP IS CHOKING",
	Doubles = "WHO IS THAT?",
	Keeper = "THE LAST KEEPER WALKS",
	Gaze = "IT SEES YOU",
}

return function(ctx: Common.Ctx)
	local player = Players.LocalPlayer
	local rnd = Random.new()
	local c = Config.World.IslandCenter

	Common.clouds(ctx, { Cover = 0.85, Density = 0.6, Color = Color3.fromRGB(80, 50, 95) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 235, 215),
		Saturation = -0.25,
		Brightness = -0.03,
		Contrast = 0.3,
		Bloom = 0.8,
		BloomThreshold = 1,
	})
	local flashGrade = Instance.new("ColorCorrectionEffect")
	flashGrade.Name = "CursedFlash"
	flashGrade.Parent = Lighting
	table.insert(ctx.cleanup, function()
		Common.tween(flashGrade, 1, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		task.delay(Common.FADE + 0.5, function()
			flashGrade:Destroy()
		end)
	end)
	local function flash(color: Color3, amount: number)
		flashGrade.TintColor = Color3.new(1, 1, 1):Lerp(color, 0.6)
		flashGrade.Brightness = amount
		Common.tween(flashGrade, 0.6, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	end

	-- ash drifting up
	local ash = Common.around(ctx, "Ash", Vector3.new(140, 30, 140), {
		Texture = Common.tex(ctx, "Ember"),
		Rate = 60,
		Size = ns(0, 0.25, 1, 0.1),
		Color = ColorSequence.new(GREEN, VIOLET),
		LightEmission = 0.8,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(2, 5),
		Spread = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 1.5, 0),
		Offset = Vector3.new(0, -12, 0),
	})
	ash.EmissionDirection = Enum.NormalId.Top

	-- the sigil overhead
	local sigil = Common.part(ctx, "Sigil", Vector3.new(1000, 1, 1000))
	sigil.CFrame = CFrame.new(c.X, 420, c.Z)
	local sgui = Instance.new("SurfaceGui")
	sgui.Face = Enum.NormalId.Bottom
	sgui.CanvasSize = Vector2.new(1024, 1024)
	sgui.LightInfluence = 0
	sgui.Brightness = 2.5
	sgui.Parent = sigil
	local simg = Instance.new("ImageLabel")
	simg.BackgroundTransparency = 1
	simg.AnchorPoint = Vector2.new(0.5, 0.5)
	simg.Position = UDim2.fromScale(0.5, 0.5)
	simg.Size = UDim2.fromScale(1, 1)
	simg.Image = Common.tex(ctx, "Sigil")
	simg.ImageColor3 = GREEN
	simg.ImageTransparency = 1
	simg.Parent = sgui
	Common.tween(simg, 8, { ImageTransparency = 0.25 })
	table.insert(ctx.cleanup, function()
		Common.tween(simg, Common.FADE, { ImageTransparency = 1 })
	end)

	-- the eye
	local eyePart = Common.part(ctx, "Eye", Vector3.one)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(EYE_SIZE, EYE_SIZE / 2)
	board.LightInfluence = 0
	board.Brightness = 1.6
	board.MaxDistance = math.huge
	board.Parent = eyePart
	local lidFrame = Instance.new("Frame") -- squashed for blinks
	lidFrame.BackgroundTransparency = 1
	lidFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	lidFrame.Position = UDim2.fromScale(0.5, 0.5)
	lidFrame.Size = UDim2.fromScale(1, 0)
	lidFrame.ClipsDescendants = false
	lidFrame.Parent = board
	local function img(id: string, z: number): ImageLabel
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.AnchorPoint = Vector2.new(0.5, 0.5)
		i.Position = UDim2.fromScale(0.5, 0.5)
		i.Size = UDim2.fromScale(1, 2) -- the textures are square; the eye is half as tall as wide
		i.Image = id
		i.ZIndex = z
		i.Parent = lidFrame
		return i
	end
	img(Common.tex(ctx, "Sclera"), 1)
	local iris = img(Common.tex(ctx, "Iris"), 2)
	iris.Size = UDim2.fromScale(0.33, 0.66)
	img(Common.tex(ctx, "Lid"), 3)
	local opened = false
	local nextBlink = os.clock() + 8

	-- hands
	type Hand = { part: BasePart, gui: BillboardGui, t0: number, base: Vector3, sway: number }
	local hands: { Hand } = {}
	local handsUntil = 0
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = { Workspace.Terrain, Workspace:FindFirstChild("Map") or Workspace.Terrain }
	local function raiseHand(near: Vector3, r: number)
		local a = rnd:NextNumber(0, math.pi * 2)
		local at = near + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local hit = Workspace:Raycast(at + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), probe)
		if not hit or hit.Material == Enum.Material.Water then
			return
		end
		local p = Common.part(ctx, "Hand", Vector3.one)
		p.CFrame = CFrame.new(hit.Position)
		local b = Instance.new("BillboardGui")
		b.Size = UDim2.fromScale(3.2, 3.2)
		b.StudsOffsetWorldSpace = Vector3.new(0, -1.6, 0)
		b.LightInfluence = 0
		b.Brightness = 1.4
		b.Parent = p
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.Size = UDim2.fromScale(1, 1)
		i.Image = Common.tex(ctx, "Hand")
		i.ImageColor3 = Color3.fromRGB(205, 170, 235)
		i.Rotation = rnd:NextNumber(-25, 25)
		i.Parent = b
		table.insert(hands, { part = p, gui = b, t0 = os.clock(), base = hit.Position, sway = rnd:NextNumber(0, 6) })
	end

	-- float: things lifting off the ground
	local floaters = Common.around(ctx, "Floaters", Vector3.new(80, 2, 80), {
		Texture = Common.tex(ctx, "Leaf"),
		Rate = 0,
		Size = ns(0, 0.8, 1, 0.6),
		Color = ColorSequence.new(Color3.fromRGB(90, 80, 70)),
		LightEmission = 0,
		LightInfluence = 1,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(2, 5),
		Spread = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 3, 0),
		Offset = Vector3.new(0, -3, 0),
	})
	floaters.EmissionDirection = Enum.NormalId.Top
	local floatUntil = 0
	local gravityWas: number? = nil

	-- choke: the beam turns sick green
	local chokeUntil = 0
	local lv = Workspace:FindFirstChild("LightVisuals")
	local beamPart = lv and lv:FindFirstChild("Beam")
	local beamWas = beamPart and beamPart:IsA("BasePart") and beamPart.Color
	local spot = beamPart and beamPart:FindFirstChildOfClass("SpotLight")
	local spotWas = spot and spot.Color
	local greened = false
	local function setGreen(on: boolean)
		if on == greened then
			return
		end
		greened = on
		if beamPart and beamPart:IsA("BasePart") and beamWas then
			Common.tween(beamPart, 1, { Color = if on then GREEN else beamWas })
		end
		if spot and spotWas then
			Common.tween(spot, 1, { Color = if on then GREEN else spotWas })
		end
	end

	-- gaze: a shaft of green light pinned on someone
	local shaft = Instance.new("Part")
	shaft.Name = "GazeShaft"
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.CanTouch = false
	shaft.CastShadow = false
	shaft.Material = Enum.Material.Neon
	shaft.Color = GREEN
	shaft.Transparency = 1
	shaft.Size = Vector3.new(400, 14, 14)
	shaft.Parent = ctx.folder
	local ring = Instance.new("Part")
	ring.Name = "GazeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = GREEN
	ring.Transparency = 1
	ring.Size = Vector3.new(0.3, 18, 18)
	ring.Parent = ctx.folder
	local gazeUid: number? = nil
	local gazeUntil, gazeT0 = 0, 0

	-- the screen: dripping titles, and black edges when the hands have you or the eye does
	local gui = Instance.new("ScreenGui")
	gui.Name = "CursedScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local edge = Instance.new("ImageLabel")
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Image = Common.tex(ctx, "Vignette")
	edge.ImageColor3 = Color3.new(0, 0, 0)
	edge.ImageTransparency = 1
	edge.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.32)
	title.Size = UDim2.fromScale(0.9, 0.12)
	title.Font = Enum.Font.Creepster
	title.TextScaled = true
	title.TextColor3 = GREEN
	title.TextStrokeColor3 = Color3.fromRGB(20, 0, 25)
	title.TextStrokeTransparency = 0.2
	title.TextTransparency = 1
	title.Text = ""
	title.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(edge, 1, { ImageTransparency = 1 })
		Common.tween(title, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)
	local titleAt = -100
	local grabbedAt = -100
	local shake = 0

	local function announce(kind: string)
		title.Text = TITLES[kind] or "..."
		title.TextColor3 = if kind == "Gaze" or kind == "Keeper" then Color3.fromRGB(255, 60, 60) else GREEN
		titleAt = os.clock()
		flash(if kind == "Gaze" then Color3.fromRGB(255, 80, 80) else GREEN, 0.35)
		shake = math.max(shake, 0.5)
	end

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Curse" and typeof(data.kind) == "string" then
			local seconds = if typeof(data.seconds) == "number" then data.seconds else 6
			announce(data.kind)
			if data.kind == "Hands" then
				handsUntil = os.clock() + seconds
			elseif data.kind == "Float" then
				floatUntil = os.clock() + seconds
				if not gravityWas then
					gravityWas = Workspace.Gravity
				end
				Workspace.Gravity = if typeof(data.gravity) == "number" then data.gravity else 26
			elseif data.kind == "Choke" then
				chokeUntil = os.clock() + seconds
			elseif data.kind == "Gaze" and typeof(data.uid) == "number" then
				gazeUid = data.uid
				gazeT0 = os.clock()
				gazeUntil = os.clock() + seconds
			end
		elseif kind == "Grabbed" then
			grabbedAt = os.clock()
		elseif kind == "GazeHit" then
			shaft.Size = Vector3.new(400, 30, 30)
			shaft.Transparency = 0.1
			if data.uid == player.UserId then
				flash(Color3.fromRGB(120, 255, 120), 0.8)
				shake = 1
			end
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
		setGreen(false)
		if gravityWas then
			Workspace.Gravity = gravityWas
			gravityWas = nil
		end
		for _, h in hands do
			h.part:Destroy()
		end
		table.clear(hands)
	end)

	local nextBolt = os.clock() + 4
	local walkWas: number? = nil
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local now = os.clock()
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character and character:FindFirstChildOfClass("Humanoid")

		-- sigil turns
		sigil.CFrame = CFrame.new(c.X, 420, c.Z) * CFrame.Angles(0, now * 0.05, 0)

		-- the eye
		local eyeAt = Workspace:GetAttribute("CursedEye") :: Vector3?
		if eyeAt then
			eyePart.CFrame = CFrame.new(eyeAt)
			if not opened and ramp > 0.3 then
				opened = true
				Common.tween(lidFrame, 3, { Size = UDim2.fromScale(1, 1) })
			end
			if opened and now >= nextBlink then
				nextBlink = now + rnd:NextNumber(4, 9)
				task.spawn(function()
					Common.tween(lidFrame, 0.12, { Size = UDim2.fromScale(1, 0.04) })
					task.wait(0.16)
					Common.tween(lidFrame, 0.18, { Size = UDim2.fromScale(1, 1) })
				end)
			end
			-- the pupil follows you (or whoever it's fixed on)
			local look: Vector3? = if root then root.Position else nil
			if gazeUid and now < gazeUntil then
				local victim = Players:GetPlayerByUserId(gazeUid)
				local vr = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
				if vr and vr:IsA("BasePart") then
					look = vr.Position
				end
			end
			if look and camera then
				local d = look - eyeAt
				local right = camera.CFrame.RightVector
				local up = camera.CFrame.UpVector
				local len = math.max(1, d.Magnitude)
				local ox = math.clamp(d:Dot(right) / len * 1.6, -1, 1)
				local oy = math.clamp(-d:Dot(up) / len * 1.6, -1, 1)
				local want = UDim2.fromScale(0.5 + ox * 0.22, 0.5 + oy * 0.12)
				iris.Position = iris.Position:Lerp(want, math.min(1, dt * 3))
			end
			iris.ImageColor3 = if gazeUid and now < gazeUntil then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
		end

		-- green lightning, no thunder
		if now >= nextBolt then
			nextBolt = now + rnd:NextNumber(3, 8)
			flash(GREEN, 0.25)
		end

		-- hands
		if now < handsUntil and ramp > 0 then
			if root and #hands < 10 and rnd:NextNumber() < dt * 8 then
				raiseHand(root.Position, rnd:NextNumber(2.5, 9))
			end
			for _, p in Players:GetPlayers() do
				local pr = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if pr and pr:IsA("BasePart") and #hands < 16 and rnd:NextNumber() < dt * 3 then
					raiseHand(pr.Position, rnd:NextNumber(2.5, 9))
				end
			end
		end
		for i = #hands, 1, -1 do
			local h = hands[i]
			local t = now - h.t0
			local rise = math.clamp(t / 0.8, 0, 1)
			local sink = if now >= handsUntil then math.clamp((now - handsUntil) / 0.8, 0, 1) else 0
			h.gui.StudsOffsetWorldSpace = Vector3.new(math.sin(t * 3 + h.sway) * 0.2, -1.8 + 3.4 * rise * (1 - sink), 0)
			if sink >= 1 or t > 6 then
				h.part:Destroy()
				table.remove(hands, i)
			end
		end
		local grabbed = now - grabbedAt < 0.6
		if hum then
			if grabbed and walkWas == nil then
				walkWas = hum.WalkSpeed
				hum.WalkSpeed = math.min(hum.WalkSpeed, 6)
			elseif not grabbed and walkWas ~= nil then
				hum.WalkSpeed = walkWas
				walkWas = nil
			end
		end

		-- float
		local floating = now < floatUntil
		floaters.Rate = if floating then 50 else 0
		if not floating and gravityWas then
			Workspace.Gravity = gravityWas
			gravityWas = nil
			shake = math.max(shake, 0.6)
		end

		-- choke
		setGreen(now < chokeUntil)

		-- gaze
		local gazing = gazeUid ~= nil and now < gazeUntil
		local mine = false
		if gazing then
			local victim = Players:GetPlayerByUserId(gazeUid :: number)
			local vr = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
			if vr and vr:IsA("BasePart") then
				local k = math.clamp((now - gazeT0) / (gazeUntil - gazeT0), 0, 1)
				local w = 16 - 10 * k
				shaft.Size = Vector3.new(400, w, w)
				shaft.CFrame = CFrame.new(vr.Position + Vector3.new(0, 197, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				shaft.Transparency = 0.75 - 0.4 * k + 0.08 * math.sin(now * 20)
				ring.CFrame = CFrame.new(vr.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				ring.Size = Vector3.new(0.3, w + 4, w + 4)
				ring.Transparency = 0.4
				mine = victim == player
			end
		else
			shaft.Transparency = math.min(1, shaft.Transparency + dt * 1.5)
			ring.Transparency = 1
		end

		-- the screen
		local tt = now - titleAt
		local showTitle = if tt < 0.3 then tt / 0.3 elseif tt < 3 then 1 elseif tt < 4 then 1 - (tt - 3) else 0
		title.TextTransparency = 1 - showTitle
		title.TextStrokeTransparency = 1 - showTitle * 0.8
		title.Position = UDim2.new(0.5, rnd:NextInteger(-3, 3) * showTitle, 0.32, rnd:NextInteger(-2, 2) * showTitle)
		local pulse = 0.5 + 0.5 * math.sin(now * 8)
		local dark = math.max(if grabbed then 0.85 else 0, if mine then 0.5 + 0.35 * pulse else 0)
		edge.ImageTransparency = 1 - dark
		if camera and shake > 0 then
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
			shake = math.max(0, shake - dt)
		end
	end)
	table.insert(ctx.cleanup, function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and walkWas then
			hum.WalkSpeed = walkWas
		end
		walkWas = nil
	end)
end
