--!strict
-- The current storm state lives as attributes on ReplicatedStorage.StormState,
-- so players who join late get it automatically. Only the server writes to it.
--
-- Attributes: Phase, CurrentStorm, StormsSurvived, PhaseEndsAt, IsGreatStorm, SpecialStorm

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAME = "StormState"

local StormState = {}

function StormState.get(): Configuration
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(NAME)
		if existing and existing:IsA("Configuration") then
			return existing
		end
		local config = Instance.new("Configuration")
		config.Name = NAME
		config.Parent = ReplicatedStorage
		return config
	end
	local found = ReplicatedStorage:WaitForChild(NAME)
	if found:IsA("Configuration") then
		return found
	end
	error("ReplicatedStorage.StormState is not a Configuration")
end

return StormState
