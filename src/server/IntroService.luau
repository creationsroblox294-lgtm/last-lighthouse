--!strict
-- IntroService: the party's intro cutscene.
--   * Waits for the whole party to arrive (the TeleportData from the harbor says how many),
--     then publishes IntroCast ("id,id,...") and IntroStartAt (server time) on
--     ReplicatedStorage so every client plays the same film, with everyone in it, in sync.
--   * Keeps the party's characters streamed to every client (the film clones them).
--   * After the film each player wakes on the beach where their actor lay (side by side,
--     slot by cast order), facing the lighthouse. Only once per player per server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))

local IntroService = {}
local done: { [Player]: boolean } = {}
local cast: { number } = {}

local SLOT_SPACING = 4.2 -- must match Client/IntroController (slotGround)

-- How many players the harbor sent over together (1 if unknown, e.g. Studio)
local function expectedPartySize(): number
	local best = 0
	for _, p in Players:GetPlayers() do
		local ok, data = pcall(function()
			return p:GetJoinData().TeleportData
		end)
		if ok and typeof(data) == "table" and typeof(data.party) == "table" then
			best = math.max(best, #data.party)
		end
	end
	return math.max(best, #Players:GetPlayers(), 1)
end

-- Pick the cast once the party is here (or after a timeout), then a shared start time
local function scheduleIntro()
	while #Players:GetPlayers() == 0 do
		task.wait(0.2)
	end
	local deadline = os.clock() + 20
	while #Players:GetPlayers() < expectedPartySize() and os.clock() < deadline do
		task.wait(0.25)
	end
	-- let avatars finish loading so nobody appears half-dressed in the film
	local t = os.clock()
	while os.clock() - t < 6 do
		local ready = true
		for _, p in Players:GetPlayers() do
			if not (p.Character and p:HasAppearanceLoaded()) then
				ready = false
			end
		end
		if ready then
			break
		end
		task.wait(0.2)
	end
	local ids = {}
	for _, p in Players:GetPlayers() do
		table.insert(ids, p.UserId)
	end
	table.sort(ids)
	cast = ids
	local text = {}
	for _, id in ids do
		table.insert(text, tostring(id))
	end
	ReplicatedStorage:SetAttribute("IntroCast", table.concat(text, ","))
	ReplicatedStorage:SetAttribute("IntroStartAt", Workspace:GetServerTimeNow() + 2.5)
end

function IntroService.Start()
	-- the intro films out at sea and on the south beach, far from where you spawn: until it
	-- is over, stream the world in around the film set instead of around the character
	-- (the real character waits, anchored, so it can't fall while its surroundings are unloaded)
	local foci: { [Player]: BasePart } = {}
	local function holdCharacter(player: Player, hold: boolean)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = hold
		end
	end
	local function releaseFocus(player: Player)
		local focus = foci[player]
		if focus then
			foci[player] = nil
			if player.Parent then
				player.ReplicationFocus = nil
			end
			focus:Destroy()
			holdCharacter(player, false)
		end
	end
	local function onPlayer(player: Player)
		if not (Config.Intro and Config.Intro.Enabled) or foci[player] then
			return
		end
		player.CharacterAdded:Connect(function(character)
			if foci[player] then
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root and root:IsA("BasePart") and foci[player] then
					root.Anchored = true
				end
			end
		end)
		holdCharacter(player, true)
		local focus = Instance.new("Part")
		focus.Name = "IntroFocus_" .. player.UserId
		focus.Anchored = true
		focus.CanCollide = false
		focus.CanQuery = false
		focus.CanTouch = false
		focus.Transparency = 1
		focus.Size = Vector3.one
		focus.Position = Config.Intro.FilmSet or Vector3.new(30, 10, 1000)
		focus.Parent = Workspace
		foci[player] = focus
		player.ReplicationFocus = focus
		-- never leave someone stuck streaming the film set
		task.delay(90, function()
			releaseFocus(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- the film clones every party member: keep all characters streamed to every client
	local function persist(player: Player)
		local function apply(character: Model)
			character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
		player.CharacterAdded:Connect(apply)
		if player.Character then
			apply(player.Character)
		end
	end
	Players.PlayerAdded:Connect(persist)
	for _, player in Players:GetPlayers() do
		persist(player)
	end
	if Config.Intro and Config.Intro.Enabled then
		task.spawn(scheduleIntro)
	end

	Remotes.event("IntroDone").OnServerEvent:Connect(function(player: Player)
		releaseFocus(player)
		if done[player] then
			return
		end
		done[player] = true
		local beach = Config.World.IntroBeach
		-- joining in the middle of a storm: stay safe in the lighthouse instead
		if not beach or StormDirector.GetPhase() == "Storm" then
			return
		end
		local character = player.Character
		if not character then
			return
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Include
		ray.FilterDescendantsInstances = { Workspace.Terrain }
		local tower = Config.World.TowerCenter
		-- wake where your actor lay in the film: side by side across the beach, in cast order
		local spot: Vector3
		local slot = table.find(cast, player.UserId)
		local centerHit = Workspace:Raycast(beach + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), ray)
		local center = if centerHit then centerHit.Position else beach
		if slot then
			local toward = (Vector3.new(tower.X, 0, tower.Z) - Vector3.new(center.X, 0, center.Z)).Unit
			local right = CFrame.lookAt(center, center + toward).RightVector
			spot = center + right * ((slot - (#cast + 1) / 2) * SLOT_SPACING)
		else
			spot = beach + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
		end
		local hit = Workspace:Raycast(spot + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), ray)
		spot = (if hit then hit.Position else spot) + Vector3.new(0, 3, 0)
		character:PivotTo(CFrame.lookAt(spot, Vector3.new(tower.X, spot.Y, tower.Z)))
		Remotes.notify(player, "You wash up on a strange island. Find the lighthouse.", "Good")
	end)
	Players.PlayerRemoving:Connect(function(player)
		releaseFocus(player)
		done[player] = nil
	end)
end

return IntroService
