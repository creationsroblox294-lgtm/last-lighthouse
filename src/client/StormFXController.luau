--!strict
-- StormFXController: plays the look of tonight's storm type during the storm phase.
-- Each built storm has a module in StormFX/<StormId> that returns build(ctx); shared helpers
-- live in StormFX/Common. Textures come from StormTypes[<id>].Textures (Blender renders).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StormState = require(Shared:WaitForChild("StormState"))
local StormTypes = require(Shared:WaitForChild("StormTypes"))

local FXFolder = script.Parent:WaitForChild("StormFX")
local Common = require(FXFolder:WaitForChild("Common"))

local StormFXController = {}

local function builderFor(id: string?): ((Common.Ctx) -> ())?
	if not id or id == "Common" then
		return nil
	end
	local m = FXFolder:FindFirstChild(id)
	if m and m:IsA("ModuleScript") then
		local ok, fn = pcall(require, m)
		if ok and typeof(fn) == "function" then
			return fn
		end
		warn("[StormFX] couldn't load", id, fn)
	end
	return nil
end

-- Does this storm type draw its own rain? (WeatherController skips its plain rain)
function StormFXController.HasCustomRain(id: string?): boolean
	if not id then
		return false
	end
	local t = StormTypes.Get(id)
	if (t :: any).KeepPlainRain then
		return false
	end
	return FXFolder:FindFirstChild(id) ~= nil
end

-- How strong tonight's look is in each phase: it starts rolling in during the warning,
-- reaches full strength in the storm and clears away when dawn comes.
local LEVEL = { Warning = 0.3, Storm = 1 }

function StormFXController.Start()
	local state = StormState.get()
	local stop: ((boolean?) -> ())? = nil
	local setLevel: ((number) -> ())? = nil
	local getRaw: (() -> number)? = nil
	local activeId: string? = nil
	local activePhase: string? = nil

	local function refresh()
		local phase = state:GetAttribute("Phase")
		local id = state:GetAttribute("StormType")
		local level = if typeof(phase) == "string" then LEVEL[phase] else nil
		local want: string? = nil
		if level and typeof(id) == "string" and builderFor(id) then
			want = id
		end
		if want == activeId and want ~= nil and activePhase == "Storm" then
			return
		end
		if want == nil and activeId == nil then
			return
		end
		-- Warning -> Storm with the same storm: rebuild it (the storm's server side has only
		-- now set things like the wind direction) and carry on from the preview's strength
		local carry = 0
		if want ~= nil and want == activeId and stop and getRaw then
			carry = getRaw()
			stop(true)
		elseif stop then
			stop()
		end
		stop, setLevel, getRaw = nil, nil, nil
		activeId = want
		activePhase = if want then phase else nil
		if want and level then
			local build = builderFor(want)
			if build then
				stop, setLevel, getRaw = Common.run(StormTypes.Get(want).Textures, build, level, carry)
			end
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refresh)
	state:GetAttributeChangedSignal("StormType"):Connect(refresh)
	refresh()
end

return StormFXController
