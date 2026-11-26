--!strict
-- PunchController: with nothing in your hands, click (mouse), tap the Punch button (touch)
-- or press R2 (gamepad) to throw a punch. Alternates left/right punch animations and tells
-- the server; PunchHit shows the impact (sparks on creatures, a shake + wood chips on trees).

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PunchController = {}
local player = Players.LocalPlayer
local C = Config.Combat

local tracks: { AnimationTrack } = {}
local nextTrack = 1
local lastPunch = 0

local function loadTracks(character: Model)
	table.clear(tracks)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local animator = humanoid and humanoid:WaitForChild("Animator", 10) :: Animator?
	if not animator then
		return
	end
	for _, id in C.PunchAnimations do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			table.insert(tracks, track)
		end
	end
end

local function canPunch(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 then
		return false
	end
	if character:FindFirstChildOfClass("Tool") then
		return false -- holding the harpoon / hammer / flare: those tools use the click
	end
	if player:GetAttribute("Grabbed") == true or player:GetAttribute("Latched") ~= nil then
		return false -- the click is used to struggle / shake off
	end
	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Climbing and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Seated
end

local function punch()
	local t = os.clock()
	if t - lastPunch < C.PunchCooldown or not canPunch() then
		return
	end
	lastPunch = t
	local track = tracks[nextTrack]
	if track then
		track:Play(0.05, 1, 1.3)
		nextTrack = nextTrack % #tracks + 1
	end
	Remotes.event("Punch"):FireServer()
end

local function burst(at: Vector3, color: Color3, count: number, size: number)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Size = Vector3.new(size, size, size)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		p.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(6, 16), math.random(-12, 12))
		p.Parent = Workspace
		Debris:AddItem(p, 0.8)
	end
end

local function flash(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 240, 210)
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.Position = at
	p.Parent = Workspace
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / 0.15
		if k >= 1 then
			conn:Disconnect()
			p:Destroy()
			return
		end
		p.Size = Vector3.one * (0.6 + k * 2.4)
		p.Transparency = k
	end)
end

local function shakeTree(tree: Instance)
	local parts: { { part: BasePart, cf: CFrame } } = {}
	for _, d in tree:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Leaves" then
			table.insert(parts, { part = d, cf = d.CFrame })
		end
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.35 then
			conn:Disconnect()
			for _, l in parts do
				l.part.CFrame = l.cf
			end
			return
		end
		local a = 0.05 * (1 - t / 0.35)
		for i, l in parts do
			l.part.CFrame = l.cf * CFrame.Angles(math.sin(t * 50 + i) * a, 0, math.cos(t * 44 + i) * a)
		end
	end)
end

function PunchController.Start()
	player.CharacterAdded:Connect(loadTracks)
	if player.Character then
		task.spawn(loadTracks, player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			punch()
		end
	end)
	-- touch / gamepad: an on-screen Punch button and R2
	ContextActionService:BindAction("Punch", function(_, state)
		if state == Enum.UserInputState.Begin then
			punch()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("Punch", "Punch")
	ContextActionService:SetPosition("Punch", UDim2.new(1, -170, 1, -150))

	Remotes.event("PunchHit").OnClientEvent:Connect(function(at: Vector3, kind: string, target: Instance?)
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - at).Magnitude > 150 then
			return
		end
		flash(at)
		if kind == "Tree" or kind == "Wood" then
			burst(at, Color3.fromRGB(150, 105, 62), if kind == "Wood" then 10 else 4, 0.35)
			if target then
				shakeTree(target)
			end
		else
			burst(at, Color3.fromRGB(230, 230, 240), 5, 0.25)
		end
	end)
end

return PunchController
