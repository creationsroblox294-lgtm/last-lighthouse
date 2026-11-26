--!strict
-- Lucky Lightning (Blessed): a dry thunderstorm. Bolts keep striking near players
-- (StormEvent "Bolt": the target crackles for a moment, then the bolt lands). Most of them hit
-- pine trees and split them into firewood you can carry. Some hit open ground: stand too close
-- and you get a nasty shock, but any creature caught there gets fried. Now and then a bolt
-- strikes the lighthouse itself and supercharges the lamp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))
local ResourceService = require(Server:WaitForChild("ResourceService"))

local S = {
	EverySeconds = NumberRange.new(1.4, 2.8),
	ChargeSeconds = 1.1, -- crackle warning before the strike
	TreeChance = 0.6, -- aim for a standing tree near the player
	TreeRadius = 70,
	LampChance = 0.1, -- the lighthouse lamp gets struck
	LampFuel = 10,
	NearRadius = NumberRange.new(14, 55),
	WoodPerTree = NumberRange.new(2, 4),
	ShockRadius = 7,
	ShockDamage = 15,
	FryRadius = 14,
	FryDamage = 80,
}

local LuckyLightning = {}

local active = false
local generation = 0
local rng = Random.new()

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

local function lamp(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local lighthouse = map and map:FindFirstChild("Lighthouse")
	local lampRoom = lighthouse and lighthouse:FindFirstChild("LampRoom")
	local l = lampRoom and lampRoom:FindFirstChild("Lamp")
	return if l and l:IsA("BasePart") then l else nil
end

local function treeNear(pos: Vector3): Model?
	local map = Workspace:FindFirstChild("Map")
	local grove = map and map:FindFirstChild("PineGrove")
	if not grove then
		return nil
	end
	local options = {}
	for _, tree in grove:GetChildren() do
		if tree:IsA("Model") and tree:GetAttribute("Felled") ~= true and tree:FindFirstChild("Trunk") then
			local p = tree:GetPivot().Position
			if Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude < S.TreeRadius then
				table.insert(options, tree)
			end
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

local function fry(at: Vector3)
	local runtime = Workspace:FindFirstChild("Runtime")
	local enemies = runtime and runtime:FindFirstChild("Enemies")
	if enemies then
		for _, m in enemies:GetChildren() do
			if m.Name ~= "Fish" and m:IsA("Model") then
				local hum = m:FindFirstChildOfClass("Humanoid")
				local root = m:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and root and root:IsA("BasePart") and (root.Position - at).Magnitude < S.FryRadius then
					hum:TakeDamage(S.FryDamage)
				end
			end
		end
	end
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and hum and hum.Health > 0 then
			local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
			if flat.Magnitude < S.ShockRadius and math.abs(root.Position.Y - at.Y) < 12 then
				hum:TakeDamage(S.ShockDamage)
				root.AssemblyLinearVelocity += (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 40 + Vector3.new(0, 25, 0)
			end
		end
	end
end

local function strike()
	local event = Remotes.event("StormEvent")
	local l = lamp()
	if l and rng:NextNumber() < S.LampChance then
		local top = l.Position + Vector3.new(0, l.Size.Y / 2 + 6, 0)
		event:FireAllClients("Bolt", { target = top, kind = "lamp", seconds = S.ChargeSeconds, seed = rng:NextInteger(1, 1e6) })
		task.delay(S.ChargeSeconds, function()
			LightService.AddFuel(S.LampFuel)
			Remotes.notify(nil, `Lightning struck the lighthouse! The lamp is supercharged: +{S.LampFuel} fuel`, "Good")
		end)
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local p = players[rng:NextInteger(1, #players)]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local tree = if rng:NextNumber() < S.TreeChance then treeNear(root.Position) else nil
	if tree then
		local base = tree:GetPivot().Position
		local _, size = tree:GetBoundingBox()
		local top = Vector3.new(base.X, base.Y + size.Y / 2, base.Z)
		local foot = landAt(base.X, base.Z) or base
		event:FireAllClients("Bolt", { target = top, foot = foot, kind = "tree", seconds = S.ChargeSeconds, seed = rng:NextInteger(1, 1e6) })
		task.delay(S.ChargeSeconds, function()
			if not tree.Parent or not ResourceService.FellTree(tree) then
				return
			end
			for _ = 1, rng:NextInteger(S.WoodPerTree.Min, S.WoodPerTree.Max) do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(2, 6)
				ResourceService.SpawnItem("Wood", foot + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			end
			fry(foot)
		end)
		return
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.NearRadius.Min, S.NearRadius.Max)
		local at = landAt(root.Position.X + math.cos(a) * r, root.Position.Z + math.sin(a) * r)
		if at then
			event:FireAllClients("Bolt", { target = at, kind = "ground", seconds = S.ChargeSeconds, seed = rng:NextInteger(1, 1e6) })
			task.delay(S.ChargeSeconds, fry, at)
			return
		end
	end
end

function LuckyLightning.Start()
	active = true
	generation += 1
	local mine = generation
	while active and generation == mine do
		strike()
		task.wait(rng:NextNumber(S.EverySeconds.Min, S.EverySeconds.Max))
	end
end

function LuckyLightning.Stop()
	active = false
end

return LuckyLightning
