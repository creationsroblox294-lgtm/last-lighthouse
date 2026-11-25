--!strict
-- Server entry point: starts each service in order, then the storm cycle.

local Server = script.Parent

local StormDirector = require(Server:WaitForChild("StormDirector"))
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))
local BuildService = require(Server:WaitForChild("BuildService"))
local EnemyService = require(Server:WaitForChild("EnemyService"))
local TideCaller = require(Server:WaitForChild("TideCaller"))
local CombatService = require(Server:WaitForChild("CombatService"))
local PlayerService = require(Server:WaitForChild("PlayerService"))
local DataService = require(Server:WaitForChild("DataService"))

-- Remotes and state objects must exist before clients look for them
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).event("Notify")

LightService.Start()
ResourceService.Start()
BuildService.Start()
EnemyService.Start()
TideCaller.Start()
CombatService.Start()
PlayerService.Start()
DataService.Start()
StormDirector.Start()
