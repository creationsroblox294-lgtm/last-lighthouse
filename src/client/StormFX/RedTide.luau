--!strict
-- Red Tide (Severe): the sea has turned to blood. The water goes a deep, glossy red, laced with
-- swirling bloom (Blender: algae), and a low red mist hangs over it. Even the lighthouse beam
-- comes out red. Step into the water and it burns: the screen floods red and the edges bubble.
-- When the tide surges (StormEvent "RedSurge") a stretch of the sea swells and boils for a
-- couple of seconds, then a red wave rolls up the beach. The stain (player attribute "Stained")
-- keeps burning after you're out. When the Drowned climb out (StormEvent "DrownedRise") the
-- water at the shore boils red where they come up.
-- Textures: Blender (Red Tide: algae) + Drizzle haze, Bountiful Tide foam, Silent Fog vignette,
-- Golden Rain splash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local BLOOD = Color3.fromRGB(150, 12, 18)
local BRIGHT = Color3.fromRGB(255, 60, 50)
local MIST = Color3.fromRGB(150, 40, 45)

return function(ctx: Common.Ctx)
	local player = Players.LocalPlayer
	local rnd = Random.new()

	-- the water itself
	local terrain = Workspace.Terrain
	local water = {
		WaterColor = terrain.WaterColor,
		WaterTransparency = terrain.WaterTransparency,
		WaterReflectance = terrain.WaterReflectance,
		WaterWaveSize = terrain.WaterWaveSize,
		WaterWaveSpeed = terrain.WaterWaveSpeed,
	}
	Common.tween(terrain, Common.FADE, {
		WaterColor = BLOOD,
		WaterTransparency = 0.12,
		WaterReflectance = 0.5,
		WaterWaveSize = 0.2,
		WaterWaveSpeed = 6,
	})
	table.insert(ctx.cleanup, function()
		Common.tween(terrain, Common.FADE, water)
	end)

	-- the lighthouse beam comes out red
	local lv = Workspace:FindFirstChild("LightVisuals")
	local beamPart = lv and lv:FindFirstChild("Beam")
	if beamPart and beamPart:IsA("BasePart") then
		local spot = beamPart:FindFirstChildOfClass("SpotLight")
		local was, spotWas = beamPart.Color, spot and spot.Color
		Common.tween(beamPart, Common.FADE, { Color = Color3.fromRGB(255, 120, 105) })
		if spot then
			Common.tween(spot, Common.FADE, { Color = Color3.fromRGB(255, 120, 105) })
		end
		table.insert(ctx.cleanup, function()
			Common.tween(beamPart, Common.FADE, { Color = was })
			if spot and spotWas then
				Common.tween(spot, Common.FADE, { Color = spotWas })
			end
		end)
	end

	-- bloom drifting on the surface and a low red mist over the sea, kept at the waterline
	local surface = Common.part(ctx, "Bloom", Vector3.new(220, 1, 220))
	local bloom = Instance.new("ParticleEmitter")
	bloom.Texture = Common.tex(ctx, "Algae")
	bloom.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	bloom.Color = ColorSequence.new(Color3.fromRGB(230, 70, 60), BLOOD)
	bloom.LightInfluence = 0.6
	bloom.LightEmission = 0.15
	bloom.Size = ns(0, 10, 1, 22)
	bloom.Transparency = ns(0, 1, 0.3, 0.35, 0.7, 0.35, 1, 1)
	bloom.Lifetime = NumberRange.new(6, 9)
	bloom.Speed = NumberRange.new(0.01, 0.02)
	bloom.EmissionDirection = Enum.NormalId.Top
	bloom.Rotation = NumberRange.new(0, 360)
	bloom.RotSpeed = NumberRange.new(-6, 6)
	bloom.Rate = 0
	bloom.Parent = surface
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = Common.tex(ctx, "Haze")
	mist.Color = ColorSequence.new(MIST)
	mist.LightInfluence = 0.8
	mist.Size = ns(0, 16, 1, 30)
	mist.Transparency = ns(0, 1, 0.3, 0.7, 0.7, 0.7, 1, 1)
	mist.Lifetime = NumberRange.new(5, 8)
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.Rate = 0
	mist.Parent = surface
	-- only over water: sample a few points under the box so the bloom doesn't draw on land
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = { terrain }
	probe.IgnoreWater = false
	local overSea = 0
	local probeAt = 0

	Common.clouds(ctx, { Cover = 0.85, Density = 0.55, Color = Color3.fromRGB(140, 70, 70) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 215, 205),
		Saturation = -0.1,
		Brightness = -0.03,
		Contrast = 0.22,
		Bloom = 0.7,
		BloomThreshold = 1.1,
	})

	-- burning: red flood and bubbling edges
	local gui = Instance.new("ScreenGui")
	gui.Name = "RedBurn"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local edge = Instance.new("ImageLabel")
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Image = Common.tex(ctx, "Vignette")
	edge.ImageColor3 = Color3.fromRGB(220, 10, 10)
	edge.ImageTransparency = 1
	edge.Parent = gui
	local wash = Instance.new("ImageLabel")
	wash.BackgroundTransparency = 1
	wash.Size = UDim2.new(1, 256, 1, 256)
	wash.Position = UDim2.fromOffset(-128, -128)
	wash.Image = Common.tex(ctx, "Algae")
	wash.ScaleType = Enum.ScaleType.Tile
	wash.TileSize = UDim2.fromOffset(256, 256)
	wash.ImageColor3 = BRIGHT
	wash.ImageTransparency = 1
	wash.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(edge, Common.FADE, { ImageTransparency = 1 })
		Common.tween(wash, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	-- boiling water: a burst of red froth and steam at a point on the sea
	local function boil(at: Vector3, size: number, count: number, seconds: number)
		local holder = Common.part(ctx, "Boil", Vector3.new(size, 1, size))
		holder.CFrame = CFrame.new(at.X, 0.6, at.Z)
		local froth = Instance.new("ParticleEmitter")
		froth.Texture = Common.tex(ctx, "Foam")
		froth.Color = ColorSequence.new(BRIGHT, BLOOD)
		froth.LightInfluence = 0.5
		froth.LightEmission = 0.2
		froth.Size = ns(0, 2, 1, 6)
		froth.Transparency = ns(0, 0.2, 1, 1)
		froth.Lifetime = NumberRange.new(0.6, 1.2)
		froth.Speed = NumberRange.new(4, 12)
		froth.SpreadAngle = Vector2.new(40, 40)
		froth.Acceleration = Vector3.new(0, -20, 0)
		froth.Rate = count / seconds
		froth.Parent = holder
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = Common.tex(ctx, "Haze")
		steam.Color = ColorSequence.new(MIST)
		steam.LightInfluence = 0.8
		steam.Size = ns(0, 6, 1, 18)
		steam.Transparency = ns(0, 0.5, 1, 1)
		steam.Lifetime = NumberRange.new(1.5, 2.5)
		steam.Speed = NumberRange.new(3, 6)
		steam.Rate = count / seconds / 4
		steam.Parent = holder
		task.delay(seconds, function()
			froth.Rate = 0
			steam.Rate = 0
		end)
		task.delay(seconds + 3, function()
			holder:Destroy()
		end)
	end

	-- the surge: the sea swells and boils, then a red wave runs up the beach
	local function surge(data: { [string]: any })
		local at: Vector3, dir: Vector3 = data.at, data.dir
		local width: number, reach: number, warn: number = data.width, data.reach, data.warn
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for i = -2, 2 do
			boil(at - dir * 25 + side * (i * width / 5), width / 5, 80, warn)
		end
		task.delay(warn, function()
			-- a wedge: the sloped face leads, so it reads as a wave front sliding up the sand
			local wave = Instance.new("WedgePart")
			wave.Name = "RedWave"
			wave.Anchored = true
			wave.CanCollide = false
			wave.CanQuery = false
			wave.CanTouch = false
			wave.CastShadow = false
			wave.Size = Vector3.new(width, 5, 10)
			wave.Parent = ctx.folder
			wave.Material = Enum.Material.Glass
			wave.Color = BLOOD
			wave.Transparency = 0.25
			wave.Reflectance = 0.2
			local tex = Instance.new("Texture")
			tex.Texture = Common.tex(ctx, "Algae")
			tex.Face = Enum.NormalId.Front
			tex.StudsPerTileU = 30
			tex.StudsPerTileV = 30
			tex.Color3 = BRIGHT
			tex.Parent = wave
			local spray = Instance.new("ParticleEmitter")
			spray.Texture = Common.tex(ctx, "Foam")
			spray.Color = ColorSequence.new(BRIGHT, BLOOD)
			spray.LightInfluence = 0.5
			spray.Size = ns(0, 3, 1, 8)
			spray.Transparency = ns(0, 0.2, 1, 1)
			spray.Lifetime = NumberRange.new(0.5, 1)
			spray.Speed = NumberRange.new(10, 20)
			spray.SpreadAngle = Vector2.new(30, 30)
			spray.EmissionDirection = Enum.NormalId.Front
			spray.Acceleration = Vector3.new(0, -30, 0)
			spray.Rate = 160
			spray.Parent = wave
			local t0 = os.clock()
			local run = 1.6
			local conn: RBXScriptConnection
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local k = math.min(1, (os.clock() - t0) / run)
				local ease = 1 - (1 - k) ^ 2
				local p = at - dir * 20 + dir * (reach + 20) * ease
				-- hug the ground under the wave front
				local hit = Workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), probe)
				local y = if hit then hit.Position.Y else at.Y
				wave.Size = Vector3.new(width * (1 - 0.3 * k), 5 * (1 - k) + 0.5, 10 + 20 * ease)
				wave.CFrame = CFrame.lookAt(Vector3.new(p.X, y + wave.Size.Y / 2 - 0.5, p.Z), Vector3.new(p.X, y, p.Z) + dir)
				wave.Transparency = 0.25 + 0.7 * math.max(0, (k - 0.6) / 0.4)
				tex.Transparency = wave.Transparency
				spray.Rate = 160 * (1 - k)
				if k >= 1 then
					conn:Disconnect()
					task.delay(1.2, function()
						wave:Destroy()
					end)
				end
			end)
			table.insert(ctx.cleanup, function()
				if conn.Connected then
					conn:Disconnect()
					wave:Destroy()
				end
			end)
			local camera = Workspace.CurrentCamera
			if camera and (camera.CFrame.Position - at).Magnitude < 140 then
				local shake = 1
				task.spawn(function()
					while shake > 0 do
						shake -= 0.05
						local cam = Workspace.CurrentCamera
						if cam then
							cam.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.02 * shake, (rnd:NextNumber() - 0.5) * 0.02 * shake, 0)
						end
						task.wait()
					end
				end)
			end
		end)
	end

	local burn = 0
	local scroll = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		scroll += dt
		-- keep the bloom box on the water under the camera
		surface.CFrame = CFrame.new(camPos.X, 0.4, camPos.Z)
		probeAt -= dt
		if probeAt <= 0 then
			probeAt = 0.5
			local wet = 0
			for _, o in { Vector3.zero, Vector3.new(60, 0, 0), Vector3.new(-60, 0, 0), Vector3.new(0, 0, 60), Vector3.new(0, 0, -60) } do
				local hit = Workspace:Raycast(Vector3.new(camPos.X + o.X, 100, camPos.Z + o.Z), Vector3.new(0, -200, 0), probe)
				if not hit or hit.Material == Enum.Material.Water then
					wet += 1
				end
			end
			overSea = wet / 5
		end
		bloom.Rate = 14 * overSea * ramp
		mist.Rate = 8 * overSea * ramp
		-- burning while in the water or stained
		local stained = player:GetAttribute("Stained") :: number?
		local hot = stained ~= nil and Workspace:GetServerTimeNow() < stained
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum and hum:GetState() == Enum.HumanoidStateType.Swimming then
			hot = true
		end
		burn += ((if hot then 1 else 0) - burn) * math.min(1, dt * 4)
		local pulse = 0.5 + 0.5 * math.sin(scroll * 9)
		edge.ImageTransparency = 1 - burn * (0.55 + 0.3 * pulse)
		wash.ImageTransparency = 1 - burn * 0.35
		wash.Position = UDim2.fromOffset(-128 + (scroll * 40) % 256, -128 + (scroll * 25) % 256)
		if burn > 0.3 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.008 * burn, (rnd:NextNumber() - 0.5) * 0.008 * burn, 0)
			end
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "RedSurge" and typeof(data.at) == "Vector3" and typeof(data.dir) == "Vector3" then
			surge(data)
		elseif kind == "DrownedRise" and typeof(data.at) == "Vector3" then
			boil(data.at, 24, 60, 1.5)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
