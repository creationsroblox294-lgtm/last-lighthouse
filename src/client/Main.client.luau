--!strict
-- Client entry point: starts each controller.

local FogController = require(script.Parent:WaitForChild("FogController"))
local LightController = require(script.Parent:WaitForChild("LightController"))
local WeatherController = require(script.Parent:WaitForChild("WeatherController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CreatureController = require(script.Parent:WaitForChild("CreatureController"))
local LadderController = require(script.Parent:WaitForChild("LadderController"))
local HollowController = require(script.Parent:WaitForChild("HollowController"))
local TreeAnimalController = require(script.Parent:WaitForChild("TreeAnimalController"))
local PunchController = require(script.Parent:WaitForChild("PunchController"))

FogController.Start()
LightController.Start()
WeatherController.Start()
HUDController.Start()
CreatureController.Start()
LadderController.Start()
HollowController.Start()
TreeAnimalController.Start()
PunchController.Start()
