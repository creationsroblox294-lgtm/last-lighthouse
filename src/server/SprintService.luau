--!strict
-- SprintService: hold Shift to sprint. The client only says "I want to sprint"; the server
-- owns the stamina (player attribute "Stamina", 0-100) and the speed (Movement).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Movement = require(script.Parent:WaitForChild("Movement"))

local SprintService = {}

type State = { wants: boolean, stamina: number, restAt: number, winded: boolean, shown: number }
local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { wants = false, stamina = Config.Sprint.MaxStamina, restAt = 0, winded = false, shown = -1 }
		states[player] = s
	end
	return s
end

function SprintService.Start()
	local S = Config.Sprint
	Remotes.event("Sprint").OnServerEvent:Connect(function(player: Player, wants: any)
		if typeof(wants) ~= "boolean" then
			return
		end
		stateOf(player).wants = wants
	end)

	Players.PlayerAdded:Connect(function(player)
		stateOf(player)
		player.CharacterAdded:Connect(function()
			local s = stateOf(player)
			s.stamina = S.MaxStamina
			s.winded = false
			Movement.SetSprinting(player, false)
		end)
	end)
	for _, player in Players:GetPlayers() do
		stateOf(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		for player, s in states do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
			local able = humanoid ~= nil and Movement.CanSprint(humanoid) and not player:GetAttribute("Latched")
			if s.winded and s.stamina >= S.MinToStart then
				s.winded = false
			end
			local sprint = s.wants and able and moving and not s.winded and s.stamina > 0
			if sprint then
				s.stamina = math.max(0, s.stamina - S.DrainPerSecond * step)
				s.restAt = now + S.RegenDelay
				if s.stamina <= 0 then
					s.winded = true
					sprint = false
				end
			elseif now >= s.restAt then
				s.stamina = math.min(S.MaxStamina, s.stamina + S.RegenPerSecond * step)
			end
			Movement.SetSprinting(player, sprint)
			local shown = math.floor(s.stamina + 0.5)
			if shown ~= s.shown then
				s.shown = shown
				player:SetAttribute("Stamina", shown)
			end
		end
	end)
end

return SprintService
