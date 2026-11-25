--!strict
-- HUDController: storm counter, phase name and countdown at the top of the screen.
-- Sizes use Scale (with min/max limits) so it fits phones, tablets, PC and console.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StormState = require(Shared:WaitForChild("StormState"))

local HUDController = {}

local PHASE_TEXT: { [string]: string } = {
	Calm = "Calm: gather and repair",
	Warning = "Fog incoming! Get to the light",
	Storm = "STORM",
	Dawn = "Dawn",
	Won = "The 100th storm has passed",
}

local PHASE_COLOR: { [string]: Color3 } = {
	Calm = Color3.fromRGB(150, 210, 255),
	Warning = Color3.fromRGB(255, 190, 80),
	Storm = Color3.fromRGB(255, 95, 85),
	Dawn = Color3.fromRGB(255, 220, 160),
	Won = Color3.fromRGB(255, 240, 150),
}

local SPECIAL_TEXT: { [string]: string } = {
	SilentFog = "Silent Fog",
	RedTide = "Red Tide",
	GhostShip = "Ghost Ship",
	CalmNight = "Calm Night",
}

local function label(name: string, parent: Instance, posY: number, height: number, font: Enum.Font, maxText: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.fromScale(0.5, posY)
	l.Size = UDim2.fromScale(0.92, height)
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxText
	limit.MinTextSize = 10
	limit.Parent = l
	l.Parent = parent
	return l
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function HUDController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local state = StormState.get()

	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = Instance.new("Frame")
	panel.Name = "StormPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.02)
	panel.Size = UDim2.fromScale(0.3, 0.12)
	panel.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
	panel.BackgroundTransparency = 0.35
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = panel

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(220, 72)
	sizeLimit.MaxSize = Vector2.new(440, 120)
	sizeLimit.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local stormLabel = label("StormLabel", panel, 0.06, 0.38, Enum.Font.GothamBlack, 34)
	local phaseLabel = label("PhaseLabel", panel, 0.46, 0.26, Enum.Font.GothamBold, 22)
	local timerLabel = label("TimerLabel", panel, 0.72, 0.24, Enum.Font.GothamMedium, 20)

	gui.Parent = playerGui

	local function refreshText()
		local phase = state:GetAttribute("Phase")
		local phaseName = if typeof(phase) == "string" then phase else "Calm"
		local storm = state:GetAttribute("CurrentStorm")
		local stormNumber = if typeof(storm) == "number" then storm else 1
		local special = state:GetAttribute("SpecialStorm")
		local isGreat = state:GetAttribute("IsGreatStorm") == true

		local title: string
		if phaseName == "Won" then
			title = "100 STORMS"
		elseif phaseName == "Dawn" then
			title = `STORM {stormNumber} SURVIVED`
		else
			title = `STORM {stormNumber}`
			if isGreat then
				title ..= " · GREAT STORM"
			elseif typeof(special) == "string" and SPECIAL_TEXT[special] then
				title ..= ` · {SPECIAL_TEXT[special]}`
			end
		end

		local color = PHASE_COLOR[phaseName] or Color3.new(1, 1, 1)
		stormLabel.Text = title
		phaseLabel.Text = PHASE_TEXT[phaseName] or phaseName
		phaseLabel.TextColor3 = color
		stroke.Color = color
	end

	refreshText()
	state.AttributeChanged:Connect(function(attribute: string)
		if attribute ~= "PhaseEndsAt" then
			refreshText()
		end
	end)

	-- Countdown: a few updates per second is plenty
	task.spawn(function()
		while gui.Parent do
			local endsAt = state:GetAttribute("PhaseEndsAt")
			if typeof(endsAt) == "number" and endsAt > 0 then
				timerLabel.Text = formatTime(endsAt - Workspace:GetServerTimeNow())
			else
				timerLabel.Text = ""
			end
			task.wait(0.25)
		end
	end)
end

return HUDController
