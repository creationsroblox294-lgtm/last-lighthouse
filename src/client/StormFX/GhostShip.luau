--!strict
-- Ghost Ship (Moderate): a still, cold night under a sickly green moon. Out on the black water a
-- ship made of light drifts round the island (StormAssets.GhostShip, kept in step with the
-- server by StormEvent "ShipState"), rising and rolling on a swell that isn't there, wreathed in
-- green mist, its stern lantern sweeping a long pale searchlight over the island. If the light
-- finds you (StormEvent "Marked") the edges of your sight go green and your heart starts to
-- pound. Its bell (StormEvent "ShipBell") sends a ring of green light racing out across the sea
-- and makes every light on the island shudder; then green fire bursts out of the ground where the
-- drowned crew rise (StormEvent "CrewRise"). And sometimes the ship dissolves into mist and
-- reforms somewhere else (StormEvent "ShipBlink").
-- Textures: Blender (Ghost Ship: model, bell ring) + Aurora wisp, Drizzle haze, Silent Fog
-- vignette, Lucky Lightning glow.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ns = Common.ns

local GHOST = Color3.fromRGB(120, 255, 200)
local PALE = Color3.fromRGB(200, 255, 230)
local BEAM_SWING = math.rad(48) -- must match Storms/GhostShip
local BEAM_SPEED = 0.55
local BEAM_REACH = 800
local SCALE = 1.35

type State = { a0: number, t0: number, w: number, r: number }

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer
	local c0 = Config.World.IslandCenter
	local centre = Vector3.new(c0.X, 0, c0.Z)
	local state: State? = nil

	-- the night: low green mist drifting over everything, and specks of ghost-light
	Common.around(ctx, "GhostMist", Vector3.new(160, 10, 160), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 14,
		LightEmission = 0.3,
		LightInfluence = 0.4,
		Color = ColorSequence.new(Color3.fromRGB(80, 140, 120)),
		Size = ns(0, 16, 1, 30),
		Transparency = ns(0, 1, 0.3, 0.8, 0.7, 0.8, 1, 1),
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.5, 1.5),
		Offset = Vector3.new(0, -5, 0),
	})
	Common.around(ctx, "Motes", Vector3.new(90, 30, 90), {
		Texture = Common.tex(ctx, "Glow"),
		Rate = 10,
		Brightness = 2,
		Color = ColorSequence.new(GHOST),
		Size = ns(0, 0, 0.3, 0.5, 1, 0),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(0.5, 1.5),
	})
	Common.clouds(ctx, { Cover = 0.7, Density = 0.4, Color = Color3.fromRGB(60, 90, 85) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(205, 255, 235),
		Saturation = -0.4,
		Brightness = -0.02,
		Contrast = 0.15,
		Bloom = 1,
		BloomThreshold = 0.9,
	})

	-- the ship
	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local template = assets and assets:FindFirstChild("GhostShip")
	local ship: Model? = nil
	local hullParts: { BasePart } = {}
	local lanternOffset = Vector3.new(0, 30, 60)
	local lantern = Common.part(ctx, "ShipLantern", Vector3.new(5, 5, 5))
	lantern.Shape = Enum.PartType.Ball
	lantern.Material = Enum.Material.Neon
	lantern.Color = PALE
	lantern.Transparency = 0
	local lanternLight = Instance.new("PointLight")
	lanternLight.Color = GHOST
	lanternLight.Range = 60
	lanternLight.Brightness = 4
	lanternLight.Parent = lantern
	local beamFrom = Instance.new("Attachment")
	beamFrom.Parent = lantern
	local beamEnd = Common.part(ctx, "BeamEnd", Vector3.one)
	local beamTo = Instance.new("Attachment")
	beamTo.Parent = beamEnd
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamFrom
	beam.Attachment1 = beamTo
	beam.Texture = Common.tex(ctx, "Haze")
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(PALE, GHOST)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = ns(0, 0.35, 0.7, 0.75, 1, 1)
	beam.Width0 = 6
	beam.Width1 = 110
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Parent = lantern
	local spot = Instance.new("PointLight")
	spot.Color = PALE
	spot.Range = 45
	spot.Brightness = 3
	spot.Parent = beamEnd
	local wake: ParticleEmitter? = nil
	local shipAlpha = 0 -- 0 gone .. 1 fully there
	if template and template:IsA("Model") then
		local m = template:Clone()
		m:ScaleTo(m:GetScale() * SCALE)
		lanternOffset = ((m:GetAttribute("LanternOffset") :: Vector3?) or lanternOffset) * SCALE
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(hullParts, d)
				-- glowing, see-through light: it has to read from the lighthouse at night
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromRGB(70, 200, 150)
				d.Transparency = 1
			end
		end
		local glow = Instance.new("Highlight")
		glow.FillColor = GHOST
		glow.OutlineColor = PALE
		glow.FillTransparency = 1
		glow.OutlineTransparency = 1
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		glow.Parent = m
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = Common.tex(ctx, "Wisp")
		mist.Color = ColorSequence.new(GHOST)
		mist.LightEmission = 1
		mist.Size = ns(0, 20, 1, 45)
		mist.Transparency = ns(0, 1, 0.3, 0.6, 1, 1)
		mist.Lifetime = NumberRange.new(3, 5)
		mist.Speed = NumberRange.new(2, 6)
		mist.SpreadAngle = Vector2.new(180, 30)
		mist.RotSpeed = NumberRange.new(-20, 20)
		mist.Rate = 0
		mist.Parent = hullParts[1]
		wake = mist
		m.Parent = ctx.folder
		ship = m
	end

	-- the ship traced in ghost-light beams: masts, sails, hull and a flare on the lantern.
	-- Meshes, parts and even beams whose attachments sit on far-off parts drop out past the
	-- player's view distance, so these beams hang off a part that rides along with the camera
	-- and their ends are moved out to the ship every frame. This is what makes the ship read
	-- from the lighthouse.
	local near = Common.part(ctx, "ShipNear", Vector3.one)
	local u = 0.1 * 62.26 * SCALE -- studs per Blender metre in the ship model
	type Line = { beam: Beam, a0: Attachment, a1: Attachment, p0: Vector3, p1: Vector3, base: number }
	local lines: { Line } = {}
	local function glowLine(p0: Vector3, p1: Vector3, w0: number, w1: number, tex: string, base: number)
		local a0 = Instance.new("Attachment")
		a0.Parent = near
		local a1 = Instance.new("Attachment")
		a1.Parent = near
		local bm = Instance.new("Beam")
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.Texture = Common.tex(ctx, tex)
		bm.TextureMode = Enum.TextureMode.Stretch
		bm.Color = ColorSequence.new(GHOST, PALE)
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Transparency = NumberSequence.new(1)
		bm.Width0 = w0 * u
		bm.Width1 = w1 * u
		bm.FaceCamera = true
		bm.Parent = near
		table.insert(lines, { beam = bm, a0 = a0, a1 = a1, p0 = p0 * u, p1 = p1 * u, base = base })
	end
	-- (x, y, z) = (across, up, back) in Blender metres from the waterline amidships
	for _, mast in { { -5, 22 }, { 3, 26 }, { 9, 18 } } do
		local z, h = -mast[1], mast[2]
		glowLine(Vector3.new(0, 1.5, z), Vector3.new(0, 1.5 + h, z), 1.2, 0.6, "Haze", 0.15)
		-- the tattered sails, hanging under their yards
		glowLine(Vector3.new(0, 1.5 + h * 0.43, z), Vector3.new(0, 1.5 + h * 0.18, z), 13, 11, "Wisp", 0.5)
		glowLine(Vector3.new(0, 1.5 + h * 0.78, z), Vector3.new(0, 1.5 + h * 0.55, z), 9, 8, "Wisp", 0.5)
	end
	glowLine(Vector3.new(0, 2, 10.5), Vector3.new(0, 2.2, -10), 4, 3, "Haze", 0.25) -- hull
	glowLine(Vector3.new(0, 3.5, -10), Vector3.new(0, 6, -16.5), 1, 0.4, "Haze", 0.3) -- bowsprit
	local flare = Instance.new("Attachment")
	flare.Parent = near
	local flareEnd = Instance.new("Attachment")
	flareEnd.Parent = near
	local flareBeam = Instance.new("Beam")
	flareBeam.Attachment0 = flare
	flareBeam.Attachment1 = flareEnd
	flareBeam.Texture = Common.tex(ctx, "Glow")
	flareBeam.TextureMode = Enum.TextureMode.Stretch
	flareBeam.Color = ColorSequence.new(PALE)
	flareBeam.LightEmission = 1
	flareBeam.LightInfluence = 0
	flareBeam.Width0 = 30
	flareBeam.Width1 = 30
	flareBeam.FaceCamera = true
	flareBeam.Parent = near

	local function shipAt(now: number): (Vector3, Vector3)
		local s = state :: State
		local a = s.a0 + s.w * (now - s.t0)
		local pos = centre + Vector3.new(math.cos(a), 0, math.sin(a)) * s.r
		local fwd = Vector3.new(-math.sin(a), 0, math.cos(a)) * (if s.w >= 0 then 1 else -1)
		return pos, fwd
	end

	-- a burst of green mist (ship arriving or leaving, crew rising)
	local function burst(at: Vector3, size: number, count: number)
		local holder = Common.part(ctx, "GhostBurst", Vector3.new(size, size * 0.3, size))
		holder.CFrame = CFrame.new(at)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.tex(ctx, "Wisp")
		e.Color = ColorSequence.new(PALE, GHOST)
		e.LightEmission = 1
		e.Size = ns(0, size * 0.2, 1, size * 0.5)
		e.Transparency = ns(0, 0.2, 1, 1)
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(size * 0.1, size * 0.3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, size * 0.15, 0)
		e.Rate = 0
		e.Parent = holder
		e:Emit(count)
		local l = Instance.new("PointLight")
		l.Color = GHOST
		l.Range = math.min(60, size)
		l.Brightness = 6
		l.Parent = holder
		Common.tween(l, 1.5, { Brightness = 0 })
		task.delay(2.5, function()
			holder:Destroy()
		end)
	end

	-- the mark: green at the edges of your sight and a pounding heart
	local gui = Instance.new("ScreenGui")
	gui.Name = "Marked"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local vignette = Instance.new("ImageLabel")
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Image = Common.tex(ctx, "Vignette")
	vignette.ImageColor3 = Color3.fromRGB(60, 255, 170)
	vignette.ImageTransparency = 1
	vignette.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local isMarked = false
	local markedFor = 0
	local shudder = 0
	local baseBrightness = Lighting.Brightness
	table.insert(ctx.cleanup, function()
		Common.tween(vignette, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	-- the bell: a ring of green light racing out over the sea
	local function bell(at: Vector3)
		local ring = Common.part(ctx, "BellRing", Vector3.new(20, 0.2, 20))
		ring.CFrame = CFrame.new(at.X, 1.5, at.Z)
		local d = Instance.new("Decal")
		d.Texture = Common.tex(ctx, "BellRing")
		d.Face = Enum.NormalId.Top
		d.Color3 = GHOST
		d.Transparency = 0.1
		d.Parent = ring
		Common.tween(ring, 6, { Size = Vector3.new(2400, 0.2, 2400) })
		Common.tween(d, 6, { Transparency = 1 })
		task.delay(6.5, function()
			ring:Destroy()
		end)
		lanternLight.Brightness = 20
		Common.tween(lanternLight, 2, { Brightness = 4 })
		burst(at + Vector3.new(0, 30, 0), 80, 30)
		shudder = 1
	end

	local function rise(points: { Vector3 })
		for _, at in points do
			if typeof(at) == "Vector3" then
				burst(at, 14, 40)
				local pillar = Common.part(ctx, "CrewPillar", Vector3.new(60, 3, 3))
				pillar.Shape = Enum.PartType.Cylinder
				pillar.Material = Enum.Material.Neon
				pillar.Color = GHOST
				pillar.Transparency = 0.2
				pillar.CFrame = CFrame.new(at + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
				Common.tween(pillar, 1.4, { Transparency = 1, Size = Vector3.new(60, 10, 10) })
				task.delay(1.5, function()
					pillar:Destroy()
				end)
			end
		end
	end

	local blinkFade = 0 -- > 0 while the ship is dissolving
	local function newState(data: { [string]: any }, blinking: boolean)
		local s: State = { a0 = data.a0, t0 = data.t0, w = data.w, r = data.r }
		if blinking and state then
			local old = shipAt(Workspace:GetServerTimeNow())
			burst(old + Vector3.new(0, 40, 0), 120, 50)
			blinkFade = 1
			task.delay(1.2, function()
				state = s
				burst(shipAt(Workspace:GetServerTimeNow()) + Vector3.new(0, 40, 0), 120, 50)
			end)
		else
			state = s
		end
	end

	local sway = 0
	table.insert(ctx.onFrame, function(dt, _camPos, ramp)
		local now = Workspace:GetServerTimeNow()
		sway += dt
		if state then
			local pos, fwd = shipAt(now)
			-- dissolve during a blink, otherwise fade in with the storm
			if blinkFade > 0 then
				blinkFade = math.max(0, blinkFade - dt * 0.8)
			end
			local goal = if blinkFade > 0.4 then 0 else ramp
			shipAlpha += (goal - shipAlpha) * math.min(1, dt * 2)
			local cf = CFrame.lookAt(pos, pos + fwd)
				* CFrame.new(0, math.sin(sway * 0.7) * 2.5, 0)
				* CFrame.Angles(math.sin(sway * 0.5) * 0.04, 0, math.sin(sway * 0.37) * 0.07)
			if ship then
				ship:PivotTo(cf)
				for _, p in hullParts do
					p.Transparency = 1 - 0.5 * shipAlpha
				end
				local h = ship:FindFirstChildOfClass("Highlight")
				if h then
					h.FillTransparency = 1 - 0.12 * shipAlpha
					h.OutlineTransparency = 1 - 0.5 * shipAlpha
				end
			end
			if wake then
				wake.Rate = 10 * shipAlpha
			end
			local camera = Workspace.CurrentCamera
			if camera then
				near.CFrame = camera.CFrame * CFrame.new(0, 0, -10)
			end
			local flicker = 0.1 * math.sin(sway * 3.1) + 0.05 * math.sin(sway * 11.7)
			for _, ln in lines do
				ln.a0.WorldPosition = (cf * CFrame.new(ln.p0)).Position
				ln.a1.WorldPosition = (cf * CFrame.new(ln.p1)).Position
				ln.beam.Transparency = NumberSequence.new(1 - (1 - math.clamp(ln.base + flicker, 0, 1)) * shipAlpha)
			end
			local lp = (cf * CFrame.new(lanternOffset)).Position
			lantern.CFrame = CFrame.new(lp)
			lantern.Transparency = 1 - shipAlpha
			flare.WorldPosition = lp + Vector3.new(0, 15, 0)
			flareEnd.WorldPosition = lp - Vector3.new(0, 15, 0)
			flareBeam.Transparency = NumberSequence.new(1 - 0.9 * shipAlpha)
			-- the searchlight sweeps to and fro across the island
			local toC = centre - pos
			local yaw = math.atan2(toC.Z, toC.X) + BEAM_SWING * math.sin(now * BEAM_SPEED)
			local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
			local reach = BEAM_REACH
			local hit = Workspace:Raycast(lp, (pos + dir * BEAM_REACH + Vector3.new(0, 8, 0)) - lp)
			if hit then
				reach = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			end
			beamEnd.CFrame = CFrame.new(pos + dir * reach + Vector3.new(0, 8, 0))
			beam.Enabled = shipAlpha > 0.3
			spot.Enabled = beam.Enabled
		end
		-- marked
		if isMarked then
			markedFor += dt
		end
		local beat = if isMarked then (0.5 + 0.5 * math.sin(markedFor * (6 + markedFor * 0.4))) else 0
		vignette.ImageTransparency = if isMarked then 0.35 - 0.3 * beat else math.min(1, vignette.ImageTransparency + dt)
		-- every light on the island shudders when the bell tolls
		if shudder > 0 then
			shudder = math.max(0, shudder - dt * 0.7)
			Lighting.Brightness = baseBrightness * (1 - 0.5 * shudder * (0.5 + 0.5 * math.sin(sway * 40)))
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.01 * shudder, (rnd:NextNumber() - 0.5) * 0.01 * shudder, 0)
			end
		else
			baseBrightness = Lighting.Brightness
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "ShipState" and typeof(data) == "table" and not state then
			newState(data, false)
		elseif kind == "ShipBlink" and typeof(data) == "table" then
			newState(data, true)
		elseif kind == "ShipBell" and typeof(data) == "table" and typeof(data.at) == "Vector3" then
			bell(data.at)
		elseif kind == "CrewRise" and typeof(data) == "table" and typeof(data.at) == "table" then
			rise(data.at)
		elseif kind == "Marked" then
			isMarked = true
			markedFor = 0
		elseif kind == "Unmarked" then
			isMarked = false
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
		if ship then
			for _, p in hullParts do
				Common.tween(p, Common.FADE, { Transparency = 1 })
			end
		end
		if shudder > 0 then
			Lighting.Brightness = baseBrightness
		end
	end)
end
