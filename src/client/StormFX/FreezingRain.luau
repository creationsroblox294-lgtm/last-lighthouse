--!strict
-- Freezing Rain (Moderate): a cold blue-grey afternoon of sleet. The ground glitters with a
-- glaze of ice, and it's slippery: out in the open you skid when you stop and slide wide
-- round corners. The longer you stay out the colder you get (player attribute "Chill"): frost
-- creeps over your view, your breath steams, you start to shiver, and when you're frozen
-- through the frost pulses blue. When the lamp ices over (Workspace attribute "LampIced") a
-- crust of ice grows over it, until someone chips it off (StormEvent "IceChipped").
-- Textures: Hailstorm pellet/frost + Fish Rain glint + Rolling Thunder smoke + Golden Rain drop/splash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local ICE = Color3.fromRGB(200, 230, 255)
local FROST = Color3.fromRGB(180, 220, 255)
local GRIP = 1.2 -- how fast your feet catch up with where you want to go (lower = icier)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer

	Common.fall(ctx, "Sleet", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1200,
		Size = ns(0, 0.35, 1, 0.35),
		Squash = ns(0, 1.4, 1, 1.4),
		Brightness = 1.4,
		Color = ColorSequence.new(ICE),
		Speed = NumberRange.new(75, 90),
		Slant = Vector3.new(6, 0, 3),
	})
	Common.fall(ctx, "Pellets", {
		Texture = Common.tex(ctx, "Pellet"),
		Rate = 250,
		Size = ns(0, 0.18, 1, 0.18),
		Brightness = 1.4,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Speed = NumberRange.new(80, 95),
		Orientation = Enum.ParticleOrientation.FacingCamera,
	})
	-- the ice glaze glittering on the ground
	Common.around(ctx, "Glaze", Vector3.new(70, 2, 70), {
		Texture = Common.tex(ctx, "Glint"),
		Rate = 45,
		Brightness = 4,
		Color = ColorSequence.new(Color3.new(1, 1, 1), ICE),
		Size = ns(0, 0, 0.5, 0.5, 1, 0),
		Transparency = ns(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(0),
		Offset = Vector3.new(0, -5, 0),
	})
	Common.clouds(ctx, { Cover = 0.95, Density = 0.75, Color = Color3.fromRGB(150, 165, 185) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 232, 255),
		Saturation = -0.35,
		Brightness = 0.02,
		Contrast = 0.18,
		Bloom = 0.8,
		BloomThreshold = 1,
	})

	-- frost over your view as you chill
	local gui = Instance.new("ScreenGui")
	gui.Name = "Chill"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local frost = Instance.new("ImageLabel")
	frost.BackgroundTransparency = 1
	frost.Size = UDim2.fromScale(1, 1)
	frost.Image = Common.tex(ctx, "Frost")
	frost.ImageColor3 = FROST
	frost.ImageTransparency = 1
	frost.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(frost, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	-- breath steaming when you're cold
	local breath = Instance.new("ParticleEmitter")
	breath.Texture = Common.tex(ctx, "Smoke")
	breath.Color = ColorSequence.new(Color3.new(1, 1, 1))
	breath.LightInfluence = 1
	breath.Size = ns(0, 0.4, 1, 1.8)
	breath.Transparency = ns(0, 0.6, 1, 1)
	breath.Lifetime = NumberRange.new(0.8, 1.2)
	breath.Speed = NumberRange.new(1.5, 3)
	breath.SpreadAngle = Vector2.new(15, 15)
	breath.Rate = 0
	local breathAt: Attachment? = nil
	local gone = false

	-- the ice crust on the lamp (StormAssets.IceCrust: a jagged shell hung with icicles)
	local crust: Instance? = nil
	local crustPart: BasePart? = nil
	local function iceOver()
		local l = Common.lamp()
		if not l or crust then
			return
		end
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local template = assets and assets:FindFirstChild("IceCrust")
		local c: BasePart
		if template and template:IsA("Model") then
			local model = template:Clone()
			model:PivotTo(l.CFrame)
			model.Parent = ctx.folder
			crust = model
			c = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		else
			c = Common.part(ctx, "LampIce", l.Size * 1.8)
			c.Shape = Enum.PartType.Ball
			c.CFrame = l.CFrame
			c.Material = Enum.Material.Glass
			c.Color = Color3.fromRGB(165, 215, 255)
			c.Reflectance = 0.25
			crust = c
		end
		crustPart = c
		c.Transparency = 1
		Common.tween(c, 3, { Transparency = 0.35 })
		local glow = Instance.new("Highlight")
		glow.FillColor = Color3.fromRGB(150, 210, 255)
		glow.OutlineColor = Color3.new(1, 1, 1)
		glow.FillTransparency = 1
		glow.OutlineTransparency = 1
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Adornee = c
		glow.Parent = c
		Common.tween(glow, 3, { FillTransparency = 0.55, OutlineTransparency = 0.1 })
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = Common.tex(ctx, "Glint")
		sparkle.Color = ColorSequence.new(ICE)
		sparkle.LightEmission = 1
		sparkle.Brightness = 3
		sparkle.Size = ns(0, 0, 0.5, 0.9, 1, 0)
		sparkle.Lifetime = NumberRange.new(0.5, 1)
		sparkle.Speed = NumberRange.new(0)
		sparkle.Rate = 16
		sparkle.Parent = c
	end
	local function chipped()
		local whole = crust
		local c = crustPart
		crust = nil
		crustPart = nil
		if not (whole and c) then
			return
		end
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = Common.tex(ctx, "Pellet")
		burst.Color = ColorSequence.new(ICE)
		burst.LightEmission = 0.4
		burst.Size = ns(0, 0.6, 1, 0.2)
		burst.Lifetime = NumberRange.new(0.6, 1.1)
		burst.Speed = NumberRange.new(10, 22)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Acceleration = Vector3.new(0, -50, 0)
		burst.RotSpeed = NumberRange.new(-300, 300)
		burst.Rate = 0
		burst.Parent = c
		burst:Emit(70)
		c.Transparency = 1
		for _, d in c:GetChildren() do
			if d:IsA("Highlight") then
				d:Destroy()
			elseif d:IsA("ParticleEmitter") and d ~= burst then
				d.Enabled = false
			end
		end
		task.delay(1.5, function()
			whole:Destroy()
		end)
	end
	if Workspace:GetAttribute("LampIced") then
		iceOver()
	end
	local icedConn = Workspace:GetAttributeChangedSignal("LampIced"):Connect(function()
		if Workspace:GetAttribute("LampIced") then
			iceOver()
		elseif crust then
			chipped()
		end
	end)
	table.insert(ctx.cleanup, function()
		icedConn:Disconnect()
		chipped()
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local slide = Vector3.zero
	local check = 0
	local onIce = false
	local chillShown = 0
	table.insert(ctx.onFrame, function(dt, _camPos, ramp)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and root:IsA("BasePart") and hum) then
			return
		end
		check -= dt
		if check <= 0 then
			check = 0.25
			params.FilterDescendantsInstances = { character, ctx.folder }
			local covered = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) ~= nil
			onIce = not covered and hum.FloorMaterial ~= Enum.Material.Air and hum.FloorMaterial ~= Enum.Material.Water
		end
		-- the ice: your momentum lags behind what you ask your feet to do
		local v = root.AssemblyLinearVelocity
		local h = Vector3.new(v.X, 0, v.Z)
		if onIce and hum.Health > 0 then
			slide = slide:Lerp(h, math.min(1, dt * GRIP))
			root.CFrame += (slide - h) * dt * 0.9 * ramp
		else
			slide = h
		end
		-- the chill
		local chill = tonumber(player:GetAttribute("Chill")) or 0
		chillShown += (chill - chillShown) * math.min(1, dt * 2)
		local frozen = chill >= 1
		local pulse = if frozen then 0.15 * (0.5 + 0.5 * math.sin(os.clock() * 6)) else 0
		frost.ImageTransparency = 1 - math.clamp(chillShown * 0.9 + pulse, 0, 0.95) * ramp
		frost.ImageColor3 = if frozen then Color3.fromRGB(140, 190, 255) else FROST
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") and not gone then
			if not breathAt or breathAt.Parent ~= head then
				breathAt = Instance.new("Attachment")
				breathAt.Position = Vector3.new(0, -0.2, -0.7)
				breathAt.Parent = head
				breath.Parent = breathAt
			end
			breath.Rate = if chillShown > 0.25 then 2 + 3 * chillShown else 0
		end
		if chillShown > 0.6 then
			local camera = Workspace.CurrentCamera
			if camera then
				local s = (chillShown - 0.6) * 0.012
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * s, (rnd:NextNumber() - 0.5) * s, 0)
			end
		end
	end)
	table.insert(ctx.cleanup, function()
		gone = true
		breath:Destroy()
		if breathAt then
			breathAt:Destroy()
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string)
		if kind == "IceChipped" then
			chipped()
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
