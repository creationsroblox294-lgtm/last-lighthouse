--!strict
-- Names every RemoteEvent in one place. The server creates them; clients wait for them.
-- Add new remotes to EVENT_NAMES. The server validates everything a client sends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENT_NAMES = {
	"PhaseChanged", -- server -> client: (info: Types.PhaseInfo)
	"Notify", -- server -> client: (text: string, kind: string?)
	"DropItem", -- client -> server: (kind: string?) drop one item from the backpack
	"Gained", -- server -> client: (kind: string, amount: number, from: Vector3?) backpack pop-up
	"AimBeam", -- client -> server: (angleDegrees: number)
	"ReleaseBeam", -- client -> server: ()
	"Struggle", -- client -> server: () while held by the Hollow
	"FlareFired", -- server -> client: (position: Vector3, shooter: Player) the flare shot
	"LeaveBoat", -- client -> server: () step off the lobby boat you're in
	"ChooseParty", -- client -> server: (size: number) the boat's leader picks the party size (1-4)
	"AnimalWarn", -- server -> client: (kind: string, tree: Model, landAt: Vector3, seconds: number)
	"Punch", -- client -> server: () throw a punch
	"PunchHit", -- server -> client: (position: Vector3, kind: string, target: Instance?)
	"IntroDone", -- client -> server: () the intro cutscene finished or was skipped
	"Sprint", -- client -> server: (wants: boolean) holding the sprint key
	"StormEvent", -- server -> client: (kind: string, data: any) storm-type moments (meteors...)
	"StormAct", -- client -> server: (kind: string, data: any) a player reacting to a storm (validated per storm)
	"Craft", -- client -> server: (recipeId: string) craft at the crafting table
	"Crafted", -- server -> client: (crafter: Player, recipeId: string) someone crafted something
	"KeeperBuy", -- client -> server: (id: string) buy a perk tier, lantern or title at the Keeper's Locker
	"KeeperEquip", -- client -> server: (slot: "Lantern" | "Title", id: string) wear something you own
	"Earned", -- server -> client: (amount: number, reason: string) Brass just paid to you
	"RedeemCode", -- client -> server: (code: string) redeem a code for Brass
	"HitConfirm", -- server -> attacker: (at: Vector3, target: Instance?, damage: number, killed: boolean, weapon: string) your hit landed
	"QuickPlay", -- client -> server: () the big PLAY button: put me on the best boat
}

local Remotes = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for _, name in EVENT_NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	error(`Unknown RemoteEvent: {name}`)
end

-- Server helper: message for one player (or everyone when player is nil)
function Remotes.notify(player: Player?, text: string, kind: string?)
	local remote = Remotes.event("Notify")
	if player then
		remote:FireClient(player, text, kind)
	else
		remote:FireAllClients(text, kind)
	end
end

return Remotes
