--!strict
-- Forage plants in Map.Forage (carrot patches, berry bushes, apple trees, mushrooms,
-- pumpkins). Each model has a Forage attribute and a PickPart. Hold E to pick and eat
-- on the spot: it heals a little, then the plant regrows after a while.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ForageService = {}

-- parts that disappear when picked, per plant
local EDIBLE: { [string]: { [string]: boolean } } = {
	Carrot = { Carrot = true, Top = true },
	Berries = { Berry = true },
	Apple = { Apple = true },
	Mushroom = { Cap = true, Stalk = true, Spot = true },
	Pumpkin = { Pumpkin = true, Stem = true },
}

local LINES: { [string]: string } = {
	Carrot = "Crunchy carrot. +%d health",
	Berries = "A handful of berries. +%d health",
	Apple = "A crisp apple. +%d health",
	Mushroom = "Earthy mushrooms. +%d health",
	Pumpkin = "Roasted pumpkin would be better... +%d health",
}

local function setRipe(model: Model, ripe: boolean)
	local edible = EDIBLE[model:GetAttribute("Forage") :: string] or {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and edible[p.Name] then
			p.Transparency = if ripe then 0 else 1
		end
	end
	model:SetAttribute("Ripe", ripe)
end

local function setup(model: Model)
	local kind = model:GetAttribute("Forage")
	local pickPart = model:FindFirstChild("PickPart")
	if typeof(kind) ~= "string" or not (pickPart and pickPart:IsA("BasePart")) then
		return
	end
	local F = Config.Forage
	local heal = (F.Heal :: any)[kind] or 10
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick"
	prompt.ObjectText = kind
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = pickPart
	setRipe(model, true)

	prompt.Triggered:Connect(function(player: Player)
		if model:GetAttribute("Ripe") ~= true then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
			return
		end
		if (root.Position - pickPart.Position).Magnitude > 14 then
			return
		end
		setRipe(model, false)
		prompt.Enabled = false
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
		Remotes.notify(player, string.format(LINES[kind] or "Tasty. +%d health", heal), "Good")
		task.delay(F.RegrowSeconds, function()
			if model.Parent then
				setRipe(model, true)
				prompt.Enabled = true
			end
		end)
	end)
end

function ForageService.Start()
	local map = Workspace:WaitForChild("Map")
	local folder = map:FindFirstChild("Forage")
	if not folder then
		return
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			setup(m)
		end
	end
end

return ForageService
