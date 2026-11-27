--!strict
-- Blackout Storm (Severe): a dry, airless violet night full of static. Sheet lightning flickers
-- in the clouds and lights up the whole island for a heartbeat; blue sparks crawl over the tops
-- of the tower and the trees. When lightning goes for the lamp (StormEvent "LampStrike") a
-- blinding bolt hits the lantern, glass and sparks shower down, and the light chokes to a weak
-- sputter: the beam dies and the dark rushes in (Workspace attribute "Blackout") until it's
-- relit (StormEvent "Relit"). Ball lightning (Workspace.Runtime.BallLightning) drifts through
-- the dark: crackling blue-white orbs (Blender: plasma) that light the ground under them, throw
-- little arcs at the earth, and burst (StormEvent "OrbBurst") or blast you (StormEvent "Zapped").
-- Textures: Blender (Blackout Storm: plasma) + Lucky Lightning spark/glow, Drizzle haze, Squall
-- sheet.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local BLUE = Color3.fromRGB(150, 190, 255)
local WHITE = Color3.fromRGB(235, 240, 255)
local VIOLET = Color3.fromRGB(150, 110, 255)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer

	Common.around(ctx, "Static", Vector3.new(80, 30, 80), {
		Texture = Common.tex(ctx, "Spark"),
		Rate = 12,
		Brightness = 3,
		Color = ColorSequence.new(BLUE),
		Size = ns(0, 0, 0.3, 0.6, 1, 0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(0),
	})
	Common.clouds(ctx, { Cover = 0.85, Density = 0.7, Color = Color3.fromRGB(60, 45, 90) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(215, 205, 255),
		Saturation = -0.25,
		Brightness = -0.03,
		Contrast = 0.25,
		Bloom = 1.1,
		BloomThreshold = 0.85,
	})

	-- St Elmo's fire on the lantern gallery
	local l = Common.lamp()
	if l then
		local crown = Common.part(ctx, "Elmo", Vector3.new(16, 4, 16))
		crown.CFrame = l.CFrame * CFrame.new(0, 9, 0)
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = Common.tex(ctx, "Spark")
		fire.Color = ColorSequence.new(BLUE, VIOLET)
		fire.LightEmission = 1
		fire.Brightness = 3
		fire.Size = ns(0, 0.4, 0.5, 1.2, 1, 0)
		fire.Lifetime = NumberRange.new(0.15, 0.35)
		fire.Speed = NumberRange.new(0.5, 2)
		fire.Rate = 25
		fire.Parent = crown
	end

	-- sheet lightning: the whole sky and island flicker violet-white for a moment
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "SheetFlash"
	flash.Parent = Lighting
	local flashLevel = 0
	local nextFlash = rnd:NextNumber(1, 3)
	table.insert(ctx.cleanup, function()
		flash:Destroy()
	end)

	-- the blackout: the night closes in (LightController kills the beam)
	local dark = Instance.new("ColorCorrectionEffect")
	dark.Name = "Blackout"
	dark.Parent = Lighting
	local choked = 0
	table.insert(ctx.cleanup, function()
		Common.tween(dark, Common.FADE, { Brightness = 0, Saturation = 0 })
		task.delay(Common.FADE + 0.5, function()
			dark:Destroy()
		end)
	end)

	-- bolts
	local function bolt(from: Vector3, to: Vector3, width: number, life: number)
		local segs = 10
		local prev = from
		for k = 1, segs do
			local t = k / segs
			local p = from:Lerp(to, t)
			if k < segs then
				p += Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.3, 0.3), rnd:NextNumber(-1, 1)) * (from - to).Magnitude * 0.04
			end
			local seg = Common.boltSegment(ctx, prev, p, width, WHITE, Color3.fromRGB(190, 150, 255), 0.65)
			Common.tween(seg, life, { Transparency = 1 })
			task.delay(life + 0.1, function()
				seg:Destroy()
			end)
			prev = p
		end
	end

	local function lampStrike(at: Vector3)
		bolt(at + Vector3.new(rnd:NextNumber(-60, 60), 400, rnd:NextNumber(-60, 60)), at, 1.6, 0.5)
		flashLevel = 1
		local holder = Common.part(ctx, "LampSparks", Vector3.new(8, 8, 8))
		holder.CFrame = CFrame.new(at)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Common.tex(ctx, "Spark")
		sparks.Color = ColorSequence.new(WHITE, BLUE)
		sparks.LightEmission = 1
		sparks.Brightness = 4
		sparks.Size = ns(0, 0.6, 1, 0)
		sparks.Lifetime = NumberRange.new(0.6, 1.4)
		sparks.Speed = NumberRange.new(15, 35)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, -60, 0)
		sparks.Rate = 0
		sparks.Parent = holder
		sparks:Emit(200)
		local glass = Instance.new("ParticleEmitter")
		glass.Texture = Common.tex(ctx, "Glow")
		glass.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
		glass.LightEmission = 0.6
		glass.Size = ns(0, 0.3, 1, 0.2)
		glass.Lifetime = NumberRange.new(1, 2)
		glass.Speed = NumberRange.new(8, 20)
		glass.SpreadAngle = Vector2.new(180, 180)
		glass.Acceleration = Vector3.new(0, -80, 0)
		glass.RotSpeed = NumberRange.new(-400, 400)
		glass.Rate = 0
		glass.Parent = holder
		glass:Emit(80)
		local boom = Instance.new("PointLight")
		boom.Color = WHITE
		boom.Range = 60
		boom.Brightness = 12
		boom.Parent = holder
		Common.tween(boom, 1, { Brightness = 0 })
		task.delay(2.5, function()
			holder:Destroy()
		end)
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - at).Magnitude < 300 then
			local shake = 1
			task.spawn(function()
				while shake > 0 do
					shake -= 0.04
					local cam = Workspace.CurrentCamera
					if cam then
						cam.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
					end
					task.wait()
				end
			end)
		end
	end

	-- ball lightning
	type OrbFX = { part: BasePart, holder: BasePart, light: PointLight, nextArc: number }
	local orbs: { [BasePart]: OrbFX } = {}
	local function dress(p: Instance)
		if not p:IsA("BasePart") or orbs[p] then
			return
		end
		local holder = Common.part(ctx, "OrbFX", Vector3.new(2, 2, 2))
		holder.CFrame = p.CFrame
		local core = Instance.new("ParticleEmitter")
		core.Texture = Common.tex(ctx, "Plasma")
		core.Color = ColorSequence.new(WHITE)
		core.LightEmission = 1
		core.Brightness = 3
		core.Size = ns(0, 4, 0.5, 5, 1, 4)
		core.Transparency = ns(0, 0.6, 0.5, 0.1, 1, 0.6)
		core.Lifetime = NumberRange.new(0.12, 0.2)
		core.Speed = NumberRange.new(0)
		core.Rotation = NumberRange.new(0, 360)
		core.RotSpeed = NumberRange.new(-400, 400)
		core.LockedToPart = true
		core.Rate = 30
		core.Parent = holder
		local crackle = Instance.new("ParticleEmitter")
		crackle.Texture = Common.tex(ctx, "Spark")
		crackle.Color = ColorSequence.new(BLUE, VIOLET)
		crackle.LightEmission = 1
		crackle.Brightness = 3
		crackle.Size = ns(0, 0.6, 1, 0)
		crackle.Lifetime = NumberRange.new(0.2, 0.4)
		crackle.Speed = NumberRange.new(6, 14)
		crackle.SpreadAngle = Vector2.new(180, 180)
		crackle.Rate = 30
		crackle.Parent = holder
		local light = Instance.new("PointLight")
		light.Color = BLUE
		light.Range = 24
		light.Brightness = 3
		light.Parent = holder
		orbs[p] = { part = p, holder = holder, light = light, nextArc = os.clock() + rnd:NextNumber(0.2, 0.8) }
	end
	local runtime = Workspace:FindFirstChild("Runtime")
	local folderConn: RBXScriptConnection? = nil
	local childConn: RBXScriptConnection? = nil
	local function watch(f: Instance)
		for _, c in f:GetChildren() do
			dress(c)
		end
		childConn = f.ChildAdded:Connect(dress)
	end
	if runtime then
		local f = runtime:FindFirstChild("BallLightning")
		if f then
			watch(f)
		else
			folderConn = runtime.ChildAdded:Connect(function(c)
				if c.Name == "BallLightning" then
					watch(c)
				end
			end)
		end
	end
	table.insert(ctx.cleanup, function()
		if folderConn then
			folderConn:Disconnect()
		end
		if childConn then
			childConn:Disconnect()
		end
	end)

	local function orbBurst(at: Vector3)
		local holder = Common.part(ctx, "OrbBurst", Vector3.new(4, 4, 4))
		holder.CFrame = CFrame.new(at)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.tex(ctx, "Spark")
		e.Color = ColorSequence.new(WHITE, BLUE)
		e.LightEmission = 1
		e.Brightness = 4
		e.Size = ns(0, 0.8, 1, 0)
		e.Lifetime = NumberRange.new(0.3, 0.7)
		e.Speed = NumberRange.new(20, 40)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 0
		e.Parent = holder
		e:Emit(90)
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = Common.tex(ctx, "Plasma")
		glow.Color = ColorSequence.new(WHITE)
		glow.LightEmission = 1
		glow.Size = ns(0, 4, 1, 18)
		glow.Transparency = ns(0, 0, 1, 1)
		glow.Lifetime = NumberRange.new(0.35, 0.35)
		glow.Speed = NumberRange.new(0)
		glow.Rate = 0
		glow.Parent = holder
		glow:Emit(2)
		local l2 = Instance.new("PointLight")
		l2.Color = WHITE
		l2.Range = 40
		l2.Brightness = 10
		l2.Parent = holder
		Common.tween(l2, 0.6, { Brightness = 0 })
		task.delay(1.5, function()
			holder:Destroy()
		end)
	end

	-- being zapped: white-out, blue edges, a shake and a stumble
	local gui = Instance.new("ScreenGui")
	gui.Name = "Zap"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local white = Instance.new("Frame")
	white.BorderSizePixel = 0
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = Color3.fromRGB(220, 230, 255)
	white.BackgroundTransparency = 1
	white.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		task.delay(Common.FADE, function()
			gui:Destroy()
		end)
	end)
	local zapShake = 0
	local function zapped(from: Vector3)
		white.BackgroundTransparency = 0.1
		Common.tween(white, 0.8, { BackgroundTransparency = 1 })
		zapShake = 1
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and hum then
			bolt(from, root.Position, 0.5, 0.3)
			local away = root.Position - from
			away = Vector3.new(away.X, 0, away.Z)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
			root.AssemblyLinearVelocity += away * 35 + Vector3.new(0, 20, 0)
			hum:ChangeState(Enum.HumanoidStateType.FallingDown)
			task.delay(1.2, function()
				if hum.Parent and hum.Health > 0 then
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		-- sheet lightning
		nextFlash -= dt
		if nextFlash <= 0 and ramp > 0.3 then
			nextFlash = rnd:NextNumber(2, 6)
			flashLevel = math.max(flashLevel, rnd:NextNumber(0.35, 0.8))
			-- sometimes a distant bolt with it
			if rnd:NextNumber() < 0.5 then
				local a = rnd:NextNumber(0, math.pi * 2)
				local far = camPos + Vector3.new(math.cos(a), 0, math.sin(a)) * rnd:NextNumber(250, 450)
				bolt(Vector3.new(far.X, 380, far.Z), Vector3.new(far.X + rnd:NextNumber(-40, 40), 0, far.Z + rnd:NextNumber(-40, 40)), 2.5, 0.35)
			end
		end
		flashLevel = math.max(0, flashLevel - dt * 4)
		local flicker = flashLevel * (0.6 + 0.4 * math.sin(os.clock() * 70))
		flash.Brightness = 0.45 * flicker
		flash.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(230, 220, 255), flicker)
		-- blackout
		local goal = if Workspace:GetAttribute("Blackout") then 1 else 0
		choked += (goal - choked) * math.min(1, dt * (if goal > 0 then 3 else 1))
		dark.Brightness = -0.12 * choked * ramp
		dark.Saturation = -0.3 * choked * ramp
		-- ball lightning
		for p, o in orbs do
			if not p.Parent then
				o.holder:Destroy()
				orbs[p] = nil
			else
				o.holder.CFrame = o.holder.CFrame:Lerp(p.CFrame, math.min(1, dt * 12))
				o.light.Brightness = 2.5 + rnd:NextNumber() * 2
				if os.clock() >= o.nextArc then
					o.nextArc = os.clock() + rnd:NextNumber(0.15, 0.7)
					local from = o.holder.Position
					local hit = Workspace:Raycast(from, Vector3.new(rnd:NextNumber(-6, 6), -12, rnd:NextNumber(-6, 6)), params)
					if hit then
						bolt(from, hit.Position, 0.15, 0.12)
					end
				end
			end
		end
		if zapShake > 0 then
			zapShake = math.max(0, zapShake - dt * 1.5)
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.04 * zapShake, (rnd:NextNumber() - 0.5) * 0.04 * zapShake, 0)
			end
		end
	end)
	table.insert(ctx.cleanup, function()
		for _, o in orbs do
			o.holder:Destroy()
		end
		table.clear(orbs)
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "LampStrike" and typeof(data) == "table" and typeof(data.at) == "Vector3" then
			lampStrike(data.at)
		elseif kind == "OrbBurst" and typeof(data) == "table" and typeof(data.at) == "Vector3" then
			orbBurst(data.at)
		elseif kind == "Zapped" and typeof(data) == "table" and typeof(data.from) == "Vector3" then
			zapped(data.from)
		elseif kind == "Relit" then
			flashLevel = 0.5
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
