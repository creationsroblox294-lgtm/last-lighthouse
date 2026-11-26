--!strict
-- IntroService: after the intro cutscene a player wakes up on the beach where the story left
-- them (Config.World.IntroBeach), facing the lighthouse. Only once per player per server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))

local IntroService = {}
local done: { [Player]: boolean } = {}

function IntroService.Start()
	Remotes.event("IntroDone").OnServerEvent:Connect(function(player: Player)
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
		local spot = beach + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Include
		ray.FilterDescendantsInstances = { Workspace.Terrain }
		local hit = Workspace:Raycast(spot + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), ray)
		spot = (if hit then hit.Position else spot) + Vector3.new(0, 3, 0)
		local tower = Config.World.TowerCenter
		character:PivotTo(CFrame.lookAt(spot, Vector3.new(tower.X, spot.Y, tower.Z)))
		Remotes.notify(player, "You wash up on a strange island. Find the lighthouse.", "Good")
	end)
	Players.PlayerRemoving:Connect(function(player)
		done[player] = nil
	end)
end

return IntroService
