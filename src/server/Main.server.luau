--!strict
-- Server entry point: starts each service in order, then the storm cycle.

local Server = script.Parent

local StormDirector = require(Server:WaitForChild("StormDirector"))
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))
local FishService = require(Server:WaitForChild("FishService"))
local BuildService = require(Server:WaitForChild("BuildService"))
local EnemyService = require(Server:WaitForChild("EnemyService"))
local TideCaller = require(Server:WaitForChild("TideCaller"))
local HollowService = require(Server:WaitForChild("HollowService"))
local CombatService = require(Server:WaitForChild("CombatService"))
local PunchService = require(Server:WaitForChild("PunchService"))
local IntroService = require(Server:WaitForChild("IntroService"))
local PlayerService = require(Server:WaitForChild("PlayerService"))
local DataService = require(Server:WaitForChild("DataService"))
local ForageService = require(Server:WaitForChild("ForageService"))
local TreeAnimalService = require(Server:WaitForChild("TreeAnimalService"))

-- Remotes and state objects must exist before clients look for them
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).event("Notify")

LightService.Start()
ResourceService.Start()
FishService.Start()
BuildService.Start()
EnemyService.Start()
TideCaller.Start()
HollowService.Start()
CombatService.Start()
PunchService.Start()
IntroService.Start()
PlayerService.Start()
DataService.Start()
ForageService.Start()
TreeAnimalService.Start()
StormDirector.Start()
