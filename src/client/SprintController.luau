--!strict
-- SprintController: hold Shift (or press the left stick / tap the Sprint button) to run.
-- The server decides the speed and stamina; this sends the intent, widens the camera a
-- little while you run, and shows a stamina bar when it isn't full.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UISkin = require(script.Parent:WaitForChild("UISkin"))

local SprintController = {}
local player = Players.LocalPlayer

local function makeBar(): (Frame, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SprintGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -96)
	back.Size = UDim2.fromOffset(240, 22)
	back.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	back.BackgroundTransparency = 0.35
	back.BorderSizePixel = 0
	back.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 230, 140)
	fill.BorderSizePixel = 0
	local c2 = corner:Clone()
	c2.Parent = fill
	fill.Parent = back
	UISkin.bar(back, fill)
	back.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return back, fill
end

function SprintController.Start()
	local remote = Remotes.event("Sprint")
	local keys = 0 -- shift keys held
	local toggled = false -- gamepad / touch toggle
	local sent = false

	local function update()
		local wants = keys > 0 or toggled
		if wants ~= sent then
			sent = wants
			remote:FireServer(wants)
		end
	end

	ContextActionService:BindAction("Sprint", function(_name, state, input)
		local kc = input.KeyCode
		if kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.RightShift then
			if state == Enum.UserInputState.Begin then
				keys += 1
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				keys = math.max(0, keys - 1)
			end
		elseif state == Enum.UserInputState.Begin then
			toggled = not toggled
		end
		update()
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Run")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -150))

	player.CharacterAdded:Connect(function()
		keys, toggled = 0, false
		update()
	end)

	local back, fill = makeBar()
	local max = Config.Sprint.MaxStamina
	local fov = 70
	RunService.RenderStepped:Connect(function(dt)
		local stamina = player:GetAttribute("Stamina")
		local frac = if typeof(stamina) == "number" then stamina / max else 1
		back.Visible = frac < 0.995
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(235, 90, 70):Lerp(Color3.fromRGB(120, 230, 140), math.clamp(frac * 1.6, 0, 1))
		if toggled and frac <= 0 then
			toggled = false
			update()
		end

		-- a touch wider view while running (only when the normal camera is in charge)
		local camera = Workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Custom then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local v = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero
			local running = player:GetAttribute("Sprinting") == true and Vector3.new(v.X, 0, v.Z).Magnitude > 8
			local goal = if running then 78 else 70
			fov += (goal - fov) * math.min(1, dt * 6)
			camera.FieldOfView = fov
		else
			fov = 70
		end
	end)
end

return SprintController
