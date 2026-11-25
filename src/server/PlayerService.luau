--!strict
-- PlayerService: spawning, death and the "everyone is lost" rule.
-- Characters don't respawn by themselves (Players.CharacterAutoLoads = false):
--   - die in the calm or at dawn: back in a few seconds
--   - die in a warning or storm: lost in the fog until dawn, then back in the bunk room
--   - the bunk room must be standing to respawn (unless nobody is left to repair it)
--   - if everyone is down during a warning or storm, the run is lost

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local BuildService = require(script.Parent:WaitForChild("BuildService"))

local PlayerService = {}

local waitingSince: { [Player]: number } = {}

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function PlayerService.IsAlive(player: Player): boolean
	return isAlive(player) and waitingSince[player] == nil
end

local function aliveCount(): number
	local n = 0
	for _, player in Players:GetPlayers() do
		if PlayerService.IsAlive(player) then
			n += 1
		end
	end
	return n
end

local function spawnPlayer(player: Player)
	if not player.Parent then
		return
	end
	waitingSince[player] = nil
	player:SetAttribute("Lost", false)
	player:LoadCharacter()
end

local function checkEveryoneLost()
	local phase = StormDirector.GetPhase()
	if phase ~= "Storm" and phase ~= "Warning" then
		return
	end
	if #Players:GetPlayers() > 0 and aliveCount() == 0 then
		StormDirector.EndRun("Everyone was lost in the fog.")
	end
end

local function onDied(player: Player)
	waitingSince[player] = os.clock()
	local phase = StormDirector.GetPhase()
	if phase == "Storm" or phase == "Warning" then
		player:SetAttribute("Lost", true)
		Remotes.notify(player, "You're lost in the fog. You'll return at dawn if the bunk room still stands.", "Alarm")
		task.defer(checkEveryoneLost)
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			onDied(player)
		end)
	end
end

-- Respawn anyone who is waiting, when the rules allow it
local function respawnTick()
	local phase = StormDirector.GetPhase()
	if phase == "Storm" or phase == "Warning" then
		return
	end
	local nobodyLeft = aliveCount() == 0
	for player, since in waitingSince do
		local waited = os.clock() - since >= Config.Player.CalmRespawnSeconds
		if waited and (BuildService.CanRespawn() or nobodyLeft or phase == "Lost") then
			spawnPlayer(player)
		elseif waited and player:GetAttribute("Lost") ~= "bunk" then
			player:SetAttribute("Lost", "bunk")
			Remotes.notify(player, "The bunk room is broken. Someone has to repair it before you can respawn.", "Alarm")
		end
	end
end

function PlayerService.Start()
	Players.CharacterAutoLoads = false

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		spawnPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		if not player.Character then
			onPlayer(player)
		else
			player.CharacterAdded:Connect(function(character)
				onCharacter(player, character)
			end)
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		waitingSince[player] = nil
		task.defer(checkEveryoneLost)
	end)

	StormDirector.RunReset:Connect(function()
		for player in waitingSince do
			spawnPlayer(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			respawnTick()
		end
	end)
end

return PlayerService
