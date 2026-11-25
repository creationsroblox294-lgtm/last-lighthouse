--!strict
-- CombatService: the player's tools.
--   Harpoon: the main weapon. Auto-aims at the nearest creature in front of you
--            (works the same on touch, gamepad and mouse). Server checks range and cooldown.
--   Hammer:  repairs the floor you're on, or a nearby barricade (costs wood or scrap).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local BuildService = require(script.Parent:WaitForChild("BuildService"))

local C = Config.Combat
local CombatService = {}

local lastHarpoon: { [Player]: number } = {}

local function makeTool(name: string, size: Vector3, color: Color3, material: Enum.Material, tip: Color3?): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = material
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	if tip then
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(size.X * 2.2, size.X * 2.2, 1)
		head.Color = tip
		head.Material = Enum.Material.Metal
		head.CanCollide = false
		head.Massless = true
		head.CFrame = handle.CFrame * CFrame.new(0, 0, -size.Z / 2)
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = head
		w.Parent = head
		head.Parent = tool
	end
	tool.Grip = CFrame.new(0, 0, size.Z * 0.3)
	return tool
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function streak(from: Vector3, to: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(220, 230, 255)
	local length = (to - from).Magnitude
	p.Size = Vector3.new(0.25, 0.25, length)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	p.Parent = Workspace:FindFirstChild("Runtime") or Workspace
	Debris:AddItem(p, 0.15)
end

local function harpoon(player: Player)
	local t = os.clock()
	if t - (lastHarpoon[player] or 0) < C.HarpoonCooldown then
		return
	end
	lastHarpoon[player] = t
	local root = rootOf(player)
	if not root then
		return
	end
	local target = EnemyService.FindTarget(root.Position, root.CFrame.LookVector, C.HarpoonRange, C.HarpoonConeDegrees)
	if not target then
		return
	end
	local targetRoot = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
	if targetRoot and targetRoot:IsA("BasePart") then
		streak(root.Position + Vector3.new(0, 1, 0), targetRoot.Position)
	end
	target:TakeDamage(C.HarpoonDamage)
end

local templates: { Tool } = {}

local function equip(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	for _, template in templates do
		local tool = template:Clone()
		local kind = tool.Name
		tool.Activated:Connect(function()
			if kind == "Harpoon" then
				harpoon(player)
			elseif kind == "Hammer" then
				BuildService.TryRepair(player)
			end
		end)
		tool.Parent = backpack
	end
end

function CombatService.Start()
	table.insert(templates, makeTool("Harpoon", Vector3.new(0.35, 0.35, 5), Color3.fromRGB(110, 80, 55), Enum.Material.Wood, Color3.fromRGB(170, 175, 180)))
	table.insert(templates, makeTool("Hammer", Vector3.new(0.4, 0.4, 2.4), Color3.fromRGB(110, 80, 55), Enum.Material.Wood, Color3.fromRGB(90, 95, 100)))

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			equip(player)
		end)
		if player.Character then
			equip(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastHarpoon[player] = nil
	end)
end

return CombatService
