--!strict
-- Hurricane (Severe): rain driven flat by a wind that swings slowly round the compass
-- (Workspace "WindDir" / "WindStrength"), spray streaming over everything, debris tumbling in
-- (StormEvent "Debris"), and overhead the storm itself: a vast spiral of cloud (Blender) turning
-- above the island, its eye creeping closer as the storm tracks in ("HurricaneEyeAt" /
-- "HurricaneEyeEnd" / "HurricaneTrack"). When the eye passes over, the wind dies, the rain stops,
-- the sky opens into a ring of towering cloud with sun pouring down through the middle, and it
-- goes quiet. Then the back wall hits (StormEvent "BackWall"): a grey wall of rain slams in from
-- the other side and everything shakes.
-- Textures: Blender (Hurricane: spiral) + Golden Rain drop, Sea Breeze streak/leaf, Drizzle haze,
-- Squall sheet.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ns = Common.ns

local RAIN = Color3.fromRGB(200, 210, 220)
local LEAVES = ColorSequence.new(Color3.fromRGB(90, 120, 60), Color3.fromRGB(130, 110, 60))
local SPIRAL_SIZE = 6000
local SPIRAL_HEIGHT = 520
local EYE_CLEAR = 300 -- studs from the eye's centre that count as inside the clear eye

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer
	local c0 = Config.World.IslandCenter
	local centre = Vector3.new(c0.X, 0, c0.Z)
	local windDir: Vector3 = (Workspace:GetAttribute("WindDir") :: Vector3?) or Vector3.new(1, 0, 0)
	local strength = 1

	local rain = Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 2600,
		Size = ns(0, 0.4, 1, 0.4),
		Squash = ns(0, 1.8, 1, 1.8),
		Brightness = 1.2,
		Color = ColorSequence.new(RAIN),
		Speed = NumberRange.new(90, 110),
		Slant = Vector3.new(60, 0, 0),
	})
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	local spray = Common.around(ctx, "Spray", Vector3.new(120, 30, 120), {
		Texture = Common.tex(ctx, "Streak"),
		Rate = 70,
		LightEmission = 0.1,
		LightInfluence = 0.9,
		Color = ColorSequence.new(Color3.fromRGB(210, 220, 225)),
		Size = ns(0, 3, 1, 5),
		Transparency = ns(0, 1, 0.3, 0.5, 0.7, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(90, 120),
		Spread = Vector2.new(0, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	spray.EmissionDirection = Enum.NormalId.Front
	local scud = Common.around(ctx, "Scud", Vector3.new(220, 40, 220), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 14,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(140, 150, 160)),
		Size = ns(0, 30, 1, 50),
		Transparency = ns(0, 1, 0.3, 0.65, 0.7, 0.65, 1, 1),
		Lifetime = NumberRange.new(3, 4),
		Speed = NumberRange.new(40, 60),
		Spread = Vector2.new(5, 5),
		Offset = Vector3.new(0, 25, 0),
	})
	scud.EmissionDirection = Enum.NormalId.Front
	local leaves = Common.around(ctx, "Leaves", Vector3.new(80, 20, 80), {
		Texture = Common.tex(ctx, "Leaf"),
		Rate = 40,
		LightEmission = 0,
		LightInfluence = 1,
		Color = LEAVES,
		Size = ns(0, 0.6, 1, 0.4),
		Transparency = ns(0, 1, 0.1, 0, 0.85, 0, 1, 1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(50, 70),
		Spread = Vector2.new(20, 20),
		RotSpeed = NumberRange.new(-500, 500),
	})
	leaves.EmissionDirection = Enum.NormalId.Front
	Common.clouds(ctx, { Cover = 1, Density = 0.9, Color = Color3.fromRGB(95, 105, 115) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(220, 230, 240),
		Saturation = -0.4,
		Brightness = -0.04,
		Contrast = 0.2,
		Bloom = 0.4,
		BloomThreshold = 1.3,
		Blur = 1,
	})

	-- the storm overhead: a turning spiral whose eye tracks in over the island. Parts top out at
	-- 2048 studs, so the spiral is a 3x3 grid of tiles, each showing its own ninth of the image
	local GRID = 3
	local TILE = SPIRAL_SIZE / GRID
	local IMAGE = 1024 -- pixels across the spiral image
	local tiles: { { part: BasePart, offset: CFrame, img: ImageLabel } } = {}
	for row = 0, GRID - 1 do
		for col = 0, GRID - 1 do
			local part = Common.part(ctx, "Spiral", Vector3.new(TILE, 1, TILE))
			-- an unlit SurfaceGui: a texture on the underside of a part would only ever be in shadow
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Bottom
			gui.LightInfluence = 0.15
			gui.Brightness = 1
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 0.2
			gui.Adornee = part
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = Common.tex(ctx, "Spiral")
			img.ImageRectSize = Vector2.new(IMAGE / GRID, IMAGE / GRID)
			img.ImageRectOffset = Vector2.new(col * IMAGE / GRID, row * IMAGE / GRID)
			img.ImageColor3 = Color3.fromRGB(120, 130, 140)
			img.ImageTransparency = 1
			img.Parent = gui
			gui.Parent = part
			Common.tween(img, Common.FADE, { ImageTransparency = 0.05 })
			local off = CFrame.new((col - (GRID - 1) / 2) * TILE, 0, (row - (GRID - 1) / 2) * TILE)
			table.insert(tiles, { part = part, offset = off, img = img })
		end
	end
	-- the eyewall: a ring of towering cloud round the clear eye (panels with a curtain of cloud on
	-- both sides, so it reads from inside the eye as well as from outside)
	local PANELS = 18
	local wallRadius = EYE_CLEAR + 60
	local panels: { BasePart } = {}
	local wallImg: { ImageLabel } = {}
	for i = 1, PANELS do
		local w = 2 * wallRadius * math.tan(math.pi / PANELS) + 8
		local part = Common.part(ctx, "Eyewall", Vector3.new(w, 700, 1))
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.LightInfluence = 0.3
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 0.5
			gui.ClipsDescendants = true
			gui.Adornee = part
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.new(1, 260, 1, 0)
			img.Image = Common.tex(ctx, "Sheet")
			img.ScaleType = Enum.ScaleType.Tile
			img.TileSize = UDim2.fromOffset(130, 350)
			img.ImageColor3 = Color3.fromRGB(150, 158, 168)
			img.ImageTransparency = 1
			img.Parent = gui
			gui.Parent = part
			table.insert(wallImg, img)
		end
		table.insert(panels, part)
	end

	-- sun shafts down the eye
	local sun = Instance.new("SunRaysEffect")
	sun.Name = "EyeRays"
	sun.Intensity = 0
	sun.Spread = 0.5
	sun.Parent = Lighting
	local eyeGrade = Instance.new("ColorCorrectionEffect")
	eyeGrade.Name = "EyeGrade"
	eyeGrade.Parent = Lighting
	local slam = Instance.new("ColorCorrectionEffect")
	slam.Name = "BackWallSlam"
	slam.Parent = Lighting
	table.insert(ctx.cleanup, function()
		Common.tween(sun, Common.FADE, { Intensity = 0 })
		Common.tween(eyeGrade, Common.FADE, { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
		task.delay(Common.FADE + 0.5, function()
			sun:Destroy()
			eyeGrade:Destroy()
			slam:Destroy()
		end)
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exposedNow = true
	local check = 0
	local shake = 0
	local calm = 0 -- 0 storm .. 1 in the eye
	local spin = 0
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")

	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local now = Workspace:GetServerTimeNow()
		windDir = (Workspace:GetAttribute("WindDir") :: Vector3?) or windDir
		local target = tonumber(Workspace:GetAttribute("WindStrength")) or 1
		strength += (target - strength) * math.min(1, dt * 1.5)
		local eyeAt = tonumber(Workspace:GetAttribute("HurricaneEyeAt"))
		local eyeEnd = tonumber(Workspace:GetAttribute("HurricaneEyeEnd"))
		local track = (Workspace:GetAttribute("HurricaneTrack") :: Vector3?) or Vector3.new(1, 0, 0)

		-- where the eye is: it crosses the island at a steady pace, centred on the calm
		local eyePos = centre
		if eyeAt and eyeEnd then
			local mid = (eyeAt + eyeEnd) / 2
			local speed = (EYE_CLEAR * 2) / math.max(4, eyeEnd - eyeAt)
			eyePos = centre + track * (now - mid) * speed
		end
		spin += dt * 0.02
		local sc = CFrame.new(eyePos.X, SPIRAL_HEIGHT, eyePos.Z) * CFrame.Angles(0, spin, 0)
		for _, tile in tiles do
			tile.part.CFrame = sc * tile.offset
		end
		local inEye = eyeAt ~= nil and eyeEnd ~= nil and now >= eyeAt and now < eyeEnd
		calm += ((if inEye then 1 else 0) - calm) * math.min(1, dt * (if inEye then 0.6 else 3))
		for i, part in panels do
			local a = (i / PANELS) * math.pi * 2 + spin * 3
			local p = eyePos + Vector3.new(math.cos(a), 0, math.sin(a)) * wallRadius + Vector3.new(0, 330, 0)
			part.CFrame = CFrame.lookAt(p, Vector3.new(eyePos.X, 330, eyePos.Z))
		end
		local dToEye = (Vector3.new(camPos.X, 0, camPos.Z) - eyePos).Magnitude
		local wallShow = math.clamp(1 - math.abs(dToEye - EYE_CLEAR) / 900, 0, 1) * ramp
		local slide = -((spin * 4000) % 130)
		for _, img in wallImg do
			img.ImageTransparency = 1 - 0.85 * math.max(wallShow, calm)
			img.Position = UDim2.fromOffset(slide, 0)
		end

		-- the weather, with the eye taking it all away
		local storm = math.clamp(strength, 0, 1.3) * ramp
		local blowing = windDir * (60 + 80 * storm)
		rain.Acceleration = blowing + Vector3.new(0, -20, 0)
		rain.Rate = 2600 * storm
		spray.Rate = 70 * storm
		scud.Rate = 14 * storm
		leaves.Rate = 40 * storm
		local box = spray.Parent :: BasePart
		box.CFrame = CFrame.lookAt(camPos, camPos + windDir)
		local sbox = scud.Parent :: BasePart
		sbox.CFrame = CFrame.lookAt(camPos + Vector3.new(0, 25, 0), camPos + Vector3.new(0, 25, 0) + windDir)
		local lbox = leaves.Parent :: BasePart
		lbox.CFrame = CFrame.lookAt(camPos, camPos + windDir)
		sun.Intensity = 0.35 * calm
		eyeGrade.Brightness = 0.08 * calm
		eyeGrade.Contrast = 0.05 * calm
		eyeGrade.Saturation = 0.45 * calm
		eyeGrade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 240, 215), calm)
		if clouds and calm > 0.01 then
			clouds.Cover = 1 - 0.6 * calm -- (Common.clouds puts the sky back afterwards)
		end
		slam.Brightness += (0 - slam.Brightness) * math.min(1, dt * 1.5)
		slam.Saturation += (0 - slam.Saturation) * math.min(1, dt * 1.5)

		-- the wind leans on you
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if character and root and root:IsA("BasePart") and hum and hum.Health > 0 then
			check -= dt
			if check <= 0 then
				check = 0.25
				params.FilterDescendantsInstances = { character, ctx.folder }
				exposedNow = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
			end
			if exposedNow and storm > 0.05 then
				local along = hum.MoveDirection:Dot(windDir)
				local speed = if hum.MoveDirection.Magnitude < 0.1 then 2.5 elseif along < -0.3 then 7 else 4
				local gust = 0.75 + 0.35 * math.sin(now * 1.7) + 0.2 * math.sin(now * 4.3)
				root.CFrame += windDir * speed * gust * storm * dt
			end
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local amt = (if exposedNow then 1 else 0.4) * storm
			shake = math.max(0, shake - dt * 0.7)
			camera.CFrame *= CFrame.Angles(
				(rnd:NextNumber() - 0.5) * (0.006 * amt + 0.04 * shake),
				(rnd:NextNumber() - 0.5) * (0.006 * amt + 0.04 * shake),
				math.sin(now * 1.3) * 0.01 * amt
			)
		end
	end)
	table.insert(ctx.cleanup, function()
		for _, tile in tiles do
			Common.tween(tile.img, Common.FADE, { ImageTransparency = 1 })
		end
		for _, img in wallImg do
			Common.tween(img, Common.FADE, { ImageTransparency = 1 })
		end
	end)

	-- debris tumbling in on the wind (the same event and models as the Gale)
	local function template(kind: string): Model?
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local m = assets and assets:FindFirstChild(kind)
		return if m and m:IsA("Model") then m else nil
	end
	local function debris(data: { [string]: any })
		local from = data.from :: Vector3
		local to = data.to :: Vector3
		local seconds = tonumber(data.seconds) or 2
		local radius = tonumber(data.radius) or 6
		local r = Random.new(tonumber(data.seed) or 1)
		local t = template(tostring(data.kind))
		if not t then
			return
		end
		local m = t:Clone()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
			end
		end
		m.Parent = ctx.folder
		local spinV = Vector3.new(r:NextNumber(-10, 10), r:NextNumber(-10, 10), r:NextNumber(-10, 10))
		local beyond = to + (to - from).Unit * 140 + Vector3.new(0, -20, 0)
		local t0 = os.clock()
		local hitDone = false
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local e = os.clock() - t0
			local pos: Vector3
			if e < seconds then
				local k = e / seconds
				pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 8, 0)
			else
				local k = math.min(1, (e - seconds) / (seconds * 0.9))
				pos = to:Lerp(beyond, k)
				if k >= 1 then
					conn:Disconnect()
					m:Destroy()
					return
				end
			end
			m:PivotTo(CFrame.new(pos) * CFrame.Angles(spinV.X * e, spinV.Y * e, spinV.Z * e))
			if not hitDone and e >= seconds then
				hitDone = true
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and hum and (root.Position - to).Magnitude < radius then
					hum:ChangeState(Enum.HumanoidStateType.FallingDown)
					root.AssemblyLinearVelocity += (to - from).Unit * 45 + Vector3.new(0, 18, 0)
					shake = math.max(shake, 1)
					task.delay(1.2, function()
						if hum.Health > 0 then
							hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						end
					end)
				end
			end
		end)
		table.insert(ctx.cleanup, function()
			if conn.Connected then
				conn:Disconnect()
				m:Destroy()
			end
		end)
	end

	-- the back wall
	local function backWall(data: { [string]: any })
		shake = 1.5
		slam.Brightness = -0.25
		slam.Saturation = -0.5
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if exposedNow and root and root:IsA("BasePart") and hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.FallingDown)
			root.AssemblyLinearVelocity += (data.dir :: Vector3) * 55 + Vector3.new(0, 20, 0)
			task.delay(1.5, function()
				if hum.Parent and hum.Health > 0 then
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
		end
		-- a burst of rain and spray all at once
		rain:Emit(800)
		spray:Emit(120)
	end

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Debris" and typeof(data.from) == "Vector3" and typeof(data.to) == "Vector3" then
			debris(data)
		elseif kind == "BackWall" and typeof(data.dir) == "Vector3" then
			backWall(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
