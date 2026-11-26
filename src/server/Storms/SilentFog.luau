--!strict
-- Silent Fog (Moderate): a dead-still, smothering fog. Things watch from inside it. Every few
-- seconds a pair of eyes opens in the fog near each player who is out of the lamp's light
-- (StormEvent "Watcher", sent only to that player). If the player looks straight at the eyes
-- (their client reports it with StormAct "WatcherSeen"), the watcher sinks back into the fog.
-- If they don't, it comes for them: a Fog Crawler lunges out of that spot (StormEvent
-- "WatcherLunge"). Standing in the lamp's light keeps the watchers away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	Every = NumberRange.new(6, 10),
	Distance = NumberRange.new(24, 34),
	LungeAfter = 7, -- seconds a watcher waits to be noticed
	MaxPerPlayer = 2,
}

local SilentFog = {}

type Watcher = { id: number, player: Player, at: Vector3, seen: boolean }

local active = false
local generation = 0
local nextId = 0
local watchers: { [number]: Watcher } = {}
local rng = Random.new()
local actConn: RBXScriptConnection? = nil

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function landAt(x: number, z: number): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function countFor(p: Player): number
	local n = 0
	for _, w in watchers do
		if w.player == p then
			n += 1
		end
	end
	return n
end

local function open(p: Player, mine: number)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or LightService.IsPointLit(root.Position) or countFor(p) >= S.MaxPerPlayer then
		return
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.Distance.Min, S.Distance.Max)
		local at = landAt(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
		if at then
			nextId += 1
			local w: Watcher = { id = nextId, player = p, at = at, seen = false }
			watchers[w.id] = w
			Remotes.event("StormEvent"):FireClient(p, "Watcher", { id = w.id, at = at, lunge = S.LungeAfter })
			task.delay(S.LungeAfter, function()
				watchers[w.id] = nil
				if w.seen or not active or generation ~= mine or not p.Parent then
					return
				end
				if EnemyService.Spawn("FogCrawler", at) then
					Remotes.event("StormEvent"):FireClient(p, "WatcherLunge", { id = w.id })
				end
			end)
			return
		end
	end
end

function SilentFog.Start()
	active = true
	generation += 1
	local mine = generation
	if not actConn then
		actConn = Remotes.event("StormAct").OnServerEvent:Connect(function(player: Player, kind: any, data: any)
			if kind ~= "WatcherSeen" or typeof(data) ~= "number" then
				return
			end
			local w = watchers[data]
			-- only the watcher's own player can see it off, and only while it's still out there
			if w and w.player == player and not w.seen then
				w.seen = true
			end
		end)
	end
	task.wait(3)
	while active and generation == mine do
		for _, p in Players:GetPlayers() do
			open(p, mine)
		end
		task.wait(rng:NextNumber(S.Every.Min, S.Every.Max))
	end
end

function SilentFog.Stop()
	active = false
	table.clear(watchers)
	if actConn then
		actConn:Disconnect()
		actConn = nil
	end
end

return SilentFog
