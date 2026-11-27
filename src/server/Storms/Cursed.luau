--!strict
-- Cursed Storm (Catastrophic): nobody knows what it is. An eye opens in the sky (Workspace
-- "CursedEye", where it hangs) and watches the island, and every 11-15 s the storm lays a new
-- curse on it, never the same twice in a row (StormEvent "Curse": kind, seconds, sometimes who):
--   Hands  "THE GROUND IS HUNGRY"   stand still outside the light and hands drag at you
--   Float  "THE SKY IS FALLING UP"  gravity all but gives out
--   Choke  "THE LAMP IS CHOKING"    the lamp shrinks to a sickly glow
--   Doubles "WHO IS THAT?"          Fog Mimics step out beside anyone in the open
--   Keeper "THE LAST KEEPER WALKS"  (once a storm) the drowned keeper comes ashore
--   Gaze   "IT SEES YOU"            the eye fixes on one person; still in the open when it
--                                   closes and it burns them, and the fog comes for them
-- Everything a curse changes is put back when it ends (or when the storm does).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local EnemyService = require(Server:WaitForChild("EnemyService"))

local S = {
	FirstAfter = 6,
	Every = NumberRange.new(11, 15),
	HandsSeconds = 8,
	HandsStill = 1.5, -- seconds standing (nearly) still before they get you
	HandsDamage = 9, -- per second
	FloatSeconds = 7,
	FloatGravity = 26,
	ChokeSeconds = 9,
	ChokeScale = 0.4,
	GazeSeconds = 7,
	GazeDamage = 25,
	EyeDistance = 2100,
	EyeHeight = 650,
}

local KINDS = { "Hands", "Float", "Choke", "Doubles", "Keeper", "Gaze" }

local Cursed = {}

local active = false
local generation = 0
local rng = Random.new()
local gravityWas: number? = nil
local choked = false

local function exposed(p: Player): (BasePart?, Humanoid?)
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and hum and hum.Health > 0 and not LightService.IsPointLit(root.Position) then
		return root, hum
	end
	return nil, nil
end

local function groundNear(at: Vector3, r: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local hit = Workspace:Raycast(Vector3.new(p.X, 200, p.Z), Vector3.new(0, -400, 0), params)
		if hit and hit.Material ~= Enum.Material.Water then
			return hit.Position + Vector3.new(0, 3, 0)
		end
	end
	return at
end

local function restoreGravity()
	if gravityWas then
		Workspace.Gravity = gravityWas
		gravityWas = nil
	end
end

local function unchoke()
	if choked then
		choked = false
		LightService.SetRadiusScale(1)
	end
end

local function curse(kind: string, mine: number)
	local live = function()
		return active and generation == mine
	end
	if kind == "Hands" then
		Remotes.event("StormEvent"):FireAllClients("Curse", { kind = kind, seconds = S.HandsSeconds })
		task.spawn(function()
			local last: { [Player]: { { t: number, p: Vector3 } } } = {}
			local t0 = os.clock()
			while live() and os.clock() - t0 < S.HandsSeconds do
				local dt = task.wait(0.25)
				for _, p in Players:GetPlayers() do
					local root, hum = exposed(p)
					if root and hum then
						local h = last[p] or {}
						last[p] = h
						table.insert(h, { t = os.clock(), p = root.Position })
						while #h > 1 and h[1].t < os.clock() - S.HandsStill do
							table.remove(h, 1)
						end
						local moved = (root.Position - h[1].p).Magnitude
						if os.clock() - t0 > S.HandsStill and h[1].t <= os.clock() - S.HandsStill + 0.3 and moved < 2 then
							hum:TakeDamage(S.HandsDamage * dt)
							Remotes.event("StormEvent"):FireClient(p, "Grabbed", {})
						end
					else
						last[p] = nil
					end
				end
			end
		end)
	elseif kind == "Float" then
		Remotes.event("StormEvent"):FireAllClients("Curse", { kind = kind, seconds = S.FloatSeconds, gravity = S.FloatGravity })
		if not gravityWas then
			gravityWas = Workspace.Gravity
		end
		Workspace.Gravity = S.FloatGravity
		task.delay(S.FloatSeconds, function()
			if generation == mine then
				restoreGravity()
			end
		end)
	elseif kind == "Choke" then
		Remotes.event("StormEvent"):FireAllClients("Curse", { kind = kind, seconds = S.ChokeSeconds })
		choked = true
		LightService.SetRadiusScale(S.ChokeScale)
		task.delay(S.ChokeSeconds, function()
			if generation == mine then
				unchoke()
			end
		end)
	elseif kind == "Doubles" then
		Remotes.event("StormEvent"):FireAllClients("Curse", { kind = kind, seconds = 4 })
		for _, p in Players:GetPlayers() do
			local root = exposed(p)
			if root then
				for _ = 1, 2 do
					EnemyService.Spawn("FogMimic", groundNear(root.Position, rng:NextNumber(22, 34)))
				end
			end
		end
	elseif kind == "Keeper" then
		Remotes.event("StormEvent"):FireAllClients("Curse", { kind = kind, seconds = 5 })
		local target: BasePart? = nil
		for _, p in Players:GetPlayers() do
			local root = exposed(p)
			if root then
				target = root
				break
			end
		end
		local tower = Config.World.TowerCenter
		local at = if target then groundNear(target.Position, 45) else groundNear(tower, 140)
		EnemyService.Spawn("LastKeeper", at)
	elseif kind == "Gaze" then
		local candidates = {}
		for _, p in Players:GetPlayers() do
			if exposed(p) then
				table.insert(candidates, p)
			end
		end
		if #candidates == 0 then
			candidates = Players:GetPlayers()
		end
		if #candidates == 0 then
			return
		end
		local victim = candidates[rng:NextInteger(1, #candidates)]
		Remotes.event("StormEvent"):FireAllClients("Curse", { kind = kind, seconds = S.GazeSeconds, uid = victim.UserId })
		task.delay(S.GazeSeconds, function()
			if not live() then
				return
			end
			local root, hum = exposed(victim)
			if root and hum then
				-- out in the open with nothing over them
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { victim.Character :: Model }
				if Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 80, 0), params) == nil then
					hum:TakeDamage(S.GazeDamage)
					Remotes.event("StormEvent"):FireAllClients("GazeHit", { uid = victim.UserId, at = root.Position })
					for _ = 1, 3 do
						EnemyService.Spawn("FogCrawler", groundNear(root.Position, rng:NextNumber(14, 24)))
					end
				end
			end
		end)
	end
end

function Cursed.Start()
	active = true
	generation += 1
	local mine = generation
	local c = Config.World.IslandCenter
	local a = rng:NextNumber(0, math.pi * 2)
	Workspace:SetAttribute("CursedEye", Vector3.new(c.X + math.cos(a) * S.EyeDistance, S.EyeHeight, c.Z + math.sin(a) * S.EyeDistance))
	task.spawn(function()
		task.wait(S.FirstAfter)
		local deck: { string } = {}
		local keeperDone = false
		local lastKind = ""
		while active and generation == mine do
			if #deck == 0 then
				for _, k in KINDS do
					if k ~= "Keeper" or not keeperDone then
						table.insert(deck, rng:NextInteger(1, #deck + 1), k)
					end
				end
				if deck[1] == lastKind and #deck > 1 then
					deck[1], deck[2] = deck[2], deck[1]
				end
			end
			local kind = table.remove(deck, 1) :: string
			if kind == "Keeper" then
				keeperDone = true
			end
			lastKind = kind
			curse(kind, mine)
			task.wait(rng:NextNumber(S.Every.Min, S.Every.Max))
		end
	end)
	Remotes.notify(nil, "Something is wrong with the sky...", "Alarm")
end

function Cursed.Stop()
	active = false
	restoreGravity()
	unchoke()
	Workspace:SetAttribute("CursedEye", nil)
end

return Cursed
