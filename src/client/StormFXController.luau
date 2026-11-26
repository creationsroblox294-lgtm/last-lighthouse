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

function StormFXController.Start()
	local state = StormState.get()
	local stop: (() -> ())? = nil
	local activeId: string? = nil

	local function refresh()
		local phase = state:GetAttribute("Phase")
		local id = state:GetAttribute("StormType")
		local want: string? = nil
		if phase == "Storm" and typeof(id) == "string" and builderFor(id) then
			want = id
		end
		if want == activeId then
			return
		end
		if stop then
			stop()
			stop = nil
		end
		activeId = want
		if want then
			local build = builderFor(want)
			if build then
				stop = Common.run(StormTypes.Get(want).Textures, build)
			end
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refresh)
	state:GetAttributeChangedSignal("StormType"):Connect(refresh)
	refresh()
end

return StormFXController
