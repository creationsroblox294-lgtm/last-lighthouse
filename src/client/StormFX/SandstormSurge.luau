--!strict
-- Sandstorm Surge (Moderate): a hot ochre gale (Workspace attribute "WindDir") drives streams of
-- sand across the island in low, hissing sheets. Step onto a beach and it flays you: the screen
-- fills with grit and the world shakes. Then a surge (StormEvent "SandSurge"): far out at sea a
-- brown wall of boiling dust rises, hundreds of studs tall, and comes racing in. The ground
-- rumbles harder as it closes. When it hits, everything goes dark brown and roaring; out in the
-- open it bowls you clean over (StormEvent "SurgeHit"). Then it rolls on inland and the air
-- slowly clears, and out on the stripped beaches things glint in the sand.
-- Textures: Blender (Sandstorm Surge: sand wall, grit) + Sea Breeze streak, Drizzle haze,
-- Fish Rain glint, Rolling Thunder smoke.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local SAND = Color3.fromRGB(214, 168, 104)
local DUST = Color3.fromRGB(170, 120, 70)
local WALL = Color3.fromRGB(165, 110, 62)
local HEIGHT = 380
local LAYERS = 3 -- parallax layers in the face of a surge
local BEHIND = 170 -- how deep the blinding dust is behind the front

type Surge = { start: Vector3, dir: Vector3, speed: number, t0: number, planes: { BasePart }, textures: { Texture }, base: BasePart, billow: ParticleEmitter }

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer
	local windDir: Vector3 = (Workspace:GetAttribute("WindDir") :: Vector3?) or Vector3.new(1, 0, 0)
	local surges: { Surge } = {}

	-- sand streaming along the ground and through the air
	local grit = Common.around(ctx, "Grit", Vector3.new(120, 14, 120), {
		Texture = Common.tex(ctx, "Grit"),
		Rate = 160,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(SAND),
		Size = ns(0, 0.6, 1, 1.2),
		Transparency = ns(0, 1, 0.15, 0.2, 0.85, 0.3, 1, 1),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(2, 6),
		Acceleration = windDir * 70,
		Offset = Vector3.new(0, -6, 0),
	})
	local streaks = Common.around(ctx, "Streaks", Vector3.new(100, 30, 100), {
		Texture = Common.tex(ctx, "Streak"),
		Rate = 40,
		LightEmission = 0.2,
		LightInfluence = 0.8,
		Color = ColorSequence.new(SAND),
		Size = ns(0, 2, 1, 3),
		Transparency = ns(0, 1, 0.3, 0.5, 0.7, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(60, 85),
		Spread = Vector2.new(0, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Offset = Vector3.new(0, 2, 0),
	})
	streaks.EmissionDirection = Enum.NormalId.Front
	local drift = Common.around(ctx, "Drift", Vector3.new(160, 30, 160), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 10,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(DUST),
		Size = ns(0, 18, 1, 30),
		Transparency = ns(0, 1, 0.3, 0.75, 0.7, 0.75, 1, 1),
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(1, 3),
		Acceleration = windDir * 10,
	})
	Common.clouds(ctx, { Cover = 0.9, Density = 0.6, Color = Color3.fromRGB(190, 145, 95) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 222, 180),
		Saturation = -0.1,
		Brightness = 0.02,
		Contrast = 0.12,
		Bloom = 0.5,
		BloomThreshold = 1.2,
		Rays = 0.08,
	})

	-- point the streak box down the wind every frame (around() only moves it)
	local streakBox = streaks.Parent :: BasePart
	table.insert(ctx.onFrame, function(_dt, camPos, _ramp)
		streakBox.CFrame = CFrame.lookAt(camPos + Vector3.new(0, 2, 0), camPos + Vector3.new(0, 2, 0) + windDir)
	end)

	-- the brown-out inside a surge, and the grit on your screen on the beach
	local dark = Instance.new("ColorCorrectionEffect")
	dark.Name = "SurgeDark"
	dark.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "SurgeBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local gui = Instance.new("ScreenGui")
	gui.Name = "Sandblast"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local veil = Instance.new("Frame")
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = DUST
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	local scour = Instance.new("ImageLabel")
	scour.BackgroundTransparency = 1
	scour.Size = UDim2.new(1, 192, 1, 192)
	scour.Image = Common.tex(ctx, "Grit")
	scour.ScaleType = Enum.ScaleType.Tile
	scour.TileSize = UDim2.fromOffset(96, 96)
	scour.ImageColor3 = SAND
	scour.ImageTransparency = 1
	scour.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(dark, Common.FADE, { Brightness = 0, Saturation = 0, Contrast = 0 })
		Common.tween(blur, Common.FADE, { Size = 0 })
		Common.tween(veil, Common.FADE, { BackgroundTransparency = 1 })
		Common.tween(scour, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			dark:Destroy()
			blur:Destroy()
			gui:Destroy()
		end)
	end)

	local function plane(i: number): (BasePart, { Texture })
		local p = Common.part(ctx, "SurgeFace", Vector3.new(2200, HEIGHT, 1))
		local texs = {}
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local t = Instance.new("Texture")
			t.Texture = Common.tex(ctx, "SandWall")
			t.Face = face
			t.StudsPerTileU = 260 + i * 70
			t.StudsPerTileV = HEIGHT
			t.Color3 = WALL:Lerp(Color3.fromRGB(110, 70, 40), (i - 1) / LAYERS)
			t.Transparency = 1
			t.ZIndex = LAYERS - i
			t.Parent = p
			table.insert(texs, t)
		end
		return p, texs
	end

	local function addSurge(data: { [string]: any })
		local planes, textures = {}, {}
		for i = 1, LAYERS do
			local p, texs = plane(i)
			table.insert(planes, p)
			for _, t in texs do
				table.insert(textures, t)
				Common.tween(t, 4, { Transparency = 0.05 + 0.1 * (i - 1) })
			end
		end
		-- the boiling dust kicked up along the foot of the wall
		local base = Common.part(ctx, "SurgeFoot", Vector3.new(700, 30, 30))
		local billow = Instance.new("ParticleEmitter")
		billow.Texture = Common.tex(ctx, "Smoke")
		billow.Color = ColorSequence.new(WALL, DUST)
		billow.LightInfluence = 1
		billow.Size = ns(0, 25, 1, 60)
		billow.Transparency = ns(0, 0.3, 0.7, 0.5, 1, 1)
		billow.Lifetime = NumberRange.new(2, 3)
		billow.Speed = NumberRange.new(20, 40)
		billow.SpreadAngle = Vector2.new(25, 25)
		billow.EmissionDirection = Enum.NormalId.Front
		billow.RotSpeed = NumberRange.new(-40, 40)
		billow.Rotation = NumberRange.new(0, 360)
		billow.Rate = 60
		billow.Parent = base
		table.insert(surges, {
			start = data.start,
			dir = data.dir,
			speed = data.speed,
			t0 = data.t0,
			planes = planes,
			textures = textures,
			base = base,
			billow = billow,
		})
	end

	local function knocked(data: { [string]: any })
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if data.sheltered or not (root and root:IsA("BasePart") and hum and hum.Health > 0) then
			return
		end
		-- players own their own physics, so the shove happens here
		root.AssemblyLinearVelocity += (data.dir :: Vector3) * 60 + Vector3.new(0, 22, 0)
		hum:ChangeState(Enum.HumanoidStateType.FallingDown)
		veil.BackgroundTransparency = 0
		task.delay(1.6, function()
			if hum.Parent and hum.Health > 0 then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end

	-- things glinting in the sand after a surge
	local glints: { Instance } = {}
	local function glint(item: Instance)
		if not item:IsA("BasePart") or not item:GetAttribute("Unearthed") then
			return
		end
		local e = Instance.new("ParticleEmitter")
		e.Name = "UnearthedGlint"
		e.Texture = Common.tex(ctx, "Glint")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190))
		e.LightEmission = 1
		e.Brightness = 5
		e.Size = ns(0, 0, 0.5, 3, 1, 0)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(0)
		e.Rate = 3
		e.Parent = item
		local l = Instance.new("PointLight")
		l.Name = "UnearthedLight"
		l.Color = Color3.fromRGB(255, 220, 150)
		l.Range = 14
		l.Brightness = 2
		l.Parent = item
		table.insert(glints, e)
		table.insert(glints, l)
	end
	local items = Workspace:FindFirstChild("Runtime") and (Workspace :: any).Runtime:FindFirstChild("Items")
	local itemConn: RBXScriptConnection? = nil
	if items then
		for _, it in items:GetChildren() do
			glint(it)
		end
		itemConn = items.ChildAdded:Connect(function(it)
			task.defer(glint, it)
		end)
	end
	table.insert(ctx.cleanup, function()
		if itemConn then
			itemConn:Disconnect()
		end
		for _, g in glints do
			g:Destroy()
		end
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local scroll = 0
	local inside = 0 -- 0 clear .. 1 in the thick of a surge
	local approach = 0 -- 0 nothing coming .. 1 about to hit
	local onBeach = 0
	local exposedNow = true
	local check = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local now = Workspace:GetServerTimeNow()
		scroll += dt
		local nearestAhead = math.huge -- distance to the front of a surge still coming
		local deepest = 0 -- how far into a surge's dust you are (0..1)
		for i = #surges, 1, -1 do
			local s = surges[i]
			local travelled = s.speed * (now - s.t0)
			if travelled > 1600 + BEHIND then
				for _, p in s.planes do
					p:Destroy()
				end
				s.base:Destroy()
				table.remove(surges, i)
			else
				local f = s.start + s.dir * travelled
				local side = Vector3.new(-s.dir.Z, 0, s.dir.X)
				local along = (camPos - f):Dot(side)
				local mid = f + side * along
				for k, p in s.planes do
					-- layered faces, each a little further back, rolling at their own pace
					p.CFrame = CFrame.fromMatrix(mid - s.dir * ((k - 1) * 35) + Vector3.new(0, HEIGHT / 2 - 10, 0), side, Vector3.yAxis)
				end
				for k, t in s.textures do
					local layer = math.ceil(k / 2)
					t.OffsetStudsU = scroll * (12 + layer * 9) * (if layer % 2 == 0 then -1 else 1)
				end
				s.base.CFrame = CFrame.fromMatrix(mid + s.dir * 10 + Vector3.new(0, 10, 0), side, Vector3.yAxis, -s.dir)
				-- fade out as it rolls away at the far side
				if travelled > 1400 then
					local fade = math.clamp((travelled - 1400) / 200, 0, 1)
					for k, t in s.textures do
						local layer = math.ceil(k / 2)
						t.Transparency = math.max(t.Transparency, 0.05 + 0.1 * (layer - 1) + fade)
					end
					s.billow.Rate = 60 * (1 - fade)
				end
				local d = (camPos - f):Dot(s.dir) -- > 0 still ahead of it, < 0 inside / behind it
				if d > 0 then
					nearestAhead = math.min(nearestAhead, d)
				else
					deepest = math.max(deepest, math.clamp(1 + d / BEHIND, 0, 1))
				end
			end
		end
		approach += (math.clamp(1 - nearestAhead / 300, 0, 1) - approach) * math.min(1, dt * 3)
		inside += (deepest - inside) * math.min(1, dt * 4)
		local k = inside * ramp
		dark.Brightness = -0.25 * k
		dark.Saturation = -0.2 * k
		dark.Contrast = 0.15 * k
		dark.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 200, 150), k)
		blur.Size = 10 * k
		-- the veil snaps opaque when you're bowled over, then settles to the depth of the dust
		local veilGoal = 1 - 0.75 * k
		veil.BackgroundTransparency += (veilGoal - veil.BackgroundTransparency) * math.min(1, dt * 1.5)
		grit.Rate = (160 + 900 * k) * ramp

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local beach = false
		if character and root and root:IsA("BasePart") and hum and hum.Health > 0 then
			check -= dt
			if check <= 0 then
				check = 0.25
				params.FilterDescendantsInstances = { character, ctx.folder }
				exposedNow = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
			end
			beach = hum.FloorMaterial == Enum.Material.Sand
			if exposedNow then
				-- the wind leans on you, and hard inside a surge
				root.CFrame += windDir * (1.5 + 6 * k) * ramp * dt
			end
		end
		onBeach += ((if beach then 1 else 0) - onBeach) * math.min(1, dt * 3)
		scour.ImageTransparency = 1 - 0.55 * onBeach * ramp
		scour.Position = UDim2.fromOffset(-96 + (scroll * 900) % 96 * (if windDir.X > 0 then 1 else -1), -96 + (scroll * 130) % 96)
		local camera = Workspace.CurrentCamera
		if camera then
			local shake = math.max(approach * 0.6, k, onBeach * 0.5)
			if shake > 0.02 then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.02 * shake, (rnd:NextNumber() - 0.5) * 0.02 * shake, 0)
			end
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "SandSurge" and typeof(data.start) == "Vector3" and typeof(data.dir) == "Vector3" then
			addSurge(data)
		elseif kind == "SurgeHit" and typeof(data.dir) == "Vector3" then
			knocked(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
		for _, s in surges do
			for _, t in s.textures do
				Common.tween(t, Common.FADE, { Transparency = 1 })
			end
			s.billow.Rate = 0
		end
	end)
end
