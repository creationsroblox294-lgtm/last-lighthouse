--!strict
-- Maelstrom (Catastrophic): a vast whirlpool opens out at sea and creeps in towards the island
-- (Workspace attributes "MaelstromAt", its centre, and "MaelstromRadius", how far its pull
-- reaches). Anything in the water inside its reach is dragged round and in (each client pulls its
-- own character, since players own their physics) and torn apart near the throat. Its pull
-- reaches up the beaches. And it lashes the shore (StormEvent "Lash"): a column of water bursts
-- out of the ground under someone near the sea, flinging them towards it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	StartOut = 1250, -- studs from the island centre it opens
	Closest = 820, -- ...and how near it creeps
	CreepSeconds = 70, -- to come all the way in
	Radius = 420,
	ThroatRadius = 45,
	ThroatDamage = 30, -- per second in the throat
	LashEvery = NumberRange.new(8, 13),
	LashWarn = 1.4,
	LashRadius = 7,
	LashDamage = 18,
	LashReach = 180, -- players on land this far beyond the pull can be lashed
	Roar = 1.5, -- extra lamp fuel per second while it's at its closest
}

local Maelstrom = {}

local active = false
local generation = 0
local rng = Random.new()

local function lash(centre: Vector3, radius: number)
	local targets = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not LightService.IsPointLit(root.Position) then
			local d = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z).Magnitude
			if d < radius + S.LashReach then
				table.insert(targets, p)
			end
		end
	end
	if #targets == 0 then
		return
	end
	local p = targets[rng:NextInteger(1, #targets)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	local at = root.Position
	Remotes.event("StormEvent"):FireAllClients("Lash", { at = at, warn = S.LashWarn, radius = S.LashRadius, toward = centre })
	task.delay(S.LashWarn, function()
		if not active then
			return
		end
		for _, pl in Players:GetPlayers() do
			local char = pl.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if r and r:IsA("BasePart") and hum and hum.Health > 0 and Vector3.new(r.Position.X - at.X, 0, r.Position.Z - at.Z).Magnitude < S.LashRadius then
				hum:TakeDamage(S.LashDamage)
				Remotes.event("StormEvent"):FireClient(pl, "Lashed", { toward = centre })
			end
		end
	end)
end

function Maelstrom.Start()
	active = true
	generation += 1
	local mine = generation
	local c = Config.World.IslandCenter
	local island = Vector3.new(c.X, 0, c.Z)
	local a = (Workspace:GetAttribute("DebugMaelstromAngle") :: number?) or rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local t0 = os.clock()
	Workspace:SetAttribute("MaelstromRadius", S.Radius)
	Workspace:SetAttribute("MaelstromThroat", S.ThroatRadius)
	task.spawn(function()
		local nextLash = os.clock() + 8
		while active and generation == mine do
			local dt = task.wait(0.25)
			local k = math.clamp((os.clock() - t0) / S.CreepSeconds, 0, 1)
			local eased = 1 - (1 - k) ^ 2
			local centre = island + dir * (S.StartOut + (S.Closest - S.StartOut) * eased)
			Workspace:SetAttribute("MaelstromAt", centre)
			-- the throat tears apart anything that reaches it
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and hum and hum.Health > 0 then
					local d = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z).Magnitude
					if d < S.ThroatRadius then
						hum:TakeDamage(S.ThroatDamage * dt)
					end
				end
			end
			if k >= 1 then
				LightService.DrainFuel(S.Roar * dt)
			end
			if os.clock() >= nextLash then
				nextLash = os.clock() + rng:NextNumber(S.LashEvery.Min, S.LashEvery.Max)
				lash(centre, S.Radius)
			end
		end
	end)
	Remotes.notify(nil, "The sea is turning... a whirlpool is opening offshore!", "Alarm")
end

function Maelstrom.Stop()
	active = false
	for _, k in { "MaelstromAt", "MaelstromRadius", "MaelstromThroat" } do
		Workspace:SetAttribute(k, nil)
	end
end

return Maelstrom
