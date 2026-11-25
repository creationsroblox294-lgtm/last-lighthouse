--!strict
-- Names every RemoteEvent in one place. The server creates them; clients wait for them.
-- Add new remotes to EVENT_NAMES. The server validates everything a client sends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENT_NAMES = {
	"PhaseChanged", -- server -> client: (info: Types.PhaseInfo)
	"Notify", -- server -> client: (text: string, kind: string?)
	"DropItem", -- client -> server: ()
	"AimBeam", -- client -> server: (angleDegrees: number)
	"ReleaseBeam", -- client -> server: ()
	"Struggle", -- client -> server: () while held by the Hollow
	"FlareFired", -- server -> client: (position: Vector3) flash effect
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
