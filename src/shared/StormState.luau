--!strict
-- Kept for older code: the storm state is SharedState "Storm".
local SharedState = require(script.Parent:WaitForChild("SharedState"))

local StormState = {}

function StormState.get(): Configuration
	return SharedState.get("Storm")
end

return StormState
