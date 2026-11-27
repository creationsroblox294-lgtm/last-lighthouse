--!strict
-- Eclipse Storm (Catastrophic): a clear, strange afternoon. A black moon bites into the sun (a
-- billboard far out along the real sun direction; the real sun is hidden) and the light goes
-- thin and wrong. At totality night slams down: the corona (Blender) blazes round a black hole
-- in the sky, stars come out, the whole horizon burns sunset-orange, and eyes open in the dark.
-- Everyone caught outside the light grows a shadow (StormEvent "Shadows"): a black silhouette of
-- them with red eyes that rises where they were and walks after them, copying every move they
-- made a moment ago. If yours reaches you the world drains to black at the edges. The lamp light
-- burns shadows away (StormEvent "ShadowBurn"). The diamond ring (StormEvent "DiamondRing") ends
-- it in one blinding flash, and the day comes back.
-- Textures: Blender (Eclipse: corona, sun) + Wild Swarm eyes, Fish Rain glint, Rolling Thunder
-- smoke, Ember Storm ember, Silent Fog vignette.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local NIGHT_AMBIENT = Color3.fromRGB(26, 30, 58)
local GLOW = Color3.fromRGB(255, 135, 70)
local DECAY = Color3.fromRGB(14, 16, 38)
local SUN_DISTANCE = 2400
local SUN_SIZE = 1000 -- studs across the billboard (the sun disc is a third of it)

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

return function(ctx: Common.Ctx)
	local player = Players.LocalPlayer
	local rnd = Random.new()

	Common.clouds(ctx, { Cover = 0.35, Density = 0.3, Color = Color3.fromRGB(200, 195, 190) })
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EclipseGrade"
	grade.Parent = Lighting
	table.insert(ctx.cleanup, function()
		Common.tween(grade, Common.FADE, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		task.delay(Common.FADE + 0.5, function()
			grade:Destroy()
		end)
	end)

	-- the sky: sun, moon and corona on one billboard far out along the sun
	local skyPart = Common.part(ctx, "EclipseSky", Vector3.one)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(SUN_SIZE, SUN_SIZE)
	board.LightInfluence = 0
	board.Brightness = 2
	board.MaxDistance = math.huge
	board.Parent = skyPart
	local function layer(image: string, size: number, z: number): ImageLabel
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.AnchorPoint = Vector2.new(0.5, 0.5)
		i.Position = UDim2.fromScale(0.5, 0.5)
		i.Size = UDim2.fromScale(size, size)
		i.Image = image
		i.ImageTransparency = 1
		i.ZIndex = z
		i.Parent = board
		return i
	end
	local corona = layer(Common.tex(ctx, "Corona"), 1, 1)
	local sun = layer(Common.tex(ctx, "Sun"), 1, 2)
	local moon = Instance.new("Frame")
	moon.AnchorPoint = Vector2.new(0.5, 0.5)
	moon.Size = UDim2.fromScale(0.34, 0.34)
	moon.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
	moon.BorderSizePixel = 0
	moon.BackgroundTransparency = 1
	moon.ZIndex = 3
	moon.Parent = board
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = moon
	local bead = layer(Common.tex(ctx, "Glint"), 0.5, 4) -- the diamond
	bead.ImageColor3 = Color3.fromRGB(255, 250, 235)

	-- stars, riding with the camera high overhead
	local starSheet = Common.part(ctx, "Stars", Vector3.new(2400, 1, 2400))
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = Common.tex(ctx, "Glint")
	stars.LightEmission = 1
	stars.LightInfluence = 0
	stars.Brightness = 3
	stars.Size = ns(0, 6, 1, 6)
	stars.Lifetime = NumberRange.new(16, 20)
	stars.Speed = NumberRange.new(0, 0)
	stars.LockedToPart = true
	stars.Rotation = NumberRange.new(0, 360)
	stars.Transparency = ns(0, 1, 1, 1)
	stars.Rate = 0
	stars.Parent = starSheet

	-- the real sky and light, to be put back after
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local sunSize = sky and sky.SunAngularSize
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local base: { [string]: any }? = nil
	local restored = false
	local function capture()
		base = {
			Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Exposure = Lighting.ExposureCompensation,
			AtmColor = atmosphere and atmosphere.Color,
			AtmDecay = atmosphere and atmosphere.Decay,
			AtmHaze = atmosphere and atmosphere.Haze,
		}
	end
	local function applyDark(d: number, glow: number)
		local b = base
		if not b then
			return
		end
		Lighting.Brightness = b.Brightness + (0.05 - b.Brightness) * d
		Lighting.Ambient = (b.Ambient :: Color3):Lerp(NIGHT_AMBIENT, d)
		Lighting.OutdoorAmbient = (b.OutdoorAmbient :: Color3):Lerp(NIGHT_AMBIENT, d)
		Lighting.ExposureCompensation = b.Exposure + (-0.2 - b.Exposure) * d
		if atmosphere and b.AtmColor then
			atmosphere.Color = (b.AtmColor :: Color3):Lerp(GLOW, glow)
			atmosphere.Decay = (b.AtmDecay :: Color3):Lerp(DECAY, glow)
			atmosphere.Haze = b.AtmHaze + (2.6 - b.AtmHaze) * glow
		end
	end
	local function restore()
		if base and not restored then
			restored = true
			local b = base
			Common.tween(Lighting, 3, { Brightness = b.Brightness, Ambient = b.Ambient, OutdoorAmbient = b.OutdoorAmbient, ExposureCompensation = b.Exposure })
			if atmosphere and b.AtmColor then
				Common.tween(atmosphere, 3, { Color = b.AtmColor, Decay = b.AtmDecay, Haze = b.AtmHaze })
			end
		end
		if sky and sunSize then
			sky.SunAngularSize = sunSize
		end
	end
	table.insert(ctx.cleanup, restore)

	-- the screen: a flash for the diamond ring, and darkness creeping in when your shadow has you
	local gui = Instance.new("ScreenGui")
	gui.Name = "EclipseScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local edge = Instance.new("ImageLabel")
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Image = Common.tex(ctx, "Vignette")
	edge.ImageColor3 = Color3.new(0, 0, 0)
	edge.ImageTransparency = 1
	edge.Parent = gui
	local flash = Instance.new("Frame")
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	flash.BackgroundTransparency = 1
	flash.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(edge, 2, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	-- eyes opening in the dark
	type Eye = { part: BasePart, img: ImageLabel, t0: number, life: number }
	local eyes: { Eye } = {}
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = { Workspace.Terrain, Workspace:FindFirstChild("Map") or Workspace.Terrain }
	local function openEye(camPos: Vector3)
		local a = rnd:NextNumber(0, math.pi * 2)
		local r = rnd:NextNumber(35, 90)
		local at = camPos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local hit = Workspace:Raycast(at + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), probe)
		if not hit or hit.Material == Enum.Material.Water then
			return
		end
		local p = Common.part(ctx, "Eyes", Vector3.one)
		p.CFrame = CFrame.new(hit.Position + Vector3.new(0, rnd:NextNumber(2, 6), 0))
		local b = Instance.new("BillboardGui")
		b.Size = UDim2.fromScale(3.6, 1.8)
		b.LightInfluence = 0
		b.Brightness = 3
		b.Parent = p
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = Common.tex(ctx, "Eyes")
		img.ImageColor3 = if rnd:NextNumber() < 0.5 then Color3.fromRGB(255, 60, 50) else Color3.fromRGB(255, 210, 90)
		img.ImageTransparency = 1
		img.Parent = b
		table.insert(eyes, { part = p, img = img, t0 = os.clock(), life = rnd:NextNumber(3, 7) })
	end

	-- shadows: silhouettes of a player that copy what they did a moment ago
	type Pose = { t: number, rel: { CFrame } }
	type Shade = {
		uid: number,
		model: Model,
		parts: { BasePart },
		source: { BasePart },
		root: BasePart?,
		poses: { Pose },
		pos: Vector3,
		target: Vector3,
		gone: boolean,
	}
	local shades: { [number]: Shade } = {}
	local DELAY = 0.9

	local function makeShade(uid: number, at: Vector3): Shade?
		local owner = Players:GetPlayerByUserId(uid)
		local char = owner and owner.Character
		if not char then
			return nil
		end
		local was = char.Archivable
		char.Archivable = true
		local ok, clone = pcall(function()
			return char:Clone()
		end)
		char.Archivable = was
		if not ok or not clone then
			return nil
		end
		local m = clone :: Model
		m.Name = "Shadow" .. uid
		local source, parts = {}, {}
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(source, d)
			end
		end
		for _, d in m:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
				d:Destroy()
			elseif d:IsA("SpecialMesh") then
				d.TextureId = ""
				d.VertexColor = Vector3.new(0, 0, 0)
			end
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d.Material = Enum.Material.SmoothPlastic
				d.Color = Color3.fromRGB(4, 4, 8)
				d.Reflectance = 0
				if d:IsA("MeshPart") then
					pcall(function()
						d.TextureID = ""
					end)
				end
				d.Transparency = if d.Name == "HumanoidRootPart" then 1 else 1
				table.insert(parts, d)
			end
		end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:Destroy()
		end
		if #parts ~= #source then
			m:Destroy()
			return nil
		end
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(3, 3, 6)
		hl.FillTransparency = 0
		hl.OutlineColor = Color3.fromRGB(200, 10, 35)
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = m
		local head = m:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local b = Instance.new("BillboardGui")
			b.Name = "ShadowEyes"
			b.Size = UDim2.fromScale(2.6, 1.3)
			b.StudsOffset = Vector3.new(0, 0.1, 0)
			b.LightInfluence = 0
			b.Brightness = 6
			b.Parent = head
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = Common.tex(ctx, "Eyes")
			img.ImageColor3 = Color3.fromRGB(255, 40, 40)
			img.Parent = b
		end
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local wisps = Instance.new("ParticleEmitter")
			wisps.Texture = Common.tex(ctx, "Smoke")
			wisps.Color = ColorSequence.new(Color3.new(0, 0, 0))
			wisps.LightInfluence = 0
			wisps.Size = ns(0, 2, 1, 5)
			wisps.Transparency = ns(0, 0.4, 1, 1)
			wisps.Lifetime = NumberRange.new(1, 1.8)
			wisps.Speed = NumberRange.new(2, 5)
			wisps.SpreadAngle = Vector2.new(30, 30)
			wisps.Rate = 14
			wisps.Parent = root
		end
		m.Parent = ctx.folder
		for _, p in parts do
			if p.Name ~= "HumanoidRootPart" then
				Common.tween(p, 1.2, { Transparency = 0 })
			end
		end
		return { uid = uid, model = m, parts = parts, source = source, root = root, poses = {}, pos = at, target = at, gone = false }
	end

	local function burn(s: Shade)
		if s.gone then
			return
		end
		s.gone = true
		local at = if s.root then s.root.Position else s.pos
		local holder = Common.part(ctx, "ShadowBurn", Vector3.new(3, 5, 3))
		holder.CFrame = CFrame.new(at)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.tex(ctx, "Ember")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 90, 40))
		e.LightEmission = 1
		e.Size = ns(0, 0.6, 1, 0.1)
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(4, 12)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 6, 0)
		e.Rate = 0
		e.Parent = holder
		e:Emit(60)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = Common.tex(ctx, "Smoke")
		smoke.Color = ColorSequence.new(Color3.new(0, 0, 0))
		smoke.Size = ns(0, 3, 1, 8)
		smoke.Transparency = ns(0, 0.3, 1, 1)
		smoke.Lifetime = NumberRange.new(1, 2)
		smoke.Speed = NumberRange.new(3, 7)
		smoke.Rate = 0
		smoke.Parent = holder
		smoke:Emit(20)
		for _, p in s.parts do
			Common.tween(p, 0.6, { Transparency = 1 })
		end
		local hl = s.model:FindFirstChildOfClass("Highlight")
		if hl then
			Common.tween(hl, 0.6, { FillTransparency = 1, OutlineTransparency = 1 })
		end
		task.delay(0.8, function()
			s.model:Destroy()
		end)
		task.delay(2.5, function()
			holder:Destroy()
		end)
	end
	table.insert(ctx.cleanup, function()
		for _, s in shades do
			burn(s)
		end
		table.clear(shades)
	end)

	local diamondAt = 0
	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Shadows" and typeof(data.list) == "table" then
			local seen = {}
			for _, e in data.list do
				local uid = e.uid
				seen[uid] = true
				local at = Vector3.new(e.x, e.y, e.z)
				local s = shades[uid]
				if not s then
					local made = makeShade(uid, at)
					if made then
						shades[uid] = made
					end
				else
					s.target = at
				end
			end
			for uid, s in shades do
				if not seen[uid] then
					burn(s)
					shades[uid] = nil
				end
			end
		elseif kind == "ShadowBurn" and typeof(data.uid) == "number" then
			local s = shades[data.uid]
			if s then
				burn(s)
				shades[data.uid] = nil
			end
		elseif kind == "DiamondRing" then
			diamondAt = os.clock()
			flash.BackgroundTransparency = 0.05
			Common.tween(flash, 2.5, { BackgroundTransparency = 1 })
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)

	local nextEye = 0
	local caught = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local now = Workspace:GetServerTimeNow()
		local contact = Workspace:GetAttribute("EclipseContact") :: number?
		local total = Workspace:GetAttribute("EclipseTotal") :: number?
		local totalEnd = Workspace:GetAttribute("EclipseTotalEnd") :: number?
		local clear = Workspace:GetAttribute("EclipseClear") :: number?
		-- how far the moon has gone across: -1 (touching, coming) .. 0 (centred) .. 1 (leaving)
		local across = -1.2
		local totality = false
		if contact and total and totalEnd and clear then
			if now < contact then
				across = -1.2
			elseif now < total then
				across = -1 + (now - contact) / (total - contact)
			elseif now < totalEnd then
				totality = true
				across = 0.06 * ((now - total) / (totalEnd - total) - 0.5)
			elseif now < clear then
				across = 0.03 + (now - totalEnd) / (clear - totalEnd)
			else
				across = 1.2
			end
		end
		local cover = math.clamp(1 - math.abs(across), 0, 1)
		local dark = if totality then 1 else 0.6 * cover ^ 3
		local glow = if totality then 1 else 0.35 * cover ^ 4

		-- the sky
		local sunDir = Lighting:GetSunDirection()
		skyPart.CFrame = CFrame.new(camPos + sunDir * SUN_DISTANCE)
		local inSky = math.abs(across) < 1.15 and ramp > 0
		if sky and sunSize then
			sky.SunAngularSize = if inSky then 0 else sunSize
		end
		local shown = if inSky then 1 else 0
		sun.ImageTransparency = 1 - shown * (if totality then 0 else 1)
		moon.BackgroundTransparency = 1 - shown
		moon.Position = UDim2.fromScale(0.5 + across * 0.34, 0.5 + across * 0.12)
		corona.ImageTransparency = if totality then 0 else 1 - shown * 0.3 * cover ^ 6
		local sinceDiamond = os.clock() - diamondAt
		if sinceDiamond < 3 then
			bead.ImageTransparency = math.clamp(sinceDiamond / 3, 0, 1)
			bead.Size = UDim2.fromScale(0.5 + 0.5 * (1 - sinceDiamond / 3), 0.5 + 0.5 * (1 - sinceDiamond / 3))
			bead.Position = UDim2.fromScale(0.5 + 0.16, 0.5 - 0.04)
		else
			bead.ImageTransparency = 1
		end

		-- the light
		if contact and now >= contact and not base then
			capture()
		end
		if base and not restored then
			if clear and now >= clear then
				restore()
			else
				applyDark(dark * ramp, glow * ramp)
			end
		end
		grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(175, 190, 255), dark * ramp)
		grade.Saturation = -0.35 * dark * ramp
		grade.Contrast = 0.15 * dark * ramp

		-- stars
		starSheet.CFrame = CFrame.new(camPos + Vector3.new(0, 700, 0))
		stars.Rate = if totality then 60 else 0
		local starT = 1 - (if totality then 0.15 else 0)
		stars.Transparency = ns(0, 1, 0.1, starT, 0.9, starT, 1, 1)

		-- eyes in the dark
		if totality and os.clock() >= nextEye and #eyes < 10 then
			nextEye = os.clock() + rnd:NextNumber(0.4, 1.2)
			openEye(camPos)
		end
		for i = #eyes, 1, -1 do
			local e = eyes[i]
			local t = os.clock() - e.t0
			local blink = if math.floor(t * 1.3) % 5 == 4 then 1 else 0
			local fade = math.min(1, t / 0.6, (e.life - t) / 0.6)
			e.img.ImageTransparency = 1 - math.max(0, fade) * (1 - blink)
			if t > e.life or not totality then
				e.part:Destroy()
				table.remove(eyes, i)
			end
		end

		-- shadows walk
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local mine = 0
		for uid, s in shades do
			if s.gone then
				continue
			end
			-- record the owner's pose
			local rel = {}
			local srcRoot: BasePart? = nil
			for _, p in s.source do
				if p.Name == "HumanoidRootPart" then
					srcRoot = p
					break
				end
			end
			if srcRoot and srcRoot.Parent then
				local inv = srcRoot.CFrame:Inverse()
				for i, p in s.source do
					rel[i] = inv * p.CFrame
				end
				table.insert(s.poses, { t = os.clock(), rel = rel })
				while #s.poses > 2 and s.poses[2].t < os.clock() - DELAY do
					table.remove(s.poses, 1)
				end
			end
			s.pos = s.pos:Lerp(s.target, math.min(1, dt * 6))
			local face = if srcRoot then srcRoot.Position - s.pos else Vector3.zAxis
			face = Vector3.new(face.X, 0, face.Z)
			local rootCF = CFrame.lookAt(s.pos + Vector3.new(0, 2.5, 0), s.pos + Vector3.new(0, 2.5, 0) + (if face.Magnitude > 0.1 then face.Unit else Vector3.zAxis))
			local pose = s.poses[1]
			if pose then
				for i, p in s.parts do
					local r = pose.rel[i]
					if r then
						p.CFrame = rootCF * r
					end
				end
			end
			if myRoot and myRoot:IsA("BasePart") and uid == player.UserId then
				local d = Vector3.new(myRoot.Position.X - s.pos.X, 0, myRoot.Position.Z - s.pos.Z).Magnitude
				mine = math.clamp(1 - (d - 3) / 25, 0, 1)
			end
		end
		caught += (mine - caught) * math.min(1, dt * 3)
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
		edge.ImageTransparency = 1 - caught * (0.7 + 0.25 * pulse)
		if caught > 0.7 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.01 * caught, (rnd:NextNumber() - 0.5) * 0.01 * caught, 0)
			end
		end
	end)
end
