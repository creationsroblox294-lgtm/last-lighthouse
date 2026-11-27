--!strict
-- The Deluge (Catastrophic): rain so heavy the air is grey with it, and a flood (Workspace
-- "DelugeLevel") that climbs over the beaches, the meadows, the trees' feet and into the
-- lighthouse. The flood is a murky churning sheet (Blender: flood water) laced with foam that
-- streams out to sea, pocked by the rain, littered with planks, barrels and crates riding the
-- current. Each surge (StormEvent "DelugeSurge") comes in with a rumble. In the flood you float
-- (buoyed on the client) and the current pulls you out; under it the world goes green-brown and
-- muffled, bubbles stream off you and your breath runs down (player attribute "Breath"). When
-- something takes hold of a swimmer (StormEvent "Undertow") the water boils and they're dragged
-- down into the dark.
-- Textures: Blender (Deluge: flood water) + Hurricane drop/streak, Golden Rain ripple/splash,
-- Drizzle bubble/haze, Silent Fog vignette.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local MURK = Color3.fromRGB(70, 82, 60)
local RAIN = Color3.fromRGB(185, 195, 200)
local SHEET = 2400 -- the flood surface follows the camera
local CURRENT = 3.2 -- studs a second, out to sea

return function(ctx: Common.Ctx)
	local player = Players.LocalPlayer
	local rnd = Random.new()
	local c = Config.World.IslandCenter
	local island = Vector3.new(c.X, 0, c.Z)

	Common.clouds(ctx, { Cover = 1, Density = 0.85, Color = Color3.fromRGB(85, 92, 95) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 225, 220),
		Saturation = -0.3,
		Brightness = -0.04,
		Contrast = 0.15,
		Bloom = 0.3,
		BloomThreshold = 1.4,
	})
	local rain = Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 4200,
		Size = ns(0, 0.45, 1, 0.45),
		Squash = ns(0, 2.2, 1, 2.2),
		Brightness = 1.1,
		Color = ColorSequence.new(RAIN),
		Speed = NumberRange.new(100, 120),
		Slant = Vector3.new(8, 0, 4),
	})
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	local veils = Common.around(ctx, "RainVeil", Vector3.new(160, 40, 160), {
		Texture = Common.tex(ctx, "Streak"),
		Rate = 40,
		Size = ns(0, 30, 1, 40),
		Transparency = ns(0, 1, 0.3, 0.75, 0.7, 0.75, 1, 1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(50, 70),
		Color = ColorSequence.new(Color3.fromRGB(190, 200, 205)),
		Offset = Vector3.new(0, 20, 0),
		Acceleration = Vector3.new(0, -40, 0),
		Spread = Vector2.new(10, 10),
		LightEmission = 0,
		LightInfluence = 0.8,
		RotSpeed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 0),
	})
	veils.EmissionDirection = Enum.NormalId.Bottom

	-- the flood
	local sheet = Common.part(ctx, "Flood", Vector3.new(SHEET, 1, SHEET))
	sheet.Material = Enum.Material.SmoothPlastic
	sheet.Color = MURK
	sheet.Reflectance = 0.12
	sheet.Transparency = 1
	local function layer(key: string, size: number, color: Color3): Texture
		local t = Instance.new("Texture")
		t.Texture = Common.tex(ctx, key)
		t.Face = Enum.NormalId.Top
		t.StudsPerTileU = size
		t.StudsPerTileV = size
		t.Color3 = color
		t.Transparency = 1
		t.Parent = sheet
		return t
	end
	local foamBig = layer("Flood", 90, Color3.fromRGB(235, 235, 225))
	local foamSmall = layer("Flood", 34, Color3.fromRGB(210, 215, 205))
	local under = Instance.new("Texture") -- seen from below
	under.Texture = Common.tex(ctx, "Flood")
	under.Face = Enum.NormalId.Bottom
	under.StudsPerTileU = 60
	under.StudsPerTileV = 60
	under.Color3 = Color3.fromRGB(150, 170, 150)
	under.Transparency = 1
	under.Parent = sheet
	-- rain pocking the surface
	local pock = Common.part(ctx, "Pock", Vector3.new(120, 1, 120))
	local rings = Instance.new("ParticleEmitter")
	rings.Texture = Common.tex(ctx, "Ripple")
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rings.EmissionDirection = Enum.NormalId.Top
	rings.Color = ColorSequence.new(Color3.fromRGB(220, 225, 215))
	rings.LightInfluence = 0.7
	rings.Size = ns(0, 0.5, 1, 3.5)
	rings.Transparency = ns(0, 0.3, 1, 1)
	rings.Lifetime = NumberRange.new(0.5, 0.8)
	rings.Speed = NumberRange.new(0.01, 0.01)
	rings.Rate = 0
	rings.Parent = pock
	local splash = Instance.new("ParticleEmitter")
	splash.Texture = Common.tex(ctx, "Splash")
	splash.Color = ColorSequence.new(Color3.fromRGB(220, 225, 220))
	splash.LightInfluence = 0.7
	splash.Size = ns(0, 0.6, 1, 1.4)
	splash.Transparency = ns(0, 0.3, 1, 1)
	splash.Lifetime = NumberRange.new(0.25, 0.4)
	splash.Speed = NumberRange.new(3, 6)
	splash.SpreadAngle = Vector2.new(20, 20)
	splash.Acceleration = Vector3.new(0, -30, 0)
	splash.Rate = 0
	splash.Parent = pock

	-- wreckage riding the flood
	type Junk = { part: BasePart, pos: Vector3, spin: number, bob: number, tilt: CFrame }
	local junk: { Junk } = {}
	local kinds = {
		function(p: Part)
			p.Size = Vector3.new(rnd:NextNumber(6, 10), 0.6, rnd:NextNumber(1.2, 2))
			p.Material = Enum.Material.WoodPlanks
			p.Color = Color3.fromRGB(115, 88, 60)
		end,
		function(p: Part)
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(4, 3.2, 3.2)
			p.Material = Enum.Material.Wood
			p.Color = Color3.fromRGB(95, 70, 45)
		end,
		function(p: Part)
			p.Size = Vector3.new(3.4, 3.4, 3.4)
			p.Material = Enum.Material.WoodPlanks
			p.Color = Color3.fromRGB(140, 110, 70)
		end,
		function(p: Part)
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(16, 1.8, 1.8)
			p.Material = Enum.Material.Wood
			p.Color = Color3.fromRGB(80, 62, 45)
		end,
	}
	local function place(j: Junk, camPos: Vector3, anywhere: boolean)
		local a = rnd:NextNumber(0, math.pi * 2)
		local r = if anywhere then rnd:NextNumber(10, 160) else rnd:NextNumber(120, 170)
		j.pos = Vector3.new(camPos.X + math.cos(a) * r, 0, camPos.Z + math.sin(a) * r)
	end
	for i = 1, 22 do
		local p = Instance.new("Part")
		p.Name = "FloodJunk"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		kinds[(i - 1) % #kinds + 1](p)
		p.Transparency = 1
		p.Parent = ctx.folder
		local j: Junk = { part = p, pos = Vector3.zero, spin = rnd:NextNumber(-0.4, 0.4), bob = rnd:NextNumber(0, 6), tilt = CFrame.Angles(0, rnd:NextNumber(0, 6.3), 0) }
		place(j, Vector3.zero, true)
		table.insert(junk, j)
	end
	local junkPlaced = false

	-- under the water: murk, blur, bubbles; and the breath gauge
	local blur = Instance.new("BlurEffect")
	blur.Name = "DelugeBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local gui = Instance.new("ScreenGui")
	gui.Name = "DelugeScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local murk = Instance.new("Frame")
	murk.BorderSizePixel = 0
	murk.Size = UDim2.fromScale(1, 1)
	murk.BackgroundColor3 = Color3.fromRGB(45, 62, 45)
	murk.BackgroundTransparency = 1
	murk.Parent = gui
	local dark = Instance.new("ImageLabel")
	dark.BackgroundTransparency = 1
	dark.Size = UDim2.fromScale(1, 1)
	dark.Image = Common.tex(ctx, "Vignette")
	dark.ImageColor3 = Color3.fromRGB(5, 12, 8)
	dark.ImageTransparency = 1
	dark.Parent = gui
	local breathBar = Instance.new("Frame")
	breathBar.AnchorPoint = Vector2.new(0.5, 0)
	breathBar.Position = UDim2.new(0.5, 0, 0.62, 0)
	breathBar.Size = UDim2.fromOffset(220, 22)
	breathBar.BackgroundTransparency = 1
	breathBar.Visible = false
	breathBar.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = breathBar
	local bubbles: { ImageLabel } = {}
	for i = 1, 8 do
		local b = Instance.new("ImageLabel")
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(22, 22)
		b.Image = Common.tex(ctx, "Bubble")
		b.ImageColor3 = Color3.fromRGB(210, 240, 255)
		b.LayoutOrder = i
		b.Parent = breathBar
		table.insert(bubbles, b)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(murk, 1, { BackgroundTransparency = 1 })
		Common.tween(dark, 1, { ImageTransparency = 1 })
		Common.tween(blur, 1, { Size = 0 })
		breathBar.Visible = false
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
			blur:Destroy()
		end)
	end)
	local bubbleHolder = Common.part(ctx, "Bubbles", Vector3.new(2, 2, 2))
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = Common.tex(ctx, "Bubble")
	trail.Color = ColorSequence.new(Color3.fromRGB(210, 235, 230))
	trail.LightInfluence = 0.5
	trail.LightEmission = 0.2
	trail.Size = ns(0, 0.3, 1, 0.6)
	trail.Lifetime = NumberRange.new(1.5, 2.5)
	trail.Speed = NumberRange.new(4, 8)
	trail.SpreadAngle = Vector2.new(25, 25)
	trail.EmissionDirection = Enum.NormalId.Top
	trail.Rate = 0
	trail.Parent = bubbleHolder

	-- floating: a lift on the character that holds it at the surface
	local lift: VectorForce? = nil
	local liftAttach: Attachment? = nil
	local function dropLift()
		if lift then
			lift:Destroy()
			lift = nil
		end
		if liftAttach then
			liftAttach:Destroy()
			liftAttach = nil
		end
	end
	table.insert(ctx.cleanup, dropLift)

	local shake = 0
	local heldUntil = 0
	local function boil(at: Vector3, level: number)
		local holder = Common.part(ctx, "UndertowBoil", Vector3.new(10, 1, 10))
		holder.CFrame = CFrame.new(at.X, level + 0.4, at.Z)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.tex(ctx, "Splash")
		e.Color = ColorSequence.new(Color3.fromRGB(225, 230, 220))
		e.LightInfluence = 0.6
		e.Size = ns(0, 2, 1, 6)
		e.Transparency = ns(0, 0.2, 1, 1)
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Speed = NumberRange.new(8, 16)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Rate = 70
		e.Parent = holder
		local b = Instance.new("ParticleEmitter")
		b.Texture = Common.tex(ctx, "Bubble")
		b.LightInfluence = 0.5
		b.Size = ns(0, 0.6, 1, 1.2)
		b.Lifetime = NumberRange.new(0.6, 1)
		b.Speed = NumberRange.new(2, 5)
		b.SpreadAngle = Vector2.new(60, 60)
		b.Rate = 50
		b.Parent = holder
		task.delay(2.4, function()
			e.Rate = 0
			b.Rate = 0
		end)
		task.delay(4, function()
			holder:Destroy()
		end)
	end

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "DelugeSurge" then
			shake = math.max(shake, 0.6)
		elseif kind == "Undertow" and typeof(data.uid) == "number" then
			local level = (Workspace:GetAttribute("DelugeLevel") :: number?) or 0
			if typeof(data.at) == "Vector3" then
				boil(data.at, level)
			end
			if data.uid == player.UserId then
				heldUntil = os.clock() + (if typeof(data.seconds) == "number" then data.seconds else 2.5)
				shake = 1
			end
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)

	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = { Workspace.Terrain }
	probe.IgnoreWater = true
	local scroll = 0
	local underK = 0
	local walkWas: number? = nil
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local level = (Workspace:GetAttribute("DelugeLevel") :: number?) or 0
		local shown = math.clamp(level / 1.5, 0, 1) * ramp
		scroll += dt
		-- the sheet
		sheet.CFrame = CFrame.new(camPos.X, level - 0.5, camPos.Z)
		sheet.Transparency = 1 - shown * 0.82
		foamBig.Transparency = 1 - shown * 0.85
		foamSmall.Transparency = 1 - shown * 0.5
		under.Transparency = 1 - shown * 0.6
		-- the current streams out to sea (world-anchored, so it doesn't slide with you)
		local out = Vector3.new(camPos.X - island.X, 0, camPos.Z - island.Z)
		local dir = if out.Magnitude > 1 then out.Unit else Vector3.xAxis
		foamBig.OffsetStudsU = (-camPos.X + scroll * dir.X * CURRENT * 2) % 90
		foamBig.OffsetStudsV = (-camPos.Z + scroll * dir.Z * CURRENT * 2) % 90
		foamSmall.OffsetStudsU = (-camPos.X + scroll * dir.X * CURRENT * 3.2) % 34
		foamSmall.OffsetStudsV = (-camPos.Z + scroll * dir.Z * CURRENT * 3.2) % 34
		under.OffsetStudsU = (-camPos.X) % 60
		under.OffsetStudsV = (-camPos.Z) % 60
		pock.CFrame = CFrame.new(camPos.X, level + 0.1, camPos.Z)
		rings.Rate = 140 * shown
		splash.Rate = 120 * shown

		-- junk
		if not junkPlaced then
			junkPlaced = true
			for _, j in junk do
				place(j, camPos, true)
			end
		end
		for _, j in junk do
			local d = Vector3.new(j.pos.X - island.X, 0, j.pos.Z - island.Z)
			local jdir = if d.Magnitude > 1 then d.Unit else Vector3.xAxis
			j.pos += jdir * CURRENT * dt
			local fromCam = Vector3.new(j.pos.X - camPos.X, 0, j.pos.Z - camPos.Z).Magnitude
			if fromCam > 180 then
				place(j, camPos, false)
			end
			-- only where the flood is over land or sea, not on top of terrain sticking out
			j.bob += dt
			j.tilt *= CFrame.Angles(0, j.spin * dt, 0)
			local y = level + math.sin(j.bob * 1.3) * 0.3
			j.part.CFrame = CFrame.new(j.pos.X, y, j.pos.Z) * j.tilt * CFrame.Angles(math.sin(j.bob) * 0.15, 0, math.cos(j.bob * 0.8) * 0.15)
			j.part.Transparency = if level > 2 then 1 - shown else 1
		end

		-- you, in the flood
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local head = character and character:FindFirstChild("Head")
		local swimming = false
		if root and root:IsA("BasePart") and hum and hum.Health > 0 and level > 1 then
			local depth = level - root.Position.Y
			swimming = depth > 0.8
			if swimming then
				if not lift then
					liftAttach = Instance.new("Attachment")
					liftAttach.Name = "DelugeLift"
					liftAttach.Parent = root
					lift = Instance.new("VectorForce")
					lift.Name = "DelugeLift"
					lift.RelativeTo = Enum.ActuatorRelativeTo.World
					lift.ApplyAtCenterOfMass = true
					lift.Attachment0 = liftAttach
					lift.Parent = root
				end
				-- cancel gravity, then steer the vertical speed: up to float with the head just out,
				-- or down into the dark while something has hold of you
				(lift :: VectorForce).Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity, 0)
				local held = os.clock() < heldUntil
				local vel = root.AssemblyLinearVelocity
				local vy = if held then -7 else math.clamp((depth - 1.6) * 2.5, -6, 9) + math.sin(os.clock() * 2) * 0.4
				root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y + (vy - vel.Y) * math.min(1, dt * 6), vel.Z)
				local state = hum:GetState()
				if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics or state == Enum.HumanoidStateType.Landed then
					hum:ChangeState(Enum.HumanoidStateType.Freefall)
				end
				-- the current takes you out
				root.CFrame += dir * CURRENT * dt * ramp
				if walkWas == nil then
					walkWas = hum.WalkSpeed
					hum.WalkSpeed = math.min(hum.WalkSpeed, 11)
				end
			end
		end
		if not swimming then
			dropLift()
			if walkWas ~= nil and hum then
				hum.WalkSpeed = walkWas
			end
			walkWas = nil
		end

		-- under it
		local below = camPos.Y < level - 0.2 and shown > 0.5
		underK += ((if below then 1 else 0) - underK) * math.min(1, dt * 6)
		murk.BackgroundTransparency = 1 - underK * 0.55
		blur.Size = underK * 10
		local held = os.clock() < heldUntil
		dark.ImageTransparency = 1 - math.max(underK * 0.5, if held then 0.95 else 0)
		if head and head:IsA("BasePart") then
			bubbleHolder.CFrame = head.CFrame
			trail.Rate = if head.Position.Y < level - 0.3 then 12 else 0
		end
		local breath = player:GetAttribute("Breath") :: number?
		breathBar.Visible = breath ~= nil
		if breath then
			for i, b in bubbles do
				local k = math.clamp(breath * #bubbles - (i - 1), 0, 1)
				b.ImageTransparency = 1 - k
				b.Size = UDim2.fromOffset(22 * (0.5 + 0.5 * k), 22 * (0.5 + 0.5 * k))
			end
		end
		local camera = Workspace.CurrentCamera
		if camera and shake > 0 then
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
			shake = math.max(0, shake - dt * 0.7)
		end
	end)
	-- put walk speed back if the storm ends while swimming
	table.insert(ctx.cleanup, function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and walkWas then
			hum.WalkSpeed = walkWas
		end
		walkWas = nil
	end)
end
