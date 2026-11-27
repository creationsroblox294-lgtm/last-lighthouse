--!strict
-- KeeperService: the core loop. Play -> earn Brass -> upgrade / unlock -> flex -> repeat.
--
--   Earn (game servers, StartGame): surviving each storm, finishing creatures with the harpoon,
--     repairing, crafting, winning a run, and a daily bonus for the first storm each day.
--     Paid the moment it's earned (and autosaved), so quitting mid-run never loses Brass.
--   Upgrade / unlock (any server): Remotes KeeperBuy(id) buys the next tier of a perk, a
--     lantern or a title from Config.Keeper; KeeperEquip(slot, id) wears a lantern or title.
--     Some titles can't be bought, only earned (level, best storm, a won run).
--   Flex (any server): a nameplate over your head with your title and Keeper level, and a
--     glowing lantern on your belt that everyone sees in the dark; unlocks are announced.
--   Perks: Thick Coat (max health), Deep Pockets (ResourceService reads Own_DeepPockets),
--     Ship's Stores (crew storage at the start of each run), Old Salt (more Brass).
--
-- Player attributes for clients: Brass, Own_<id> = tier, Title, Lantern, BestStorm, RunsWon
-- (KeeperLevel comes from DataService).
-- The Keeper's Locker stall in the harbor (Lobby.KeepersLocker) gets a prompt that opens the
-- window; the HUD's Locker button opens it anywhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))

local K = Config.Keeper
local E = K.Earn
local KeeperService = {}

type Profile = DataService.Profile

local perks: { [string]: any } = {}
local lanterns: { [string]: any } = {}
local titles: { [string]: any } = {}
for _, p in K.Perks :: { any } do
	perks[p.Id] = p
end
for _, l in K.Lanterns :: { any } do
	lanterns[l.Id] = l
end
for _, t in K.Titles :: { any } do
	titles[t.Id] = t
end

local lastAction: { [Player]: number } = {}
local repairsThisRun: { [Player]: number } = {}

local function tierOf(profile: Profile, id: string): number
	return profile.Owned[id] or 0
end

-- can this player wear this title?
local function titleUnlocked(profile: Profile, t: any): boolean
	if t.Cost then
		return tierOf(profile, t.Id) > 0
	elseif t.Level then
		return DataService.LevelOf(profile) >= t.Level
	elseif t.BestStorm then
		return profile.BestStorm >= t.BestStorm
	elseif t.RunsWon then
		return profile.RunsWon >= t.RunsWon
	end
	return true
end

---------------------------------------------------------------------------
-- Looks: nameplate + belt lantern
---------------------------------------------------------------------------
local function nameplate(player: Player, profile: Profile)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (head and humanoid) then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local gui = head:FindFirstChild("KeeperTag") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "KeeperTag"
		g.Size = UDim2.new(5, 0, 1.15, 0)
		g.StudsOffset = Vector3.new(0, 2.1, 0)
		g.MaxDistance = 70
		g.LightInfluence = 0
		g.PlayerToHideFrom = player -- you don't need your own name over your head
		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromScale(1, 0.55)
		name.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Parent = g
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0, 0.55)
		title.Size = UDim2.fromScale(1, 0.45)
		title.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
		title.TextScaled = true
		title.TextStrokeTransparency = 0.35
		title.Parent = g
		g.Parent = head
		gui = g
	end
	local g = gui :: BillboardGui
	local t = titles[profile.Title] or titles.Castaway
	local nameLabel = g:FindFirstChild("PlayerName") :: TextLabel
	local titleLabel = g:FindFirstChild("Title") :: TextLabel
	nameLabel.Text = player.DisplayName
	titleLabel.Text = `{string.upper(t.Name)}  ·  LV {DataService.LevelOf(profile)}`
	titleLabel.TextColor3 = t.Color
end

local function belt(player: Player, profile: Profile)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("KeeperLantern")
	if old then
		old:Destroy()
	end
	local l = lanterns[profile.Lantern]
	local hip = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if not (l and hip and hip:IsA("BasePart")) then
		return
	end
	-- the brass ship lantern (ReplicatedStorage.Assets.ShipLantern, modelled in Blender), small,
	-- with its glass and flame in this lantern's colour, welded at the hip
	local template = ReplicatedStorage:FindFirstChild("Assets") and (ReplicatedStorage :: any).Assets:FindFirstChild("ShipLantern")
	if not template then
		return
	end
	local model = template:Clone() :: Model
	model.Name = "KeeperLantern"
	model:ScaleTo(0.42)
	local _, size = model:GetBoundingBox()
	local at = hip.CFrame * CFrame.new(hip.Size.X / 2 + 0.22, -0.2 - size.Y / 2, 0.1)
	model:PivotTo(at * (model:GetPivot() - model:GetPivot().Position).Rotation)
	local bb = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (at.Position - bb.Position))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hip
			weld.Part1 = p
			weld.Parent = p
		end
	end
	local glass = model:FindFirstChild("Glass") :: BasePart?
	local flame = model:FindFirstChild("Flame") :: BasePart?
	local brassPart = model:FindFirstChild("Brass") :: BasePart?
	if glass then
		glass.Color = (l.Color :: Color3):Lerp(Color3.new(1, 1, 1), 0.25)
	end
	if brassPart and l.Id == "Gilded" then
		brassPart.Color = Color3.fromRGB(236, 196, 96)
		brassPart.Reflectance = 0.2
	end
	if flame then
		flame.Color = l.Color
		local light = flame:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = l.Color
			light.Brightness = 1.2
			light.Range = 9
			light.Shadows = false
		end
		if l.Sparkle then
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = "rbxassetid://118122779843195"
			sparks.Color = ColorSequence.new(l.Color)
			sparks.LightEmission = 1
			sparks.Rate = 6
			sparks.Lifetime = NumberRange.new(0.6, 1.1)
			sparks.Speed = NumberRange.new(0.5, 1.5)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Size = NumberSequence.new(0.12, 0)
			sparks.Parent = flame
		end
	end
	model.Parent = character
end

local function publish(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	for id, tier in profile.Owned do
		player:SetAttribute("Own_" .. id, tier)
	end
	player:SetAttribute("Title", profile.Title)
	player:SetAttribute("Lantern", profile.Lantern)
	player:SetAttribute("BestStorm", profile.BestStorm)
	player:SetAttribute("RunsWon", profile.RunsWon)
	DataService.Changed(player)
	nameplate(player, profile)
end

local inGame = false

-- Thick Coat: more max health (game servers)
local function applyCoat(player: Player, profile: Profile)
	if not inGame then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local want = 100 + tierOf(profile, "ThickCoat") * perks.ThickCoat.PerTier
	if humanoid.MaxHealth ~= want then
		local frac = humanoid.Health / humanoid.MaxHealth
		humanoid.MaxHealth = want
		humanoid.Health = want * frac
	end
end

local function dress(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	nameplate(player, profile)
	belt(player, profile)
	applyCoat(player, profile)
end

---------------------------------------------------------------------------
-- Earning
---------------------------------------------------------------------------
function KeeperService.Award(player: Player, amount: number, reason: string)
	local profile = DataService.GetProfile(player)
	if not profile or amount <= 0 then
		return
	end
	local bonus = 1 + tierOf(profile, "OldSalt") * perks.OldSalt.PerTier / 100
	local paid = math.floor(amount * bonus + 0.5)
	profile.Brass += paid
	profile.BrassEarned += paid
	DataService.Changed(player)
	Remotes.event("Earned"):FireClient(player, paid, reason)
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function onStormSurvived(n: number)
	for _, player in Players:GetPlayers() do
		local profile = DataService.GetProfile(player)
		if profile and alive(player) then
			KeeperService.Award(player, E.NightBase + E.NightPerStorm * n, `Survived storm {n}`)
			if profile.DailyDay ~= today() then
				profile.DailyDay = today()
				KeeperService.Award(player, E.DailyBonus, "Daily tide bonus")
			end
			task.defer(publish, player) -- level / best storm may have changed (DataService adds XP)
		end
	end
end

local function onRunFinished(won: boolean)
	if not won then
		return
	end
	for _, player in Players:GetPlayers() do
		local profile = DataService.GetProfile(player)
		if profile then
			profile.RunsWon += 1
			KeeperService.Award(player, E.RunWon, "Kept the light burning!")
			publish(player)
		end
	end
end

local function onReward(player: Player, kind: string)
	if kind == "Kill" then
		KeeperService.Award(player, E.Kill, "Creature down")
	elseif kind == "Craft" then
		KeeperService.Award(player, E.Craft, "Crafted")
	elseif kind == "Repair" then
		local n = (repairsThisRun[player] or 0) + 1
		repairsThisRun[player] = n
		if n <= E.RepairCapPerRun then
			KeeperService.Award(player, E.Repair, "Repair")
		end
	end
end

local function onRunReset()
	table.clear(repairsThisRun)
	-- Ship's Stores: everyone who owns it brings supplies into the crew's storage
	local ResourceService = require(script.Parent:WaitForChild("ResourceService")) :: any
	local wood, scrap = 0, 0
	for _, player in Players:GetPlayers() do
		local profile = DataService.GetProfile(player)
		local tier = profile and tierOf(profile, "HeadStart") or 0
		wood += tier * 2
		scrap += tier
	end
	if wood > 0 then
		task.delay(1, function()
			ResourceService.AddStorage("Wood", wood)
			ResourceService.AddStorage("Scrap", scrap)
			Remotes.notify(nil, `Ship's Stores: the crew brought {wood} wood and {scrap} scrap.`, "Good")
		end)
	end
end

---------------------------------------------------------------------------
-- Spending and wearing
---------------------------------------------------------------------------
local function throttled(player: Player): boolean
	local t = os.clock()
	if t - (lastAction[player] or 0) < 0.3 then
		return true
	end
	lastAction[player] = t
	return false
end

local function buy(player: Player, id: any)
	if typeof(id) ~= "string" or throttled(player) then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local cost: number? = nil
	local nextTier = 1
	local item = perks[id] or lanterns[id] or titles[id]
	if not item then
		return
	end
	if perks[id] then
		nextTier = tierOf(profile, id) + 1
		cost = item.Costs[nextTier]
		if not cost then
			return -- maxed
		end
	else
		if tierOf(profile, id) > 0 or not item.Cost then
			return -- owned already, or earned-only
		end
		cost = item.Cost
	end
	local price = cost :: number
	if profile.Brass < price then
		Remotes.notify(player, `You need {price - profile.Brass} more Brass.`, nil)
		return
	end
	profile.Brass -= price
	profile.Owned[id] = nextTier
	if lanterns[id] then
		profile.Lantern = id
		Remotes.notify(nil, `{player.DisplayName} unlocked the {item.Name}!`, "Good")
	elseif titles[id] then
		profile.Title = id
		Remotes.notify(nil, `{player.DisplayName} is now a {item.Name}!`, "Good")
	else
		Remotes.notify(player, `{item.Name} {if #item.Costs > 1 then "tier " .. nextTier else ""} unlocked.`, "Good")
	end
	publish(player)
	dress(player)
end

local function equip(player: Player, slot: any, id: any)
	if typeof(slot) ~= "string" or typeof(id) ~= "string" or throttled(player) then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	if slot == "Lantern" then
		if id ~= "" and not (lanterns[id] and tierOf(profile, id) > 0) then
			return
		end
		profile.Lantern = id
	elseif slot == "Title" then
		local t = titles[id]
		if not (t and titleUnlocked(profile, t)) then
			return
		end
		profile.Title = id
	else
		return
	end
	publish(player)
	dress(player)
end

---------------------------------------------------------------------------
local function setUp(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	-- a title that's no longer earned (or unknown) falls back to Castaway
	local t = titles[profile.Title]
	if not (t and titleUnlocked(profile, t)) then
		profile.Title = "Castaway"
	end
	if profile.Lantern ~= "" and not lanterns[profile.Lantern] then
		profile.Lantern = ""
	end
	publish(player)
	dress(player)
end

local function addLockerPrompt()
	local lobby = Workspace:FindFirstChild("Lobby")
	local stall = lobby and lobby:FindFirstChild("KeepersLocker")
	local counter = stall and stall:FindFirstChild("Counter")
	if counter and counter:IsA("BasePart") and not counter:FindFirstChild("LockerPrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockerPrompt"
		prompt.ActionText = "Open"
		prompt.ObjectText = "Keeper's Locker"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
	end
end

local started = false
function KeeperService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("KeeperBuy").OnServerEvent:Connect(buy)
	Remotes.event("KeeperEquip").OnServerEvent:Connect(equip)
	Remotes.event("Earned")
	DataService.Loaded:Connect(setUp)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("ProfileLoaded") then
			task.spawn(setUp, player)
		end
	end
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			character:WaitForChild("Head", 10)
			task.wait(0.2)
			dress(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		repairsThisRun[player] = nil
	end)
	addLockerPrompt()
	-- Studio testing: set workspace attribute KeeperGiveBrass (a number) to pay everyone that much
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("KeeperGiveBrass"):Connect(function()
			local amount = Workspace:GetAttribute("KeeperGiveBrass")
			if typeof(amount) == "number" and amount > 0 then
				Workspace:SetAttribute("KeeperGiveBrass", nil)
				for _, player in Players:GetPlayers() do
					KeeperService.Award(player, amount, "Studio test")
				end
			end
		end)
	end
end

-- Game servers only: the earning side, and perks that act during a run
function KeeperService.StartGame()
	inGame = true
	StormDirector.StormSurvived:Connect(onStormSurvived)
	StormDirector.RunFinished:Connect(onRunFinished)
	StormDirector.RunReset:Connect(onRunReset)
	Rewards.Earned:Connect(onReward)
	for _, player in Players:GetPlayers() do
		task.spawn(dress, player)
	end
end

return KeeperService
