--!strict
-- WeatherController: rain during the warning and the storm, and a camera shake when a wave hits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormState = require(Shared:WaitForChild("StormState"))
local StormFXController = require(script.Parent:WaitForChild("StormFXController"))
local Common = require(script.Parent:WaitForChild("StormFX"):WaitForChild("Common"))

local WeatherController = {}

function WeatherController.Start()
	local state = StormState.get()

	local cloud = Instance.new("Part")
	cloud.Name = "RainCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(120, 1, 120)
	cloud.Parent = Workspace

	local rain = Instance.new("ParticleEmitter")
	rain.Texture = Common.TEX.Streak
	rain.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 230))
	rain.LightEmission = 0.25
	rain.LightInfluence = 0.4
	rain.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.45),
		NumberSequenceKeypoint.new(0.85, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	rain.Size = NumberSequence.new(0.22)
	rain.Squash = NumberSequence.new(-2.4) -- tall, thin streaks
	rain.Lifetime = NumberRange.new(1.1, 1.3)
	rain.Speed = NumberRange.new(70, 90)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Rate = 0
	rain.Parent = cloud
	local rainGoal = 0

	local function refresh()
		local phase = state:GetAttribute("Phase")
		local id = state:GetAttribute("StormType")
		if phase == "Storm" and StormFXController.HasCustomRain(if typeof(id) == "string" then id else nil) then
			rainGoal = 0
			return
		end
		rainGoal = if phase == "Storm" then 900 elseif phase == "Warning" then 250 else 0
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refresh)
	state:GetAttributeChangedSignal("StormType"):Connect(refresh)
	refresh()

	local shakeUntil = 0
	Remotes.event("Notify").OnClientEvent:Connect(function(_text: string, kind: string?)
		if kind == "Wave" then
			shakeUntil = os.clock() + 1.2
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		-- the rain eases in and out and sways with the gusts instead of switching on and off
		rain.Rate += (rainGoal - rain.Rate) * (1 - math.exp(-dt / 2.5))
		local push = Common.gustAt(os.clock()) * 14
		rain.Acceleration = push
		cloud.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0) - push * 0.6)
		local left = shakeUntil - os.clock()
		if left > 0 then
			-- a smooth rolling shake (noise), not random jitter
			local s = math.min(left, 1) * 0.5
			local t = os.clock() * 14
			camera.CFrame *= CFrame.new(math.noise(t, 1.3) * s, math.noise(t, 7.9) * s, 0)
				* CFrame.Angles(0, 0, math.noise(t, 4.2) * s * 0.03)
		end
	end)
end

return WeatherController
