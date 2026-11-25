--!strict
-- Ragdoll: on death, a character's joints go limp instead of the body breaking apart.
-- Every Motor6D is swapped for a BallSocketConstraint with human-like limits, so the body
-- folds, slumps and tumbles with real physics. Works for R15 and R6 characters.

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
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local part0, part1 = motor.Part0 :: BasePart, motor.Part1 :: BasePart
			if part0.Name == "HumanoidRootPart" or part1.Name == "HumanoidRootPart" then
				continue -- keep the root attached to the lower torso
			end
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = motor.C0
			a0.Parent = part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = motor.C1
			a1.Parent = part1
			local joint = Instance.new("BallSocketConstraint")
			joint.Name = "RagdollJoint"
			joint.Attachment0 = a0
			joint.Attachment1 = a1
			local limit = LIMITS[motor.Name] or { cone = 45, twist = 20 }
			joint.LimitsEnabled = true
			joint.UpperAngle = limit.cone
			joint.TwistLimitsEnabled = true
			joint.TwistLowerAngle = -limit.twist
			joint.TwistUpperAngle = limit.twist
			joint.Restitution = 0
			joint.Parent = part1
			motor.Enabled = false
		end
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
