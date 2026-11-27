--!strict
-- CraftingService: the crafting table on the lighthouse's ground floor.
--
-- The table (Map.Lighthouse.GroundFloor.CraftingTable, built by tools/BuildCraftingTable.luau)
-- gets a "Craft" prompt; the client opens the crafting window (CraftingController) and sends
-- Craft(recipeId). Recipes are in Config.Crafting: materials come out of the shared storage.
--   Personal recipes set a player attribute (HarpoonTier, HammerTier, FlareTier) that
--   CombatService / BuildService read, and tint that player's tools so everyone sees them.
--   Crew recipes go in SharedState "Crafting" (<id> = true); the lenses raise LightService's lens tier.
-- Everything resets when a new run starts.

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
local CombatService = require(script.Parent:WaitForChild("CombatService"))

local K = Config.Crafting
local CraftingService = {}

type Recipe = {
	Id: string,
	Name: string,
	Scope: string,
	Stat: string,
	Level: number,
	Requires: string?,
	Cost: { [string]: number },
	Blurb: string,
}

local byId: { [string]: Recipe } = {}
for _, r in K.Recipes :: { Recipe } do
	byId[r.Id] = r
end
local PERSONAL_STATS = { "HarpoonTier", "HammerTier", "FlareTier" }

local crewState: Configuration
local tablePart: BasePart? = nil
local lastCraft: { [Player]: number } = {}

-- does this player (or the crew) already have the recipe's level?
local function has(player: Player, r: Recipe): boolean
	if r.Scope == "Crew" then
		return crewState:GetAttribute(r.Id) == true
	end
	local v = player:GetAttribute(r.Stat)
	return typeof(v) == "number" and v >= r.Level
end

local function nearTable(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (tablePart and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return false
	end
	return (root.Position - tablePart.Position).Magnitude <= K.UseRange + 2 -- a little slack for lag
end

local function craft(player: Player, recipeId: any)
	if typeof(recipeId) ~= "string" then
		return
	end
	local r = byId[recipeId]
	if not r then
		return
	end
	local t = os.clock()
	if t - (lastCraft[player] or 0) < 0.4 then
		return
	end
	lastCraft[player] = t
	if not nearTable(player) then
		Remotes.notify(player, "Stand at the crafting table to craft.", nil)
		return
	end
	if has(player, r) then
		return
	end
	if r.Requires then
		local need = byId[r.Requires]
		if need and not has(player, need) then
			Remotes.notify(player, `Craft the {need.Name} first.`, nil)
			return
		end
	end
	-- check everything before spending anything
	local missing = {}
	for kind, amount in r.Cost do
		local have = ResourceService.GetStorage(kind)
		if have < amount then
			table.insert(missing, `{amount - have} {string.lower(kind)}`)
		end
	end
	if #missing > 0 then
		Remotes.notify(player, `Storage needs {table.concat(missing, ", ")} more.`, nil)
		return
	end
	for kind, amount in r.Cost do
		ResourceService.Spend(kind, amount)
	end

	if r.Scope == "Crew" then
		crewState:SetAttribute(r.Id, true)
		if r.Stat == "LensTier" then
			LightService.SetLensTier(r.Level)
		end
		Remotes.notify(nil, `{player.DisplayName} fitted the {r.Name}! The light reaches further.`, "Good")
	else
		player:SetAttribute(r.Stat, r.Level)
		CombatService.Dress(player)
		Remotes.notify(nil, `{player.DisplayName} crafted a {r.Name}!`, "Good")
	end
	Remotes.event("Crafted"):FireAllClients(player, r.Id)
end

function CraftingService.Reset()
	for _, player in Players:GetPlayers() do
		for _, stat in PERSONAL_STATS do
			player:SetAttribute(stat, nil)
		end
		CombatService.Dress(player)
	end
	for _, r in K.Recipes :: { Recipe } do
		if r.Scope == "Crew" then
			crewState:SetAttribute(r.Id, nil)
		end
	end
end

function CraftingService.Start()
	crewState = SharedState.get("Crafting")
	local map = Workspace:WaitForChild("Map")
	local lighthouse = map:FindFirstChild("Lighthouse")
	local ground = lighthouse and lighthouse:FindFirstChild("GroundFloor")
	local bench = ground and ground:FindFirstChild("CraftingTable")
	local top = bench and (bench:FindFirstChild("Top") or bench:FindFirstChildWhichIsA("BasePart", true))
	if top and top:IsA("BasePart") then
		tablePart = top
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CraftPrompt"
		prompt.ActionText = "Craft"
		prompt.ObjectText = "Crafting table"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = K.UseRange
		prompt.RequiresLineOfSight = false
		prompt.Parent = top
	else
		warn("[CraftingService] Map.Lighthouse.GroundFloor.CraftingTable missing")
	end

	Remotes.event("Craft").OnServerEvent:Connect(craft)
	Players.PlayerRemoving:Connect(function(player)
		lastCraft[player] = nil
	end)
	StormDirector.RunReset:Connect(CraftingService.Reset)
end

return CraftingService
