--!strict
-- ResourceService: physical items, carrying, the shared storage, gathering and wreckage.
--
-- Everything you gather goes into your backpack (Config.Resources.BackpackSize items; the
-- fuller it is, the slower you walk, so hauling is still real work). Stations:
--   StorageCrateA  "Empty backpack" -> wood, scrap, oil and cooked fish go into shared storage
--   StorageCrateB  "Take fuel"      -> oil (or wood) from storage into your backpack
--   FuelTank       "Pour fuel"      -> whale oil, oil (or wood) from your backpack into the lamp
--   Fireplace      "Cook fish"      -> every raw fish in your backpack gets cooked
--   FoodStorage    "Eat fish"       -> heals you
-- Players see what's in their backpack through player attributes "Pack_<Kind>" and
-- "PackTotal"; "Carrying" is the kind they picked up last (nil when the backpack is empty).
-- Every item gained fires "Gained" (kind, amount, fromPosition) for the pop-up animation.
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

local storageState: Configuration
local storage: { [string]: number } = {}
local packs: { [Player]: { [string]: number } } = {}
local lastKind: { [Player]: string } = {}
local PACK_KINDS = { "Wood", "Scrap", "Oil", "Fish", "RawFish", "WhaleOil" }
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

local function packOf(player: Player): { [string]: number }
	local pack = packs[player]
	if not pack then
		pack = {}
		packs[player] = pack
	end
	return pack
end

local function packTotal(player: Player): number
	local n = 0
	for _, count in packOf(player) do
		n += count
	end
	return n
end

-- The kind the player picked up last, or any kind they have (nil when the backpack is empty)
function ResourceService.GetCarried(player: Player): string?
	local pack = packOf(player)
	local last = lastKind[player]
	if last and (pack[last] or 0) > 0 then
		return last
	end
	for _, kind in PACK_KINDS do
		if (pack[kind] or 0) > 0 then
			return kind
		end
	end
	return nil
end

function ResourceService.Has(player: Player, kind: string): boolean
	return (packOf(player)[kind] or 0) > 0
end

function ResourceService.Count(player: Player, kind: string): number
	return packOf(player)[kind] or 0
end

function ResourceService.IsFull(player: Player): boolean
	return packTotal(player) >= R.BackpackSize
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

-- the fuller the backpack, the slower you walk
local function updatePack(player: Player)
	local pack = packOf(player)
	local total = 0
	for _, kind in PACK_KINDS do
		local n = pack[kind] or 0
		total += n
		player:SetAttribute("Pack_" .. kind, if n > 0 then n else nil)
	end
	player:SetAttribute("PackTotal", total)
	player:SetAttribute("PackSize", R.BackpackSize)
	player:SetAttribute("Carrying", ResourceService.GetCarried(player))
	local humanoid = humanoidOf(player)
	if humanoid then
		local load = math.clamp(total / R.BackpackSize, 0, 1)
		Movement.SetBase(humanoid, R.WalkSpeed - (R.WalkSpeed - R.CarryWalkSpeed) * load)
	end
end

local function fullMessage(player: Player)
	Remotes.notify(player, `Your backpack is full ({R.BackpackSize}). Empty it at the storage chest.`, nil)
end

-- Put items in the backpack. from: where they came from (for the pop-up animation).
local function add(player: Player, kind: string, amount: number, from: Vector3?): boolean
	if packTotal(player) + amount > R.BackpackSize then
		fullMessage(player)
		return false
	end
	local pack = packOf(player)
	pack[kind] = (pack[kind] or 0) + amount
	lastKind[player] = kind
	updatePack(player)
	local root = rootOf(player)
	Remotes.event("Gained"):FireClient(player, kind, amount, from or (if root then root.Position else nil))
	return true
end

-- Take items out of the backpack; returns how many were taken
local function take(player: Player, kind: string, amount: number): number
	local pack = packOf(player)
	local n = math.min(pack[kind] or 0, amount)
	if n > 0 then
		pack[kind] -= n
		if pack[kind] <= 0 then
			pack[kind] = nil
		end
		updatePack(player)
	end
	return n
end

pickUp = function(player: Player, part: BasePart)
	if part.Parent ~= itemsFolder then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local kind = part:GetAttribute("ItemKind")
	if typeof(kind) ~= "string" then
		return
	end
	if add(player, kind, 1, part.Position) then
		part:Destroy()
	end
end

-- Give the player a fresh item (from a tree, pool or storage)
local function give(player: Player, kind: string, from: Vector3?): boolean
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	return add(player, kind, 1, from)
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
	if ResourceService.IsFull(player) then
		fullMessage(player)
		tree:SetAttribute("Hits", R.PunchesPerTree - 1)
		return "full"
	end
	local trunk = tree:FindFirstChild("Trunk")
	local from = if trunk and trunk:IsA("BasePart") then trunk.Position + Vector3.new(0, 2, 0) else nil
	if not give(player, "Wood", from) then
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

-- Public: put a fresh item in the player's backpack (FishService uses this)
function ResourceService.Give(player: Player, kind: string, from: Vector3?): boolean
	return give(player, kind, from)
end

-- Drop one item (of `kind`, or the last kind picked up) on the ground
function ResourceService.DropCarried(player: Player, at: Vector3?, kind: string?)
	local which = kind or ResourceService.GetCarried(player)
	if not which or take(player, which, 1) == 0 then
		return
	end
	local root = rootOf(player)
	local pos = at or if root then (root.CFrame * CFrame.new(0, 0, -3)).Position else nil
	if pos then
		ResourceService.SpawnItem(which, pos)
	end
end

-- Drop everything (on death), spread around where the player fell
local function dropAll(player: Player)
	local root = rootOf(player)
	local center = if root then root.Position else nil
	for _, kind in PACK_KINDS do
		local n = take(player, kind, math.huge)
		if center then
			for _ = 1, n do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(1.5, 5)
				ResourceService.SpawnItem(kind, center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			end
		end
	end
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

-- A leather backpack (with a rolled blanket on top) strapped to the character's back
local function wearBackpack(character: Model)
	local torso = character:WaitForChild("UpperTorso", 5) or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") or character:FindFirstChild("PackModel") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "PackModel"
	local back = torso.CFrame * CFrame.new(0, 0.05, torso.Size.Z / 2 + 0.5)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.CFrame = back * offset
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso :: BasePart
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end
	local leather = Color3.fromRGB(120, 72, 40)
	local brass = Color3.fromRGB(205, 160, 70)
	piece("Body", Vector3.new(1.5, 1.7, 0.85), CFrame.new(), leather, Enum.Material.Leather)
	piece("Flap", Vector3.new(1.54, 0.6, 0.9), CFrame.new(0, 0.6, 0.02), Color3.fromRGB(100, 58, 32), Enum.Material.Leather)
	piece("Pocket", Vector3.new(1, 0.6, 0.25), CFrame.new(0, -0.35, 0.5), Color3.fromRGB(105, 62, 34), Enum.Material.Leather)
	piece("BuckleL", Vector3.new(0.18, 0.2, 0.08), CFrame.new(-0.4, 0.38, 0.48), brass, Enum.Material.Metal)
	piece("BuckleR", Vector3.new(0.18, 0.2, 0.08), CFrame.new(0.4, 0.38, 0.48), brass, Enum.Material.Metal)
	piece("Blanket", Vector3.new(1.7, 0.5, 0.5), CFrame.new(0, 1.05, -0.05), Color3.fromRGB(34, 48, 86), Enum.Material.Fabric, Enum.PartType.Cylinder)
	piece("StrapL", Vector3.new(0.14, 1.9, 0.06), CFrame.new(-0.45, 0.1, -0.46), Color3.fromRGB(70, 42, 24), Enum.Material.Leather)
	piece("StrapR", Vector3.new(0.14, 1.9, 0.06), CFrame.new(0.45, 0.1, -0.46), Color3.fromRGB(70, 42, 24), Enum.Material.Leather)
	model.Parent = character
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
		addPrompt(crateA, "Empty backpack", "Storage", 0, function(player)
			local stored = {}
			for _, kind in R.Kinds do
				local n = take(player, kind, math.huge)
				if n > 0 then
					ResourceService.AddStorage(kind, n)
					table.insert(stored, `{n} {string.lower(kind)}`)
				end
			end
			local left = {}
			if ResourceService.Has(player, "RawFish") then
				table.insert(left, "cook the raw fish at the fireplace first")
			end
			if ResourceService.Has(player, "WhaleOil") then
				table.insert(left, "whale oil goes straight into the lamp")
			end
			if #stored > 0 then
				Remotes.notify(player, `Stored {table.concat(stored, ", ")}.`, "Good")
			elseif #left == 0 then
				Remotes.notify(player, "Your backpack is empty. Gather wood, scrap, oil or fish.", nil)
			end
			if #left > 0 then
				Remotes.notify(player, `Kept in your backpack: {table.concat(left, "; ")}.`, nil)
			end
		end)
	end

	local crateB = ground and ground:FindFirstChild("StorageCrateB")
	if crateB then
		addPrompt(crateB, "Take fuel", "Storage", 0, function(player)
			-- up to R.TakeFuel at a time: oil first, then wood
			local room = R.BackpackSize - packTotal(player)
			if room <= 0 then
				fullMessage(player)
				return
			end
			local want = math.min(R.TakeFuel, room)
			local oil = math.min(want, storage.Oil or 0)
			local wood = math.min(want - oil, storage.Wood or 0)
			if oil + wood == 0 then
				Remotes.notify(player, "Storage has no oil or wood!", "Alarm")
				return
			end
			local from = if crateB:IsA("BasePart") then crateB.Position else nil
			if oil > 0 and ResourceService.Spend("Oil", oil) then
				add(player, "Oil", oil, from)
			end
			if wood > 0 and ResourceService.Spend("Wood", wood) then
				add(player, "Wood", wood, from)
				if oil == 0 then
					Remotes.notify(player, "No oil left, so you took wood. It burns fast.", nil)
				end
			end
		end)
	end

	local tank = lampRoom and lampRoom:FindFirstChild("FuelTank")
	if tank then
		addPrompt(tank, "Pour fuel", "Lamp fuel tank", 0.5, function(player)
			-- pour the best fuel first until the tank is full; wood only if there's no oil
			local values = Config.Light.FuelValues :: any
			local room = Config.Light.MaxFuel - LightService.GetFuel()
			local poured = 0
			local hasOil = ResourceService.Has(player, "WhaleOil") or ResourceService.Has(player, "Oil")
			for _, kind in { "WhaleOil", "Oil", "Wood" } do
				if kind == "Wood" and hasOil then
					break
				end
				while room > 0 and ResourceService.Has(player, kind) do
					take(player, kind, 1)
					LightService.AddFuel(values[kind])
					room -= values[kind]
					poured += values[kind]
				end
			end
			if poured == 0 then
				Remotes.notify(player, if room <= 0 then "The tank is already full." else "Bring oil or wood up here in your backpack to refuel the lamp.", nil)
				return
			end
			Remotes.notify(player, `+{poured} fuel`, "Good")
		end)
	end

	-- Fireplace: carried raw fish -> cooked fish (takes a few seconds by the fire)
	local fireplace = ground and ground:FindFirstChild("Fireplace")
	local hearth = fireplace and (fireplace:FindFirstChild("Hearth") or fireplace:FindFirstChildWhichIsA("BasePart"))
	if hearth then
		local cooking: { [Player]: boolean } = {}
		addPrompt(hearth, "Cook fish", "Fireplace", R.CookSeconds, function(player)
			if not ResourceService.Has(player, "RawFish") then
				Remotes.notify(player, "Catch a fish in the sea (or the tide pools), then cook it here.", nil)
				return
			end
			if cooking[player] then
				return
			end
			cooking[player] = true
			local n = take(player, "RawFish", math.huge)
			Remotes.notify(player, "Sizzling...", nil)
			task.delay(1.2, function()
				cooking[player] = nil
				if player.Parent then
					local pack = packOf(player)
					pack.Fish = (pack.Fish or 0) + n -- the raw fish's space is still free
					lastKind[player] = "Fish"
					updatePack(player)
					Remotes.event("Gained"):FireClient(player, "Fish", n, hearth.Position)
					Remotes.notify(player, `Cooked {n} fish! Store it in the chest or eat it in the bunk room.`, "Good")
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
			if ResourceService.Has(player, "Fish") then
				take(player, "Fish", 1)
			elseif ResourceService.Has(player, "RawFish") and (storage.Fish or 0) <= 0 then
				Remotes.notify(player, "Raw fish will make you sick. Cook it at the fireplace downstairs!", nil)
				return
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
			if give(player, "RawFish", part.Position) then
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
	for player in packs do
		table.clear(packs[player])
		updatePack(player)
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

	Remotes.event("DropItem").OnServerEvent:Connect(function(player: Player, kind: any)
		local t = os.clock()
		if t - (lastDrop[player] or 0) < 0.2 then
			return
		end
		lastDrop[player] = t
		-- the client may name which kind to drop; anything else drops the last kind picked up
		local which = if typeof(kind) == "string" and table.find(PACK_KINDS, kind) then kind else nil
		ResourceService.DropCarried(player, nil, which)
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		updatePack(player) -- the backpack (now empty after a death) and walk speed
		task.spawn(wearBackpack, character)
		humanoid.Died:Connect(function()
			dropAll(player)
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
		dropAll(player)
		packs[player] = nil
		lastKind[player] = nil
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
