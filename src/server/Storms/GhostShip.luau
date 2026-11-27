--!strict
-- Ghost Ship (Moderate): a spectral ship circles the island out at sea (StormEvent "ShipState":
-- where it is on its circle and how fast it goes, so every client can place it the same way).
-- Its stern lantern throws a pale searchlight that sweeps back and forth across the island.
-- Anyone it finds out in the dark (outside the lamp's light, nothing overhead) is marked
-- (StormEvent "Marked" to that player). Every so often its bell tolls (StormEvent "ShipBell"):
-- the drowned crew rise out of the ground right behind every marked player, and more come ashore
-- on the beach nearest the ship. And now and then the ship simply isn't there any more, and
-- then it is, somewhere else, sometimes much closer (StormEvent "ShipBlink").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local EnemyService = require(Server:WaitForChild("EnemyService"))
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	Radius = 720, -- how far out the ship sails
	CloseRadius = 610, -- right off the beach, after some blinks
	CloseChance = 0.4,
	Period = 200, -- seconds per lap
	BellEvery = NumberRange.new(15, 22),
	BlinkEvery = NumberRange.new(38, 52),
	BeamReach = 800,
	BeamHalfAngle = math.rad(4.5),
	BeamSwing = math.rad(48), -- how far either side of the island centre the searchlight sweeps
	BeamSpeed = 0.55, -- radians per second of the sweep's sine
	CrewBehind = 18,
	CrewPerMark = 2,
	CrewAshore = 2,
}

local GhostShip = {}

type State = { a0: number, t0: number, w: number, r: number }

local active = false
local generation = 0
local state: State = { a0 = 0, t0 = 0, w = 0, r = S.Radius }
local marked: { [Player]: boolean } = {}
local rng = Random.new()

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.IgnoreWater = false

local function centre(): Vector3
	local c = Config.World.IslandCenter
	return Vector3.new(c.X, 0, c.Z)
end

-- the same maths runs on every client (StormFX/GhostShip)
local function shipPos(now: number): Vector3
	local a = state.a0 + state.w * (now - state.t0)
	return centre() + Vector3.new(math.cos(a), 0, math.sin(a)) * state.r
end

local function beamDir(now: number): Vector3
	local p = shipPos(now)
	local toC = centre() - p
	local yaw = math.atan2(toC.Z, toC.X) + S.BeamSwing * math.sin(now * S.BeamSpeed)
	return Vector3.new(math.cos(yaw), 0, math.sin(yaw))
end

local function landAt(x: number, z: number): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function broadcast(kind: string)
	Remotes.event("StormEvent"):FireAllClients(kind, { a0 = state.a0, t0 = state.t0, w = state.w, r = state.r })
end

local function sheltered(char: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) ~= nil
end

local function sweep()
	local now = Workspace:GetServerTimeNow()
	local p = shipPos(now)
	local d = beamDir(now)
	for _, pl in Players:GetPlayers() do
		local char = pl.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not marked[pl] and char and root and root:IsA("BasePart") and hum and hum.Health > 0 then
			local to = Vector3.new(root.Position.X - p.X, 0, root.Position.Z - p.Z)
			local dist = to.Magnitude
			if dist < S.BeamReach and dist > 1 and math.acos(math.clamp(to.Unit:Dot(d), -1, 1)) < S.BeamHalfAngle then
				if not LightService.IsPointLit(root.Position) and not sheltered(char, root) then
					marked[pl] = true
					Remotes.event("StormEvent"):FireClient(pl, "Marked", nil)
					Remotes.notify(pl, "The ghost ship's lantern found you... get into the light before the bell tolls!", "Alarm")
				end
			end
		end
	end
	-- getting into the light breaks the mark
	for pl in marked do
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or LightService.IsPointLit(root.Position) then
			marked[pl] = nil
			if root then
				Remotes.event("StormEvent"):FireClient(pl, "Unmarked", nil)
			end
		end
	end
end

local function bell()
	local now = Workspace:GetServerTimeNow()
	local p = shipPos(now)
	Remotes.event("StormEvent"):FireAllClients("ShipBell", { at = p })
	local rises = {}
	for pl in marked do
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local back = -root.CFrame.LookVector
			for i = 1, S.CrewPerMark do
				local off = back * S.CrewBehind + root.CFrame.RightVector * ((i - 1.5) * 8)
				local at = landAt(root.Position.X + off.X, root.Position.Z + off.Z)
				if at then
					table.insert(rises, at)
				end
			end
			Remotes.event("StormEvent"):FireClient(pl, "Unmarked", nil)
		end
	end
	table.clear(marked)
	-- and the rest wade ashore on the beach nearest the ship
	local c = centre()
	for k = 0, 40 do
		local q = p:Lerp(c, k / 40)
		local at = landAt(q.X, q.Z)
		if at then
			local side = Vector3.new(-(c - p).Unit.Z, 0, (c - p).Unit.X)
			for i = 1, S.CrewAshore do
				local o = side * rng:NextNumber(-30, 30)
				table.insert(rises, landAt(at.X + o.X, at.Z + o.Z) or at)
			end
			break
		end
	end
	if #rises > 0 then
		Remotes.event("StormEvent"):FireAllClients("CrewRise", { at = rises })
		task.delay(1.2, function()
			if not active then
				return
			end
			for _, at in rises do
				EnemyService.Spawn("FogCrawler", at)
			end
		end)
	end
	Remotes.notify(nil, "The ghost ship's bell tolls... the drowned crew are coming!", "Alarm")
end

local function blink()
	local now = Workspace:GetServerTimeNow()
	state = {
		a0 = rng:NextNumber(0, math.pi * 2),
		t0 = now,
		w = state.w,
		r = if rng:NextNumber() < S.CloseChance then S.CloseRadius else S.Radius,
	}
	broadcast("ShipBlink")
	if state.r == S.CloseRadius then
		Remotes.notify(nil, "The ghost ship is gone... no, there! It's right off the beach!", "Alarm")
	end
end

function GhostShip.Start()
	active = true
	generation += 1
	local mine = generation
	table.clear(marked)
	state = {
		a0 = rng:NextNumber(0, math.pi * 2),
		t0 = Workspace:GetServerTimeNow(),
		w = (2 * math.pi / S.Period) * (if rng:NextNumber() < 0.5 then 1 else -1),
		r = S.Radius,
	}
	broadcast("ShipState")
	task.spawn(function()
		while active and generation == mine do
			sweep()
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while active and generation == mine do
			task.wait(rng:NextNumber(S.BlinkEvery.Min, S.BlinkEvery.Max))
			if active and generation == mine then
				blink()
			end
		end
	end)
	-- late joiners and clients whose storm FX started after the first broadcast
	task.spawn(function()
		while active and generation == mine do
			task.wait(5)
			if active and generation == mine then
				broadcast("ShipState")
			end
		end
	end)
	task.wait(rng:NextNumber(8, 12))
	while active and generation == mine do
		bell()
		task.wait(rng:NextNumber(S.BellEvery.Min, S.BellEvery.Max))
	end
end

function GhostShip.Stop()
	active = false
	for pl in marked do
		Remotes.event("StormEvent"):FireClient(pl, "Unmarked", nil)
	end
	table.clear(marked)
end

return GhostShip
