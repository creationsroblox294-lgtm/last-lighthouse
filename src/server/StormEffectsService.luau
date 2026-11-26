--!strict
-- StormEffectsService: what each storm type does to players during the storm phase
-- (fuel and creature numbers are handled by LightService and EnemyService).
--   * HealPerSecond (Golden Rain): players standing out in the open, with nothing but
--     sky above them, slowly heal.

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

function StormEffectsService.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return StormEffectsService
