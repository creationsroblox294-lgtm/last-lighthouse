--!strict
-- StormEffectsService: what each storm type does to players during the storm phase
-- (fuel and creature numbers are handled by LightService and EnemyService).
--   * HealPerSecond (Golden Rain): players standing out in the open, with nothing but
--     sky above them, slowly heal.
--   * Storms/<StormId> modules (if present) get Start() when their storm begins and Stop()
--     when it ends, for storms with their own events (meteors, lightning, waves...).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local StormDirector = require(script.Parent:WaitForChild("StormDirector"))

local StormEffectsService = {}

local TICK = 0.5

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

-- true if nothing solid is between this point and the sky
local function underOpenSky(pos: Vector3, character: Model): boolean
	params.FilterDescendantsInstances = { character }
	return Workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, 300, 0), params) == nil
end

local function tick()
	if StormDirector.GetPhase() ~= "Storm" then
		return
	end
	local t = StormDirector.GetStormType()
	local heal = t.HealPerSecond
	if not heal or heal <= 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			if underOpenSky(root.Position, character) then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal * TICK)
			end
		end
	end
end

type StormModule = { Start: () -> (), Stop: () -> () }
local running: StormModule? = nil

local function moduleFor(id: string): StormModule?
	local folder = script.Parent:FindFirstChild("Storms")
	local m = folder and folder:FindFirstChild(id)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok and typeof(mod) == "table" then
			return mod :: any
		end
		warn("[StormEffects] couldn't load", id, mod)
	end
	return nil
end

function StormEffectsService.Start()
	StormDirector.PhaseChanged:Connect(function(info)
		if info.phase == "Storm" and not running then
			local mod = moduleFor(StormDirector.GetStormType().Id)
			if mod then
				running = mod
				task.spawn(mod.Start)
			end
		elseif info.phase ~= "Storm" and running then
			local mod = running
			running = nil
			task.spawn(mod.Stop)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return StormEffectsService
