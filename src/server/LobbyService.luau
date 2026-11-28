--!strict
-- LobbyService: the harbor. Each boat in Workspace.Lobby.Boats (six: tools/BuildLobby.luau + tools/AddBoats56.luau) takes a party of up to 4.
--
--   * The first person to step onto an empty boat is its leader and creates the party:
--     they choose its size (1-4) with the ChooseParty remote. Until they do, the boat is
--     reserved (anyone else is put back on the dock).
--   * Then up to that many can board. When the party is full a short countdown starts
--     (Config.Lobby.FullCountdown); if someone steps off it stops. The leader can change the
--     size (not below how many are aboard). If the leader leaves, the next aboard leads;
--     an empty boat resets.
--   * When the countdown ends the boat casts off: the party is seated and the boat rows out
--     (every client animates it from the CastOffAt attribute). After CastOffSeconds the
--     server reserves a private server and teleports the party there together.
--   * In Studio there is no teleport: casting off calls onStudioLaunch instead, which
--     switches this server into the game.
--
-- Boat attributes (read by Client/LobbyController):
--   Count, Capacity (chosen party size, 0 while the leader is choosing), Leader (user id or 0),
--   LeaderName, LeavesAt (server time or 0), CastOffAt (server time or 0), Passengers ("id,id")
-- Player attribute: Boat (boat name, or nil)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local LobbyService = {}

type Boat = {
	model: Model,
	zone: BasePart,
	exit: BasePart,
	seats: { Attachment },
	passengers: { Player },
	leader: Player?,
	size: number?, -- chosen party size (nil: the leader hasn't chosen yet)
	leavesAt: number?,
	castingOff: boolean,
}

local boats: { Boat } = {}
local onStudioLaunch: ((party: { Player }) -> ())? = nil
local running = false

local function now(): number
	return Workspace:GetServerTimeNow()
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

local function inside(zone: BasePart, at: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(at)
	local h = zone.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function publish(boat: Boat)
	local ids = {}
	for _, p in boat.passengers do
		table.insert(ids, tostring(p.UserId))
	end
	boat.model:SetAttribute("Count", #boat.passengers)
	boat.model:SetAttribute("Capacity", boat.size or 0)
	boat.model:SetAttribute("Leader", if boat.leader then boat.leader.UserId else 0)
	boat.model:SetAttribute("LeaderName", if boat.leader then boat.leader.DisplayName else "")
	boat.model:SetAttribute("LeavesAt", boat.leavesAt or 0)
	boat.model:SetAttribute("Passengers", table.concat(ids, ","))
end

-- Put someone back on the dock next to their boat
local function putOnDock(boat: Boat, player: Player)
	local root = rootOf(player)
	if root then
		root.Anchored = false
		local character = player.Character :: Model
		character:PivotTo(CFrame.lookAt(boat.exit.Position, boat.exit.Position + Vector3.new(-1, 0, 0)))
	end
	if player:GetAttribute("Boat") == boat.model.Name then
		player:SetAttribute("Boat", nil)
	end
end

local function resetBoat(boat: Boat)
	boat.castingOff = false
	boat.leavesAt = nil
	boat.leader = nil
	boat.size = nil
	table.clear(boat.passengers)
	boat.model:SetAttribute("CastOffAt", 0)
	publish(boat)
end

local function teleportParty(boat: Boat, party: { Player })
	if #party == 0 then
		return
	end
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if ok and typeof(code) == "string" then
		local ids = {}
		for _, p in party do
			table.insert(ids, p.UserId)
		end
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({ party = ids, boat = boat.model.Name })
		for attempt = 1, 3 do
			local sent = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, party, options)
			end)
			if sent then
				return
			end
			task.wait(attempt)
		end
	end
	-- could not reserve or send: everyone back on the dock
	for _, p in party do
		if p.Parent then
			putOnDock(boat, p)
			Remotes.notify(p, "The boat couldn't set out. Try again in a moment.", "Alarm")
		end
	end
end

local function castOff(boat: Boat)
	boat.castingOff = true
	local party = table.clone(boat.passengers)
	-- seat everyone and hold them in place (clients carry them along with the boat)
	for i, p in party do
		local root = rootOf(p)
		local seat = boat.seats[i]
		if root and seat then
			local character = p.Character :: Model
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Sit = true
			end
			local hip = if humanoid then humanoid.HipHeight else 2
			root.Anchored = true
			character:PivotTo(seat.WorldCFrame * CFrame.new(0, hip * 0.5 + 0.2, 0))
		end
	end
	boat.model:SetAttribute("CastOffAt", now())
	publish(boat)
	task.delay(Config.Lobby.CastOffSeconds, function()
		local stillHere = {}
		for _, p in party do
			if p.Parent then
				table.insert(stillHere, p)
			end
		end
		if RunService:IsStudio() then
			if onStudioLaunch then
				onStudioLaunch(stillHere)
			end
		else
			teleportParty(boat, stillHere)
		end
		-- the boat comes back to the dock for the next party
		task.wait(8)
		for _, p in stillHere do
			if p.Parent and p:GetAttribute("Boat") == boat.model.Name then
				p:SetAttribute("Boat", nil)
			end
		end
		resetBoat(boat)
	end)
end

local function step()
	local t = now()
	for _, boat in boats do
		if boat.castingOff then
			continue
		end
		-- who is standing in the boat right now
		local present: { [Player]: boolean } = {}
		for _, p in Players:GetPlayers() do
			local root = rootOf(p)
			if root and inside(boat.zone, root.Position) then
				present[p] = true
			end
		end
		-- keep those already aboard (in boarding order), drop anyone who left
		local kept: { Player } = {}
		for _, p in boat.passengers do
			if present[p] then
				table.insert(kept, p)
				present[p] = nil
			elseif p.Parent and p:GetAttribute("Boat") == boat.model.Name then
				p:SetAttribute("Boat", nil)
			end
		end
		-- the leader left: the next one aboard takes over; nobody left: the boat is free again
		if boat.leader and not table.find(kept, boat.leader) then
			boat.leader = kept[1]
			if boat.leader then
				Remotes.notify(boat.leader, "You lead this boat now.", nil)
			end
		end
		if #kept == 0 then
			boat.leader = nil
			boat.size = nil
		end
		-- newcomers: the first onto an empty boat creates the party; then up to its size
		for p in present do
			if not boat.leader then
				boat.leader = p
				boat.size = nil
				table.insert(kept, p)
				p:SetAttribute("Boat", boat.model.Name)
			elseif not boat.size then
				putOnDock(boat, p)
				Remotes.notify(p, `{boat.leader.DisplayName} is setting up this boat. Try another one, or wait a moment!`, nil)
			elseif #kept < boat.size then
				table.insert(kept, p)
				p:SetAttribute("Boat", boat.model.Name)
			else
				putOnDock(boat, p)
				Remotes.notify(p, `This party is full ({boat.size}). Try another boat!`, nil)
			end
		end
		boat.passengers = kept
		-- full: count down; not full (someone stepped off, or the size went up): wait
		local full = boat.size ~= nil and #kept >= boat.size
		if full and not boat.leavesAt then
			boat.leavesAt = t + Config.Lobby.FullCountdown
		elseif not full then
			boat.leavesAt = nil
		end
		publish(boat)
		if boat.leavesAt and t >= boat.leavesAt then
			castOff(boat)
		end
	end
end

-- Studio: what to do when a boat casts off (switch this server into the game)
function LobbyService.SetStudioLaunch(fn: (party: { Player }) -> ())
	onStudioLaunch = fn
end

function LobbyService.Stop()
	running = false
end

function LobbyService.Start()
	local lobby = Workspace:WaitForChild("Lobby")
	local folder = lobby:WaitForChild("Boats")
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local zone = model:FindFirstChild("Zone")
		local exit = model:FindFirstChild("Exit")
		if not (zone and zone:IsA("BasePart") and exit and exit:IsA("BasePart")) then
			warn(`[LobbyService] {model.Name} needs Zone and Exit parts`)
			continue
		end
		local seats: { Attachment } = {}
		local seatFolder = model:FindFirstChild("Seats")
		for i = 1, Config.Lobby.PartySize do
			local ref = seatFolder and seatFolder:FindFirstChild("Seat" .. i)
			if ref and ref:IsA("ObjectValue") and ref.Value and ref.Value:IsA("Attachment") then
				table.insert(seats, ref.Value)
			end
		end
		local boat: Boat = {
			model = model,
			zone = zone,
			exit = exit,
			seats = seats,
			passengers = {},
			leader = nil,
			size = nil,
			leavesAt = nil,
			castingOff = false,
		}
		table.insert(boats, boat)
		resetBoat(boat)
	end
	table.sort(boats, function(a, b)
		return (a.model:GetAttribute("Number") or 0) < (b.model:GetAttribute("Number") or 0)
	end)

	-- the leader picks (or changes) the party size
	Remotes.event("ChooseParty").OnServerEvent:Connect(function(player: Player, size: any)
		if typeof(size) ~= "number" or size ~= size then
			return
		end
		size = math.floor(size)
		if size < 1 or size > Config.Lobby.PartySize then
			return
		end
		for _, boat in boats do
			if boat.leader == player and not boat.castingOff then
				if size < #boat.passengers then
					Remotes.notify(player, `There are already {#boat.passengers} aboard.`, nil)
					return
				end
				boat.size = size
				boat.leavesAt = nil -- step() restarts the countdown if it's full
				publish(boat)
				return
			end
		end
	end)

	-- the big PLAY button: join a party that has room, or else take a free boat
	local lastQuick: { [Player]: number } = {}
	Remotes.event("QuickPlay").OnServerEvent:Connect(function(player: Player)
		local t = now()
		if t - (lastQuick[player] or 0) < 1 or player:GetAttribute("Boat") then
			return
		end
		lastQuick[player] = t
		local root = rootOf(player)
		if not root then
			return
		end
		local pick: Boat? = nil
		for _, boat in boats do
			if not boat.castingOff and boat.size and #boat.passengers < boat.size then
				pick = boat
				break
			end
		end
		if not pick then
			for _, boat in boats do
				if not boat.castingOff and #boat.passengers == 0 then
					pick = boat
					break
				end
			end
		end
		if not pick then
			Remotes.notify(player, "Every boat is busy. One will be back in a moment!", nil)
			return
		end
		-- step in: stand in the middle of the boat (step() does the rest)
		local zone = pick.zone
		root.CFrame = CFrame.new(zone.Position + Vector3.new(0, zone.Size.Y / 2 + 2.5, 0)) * pick.exit.CFrame.Rotation
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastQuick[player] = nil
	end)

	Remotes.event("LeaveBoat").OnServerEvent:Connect(function(player: Player)
		local name = player:GetAttribute("Boat")
		for _, boat in boats do
			if boat.model.Name == name and not boat.castingOff then
				putOnDock(boat, player)
				-- step() drops them from the list on its next pass
			end
		end
	end)
	-- a teleport that failed after it started: put them back on the dock
	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		for _, boat in boats do
			if table.find(boat.passengers, player) then
				putOnDock(boat, player)
				Remotes.notify(player, "The boat couldn't set out. Try again in a moment.", "Alarm")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, boat in boats do
			local i = table.find(boat.passengers, player)
			if i and not boat.castingOff then
				table.remove(boat.passengers, i)
				publish(boat)
			end
		end
	end)

	running = true
	task.spawn(function()
		while running do
			step()
			task.wait(0.2)
		end
	end)
end

return LobbyService
