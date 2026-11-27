--!strict
-- UISkin: dresses plain UI frames in the game's art (navy driftwood + brass, made with
-- ForgeGUI and cut out by tools/forge_cutout.py). The images are 9-sliced, so one panel or
-- bar image fits any size without stretching its corners or bolts. Image ids and slice
-- rectangles live in Config.UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UISkin = {}
local UI = Config.UI

local function rect(r: { number }): Rect
	return Rect.new(r[1], r[2], r[3], r[4])
end

-- keep a callback in step with an object's on-screen size
local function onSize(obj: GuiObject, fn: (Vector2) -> ())
	obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fn(obj.AbsoluteSize)
	end)
	fn(obj.AbsoluteSize)
end

local function strip(obj: Instance)
	for _, c in obj:GetChildren() do
		if c:IsA("UICorner") or c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

-- The navy/brass panel behind a frame. The frame itself goes see-through.
function UISkin.panel(frame: GuiObject): ImageLabel
	strip(frame)
	frame.BackgroundTransparency = 1
	local skin = Instance.new("ImageLabel")
	skin.Name = "Skin"
	skin.BackgroundTransparency = 1
	skin.Image = UI.Panel
	skin.ScaleType = Enum.ScaleType.Slice
	skin.SliceCenter = rect(UI.PanelSlice)
	skin.ZIndex = 0
	skin.Parent = frame
	onSize(frame, function(size)
		-- the frame hangs a little outside the panel so the contents keep their room
		local border = math.clamp(math.min(size.X, size.Y) * 0.2, 10, 24)
		skin.SliceScale = border / 60
		local out = math.floor(border * 0.55)
		skin.Position = UDim2.fromOffset(-out, -out)
		skin.Size = UDim2.new(1, out * 2, 1, out * 2)
	end)
	return skin
end

-- A brass bar frame. `fill` is moved into the slot inside the frame (it keeps its own
-- Size along X, so callers can still set fill.Size = UDim2.fromScale(frac, 1)).
function UISkin.bar(back: GuiObject, fill: GuiObject): Frame
	strip(back)
	back.BackgroundTransparency = 1
	local skin = Instance.new("ImageLabel")
	skin.Name = "Skin"
	skin.BackgroundTransparency = 1
	skin.Image = UI.Bar
	skin.ScaleType = Enum.ScaleType.Slice
	skin.SliceCenter = rect(UI.BarSlice)
	skin.Size = UDim2.fromScale(1, 1)
	skin.ZIndex = 2
	skin.Parent = back
	local slot = Instance.new("Frame")
	slot.Name = "Slot"
	slot.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	slot.BackgroundTransparency = 0.15
	slot.BorderSizePixel = 0
	slot.ZIndex = 1
	slot.ClipsDescendants = true
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = slot
	slot.Parent = back
	strip(fill)
	local fillRound = Instance.new("UICorner")
	fillRound.CornerRadius = UDim.new(1, 0)
	fillRound.Parent = fill
	fill.ZIndex = 1
	fill.Parent = slot
	-- a soft highlight along the top of the liquid
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 235, 235)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
	})
	shine.Parent = fill
	local inset = UI.BarInset -- left, top, right, bottom in image pixels
	-- the brass is drawn thinner than the art's own proportions so the slot (and the text
	-- in it) gets most of the bar's height
	local labels: { TextLabel } = {}
	for _, c in back:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	onSize(back, function(size)
		local s = size.Y / (UI.BarHeight * 1.8)
		skin.SliceScale = s
		slot.Position = UDim2.fromOffset(inset[1] * s, inset[2] * s)
		slot.Size = UDim2.new(1, -(inset[1] + inset[3]) * s, 1, -(inset[2] + inset[4]) * s)
		local slotH = size.Y - (inset[2] + inset[4]) * s
		for _, l in labels do
			local limit = l:FindFirstChildOfClass("UITextSizeConstraint")
			if limit then
				limit.MaxTextSize = math.max(1, math.floor(slotH * 0.92))
				limit.MinTextSize = 1
			end
		end
	end)
	-- labels go inside the slot, over the liquid, filling its height
	for _, l in labels do
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.new(0, 8, 0.5, 0)
		l.Size = UDim2.new(1, -16, 0.96, 0)
		l.TextScaled = true
		l.ZIndex = 3
		l.Parent = slot
	end
	return slot
end

-- An image button (e.g. the brass X)
function UISkin.imageButton(image: string): ImageButton
	local b = Instance.new("ImageButton")
	b.BackgroundTransparency = 1
	b.Image = image
	b.ScaleType = Enum.ScaleType.Fit
	b.AutoButtonColor = false
	b.MouseEnter:Connect(function()
		b.ImageColor3 = Color3.fromRGB(255, 236, 190)
	end)
	b.MouseLeave:Connect(function()
		b.ImageColor3 = Color3.new(1, 1, 1)
	end)
	return b
end

return UISkin
