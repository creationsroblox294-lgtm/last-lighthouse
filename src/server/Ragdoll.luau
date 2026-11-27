--!strict
-- Ragdoll: on death, a character's joints go limp instead of the body breaking apart.
-- Every joint is swapped for a BallSocketConstraint with human-like limits, so the body
-- folds, slumps and tumbles with real physics. Works for R15 and R6 characters, with either
-- classic Motor6D joints or the newer AnimationConstraint joints some avatars use.

local Ragdoll = {}

-- Joint limits (degrees): how far each joint may bend / twist
local LIMITS: { [string]: { cone: number, twist: number } } = {
	Neck = { cone = 35, twist = 30 },
	Waist = { cone = 25, twist = 25 },
	LeftShoulder = { cone = 85, twist = 60 }, RightShoulder = { cone = 85, twist = 60 },
	LeftElbow = { cone = 70, twist = 5 }, RightElbow = { cone = 70, twist = 5 },
	LeftWrist = { cone = 30, twist = 10 }, RightWrist = { cone = 30, twist = 10 },
	LeftHip = { cone = 60, twist = 20 }, RightHip = { cone = 60, twist = 20 },
	LeftKnee = { cone = 75, twist = 5 }, RightKnee = { cone = 75, twist = 5 },
	LeftAnkle = { cone = 25, twist = 10 }, RightAnkle = { cone = 25, twist = 10 },
}

function Ragdoll.apply(character: Model, impulse: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end
	for _, joint in character:GetDescendants() do
		-- where each joint is: its two parts and the joint frame in each of them
		local part0: BasePart?, part1: BasePart?
		local a0: Attachment?, a1: Attachment?
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			part0, part1 = joint.Part0, joint.Part1
		elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
			a0, a1 = joint.Attachment0, joint.Attachment1
			local p0, p1 = (a0 :: Attachment).Parent, (a1 :: Attachment).Parent
			if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
				part0, part1 = p0, p1
			end
		end
		if not part0 or not part1 then
			continue
		end
		if part0.Name == "HumanoidRootPart" or part1.Name == "HumanoidRootPart" then
			-- keep the root attached to the lower torso (newer avatars can let go of their
			-- root joint on death, so pin it with a weld as well)
			if joint:IsA("AnimationConstraint") then
				local pin = Instance.new("WeldConstraint")
				pin.Name = "RagdollRootPin"
				pin.Part0 = part0
				pin.Part1 = part1
				pin.Parent = part0
			end
			continue
		end
		if joint:IsA("Motor6D") then
			local m0 = Instance.new("Attachment")
			m0.Name = "RagdollA0"
			m0.CFrame = joint.C0
			m0.Parent = part0
			local m1 = Instance.new("Attachment")
			m1.Name = "RagdollA1"
			m1.CFrame = joint.C1
			m1.Parent = part1
			a0, a1 = m0, m1
		end
		local socket = Instance.new("BallSocketConstraint")
		socket.Name = "RagdollJoint"
		socket.Attachment0 = a0
		socket.Attachment1 = a1
		local limit = LIMITS[joint.Name] or { cone = 45, twist = 20 }
		socket.LimitsEnabled = true
		socket.UpperAngle = limit.cone
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -limit.twist
		socket.TwistUpperAngle = limit.twist
		socket.Restitution = 0
		socket.Parent = part1
		;(joint :: any).Enabled = false
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "HumanoidRootPart" then
				part.CanCollide = false
			elseif part.Parent == character then
				part.CanCollide = true
			end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if impulse and root and root:IsA("BasePart") then
		root:ApplyImpulse(impulse * root.AssemblyMass)
	end
end

-- Call once per character when it spawns
function Ragdoll.setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Connect(function()
		Ragdoll.apply(character, Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
	end)
end

return Ragdoll
