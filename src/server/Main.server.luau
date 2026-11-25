--!strict
-- Server entry point: starts each service in order.

local StormDirector = require(script.Parent:WaitForChild("StormDirector"))

StormDirector.Start()
