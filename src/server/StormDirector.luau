--!strict
-- StormDirector: runs the calm -> warning -> storm -> dawn cycle and keeps the storm count.
--
-- - Writes the state to ReplicatedStorage.StormState (attributes) for clients.
-- - Fires Remotes "PhaseChanged" to all clients on every phase change.
-- - Other server modules can listen with StormDirector.PhaseChanged:Connect(function(info) ... end)
--
-- This is the only server module allowed a running loop (see DESIGN.md, Tech plan).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormState = require(Shared:WaitForChild("StormState"))
local Types = require(Shared:WaitForChild("Types"))

type Phase = Types.Phase
type PhaseInfo = Types.PhaseInfo

local StormDirector = {}

local phaseChangedEvent = Instance.new("BindableEvent")
StormDirector.PhaseChanged = phaseChangedEvent.Event

local rng = Random.new()
local started = false
local state: Configuration
local phaseChangedRemote: RemoteEvent

local stormsSurvived = 0
local currentStorm = 1
local isGreatStorm = false
local specialStorm: string? = nil
local currentPhase: Phase = "Calm"
local phaseEndsAt = 0

local function fastCycle(): boolean
	if Config.DebugFastCycle then
		return true
	end
	return RunService:IsStudio() and Workspace:GetAttribute("DebugFastCycle") == true
end

local function durationOf(phase: Phase): number
	if fastCycle() then
		return Config.DebugPhaseSeconds
	end
	local d = Config.PhaseDurations
	if phase == "Calm" then
		return d.Calm
	elseif phase == "Warning" then
		return d.Warning
	elseif phase == "Storm" then
		return rng:NextNumber(d.StormMin, d.StormMax)
	elseif phase == "Dawn" then
		return d.Dawn
	end
	return 0
end

function StormDirector.GetInfo(): PhaseInfo
	return {
		phase = currentPhase,
		currentStorm = currentStorm,
		stormsSurvived = stormsSurvived,
		endsAt = phaseEndsAt,
		isGreatStorm = isGreatStorm,
		specialStorm = specialStorm,
	}
end

local function publish()
	state:SetAttribute("Phase", currentPhase)
	state:SetAttribute("CurrentStorm", currentStorm)
	state:SetAttribute("StormsSurvived", stormsSurvived)
	state:SetAttribute("PhaseEndsAt", phaseEndsAt)
	state:SetAttribute("IsGreatStorm", isGreatStorm)
	state:SetAttribute("SpecialStorm", specialStorm or "")

	local info = StormDirector.GetInfo()
	phaseChangedRemote:FireAllClients(info)
	phaseChangedEvent:Fire(info)
end

local function runPhase(phase: Phase)
	local duration = durationOf(phase)
	currentPhase = phase
	phaseEndsAt = Workspace:GetServerTimeNow() + duration
	publish()
	task.wait(duration)
end

-- Decide what kind of storm is coming (shown on the HUD during the calm)
local function rollStorm()
	isGreatStorm = currentStorm % Config.GreatStormEvery == 0 or currentStorm >= Config.LastLightStartsAt
	specialStorm = nil
	if not isGreatStorm and rng:NextNumber() < Config.SpecialStormChance then
		specialStorm = Config.SpecialStorms[rng:NextInteger(1, #Config.SpecialStorms)]
	end
end

local function loop()
	while stormsSurvived < Config.MaxStorms do
		currentStorm = stormsSurvived + 1
		rollStorm()
		runPhase("Calm")
		runPhase("Warning")
		runPhase("Storm")
		stormsSurvived += 1
		runPhase("Dawn")
	end
	currentPhase = "Won"
	phaseEndsAt = 0
	publish()
end

function StormDirector.Start()
	if started then
		return
	end
	started = true
	state = StormState.get()
	phaseChangedRemote = Remotes.event("PhaseChanged")
	task.spawn(loop)
end

return StormDirector
