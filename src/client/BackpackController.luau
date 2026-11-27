--!strict
-- BackpackController: the backpack button (bottom right), the backpack window (B / click)
-- and the pop-up when you gain something: a tiny 3D piece of it pops out of where it came
-- from (the tree, the pool, the crate...), arcs into your back, then its icon and "+1"
-- float up beside the backpack button.
-- The server owns the contents: player attributes Pack_<Kind>, PackTotal, PackSize.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UISkin = require(script.Parent:WaitForChild("UISkin"))

local BackpackController = {}
local player = Players.LocalPlayer
local UI = Config.UI

-- what each kind looks like: its icon, its name and its tiny 3D piece
local KINDS = { "Wood", "Scrap", "Oil", "RawFish", "Fish", "WhaleOil" }
local INFO: { [string]: { icon: string, name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType? } } = {
	Wood = { icon = UI.Items.Wood, name = "Wood", size = Vector3.new(0.45, 1.3, 0.45), color = Color3.fromRGB(150, 104, 62), material = Enum.Material.Wood, shape = Enum.PartType.Cylinder },
	Scrap = { icon = UI.Items.Scrap, name = "Scrap", size = Vector3.new(0.8, 0.45, 0.6), color = Color3.fromRGB(140, 120, 104), material = Enum.Material.CorrodedMetal },
	Oil = { icon = UI.Items.Oil, name = "Oil", size = Vector3.new(0.9, 0.7, 0.7), color = Color3.fromRGB(170, 40, 34), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
	RawFish = { icon = UI.Items.RawFish, name = "Raw fish", size = Vector3.new(0.35, 0.5, 1.1), color = Color3.fromRGB(160, 182, 196), material = Enum.Material.SmoothPlastic },
	Fish = { icon = UI.Items.CookedFish, name = "Cooked fish", size = Vector3.new(0.35, 0.5, 1.1), color = Color3.fromRGB(205, 130, 60), material = Enum.Material.SmoothPlastic },
	WhaleOil = { icon = UI.Items.WhaleOil, name = "Whale oil", size = Vector3.new(0.6, 0.8, 0.6), color = Color3.fromRGB(255, 205, 90), material = Enum.Material.Neon },
}

local function ease(t: number): number
	return 1 - (1 - t) * (1 - t)
end

function BackpackController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BackpackGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	------------------------------------------------------------------ the button
	local button = Instance.new("ImageButton")
	button.Name = "BackpackButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = if touch then UDim2.new(1, -16, 1, -170) else UDim2.new(1, -20, 1, -24)
	button.Size = UDim2.fromOffset(92, 92)
	button.BackgroundTransparency = 1
	button.Image = UI.RoundButton
	button.AutoButtonColor = false
	button.Parent = gui
	local bag = Instance.new("ImageLabel")
	bag.Name = "Bag"
	bag.BackgroundTransparency = 1
	bag.Image = UI.Items.Backpack
	bag.AnchorPoint = Vector2.new(0.5, 0.5)
	bag.Position = UDim2.fromScale(0.5, 0.47)
	bag.Size = UDim2.fromScale(0.72, 0.72)
	bag.ScaleType = Enum.ScaleType.Fit
	bag.Parent = button
	local bagScale = Instance.new("UIScale")
	bagScale.Parent = bag
	-- the count, on a small brass plate under the bag
	local plate = Instance.new("ImageLabel")
	plate.BackgroundTransparency = 1
	plate.Image = UI.PillButton
	plate.ScaleType = Enum.ScaleType.Fit
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.new(0.5, 0, 1, -4)
	plate.Size = UDim2.fromOffset(70, 26)
	plate.ZIndex = 2
	plate.Parent = button
	local countLabel = Instance.new("TextLabel")
	countLabel.BackgroundTransparency = 1
	countLabel.Size = UDim2.fromScale(1, 1)
	countLabel.Font = Enum.Font.GothamBlack
	countLabel.TextScaled = true
	countLabel.TextColor3 = Color3.fromRGB(40, 26, 10)
	countLabel.Text = "0/20"
	countLabel.ZIndex = 3
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = countLabel
	countLabel.Parent = plate
	local keyHint = Instance.new("TextLabel")
	keyHint.BackgroundTransparency = 1
	keyHint.AnchorPoint = Vector2.new(0.5, 1)
	keyHint.Position = UDim2.new(0.5, 0, 0, -2)
	keyHint.Size = UDim2.fromOffset(90, 16)
	keyHint.Font = Enum.Font.GothamBold
	keyHint.TextSize = 12
	keyHint.TextColor3 = Color3.fromRGB(255, 240, 210)
	keyHint.TextStrokeTransparency = 0.3
	keyHint.Text = if touch then "" else "B · Backpack"
	keyHint.Parent = button

	------------------------------------------------------------------ the window
	local window = Instance.new("Frame")
	window.Name = "BackpackWindow"
	window.AnchorPoint = Vector2.new(1, 1)
	window.Position = UDim2.new(1, -28, 1, -136)
	window.Size = UDim2.fromOffset(330, 250)
	window.Visible = false
	window.Parent = gui
	UISkin.panel(window)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -28, 0, 26)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 204, 92)
	title.TextStrokeTransparency = 0.4
	title.Text = "BACKPACK"
	title.ZIndex = 2
	title.Parent = window
	-- how full it is
	local fullBack = Instance.new("Frame")
	fullBack.Name = "Fullness"
	fullBack.Position = UDim2.fromOffset(12, 38)
	fullBack.Size = UDim2.new(1, -24, 0, 22)
	fullBack.Parent = window
	local fullFill = Instance.new("Frame")
	fullFill.Name = "Fill"
	fullFill.Size = UDim2.fromScale(0, 1)
	fullFill.BackgroundColor3 = Color3.fromRGB(200, 160, 90)
	fullFill.Parent = fullBack
	local fullText = Instance.new("TextLabel")
	fullText.BackgroundTransparency = 1
	fullText.Font = Enum.Font.GothamBold
	fullText.TextColor3 = Color3.new(1, 1, 1)
	fullText.TextStrokeTransparency = 0.2
	fullText.TextXAlignment = Enum.TextXAlignment.Left
	local fullLimit = Instance.new("UITextSizeConstraint")
	fullLimit.MaxTextSize = 16
	fullLimit.Parent = fullText
	fullText.Parent = fullBack
	UISkin.bar(fullBack, fullFill)
	local grid = Instance.new("Frame")
	grid.Name = "Items"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(12, 68)
	grid.Size = UDim2.new(1, -24, 1, -96)
	grid.ZIndex = 2
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(94, 66)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 14, 1, -6)
	hint.Size = UDim2.new(1, -28, 0, 18)
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(215, 200, 170)
	hint.Text = "Click an item to drop one. Empty it at the storage chest."
	hint.ZIndex = 2
	hint.Parent = window
	local empty = Instance.new("TextLabel")
	empty.BackgroundTransparency = 1
	empty.Position = UDim2.fromOffset(12, 80)
	empty.Size = UDim2.new(1, -24, 0, 40)
	empty.Font = Enum.Font.GothamMedium
	empty.TextScaled = true
	empty.TextColor3 = Color3.fromRGB(200, 205, 215)
	empty.Text = "Empty. Punch trees, catch fish and pick up wreckage."
	empty.TextWrapped = true
	empty.ZIndex = 2
	empty.Parent = window

	local cells: { [string]: { frame: TextButton, count: TextLabel } } = {}
	for i, kind in KINDS do
		local info = INFO[kind]
		local cell = Instance.new("TextButton")
		cell.Name = kind
		cell.Text = ""
		cell.LayoutOrder = i
		cell.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
		cell.BackgroundTransparency = 0.25
		cell.AutoButtonColor = true
		cell.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = cell
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(190, 150, 80)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = cell
		local pic = Instance.new("ImageLabel")
		pic.BackgroundTransparency = 1
		pic.Image = info.icon
		pic.ScaleType = Enum.ScaleType.Fit
		pic.Position = UDim2.fromScale(0.04, 0.08)
		pic.Size = UDim2.fromScale(0.5, 0.84)
		pic.Parent = cell
		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromScale(0.52, 0.1)
		count.Size = UDim2.fromScale(0.44, 0.5)
		count.Font = Enum.Font.GothamBlack
		count.TextScaled = true
		count.TextColor3 = Color3.new(1, 1, 1)
		count.TextStrokeTransparency = 0.3
		count.Text = "0"
		count.Parent = cell
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.5, 0.62)
		name.Size = UDim2.fromScale(0.48, 0.28)
		name.Font = Enum.Font.GothamMedium
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(215, 200, 170)
		name.Text = info.name
		name.Parent = cell
		cell.Parent = grid
		cell.Activated:Connect(function()
			Remotes.event("DropItem"):FireServer(kind)
		end)
		cells[kind] = { frame = cell, count = count }
	end

	local function refresh()
		local total = tonumber(player:GetAttribute("PackTotal")) or 0
		local size = tonumber(player:GetAttribute("PackSize")) or Config.Resources.BackpackSize
		countLabel.Text = `{total}/{size}`
		countLabel.TextColor3 = if total >= size then Color3.fromRGB(150, 20, 10) else Color3.fromRGB(40, 26, 10)
		fullFill.Size = UDim2.fromScale(math.clamp(total / size, 0, 1), 1)
		fullFill.BackgroundColor3 = if total >= size then Color3.fromRGB(230, 90, 60) else Color3.fromRGB(200, 160, 90)
		fullText.Text = if total >= size then `FULL  {total}/{size}` else `{total}/{size}`
		local any = false
		for kind, cell in cells do
			local n = tonumber(player:GetAttribute("Pack_" .. kind)) or 0
			cell.frame.Visible = n > 0
			cell.count.Text = tostring(n)
			any = any or n > 0
		end
		empty.Visible = not any
	end
	player.AttributeChanged:Connect(function(name)
		if name == "PackTotal" or string.sub(name, 1, 5) == "Pack_" then
			refresh()
		end
	end)
	refresh()

	local open = false
	local function setOpen(on: boolean)
		open = on
		window.Visible = on
		if on then
			local scale = window:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Scale = 0.85
			scale.Parent = window
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	button.Activated:Connect(function()
		setOpen(not open)
	end)
	ContextActionService:BindAction("ToggleBackpack", function(_name, state)
		if state == Enum.UserInputState.Begin then
			setOpen(not open)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonY)

	gui.Parent = player:WaitForChild("PlayerGui")

	------------------------------------------------------------------ the pop-up
	local function bump()
		bagScale.Scale = 1.25
		TweenService:Create(bagScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	-- icon + "+N" floating up from the backpack button
	local function screenPop(kind: string, amount: number)
		local info = INFO[kind]
		if not info then
			return
		end
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Size = UDim2.fromOffset(120, 48)
		local startPos = button.Position + UDim2.fromOffset(-60, -96)
		holder.Position = startPos
		holder.ZIndex = 5
		local pic = Instance.new("ImageLabel")
		pic.BackgroundTransparency = 1
		pic.Image = info.icon
		pic.ScaleType = Enum.ScaleType.Fit
		pic.Size = UDim2.fromOffset(48, 48)
		pic.ZIndex = 5
		pic.Parent = holder
		local plus = Instance.new("TextLabel")
		plus.BackgroundTransparency = 1
		plus.Position = UDim2.fromOffset(50, 4)
		plus.Size = UDim2.fromOffset(70, 40)
		plus.Font = Enum.Font.FredokaOne
		plus.TextSize = 34
		plus.TextXAlignment = Enum.TextXAlignment.Left
		plus.TextColor3 = Color3.fromRGB(255, 230, 140)
		plus.TextStrokeColor3 = Color3.fromRGB(40, 24, 6)
		plus.TextStrokeTransparency = 0
		plus.Text = `+{amount}`
		plus.ZIndex = 5
		plus.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = holder
		holder.Parent = gui
		-- pop in, drift up, fade out
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(holder, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = startPos + UDim2.fromOffset(0, -70) }):Play()
		task.delay(0.8, function()
			local fade = TweenInfo.new(0.5)
			TweenService:Create(pic, fade, { ImageTransparency = 1 }):Play()
			TweenService:Create(plus, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.55, function()
				holder:Destroy()
			end)
		end)
		bump()
	end

	-- the tiny 3D piece: pops up out of where it came from, then arcs into your back
	local function worldPop(kind: string, from: Vector3, onArrive: () -> ())
		local info = INFO[kind]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not info or not root then
			onArrive()
			return
		end
		local piece = Instance.new("Part")
		piece.Name = "PickupPop"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Size = info.size
		piece.Color = info.color
		piece.Material = info.material
		if info.shape then
			piece.Shape = info.shape
		end
		piece.Parent = Workspace
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxassetid://105240361456761"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 170))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Transparency = NumberSequence.new(0.3)
		sparkle.Lifetime = NumberRange.new(0.25, 0.4)
		sparkle.Speed = NumberRange.new(0)
		sparkle.Rate = 40
		sparkle.Parent = piece
		local popTime, flyTime = 0.32, 0.42
		local popTo = from + Vector3.new(0, 3.2, 0)
		local spin = Vector3.new(math.random() * 8 - 4, 9, math.random() * 8 - 4)
		local t = 0
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			local pos: Vector3
			local scale = 1
			if t < popTime then
				-- the pop: shoot up with a little overshoot, growing in
				local k = ease(t / popTime)
				pos = from:Lerp(popTo, k)
				scale = 0.3 + 0.9 * k
			else
				-- the arc into your back
				local k = math.min(1, (t - popTime) / flyTime)
				local target = root.Position + root.CFrame.LookVector * -0.9 + Vector3.new(0, 1, 0)
				local mid = popTo:Lerp(target, 0.5) + Vector3.new(0, 2.5, 0)
				local a = popTo:Lerp(mid, k)
				local b = mid:Lerp(target, k)
				pos = a:Lerp(b, k)
				scale = 1.2 - 0.9 * k * k
			end
			piece.Size = info.size * scale
			piece.CFrame = CFrame.new(pos) * CFrame.fromOrientation(spin.X * t, spin.Y * t, spin.Z * t)
			if t >= popTime + flyTime then
				conn:Disconnect()
				piece:Destroy()
				onArrive()
			end
		end)
	end

	Remotes.event("Gained").OnClientEvent:Connect(function(kind: string, amount: number, from: Vector3?)
		if typeof(kind) ~= "string" or typeof(amount) ~= "number" then
			return
		end
		local start = if typeof(from) == "Vector3" then from else nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if start and root and (start - root.Position).Magnitude < 60 then
			-- a few pieces for a handful, staggered
			local shown = math.min(amount, 4)
			for i = 1, shown do
				task.delay((i - 1) * 0.08, function()
					worldPop(kind, start :: Vector3, function()
						if i == shown then
							screenPop(kind, amount)
						end
					end)
				end)
			end
		else
			screenPop(kind, amount)
		end
	end)
end

return BackpackController
