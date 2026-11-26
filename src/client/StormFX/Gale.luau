--!strict
-- Gale (Moderate): a howling slate-green storm. The wind never stops: rain flies sideways, wind
-- lines and torn leaves stream past, the trees and grass thrash, the sea is a mess of
-- whitecaps and the view shudders. Out in the open the wind leans on you, pushing you
-- downwind and fighting every step upwind. Debris (StormEvent "Debris": Blender planks and
-- branches) comes tumbling out of the storm at you; and the wind can tear what you're carrying
-- right out of your hands (StormEvent "Snatch").
-- Textures: Sea Breeze leaf/streak + Golden Rain drop/splash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local LEAVES = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 140, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 150, 70)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 90, 50)),
})
local PUSH = 5 -- studs per second the wind pushes back when you walk into it

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local terrain = Workspace.Terrain
	local windDir: Vector3 = (Workspace:GetAttribute("WindDir") :: Vector3?) or Vector3.new(1, 0, 0)
	local shake = 0

	local before = { WaterWaveSize = terrain.WaterWaveSize, WaterWaveSpeed = terrain.WaterWaveSpeed }
	Common.tween(terrain, Common.FADE, { WaterWaveSize = 1, WaterWaveSpeed = 40 })
	local windBefore = Workspace.GlobalWind
	table.insert(ctx.cleanup, function()
		Common.tween(terrain, Common.FADE, before)
		Workspace.GlobalWind = windBefore
	end)
	Common.clouds(ctx, { Cover = 0.95, Density = 0.85, Color = Color3.fromRGB(85, 100, 95) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(220, 235, 228),
		Saturation = -0.25,
		Brightness = -0.03,
		Contrast = 0.22,
		Bloom = 0.5,
		BloomThreshold = 1.2,
	})
	Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 1600,
		Size = ns(0, 0.4, 1, 0.4),
		Squash = ns(0, 1.6, 1, 1.6),
		Brightness = 1.2,
		Color = ColorSequence.new(Color3.fromRGB(200, 215, 215)),
		Speed = NumberRange.new(75, 90),
		Slant = windDir * 90,
		Offset = -windDir * 40,
	})

	-- the wind sheet: wind lines and torn leaves pouring past, emitted downwind
	local sheet = Common.part(ctx, "WindSheet", Vector3.new(180, 1, 60))
	local function emitter(props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.LightInfluence = 0
		e.EmissionDirection = Enum.NormalId.Top
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = sheet
		return e
	end
	emitter({
		Texture = Common.tex(ctx, "Streak"),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		LightEmission = 0.5,
		Brightness = 2,
		Color = ColorSequence.new(Color3.fromRGB(230, 240, 240)),
		Size = ns(0, 0.5, 1, 0.5),
		Squash = ns(0, -2.5, 1, -2.5),
		Transparency = ns(0, 1, 0.15, 0.45, 0.85, 0.45, 1, 1),
		Lifetime = NumberRange.new(1.1, 1.5),
		Speed = NumberRange.new(100, 130),
		SpreadAngle = Vector2.new(5, 5),
		Rate = 300,
	})
	emitter({
		Texture = Common.tex(ctx, "Leaf"),
		LightInfluence = 0.8,
		LightEmission = 0.1,
		Color = LEAVES,
		Size = ns(0, 0.7, 1, 0.7),
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(45, 70),
		SpreadAngle = Vector2.new(15, 25),
		Acceleration = Vector3.new(0, -4, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-600, 600),
		Rate = 90,
	})

	-- the wind leaning on you (a steady nudge each frame: predictable, unlike a physics force on
	-- a character that has almost no grip when standing still)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function template(kind: string): Model?
		local assets = ReplicatedStorage:FindFirstChild("StormAssets")
		local m = assets and assets:FindFirstChild(kind)
		return if m and m:IsA("Model") then m else nil
	end

	local function debris(data: { [string]: any })
		local from = data.from :: Vector3
		local to = data.to :: Vector3
		local seconds = tonumber(data.seconds) or 2.2
		local radius = tonumber(data.radius) or 5
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
		local trail = Instance.new("ParticleEmitter")
		trail.Texture = Common.tex(ctx, "Leaf")
		trail.Color = LEAVES
		trail.LightInfluence = 0.8
		trail.Size = ns(0, 0.5, 1, 0.3)
		trail.Lifetime = NumberRange.new(0.4, 0.8)
		trail.Speed = NumberRange.new(1, 4)
		trail.SpreadAngle = Vector2.new(180, 180)
		trail.RotSpeed = NumberRange.new(-400, 400)
		trail.Rate = if data.kind == "Branch" then 40 else 10
		trail.Parent = m:FindFirstChildWhichIsA("BasePart")
		m.Parent = ctx.folder
		local spin = Vector3.new(r:NextNumber(-8, 8), r:NextNumber(-8, 8), r:NextNumber(-8, 8))
		local beyond = to + (to - from).Unit * 120 + Vector3.new(0, -20, 0)
		local t0 = os.clock()
		local hitDone = false
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local e = os.clock() - t0
			local pos: Vector3
			if e < seconds then
				local k = e / seconds
				pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 6, 0)
			else
				local k = math.min(1, (e - seconds) / (seconds * 0.9))
				pos = to:Lerp(beyond, k)
				if k >= 1 then
					conn:Disconnect()
					m:Destroy()
					return
				end
			end
			m:PivotTo(CFrame.new(pos) * CFrame.Angles(spin.X * e, spin.Y * e, spin.Z * e))
			if not hitDone and e >= seconds then
				hitDone = true
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and hum and (root.Position - to).Magnitude < radius then
					hum:ChangeState(Enum.HumanoidStateType.FallingDown)
					root.AssemblyLinearVelocity += windDir * 40 + Vector3.new(0, 18, 0)
					shake = math.max(shake, 1)
					task.delay(1.2, function()
						if hum.Health > 0 then
							hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						end
					end)
				end
			end
		end)
	end

	local function snatch(data: { [string]: any })
		-- a puff of dust and glints whipping the item away downwind
		local holder = Common.part(ctx, "Snatch", Vector3.one)
		holder.CFrame = CFrame.new(data.from :: Vector3)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.tex(ctx, "Leaf")
		e.Color = LEAVES
		e.LightInfluence = 0.8
		e.Size = ns(0, 0.8, 1, 0.3)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(20, 40)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Rate = 0
		e.Parent = holder
		holder.CFrame = CFrame.lookAt(data.from :: Vector3, data.to :: Vector3) * CFrame.Angles(-math.pi / 2, 0, 0)
		e:Emit(30)
		task.delay(1.5, function()
			holder:Destroy()
		end)
	end

	local check = 0
	local exposedNow = false
	local sway = 0
	local baseFov = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70
	table.insert(ctx.cleanup, function()
		local cam = Workspace.CurrentCamera
		if cam then
			Common.tween(cam, 1, { FieldOfView = baseFov })
		end
	end)
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local side = Vector3.new(-windDir.Z, 0, windDir.X)
		sheet.CFrame = CFrame.fromMatrix(camPos - windDir * 80 + Vector3.new(0, 10, 0), side, windDir)
		Workspace.GlobalWind = windDir * 120 * ramp
		-- lean on the player while they're out in the open
		check -= dt
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			if check <= 0 then
				check = 0.25
				params.FilterDescendantsInstances = { character, ctx.folder }
				exposedNow = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
			end
			local hum = character:FindFirstChildOfClass("Humanoid")
			if exposedNow and hum and hum.Health > 0 then
				local gust = 0.8 + 0.35 * math.sin(os.clock() * 1.3) + 0.15 * math.sin(os.clock() * 3.1)
				local along = hum.MoveDirection:Dot(windDir)
				-- idle: a slow drift; walking into the wind: a real slog; with it: a push
				local speed = if hum.MoveDirection.Magnitude < 0.1 then 1.8 elseif along < -0.3 then PUSH else 3
				root.CFrame += windDir * speed * gust * ramp * dt
			end
		end
		sway += dt
		local cam = Workspace.CurrentCamera
		if cam then
			cam.FieldOfView = baseFov + 3 * ramp
			local amt = if exposedNow then 1 else 0.4
			cam.CFrame *= CFrame.Angles(
				(rnd:NextNumber() - 0.5) * 0.004 * amt * ramp + (rnd:NextNumber() - 0.5) * 0.03 * shake,
				(rnd:NextNumber() - 0.5) * 0.004 * amt * ramp + (rnd:NextNumber() - 0.5) * 0.03 * shake,
				math.sin(sway * 1.9) * 0.008 * amt * ramp
			)
		end
		shake = math.max(0, shake - dt * 2)
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Debris" and typeof(data.from) == "Vector3" and typeof(data.to) == "Vector3" then
			debris(data)
		elseif kind == "Snatch" and typeof(data.from) == "Vector3" and typeof(data.to) == "Vector3" then
			snatch(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
