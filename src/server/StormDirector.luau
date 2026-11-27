--!strict
-- StormDirector: runs the calm -> warning -> storm -> dawn cycle, keeps the storm count,
-- and ends the run when the lighthouse falls or everyone is lost.
--
-- - State goes to SharedState "Storm" (attributes) for clients, plus Remotes "PhaseChanged".
-- - Server modules listen with:
--     StormDirector.PhaseChanged:Connect(function(info) ... end)
--     StormDirector.RunReset:Connect(function() ... end)        -- a new run is starting
--     StormDirector.StormSurvived:Connect(function(stormNumber) ... end)
-- - A boss can keep the storm going with StormDirector.HoldStorm(name, predicate, maxSeconds).
--
-- This is the only server module allowed a long-running phase loop (see DESIGN.md, Tech plan).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local Types = require(Shared:WaitForChild("Types"))
local StormTypes = require(Shared:WaitForChild("StormTypes"))

type Phase = Types.Phase
type PhaseInfo = Types.PhaseInfo
type Hold = { predicate: () -> boolean, untilTime: number }

local StormDirector = {}

local phaseChangedEvent = Instance.new("BindableEvent")
StormDirector.PhaseChanged = phaseChangedEvent.Event
local runResetEvent = Instance.new("BindableEvent")
StormDirector.RunReset = runResetEvent.Event
local stormSurvivedEvent = Instance.new("BindableEvent")
StormDirector.StormSurvived = stormSurvivedEvent.Event

local rng = Random.new()
local started = false
local state: Configuration
local runState: Configuration
local phaseChangedRemote: RemoteEvent

local stormsSurvived = 0
local currentStorm = 1
local isGreatStorm = false
local specialStorm: string? = nil -- tonight's StormTypes id
local currentPhase: Phase = "Calm"
local phaseEndsAt = 0
local holding = false
local lostReason: string? = nil
local holds: { [string]: Hold } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function fastCycle(): boolean
	if Config.DebugFastCycle then
		return true
	end
	return RunService:IsStudio() and Workspace:GetAttribute("DebugFastCycle") == true
end

local function durationOf(phase: Phase): number
	if fastCycle() then
		return if phase == "Storm" then Config.DebugStormSeconds else Config.DebugPhaseSeconds
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

function StormDirector.GetPhase(): Phase
	return currentPhase
end

-- Tonight's storm type (StormTypes entry)
function StormDirector.GetStormType(): StormTypes.StormType
	return StormTypes.Get(specialStorm)
end

local function publish()
	state:SetAttribute("Phase", currentPhase)
	state:SetAttribute("CurrentStorm", currentStorm)
	state:SetAttribute("StormsSurvived", stormsSurvived)
	state:SetAttribute("PhaseEndsAt", phaseEndsAt)
	state:SetAttribute("IsGreatStorm", isGreatStorm)
	state:SetAttribute("SpecialStorm", specialStorm or "")
	state:SetAttribute("StormType", specialStorm or "Ordinary")
	state:SetAttribute("Holding", holding)

	local info = StormDirector.GetInfo()
	phaseChangedRemote:FireAllClients(info)
	phaseChangedEvent:Fire(info)
end

local announce: (phase: Phase) -> () -- defined below rollStorm

-- Wait until a time; returns false if the run was lost meanwhile
local function waitUntil(t: number): boolean
	while now() < t do
		if lostReason then
			return false
		end
		task.wait(0.25)
	end
	return lostReason == nil
end

local function anyHoldActive(): boolean
	local active = false
	for name, hold in holds do
		if now() >= hold.untilTime or not hold.predicate() then
			holds[name] = nil
		else
			active = true
		end
	end
	return active
end

local function runPhase(phase: Phase): boolean
	currentPhase = phase
	holding = false
	phaseEndsAt = now() + durationOf(phase)
	publish()
	announce(phase)
	if not waitUntil(phaseEndsAt) then
		return false
	end
	-- A boss can keep the storm going until it is beaten (or its time runs out)
	if phase == "Storm" and anyHoldActive() then
		holding = true
		phaseEndsAt = 0
		publish()
		while anyHoldActive() do
			if lostReason then
				return false
			end
			task.wait(0.25)
		end
		holding = false
	end
	return lostReason == nil
end

-- Roll tonight's storm type (StormTypes). Early storms only roll easy types; Great Storms
-- are always the ordinary boss storm. Studio: set Workspace attribute DebugStormType
-- (e.g. "GoldenRain") to force a type.
local function rollStorm()
	isGreatStorm = currentStorm % Config.GreatStormEvery == 0 or currentStorm >= Config.LastLightStartsAt
	local forced = Workspace:GetAttribute("DebugStormType")
	local forcedId = if RunService:IsStudio() and typeof(forced) == "string" and forced ~= "" then forced else nil
	if isGreatStorm and not forcedId then
		specialStorm = "Ordinary"
	else
		specialStorm = StormTypes.Roll(currentStorm, rng, forcedId).Id
	end
end

-- Tell everyone what's coming (calm) and what it is (storm start)
function announce(phase: Phase)
	local t = StormTypes.Get(specialStorm)
	if t.Id == "Ordinary" then
		return
	end
	if phase == "Calm" then
		Remotes.notify(nil, `Barometer: {t.Forecast}`, nil)
	elseif phase == "Storm" then
		Remotes.notify(nil, t.Blurb, if t.Tier == "Blessed" then "Good" else "Alarm")
	end
end

-- One full run. Returns true if the group survived every storm.
local function runOnce(): boolean
	stormsSurvived = 0
	-- Studio only: set the DebugStartStorm attribute on Workspace to jump ahead (e.g. 10 for the boss)
	local startAt = Workspace:GetAttribute("DebugStartStorm")
	if RunService:IsStudio() and typeof(startAt) == "number" and startAt > 1 then
		stormsSurvived = math.clamp(math.floor(startAt) - 1, 0, Config.MaxStorms - 1)
	end
	while stormsSurvived < Config.MaxStorms do
		currentStorm = stormsSurvived + 1
		rollStorm()
		table.clear(holds)
		if not runPhase("Calm") then
			return false
		end
		if not runPhase("Warning") then
			return false
		end
		if not runPhase("Storm") then
			return false
		end
		stormsSurvived += 1
		stormSurvivedEvent:Fire(currentStorm)
		if not runPhase("Dawn") then
			return false
		end
	end
	return true
end

-- Called after a run's end screen; return true to stop (e.g. the party is sent home)
local runEndedHandler: ((won: boolean) -> boolean)? = nil

local function loop()
	while true do
		lostReason = nil
		runState:SetAttribute("LostReason", "")
		table.clear(holds)
		runResetEvent:Fire()
		local won = runOnce()
		holding = false
		if won then
			currentPhase = "Won"
			phaseEndsAt = now() + 30
			publish()
			Remotes.notify(nil, `You kept the light burning through {Config.MaxStorms} storms!`, "Good")
			task.wait(30)
			if runEndedHandler and runEndedHandler(true) then
				return
			end
		else
			currentPhase = "Lost"
			phaseEndsAt = now() + Config.LostScreenSeconds
			runState:SetAttribute("LostReason", lostReason or "The light went out.")
			publish()
			task.wait(Config.LostScreenSeconds)
			if runEndedHandler and runEndedHandler(false) then
				return
			end
		end
	end
end

-- What happens when a run is over (after its end screen). Return true to end the loop.
function StormDirector.OnRunEnded(fn: (won: boolean) -> boolean)
	runEndedHandler = fn
end

-- Keep the storm going while predicate() is true, for at most maxSeconds from now
function StormDirector.HoldStorm(name: string, predicate: () -> boolean, maxSeconds: number)
	holds[name] = { predicate = predicate, untilTime = now() + maxSeconds }
end

-- End the current run (the lighthouse fell, or everyone was lost)
function StormDirector.EndRun(reason: string)
	if lostReason or currentPhase == "Lost" or currentPhase == "Won" then
		return
	end
	lostReason = reason
	Remotes.notify(nil, reason, "Alarm")
end

function StormDirector.Start()
	if started then
		return
	end
	started = true
	state = SharedState.get("Storm")
	runState = SharedState.get("Run")
	phaseChangedRemote = Remotes.event("PhaseChanged")
	task.spawn(loop)
end

return StormDirector
