--!strict
-- Names every RemoteEvent in one place. The server creates them; clients wait for them.
-- Add new remotes to EVENT_NAMES.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENT_NAMES = {
	"PhaseChanged", -- server -> client: (info: Types.PhaseInfo)
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

return Remotes
