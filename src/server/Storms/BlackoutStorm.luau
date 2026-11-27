--!strict
-- Blackout Storm (Severe): a dry electrical storm. Lightning goes for the lamp (StormEvent
-- "LampStrike"): it chokes the light down to a dim glow (LightService.SetRadiusScale, Workspace
-- attribute "Blackout") until someone climbs up and holds "Relight the lamp". The fuel isn't
-- touched, but while it's choked the safe circle is a fraction of its size and the creatures close
-- in. And ball lightning (Workspace.Runtime.BallLightning: anchored parts the clients dress up)
-- drifts in from the dark and hunts anyone outside the light: touch one and it bursts (StormEvent
-- "Zapped" to that player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	FirstStrike = 4,
	StrikeEvery = NumberRange.new(30, 45), -- after a relight, before it goes for the lamp again
	ChokedScale = 0.3,
	RelightHold = 3,
	MaxOrbs = 3,
	OrbEvery = NumberRange.new(5, 9),
	OrbSpeed = 9,
	OrbLife = 30,
	OrbHeight = 5,
	ZapRadius = 5,
	ZapDamage = 16,
	SpawnRing = NumberRange.new(150, 260), -- spawned this far from the lighthouse
}

local BlackoutStorm = {}

local active = false
local generation = 0
local rng = Random.new()
local prompt: ProximityPrompt? = nil
local folder: Folder? = nil

local function lamp(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local lighthouse = map and map:FindFirstChild("Lighthouse")
	local lampRoom = lighthouse and lighthouse:FindFirstChild("LampRoom")
	local l = lampRoom and lampRoom:FindFirstChild("Lamp")
	return if l and l:IsA("BasePart") then l else nil
end

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include

local function groundAt(x: number, z: number): Vector3?
	ground.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), ground)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function choke(on: boolean)
	LightService.SetRadiusScale(if on then S.ChokedScale else 1)
	Workspace:SetAttribute("Blackout", if on then true else nil)
	if prompt then
		prompt.Enabled = on
	end
end

local function strikeLamp()
	local l = lamp()
	Remotes.event("StormEvent"):FireAllClients("LampStrike", { at = if l then l.Position else LightService.GetCenter() })
	choke(true)
	Remotes.notify(nil, "Lightning hit the lamp! It's barely glowing. Someone climb up and relight it!", "Alarm")
end

type Orb = { part: BasePart, born: number }

local function spawnOrb(orbs: { Orb })
	local c = LightService.GetCenter()
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.SpawnRing.Min, S.SpawnRing.Max)
		local at = groundAt(c.X + math.cos(a) * r, c.Z + math.sin(a) * r)
		if at then
			local p = Instance.new("Part")
			p.Name = "Orb"
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(3, 3, 3)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.CFrame = CFrame.new(at + Vector3.new(0, S.OrbHeight, 0))
			p.Parent = folder
			table.insert(orbs, { part = p, born = os.clock() })
			return
		end
	end
end

local function burst(o: Orb)
	Remotes.event("StormEvent"):FireAllClients("OrbBurst", { at = o.part.Position })
	o.part:Destroy()
end

function BlackoutStorm.Start()
	active = true
	generation += 1
	local mine = generation
	local runtime = Workspace:FindFirstChild("Runtime")
	local f = Instance.new("Folder")
	f.Name = "BallLightning"
	f.Parent = runtime or Workspace
	folder = f
	local l = lamp()
	if l and not prompt then
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "Relight"
		pr.ActionText = "Relight the lamp"
		pr.ObjectText = "Choked lamp"
		pr.HoldDuration = S.RelightHold
		pr.MaxActivationDistance = 12
		pr.RequiresLineOfSight = false
		pr.Enabled = false
		pr.Parent = l
		pr.Triggered:Connect(function(player: Player)
			if Workspace:GetAttribute("Blackout") then
				choke(false)
				Remotes.event("StormEvent"):FireAllClients("Relit", nil)
				Remotes.notify(nil, `{player.DisplayName} relit the lamp!`, "Good")
			end
		end)
		prompt = pr
	end
	-- the lamp strikes
	task.spawn(function()
		task.wait(S.FirstStrike)
		while active and generation == mine do
			if not Workspace:GetAttribute("Blackout") then
				strikeLamp()
			end
			-- wait for a relight, then give them a breather before the next one
			while active and generation == mine and Workspace:GetAttribute("Blackout") do
				task.wait(0.5)
			end
			task.wait(rng:NextNumber(S.StrikeEvery.Min, S.StrikeEvery.Max))
		end
	end)
	-- ball lightning
	local orbs: { Orb } = {}
	local nextOrb = os.clock() + 6
	while active and generation == mine do
		local dt = task.wait(0.1)
		if #orbs < S.MaxOrbs and os.clock() >= nextOrb then
			nextOrb = os.clock() + rng:NextNumber(S.OrbEvery.Min, S.OrbEvery.Max)
			spawnOrb(orbs)
		end
		for i = #orbs, 1, -1 do
			local o = orbs[i]
			local pos = o.part.Position
			if os.clock() - o.born > S.OrbLife or LightService.IsPointLit(pos) then
				burst(o)
				table.remove(orbs, i)
				continue
			end
			-- drift towards the nearest player out in the dark
			local best: BasePart?, bestD = nil, 160
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and not LightService.IsPointLit(root.Position) then
					local d = (root.Position - pos).Magnitude
					if d < bestD then
						best, bestD = root, d
					end
				end
			end
			local wander = Vector3.new(math.sin(os.clock() * 1.3 + i), 0, math.cos(os.clock() * 1.1 + i * 2))
			local dir = if best then ((best.Position - pos) * Vector3.new(1, 0, 1)).Unit + wander * 0.4 else wander
			local nextPos = pos + dir.Unit * S.OrbSpeed * dt
			local g = groundAt(nextPos.X, nextPos.Z)
			local y = (if g then g.Y else pos.Y - S.OrbHeight) + S.OrbHeight + math.sin(os.clock() * 2 + i) * 1.5
			o.part.CFrame = CFrame.new(nextPos.X, y, nextPos.Z)
			-- touch
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and hum and hum.Health > 0 and (root.Position - o.part.Position).Magnitude < S.ZapRadius then
					hum:TakeDamage(S.ZapDamage)
					Remotes.event("StormEvent"):FireClient(p, "Zapped", { from = o.part.Position })
					burst(o)
					table.remove(orbs, i)
					break
				end
			end
		end
	end
	for _, o in orbs do
		if o.part.Parent then
			burst(o)
		end
	end
end

function BlackoutStorm.Stop()
	active = false
	choke(false)
	if folder then
		task.delay(1, function()
			if folder and not active then
				folder:Destroy()
				folder = nil
			end
		end)
	end
end

return BlackoutStorm
