--!strict
-- HollowController: the player's side of the Hollow.
--   * while the Hollow is out: nearby lights flicker, frost creeps over the screen edges
--     and a low hum rises the closer it gets
--   * when it grabs you: a "STRUGGLE!" prompt; every Space / tap / button press is sent
--   * flare flashes for everyone

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local HollowController = {}

local player = Players.LocalPlayer

local function findHollow(): Model?
	local runtime = Workspace:FindFirstChild("Runtime")
	local enemies = runtime and runtime:FindFirstChild("Enemies")
	local m = enemies and enemies:FindFirstChild("Hollow")
	return if m and m:IsA("Model") then m else nil
end

local function makeGui(): (ScreenGui, Frame, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HollowGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local frost = Instance.new("Frame")
	frost.Name = "Frost"
	frost.Size = UDim2.fromScale(1, 1)
	frost.BackgroundColor3 = Color3.fromRGB(200, 225, 255)
	frost.BackgroundTransparency = 1
	frost.BorderSizePixel = 0
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.82, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	grad.Parent = frost
	frost.Parent = gui
	local label = Instance.new("TextButton")
	label.Name = "Struggle"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.62)
	label.Size = UDim2.fromScale(0.5, 0.14)
	label.BackgroundColor3 = Color3.fromRGB(120, 20, 24)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "STRUGGLE! (tap fast)"
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, frost, label :: any
end

function HollowController.Start()
	local _gui, frost, struggle = makeGui()
	local struggleRemote = Remotes.event("Struggle")
	local hum = Instance.new("Sound")
	hum.Name = "HollowHum"
	hum.SoundId = "rbxassetid://96727522170625"
	hum.Looped = true
	hum.Volume = 0
	hum.Parent = Workspace.CurrentCamera or Workspace

	local lastPress = 0
	local function press()
		if player:GetAttribute("Grabbed") ~= true then
			return
		end
		local t = os.clock()
		if t - lastPress < 0.06 then
			return
		end
		lastPress = t
		struggleRemote:FireServer()
		struggle.Rotation = math.random(-6, 6)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.Touch then
			press()
		elseif not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			press()
		end
	end);
	(struggle :: any).Activated:Connect(press)

	player:GetAttributeChangedSignal("Grabbed"):Connect(function()
		struggle.Visible = player:GetAttribute("Grabbed") == true
	end)

	Remotes.event("FlareFired").OnClientEvent:Connect(function(at: Vector3)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.2, 1.2, 1.2)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 80, 50)
		p.Position = at
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 90, 60)
		l.Range = 60
		l.Brightness = 6
		l.Parent = p
		p.Parent = Workspace
		Debris:AddItem(p, 6)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = os.clock() - t0
			if not p.Parent then
				conn:Disconnect()
				return
			end
			p.Position = at + Vector3.new(0, k * 1.5, 0)
			l.Brightness = math.max(0, 6 - k)
		end)
	end)

	-- flicker nearby lights while it's near
	local flickered: { [Light]: number } = {}
	local lastScan = 0
	local cachedLights: { PointLight }? = nil
	local function mapLights(): { PointLight }
		if cachedLights then
			return cachedLights
		end
		local list = {}
		local map = Workspace:FindFirstChild("Map")
		for _, d in (if map then map:GetDescendants() else {}) do
			if d:IsA("PointLight") then
				table.insert(list, d)
			end
		end
		cachedLights = list
		task.delay(20, function()
			cachedLights = nil
		end)
		return list
	end
	RunService.RenderStepped:Connect(function()
		local hollow = findHollow()
		local cam = Workspace.CurrentCamera
		local near = 0
		if hollow and cam then
			local body = hollow:FindFirstChild("Body", true)
			if body and body:IsA("BasePart") then
				local d = (body.Position - cam.CFrame.Position).Magnitude
				near = math.clamp(1 - (d - 15) / 90, 0, 1)
			end
		end
		frost.BackgroundTransparency = 1 - near * 0.55
		hum.Volume = near * 0.8
		if near > 0 and not hum.IsPlaying then
			hum:Play()
		elseif near <= 0 and hum.IsPlaying then
			hum:Stop()
		end
		if near > 0.3 and hollow and os.clock() - lastScan > 1 then
			lastScan = os.clock()
			local body = hollow:FindFirstChild("Body", true)
			if body and body:IsA("BasePart") then
				for _, l in mapLights() do
					local holder = l.Parent
					if holder and holder:IsA("BasePart") and flickered[l] == nil and (holder.Position - body.Position).Magnitude < 45 then
						flickered[l] = l.Brightness
					end
				end
			end
		end
		for l, base in flickered do
			if near > 0.3 and l.Parent then
				l.Brightness = base * (if math.random() < 0.15 then 0.1 else 1)
			else
				l.Brightness = base
				flickered[l] = nil
			end
		end
	end)
end

return HollowController
