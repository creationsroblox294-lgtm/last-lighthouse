--!strict
-- HUDController: everything on screen. Scale-based sizes (with limits) so it works on
-- phones, tablets, PC and console. Buttons are big enough for touch.
--   top centre:  storm number, phase, countdown, boss health
--   top left:    lamp fuel and the three floors' health
--   top right:   shared storage
--   bottom:      what you're carrying (+ Drop), beam control (+ Let go)
--   middle:      alarms (lamp out, lost in the fog, run over) and short messages

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UISkin = require(script.Parent:WaitForChild("UISkin"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local StormTypes = require(Shared:WaitForChild("StormTypes"))

local HUDController = {}

local PHASE_TEXT: { [string]: string } = {
	Calm = "Calm: gather and repair",
	Warning = "Fog incoming! Get to the light",
	Storm = "STORM: keep the lamp lit",
	Dawn = "Dawn",
	Won = "The last storm has passed",
	Lost = "The light went out",
}
local PHASE_COLOR: { [string]: Color3 } = {
	Calm = Color3.fromRGB(150, 210, 255),
	Warning = Color3.fromRGB(255, 190, 80),
	Storm = Color3.fromRGB(255, 95, 85),
	Dawn = Color3.fromRGB(255, 220, 160),
	Won = Color3.fromRGB(255, 240, 150),
	Lost = Color3.fromRGB(200, 80, 80),
}
local KIND_COLOR: { [string]: Color3 } = {
	Alarm = Color3.fromRGB(255, 110, 90),
	Good = Color3.fromRGB(140, 230, 140),
	Wave = Color3.fromRGB(120, 190, 255),
}
local ITEM_NAME: { [string]: string } = {
	Wood = "wood",
	Scrap = "scrap metal",
	Oil = "an oil barrel",
	Fish = "a fish",
	WhaleOil = "whale oil",
}

local DARK = Color3.fromRGB(15, 20, 28)

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = DARK
	f.BackgroundTransparency = 0.35
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function text(parent: Instance, name: string, pos: UDim2, size: UDim2, font: Enum.Font, maxSize: number, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.MinTextSize = 9
	limit.Parent = l
	l.Parent = parent
	return l
end

local function bar(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): (Frame, Frame, TextLabel)
	local back = Instance.new("Frame")
	back.Name = name
	back.Position = pos
	back.Size = size
	back.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
	back.BorderSizePixel = 0
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(0, 6)
	c1.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 6)
	c2.Parent = fill
	fill.Parent = back
	local label = text(back, "Label", UDim2.fromScale(0.04, 0), UDim2.fromScale(0.92, 1), Enum.Font.GothamBold, 16, Enum.TextXAlignment.Left)
	label.ZIndex = 2
	label.TextStrokeTransparency = 0.2
	back.Parent = parent
	UISkin.bar(back, fill)
	return back, fill, label
end

local function button(parent: Instance, name: string, label: string, pos: UDim2, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position = pos
	b.Size = size
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = label
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.Parent = b
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(110, 44)
	min.Parent = b
	b.Parent = parent
	UISkin.button(b)
	return b
end

local UI = Config.UI

local function icon(parent: Instance, image: string, size: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = image
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = UDim2.fromOffset(size, size)
	i.ZIndex = 2
	i.Parent = parent
	return i
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function HUDController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local storm = SharedState.get("Storm")
	local light = SharedState.get("Light")
	local tower = SharedState.get("Tower")
	local storage = SharedState.get("Storage")
	local boss = SharedState.get("Boss")
	local run = SharedState.get("Run")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false

	-- Storm panel (top centre)
	local panel = frame(gui, "StormPanel", UDim2.fromScale(0.5, 0.015), UDim2.fromScale(0.3, 0.11), Vector2.new(0.5, 0))
	local panelLimit = Instance.new("UISizeConstraint")
	panelLimit.MinSize = Vector2.new(220, 68)
	panelLimit.MaxSize = Vector2.new(440, 115)
	panelLimit.Parent = panel
	local stormSkin = UISkin.panel(panel)
	local stormLabel = text(panel, "StormLabel", UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.4), Enum.Font.GothamBlack, 32)
	local phaseLabel = text(panel, "PhaseLabel", UDim2.fromScale(0.04, 0.46), UDim2.fromScale(0.92, 0.26), Enum.Font.GothamBold, 20)
	local timerLabel = text(panel, "TimerLabel", UDim2.fromScale(0.04, 0.72), UDim2.fromScale(0.92, 0.24), Enum.Font.GothamMedium, 18)
	-- the storm's severity badge, hanging off the panel's left end
	local tierBadge = icon(panel, UI.Tiers.Mild, 64)
	tierBadge.Name = "TierBadge"
	tierBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	tierBadge.Position = UDim2.new(0, -6, 0.5, 0)
	tierBadge.Size = UDim2.fromScale(0.62, 0.62)
	local badgeAspect = Instance.new("UIAspectRatioConstraint")
	badgeAspect.Parent = tierBadge
	tierBadge.SizeConstraint = Enum.SizeConstraint.RelativeYY
	tierBadge.Visible = false

	-- Boss bar (under the storm panel)
	local bossBack, bossFill, bossLabel = bar(gui, "BossBar", UDim2.new(0.3, 0, 0.14, 0), UDim2.fromScale(0.4, 0.035), Color3.fromRGB(110, 200, 120))
	bossBack.Visible = false

	-- Lamp + tower (top left)
	local left = frame(gui, "LampPanel", UDim2.fromScale(0.01, 0.015), UDim2.fromScale(0.22, 0.2))
	local leftLimit = Instance.new("UISizeConstraint")
	leftLimit.MinSize = Vector2.new(170, 110)
	leftLimit.MaxSize = Vector2.new(300, 170)
	leftLimit.Parent = left
	UISkin.panel(left)
	local _, fuelFill, fuelLabel = bar(left, "Fuel", UDim2.fromScale(0.05, 0.07), UDim2.fromScale(0.9, 0.26), Color3.fromRGB(255, 205, 90))
	local floorBars: { [string]: { fill: Frame, label: TextLabel } } = {}
	local floorNames = { GroundFloor = "Ground floor", BunkRoom = "Bunk room", LampRoom = "Lamp room" }
	for i, name in Config.Tower.Floors do
		local _, fill, label = bar(left, name, UDim2.fromScale(0.05, 0.38 + (i - 1) * 0.2), UDim2.fromScale(0.9, 0.16), Color3.fromRGB(120, 170, 220))
		floorBars[name] = { fill = fill, label = label }
		label.Text = floorNames[name]
	end

	-- Storage (top right)
	local right = frame(gui, "StoragePanel", UDim2.fromScale(0.99, 0.015), UDim2.fromScale(0.26, 0.07), Vector2.new(1, 0))
	local rightLimit = Instance.new("UISizeConstraint")
	rightLimit.MinSize = Vector2.new(200, 40)
	rightLimit.MaxSize = Vector2.new(400, 60)
	rightLimit.Parent = right
	UISkin.panel(right)
	-- storage: an icon and a count for each resource
	local storageRow = Instance.new("Frame")
	storageRow.Name = "Storage"
	storageRow.BackgroundTransparency = 1
	storageRow.Position = UDim2.fromScale(0.03, 0.05)
	storageRow.Size = UDim2.fromScale(0.94, 0.9)
	storageRow.ZIndex = 2
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0.02, 0)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = storageRow
	storageRow.Parent = right
	local storageCounts: { [string]: TextLabel } = {}
	for i, kind in { "Wood", "Scrap", "Oil", "Fish" } do
		local cell = Instance.new("Frame")
		cell.Name = kind
		cell.BackgroundTransparency = 1
		cell.Size = UDim2.fromScale(0.23, 1)
		cell.LayoutOrder = i
		cell.Parent = storageRow
		local pic = icon(cell, UI.Items[kind], 0)
		pic.Size = UDim2.fromScale(0.55, 1)
		local count = text(cell, "Count", UDim2.fromScale(0.55, 0.1), UDim2.fromScale(0.45, 0.8), Enum.Font.GothamBlack, 22, Enum.TextXAlignment.Left)
		count.ZIndex = 2
		storageCounts[kind] = count
	end

	-- Carrying + beam control (bottom, above the hotbar)
	local carryLabel = text(gui, "Carrying", UDim2.fromScale(0.3, 0.74), UDim2.fromScale(0.4, 0.04), Enum.Font.GothamBold, 20)
	local carryIcon = icon(gui, UI.Items.Wood, 50)
	carryIcon.Name = "CarryIcon"
	carryIcon.AnchorPoint = Vector2.new(1, 0)
	carryIcon.Position = UDim2.new(0.5, -84, 0.785, 0)
	carryIcon.Visible = false
	local dropButton = button(gui, "DropButton", "Drop", UDim2.fromScale(0.5, 0.785), UDim2.fromScale(0.12, 0.055), Color3.fromRGB(150, 90, 60))
	local releaseButton = button(gui, "ReleaseBeam", "Let go of the beam", UDim2.fromScale(0.5, 0.66), UDim2.fromScale(0.24, 0.06), Color3.fromRGB(170, 130, 50))

	-- Alarm banner (middle) and messages
	local bannerHolder = Instance.new("Frame")
	bannerHolder.Name = "AlarmBanner"
	bannerHolder.BackgroundTransparency = 1
	bannerHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerHolder.Position = UDim2.fromScale(0.5, 0.52)
	bannerHolder.Size = UDim2.fromScale(0.62, 0.1)
	bannerHolder.Visible = false
	bannerHolder.Parent = gui
	local bannerLimit = Instance.new("UISizeConstraint")
	bannerLimit.MaxSize = Vector2.new(900, 96)
	bannerLimit.Parent = bannerHolder
	local bannerSkin = UISkin.banner(bannerHolder, UI.Banner)
	local banner = text(bannerHolder, "Banner", UDim2.fromScale(0.1, 0.18), UDim2.fromScale(0.8, 0.64), Enum.Font.GothamBlack, 40)
	banner.ZIndex = 2
	local emblem = icon(gui, UI.EmblemVictory, 0)
	emblem.Name = "EndEmblem"
	emblem.AnchorPoint = Vector2.new(0.5, 1)
	emblem.Position = UDim2.fromScale(0.5, 0.46)
	emblem.Size = UDim2.fromScale(0.22, 0.22)
	emblem.SizeConstraint = Enum.SizeConstraint.RelativeYY
	emblem.Visible = false
	local subBanner = text(gui, "SubBanner", UDim2.fromScale(0.2, 0.585), UDim2.fromScale(0.6, 0.045), Enum.Font.GothamBold, 24)
	local toasts = Instance.new("Frame")
	toasts.Name = "Messages"
	toasts.BackgroundTransparency = 1
	toasts.Position = UDim2.fromScale(0.25, 0.19)
	toasts.Size = UDim2.fromScale(0.5, 0.3)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = toasts
	toasts.Parent = gui

	gui.Parent = playerGui

	dropButton.Activated:Connect(function()
		Remotes.event("DropItem"):FireServer()
	end)
	releaseButton.Activated:Connect(function()
		Remotes.event("ReleaseBeam"):FireServer()
	end)

	local order = 0
	Remotes.event("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
		if typeof(message) ~= "string" then
			return
		end
		order += 1
		-- each message sits on a small banner (green for good news, red for alarms)
		local l = Instance.new("Frame")
		l.Name = "Message"
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 38)
		l.LayoutOrder = order
		l.Parent = toasts
		local skin = UISkin.banner(l, if kind == "Good" then UI.BannerGood elseif kind == "Alarm" then UI.BannerWarning else UI.Banner)
		skin.ImageTransparency = 0.1
		local words = text(l, "Text", UDim2.fromScale(0.09, 0.14), UDim2.fromScale(0.82, 0.72), Enum.Font.GothamBold, 20)
		words.ZIndex = 2
		words.TextStrokeTransparency = 0.3
		words.Text = message
		words.TextColor3 = if kind then (KIND_COLOR[kind] or Color3.new(1, 1, 1)) else Color3.new(1, 1, 1)
		local items = toasts:GetChildren()
		local count = 0
		for _, child in items do
			if child:IsA("Frame") then
				count += 1
			end
		end
		if count > 4 then
			for _, child in items do
				if child:IsA("Frame") and child ~= l then
					child:Destroy()
					break
				end
			end
		end
		task.delay(4.5, function()
			l:Destroy()
		end)
	end)

	local function refreshStorm()
		local phase = storm:GetAttribute("Phase")
		local phaseName = if typeof(phase) == "string" then phase else "Calm"
		local stormNumber = SharedState.number(storm, "CurrentStorm", 1)
		local special = storm:GetAttribute("SpecialStorm")
		local isGreat = storm:GetAttribute("IsGreatStorm") == true
		local title: string
		if phaseName == "Won" then
			title = `{Config.MaxStorms} STORMS SURVIVED`
		elseif phaseName == "Lost" then
			title = `LOST AT STORM {stormNumber}`
		elseif phaseName == "Dawn" then
			title = `STORM {stormNumber} SURVIVED`
		else
			title = `STORM {stormNumber}`
			if isGreat then
				title ..= " · GREAT STORM"
			elseif typeof(special) == "string" and special ~= "" and special ~= "Ordinary" then
				-- the barometer only hints during the calm; the name is revealed at the warning
				local t = StormTypes.Get(special)
				title ..= if phaseName == "Calm" then " · ???" else ` · {string.upper(t.Name)}`
			end
		end
		local color = PHASE_COLOR[phaseName] or Color3.new(1, 1, 1)
		if (phaseName == "Warning" or phaseName == "Storm") and typeof(special) == "string" and special ~= "" and special ~= "Ordinary" then
			color = StormTypes.Get(special).Color
		end
		-- severity badge once the storm is known (the calm only hints at it)
		local tierShown = false
		if phaseName == "Warning" or phaseName == "Storm" or phaseName == "Dawn" then
			local sid = if typeof(special) == "string" and special ~= "" then special else "Ordinary"
			local tier = (StormTypes.Get(sid) :: any).Tier
			local image = if isGreat then UI.Tiers.Catastrophic else (UI.Tiers :: any)[tier or "Mild"]
			if image then
				tierBadge.Image = image
				tierShown = true
			end
		end
		tierBadge.Visible = tierShown
		stormLabel.Text = title
		phaseLabel.Text = if storm:GetAttribute("Holding") == true then "Drive off the Tide Caller!" else (PHASE_TEXT[phaseName] or phaseName)
		phaseLabel.TextColor3 = color
		stormSkin.ImageColor3 = Color3.new(1, 1, 1):Lerp(color, 0.3)
	end
	storm.AttributeChanged:Connect(function(attribute)
		if attribute ~= "PhaseEndsAt" then
			refreshStorm()
		end
	end)
	refreshStorm()

	local function refreshLight()
		local fuel = SharedState.number(light, "Fuel", 0)
		local maxFuel = SharedState.number(light, "MaxFuel", 100)
		local frac = math.clamp(fuel / maxFuel, 0, 1)
		fuelFill.Size = UDim2.fromScale(frac, 1)
		fuelFill.BackgroundColor3 = if frac <= 0 then Color3.fromRGB(90, 90, 90)
			elseif frac < Config.Light.LowFuelFraction then Color3.fromRGB(255, 110, 70)
			else Color3.fromRGB(255, 205, 90)
		fuelLabel.Text = if frac <= 0 then "LAMP OUT" else `Lamp fuel {math.floor(frac * 100 + 0.5)}%`
		releaseButton.Visible = light:GetAttribute("Controller") == player.Name
	end
	light.AttributeChanged:Connect(refreshLight)
	refreshLight()

	local function refreshTower()
		local maxHealth = SharedState.number(tower, "MaxHealth", 200)
		for name, b in floorBars do
			local frac = math.clamp(SharedState.number(tower, name, maxHealth) / maxHealth, 0, 1)
			b.fill.Size = UDim2.fromScale(frac, 1)
			b.fill.BackgroundColor3 = if frac <= 0 then Color3.fromRGB(120, 50, 50)
				elseif frac < 0.4 then Color3.fromRGB(230, 140, 70)
				else Color3.fromRGB(120, 170, 220)
		end
	end
	tower.AttributeChanged:Connect(refreshTower)
	refreshTower()

	local function refreshStorage()
		for kind, label in storageCounts do
			label.Text = tostring(SharedState.number(storage, kind, 0))
		end
	end
	storage.AttributeChanged:Connect(refreshStorage)
	refreshStorage()

	local function refreshBoss()
		local active = boss:GetAttribute("Active") == true
		bossBack.Visible = active
		if active then
			local maxHealth = math.max(1, SharedState.number(boss, "MaxHealth", 1))
			local frac = math.clamp(SharedState.number(boss, "Health", 0) / maxHealth, 0, 1)
			bossFill.Size = UDim2.fromScale(frac, 1)
			bossLabel.Text = "Tide Caller: hold the beam on its eyes"
		end
	end
	boss.AttributeChanged:Connect(refreshBoss)
	refreshBoss()

	local function refreshCarry()
		-- everything you gather goes into the backpack now (BackpackController), so the old
		-- "Carrying ..." line and Drop button stay hidden
		local _ = ITEM_NAME
		carryLabel.Text = ""
		carryIcon.Visible = false
		dropButton.Visible = false
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)
	refreshCarry()

	-- Timer + banners: a few updates per second
	task.spawn(function()
		while gui.Parent do
			local now = Workspace:GetServerTimeNow()
			local endsAt = SharedState.number(storm, "PhaseEndsAt", 0)
			timerLabel.Text = if endsAt > 0 then formatTime(endsAt - now) else ""

			local phase = storm:GetAttribute("Phase")
			local outAt = SharedState.number(light, "LightsOutAt", 0)
			local lost = player:GetAttribute("Lost")
			local skinImage, emblemImage = UI.BannerWarning, nil
			if phase == "Lost" then
				emblemImage = UI.EmblemDefeat
				banner.Text = "THE LIGHT WENT OUT"
				banner.TextColor3 = PHASE_COLOR.Lost
				local reason = run:GetAttribute("LostReason")
				subBanner.Text = `{if typeof(reason) == "string" then reason else ""}  A new run starts soon.`
			elseif phase == "Won" then
				skinImage, emblemImage = UI.BannerGood, UI.EmblemVictory
				banner.Text = "YOU KEPT THE LIGHT BURNING"
				banner.TextColor3 = PHASE_COLOR.Won
				subBanner.Text = "More storms are coming in the next update."
			elseif outAt > 0 then
				local left = Config.Light.LightsOutGrace - (now - outAt)
				banner.TextColor3 = PHASE_COLOR.Lost
				banner.Text = if left > 0 then `LAMP OUT! REFUEL IT: {math.ceil(left)}` else "LAMP OUT! THE FOG IS SWARMING"
				subBanner.Text = "Take fuel from storage and pour it into the tank in the lamp room."
			elseif lost == true or lost == "bunk" then
				skinImage = UI.Banner
				banner.TextColor3 = Color3.fromRGB(180, 200, 220)
				banner.Text = "LOST IN THE FOG"
				subBanner.Text = if lost == "bunk" then "Repair the bunk room to bring you back." else "You'll return at dawn."
			else
				banner.Text = ""
				subBanner.Text = ""
			end
			bannerHolder.Visible = banner.Text ~= ""
			bannerSkin.Image = skinImage
			emblem.Visible = emblemImage ~= nil
			if emblemImage then
				emblem.Image = emblemImage
			end
			task.wait(0.2)
		end
	end)
end

return HUDController
