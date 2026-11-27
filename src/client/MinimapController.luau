--!strict
-- MinimapController: a round minimap in the bottom-left corner that follows you (north up,
-- your arrow turns with the camera) and always points the way to the lighthouse. Click it,
-- or press M, to open the full island map with you, your teammates and the lighthouse marked.
-- The map image is a stitched top-down render of the island (tools/stitch_map.py); its world
-- square is Config.Minimap (MinX, MinZ, Span; north = -Z is up).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MinimapController = {}
local player = Players.LocalPlayer

local M = Config.Minimap
local UI = Config.UI
local UISkin = require(script.Parent:WaitForChild("UISkin"))
local CREAM = Color3.fromRGB(255, 240, 210)
local GOLD = Color3.fromRGB(255, 204, 92)
local INK = Color3.fromRGB(24, 28, 36)
local YOU = Color3.fromRGB(255, 255, 255)
local MATE = Color3.fromRGB(110, 190, 255)

-- world position -> 0..1 across the map image
local function toMap(p: Vector3): Vector2
	return Vector2.new((p.X - M.MinX) / M.Span, (p.Z - M.MinZ) / M.Span)
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

-- a pointer: white dot with a tip, rotate the returned frame to aim it
local function makePointer(parent: Instance, size: number, color: Color3): Frame
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.new(0.5, 0, 0.5, -size * 0.42)
	tip.Size = UDim2.fromOffset(size * 0.5, size * 0.5)
	tip.Rotation = 45
	tip.BackgroundColor3 = color
	tip.BorderSizePixel = 0
	tip.ZIndex = 6
	stroke(tip, INK, 1.5)
	tip.Parent = holder
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size * 0.62, size * 0.62)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 7
	corner(dot, UDim.new(1, 0))
	stroke(dot, INK, 2)
	dot.Parent = holder
	holder.Parent = parent
	return holder
end

-- the lighthouse marker: a gold lamp with a dark ring
local function makeLighthouse(parent: Instance, size: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = INK
	f.BorderSizePixel = 0
	f.ZIndex = 5
	corner(f, UDim.new(1, 0))
	stroke(f, GOLD, 2)
	local lamp = Instance.new("Frame")
	lamp.AnchorPoint = Vector2.new(0.5, 0.5)
	lamp.Position = UDim2.fromScale(0.5, 0.5)
	lamp.Size = UDim2.fromScale(0.5, 0.5)
	lamp.BackgroundColor3 = GOLD
	lamp.BorderSizePixel = 0
	lamp.ZIndex = 5
	corner(lamp, UDim.new(1, 0))
	lamp.Parent = f
	f.Parent = parent
	return f
end

local function dotMarker(parent: Instance, size: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = 5
	corner(f, UDim.new(1, 0))
	stroke(f, INK, 1.5)
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = CREAM
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.ZIndex = 8
	l.Parent = parent
	return l
end

function MinimapController.Start()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local miniSize = if touchOnly then 108 else 150
	-- the brass porthole frame is drawn around the map disc; its opening matches the disc
	local hole = UI.PortholeHole
	local portW = miniSize / (2 * hole[3])
	local portH = portW * 439 / 456
	local ext = math.ceil(portW * hole[1] - miniSize / 2) -- how far the brass reaches past the disc

	local gui = Instance.new("ScreenGui")
	gui.Name = "MinimapGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	------------------------------------------------------------------ the corner minimap
	local mini = Instance.new("Frame")
	mini.Name = "Minimap"
	mini.AnchorPoint = Vector2.new(0, 1)
	-- on phones the thumbstick lives in the bottom-left, so sit above it
	mini.Position = if touchOnly then UDim2.new(0, 6 + ext, 1, -222 - ext) else UDim2.new(0, 10 + ext, 1, -24 - ext)
	mini.Size = UDim2.fromOffset(miniSize, miniSize)
	mini.BackgroundTransparency = 1
	mini.Parent = gui

	-- the round map: one image showing just the patch around you (ImageRect), rounded by
	-- its own UICorner, so nothing needs clipping
	local disc = Instance.new("ImageLabel")
	disc.Name = "Map"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Color3.fromRGB(18, 96, 170)
	disc.BorderSizePixel = 0
	disc.Image = M.Image
	disc.ImageRectSize = Vector2.new(M.ImageSize / M.Zoom, M.ImageSize / M.Zoom)
	corner(disc, UDim.new(1, 0))
	disc.Parent = mini
	local port = Instance.new("ImageLabel")
	port.Name = "Porthole"
	port.BackgroundTransparency = 1
	port.Image = UI.Porthole
	port.AnchorPoint = Vector2.new(hole[1], hole[2])
	port.Position = UDim2.fromScale(0.5, 0.5)
	port.Size = UDim2.fromOffset(portW, portH)
	port.ZIndex = 9
	port.Parent = mini

	local miniMates = Instance.new("Folder")
	miniMates.Parent = mini
	local miniLight = makeLighthouse(mini, 18)
	local miniYou = makePointer(mini, 16, YOU)
	miniYou.Position = UDim2.fromScale(0.5, 0.5)

	local north = label(mini, "N", 13)
	north.AnchorPoint = Vector2.new(0.5, 0.5)
	north.Position = UDim2.new(0.5, 0, 0, -ext * 0.45) -- on the brass rim
	north.TextColor3 = GOLD
	north.ZIndex = 10

	local hint = label(mini, if touchOnly then "Tap for map" else "M  ·  Map", 12)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 1, ext - 4)
	hint.ZIndex = 10
	hint.TextTransparency = 0.15

	local miniButton = Instance.new("TextButton")
	miniButton.Size = UDim2.fromScale(1, 1)
	miniButton.BackgroundTransparency = 1
	miniButton.Text = ""
	miniButton.ZIndex = 11
	corner(miniButton, UDim.new(1, 0))
	miniButton.Parent = mini

	------------------------------------------------------------------ the full map
	local shade = Instance.new("TextButton") -- click outside the map to close
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.Position = UDim2.fromOffset(0, 0)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.Visible = false
	shade.ZIndex = 20
	shade.Parent = gui

	local big = Instance.new("Frame")
	big.Name = "BigMap"
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.52)
	big.Size = UDim2.fromScale(0.78, 0.78)
	big.BorderSizePixel = 0
	big.Visible = false
	big.ZIndex = 21
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = big
	big.Parent = gui
	UISkin.panel(big)

	local bigImg = Instance.new("ImageLabel")
	bigImg.AnchorPoint = Vector2.new(0.5, 0.5)
	bigImg.Position = UDim2.fromScale(0.5, 0.5)
	bigImg.Size = UDim2.new(1, -26, 1, -26)
	bigImg.BackgroundTransparency = 1
	bigImg.Image = M.Image
	bigImg.ZIndex = 22
	corner(bigImg, UDim.new(0, 10))
	bigImg.Parent = big

	local title = label(big, "THE ISLAND", 26)
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = GOLD
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0, 2)
	title.ZIndex = 31
	title.TextStrokeTransparency = 0.3
	-- a small navy-and-brass plaque behind the title, hanging over the top edge
	local plaque = Instance.new("Frame")
	plaque.Name = "TitlePlaque"
	plaque.AnchorPoint = Vector2.new(0.5, 0.5)
	plaque.Position = UDim2.new(0.5, 0, 0, 2)
	plaque.Size = UDim2.fromOffset(230, 50)
	plaque.ZIndex = 30
	plaque.Parent = big
	UISkin.panel(plaque).ZIndex = 30
	title.Size = UDim2.fromOffset(200, 34)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.TextScaled = true
	local titleMax = Instance.new("UITextSizeConstraint")
	titleMax.MaxTextSize = 30
	titleMax.Parent = title

	local close = UISkin.imageButton(UI.Close)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(52, 52)
	close.ZIndex = 32
	close.Parent = big

	local legend = label(big, '<font color="#FFFFFF">●</font> You      <font color="#6EBEFF">●</font> Teammates      <font color="#FFCC5C">●</font> The lighthouse', 15)
	legend.RichText = true
	legend.AnchorPoint = Vector2.new(0.5, 1)
	legend.Position = UDim2.new(0.5, 0, 1, -14)
	legend.ZIndex = 30
	local legendBg = Instance.new("Frame")
	legendBg.AnchorPoint = Vector2.new(0.5, 0.5)
	legendBg.Position = UDim2.fromScale(0.5, 0.5)
	legendBg.Size = UDim2.new(1, 24, 1, 10)
	legendBg.BackgroundColor3 = INK
	legendBg.BackgroundTransparency = 0.3
	legendBg.ZIndex = 29
	corner(legendBg, UDim.new(1, 0))
	legendBg.Parent = legend

	local bigLight = makeLighthouse(bigImg, 30)
	local lightName = label(bigImg, "Lighthouse", 16)
	lightName.AnchorPoint = Vector2.new(0.5, 0)
	lightName.TextColor3 = GOLD
	local bigYou = makePointer(bigImg, 24, YOU)
	local youName = label(bigImg, "You", 15)
	youName.AnchorPoint = Vector2.new(0.5, 0)
	local bigMates = Instance.new("Folder")
	bigMates.Parent = bigImg

	gui.Parent = player:WaitForChild("PlayerGui")

	local open = false
	local function setOpen(on: boolean)
		if open == on then
			return
		end
		open = on
		shade.Visible = true
		big.Visible = true
		local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if on then
			big.Size = UDim2.fromScale(0.7, 0.7)
			shade.BackgroundTransparency = 1
			TweenService:Create(big, info, { Size = UDim2.fromScale(0.78, 0.78) }):Play()
			TweenService:Create(shade, info, { BackgroundTransparency = 0.45 }):Play()
		else
			TweenService:Create(shade, info, { BackgroundTransparency = 1 }):Play()
			local t = TweenService:Create(big, info, { Size = UDim2.fromScale(0.7, 0.7) })
			t:Play()
			t.Completed:Once(function()
				if not open then
					big.Visible = false
					shade.Visible = false
				end
			end)
		end
	end
	miniButton.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	shade.Activated:Connect(function()
		setOpen(false)
	end)
	ContextActionService:BindAction("ToggleMap", function(_name, state)
		if state == Enum.UserInputState.Begin then
			setOpen(not open)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

	-- one marker per teammate, made and dropped as players come and go
	local function mateMarkers(folder: Folder, size: number, named: boolean): { [Player]: Frame }
		local list: { [Player]: Frame } = {}
		return setmetatable(list, {
			__index = function(t, p: Player)
				local f = dotMarker(folder, size, MATE)
				if named then
					local n = label(f, p.DisplayName, 13)
					n.AnchorPoint = Vector2.new(0.5, 0)
					n.Position = UDim2.new(0.5, 0, 1, 2)
					n.TextColor3 = MATE
				end
				rawset(t, p, f)
				return f
			end,
		}) :: any
	end
	local miniMateMarks = mateMarkers(miniMates, 9, false)
	local bigMateMarks = mateMarkers(bigMates, 13, true)
	Players.PlayerRemoving:Connect(function(p)
		for _, marks in { miniMateMarks, bigMateMarks } do
			local f = rawget(marks, p)
			if f then
				f:Destroy()
				marks[p] = nil
			end
		end
	end)

	local lastPos = Config.World.TowerCenter
	local towerUV = toMap(Config.World.TowerCenter)
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			lastPos = root.Position
		end
		local you = toMap(lastPos)
		local camera = Workspace.CurrentCamera
		local look = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
		local heading = math.deg(math.atan2(look.X, -look.Z))

		-- minimap: show the patch of the image centred on you
		local half = M.ImageSize / M.Zoom / 2
		disc.ImageRectOffset = Vector2.new(you.X * M.ImageSize - half, you.Y * M.ImageSize - half)
		miniYou.Rotation = heading
		local px = mini.AbsoluteSize.X
		local radius = px / 2 - 11
		local function placeOnMini(f: GuiObject, uv: Vector2, clamp: boolean): boolean
			local d = (uv - you) * M.Zoom * px
			local inside = d.Magnitude <= radius
			if not inside and clamp then
				d = d.Unit * radius
			end
			f.Position = UDim2.new(0.5, d.X, 0.5, d.Y)
			return inside
		end
		-- the lighthouse stays on the rim when it is out of range, so it always shows the way
		local near = placeOnMini(miniLight, towerUV, true)
		miniLight.Size = if near then UDim2.fromOffset(18, 18) else UDim2.fromOffset(14, 14)

		-- teammates
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				local m1, m2 = miniMateMarks[p], bigMateMarks[p]
				if r and r:IsA("BasePart") then
					local uv = toMap(r.Position)
					m1.Visible = placeOnMini(m1, uv, false)
					m2.Visible = open
					m2.Position = UDim2.fromScale(uv.X, uv.Y)
				else
					m1.Visible = false
					m2.Visible = false
				end
			end
		end

		if open then
			bigYou.Position = UDim2.fromScale(you.X, you.Y)
			bigYou.Rotation = heading
			youName.Position = UDim2.new(you.X, 0, you.Y, 14)
			bigLight.Position = UDim2.fromScale(towerUV.X, towerUV.Y)
			lightName.Position = UDim2.new(towerUV.X, 0, towerUV.Y, 18)
		end
	end)
end

return MinimapController
