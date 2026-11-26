--!strict
-- Hailstorm (Mild): a bitter steel-blue afternoon. Hail pours down and bounces off everything
-- in little white sprays. Out in the open, frost creeps in around the edges of your view and
-- the hail rattles you. A giant hailstone (StormEvent "GiantHail", Blender model) announces
-- itself with a shadow that grows on the ground, then plummets in a trail of ice, smashes down
-- with a ring of frost, a flash and a jolt, and throws anyone too close off their feet.
-- Textures: Blender (Hailstorm: pellet, frost) + Golden Rain splash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local ICE = Color3.fromRGB(225, 240, 255)
local FROST = Color3.fromRGB(180, 220, 255)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local shake = 0

	Common.fall(ctx, "Hail", {
		Texture = Common.tex(ctx, "Pellet"),
		Rate = 1300,
		Size = ns(0, 0.28, 1, 0.28),
		Brightness = 1.4,
		Color = ColorSequence.new(ICE),
		Speed = NumberRange.new(90, 110),
		Lifetime = NumberRange.new(0.9, 1.1),
		Slant = Vector3.new(10, 0, 4),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		RotSpeed = NumberRange.new(-300, 300),
	})
	-- hail bouncing off the ground
	local bounce = Instance.new("ParticleEmitter")
	bounce.Texture = Common.tex(ctx, "Pellet")
	bounce.Color = ColorSequence.new(ICE)
	bounce.LightEmission = 0.3
	bounce.LightInfluence = 0.5
	bounce.Size = ns(0, 0.22, 1, 0.18)
	bounce.Lifetime = NumberRange.new(0.35, 0.55)
	bounce.Speed = NumberRange.new(6, 13)
	bounce.SpreadAngle = Vector2.new(45, 45)
	bounce.EmissionDirection = Enum.NormalId.Top
	bounce.Acceleration = Vector3.new(0, -70, 0)
	bounce.Rate = 0
	local anchor = Common.impacts(ctx, 110, 35, function()
		bounce:Emit(3)
	end)
	bounce.Parent = anchor
	Common.clouds(ctx, { Cover = 0.92, Density = 0.85, Color = Color3.fromRGB(110, 125, 150) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 230, 255),
		Saturation = -0.25,
		Brightness = 0,
		Contrast = 0.2,
		Bloom = 0.6,
		BloomThreshold = 1.2,
	})

	-- frost creeping in at the edges of the screen while you're exposed
	local gui = Instance.new("ScreenGui")
	gui.Name = "HailFrost"
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
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(frost, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function isExposed(): boolean
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (character and root and root:IsA("BasePart")) then
			return false
		end
		params.FilterDescendantsInstances = { character, ctx.folder }
		return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
	end

	local function template(): Model?
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local m = assets and assets:FindFirstChild("Hailstone")
		return if m and m:IsA("Model") then m else nil
	end

	local function giant(at: Vector3, seconds: number, radius: number)
		-- the shadow grows on the ground as it falls
		local shadow = Common.part(ctx, "HailShadow", Vector3.new(0.2, 2, 2))
		shadow.Shape = Enum.PartType.Cylinder
		shadow.Material = Enum.Material.SmoothPlastic
		shadow.Color = Color3.fromRGB(15, 20, 35)
		shadow.Transparency = 0.85
		shadow.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Common.tween(shadow, seconds, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 0.35 })
		local rim = Common.part(ctx, "HailRim", Vector3.new(0.25, radius * 2.2, radius * 2.2))
		rim.Shape = Enum.PartType.Cylinder
		rim.Material = Enum.Material.Neon
		rim.Color = FROST
		rim.Transparency = 0.9
		rim.CFrame = shadow.CFrame
		local stone: Model? = nil
		local t = template()
		if t then
			local s = t:Clone()
			for _, p in s:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
				end
			end
			local body = s:FindFirstChild("Ice")
			if body then
				local trail = Instance.new("ParticleEmitter")
				trail.Texture = Common.tex(ctx, "Pellet")
				trail.Color = ColorSequence.new(ICE)
				trail.LightEmission = 0.5
				trail.Size = ns(0, 0.8, 1, 0.2)
				trail.Lifetime = NumberRange.new(0.4, 0.8)
				trail.Speed = NumberRange.new(2, 6)
				trail.SpreadAngle = Vector2.new(180, 180)
				trail.Rate = 120
				trail.Parent = body
			end
			s.Parent = ctx.folder
			stone = s
		end
		local t0 = os.clock()
		local spin = Vector3.new(rnd:NextNumber(-3, 3), rnd:NextNumber(-3, 3), rnd:NextNumber(-3, 3))
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local h = 260 * (1 - k * k) + 1.5
			local e = os.clock() - t0
			if stone then
				stone:PivotTo(CFrame.new(at + Vector3.new(0, h, 0)) * CFrame.Angles(spin.X * e, spin.Y * e, spin.Z * e))
			end
			rim.Transparency = 0.9 - 0.5 * k + math.sin(os.clock() * 18) * 0.05
			if k >= 1 then
				conn:Disconnect()
				if stone then
					stone:Destroy()
				end
				shadow:Destroy()
				rim:Destroy()
				-- the smash
				local holder = Common.part(ctx, "HailSmash", Vector3.one)
				holder.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
				local shards = Instance.new("ParticleEmitter")
				shards.Texture = Common.tex(ctx, "Pellet")
				shards.Color = ColorSequence.new(ICE)
				shards.LightEmission = 0.4
				shards.Size = ns(0, 1.1, 1, 0.3)
				shards.Lifetime = NumberRange.new(0.6, 1.1)
				shards.Speed = NumberRange.new(18, 40)
				shards.SpreadAngle = Vector2.new(70, 70)
				shards.EmissionDirection = Enum.NormalId.Top
				shards.Acceleration = Vector3.new(0, -60, 0)
				shards.RotSpeed = NumberRange.new(-300, 300)
				shards.Rate = 0
				shards.Parent = holder
				shards:Emit(90)
				local powder = Instance.new("ParticleEmitter")
				powder.Texture = Common.tex(ctx, "Splash")
				powder.Color = ColorSequence.new(Color3.new(1, 1, 1))
				powder.LightInfluence = 0.6
				powder.Size = ns(0, 3, 1, 12)
				powder.Transparency = ns(0, 0.2, 1, 1)
				powder.Lifetime = NumberRange.new(0.8, 1.3)
				powder.Speed = NumberRange.new(6, 14)
				powder.SpreadAngle = Vector2.new(180, 20)
				powder.Rate = 0
				powder.Parent = holder
				powder:Emit(16)
				local ring = Common.part(ctx, "FrostRing", Vector3.new(0.2, 2, 2))
				ring.Shape = Enum.PartType.Cylinder
				ring.Material = Enum.Material.Neon
				ring.Color = FROST
				ring.Transparency = 0.2
				ring.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				Common.tween(ring, 0.7, { Size = Vector3.new(0.1, radius * 4, radius * 4), Transparency = 1 })
				local light = Instance.new("PointLight")
				light.Color = FROST
				light.Range = 40
				light.Brightness = 6
				light.Parent = holder
				Common.tween(light, 0.7, { Brightness = 0 })
				local camera = Workspace.CurrentCamera
				if camera then
					local dist = (camera.CFrame.Position - at).Magnitude
					shake = math.max(shake, math.clamp(1.3 - dist / 60, 0, 1.3))
				end
				-- knocked off your feet if it landed on you (players own their physics)
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and hum then
					local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
					if flat.Magnitude < radius and math.abs(root.Position.Y - at.Y) < 14 then
						hum:ChangeState(Enum.HumanoidStateType.FallingDown)
						root.AssemblyLinearVelocity += (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 35 + Vector3.new(0, 22, 0)
						task.delay(1.2, function()
							if hum.Health > 0 then
								hum:ChangeState(Enum.HumanoidStateType.GettingUp)
							end
						end)
					end
				end
				task.delay(1.6, function()
					holder:Destroy()
					ring:Destroy()
				end)
			end
		end)
	end

	local frostLevel = 0
	local check = 0
	local exposedNow = false
	table.insert(ctx.onFrame, function(dt, _camPos, ramp)
		check -= dt
		if check <= 0 then
			check = 0.25
			exposedNow = isExposed()
		end
		local goal = if exposedNow then 1 else 0
		frostLevel += (goal - frostLevel) * math.min(1, dt * (if exposedNow then 0.4 else 1.5))
		frost.ImageTransparency = 1 - 0.85 * frostLevel * ramp
		local camera = Workspace.CurrentCamera
		if camera then
			local s = shake + (if exposedNow then 0.06 * ramp else 0)
			if s > 0.01 then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * s, (rnd:NextNumber() - 0.5) * 0.03 * s, 0)
			end
		end
		shake = math.max(0, shake - dt * 2.2)
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "GiantHail" and typeof(data) == "table" and typeof(data.at) == "Vector3" then
			giant(data.at, tonumber(data.seconds) or 2.8, tonumber(data.radius) or 9)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
