--!strict
-- GameMode: is this server the harbor lobby or a party's game?
--
--   * Public servers are the lobby (Workspace.Lobby). Players step onto a boat (up to 4);
--     when it casts off, the server reserves a private server and teleports the party there.
--   * Reserved servers are the game (Workspace.Map, storms, the lighthouse).
--   * Studio: starts in the lobby; a boat casting off switches this server into the game
--     (teleports don't work in Studio). Set Workspace attribute ForceMode = "Game" (or
--     "Lobby") to pick one directly.
--
-- The server publishes the mode as the ReplicatedStorage attribute "GameMode".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type Mode = "Lobby" | "Game"

local GameMode = {}

-- True on a reserved (party) server
function GameMode.IsReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- Server: which mode this server starts in
function GameMode.Resolve(): Mode
	local forced = Workspace:GetAttribute("ForceMode")
	if forced == "Game" or forced == "Lobby" then
		return forced
	end
	if GameMode.IsReservedServer() then
		return "Game"
	end
	return "Lobby"
end

-- Server: publish the mode
function GameMode.Set(mode: Mode)
	ReplicatedStorage:SetAttribute("GameMode", mode)
end

function GameMode.Get(): Mode?
	local m = ReplicatedStorage:GetAttribute("GameMode")
	if m == "Lobby" or m == "Game" then
		return m
	end
	return nil
end

-- Wait until the mode is known (clients) and return it
function GameMode.Wait(): Mode
	while not GameMode.Get() do
		ReplicatedStorage:GetAttributeChangedSignal("GameMode"):Wait()
	end
	return GameMode.Get() :: Mode
end

-- Wait until the mode is `mode`
function GameMode.WaitFor(mode: Mode)
	while GameMode.Get() ~= mode do
		ReplicatedStorage:GetAttributeChangedSignal("GameMode"):Wait()
	end
end

function GameMode.IsStudio(): boolean
	return RunService:IsStudio()
end

return GameMode
