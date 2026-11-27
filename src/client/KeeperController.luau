--!strict
-- KeeperController: the client side of the core loop (KeeperService).
--   - Brass counter + "Locker" button (top left, in the harbor and on the island)
--   - "+19 Brass  Survived storm 3" pop-ups as Brass is earned
--   - The Keeper's Locker window: Perks / Lanterns / Titles tabs with buy, wear and locked
--     states. Opens from the Locker button or the stall's prompt in the harbor.
-- Plain big buttons that work with touch, mouse and gamepad; B / Esc / X closes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UISkin = require(script.Parent:WaitForChild("UISkin"))

local KeeperController = {}

local player = Players.LocalPlayer
local K = Config.Keeper
local GOLD = Color3.fromRGB(255, 214, 120)
local TEXT = Color3.fromRGB(255, 240, 210)
local SOFT = Color3.fromRGB(200, 210, 225)
local BRASS = Color3.fromRGB(232, 184, 92)
local COIN = "rbxassetid://73592926731933" -- assets/ui/BrassCoin.png

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

local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, maxText: number?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = TEXT
	b.ZIndex = 5
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxText or 20
	c.Parent = b
	b.Parent = parent
	UISkin.button(b)
	return b
end

local function num(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

type Card = { frame: Frame, button: TextButton, info: TextLabel, usable: boolean, action: () -> () }

function KeeperController.Start()
	local buyRemote = Remotes.event("KeeperBuy")
	local equipRemote = Remotes.event("KeeperEquip")

	local gui = Instance.new("ScreenGui")
	gui.Name = "KeeperGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11

	-- Brass counter + Locker button
	local bar = Instance.new("Frame")
	bar.Name = "BrassBar"
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.new(0, 12, 0.23, 0)
	bar.Size = UDim2.fromOffset(250, 46)
	bar.Parent = gui
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(130, 46)
	pill.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	pill.BackgroundTransparency = 0.2
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = pill
	local ps = Instance.new("UIStroke")
	ps.Color = BRASS
	ps.Thickness = 2
	ps.Parent = pill
	-- the brass coin (a lighthouse stamped in brass)
	local coin = Instance.new("ImageLabel")
	coin.BackgroundTransparency = 1
	coin.Image = COIN
	coin.Size = UDim2.fromOffset(36, 36)
	coin.Position = UDim2.fromOffset(5, 5)
	coin.ZIndex = 2
	coin.Parent = pill
	local brassText = label(pill, "0", UDim2.new(1, -52, 1, -12), UDim2.fromOffset(46, 6), Enum.Font.GothamBlack, 24, GOLD)
	pill.Parent = bar
	local lockerButton = button(bar, "Locker", UDim2.fromOffset(108, 46), UDim2.fromOffset(138, 0), 20)
	lockerButton.Name = "LockerButton"

	-- pop-ups
	local pops = Instance.new("Frame")
	pops.BackgroundTransparency = 1
	pops.Position = UDim2.new(0, 12, 0.23, 52)
	pops.Size = UDim2.fromOffset(300, 140)
	pops.Parent = gui
	local popLayout = Instance.new("UIListLayout")
	popLayout.SortOrder = Enum.SortOrder.LayoutOrder
	popLayout.Padding = UDim.new(0, 2)
	popLayout.Parent = pops
	local popOrder = 0

	-- window
	local shade = Instance.new("Frame")
	shade.Name = "Locker"
	shade.Size = UDim2.new(1, 0, 1, 80)
	shade.Position = UDim2.fromOffset(0, -60)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45 -- dim the world behind the window
	shade.BorderSizePixel = 0
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = gui
	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.new(0.5, 0, 0.5, 30)
	window.Size = UDim2.fromOffset(700, 500)
	window.BackgroundTransparency = 1
	UISkin.panel(window)
	local scale = Instance.new("UIScale")
	scale.Parent = window
	window.Parent = shade
	label(window, "KEEPER'S LOCKER", UDim2.new(1, -140, 0, 34), UDim2.fromOffset(24, 14), Enum.Font.GothamBlack, 30, GOLD)
	local header = label(window, "", UDim2.new(1, -140, 0, 22), UDim2.fromOffset(24, 50), Enum.Font.GothamBold, 18, SOFT)
	header.RichText = true
	local close = button(window, "X", UDim2.fromOffset(52, 46), UDim2.new(1, -72, 0, 12))

	local TABS = { "Perks", "Lanterns", "Titles" }
	local tabButtons: { [string]: TextButton } = {}
	local tab = "Perks"
	for i, name in TABS do
		local b = button(window, name, UDim2.fromOffset(140, 40), UDim2.fromOffset(24 + (i - 1) * 150, 82), 20)
		tabButtons[name] = b
	end

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(18, 132)
	list.Size = UDim2.new(1, -36, 1, -148)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Color3.fromRGB(196, 150, 70)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 3
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 150)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	list.Parent = window

	local cards: { Card } = {}
	local function clearCards()
		for _, c in cards do
			c.frame:Destroy()
		end
		table.clear(cards)
	end

	local function card(order: number, title: string, titleColor: Color3, blurb: string): Card
		local f = Instance.new("Frame")
		f.LayoutOrder = order
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
		label(f, title, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 8), Enum.Font.GothamBlack, 21, titleColor)
		local info = label(f, "", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(10, 33), Enum.Font.GothamBold, 14, SOFT)
		info.TextStrokeTransparency = 1
		local b = label(f, blurb, UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 52), Enum.Font.Gotham, 15)
		b.TextWrapped = true
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.TextStrokeTransparency = 1
		local btn = button(f, "", UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -46))
		f.Parent = list
		local c: Card = { frame = f, button = btn, info = info, usable = false, action = function() end }
		btn.Activated:Connect(function()
			if c.usable then
				c.action()
			end
		end)
		table.insert(cards, c)
		return c
	end

	local function setButton(c: Card, text: string, usable: boolean, action: (() -> ())?)
		c.button.Text = text
		c.usable = usable
		c.button.TextTransparency = if usable then 0 else 0.45
		if action then
			c.action = action
		end
	end

	local function titleUnlocked(t: any): boolean
		if t.Cost then
			return num("Own_" .. t.Id) > 0
		elseif t.Level then
			return num("KeeperLevel") >= t.Level
		elseif t.BestStorm then
			return num("BestStorm") >= t.BestStorm
		elseif t.RunsWon then
			return num("RunsWon") >= t.RunsWon
		end
		return true
	end

	local function render()
		local brass = num("Brass")
		header.Text = `<font color="#ffd678">{brass} Brass</font>   ·   Keeper level {math.max(1, num("KeeperLevel"))}   ·   earn more by surviving storms`
		for name, b in tabButtons do
			-- the open tab is bright gold; the others step back
			b.TextColor3 = if name == tab then GOLD else SOFT
			b.TextTransparency = if name == tab then 0 else 0.35
		end
		clearCards()
		if tab == "Perks" then
			for i, p in K.Perks :: { any } do
				local tier = num("Own_" .. p.Id)
				local c = card(i, p.Name, GOLD, p.Blurb)
				c.info.Text = `Tier {tier} of {#p.Costs}`
				local cost = p.Costs[tier + 1]
				if not cost then
					setButton(c, "Maxed", false)
				else
					setButton(c, `Buy tier {tier + 1}  ·  {cost} Brass`, brass >= cost, function()
						buyRemote:FireServer(p.Id)
					end)
				end
			end
		elseif tab == "Lanterns" then
			local wearing = player:GetAttribute("Lantern")
			for i, l in K.Lanterns :: { any } do
				local c = card(i, l.Name, l.Color, l.Blurb)
				local owned = num("Own_" .. l.Id) > 0
				if wearing == l.Id then
					c.info.Text = "On your belt"
					setButton(c, "Take off", true, function()
						equipRemote:FireServer("Lantern", "")
					end)
				elseif owned then
					c.info.Text = "Owned"
					setButton(c, "Wear", true, function()
						equipRemote:FireServer("Lantern", l.Id)
					end)
				else
					c.info.Text = `{l.Cost} Brass`
					setButton(c, `Buy  ·  {l.Cost} Brass`, brass >= l.Cost, function()
						buyRemote:FireServer(l.Id)
					end)
				end
			end
		else
			local wearing = player:GetAttribute("Title")
			for i, t in K.Titles :: { any } do
				local c = card(i, t.Name, t.Color, t.Blurb)
				local unlocked = titleUnlocked(t)
				if wearing == t.Id then
					c.info.Text = "Over your head"
					setButton(c, "Wearing", false)
				elseif unlocked then
					c.info.Text = "Unlocked"
					setButton(c, "Wear", true, function()
						equipRemote:FireServer("Title", t.Id)
					end)
				elseif t.Cost then
					c.info.Text = `{t.Cost} Brass`
					setButton(c, `Buy  ·  {t.Cost} Brass`, brass >= t.Cost, function()
						buyRemote:FireServer(t.Id)
					end)
				else
					c.info.Text = "Earn it in a run"
					setButton(c, "Locked", false)
				end
			end
		end
	end

	local function fit()
		local camera = Workspace.CurrentCamera
		if camera then
			local v = camera.ViewportSize
			scale.Scale = math.min(1, (v.X - 24) / 700, (v.Y - 24) / 500)
		end
	end

	local open = false
	local function setOpen(on: boolean)
		if on == open then
			return
		end
		open = on
		shade.Visible = on
		bar.Visible = not on -- the window shows your Brass itself
		if on then
			fit()
			render()
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = tabButtons[tab]
			end
			ContextActionService:BindAction("CloseLocker", function(_, state)
				if state == Enum.UserInputState.Begin then
					setOpen(false)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		else
			ContextActionService:UnbindAction("CloseLocker")
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		end
	end
	for name, b in tabButtons do
		b.Activated:Connect(function()
			tab = name
			render()
		end)
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)
	lockerButton.Activated:Connect(function()
		setOpen(not open)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "LockerPrompt" then
			setOpen(true)
		end
	end)

	local function refreshBrass()
		brassText.Text = tostring(num("Brass"))
	end
	refreshBrass()
	player.AttributeChanged:Connect(function(name)
		if name == "Brass" then
			refreshBrass()
		end
		if open and (name == "Brass" or name == "Title" or name == "Lantern" or name == "KeeperLevel" or string.sub(name, 1, 4) == "Own_") then
			render()
		end
	end)

	Remotes.event("Earned").OnClientEvent:Connect(function(amount: number, reason: string)
		popOrder += 1
		local pop = label(pops, `+{amount} Brass   {reason}`, UDim2.new(1, 0, 0, 24), UDim2.new(), Enum.Font.GothamBlack, 20, GOLD)
		pop.LayoutOrder = popOrder
		pop.TextTransparency = 0
		local bump = TweenService:Create(pill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Size = UDim2.fromOffset(138, 50) })
		bump:Play()
		task.delay(2.2, function()
			TweenService:Create(pop, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.65)
			pop:Destroy()
		end)
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

return KeeperController
