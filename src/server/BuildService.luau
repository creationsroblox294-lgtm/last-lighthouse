--!strict
-- BuildService: the tower's three floors (each with its own health), repairs and barricades.
--
-- Floors (design doc):
--   GroundFloor  broken -> creatures get in and go for the stairs (damage moves up a floor)
--   BunkRoom     broken -> no respawning until it's repaired
--   LampRoom     broken -> fuel leaks (drains 2x) and the light flickers
-- If all three reach 0, the lighthouse falls and the run ends.
-- Repairs: hammer + 1 wood or scrap from storage. Barricades: 3 wood at fixed slots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local LightService = require(script.Parent:WaitForChild("LightService"))
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))

local T = Config.Tower
local BuildService = {}

type Barricade = { part: BasePart, prompt: ProximityPrompt, health: number, built: boolean }

local towerState: Configuration
local health: { [string]: number } = {}
local floorModels: { [string]: Instance } = {}
local originalColors: { [BasePart]: Color3 } = {}
local barricades: { Barricade } = {}
local lastRepair: { [Player]: number } = {}
local spawnLocation: SpawnLocation? = nil
local center = Config.World.TowerCenter

local DAMAGED_COLOR = Color3.fromRGB(45, 40, 38)
local FLOOR_LABEL = { GroundFloor = "ground floor", BunkRoom = "bunk room", LampRoom = "lamp room" }

local SLOTS = {
	{ name = "RampBarricade", cf = CFrame.new(-10, 8.4, 175), size = Vector3.new(16, 3, 1.5) },
	{ name = "DoorBarricade", cf = CFrame.new(-10, 9.1, 163.1), size = Vector3.new(10, 3, 1.5) },
}

local function paintFloor(name: string)
	local model = floorModels[name]
	if not model then
		return
	end
	local frac = (health[name] or 0) / T.FloorMaxHealth
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Wall" then
			local original = originalColors[d]
			if not original then
				original = d.Color
				originalColors[d] = original
			end
			d.Color = original:Lerp(DAMAGED_COLOR, 1 - frac)
		end
	end
end

local function publish()
	for _, name in T.Floors do
		towerState:SetAttribute(name, math.ceil(health[name] or 0))
	end
	towerState:SetAttribute("MaxHealth", T.FloorMaxHealth)
end

local function applyEffects()
	local spawnPad = spawnLocation
	if spawnPad then
		spawnPad.Enabled = (health.BunkRoom or 0) > 0
	end
	LightService.SetLeaking((health.LampRoom or 0) <= 0)
	local standing = false
	for _, name in T.Floors do
		if (health[name] or 0) > 0 then
			standing = true
		end
	end
	if not standing then
		StormDirector.EndRun("The lighthouse has fallen.")
	end
end

function BuildService.GetHealth(name: string): number
	return health[name] or 0
end

function BuildService.CanRespawn(): boolean
	return (health.BunkRoom or 0) > 0
end

function BuildService.DamageFloor(name: string, amount: number)
	local before = health[name]
	if not before or before <= 0 then
		return
	end
	health[name] = math.max(0, before - amount)
	if health[name] <= 0 then
		local label = FLOOR_LABEL[name] or name
		local extra = if name == "BunkRoom" then " No one can respawn until it's repaired."
			elseif name == "LampRoom" then " Fuel is leaking!"
			else " Creatures are getting inside!"
		Remotes.notify(nil, `The {label} is broken!{extra}`, "Alarm")
	end
	paintFloor(name)
	publish()
	applyEffects()
end

-- Damage the first standing floor, from the ground up
function BuildService.DamageTower(amount: number)
	for _, name in T.Floors do
		if (health[name] or 0) > 0 then
			BuildService.DamageFloor(name, amount)
			return
		end
	end
end

function BuildService.RepairFloor(name: string, amount: number)
	if not health[name] then
		return
	end
	health[name] = math.min(T.FloorMaxHealth, health[name] + amount)
	paintFloor(name)
	publish()
	applyEffects()
end

local function setBarricade(b: Barricade, built: boolean)
	b.built = built
	b.health = if built then T.BarricadeHealth else 0
	b.part.Transparency = if built then 0 else 0.8
	b.part.CanCollide = built
	b.part.Material = if built then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic
	b.part:SetAttribute("Health", b.health)
	b.prompt.Enabled = not built
end

-- A standing barricade near a position (creatures attack these when blocked)
function BuildService.GetBarricadeNear(pos: Vector3, range: number): BasePart?
	for _, b in barricades do
		if b.built and (b.part.Position - pos).Magnitude <= range then
			return b.part
		end
	end
	return nil
end

function BuildService.DamageBarricade(part: BasePart, amount: number)
	for _, b in barricades do
		if b.part == part and b.built then
			b.health -= amount
			part:SetAttribute("Health", math.max(0, b.health))
			if b.health <= 0 then
				setBarricade(b, false)
				Remotes.notify(nil, "A barricade was smashed!", "Alarm")
			end
			return
		end
	end
end

local function floorAtHeight(y: number): string
	if y < center.Y + 17 then
		return "GroundFloor"
	elseif y < center.Y + 33 then
		return "BunkRoom"
	end
	return "LampRoom"
end

-- Hammer: repair the nearest damaged barricade, or the floor you're standing on
function BuildService.TryRepair(player: Player)
	local t = os.clock()
	if t - (lastRepair[player] or 0) < T.RepairCooldown then
		return
	end
	lastRepair[player] = t
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local pos = root.Position

	for _, b in barricades do
		if b.built and b.health < T.BarricadeHealth and (b.part.Position - pos).Magnitude <= 12 then
			if not ResourceService.SpendAny({ "Wood", "Scrap" }, 1) then
				Remotes.notify(player, "You need wood or scrap in storage to repair.", nil)
				return
			end
			b.health = math.min(T.BarricadeHealth, b.health + T.BarricadeRepairAmount)
			b.part:SetAttribute("Health", b.health)
			return
		end
	end

	local dx, dz = pos.X - center.X, pos.Z - center.Z
	if math.sqrt(dx * dx + dz * dz) > Config.Combat.HammerRange then
		Remotes.notify(player, "Get closer to the lighthouse (or a barricade) to repair it.", nil)
		return
	end
	local target = floorAtHeight(pos.Y)
	if (health[target] or 0) >= T.FloorMaxHealth then
		local lowest: string? = nil
		for _, name in T.Floors do
			if health[name] < T.FloorMaxHealth and (not lowest or health[name] < health[lowest]) then
				lowest = name
			end
		end
		if not lowest then
			Remotes.notify(player, "The lighthouse is in good shape.", nil)
			return
		end
		target = lowest
	end
	if not ResourceService.SpendAny({ "Wood", "Scrap" }, 1) then
		Remotes.notify(player, "You need wood or scrap in storage to repair.", nil)
		return
	end
	BuildService.RepairFloor(target, T.RepairAmount)
end

local function makeBarricades()
	local runtime = Workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "Barricades"
	folder.Parent = runtime
	for _, slot in SLOTS do
		local part = Instance.new("Part")
		part.Name = slot.name
		part.Anchored = true
		part.Size = slot.size
		part.CFrame = slot.cf
		part.Color = Color3.fromRGB(125, 92, 62)
		part.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `Build barricade ({T.BarricadeWoodCost} wood)`
		prompt.ObjectText = "Barricade spot"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		local b: Barricade = { part = part, prompt = prompt, health = 0, built = false }
		prompt.Triggered:Connect(function(player: Player)
			if b.built then
				return
			end
			if not ResourceService.Spend("Wood", T.BarricadeWoodCost) then
				Remotes.notify(player, `You need {T.BarricadeWoodCost} wood in storage.`, nil)
				return
			end
			setBarricade(b, true)
			Remotes.notify(player, "Barricade built.", "Good")
		end)
		table.insert(barricades, b)
		setBarricade(b, false)
	end
end

function BuildService.Reset()
	for _, name in T.Floors do
		health[name] = T.FloorMaxHealth
		paintFloor(name)
	end
	for _, b in barricades do
		setBarricade(b, false)
	end
	publish()
	applyEffects()
end

function BuildService.Start()
	towerState = SharedState.get("Tower")
	local map = Workspace:WaitForChild("Map")
	local lighthouse = map:WaitForChild("Lighthouse")
	for _, name in T.Floors do
		local model = lighthouse:FindFirstChild(name)
		if model then
			floorModels[name] = model
		end
	end
	local bunk = floorModels.BunkRoom
	local pad = bunk and bunk:FindFirstChildOfClass("SpawnLocation")
	spawnLocation = pad
	makeBarricades()

	Players.PlayerRemoving:Connect(function(player)
		lastRepair[player] = nil
	end)
	StormDirector.RunReset:Connect(BuildService.Reset)
	BuildService.Reset()
end

return BuildService
