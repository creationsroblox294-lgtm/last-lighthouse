--!strict
-- TreeAnimalController: the client side of the tree animals.
--   AnimalWarn  -> the tree's leaves rustle and a red ring marks where it will land.
--   Latched     -> (player attribute) shaky camera, red edges, a "SHAKE IT OFF" button;
--                  tapping Space / the screen fires the Struggle remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local TreeAnimalController = {}
local player = Players.LocalPlayer

local NAMES: { [string]: string } = { Snake = "SNAKE", Spider = "SPIDER", Bat = "BAT" }

local function rustle(tree: Instance, seconds: number)
	local leaves: { { part: BasePart, cf: CFrame } } = {}
	for _, p in tree:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Leaves" then
			table.insert(leaves, { part = p, cf = p.CFrame })
		end
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > seconds then
			conn:Disconnect()
			for _, l in leaves do
				l.part.CFrame = l.cf
			end
			return
		end
		local a = 0.06 * (1 + t)
		for i, l in leaves do
			l.part.CFrame = l.cf * CFrame.Angles(math.sin(t * 30 + i) * a * 0.5, math.sin(t * 24 + i * 2) * a, math.cos(t * 27 + i) * a * 0.5)
		end
	end)
end

local function ring(at: Vector3, seconds: number)
	local p = Instance.new("Part")
	p.Name = "AnimalWarning"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 60, 40)
	p.Transparency = 0.75
	p.Size = Vector3.new(0.15, 1, 1)
	p.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 7, 7),
		Transparency = 0.35,
	}):Play()
	task.delay(seconds + 0.3, function()
		p:Destroy()
	end)
end

local function makeGui(): (Frame, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TreeAnimalGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Size = UDim2.fromScale(1, 1)
	edge.BackgroundColor3 = Color3.fromRGB(150, 10, 10)
	edge.BorderSizePixel = 0
	edge.Visible = false
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	grad.Parent = edge
	edge.Parent = gui
	local button = Instance.new("TextButton")
	button.Name = "Shake"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.66)
	button.Size = UDim2.fromScale(0.46, 0.12)
	button.BackgroundColor3 = Color3.fromRGB(40, 90, 30)
	button.BackgroundTransparency = 0.1
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 230, 120)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return edge, button
end

function TreeAnimalController.Start()
	local edge, button = makeGui()
	local struggle = Remotes.event("Struggle")

	Remotes.event("AnimalWarn").OnClientEvent:Connect(function(_kind: string, tree: Instance?, at: Vector3, seconds: number)
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - at).Magnitude > 120 then
			return
		end
		if tree then
			rustle(tree, seconds)
		end
		ring(at, seconds)
	end)

	local function latchedKind(): string?
		local k = player:GetAttribute("Latched")
		return if typeof(k) == "string" then k else nil
	end

	local function refresh()
		local kind = latchedKind()
		edge.Visible = kind ~= nil
		button.Visible = kind ~= nil
		if kind then
			local left = player:GetAttribute("LatchShakes")
			button.Text = `SHAKE OFF THE {NAMES[kind] or "ANIMAL"}! ({if typeof(left) == "number" then left else "?"})`
		end
	end
	player:GetAttributeChangedSignal("Latched"):Connect(refresh)
	player:GetAttributeChangedSignal("LatchShakes"):Connect(refresh)

	local last = 0
	local function press()
		if not latchedKind() then
			return
		end
		local t = os.clock()
		if t - last < 0.07 then
			return
		end
		last = t
		struggle:FireServer()
		button.Rotation = math.random(-8, 8)
	end
	UserInputService.InputBegan:Connect(function(input)
		if not latchedKind() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			press()
		end
	end)
	button.Activated:Connect(press)

	-- shaky camera while something is on you
	RunService:BindToRenderStep("TreeAnimalShake", Enum.RenderPriority.Camera.Value + 1, function()
		if not latchedKind() then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local t = os.clock()
			camera.CFrame *= CFrame.Angles(math.sin(t * 37) * 0.012, math.sin(t * 29) * 0.016, math.sin(t * 23) * 0.01)
		end
		edge.BackgroundTransparency = 0.2 + math.sin(os.clock() * 8) * 0.15
	end)
end

return TreeAnimalController
