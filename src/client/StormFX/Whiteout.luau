--!strict
-- Whiteout (Severe): a blizzard. Snow (Blender: snowflake) drives sideways past you in thick
-- flurries, ground drift streams along the floor, and the island turns white under it (the
-- terrain's grass, sand, rock and earth are tinted to snow for the storm). The cold creeps in
-- (player attribute "Chill"): frost over your sight, your breath steaming, shivering. When the
-- snow closes in ("WhiteoutUntil") the world goes white to arm's length, and then the tracks come
-- (StormEvent "Tracks"): clawed footprints (Blender: footprint) pressing into the snow one by
-- one, walking straight at you out of the white.
-- Textures: Blender (Whiteout: snowflake, footprint) + Hailstorm frost, Rolling Thunder smoke,
-- Drizzle haze.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local SNOW = Color3.fromRGB(235, 242, 250)
local SNOW_MATERIALS = {
	[Enum.Material.Grass] = Color3.fromRGB(225, 232, 240),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(220, 228, 236),
	[Enum.Material.Ground] = Color3.fromRGB(210, 216, 224),
	[Enum.Material.Mud] = Color3.fromRGB(200, 206, 214),
	[Enum.Material.Sand] = Color3.fromRGB(232, 236, 242),
	[Enum.Material.Rock] = Color3.fromRGB(190, 198, 208),
	[Enum.Material.Slate] = Color3.fromRGB(185, 192, 202),
}

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer
	local wind = Vector3.new(1, 0, 0.35).Unit

	local snow = Common.fall(ctx, "Snow", {
		Texture = Common.tex(ctx, "Flake"),
		Rate = 900,
		Size = ns(0, 0.35, 1, 0.35),
		Brightness = 1.2,
		Color = ColorSequence.new(SNOW),
		Speed = NumberRange.new(20, 30),
		Slant = wind * 60,
		Orientation = Enum.ParticleOrientation.FacingCamera,
	})
	snow.LightInfluence = 0.6
	snow.RotSpeed = NumberRange.new(-200, 200)
	local flurry = Common.around(ctx, "Flurry", Vector3.new(40, 16, 40), {
		Texture = Common.tex(ctx, "Flake"),
		Rate = 220,
		LightEmission = 0.2,
		LightInfluence = 0.7,
		Color = ColorSequence.new(SNOW),
		Size = ns(0, 0.2, 1, 0.2),
		Transparency = ns(0, 1, 0.1, 0, 0.85, 0, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(30, 45),
		Spread = Vector2.new(8, 8),
		RotSpeed = NumberRange.new(-300, 300),
	})
	flurry.EmissionDirection = Enum.NormalId.Front
	local drift = Common.around(ctx, "Drift", Vector3.new(120, 4, 120), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 22,
		LightEmission = 0.1,
		LightInfluence = 0.9,
		Color = ColorSequence.new(SNOW),
		Size = ns(0, 6, 1, 14),
		Transparency = ns(0, 1, 0.3, 0.6, 0.7, 0.6, 1, 1),
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(14, 22),
		Spread = Vector2.new(5, 2),
		Offset = Vector3.new(0, -8, 0),
	})
	drift.EmissionDirection = Enum.NormalId.Front
	Common.clouds(ctx, { Cover = 1, Density = 0.85, Color = Color3.fromRGB(215, 222, 232) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(230, 240, 255),
		Saturation = -0.45,
		Brightness = 0.04,
		Contrast = -0.05,
		Bloom = 0.5,
		BloomThreshold = 1.2,
	})

	-- the island turns white
	local terrain = Workspace.Terrain
	local before: { [Enum.Material]: Color3 } = {}
	for mat in SNOW_MATERIALS do
		local ok, c = pcall(function()
			return terrain:GetMaterialColor(mat)
		end)
		if ok then
			before[mat] = c
		end
	end
	local snowCover = 0
	local function cover(k: number)
		for mat, white in SNOW_MATERIALS do
			local was = before[mat]
			if was then
				terrain:SetMaterialColor(mat, was:Lerp(white, k))
			end
		end
	end
	table.insert(ctx.cleanup, function()
		-- melt back over a couple of seconds, then make sure it's exactly as it was
		task.spawn(function()
			local k = snowCover
			while k > 0 do
				k = math.max(0, k - 0.05)
				cover(k)
				task.wait(0.1)
			end
			for mat, c in before do
				terrain:SetMaterialColor(mat, c)
			end
		end)
	end)

	-- chill: frost over your sight, breath, shivering
	local gui = Instance.new("ScreenGui")
	gui.Name = "Whiteout"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local white = Instance.new("Frame")
	white.BorderSizePixel = 0
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = Color3.fromRGB(236, 240, 246)
	white.BackgroundTransparency = 1
	white.Parent = gui
	local frost = Instance.new("ImageLabel")
	frost.BackgroundTransparency = 1
	frost.Size = UDim2.fromScale(1, 1)
	frost.Image = Common.tex(ctx, "Frost")
	frost.ImageColor3 = Color3.fromRGB(200, 230, 255)
	frost.ImageTransparency = 1
	frost.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(white, Common.FADE, { BackgroundTransparency = 1 })
		Common.tween(frost, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)
	local breath = Instance.new("ParticleEmitter")
	breath.Texture = Common.tex(ctx, "Smoke")
	breath.Color = ColorSequence.new(Color3.new(1, 1, 1))
	breath.LightInfluence = 1
	breath.Size = ns(0, 0.4, 1, 1.8)
	breath.Transparency = ns(0, 0.55, 1, 1)
	breath.Lifetime = NumberRange.new(0.8, 1.2)
	breath.Speed = NumberRange.new(1.5, 3)
	breath.SpreadAngle = Vector2.new(15, 15)
	breath.Rate = 0
	local breathAt: Attachment? = nil
	local gone = false
	table.insert(ctx.cleanup, function()
		gone = true
		breath:Destroy()
		if breathAt then
			breathAt:Destroy()
		end
	end)

	-- tracks walking out of the white
	local function tracks(data: { [string]: any })
		local from: Vector3, to: Vector3 = data.from, data.to
		local steps = math.max(1, math.floor(tonumber(data.steps) or 10))
		local pace = tonumber(data.pace) or 0.32
		local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local probe = RaycastParams.new()
		probe.FilterType = Enum.RaycastFilterType.Include
		probe.FilterDescendantsInstances = { Workspace.Terrain }
		task.spawn(function()
			for i = 0, steps do
				local p = from:Lerp(to, i / steps) + side * (if i % 2 == 0 then 0.9 else -0.9)
				local hit = Workspace:Raycast(p + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), probe)
				if hit then
					-- a little above the ground, so the grass under the snow doesn't swallow it
					local print_ = Common.part(ctx, "Print", Vector3.new(3.2, 0.1, 3.7))
					print_.CFrame = CFrame.lookAt(hit.Position + Vector3.new(0, 0.7, 0), hit.Position + Vector3.new(0, 0.7, 0) + dir) * CFrame.Angles(0, if i % 2 == 0 then 0.12 else -0.12, 0)
					local d = Instance.new("Decal")
					d.Texture = Common.tex(ctx, "Print")
					d.Face = Enum.NormalId.Top
					d.Transparency = 1
					d.Parent = print_
					Common.tween(d, 0.15, { Transparency = 0.1 })
					local puff = Instance.new("ParticleEmitter")
					puff.Texture = Common.tex(ctx, "Haze")
					puff.Color = ColorSequence.new(SNOW)
					puff.LightInfluence = 0.9
					puff.Size = ns(0, 1, 1, 3)
					puff.Transparency = ns(0, 0.4, 1, 1)
					puff.Lifetime = NumberRange.new(0.5, 0.8)
					puff.Speed = NumberRange.new(2, 4)
					puff.SpreadAngle = Vector2.new(60, 60)
					puff.EmissionDirection = Enum.NormalId.Top
					puff.Rate = 0
					puff.Parent = print_
					puff:Emit(6)
					task.delay(10, function()
						Common.tween(d, 3, { Transparency = 1 })
						task.delay(3.2, function()
							print_:Destroy()
						end)
					end)
				end
				task.wait(pace)
			end
		end)
	end

	local chillShown = 0
	local whiteShown = 0
	local coverClock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		-- snow settles over the first part of the storm (terrain recolours are costly: 4 a second)
		coverClock += dt
		if coverClock >= 0.25 then
			if math.abs(ramp - snowCover) > 0.01 then
				snowCover += (ramp - snowCover) * math.min(1, coverClock * 0.4)
				cover(snowCover)
			end
			coverClock = 0
		end
		local box = flurry.Parent :: BasePart
		box.CFrame = CFrame.lookAt(camPos - wind * 20, camPos)
		local dbox = drift.Parent :: BasePart
		dbox.CFrame = CFrame.lookAt(camPos + Vector3.new(0, -8, 0) - wind * 50, camPos + Vector3.new(0, -8, 0))
		-- the white-out
		local untilT = tonumber(Workspace:GetAttribute("WhiteoutUntil"))
		local closed = untilT ~= nil and Workspace:GetServerTimeNow() < untilT
		whiteShown += ((if closed then 1 else 0) - whiteShown) * math.min(1, dt * (if closed then 1.5 else 0.8))
		white.BackgroundTransparency = 1 - (0.12 + 0.7 * whiteShown) * ramp
		snow.Rate = (900 + 2200 * whiteShown) * ramp
		flurry.Rate = (220 + 600 * whiteShown) * ramp
		-- chill
		local chill = tonumber(player:GetAttribute("Chill")) or 0
		chillShown += (chill - chillShown) * math.min(1, dt * 2)
		local frozen = chill >= 1
		local pulse = if frozen then 0.15 * (0.5 + 0.5 * math.sin(os.clock() * 6)) else 0
		frost.ImageTransparency = 1 - math.clamp(chillShown * 0.9 + pulse, 0, 0.95) * ramp
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") and not gone then
			if not breathAt or breathAt.Parent ~= head then
				breathAt = Instance.new("Attachment")
				breathAt.Position = Vector3.new(0, -0.2, -0.7)
				breathAt.Parent = head
				breath.Parent = breathAt
			end
			breath.Rate = (2 + 4 * chillShown) * ramp
		end
		local camera = Workspace.CurrentCamera
		if camera and chillShown > 0.55 then
			local s = (chillShown - 0.55) * 0.014
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * s, (rnd:NextNumber() - 0.5) * s, 0)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Tracks" and typeof(data) == "table" and typeof(data.from) == "Vector3" and typeof(data.to) == "Vector3" then
			tracks(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
