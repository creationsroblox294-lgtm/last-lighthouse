--!strict
-- FishService: schools of fish swimming just under the surface around the island.
-- Wade in (or stand on the lighthouse dock) and hold E to catch one: you carry a raw fish,
-- cook it at the lighthouse fireplace, then store or eat it.
-- Fish are anchored Blender models moved by the server; CreatureController animates them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))

local F = Config.Fish
local FishService = {}

type Fish = {
	model: Model,
	pivotFix: CFrame,
	school: Vector3,
	angle: number,
	radius: number,
	speed: number,
	bob: number,
	caught: boolean,
}

local fishes: { Fish } = {}
local folder: Instance
local rng = Random.new()

type School = { centre: Vector3, tint: Color3?, scale: number }

local function schoolCentres(): { School }
	local map = Workspace:FindFirstChild("Map")
	local waters = map and map:FindFirstChild("FishingWaters")
	local list: { School } = {}
	if waters then
		for _, p in waters:GetChildren() do
			if p:IsA("BasePart") then
				-- optional attributes on a school part: Tint (Color3), Scale (number)
				local tint = p:GetAttribute("Tint")
				local scale = p:GetAttribute("Scale")
				table.insert(list, {
					centre = Vector3.new(p.Position.X, 0, p.Position.Z),
					tint = if typeof(tint) == "Color3" then tint else nil,
					scale = if typeof(scale) == "number" then scale else 1,
				})
			end
		end
	end
	if #list == 0 then
		for _, c in F.Schools do
			table.insert(list, { centre = c, tint = nil, scale = 1 })
		end
	end
	return list
end

local function place(f: Fish)
	local pos = f.school + Vector3.new(math.cos(f.angle) * f.radius, F.Depth + math.sin(f.bob) * 0.25, math.sin(f.angle) * f.radius)
	-- swimming direction is the tangent of the circle
	local dir = Vector3.new(-math.sin(f.angle), 0, math.cos(f.angle)) * math.sign(f.speed)
	f.model:PivotTo(CFrame.lookAt(pos, pos + dir) * f.pivotFix)
end

local function spawnFish(school: School): Fish?
	local centre = school.centre
	local templates = ReplicatedStorage:FindFirstChild("CreatureModels")
	local template = templates and templates:FindFirstChild("Fish")
	if not template or not template:IsA("Model") then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Fish"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local v = template:Clone()
	v.Name = "Visual"
	if school.scale ~= 1 then
		v:ScaleTo(v:GetScale() * school.scale * rng:NextNumber(0.85, 1.15))
	end
	if school.tint then
		for _, sa in v:GetDescendants() do
			if sa:IsA("SurfaceAppearance") then
				pcall(function()
					(sa :: any).Color = school.tint
				end)
			end
		end
	end
	for _, d in v:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true
		end
	end
	local box = v:GetBoundingBox()
	local fix = CFrame.new(box.Position) * box.Rotation
	v.Parent = m
	m:SetAttribute("Creature", "Fish")
	m:SetAttribute("Anim", "Swim")
	m:SetAttribute("AnimSpeed", rng:NextNumber(0.8, 1.2))
	local body = v:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		m.PrimaryPart = body
	end
	local f: Fish = {
		model = m,
		pivotFix = fix:ToObjectSpace(v:GetPivot()),
		school = centre,
		angle = rng:NextNumber(0, math.pi * 2),
		radius = rng:NextNumber(3, 11),
		speed = (if rng:NextNumber() < 0.5 then -1 else 1) * F.SwimSpeed * rng:NextNumber(0.7, 1.3),
		bob = rng:NextNumber(0, 6),
		caught = false,
	}
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Catch"
	prompt.ObjectText = "Fish"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = F.CatchDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = (m.PrimaryPart or v) :: Instance
	prompt.Triggered:Connect(function(player: Player)
		if f.caught then
			return
		end
		if ResourceService.GetCarried(player) then
			Remotes.notify(player, "Your hands are full.", nil)
			return
		end
		if ResourceService.Give(player, "RawFish") then
			f.caught = true
			prompt.Enabled = false
			m:SetAttribute("Anim", "Flop")
			Remotes.notify(player, "Caught a fish! Cook it at the lighthouse fireplace.", "Good")
			task.delay(0.8, function()
				m.Parent = nil
				task.delay(F.RespawnSeconds, function()
					f.caught = false
					prompt.Enabled = true
					m:SetAttribute("Anim", "Swim")
					m.Parent = folder
				end)
			end)
		end
	end)
	place(f)
	m.Parent = folder
	return f
end

function FishService.Start()
	local runtime = Workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = Workspace
	-- live in Runtime.Enemies so CreatureController animates them like the other creatures
	local enemies = runtime:FindFirstChild("Enemies")
	if not enemies then
		local e = Instance.new("Folder")
		e.Name = "Enemies"
		e.Parent = runtime
		enemies = e
	end
	folder = enemies :: Instance

	for _, school in schoolCentres() do
		for _ = 1, F.PerSchool do
			local f = spawnFish(school)
			if f then
				table.insert(fishes, f)
			end
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		for _, f in fishes do
			if not f.caught then
				f.angle += f.speed / f.radius * step
				f.bob += step * 1.7
				place(f)
			end
		end
	end)
end

return FishService
