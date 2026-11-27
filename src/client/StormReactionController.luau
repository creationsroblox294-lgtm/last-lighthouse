--!strict
-- StormReactionController: everyone's character reacts to the weather.
--   * wind storms: lean into the wind, swaying with the gusts
--   * rain / storms: hunch a little, head down
--   * cold (Whiteout, Freezing Rain, Hailstorm, or the player's "Chill"): arms pulled in, shivering
--   * hail / falling things: an arm up over the head
--   * lightning nearby: a quick flinch
-- It only bends joints on top of the normal animations (Motor6D.C0 offsets in the torso's
-- space), on every client for every character, so nothing is sent over the network.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StormState = require(Shared:WaitForChild("StormState"))
local StormTypes = require(Shared:WaitForChild("StormTypes"))
local Common = require(script.Parent:WaitForChild("StormFX"):WaitForChild("Common"))

local StormReactionController = {}

-- how windy / cold / "duck!" each storm is (0..1+); storms not listed only get the hunch
local WIND: { [string]: number } = {
	Ordinary = 0.35,
	SeaBreeze = 0.6,
	Squall = 0.7,
	Gale = 1,
	Hurricane = 1.2,
	SandstormSurge = 0.9,
	Maelstrom = 1,
	Waterspout = 0.8,
	EmberStorm = 0.5,
	Whiteout = 0.8,
	Deluge = 0.6,
	Thunderhead = 0.45,
	RollingThunder = 0.35,
	FreezingRain = 0.4,
}
local COLD: { [string]: number } = { Whiteout = 1, FreezingRain = 0.8, Hailstorm = 0.45 }
local COVER: { [string]: number } = { Hailstorm = 1, Starfall = 0.5, FishRain = 0.6, Deluge = 0.35 }

type Joint = { motor: Motor6D, base: CFrame }
type Rig = {
	character: Model,
	waist: Joint?,
	neck: Joint?,
	rShoulder: Joint?,
	lShoulder: Joint?,
	torso: BasePart,
	flinch: number,
	lean: Vector3, -- smoothed, in world space
	seed: number,
}

local rigs: { [Model]: Rig } = {}

local function joint(parent: Instance?, name: string): Joint?
	local m = parent and parent:FindFirstChild(name)
	if m and m:IsA("Motor6D") then
		return { motor = m, base = m.C0 }
	end
	return nil
end

local function track(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local rig: Rig
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local upper = character:WaitForChild("UpperTorso", 10) :: BasePart?
		local lower = character:WaitForChild("LowerTorso", 10) :: BasePart?
		local head = character:WaitForChild("Head", 10)
		if not upper or not lower or not head then
			return
		end
		rig = {
			character = character,
			waist = joint(upper, "Waist"),
			neck = joint(head, "Neck"),
			rShoulder = joint(character:FindFirstChild("RightUpperArm"), "RightShoulder"),
			lShoulder = joint(character:FindFirstChild("LeftUpperArm"), "LeftShoulder"),
			torso = upper,
			flinch = 0,
			lean = Vector3.zero,
			seed = math.random() * 100,
		}
	else
		local torso = character:WaitForChild("Torso", 10) :: BasePart?
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not torso or not root then
			return
		end
		rig = {
			character = character,
			waist = joint(root, "RootJoint"),
			neck = joint(torso, "Neck"),
			rShoulder = joint(torso, "Right Shoulder"),
			lShoulder = joint(torso, "Left Shoulder"),
			torso = torso,
			flinch = 0,
			lean = Vector3.zero,
			seed = math.random() * 100,
		}
	end
	rigs[character] = rig
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(Workspace) then
			rigs[character] = nil
		end
	end)
end

-- bend a joint by `r`, a rotation expressed in its parent part's space (so the same numbers
-- work for R6 and R15 joints, whatever their C0 axes are)
local function bend(j: Joint?, r: CFrame)
	if not j or not j.motor.Parent or not j.motor.Enabled then
		return
	end
	j.motor.C0 = CFrame.new(j.base.Position) * r * j.base.Rotation
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(track, character)
	end)
	if player.Character then
		task.spawn(track, player.Character)
	end
end

function StormReactionController.Start()
	local state = StormState.get()
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- lightning nearby makes people flinch
	Common.Flashed.Event:Connect(function(at: Vector3)
		for _, rig in rigs do
			local d = (rig.torso.Position - at).Magnitude
			if d < 160 then
				rig.flinch = math.max(rig.flinch, 1 - d / 200)
			end
		end
	end)

	-- the storm's strength eases in and out with the phases
	local level = 0
	RunService.RenderStepped:Connect(function(dt)
		local phase = state:GetAttribute("Phase")
		local id = state:GetAttribute("StormType")
		local sid = if typeof(id) == "string" then id else "Ordinary"
		local goal = if phase == "Storm" then 1 elseif phase == "Warning" then 0.35 else 0
		level += (goal - level) * (1 - math.exp(-dt / 3))

		local info = StormTypes.Get(sid)
		local blessed = (info :: any).Tier == "Blessed"
		local wind = (WIND[sid] or 0) * level
		local strength = Workspace:GetAttribute("WindStrength")
		if typeof(strength) == "number" then
			wind *= math.clamp(strength, 0.3, 1.6)
		end
		local coverGoal = (COVER[sid] or 0) * math.clamp((level - 0.5) * 2, 0, 1)
		local hunch = if blessed then 0 else level
		local now = os.clock()
		local gust = Common.gustAt(now)
		local windDir = Workspace:GetAttribute("WindDir")
		local dir: Vector3 = if typeof(windDir) == "Vector3" and windDir.Magnitude > 0
			then Vector3.new(windDir.X, 0, windDir.Z).Unit
			else (if gust.Magnitude > 0.05 then gust.Unit else Vector3.xAxis)
		local gustPower = 0.65 + 0.45 * math.clamp(gust.Magnitude, 0, 1.3)

		for character, rig in rigs do
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end
			local player = Players:GetPlayerFromCharacter(character)
			local chill = if player then tonumber(player:GetAttribute("Chill")) or 0 else 0
			local cold = math.max((COLD[sid] or 0) * level, chill)
			rig.flinch = math.max(0, rig.flinch - dt * 1.6)
			local f = Common.smooth(rig.flinch)

			-- lean into the wind (smoothed so gust changes flow)
			local leanGoal = -dir * wind * gustPower
			rig.lean = rig.lean:Lerp(leanGoal, 1 - math.exp(-dt * 2.5))
			local cf = rig.torso.CFrame
			local local_ = cf:VectorToObjectSpace(rig.lean)
			local flat = Vector3.new(local_.X, 0, local_.Z)
			local waist = CFrame.identity
			if flat.Magnitude > 0.01 then
				local axis = Vector3.yAxis:Cross(flat.Unit)
				waist = CFrame.fromAxisAngle(axis, math.rad(13) * math.min(flat.Magnitude, 1.4))
			end
			-- hunch / flinch forward, shiver
			local t = now + rig.seed
			local shiver = cold * math.rad(1.6) * math.noise(t * 22, rig.seed)
			waist = waist
				* CFrame.Angles(-math.rad(4) * hunch - math.rad(22) * f, 0, shiver)
			bend(rig.waist, waist)
			bend(
				rig.neck,
				CFrame.Angles(-math.rad(9) * hunch - math.rad(18) * f - math.rad(6) * cold, math.noise(t * 0.4, 3) * math.rad(6) * wind, 0)
			)

			-- arms: hugged in when cold or flinching, right arm over the head under hail
			local hug = math.max(cold * 0.9, f)
			local cover = coverGoal * (0.85 + 0.15 * math.noise(t * 0.7, 9))
			local flap = math.noise(t * 3.1, 5) * math.rad(4) * wind
			bend(
				rig.rShoulder,
				CFrame.Angles(math.rad(150) * cover + math.rad(38) * hug, math.rad(28) * hug, -math.rad(25) * cover + flap)
			)
			bend(rig.lShoulder, CFrame.Angles(math.rad(38) * hug, -math.rad(28) * hug, -flap))
		end
	end)
end

return StormReactionController
