--!strict
-- CraftingController: the crafting window. Opens from the crafting table's "Craft" prompt
-- (CraftingService adds it), lists Config.Crafting.Recipes as cards with what each costs
-- (green when storage has enough, red when not), and sends Craft(recipeId). The server
-- checks everything again. Works the same with touch, mouse and gamepad: big plain
-- buttons, no hover-only states, B / Esc / walking away closes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local UISkin = require(script.Parent:WaitForChild("UISkin"))

local CraftingController = {}

local player = Players.LocalPlayer
local K = Config.Crafting
local GOLD = Color3.fromRGB(255, 214, 120)
local TEXT = Color3.fromRGB(255, 240, 210)
local SOFT = Color3.fromRGB(200, 210, 225)
local KINDS = { "Wood", "Scrap", "Oil", "Fish" }

type Card = { recipe: any, frame: Frame, button: TextButton, cost: TextLabel, stamp: TextLabel, usable: boolean }

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, font: Enum.Font, maxSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or TEXT
	l.TextStrokeColor3 = Color3.fromRGB(20, 14, 10)
	l.TextStrokeTransparency = 0.5
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 4
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, pos: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = TEXT
	b.ZIndex = 5
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 20
	c.Parent = b
	b.Parent = parent
	UISkin.button(b)
	return b
end

function CraftingController.Start()
	local storage = SharedState.get("Storage")
	local crew = SharedState.get("Crafting")
	local craftRemote = Remotes.event("Craft")

	local gui = Instance.new("ScreenGui")
	gui.Name = "CraftingGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Enabled = false

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45 -- dim the world behind the window
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(640, 460)
	window.BackgroundTransparency = 1
	UISkin.panel(window)
	local scale = Instance.new("UIScale")
	scale.Parent = window
	window.Parent = gui

	label(window, "CRAFTING TABLE", UDim2.new(1, -120, 0, 34), UDim2.fromOffset(24, 14), Enum.Font.GothamBlack, 30, GOLD)
	local stock = label(window, "", UDim2.new(1, -48, 0, 22), UDim2.fromOffset(24, 52), Enum.Font.GothamBold, 18, SOFT)
	stock.RichText = true
	local close = button(window, "X", UDim2.fromOffset(52, 46), UDim2.new(1, -72, 0, 12))
	close.Name = "Close"

	local list = Instance.new("ScrollingFrame")
	list.Name = "Recipes"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(18, 84)
	list.Size = UDim2.new(1, -36, 1, -100)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Color3.fromRGB(196, 150, 70)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 3
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 168)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	list.Parent = window

	local cards: { Card } = {}
	for i, r in K.Recipes :: { any } do
		local f = Instance.new("Frame")
		f.Name = r.Id
		f.LayoutOrder = i
		f.BackgroundColor3 = Color3.fromRGB(16, 24, 38)
		f.BackgroundTransparency = 0.25
		f.ZIndex = 3
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(150, 112, 56)
		stroke.Thickness = 1.5
		stroke.Parent = f
		label(f, r.Name, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 8), Enum.Font.GothamBlack, 21, GOLD)
		local tag = label(f, if r.Scope == "Crew" then "WHOLE CREW" else "YOURS", UDim2.new(1, -20, 0, 14), UDim2.fromOffset(10, 33), Enum.Font.GothamBold, 13,
			if r.Scope == "Crew" then Color3.fromRGB(140, 210, 255) else Color3.fromRGB(170, 230, 150))
		tag.TextStrokeTransparency = 1
		local blurb = label(f, r.Blurb, UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 50), Enum.Font.Gotham, 15)
		blurb.TextWrapped = true
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		blurb.TextStrokeTransparency = 1
		local cost = label(f, "", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 102), Enum.Font.GothamBold, 16)
		cost.RichText = true
		cost.TextStrokeTransparency = 1
		local b = button(f, "Craft", UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -46))
		local stamp = label(f, "CRAFTED!", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 60), Enum.Font.GothamBlack, 30, Color3.fromRGB(255, 236, 160))
		stamp.TextXAlignment = Enum.TextXAlignment.Center
		stamp.ZIndex = 6
		stamp.Visible = false
		f.Parent = list
		local card: Card = { recipe = r, frame = f, button = b, cost = cost, stamp = stamp, usable = false }
		table.insert(cards, card)
		b.Activated:Connect(function()
			if card.usable then
				craftRemote:FireServer(r.Id)
			end
		end)
	end
	gui.Parent = player:WaitForChild("PlayerGui")

	local byId: { [string]: any } = {}
	for _, r in K.Recipes :: { any } do
		byId[r.Id] = r
	end
	local function has(r: any): boolean
		if r.Scope == "Crew" then
			return crew:GetAttribute(r.Id) == true
		end
		local v = player:GetAttribute(r.Stat)
		return typeof(v) == "number" and v >= r.Level
	end

	local function refresh()
		local parts = {}
		for _, kind in KINDS do
			table.insert(parts, `{kind} <font color="#ffd678">{storage:GetAttribute(kind) or 0}</font>`)
		end
		stock.Text = "Crew storage:  " .. table.concat(parts, "   ")
		for _, card in cards do
			local r = card.recipe
			local costs = {}
			local enough = true
			for _, kind in KINDS do
				local need = r.Cost[kind]
				if need then
					local ok = (storage:GetAttribute(kind) or 0) >= need
					enough = enough and ok
					table.insert(costs, `<font color="{if ok then "#9be08a" else "#ff8a7a"}">{need} {string.lower(kind)}</font>`)
				end
			end
			card.cost.Text = table.concat(costs, "  ")
			local owned = has(r)
			local locked = r.Requires and not has(byId[r.Requires])
			local b = card.button
			if owned then
				b.Text = if r.Scope == "Crew" then "Built" else "Owned"
			elseif locked then
				b.Text = `Needs {byId[r.Requires].Name}`
			elseif not enough then
				b.Text = "Not enough in storage"
			else
				b.Text = "Craft"
			end
			local usable = not owned and not locked and enough
			card.usable = usable
			b.TextTransparency = if usable then 0 else 0.45
			card.frame.BackgroundTransparency = if owned then 0.5 else 0.25
		end
	end

	-- keep it fitting the screen on phones
	local function fit()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local v = camera.ViewportSize
		scale.Scale = math.min(1, (v.X - 24) / 640, (v.Y - 24) / 460)
	end

	local open = false
	local function setOpen(on: boolean)
		if on == open then
			return
		end
		open = on
		gui.Enabled = on
		if on then
			fit()
			refresh()
			if UserInputService.GamepadEnabled and #cards > 0 then
				GuiService.SelectedObject = cards[1].button
			end
			ContextActionService:BindAction("CloseCrafting", function(_, state)
				if state == Enum.UserInputState.Begin then
					setOpen(false)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		else
			ContextActionService:UnbindAction("CloseCrafting")
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		end
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "CraftPrompt" then
			setOpen(true)
		end
	end)

	-- live updates while open
	storage.AttributeChanged:Connect(function()
		if open then
			refresh()
		end
	end)
	crew.AttributeChanged:Connect(function()
		if open then
			refresh()
		end
	end)
	player.AttributeChanged:Connect(function()
		if open then
			refresh()
		end
	end)

	Remotes.event("Crafted").OnClientEvent:Connect(function(crafter: Player, recipeId: string)
		if not open then
			return
		end
		for _, card in cards do
			if card.recipe.Id == recipeId and (crafter == player or card.recipe.Scope == "Crew") then
				card.stamp.Visible = true
				task.delay(1.4, function()
					card.stamp.Visible = false
				end)
			end
		end
	end)

	-- close when you walk away (or die)
	local since = 0
	local top: Instance? = nil
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "CraftPrompt" then
			top = prompt.Parent
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		if not open then
			return
		end
		since += dt
		if since < 0.25 then
			return
		end
		since = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not (root and root:IsA("BasePart") and top and top:IsA("BasePart")) or (root.Position - top.Position).Magnitude > K.UseRange + 4 then
			setOpen(false)
		end
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

return CraftingController
