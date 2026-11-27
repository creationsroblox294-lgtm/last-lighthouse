--!strict
-- DataService: saves each player's Keeper Level (XP), best storm, storms survived, and the
-- core loop's Brass, runs won, what they own at the Keeper's Locker and what they wear
-- (KeeperService changes those through GetProfile + Changed). Runs on lobby and game servers.
-- - Session locking: a server marks the profile as its own while the player is in it, so two
--   servers can't overwrite each other. Stale locks (older than 10 min) are taken over.
-- - Retries with backoff on every DataStore call, autosave, and BindToClose.
-- - In Studio without "Enable Studio Access to API Services", it plays without saving.

local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local PlayerService = require(script.Parent:WaitForChild("PlayerService"))

local P = Config.Progress
local DataService = {}

export type Profile = {
	XP: number,
	BestStorm: number,
	StormsSurvived: number,
	Brass: number, -- to spend
	BrassEarned: number, -- all-time
	RunsWon: number,
	Owned: { [string]: number }, -- perk id -> tier, lantern/title id -> 1
	Title: string,
	Lantern: string, -- "" = none
	DailyDay: number, -- UTC day number of the last daily bonus
	Redeemed: { [string]: boolean }, -- codes already used
	Version: number,
}

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}
local store: DataStore? = nil
local LOCK_EXPIRE_SECONDS = 600

local function defaultProfile(): Profile
	return {
		XP = 0,
		BestStorm = 0,
		StormsSurvived = 0,
		Brass = 0,
		BrassEarned = 0,
		RunsWon = 0,
		Owned = {},
		Title = "Castaway",
		Lantern = "",
		DailyDay = 0,
		Redeemed = {},
		Version = 2,
	}
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function reconcile(data: any): Profile
	local profile = defaultProfile()
	if typeof(data) == "table" then
		for k, v in data do
			if (profile :: any)[k] ~= nil and typeof(v) == typeof((profile :: any)[k]) then
				(profile :: any)[k] = v
			end
		end
	end
	-- only keep sane entries in Owned
	local owned = {}
	for id, tier in profile.Owned do
		if typeof(id) == "string" and typeof(tier) == "number" and tier >= 1 then
			owned[id] = math.floor(tier)
		end
	end
	profile.Owned = owned
	local redeemed = {}
	for code, used in profile.Redeemed do
		if typeof(code) == "string" and used == true then
			redeemed[code] = true
		end
	end
	profile.Redeemed = redeemed
	profile.Version = 2
	return profile
end

local function levelOf(profile: Profile): number
	return math.floor(profile.XP / P.XPPerLevel) + 1
end

local function updateLeaderstats(player: Player)
	local profile = profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	if not profile or not stats then
		return
	end
	local level = stats:FindFirstChild("Level")
	local best = stats:FindFirstChild("Best")
	if level and level:IsA("IntValue") then
		level.Value = levelOf(profile)
	end
	if best and best:IsA("IntValue") then
		best.Value = profile.BestStorm
	end
	player:SetAttribute("KeeperLevel", levelOf(profile))
	player:SetAttribute("Brass", profile.Brass)
	player:SetAttribute("BrassEarned", profile.BrassEarned)
end

local loadedEvent = Instance.new("BindableEvent")
-- Fires (player) once their profile is ready (loaded, or a fresh one if saving is off)
DataService.Loaded = loadedEvent.Event

local function ready(player: Player)
	updateLeaderstats(player)
	player:SetAttribute("ProfileLoaded", true)
	loadedEvent:Fire(player)
end

local function makeLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = stats
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Parent = stats
	stats.Parent = player
end

local function load(player: Player)
	makeLeaderstats(player)
	local ds = store
	if not ds then
		profiles[player] = defaultProfile()
		ready(player)
		return
	end
	local key = keyFor(player)
	for attempt = 1, 5 do
		local force = attempt == 5
		local ok, result = pcall(function()
			return ds:UpdateAsync(key, function(old: any)
				local record = if typeof(old) == "table" then old else { data = defaultProfile() }
				local lock = record.lock
				if not force and typeof(lock) == "table" and lock.job ~= game.JobId and os.time() - (lock.time or 0) < LOCK_EXPIRE_SECONDS then
					return nil -- another server owns it right now
				end
				record.lock = { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if not player.Parent then
			return
		end
		if ok and typeof(result) == "table" and typeof(result.lock) == "table" and result.lock.job == game.JobId then
			profiles[player] = reconcile(result.data)
			canSave[player] = true
			ready(player)
			return
		end
		task.wait(2 * attempt)
	end
	profiles[player] = defaultProfile()
	ready(player)
	Remotes.notify(player, "Your progress couldn't be loaded, so this session won't be saved.", "Alarm")
end

local function save(player: Player, release: boolean)
	local ds = store
	local profile = profiles[player]
	if not ds or not profile or not canSave[player] then
		return
	end
	local key = keyFor(player)
	local delay = 1
	for _ = 1, 3 do
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old: any)
				if typeof(old) == "table" and typeof(old.lock) == "table" and old.lock.job ~= game.JobId then
					return nil -- another server took over; don't overwrite it
				end
				return {
					data = profile,
					lock = if release then nil else { job = game.JobId, time = os.time() },
				}
			end)
		end)
		if ok then
			-- the harbor's leaderboards read these (LeaderboardService)
			for _, board in Config.Keeper.Boards :: { any } do
				local value = (profile :: any)[board.Stat]
				if typeof(value) == "number" and value > 0 then
					pcall(function()
						DataStoreService:GetOrderedDataStore("Board_" .. board.Stat):SetAsync(tostring(player.UserId), math.floor(value))
					end)
				end
			end
			return
		end
		warn("[DataService] save failed:", err)
		task.wait(delay)
		delay *= 2
	end
end

local function awardBadge(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
	end)
end

local function onStormSurvived(stormNumber: number)
	for _, player in Players:GetPlayers() do
		local profile = profiles[player]
		if profile and PlayerService.IsAlive(player) then
			profile.XP += P.XPPerStorm
			profile.StormsSurvived += 1
			profile.BestStorm = math.max(profile.BestStorm, stormNumber)
			updateLeaderstats(player)
			if stormNumber == 10 then
				awardBadge(player, P.Badges.Storm10)
			elseif stormNumber == 20 then
				awardBadge(player, P.Badges.Storm20)
			end
		end
	end
end

function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.LevelOf(profile: Profile): number
	return levelOf(profile)
end

-- Call after changing a profile so leaderstats and attributes follow
function DataService.Changed(player: Player)
	updateLeaderstats(player)
end

local started = false

function DataService.Start()
	if started then
		return
	end
	started = true
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(P.DataStoreName)
	end)
	if ok and ds then
		local probeOk = pcall(function()
			ds:GetAsync("probe")
		end)
		if probeOk then
			store = ds
		else
			warn("[DataService] DataStores unavailable (in Studio: Game Settings > Security > Enable Studio Access to API Services). Playing without saving.")
		end
	end

	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		canSave[player] = nil
	end)
	StormDirector.StormSurvived:Connect(onStormSurvived)

	task.spawn(function()
		while true do
			task.wait(P.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.5)
		end
	end)
end

return DataService
