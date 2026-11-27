--!strict
-- Client entry point. In the harbor lobby only LobbyController runs; on a game server
-- (or once a Studio test casts off) every game controller starts.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameMode = require(Shared:WaitForChild("GameMode"))
if GameMode.Wait() == "Lobby" then
	local LobbyController = require(script.Parent:WaitForChild("LobbyController"))
	LobbyController.Start()
	GameMode.WaitFor("Game")
	LobbyController.Stop()
end

local FogController = require(script.Parent:WaitForChild("FogController"))
local LightController = require(script.Parent:WaitForChild("LightController"))
local WeatherController = require(script.Parent:WaitForChild("WeatherController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CreatureController = require(script.Parent:WaitForChild("CreatureController"))
local LadderController = require(script.Parent:WaitForChild("LadderController"))
local HollowController = require(script.Parent:WaitForChild("HollowController"))
local TreeAnimalController = require(script.Parent:WaitForChild("TreeAnimalController"))
local PunchController = require(script.Parent:WaitForChild("PunchController"))
local IntroController = require(script.Parent:WaitForChild("IntroController"))
local SprintController = require(script.Parent:WaitForChild("SprintController"))
local MinimapController = require(script.Parent:WaitForChild("MinimapController"))
local StormFXController = require(script.Parent:WaitForChild("StormFXController"))
local StormReactionController = require(script.Parent:WaitForChild("StormReactionController"))
local BackpackController = require(script.Parent:WaitForChild("BackpackController"))
local FlareController = require(script.Parent:WaitForChild("FlareController"))

FogController.Start()
LightController.Start()
WeatherController.Start()
HUDController.Start()
CreatureController.Start()
LadderController.Start()
HollowController.Start()
TreeAnimalController.Start()
PunchController.Start()
SprintController.Start()
MinimapController.Start()
StormFXController.Start()
StormReactionController.Start()
BackpackController.Start()
FlareController.Start()
task.spawn(IntroController.Start)

-- Preload the tool meshes (Harpoon, Hammer, Flare) so they don't pop in on first equip
task.spawn(function()
	local player = game:GetService("Players").LocalPlayer
	local backpack = player:WaitForChild("Backpack")
	task.wait(2)
	local parts = {}
	for _, tool in backpack:GetChildren() do
		for _, part in tool:GetChildren() do
			if part:IsA("MeshPart") then
				table.insert(parts, part)
			end
		end
	end
	if #parts > 0 then
		game:GetService("ContentProvider"):PreloadAsync(parts)
	end
end)
