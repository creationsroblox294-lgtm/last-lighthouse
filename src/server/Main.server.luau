--!strict
-- Server entry point.
--   Lobby servers (public): show the harbor, run LobbyService, nothing else.
--   Game servers (reserved, one per party): show the island, start each service in order,
--   then the storm cycle; when the run is over, send everyone back to the harbor.
--   Studio: starts in the lobby, and a boat casting off switches this server into the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Server = script.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameMode = require(Shared:WaitForChild("GameMode"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Remotes must exist before clients look for them
Remotes.event("Notify")

---------------------------------------------------------------------------
-- Which world is in Workspace: the harbor (Lobby) or the island (Map).
-- The other one waits in ServerStorage.Parked so clients never load it.
---------------------------------------------------------------------------
local parked = ServerStorage:FindFirstChild("Parked") or Instance.new("Folder")
parked.Name = "Parked"
parked.Parent = ServerStorage

local function park(name: string)
	local m = Workspace:FindFirstChild(name)
	if m then
		m.Parent = parked
	end
end
local function unpark(name: string)
	local m = parked:FindFirstChild(name)
	if m then
		m.Parent = Workspace
	end
end
local function showWorld(mode: GameMode.Mode)
	if mode == "Lobby" then
		park("Map")
		unpark("Lobby")
	else
		park("Lobby")
		unpark("Map")
	end
end

-- Saved progress and the core loop run on every server (the Locker is in the harbor)
local DataService = require(Server:WaitForChild("DataService"))
local KeeperService = require(Server:WaitForChild("KeeperService"))
DataService.Start()
KeeperService.Start()

local mode = GameMode.Resolve()
if mode == "Lobby" then
	showWorld("Lobby")
	GameMode.Set("Lobby")
	local LobbyService = require(Server:WaitForChild("LobbyService"))
	local launched = Instance.new("BindableEvent")
	LobbyService.SetStudioLaunch(function()
		launched:Fire()
	end)
	LobbyService.Start()
	local LeaderboardService = require(Server:WaitForChild("LeaderboardService"))
	LeaderboardService.Start()
	if not RunService:IsStudio() then
		-- a real lobby server never runs the game
		return
	end
	launched.Event:Wait()
	LobbyService.Stop()
	LeaderboardService.Stop()
	-- Studio: become the game, with everyone on this server as the party
	showWorld("Game")
	GameMode.Set("Game")
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Boat", nil)
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
else
	showWorld("Game")
	GameMode.Set("Game")
end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------
local StormDirector = require(Server:WaitForChild("StormDirector"))
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))
local FishService = require(Server:WaitForChild("FishService"))
local BuildService = require(Server:WaitForChild("BuildService"))
local EnemyService = require(Server:WaitForChild("EnemyService"))
local TideCaller = require(Server:WaitForChild("TideCaller"))
local HollowService = require(Server:WaitForChild("HollowService"))
local CombatService = require(Server:WaitForChild("CombatService"))
local CraftingService = require(Server:WaitForChild("CraftingService"))
local PunchService = require(Server:WaitForChild("PunchService"))
local IntroService = require(Server:WaitForChild("IntroService"))
local PlayerService = require(Server:WaitForChild("PlayerService"))
local ForageService = require(Server:WaitForChild("ForageService"))
local TreeAnimalService = require(Server:WaitForChild("TreeAnimalService"))
local SprintService = require(Server:WaitForChild("SprintService"))
local StormEffectsService = require(Server:WaitForChild("StormEffectsService"))

LightService.Start()
ResourceService.Start()
FishService.Start()
BuildService.Start()
EnemyService.Start()
TideCaller.Start()
HollowService.Start()
CombatService.Start()
CraftingService.Start()
PunchService.Start()
IntroService.Start()
PlayerService.Start()
KeeperService.StartGame()
ForageService.Start()
TreeAnimalService.Start()
SprintService.Start()
StormEffectsService.Start()

-- A party's own server: when the run is over, row everyone back to the harbor
if GameMode.IsReservedServer() then
	StormDirector.OnRunEnded(function(_won: boolean): boolean
		Remotes.notify(nil, `Rowing back to the harbor in {Config.Lobby.ReturnDelay}s...`, nil)
		task.wait(Config.Lobby.ReturnDelay)
		local everyone = Players:GetPlayers()
		if #everyone > 0 then
			local ok = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, everyone)
			end)
			if not ok then
				for _, p in everyone do
					p:Kick("The run is over. Rejoin to get back to the harbor.")
				end
			end
		end
		return true
	end)
end

StormDirector.Start()
