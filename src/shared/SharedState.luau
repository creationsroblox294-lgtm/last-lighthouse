--!strict
-- Replicated game state: Configuration objects under ReplicatedStorage.State,
-- with values stored as attributes (players who join late get them automatically).
-- Only the server writes. Names in use:
--   Storm   Phase, CurrentStorm, StormsSurvived, PhaseEndsAt, IsGreatStorm, SpecialStorm, Holding
--   Light   Fuel, MaxFuel, Radius, IsLit, BeamAngle, BeamSpeed, Controller, LightsOutAt, LensTier
--   Tower   GroundFloor, BunkRoom, LampRoom, MaxHealth
--   Storage Wood, Scrap, Oil, Fish
--   Boss    Active, Health, MaxHealth
--   Run     LostReason

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedState = {}

local function root(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("State")
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = "State"
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild("State")
end

function SharedState.get(name: string): Configuration
	local folder = root()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("Configuration") then
			return existing
		end
		local config = Instance.new("Configuration")
		config.Name = name
		config.Parent = folder
		return config
	end
	local found = folder:WaitForChild(name)
	if found:IsA("Configuration") then
		return found
	end
	error(`State {name} is not a Configuration`)
end

-- Read a number attribute with a default
function SharedState.number(config: Configuration, attribute: string, default: number): number
	local value = config:GetAttribute(attribute)
	return if typeof(value) == "number" then value else default
end

return SharedState
