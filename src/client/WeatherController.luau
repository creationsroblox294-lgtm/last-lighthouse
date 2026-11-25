--!strict
-- WeatherController: rain during the warning and the storm, and a camera shake when a wave hits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormState = require(Shared:WaitForChild("StormState"))

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
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(180, 200, 220))
	rain.LightEmission = 0.2
	rain.Transparency = NumberSequence.new(0.4)
	rain.Size = NumberSequence.new(0.15)
	rain.Lifetime = NumberRange.new(1.2)
	rain.Speed = NumberRange.new(70, 90)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Rate = 0
	rain.Parent = cloud

	local function refresh()
		local phase = state:GetAttribute("Phase")
		rain.Rate = if phase == "Storm" then 900 elseif phase == "Warning" then 250 else 0
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refresh)
	refresh()

	local shakeUntil = 0
	Remotes.event("Notify").OnClientEvent:Connect(function(_text: string, kind: string?)
		if kind == "Wave" then
			shakeUntil = os.clock() + 1.2
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		cloud.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		local left = shakeUntil - os.clock()
		if left > 0 then
			local s = left * 0.6
			camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
		end
	end)
end

return WeatherController
