--!strict
-- FogController: blends the sky, light and fog to match the storm phase.
-- Runs on each client, so the server sends nothing per frame.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StormState = require(Shared:WaitForChild("StormState"))

local FogController = {}

local activeTweens: { Tween } = {}

local function getAtmosphere(): Atmosphere
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		return existing
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	return atmosphere
end

local function apply(phase: string, instant: boolean)
	local look = (Config.PhaseLook :: any)[phase]
	if not look then
		return
	end

	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)

	local seconds = if instant then 0 else ((Config.LookTweenSeconds :: any)[phase] or 5)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- The clock jumps at dawn: tweening it backwards would flash through midday.
	local jumpClock = instant or phase == "Dawn"
	if jumpClock then
		Lighting.ClockTime = look.ClockTime
	end

	local lightingGoal: { [string]: any } = {
		Brightness = look.Brightness,
		Ambient = look.Ambient,
		OutdoorAmbient = look.Ambient,
		ExposureCompensation = look.Exposure or 0,
	}
	if not jumpClock then
		lightingGoal.ClockTime = look.ClockTime
	end

	local atmosphereGoal: { [string]: any } = {
		Density = look.FogDensity,
		Haze = look.FogHaze,
		Color = look.FogColor,
		Decay = look.FogColor,
	}

	local lightingTween = TweenService:Create(Lighting, info, lightingGoal)
	local atmosphereTween = TweenService:Create(getAtmosphere(), info, atmosphereGoal)
	table.insert(activeTweens, lightingTween)
	table.insert(activeTweens, atmosphereTween)
	lightingTween:Play()
	atmosphereTween:Play()
end

function FogController.Start()
	local state = StormState.get()
	local function current(): string
		local phase = state:GetAttribute("Phase")
		return if typeof(phase) == "string" then phase else "Calm"
	end
	apply(current(), true)
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		apply(current(), false)
	end)
end

return FogController
