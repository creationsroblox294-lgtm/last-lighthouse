--!strict
-- LadderController: makes the lighthouse ladders smooth to use.
-- Roblox climbing gets stuck at the top of a ladder and is fiddly to get onto from above, so:
--   * Climbing up: when you reach the top while still moving, a short hop puts you on the floor.
--   * Going down: walk into the opening from the floor above and you grab the ladder facing it;
--     then hold back (S / down on the stick) to climb down.
-- Ladders are the invisible TrussParts named "ClimbSurface" under Workspace.Map.
-- Each truss's -Z side is where you climb; +Z points into the room you step off into.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LadderController = {}

local HOP_SECONDS = 0.28
local busyUntil = 0

local function ladders(): { BasePart }
	local list = {}
	local map = Workspace:FindFirstChild("Map")
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("TrussPart") and d.Name == "ClimbSurface" then
				table.insert(list, d)
			end
		end
	end
	return list
end

-- Smoothly move the root to a target with a little arc
local function hop(root: BasePart, humanoid: Humanoid, target: CFrame, onDone: (() -> ())?)
	busyUntil = os.clock() + HOP_SECONDS + 0.15
	local start = root.CFrame
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local a = math.min(1, (os.clock() - t0) / HOP_SECONDS)
		local eased = a * a * (3 - 2 * a)
		local cf = start:Lerp(target, eased) + Vector3.new(0, math.sin(math.pi * a) * 1.2, 0)
		root.CFrame = cf
		root.AssemblyLinearVelocity = Vector3.zero
		if a >= 1 then
			conn:Disconnect()
			if onDone then
				onDone()
			end
		end
	end)
end

function LadderController.Start()
	local player = Players.LocalPlayer
	-- ladders stream in and out (StreamingEnabled), so refresh the list now and then
	local list = ladders()
	task.spawn(function()
		while true do
			task.wait(1)
			list = ladders()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if os.clock() < busyUntil then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local state = humanoid:GetState()
		for _, truss in list do
			local localPos = truss.CFrame:PointToObjectSpace(root.Position)
			local halfY = truss.Size.Y / 2
			if math.abs(localPos.X) > 2.2 then
				continue
			end
			-- Climbing up and reached the top: step off onto the floor
			if state == Enum.HumanoidStateType.Climbing and moving and localPos.Y > halfY - 3.4 and localPos.Z < 0.5 and localPos.Z > -4 then
				local target = truss.CFrame * CFrame.new(0, halfY + 3.0, 3.4)
				local facing = CFrame.lookAt(target.Position, target.Position + (-truss.CFrame.LookVector * Vector3.new(1, 0, 1)))
				hop(root, humanoid, facing, function()
					humanoid:ChangeState(Enum.HumanoidStateType.Running)
				end)
				return
			end
			-- Walking into the opening from above: grab the ladder facing it
			if state ~= Enum.HumanoidStateType.Climbing and moving and localPos.Y > halfY + 1 and localPos.Y < halfY + 4.5
				and localPos.Z > -0.5 and localPos.Z < 4 then
				-- walking toward the climb side (the truss's LookVector) means stepping into the opening
				if humanoid.MoveDirection:Dot(truss.CFrame.LookVector) > 0.3 then
					local target = truss.CFrame * CFrame.new(0, halfY - 3.2, -2.1)
					local facing = CFrame.lookAt(target.Position, Vector3.new(truss.Position.X, target.Position.Y, truss.Position.Z))
					hop(root, humanoid, facing, function()
						humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
					end)
					return
				end
			end
		end
	end)
end

return LadderController
