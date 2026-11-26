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
		releaseFocus(player)
		done[player] = nil
	end)
end

return IntroService
