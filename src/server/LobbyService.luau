--!strict
-- LobbyService: the harbor. Each boat in Workspace.Lobby.Boats takes a party of up to 4.
--
--   * Walk onto a boat to board. The first person aboard starts a countdown
--     (Config.Lobby.Countdown); anyone can still hop on or off until it ends.
--   * When it ends the boat casts off: the party is seated and the boat rows out
--     (every client animates it from the CastOffAt attribute). After CastOffSeconds the
--     server reserves a private server and teleports the party there together.
--   * In Studio there is no teleport: casting off calls onStudioLaunch instead, which
--     switches this server into the game.
--
-- Boat attributes (read by Client/LobbyController):
--   Count, Capacity, LeavesAt (server time or 0), CastOffAt (server time or 0), Passengers ("id,id")
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
	boat.model:SetAttribute("Capacity", Config.Lobby.PartySize)
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
		-- newcomers, until the boat is full
		for p in present do
			if #kept < Config.Lobby.PartySize then
				table.insert(kept, p)
				p:SetAttribute("Boat", boat.model.Name)
			else
				putOnDock(boat, p)
				Remotes.notify(p, `This boat is full ({Config.Lobby.PartySize}). Try another one!`, nil)
			end
		end
		boat.passengers = kept
		if #kept > 0 and not boat.leavesAt then
			boat.leavesAt = t + Config.Lobby.Countdown
		elseif #kept == 0 then
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
			leavesAt = nil,
			castingOff = false,
		}
		table.insert(boats, boat)
		resetBoat(boat)
	end
	table.sort(boats, function(a, b)
		return (a.model:GetAttribute("Number") or 0) < (b.model:GetAttribute("Number") or 0)
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
