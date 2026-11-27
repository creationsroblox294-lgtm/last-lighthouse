--!strict
-- HitFeelController: makes a landed hit feel like a hit. When the server confirms that YOUR
-- punch or harpoon struck a creature (HitConfirm), the attacker gets:
--   * hit-stop: your own swing freezes for a few frames, as if the blow met real weight
--   * a camera kick in the direction of the blow, then a short decaying shake
--   * a quick FOV punch (the world "jolts" toward you)
--   * a white flash on the creature itself, plus an impact ring and sparks
--   * a punchy damage number that pops and floats off the creature
--   * a meaty hit sound, pitch-varied so repeated hits don't sound copy-pasted
--   * gamepad rumble
-- A killing blow gets all of it harder: a longer freeze, a gold screen-edge flash, a big
-- "SLAIN" stamp and a heavier sound. Everyone else still sees the normal PunchHit sparks.

local Debris = game:GetService("Debris")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Typography = require(script.Parent:WaitForChild("Typography"))

local HitFeelController = {}

local player = Players.LocalPlayer
local F = Config.HitFeel

type Feel = { Stop: number, Kick: number, Trauma: number, Fov: number, Rumble: number }

local HIT_WHITE = Color3.fromRGB(255, 246, 228)
local KILL_GOLD = Color3.fromRGB(255, 196, 72)
local DAMAGE_COLOR = Color3.fromRGB(255, 236, 200)

-- camera state, applied after the default camera every frame
local trauma = 0
local kickPitch = 0 -- degrees, springs back to 0
local kickYaw = 0
local fovBoost = 0
local baseFov: number? = nil
local seed = math.random() * 1000

local gui: ScreenGui? = nil
local edges: { Frame } = {}
local sounds: { [string]: Sound } = {}
local connections: { RBXScriptConnection } = {}

local function rumble(strength: number, seconds: number)
	if not UserInputService.GamepadEnabled then
		return
	end
	local pad = Enum.UserInputType.Gamepad1
	local ok = pcall(function()
		if HapticService:IsVibrationSupported(pad) then
			HapticService:SetMotor(pad, Enum.VibrationMotor.Large, strength)
			HapticService:SetMotor(pad, Enum.VibrationMotor.Small, strength * 0.6)
		end
	end)
	if ok then
		task.delay(seconds, function()
			pcall(function()
				HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
				HapticService:SetMotor(pad, Enum.VibrationMotor.Small, 0)
			end)
		end)
	end
end

local function playSound(kind: string, volume: number)
	local s = sounds[kind]
	if not s then
		return
	end
	local c = s:Clone()
	c.PlaybackSpeed = 0.92 + math.random() * 0.16
	c.Volume = volume
	c.Parent = SoundService
	c:Play()
	Debris:AddItem(c, 2)
end

-- freeze the local character's animations for a moment (the "impact frame")
local function hitStop(seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local frozen: { [AnimationTrack]: number } = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		frozen[track] = track.Speed
		track:AdjustSpeed(0.03)
	end
	task.delay(seconds, function()
		for track, speed in frozen do
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

local function cameraJolt(feel: Feel, at: Vector3)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- kick away from the impact: up, and a little sideways depending on which side it was
	local rel = camera.CFrame:PointToObjectSpace(at)
	local side = if rel.X > 0.5 then -1 elseif rel.X < -0.5 then 1 else (if math.random() < 0.5 then -1 else 1)
	kickPitch = math.min(kickPitch + feel.Kick, 7)
	kickYaw = math.clamp(kickYaw + side * feel.Kick * 0.45, -4, 4)
	trauma = math.min(trauma + feel.Trauma, 1)
	fovBoost = math.max(fovBoost, feel.Fov)
end

local function flashModel(model: Instance, color: Color3, seconds: number)
	if not (model:IsA("Model") or model:IsA("BasePart")) then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "HitFlash"
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.15
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	Debris:AddItem(h, seconds + 0.05)
end

local function impactRing(at: Vector3, color: Color3, size: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "HitRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.15
	ring.Size = Vector3.new(0.05, 0.6, 0.6)
	-- the cylinder's axis is X: point it at the camera so the disc faces you
	ring.CFrame = CFrame.lookAt(at, camera.CFrame.Position) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.3)

	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = Workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(HIT_WHITE, color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(18, 34)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 6
	sparks.Enabled = false
	sparks.Parent = a
	sparks:Emit(if size > 8 then 28 else 14)
	Debris:AddItem(a, 0.6)
end

local function damageNumber(at: Vector3, damage: number, killed: boolean)
	local bb = Instance.new("BillboardGui")
	bb.Name = "HitNumber"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(160, 64)
	bb.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 2.4, 2.2 + math.random() * 0.8, 0)
	bb.MaxDistance = 140
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = Workspace.Terrain
	bb.Adornee = a
	bb.Parent = a

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Typography.Heading
	label.TextScaled = true
	label.Text = if killed then "SLAIN" elseif damage > 0 then tostring(math.floor(damage + 0.5)) else "HIT"
	label.TextColor3 = if killed then KILL_GOLD else DAMAGE_COLOR
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 22, 12)
	stroke.Thickness = 3
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	label.Parent = bb

	local peak = if killed then 1.6 else 1.15
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = peak }):Play()
	task.delay(0.12, function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = peak * 0.82 }):Play()
	end)
	local life = if killed then 1.1 else 0.75
	TweenService:Create(bb, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 2.6, 0),
	}):Play()
	task.delay(life * 0.55, function()
		local fade = TweenInfo.new(life * 0.45)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end)
	Debris:AddItem(a, life + 0.1)
end

local function edgeFlash(color: Color3, strength: number, seconds: number)
	for _, e in edges do
		e.BackgroundColor3 = color
		e.BackgroundTransparency = 1 - strength
		TweenService:Create(e, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end
end

local function buildGui()
	local g = Instance.new("ScreenGui")
	g.Name = "HitFeel"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 40
	g.Parent = player:WaitForChild("PlayerGui")
	-- four soft edges (a vignette), each fading toward the middle of the screen
	local specs = {
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0.84, 0), 180 },
	}
	for _, spec in specs do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = spec[1]
		f.Position = spec[2]
		f.BackgroundTransparency = 1
		local grad = Instance.new("UIGradient")
		grad.Rotation = spec[3]
		grad.Transparency = NumberSequence.new(0, 1)
		grad.Parent = f
		f.Parent = g
		table.insert(edges, f)
	end
	gui = g
end

local function onConfirm(at: Vector3, target: Instance?, damage: number, killed: boolean, weapon: string)
	if typeof(at) ~= "Vector3" then
		return
	end
	local feel: Feel = if killed then F.Kill elseif weapon == "Harpoon" then F.Harpoon else F.Punch
	hitStop(feel.Stop)
	cameraJolt(feel, at)
	rumble(feel.Rumble, feel.Stop + 0.06)
	if target then
		flashModel(target, if killed then KILL_GOLD else HIT_WHITE, if killed then 0.35 else 0.18)
	end
	impactRing(at, if killed then KILL_GOLD else HIT_WHITE, if killed then 11 else (if weapon == "Harpoon" then 7 else 5))
	damageNumber(at, damage, killed)
	playSound(if weapon == "Harpoon" then "Harpoon" else "Punch", if killed then 0.9 else 0.7)
	if killed then
		playSound("Kill", 0.85)
		edgeFlash(KILL_GOLD, 0.55, 0.45)
	elseif weapon == "Harpoon" then
		edgeFlash(HIT_WHITE, 0.22, 0.2)
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if baseFov == nil then
		baseFov = camera.FieldOfView
	end
	local active = trauma > 0.001 or math.abs(kickPitch) > 0.01 or math.abs(kickYaw) > 0.01 or fovBoost > 0.01
	if not active then
		-- keep tracking the real FOV (sprint and other effects may change it)
		baseFov = camera.FieldOfView
		return
	end
	local t = os.clock() * 28
	local shake = trauma * trauma
	local sx = (math.noise(seed, t) * 2) * shake * 1.6
	local sy = (math.noise(seed + 10, t) * 2) * shake * 1.6
	local sr = (math.noise(seed + 20, t) * 2) * shake * 1.2
	camera.CFrame *= CFrame.Angles(math.rad(kickPitch + sy), math.rad(kickYaw + sx), math.rad(sr))
	camera.FieldOfView = (baseFov :: number) + fovBoost
	-- spring everything back: snappy, so the jolt reads as an impact and not a wobble
	local k = math.exp(-dt * 16)
	kickPitch *= k
	kickYaw *= k
	fovBoost *= math.exp(-dt * 12)
	trauma = math.max(0, trauma - dt * 2.6)
	if not (trauma > 0.001 or math.abs(kickPitch) > 0.01 or math.abs(kickYaw) > 0.01 or fovBoost > 0.01) then
		camera.FieldOfView = baseFov :: number
	end
end

function HitFeelController.Start()
	for kind, id in F.Sounds do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "Hit" .. kind
			s.SoundId = id
			sounds[kind] = s
		end
	end
	buildGui()
	RunService:BindToRenderStep("HitFeel", Enum.RenderPriority.Camera.Value + 2, step)
	table.insert(connections, Remotes.event("HitConfirm").OnClientEvent:Connect(onConfirm))
end

function HitFeelController.Stop()
	RunService:UnbindFromRenderStep("HitFeel")
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
		gui = nil
	end
	table.clear(edges)
end

return HitFeelController
