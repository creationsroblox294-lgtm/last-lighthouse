--!strict
-- Maelstrom (Catastrophic): out at sea the water has opened into a vast whirlpool. The sea itself
-- is cut away (a local terrain carve that follows the vortex) and a dark glassy funnel (Blender:
-- funnel mesh) spirals down a hundred and fifty studs to a black throat. A huge foam whirl
-- (Blender) wheels round its lip, spray boils off the rim, and wreckage circles down the walls and
-- vanishes. Anywhere inside its reach you feel it dragging you seaward; in the water it takes you
-- round and down. When it lashes the shore (StormEvent "Lash") a ring of foam boils under someone,
-- then a column of sea bursts out of the ground and flings them towards it.
-- Textures: Blender (Maelstrom: funnel, whirl, column) + Bountiful Tide foam, Fish Rain spray,
-- Drizzle haze, Silent Fog vignette.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local DEEP = Color3.fromRGB(10, 40, 50)
local SEA = Color3.fromRGB(40, 110, 120)
local FOAM = Color3.fromRGB(225, 245, 250)
local RIM = 200 -- funnel lip radius (the mesh is 400 across)
local WATER_Y = 0
local SPIN = 0.32 -- funnel turns, radians a second

-- depth of the funnel wall below its lip at a radius (measured off the mesh)
local PROFILE = { { 0, -150 }, { 20, -139 }, { 60, -100 }, { 100, -69 }, { 140, -45 }, { 170, -12 }, { 190, -1 }, { 200, 0 } }
local function wallY(r: number): number
	if r >= 200 then
		return 0
	end
	for i = 2, #PROFILE do
		local a, b = PROFILE[i - 1], PROFILE[i]
		if r <= b[1] then
			local k = (r - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * k
		end
	end
	return 0
end

return function(ctx: Common.Ctx)
	local player = Players.LocalPlayer
	local rnd = Random.new()
	local terrain = Workspace.Terrain

	-- the sea goes dark and heavy
	local water = {
		WaterColor = terrain.WaterColor,
		WaterWaveSize = terrain.WaterWaveSize,
		WaterWaveSpeed = terrain.WaterWaveSpeed,
	}
	Common.tween(terrain, Common.FADE, { WaterColor = Color3.fromRGB(18, 70, 80), WaterWaveSize = 0.45, WaterWaveSpeed = 22 })
	table.insert(ctx.cleanup, function()
		Common.tween(terrain, Common.FADE, water)
	end)
	Common.clouds(ctx, { Cover = 0.9, Density = 0.6, Color = Color3.fromRGB(90, 110, 115) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(205, 230, 235),
		Saturation = -0.2,
		Brightness = -0.04,
		Contrast = 0.25,
		Bloom = 0.6,
		BloomThreshold = 1.2,
	})

	-- cutting the sea away: replace water with air in a stack of strips (a cone, roughly), so only
	-- water is touched and the beaches are left alone; put back when it moves on or ends
	local LAYERS = { { r = 196, bottom = -48 }, { r = 140, bottom = -104 }, { r = 76, bottom = -160 } }
	local STRIP = 24
	local function boxes(c: Vector3): { Region3 }
		local out = {}
		for _, layer in LAYERS do
			local z = -layer.r
			while z < layer.r do
				local z1 = math.min(layer.r, z + STRIP)
				local far = math.max(math.abs(z), math.abs(z1))
				local half = math.sqrt(math.max(0, layer.r * layer.r - far * far))
				if half > 4 then
					local lo = Vector3.new(c.X - half, layer.bottom, c.Z + z)
					local hi = Vector3.new(c.X + half, WATER_Y, c.Z + z1)
					table.insert(out, Region3.new(lo, hi):ExpandToGrid(4))
				end
				z = z1
			end
		end
		return out
	end
	local carved: Vector3? = nil
	local stopped = false
	local function restore()
		if carved then
			for _, region in boxes(carved) do
				pcall(function()
					terrain:ReplaceMaterial(region, 4, Enum.Material.Air, Enum.Material.Water)
				end)
			end
			carved = nil
		end
	end
	local function carve(c: Vector3)
		restore()
		for _, region in boxes(c) do
			pcall(function()
				terrain:ReplaceMaterial(region, 4, Enum.Material.Water, Enum.Material.Air)
			end)
		end
		carved = c
	end
	table.insert(ctx.cleanup, function()
		stopped = true
		restore()
	end)

	-- the funnel
	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local template = assets and assets:FindFirstChild("MaelstromFunnel")
	local funnel: Model? = nil
	if template and template:IsA("Model") then
		local m = template:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d.Material = Enum.Material.Glass
				d.Color = DEEP
				d.Reflectance = 0.15
				d.Transparency = 1
				Common.tween(d, 3, { Transparency = 0.05 })
				pcall(function()
					(d :: any).DoubleSided = true
				end)
			end
		end
		m:PivotTo(CFrame.new(0, -2000, 0))
		m.Parent = ctx.folder
		funnel = m
	end

	-- the whirl of foam round the lip, two layers turning at different speeds
	local function whirl(size: number, transparency: number, y: number): (Part, ImageLabel)
		local disc = Common.part(ctx, "Whirl", Vector3.new(size, 0.2, size))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.CanvasSize = Vector2.new(1024, 1024)
		gui.LightInfluence = 0.35
		gui.Brightness = 1.4
		gui.Parent = disc
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		img.Image = Common.tex(ctx, "Whirl")
		img.ImageTransparency = 1
		img.Parent = gui
		disc:SetAttribute("Y", y)
		Common.tween(img, Common.FADE, { ImageTransparency = transparency })
		table.insert(ctx.cleanup, function()
			Common.tween(img, Common.FADE, { ImageTransparency = 1 })
		end)
		return disc, img
	end
	local disc1, img1 = whirl(RIM * 2 / 0.46, 0.05, WATER_Y + 0.7)
	local disc2, img2 = whirl(RIM * 2 / 0.46 * 1.35, 0.45, WATER_Y + 0.5)

	-- spray boiling off the lip: one emitter hopped round the rim every frame
	local rimHolder = Common.part(ctx, "RimSpray", Vector3.new(30, 1, 30))
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = Common.tex(ctx, "Spray")
	spray.Color = ColorSequence.new(FOAM)
	spray.LightInfluence = 0.6
	spray.LightEmission = 0.1
	spray.Size = ns(0, 6, 1, 18)
	spray.Transparency = ns(0, 0.3, 0.6, 0.6, 1, 1)
	spray.Lifetime = NumberRange.new(1.2, 2.2)
	spray.Speed = NumberRange.new(14, 30)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.Drag = 0.6
	spray.Rotation = NumberRange.new(0, 360)
	spray.RotSpeed = NumberRange.new(-60, 60)
	spray.Rate = 0
	spray.Parent = rimHolder
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = Common.tex(ctx, "Haze")
	mist.Color = ColorSequence.new(Color3.fromRGB(190, 215, 220))
	mist.LightInfluence = 0.8
	mist.Size = ns(0, 30, 1, 60)
	mist.Transparency = ns(0, 1, 0.3, 0.6, 1, 1)
	mist.Lifetime = NumberRange.new(3, 5)
	mist.Speed = NumberRange.new(4, 10)
	mist.Rate = 0
	mist.Parent = rimHolder
	-- a breath of dark mist rising out of the throat
	local throat = Common.part(ctx, "Throat", Vector3.new(20, 1, 20))
	local breath = Instance.new("ParticleEmitter")
	breath.Texture = Common.tex(ctx, "Haze")
	breath.Color = ColorSequence.new(Color3.fromRGB(30, 60, 70))
	breath.LightInfluence = 1
	breath.Size = ns(0, 10, 1, 50)
	breath.Transparency = ns(0, 1, 0.3, 0.5, 1, 1)
	breath.Lifetime = NumberRange.new(4, 6)
	breath.Speed = NumberRange.new(14, 22)
	breath.SpreadAngle = Vector2.new(15, 15)
	breath.Rate = 0
	breath.Parent = throat

	-- wreckage riding the walls down and in
	type Wreck = { part: BasePart, r: number, a: number, spin: Vector3, rot: CFrame }
	local wrecks: { Wreck } = {}
	local function placeWreck(w: Wreck, fresh: boolean)
		w.r = if fresh then rnd:NextNumber(60, 420) else rnd:NextNumber(300, 420)
		w.a = rnd:NextNumber(0, math.pi * 2)
		w.spin = Vector3.new(rnd:NextNumber(-2, 2), rnd:NextNumber(-2, 2), rnd:NextNumber(-2, 2))
	end
	for i = 1, 18 do
		local p = Instance.new("Part")
		p.Name = "Wreck"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = if i % 3 == 0 then Enum.Material.Wood else Enum.Material.WoodPlanks
		p.Color = if i % 3 == 0 then Color3.fromRGB(90, 70, 50) else Color3.fromRGB(120, 92, 64)
		p.Size = if i % 3 == 0 then Vector3.new(14, 1.6, 1.6) else Vector3.new(rnd:NextNumber(5, 9), 0.7, rnd:NextNumber(1.4, 2.4))
		p.CFrame = CFrame.new(0, -2000, 0)
		p.Parent = ctx.folder
		local w: Wreck = { part = p, r = 0, a = 0, spin = Vector3.zero, rot = CFrame.Angles(rnd:NextNumber(0, 6), rnd:NextNumber(0, 6), 0) }
		placeWreck(w, true)
		table.insert(wrecks, w)
	end

	-- the shore: a dragging vignette when you're inside its reach
	local gui = Instance.new("ScreenGui")
	gui.Name = "MaelstromPull"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local edge = Instance.new("ImageLabel")
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Image = Common.tex(ctx, "Vignette")
	edge.ImageColor3 = Color3.fromRGB(10, 50, 60)
	edge.ImageTransparency = 1
	edge.Parent = gui
	local veil = Instance.new("Frame")
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(210, 240, 245)
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(edge, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	local shake = 0
	local function addShake(amount: number)
		shake = math.max(shake, amount)
	end

	-- the lash: foam boils in a ring under someone, then the sea bursts up out of the ground
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = { terrain, Workspace:FindFirstChild("Map") or terrain }
	local function lash(data: { [string]: any })
		local at: Vector3 = data.at
		local warn: number = data.warn or 1.4
		local radius: number = data.radius or 7
		local hit = Workspace:Raycast(at + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), probe)
		local ground = if hit then hit.Position.Y else at.Y - 3
		local ring = Instance.new("Part")
		ring.Name = "LashRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(140, 230, 240)
		ring.Transparency = 0.7
		ring.Size = Vector3.new(0.3, 2, 2)
		ring.CFrame = CFrame.new(at.X, ground + 0.2, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = ctx.folder
		Common.tween(ring, warn, { Size = Vector3.new(0.3, radius * 2.2, radius * 2.2), Transparency = 0.35 })
		local boilPart = Common.part(ctx, "LashBoil", Vector3.new(radius * 2, 1, radius * 2))
		boilPart.CFrame = CFrame.new(at.X, ground + 0.5, at.Z)
		local froth = Instance.new("ParticleEmitter")
		froth.Texture = Common.tex(ctx, "Foam")
		froth.Color = ColorSequence.new(FOAM, SEA)
		froth.LightInfluence = 0.5
		froth.LightEmission = 0.2
		froth.Size = ns(0, 2, 1, 5)
		froth.Transparency = ns(0, 0.2, 1, 1)
		froth.Lifetime = NumberRange.new(0.4, 0.9)
		froth.Speed = NumberRange.new(4, 12)
		froth.SpreadAngle = Vector2.new(30, 30)
		froth.Acceleration = Vector3.new(0, -25, 0)
		froth.Rate = 90
		froth.Parent = boilPart
		task.delay(warn, function()
			ring:Destroy()
			froth.Rate = 0
			-- the column
			local col = Instance.new("Part")
			col.Name = "LashColumn"
			col.Shape = Enum.PartType.Cylinder
			col.Anchored = true
			col.CanCollide = false
			col.CanQuery = false
			col.CanTouch = false
			col.CastShadow = false
			col.Material = Enum.Material.Glass
			col.Color = SEA
			col.Transparency = 0.35
			col.Reflectance = 0.2
			col.Size = Vector3.new(1, radius * 1.6, radius * 1.6)
			col.Parent = ctx.folder
			local burst = Instance.new("ParticleEmitter")
			burst.Texture = Common.tex(ctx, "Column")
			burst.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
			burst.Color = ColorSequence.new(FOAM, SEA)
			burst.LightInfluence = 0.5
			burst.LightEmission = 0.15
			burst.Size = ns(0, radius * 1.2, 1, radius * 2.4)
			burst.Squash = ns(0, 1.4, 1, 0.4)
			burst.Transparency = ns(0, 0.15, 0.7, 0.4, 1, 1)
			burst.Lifetime = NumberRange.new(0.9, 1.5)
			burst.Speed = NumberRange.new(60, 90)
			burst.SpreadAngle = Vector2.new(8, 8)
			burst.Acceleration = Vector3.new(0, -70, 0)
			burst.Rate = 0
			burst.Parent = boilPart
			burst:Emit(26)
			local splash = Instance.new("ParticleEmitter")
			splash.Texture = Common.tex(ctx, "Spray")
			splash.Color = ColorSequence.new(FOAM)
			splash.LightInfluence = 0.6
			splash.Size = ns(0, 4, 1, 10)
			splash.Transparency = ns(0, 0.2, 1, 1)
			splash.Lifetime = NumberRange.new(1, 1.8)
			splash.Speed = NumberRange.new(30, 55)
			splash.SpreadAngle = Vector2.new(70, 70)
			splash.Acceleration = Vector3.new(0, -60, 0)
			splash.Rate = 0
			splash.Parent = boilPart
			splash:Emit(40)
			local t0 = os.clock()
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				local h: number
				if t < 0.25 then
					h = 70 * (t / 0.25)
				else
					h = 70 * math.max(0, 1 - (t - 0.25) / 1.1) ^ 2
				end
				col.Size = Vector3.new(math.max(0.5, h), radius * 1.6 * (1 + 0.3 * math.min(1, t)), radius * 1.6 * (1 + 0.3 * math.min(1, t)))
				col.CFrame = CFrame.new(at.X, ground + h / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
				col.Transparency = 0.35 + 0.65 * math.clamp((t - 0.6) / 0.8, 0, 1)
				if t > 1.4 then
					conn:Disconnect()
					col:Destroy()
				end
			end)
			task.delay(3, function()
				boilPart:Destroy()
			end)
			local camera = Workspace.CurrentCamera
			if camera then
				local d = (camera.CFrame.Position - at).Magnitude
				if d < 120 then
					addShake(1 - d / 160)
				end
			end
		end)
	end

	local function lashed(data: { [string]: any })
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and hum and hum.Health > 0) then
			return
		end
		local toward: Vector3 = data.toward
		local flat = Vector3.new(toward.X - root.Position.X, 0, toward.Z - root.Position.Z)
		local dir = if flat.Magnitude > 1 then flat.Unit else Vector3.zero
		root.AssemblyLinearVelocity = dir * 55 + Vector3.new(0, 70, 0)
		hum:ChangeState(Enum.HumanoidStateType.FallingDown)
		veil.BackgroundTransparency = 0.1
		Common.tween(veil, 1.2, { BackgroundTransparency = 1 })
		addShake(1)
		task.delay(1.6, function()
			if hum.Parent and hum.Health > 0 then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end

	local turn = 0
	local spin1, spin2 = 0, 0
	local pull = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local at = Workspace:GetAttribute("MaelstromAt") :: Vector3?
		local reach = (Workspace:GetAttribute("MaelstromRadius") :: number?) or 420
		local camera = Workspace.CurrentCamera
		if shake > 0 and camera then
			shake = math.max(0, shake - dt * 1.2)
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.04 * shake, (rnd:NextNumber() - 0.5) * 0.04 * shake, 0)
		end
		if not at then
			spray.Rate = 0
			mist.Rate = 0
			breath.Rate = 0
			return
		end
		local centre = Vector3.new(at.X, WATER_Y, at.Z)
		-- keep the sea cut away under it
		if not stopped and ramp > 0.05 and (not carved or (carved - centre).Magnitude > 24) then
			carve(centre)
		end
		turn += dt * SPIN
		if funnel then
			funnel:PivotTo(CFrame.new(centre.X, WATER_Y + 0.5, centre.Z) * CFrame.Angles(0, -turn, 0))
		end
		spin1 += dt * 16
		spin2 += dt * 7
		disc1.CFrame = CFrame.new(centre.X, disc1:GetAttribute("Y") :: number, centre.Z)
		disc2.CFrame = CFrame.new(centre.X, disc2:GetAttribute("Y") :: number, centre.Z)
		img1.Rotation = -spin1
		img2.Rotation = -spin2
		local a = rnd:NextNumber(0, math.pi * 2)
		rimHolder.CFrame = CFrame.new(centre + Vector3.new(math.cos(a), 0, math.sin(a)) * RIM * rnd:NextNumber(0.95, 1.05) + Vector3.new(0, 1, 0))
		spray.Rate = 260 * ramp
		mist.Rate = 40 * ramp
		throat.CFrame = CFrame.new(centre.X, WATER_Y - 140, centre.Z)
		breath.Rate = 10 * ramp
		-- wreckage circles in and down, faster the deeper it goes
		for _, w in wrecks do
			local v = 22 + 1400 / math.max(w.r, 20)
			w.a += v / w.r * dt
			w.r -= (3 + 420 / math.max(w.r, 15)) * dt
			if w.r < 16 then
				placeWreck(w, false)
			end
			local y = if w.r > RIM then WATER_Y + 0.3 else WATER_Y + 0.5 + wallY(w.r) + 1.2
			w.rot *= CFrame.Angles(w.spin.X * dt, w.spin.Y * dt, w.spin.Z * dt)
			local pos = centre + Vector3.new(math.cos(-w.a) * w.r, 0, math.sin(-w.a) * w.r)
			w.part.CFrame = CFrame.new(pos.X, y, pos.Z) * w.rot
			w.part.Transparency = if w.r < 40 then (40 - w.r) / 24 else 0
		end
		-- the drag: round and in, much harder in the water
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local want = 0
		if root and root:IsA("BasePart") and hum and hum.Health > 0 then
			local off = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
			local d = off.Magnitude
			if d < reach and d > 1 then
				local k = 1 - d / reach
				local inward = -off.Unit
				local round = Vector3.new(off.Z, 0, -off.X).Unit
				local swimming = hum:GetState() == Enum.HumanoidStateType.Swimming or root.Position.Y < WATER_Y - 1
				local vel: Vector3
				if swimming then
					vel = inward * (5 + 22 * k * k) + round * (4 + 16 * k)
					want = 0.4 + 0.6 * k
				else
					vel = inward * (1 + 3 * k) + round * (0.5 * k)
					want = 0.25 * k
				end
				root.CFrame += vel * dt * ramp
				if d < RIM and not swimming then
					-- over the lip: sliding down the wall
					root.AssemblyLinearVelocity += (inward * 20 + Vector3.new(0, -10, 0)) * dt
				end
			end
		end
		pull += (want - pull) * math.min(1, dt * 3)
		edge.ImageTransparency = 1 - pull * 0.8
		if camera and (camPos - centre).Magnitude < reach then
			-- a low rumble under everything near it
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.004 * ramp, (rnd:NextNumber() - 0.5) * 0.004 * ramp, 0)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Lash" and typeof(data.at) == "Vector3" then
			lash(data)
		elseif kind == "Lashed" and typeof(data.toward) == "Vector3" then
			lashed(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
		spray.Rate = 0
		mist.Rate = 0
		breath.Rate = 0
		if funnel then
			for _, d in funnel:GetDescendants() do
				if d:IsA("BasePart") then
					Common.tween(d, Common.FADE, { Transparency = 1 })
				end
			end
		end
		for _, w in wrecks do
			Common.tween(w.part, Common.FADE, { Transparency = 1 })
		end
	end)
end
