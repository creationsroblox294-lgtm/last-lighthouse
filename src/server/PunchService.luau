--!strict
-- PunchService: fists. With nothing in your hands, click / tap (PunchController) to punch.
--   * Creatures in front of you take PunchDamage (fog crawlers, the drowned, gulls...).
--   * The Hollow counts a punch as a hit, like a harpoon.
--   * A tree in front of you shakes; every PunchesPerTree punches knocks off a piece of wood.
-- The server checks range, facing and the cooldown; the client only says "I punched".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local HollowService = require(script.Parent:WaitForChild("HollowService"))
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))

local C = Config.Combat
local PunchService = {}

local lastPunch: { [Player]: number } = {}
local hitRemote: RemoteEvent

local function treeInFront(root: BasePart): (Model?, BasePart?)
	local map = Workspace:FindFirstChild("Map")
	local grove = map and map:FindFirstChild("PineGrove")
	if not grove then
		return nil, nil
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		return nil, nil
	end
	look = look.Unit
	local best, bestTrunk, bestD = nil, nil, math.huge
	for _, tree in grove:GetChildren() do
		local trunk = tree:FindFirstChild("Trunk")
		if tree:IsA("Model") and trunk and trunk:IsA("BasePart") and tree:GetAttribute("Felled") ~= true then
			local flat = Vector3.new(trunk.Position.X - root.Position.X, 0, trunk.Position.Z - root.Position.Z)
			-- distance to the trunk's surface, not its centre
			local d = flat.Magnitude - math.max(trunk.Size.X, trunk.Size.Z) / 2
			local low = trunk.Position.Y - trunk.Size.Y / 2
			if d < C.PunchRange - 2 and d < bestD and root.Position.Y > low - 4 and root.Position.Y < low + 10
				and (flat.Magnitude < 1 or flat.Unit:Dot(look) > 0.35) then
				best, bestTrunk, bestD = tree, trunk, d
			end
		end
	end
	return best, bestTrunk
end

local function punch(player: Player)
	local t = os.clock()
	-- a little slack under the client's cooldown for network jitter
	if t - (lastPunch[player] or 0) < C.PunchCooldown * 0.8 then
		return
	end
	lastPunch[player] = t
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return
	end
	if character:FindFirstChildOfClass("Tool") or player:GetAttribute("Grabbed") == true then
		return
	end
	local look = root.CFrame.LookVector

	-- 1) creatures
	local target = EnemyService.FindTarget(root.Position, look, C.PunchRange, C.PunchConeDegrees)
	if target then
		target:TakeDamage(C.PunchDamage)
		local troot = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
		local at = if troot and troot:IsA("BasePart") then troot.Position else root.Position + look * 3
		hitRemote:FireAllClients(at, "Creature", target.Parent)
		return
	end
	-- 2) the Hollow (punching it is as good as a harpoon hit, but you have to be close)
	if HollowService.TryHarpoon(root.Position, look, C.PunchRange + 3, C.PunchConeDegrees) then
		hitRemote:FireAllClients(root.Position + look * 4, "Creature", nil)
		return
	end
	-- 3) trees
	local tree, trunk = treeInFront(root)
	if tree and trunk then
		local result = ResourceService.HitTree(player, tree)
		if result then
			local at = Vector3.new(trunk.Position.X, root.Position.Y + 0.5, trunk.Position.Z)
			at -= (at - root.Position).Unit * (trunk.Size.X / 2)
			hitRemote:FireAllClients(at, if result == "wood" then "Wood" else "Tree", tree)
		end
	end
end

function PunchService.Start()
	hitRemote = Remotes.event("PunchHit")
	Remotes.event("Punch").OnServerEvent:Connect(punch)
	Players.PlayerRemoving:Connect(function(player)
		lastPunch[player] = nil
	end)
end

return PunchService
