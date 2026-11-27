--!strict
-- LeaderboardService: the three boards in the harbor (Lobby.Boards, built by
-- tools/BuildLobbyBoards.luau): Furthest Storm, Brass Earned and Lights Kept.
-- DataService writes each player's stats to OrderedDataStores "Board_<Stat>" when it saves;
-- every Config.Keeper.BoardRefreshSeconds this reads the top 8 and fills the boards' rows.
-- If the stores can't be read (Studio without API access), it ranks the players in this
-- server instead, so the boards never sit empty. Each client adds its own "You" row.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local LeaderboardService = {}

local ROWS = 8
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local present = Players:GetPlayerByUserId(userId)
	if present then
		names[userId] = present.DisplayName
		return present.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and typeof(name) == "string" then name else "Keeper"
	return names[userId]
end

type Entry = { userId: number, value: number }

local function readStore(stat: string): { Entry }?
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore("Board_" .. stat):GetSortedAsync(false, ROWS)
	end)
	if not ok or not pages then
		return nil
	end
	local out = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(item.key)
		if id then
			table.insert(out, { userId = id, value = item.value })
		end
	end
	return out
end

local function fromServer(stat: string): { Entry }
	local out = {}
	for _, player in Players:GetPlayers() do
		local profile = DataService.GetProfile(player) :: any
		local v = profile and profile[stat]
		if typeof(v) == "number" and v > 0 then
			table.insert(out, { userId = player.UserId, value = v })
		end
	end
	table.sort(out, function(a, b)
		return a.value > b.value
	end)
	return out
end

local function fill(board: Instance, entries: { Entry })
	local face = board:FindFirstChild("Face")
	local gui = face and face:FindFirstChild("BoardGui")
	local rows = gui and gui:FindFirstChild("Rows")
	if not rows then
		return
	end
	for i = 1, ROWS do
		local row = rows:FindFirstChild("Row" .. i)
		if row then
			local e = entries[i]
			local nameLabel = row:FindFirstChild("Name") :: TextLabel?
			local valueLabel = row:FindFirstChild("Value") :: TextLabel?
			if nameLabel and valueLabel then
				nameLabel.Text = if e then nameOf(e.userId) else "—"
				valueLabel.Text = if e then tostring(e.value) else ""
			end
		end
	end
end

local function refresh()
	local folder = Workspace:FindFirstChild("Lobby") and (Workspace :: any).Lobby:FindFirstChild("Boards")
	if not folder then
		return
	end
	for _, b in Config.Keeper.Boards :: { any } do
		local board = folder:FindFirstChild("Board_" .. b.Stat)
		if board then
			local entries = readStore(b.Stat)
			if not entries or #entries == 0 then
				entries = fromServer(b.Stat)
			end
			fill(board, entries)
		end
	end
end

local running = false
function LeaderboardService.Start()
	running = true
	task.spawn(function()
		task.wait(3) -- let profiles load
		while running do
			refresh()
			task.wait(Config.Keeper.BoardRefreshSeconds)
		end
	end)
	DataService.Loaded:Connect(function()
		task.delay(1, refresh)
	end)
end

function LeaderboardService.Stop()
	running = false
end

return LeaderboardService
