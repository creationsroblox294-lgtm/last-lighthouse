--!strict
-- Client entry point: starts each controller.

local FogController = require(script.Parent:WaitForChild("FogController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

FogController.Start()
HUDController.Start()
