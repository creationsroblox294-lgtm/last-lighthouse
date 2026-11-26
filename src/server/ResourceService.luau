--!strict
-- ResourceService: physical items, carrying, the shared storage, gathering and wreckage.
--
-- Items are real objects you carry one at a time (design doc: moving fuel up the tower is
-- real work). Stations in and around the tower:
--   StorageCrateA  "Store item"     -> adds what you carry to the shared storage
--   StorageCrateB  "Take fuel"      -> takes oil (or wood) out of storage to carry
--   FuelTank       "Pour fuel"      -> carried oil / wood / whale oil goes into the lamp
--   FoodStorage    "Eat fish"       -> heals you
-- Gathering: chop pines, catch fish at the tide pools (and the dock from storm 5),
-- pick up wreckage that washes up on Wreck Beach after every storm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local LightService = require(script.Parent:WaitForChild("LightService"))
local Movement = require(script.Parent:WaitForChild("Movement"))

local R = Config.Resources
local ResourceService = {}

type Carry = { kind: string, item: BasePart }

local storageState: Configuration
local storage: { [string]: number } = {}
local carrying: { [Player]: Carry } = {}
local lastDrop: { [Player]: number } = {}
local itemsFolder: Folder
local rng = Random.new()

local ITEM_LOOK: { [string]: { size: Vector3, color: Color3, material: Enum.Material, label: string } } = {
	Wood = { size = Vector3.new(1.2, 1.2, 4), color = Color3.fromRGB(125, 92, 62), material = Enum.Material.Wood, label = "Wood" },
	Scrap = { size = Vector3.new(2, 1, 2), color = Color3.fromRGB(120, 124, 130), material = Enum.Material.CorrodedMetal, label = "Scrap metal" },
	Oil = { size = Vector3.new(2, 2.6, 2), color = Color3.fromRGB(40, 38, 35), material = Enum.Material.Metal, label = "Oil barrel" },
	Fish = { size = Vector3.new(0.8, 0.8, 2), color = Color3.fromRGB(196, 120, 58), material = Enum.Material.SmoothPlastic, label = "Cooked fish" },
	RawFish = { size = Vector3.new(0.7, 0.8, 2), color = Color3.fromRGB(150, 170, 182), material = Enum.Material.SmoothPlastic, label = "Raw fish" },
	WhaleOil = { size = Vector3.new(2, 2.6, 2), color = Color3.fromRGB(230, 200, 90), material = Enum.Material.Neon, label = "Whale oil" },
}

local function publishStorage()
	for _, kind in R.Kinds do
		storageState:SetAttribute(kind, storage[kind] or 0)
	end
end

function ResourceService.GetStorage(kind: string): number
	return storage[kind] or 0
end

function ResourceService.AddStorage(kind: string, amount: number)
	storage[kind] = (storage[kind] or 0) + amount
	publishStorage()
end

function ResourceService.Spend(kind: string, amount: number): boolean
	if (storage[kind] or 0) < amount then
		return false
	end
	storage[kind] -= amount
	publishStorage()
	return true
end

-- Spend the first kind in the list that storage has enough of; returns that kind
function ResourceService.SpendAny(kinds: { string }, amount: number): string?
	for _, kind in kinds do
		if ResourceService.Spend(kind, amount) then
			return kind
		end
	end
	return nil
end

function ResourceService.GetCarried(player: Player): string?
	local carry = carrying[player]
	return if carry then carry.kind else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local pickUp: (Player, BasePart) -> ()

local function makeItem(kind: string, cf: CFrame): BasePart
	local look = ITEM_LOOK[kind] or ITEM_LOOK.Scrap
	local part = Instance.new("Part")
	part.Name = kind
	part.Size = look.size
	part.Color = look.color
	part.Material = look.material
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = cf
	part:SetAttribute("ItemKind", kind)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUp"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = look.label
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		pickUp(player, part)
	end)

	part.Parent = itemsFolder
	return part
end

-- Place an item on the ground at a position (raycast down to find the ground)
function ResourceService.SpawnItem(kind: string, pos: Vector3): BasePart?
	if #itemsFolder:GetChildren() >= R.MaxGroundItems then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { itemsFolder }
	local hit = Workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	local look = ITEM_LOOK[kind] or ITEM_LOOK.Scrap
	local groundY = if hit then hit.Position.Y else pos.Y
	local cf = CFrame.new(pos.X, groundY + look.size.Y / 2, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	return makeItem(kind, cf)
end

local function setCarrySpeed(player: Player, carryingSomething: boolean)
	local humanoid = humanoidOf(player)
	if humanoid then
		Movement.SetBase(humanoid, if carryingSomething then R.CarryWalkSpeed else R.WalkSpeed)
	end
end

local function attach(player: Player, part: BasePart): boolean
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local prompt = part:FindFirstChild("PickUp")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0, 0.6, -1.8)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = player.Character
	carrying[player] = { kind = part:GetAttribute("ItemKind") :: string, item = part }
	player:SetAttribute("Carrying", carrying[player].kind)
	setCarrySpeed(player, true)
	return true
end

pickUp = function(player: Player, part: BasePart)
	if carrying[player] then
		Remotes.notify(player, "Your hands are full. Drop or use what you're carrying first.", nil)
		return
	end
	if part.Parent ~= itemsFolder then
		return
	end
	attach(player, part)
end

-- Give the player a fresh item to carry (from a tree, pool or storage)
local function give(player: Player, kind: string): boolean
	if carrying[player] then
		Remotes.notify(player, "Your hands are full. Drop or use what you're carrying first.", nil)
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local part = makeItem(kind, root.CFrame)
	if not attach(player, part) then
		part:Destroy()
		return false
	end
	return true
end

-- defined further down (tree felling uses it before its definition)
local setVisible: (model: Instance, visible: boolean) -> ()

-- Public: one punch on a tree. Every R.PunchesPerTree punches gives a piece of wood;
-- the tree then disappears and grows back. Returns "hit", "wood", "full" or nil.
function ResourceService.HitTree(player: Player, tree: Model): string?
	if tree:GetAttribute("Felled") == true then
		return nil
	end
	local hits = ((tree:GetAttribute("Hits") :: number?) or 0) + 1
	if hits < R.PunchesPerTree then
		tree:SetAttribute("Hits", hits)
		return "hit"
	end
	if carrying[player] then
		Remotes.notify(player, "Your hands are full. Drop or use what you're carrying first.", nil)
		tree:SetAttribute("Hits", R.PunchesPerTree - 1)
		return "full"
	end
	if not give(player, "Wood") then
		return nil
	end
	tree:SetAttribute("Hits", 0)
	tree:SetAttribute("Felled", true)
	setVisible(tree, false)
	task.delay(R.TreeRegrowSeconds, function()
		if tree.Parent then
			setVisible(tree, true)
			tree:SetAttribute("Felled", false)
		end
	end)
	return "wood"
end

-- Public: knock a tree down outright (a lightning strike). It hides and grows back like a
-- punched-out tree. Returns false if it was already down.
function ResourceService.FellTree(tree: Model): boolean
	if tree:GetAttribute("Felled") == true then
		return false
	end
	tree:SetAttribute("Hits", 0)
	tree:SetAttribute("Felled", true)
	setVisible(tree, false)
	task.delay(R.TreeRegrowSeconds, function()
		if tree.Parent then
			setVisible(tree, true)
			tree:SetAttribute("Felled", false)
		end
	end)
	return true
end

-- Public: hand a fresh item to the player (FishService uses this)
function ResourceService.Give(player: Player, kind: string): boolean
	return give(player, kind)
end

-- Remove the carried item and return its kind
local function consume(player: Player): string?
	local carry = carrying[player]
	if not carry then
		return nil
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	carry.item:Destroy()
	setCarrySpeed(player, false)
	return carry.kind
end

function ResourceService.DropCarried(player: Player, at: Vector3?)
	local carry = carrying[player]
	if not carry then
		return
	end
	local root = rootOf(player)
	local pos = at or if root then (root.CFrame * CFrame.new(0, 0, -3)).Position else carry.item.Position
	consume(player)
	ResourceService.SpawnItem(carry.kind, pos)
end

local function addPrompt(parent: Instance, action: string, object: string, hold: number, onTrigger: (Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(onTrigger)
	return prompt
end

local function setupStations(map: Instance)
	local lighthouse = map:FindFirstChild("Lighthouse")
	if not lighthouse then
		warn("[ResourceService] Map.Lighthouse missing")
		return
	end
	local ground = lighthouse:FindFirstChild("GroundFloor")
	local bunk = lighthouse:FindFirstChild("BunkRoom")
	local lampRoom = lighthouse:FindFirstChild("LampRoom")

	local crateA = ground and ground:FindFirstChild("StorageCrateA")
	if crateA then
		addPrompt(crateA, "Store item", "Storage", 0, function(player)
			local kind = ResourceService.GetCarried(player)
			if not kind then
				Remotes.notify(player, "Bring wood, scrap, oil or fish here to store it.", nil)
				return
			end
			if kind == "WhaleOil" then
				Remotes.notify(player, "Whale oil can't be stored. Pour it into the lamp!", nil)
				return
			end
			if kind == "RawFish" then
				Remotes.notify(player, "Cook it at the fireplace first, then store it.", nil)
				return
			end
			consume(player)
			ResourceService.AddStorage(kind, 1)
			Remotes.notify(player, `Stored 1 {kind}.`, "Good")
		end)
	end

	local crateB = ground and ground:FindFirstChild("StorageCrateB")
	if crateB then
		addPrompt(crateB, "Take fuel", "Storage", 0, function(player)
			if carrying[player] then
				Remotes.notify(player, "Your hands are full.", nil)
				return
			end
			if ResourceService.Spend("Oil", 1) then
				give(player, "Oil")
			elseif ResourceService.Spend("Wood", 1) then
				give(player, "Wood")
				Remotes.notify(player, "No oil left, so you took wood. It burns fast.", nil)
			else
				Remotes.notify(player, "Storage has no oil or wood!", "Alarm")
			end
		end)
	end

	local tank = lampRoom and lampRoom:FindFirstChild("FuelTank")
	if tank then
		addPrompt(tank, "Pour fuel", "Lamp fuel tank", 0.5, function(player)
			local kind = ResourceService.GetCarried(player)
			local value = if kind then (Config.Light.FuelValues :: any)[kind] else nil
			if not value then
				Remotes.notify(player, "Carry oil or wood up here to refuel the lamp.", nil)
				return
			end
			consume(player)
			LightService.AddFuel(value)
			Remotes.notify(player, `+{value} fuel`, "Good")
		end)
	end

	-- Fireplace: carried raw fish -> cooked fish (takes a few seconds by the fire)
	local fireplace = ground and ground:FindFirstChild("Fireplace")
	local hearth = fireplace and (fireplace:FindFirstChild("Hearth") or fireplace:FindFirstChildWhichIsA("BasePart"))
	if hearth then
		local cooking: { [Player]: boolean } = {}
		addPrompt(hearth, "Cook fish", "Fireplace", R.CookSeconds, function(player)
			if ResourceService.GetCarried(player) ~= "RawFish" then
				Remotes.notify(player, "Catch a fish in the sea (or the tide pools), then cook it here.", nil)
				return
			end
			if cooking[player] then
				return
			end
			cooking[player] = true
			consume(player)
			Remotes.notify(player, "Sizzling...", nil)
			task.delay(1.2, function()
				cooking[player] = nil
				if player.Parent and give(player, "Fish") then
					Remotes.notify(player, "Cooked fish! Store it in the chest or eat it in the bunk room.", "Good")
				else
					ResourceService.SpawnItem("Fish", hearth.Position + Vector3.new(0, 0, 3))
				end
			end)
		end)
	end

	local food = bunk and bunk:FindFirstChild("FoodStorage")
	if food then
		addPrompt(food, "Eat fish", "Food", 0.5, function(player)
			local humanoid = humanoidOf(player)
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			if ResourceService.GetCarried(player) == "RawFish" then
				Remotes.notify(player, "Raw fish will make you sick. Cook it at the fireplace downstairs!", nil)
				return
			end
			if ResourceService.GetCarried(player) == "Fish" then
				consume(player)
			elseif not ResourceService.Spend("Fish", 1) then
				Remotes.notify(player, "No cooked fish! Catch one in the sea and cook it at the fireplace.", nil)
				return
			end
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + R.FishHeal)
			Remotes.notify(player, "That hit the spot.", "Good")
		end)
	end
end

function setVisible(model: Instance, visible: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			-- remember each part's own look so invisible collision parts and leaf cards stay correct
			if d:GetAttribute("BaseTransparency") == nil then
				d:SetAttribute("BaseTransparency", d.Transparency)
				d:SetAttribute("BaseCollide", d.CanCollide)
			end
			local baseT = d:GetAttribute("BaseTransparency") :: number
			d.Transparency = if visible then baseT else 1 - (1 - baseT) * 0.15
			d.CanCollide = visible and (d:GetAttribute("BaseCollide") :: boolean)
		end
	end
end

local function setupGathering(map: Instance)
	-- trees are punched for wood (PunchService calls ResourceService.HitTree)
	local grove = map:FindFirstChild("PineGrove")
	if grove then
		for _, tree in grove:GetChildren() do
			local trunk = tree:FindFirstChild("Trunk")
			if tree:IsA("Model") and trunk and trunk:IsA("BasePart") then
				tree:SetAttribute("Hits", 0)
				tree:SetAttribute("Felled", false)
			end
		end
	end

	local function fishingSpot(part: BasePart, label: string): ProximityPrompt
		local prompt: ProximityPrompt
		prompt = addPrompt(part, "Catch fish", label, 2, function(player)
			if give(player, "RawFish") then
				prompt.Enabled = false
				task.delay(R.FishCooldownSeconds, function()
					prompt.Enabled = true
				end)
			end
		end)
		return prompt
	end

	local pools = map:FindFirstChild("TidePools")
	if pools then
		for _, pool in pools:GetChildren() do
			if pool:IsA("BasePart") and pool:GetAttribute("Resource") == "Fish" then
				fishingSpot(pool, "Tide pool")
			end
		end
	end

	local dock = map:FindFirstChild("OldDock")
	local deck = dock and dock:FindFirstChild("Deck")
	if dock and deck and deck:IsA("BasePart") then
		local spot = Instance.new("Attachment")
		spot.Name = "FishingSpot"
		spot.Position = Vector3.new(0, 1, 27)
		spot.Parent = deck
		local prompt = fishingSpot(deck, "Old dock")
		prompt.Parent = spot
		local unlockStorm = dock:GetAttribute("UnlockStorm")
		local function refresh()
			local storm = StormDirector.GetInfo().currentStorm
			prompt.Enabled = typeof(unlockStorm) ~= "number" or storm >= unlockStorm
		end
		StormDirector.PhaseChanged:Connect(refresh)
		refresh()
	end
end

local function spawnWreckage()
	local map = Workspace:FindFirstChild("Map")
	local beach = map and map:FindFirstChild("WreckBeach")
	local zone = beach and beach:FindFirstChild("WreckageSpawnZone")
	if not zone or not zone:IsA("BasePart") then
		return
	end
	for kind, count in R.WreckagePerDawn do
		for _ = 1, count do
			local offset = Vector3.new(rng:NextNumber(-0.5, 0.5) * zone.Size.X, 0, rng:NextNumber(-0.5, 0.5) * zone.Size.Z)
			ResourceService.SpawnItem(kind, zone.Position + offset)
		end
	end
	if rng:NextNumber() < R.SupplyCrateChance then
		for _ = 1, 2 do
			ResourceService.SpawnItem("Oil", Config.World.RampBottom + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(4, 12)))
		end
		Remotes.notify(nil, "A supply crate washed up by the ramp: 2 oil barrels!", "Good")
	end
end

function ResourceService.Reset()
	for player in carrying do
		consume(player)
	end
	itemsFolder:ClearAllChildren()
	table.clear(storage)
	for kind, amount in R.StartStorage do
		storage[kind] = amount
	end
	publishStorage()
	spawnWreckage()
end

function ResourceService.Start()
	storageState = SharedState.get("Storage")
	local runtime = Workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "Items"
	folder.Parent = runtime
	itemsFolder = folder

	local map = Workspace:WaitForChild("Map")
	setupStations(map)
	setupGathering(map)

	Remotes.event("DropItem").OnServerEvent:Connect(function(player: Player)
		local t = os.clock()
		if t - (lastDrop[player] or 0) < 0.3 then
			return
		end
		lastDrop[player] = t
		ResourceService.DropCarried(player)
	end)

	local function onCharacter(player: Player, character: Model)
		carrying[player] = nil
		player:SetAttribute("Carrying", nil)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		Movement.SetBase(humanoid, R.WalkSpeed)
		humanoid.Died:Connect(function()
			ResourceService.DropCarried(player)
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ResourceService.DropCarried(player)
		carrying[player] = nil
		lastDrop[player] = nil
	end)

	StormDirector.PhaseChanged:Connect(function(info)
		if info.phase == "Dawn" then
			spawnWreckage()
		end
	end)
	StormDirector.RunReset:Connect(ResourceService.Reset)
	ResourceService.Reset()
end

return ResourceService
