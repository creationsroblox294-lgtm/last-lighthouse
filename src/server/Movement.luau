--!strict
-- Movement: the one place that sets a character's WalkSpeed. Services set a base speed
-- (normal, carrying, latched); sprinting multiplies it, but only from a normal-speed base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Movement = {}
local sprinting: { [Player]: boolean } = {}

local function baseOf(humanoid: Humanoid): number
	local base = humanoid:GetAttribute("BaseWalkSpeed")
	return if typeof(base) == "number" then base else Config.Resources.WalkSpeed
end

function Movement.Apply(humanoid: Humanoid)
	local base = baseOf(humanoid)
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	local fast = player ~= nil and sprinting[player] == true and base >= Config.Resources.WalkSpeed
	humanoid.WalkSpeed = if fast then base * Config.Sprint.Multiplier else base
end

function Movement.SetBase(humanoid: Humanoid, speed: number)
	humanoid:SetAttribute("BaseWalkSpeed", speed)
	Movement.Apply(humanoid)
end

-- can this character sprint right now (not carrying, not latched, alive)?
function Movement.CanSprint(humanoid: Humanoid): boolean
	return humanoid.Health > 0 and baseOf(humanoid) >= Config.Resources.WalkSpeed
end

function Movement.SetSprinting(player: Player, on: boolean)
	if (sprinting[player] == true) == on then
		return
	end
	sprinting[player] = if on then true else nil
	player:SetAttribute("Sprinting", on or nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Movement.Apply(humanoid)
	end
end

function Movement.IsSprinting(player: Player): boolean
	return sprinting[player] == true
end

Players.PlayerRemoving:Connect(function(player)
	sprinting[player] = nil
end)

return Movement
