--!strict
-- Client entry point: starts each controller.

local FogController = require(script.Parent:WaitForChild("FogController"))
local LightController = require(script.Parent:WaitForChild("LightController"))
local WeatherController = require(script.Parent:WaitForChild("WeatherController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

FogController.Start()
LightController.Start()
WeatherController.Start()
HUDController.Start()
