--!strict
-- IntroController: plays the intro cutscene once per session: a fisherman's boat is caught
-- in a storm, capsizes, and he washes up on this island. Rendered in Blender; plays as a
-- video (Config.Intro.VideoId) or, without one, as a moving storyboard of stills from the
-- same animation (Config.Intro.Slides). Skippable. When it ends the server puts you on the
-- beach where the story leaves you.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local IntroController = {}
local player = Players.LocalPlayer

local function controls(enabled: boolean)
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any):WaitForChild("PlayerModule")) :: any
	end)
	if ok and module then
		local c = module:GetControls()
		if enabled then
			c:Enable()
		else
			c:Disable()
		end
	end
end

local function makeGui(): (ScreenGui, Frame, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	back.Parent = gui
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -24, 1, -24)
	skip.Size = UDim2.fromOffset(130, 44)
	skip.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	skip.BackgroundTransparency = 0.3
	skip.TextColor3 = Color3.fromRGB(255, 236, 200)
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 20
	skip.Text = "Skip  >>"
	skip.ZIndex = 10
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = skip
	skip.Parent = back
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, back, skip
end

local function slideshow(back: Frame, slides: { any }, isDone: () -> boolean)
	local images = {}
	for _, sl in slides do
		table.insert(images, sl.image)
	end
	-- preload, but never wait more than a few seconds for it
	local preloaded = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(images)
		end)
		preloaded = true
	end)
	local t0 = os.clock()
	while not preloaded and os.clock() - t0 < 4 do
		task.wait(0.1)
	end
	local frames: { ImageLabel } = {}
	for i = 1, 2 do
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Crop
		img.ImageTransparency = 1
		img.ZIndex = i
		img.Parent = back
		frames[i] = img
	end
	local caption = Instance.new("TextLabel")
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -70)
	caption.Size = UDim2.new(0.8, 0, 0, 40)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.Merriweather
	caption.TextSize = 28
	caption.TextColor3 = Color3.fromRGB(255, 240, 220)
	caption.TextStrokeTransparency = 0.4
	caption.TextTransparency = 1
	caption.ZIndex = 5
	caption.Parent = back
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(230, 240, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 6
	flash.Parent = back
	local front = 1
	for _, sl in slides do
		if isDone() then
			return
		end
		front = 3 - front
		local img = frames[front]
		local other = frames[3 - front]
		img.ZIndex = 3
		other.ZIndex = 2
		img.Image = sl.image
		img.Size = UDim2.fromScale(1.02, 1.02)
		-- slow push-in on every still, cross-fade from the last one
		TweenService:Create(img, TweenInfo.new(sl.seconds + 0.6, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1.12, 1.12) }):Play()
		TweenService:Create(img, TweenInfo.new(0.5), { ImageTransparency = 0 }):Play()
		if sl.flash then
			flash.BackgroundTransparency = 0
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
		if sl.caption then
			caption.Text = sl.caption
			caption.TextTransparency = 1
			TweenService:Create(caption, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
			task.delay(sl.seconds - 0.4, function()
				TweenService:Create(caption, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end)
		end
		task.wait(sl.seconds)
		TweenService:Create(other, TweenInfo.new(0.2), { ImageTransparency = 1 }):Play()
		if sl.blackAfter then
			TweenService:Create(img, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
			task.wait(sl.blackAfter)
		end
	end
	task.wait(0.8)
end

function IntroController.Start()
	local intro = Config.Intro
	local id = intro.VideoId
	local slides = intro.Slides
	local useVideo = typeof(id) == "string" and id ~= ""
	if not useVideo and not (slides and #slides > 0) then
		return
	end
	local gui, back, skip = makeGui()
	controls(false)

	local finished = false
	local video: VideoFrame? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		if video then
			video:Pause()
		end
		Remotes.event("IntroDone"):FireServer()
		task.wait(0.4)
		controls(true)
		skip.Visible = false
		for _, d in back:GetChildren() do
			if d:IsA("GuiObject") and d ~= skip then
				d.Visible = false
			end
		end
		TweenService:Create(back, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		task.wait(1.3)
		gui:Destroy()
	end
	skip.Activated:Connect(finish)

	if not useVideo then
		slideshow(back, slides, function()
			return finished
		end)
		finish()
		return
	end

	local v = Instance.new("VideoFrame")
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = UDim2.fromScale(0.5, 0.5)
	v.Size = UDim2.fromScale(1, 1)
	v.BackgroundTransparency = 1
	v.Looped = false
	v.Video = id
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.Parent = v
	v.Parent = back
	video = v
	v.Ended:Connect(finish)
	-- give the video a few seconds to load, otherwise skip it
	local t0 = os.clock()
	while not v.IsLoaded and os.clock() - t0 < 8 do
		task.wait(0.1)
	end
	if not v.IsLoaded then
		finish()
		return
	end
	v:Play()
end

return IntroController
