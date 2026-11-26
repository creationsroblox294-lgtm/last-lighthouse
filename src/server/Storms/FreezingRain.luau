--!strict
-- Freezing Rain (Moderate): rain that freezes where it lands. Out in the open (nothing
-- overhead, outside the lamp's warm light) players slowly chill (player attribute "Chill",
-- 0..1); a player who is chilled through starts to freeze and takes damage until they get
-- under cover or into the light. The clients make the ground slippery. And the lamp ices
-- over again and again (Workspace attribute "LampIced"): while it's iced it burns extra fuel,
-- until someone climbs up and chips it clear (a hold prompt on the lamp).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Server = script.Parent.Parent
local LightService = require(Server:WaitForChild("LightService"))

local S = {
	ChillSeconds = 35, -- out in the open this long and you're chilled through
	WarmSeconds = 8, -- under cover or in the light this long and you're warm again
	FreezeDamage = 2, -- per second while chilled through
	IceEvery = NumberRange.new(18, 26),
	IcedDrain = 1, -- extra lamp fuel per second while the lamp is iced
	ChipHold = 2,
}

local FreezingRain = {}

local active = false
local generation = 0
local rng = Random.new()
local prompt: ProximityPrompt? = nil

local function lamp(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local lighthouse = map and map:FindFirstChild("Lighthouse")
	local lampRoom = lighthouse and lighthouse:FindFirstChild("LampRoom")
	local l = lampRoom and lampRoom:FindFirstChild("Lamp")
	return if l and l:IsA("BasePart") then l else nil
end

local function exposed(char: Model, root: BasePart): boolean
	if LightService.IsPointLit(root.Position) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 60, 0), params) == nil
end

local function setIced(v: boolean)
	Workspace:SetAttribute("LampIced", if v then true else nil)
	if prompt then
		prompt.Enabled = v
	end
end

function FreezingRain.Start()
	active = true
	generation += 1
	local mine = generation
	local l = lamp()
	if l and not prompt then
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "ChipIce"
		pr.ActionText = "Chip the ice off"
		pr.ObjectText = "Iced lamp"
		pr.HoldDuration = S.ChipHold
		pr.MaxActivationDistance = 12
		pr.RequiresLineOfSight = false
		pr.Enabled = false
		pr.Parent = l
		pr.Triggered:Connect(function(player: Player)
			if Workspace:GetAttribute("LampIced") then
				setIced(false)
				Remotes.event("StormEvent"):FireAllClients("IceChipped", nil)
				Remotes.notify(nil, `{player.DisplayName} chipped the ice off the lamp!`, "Good")
			end
		end)
		prompt = pr
	end
	-- chill, freezing, and the iced lamp's extra burn
	task.spawn(function()
		local tick = 0
		while active and generation == mine do
			local dt = task.wait(0.5)
			tick += dt
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if char and root and root:IsA("BasePart") and hum and hum.Health > 0 then
					local chill = (p:GetAttribute("Chill") :: number?) or 0
					if exposed(char, root) then
						chill = math.min(1, chill + dt / S.ChillSeconds)
					else
						chill = math.max(0, chill - dt / S.WarmSeconds)
					end
					p:SetAttribute("Chill", chill)
					if chill >= 1 and tick >= 1 then
						hum:TakeDamage(S.FreezeDamage)
					end
				end
			end
			if tick >= 1 then
				tick = 0
				if Workspace:GetAttribute("LampIced") then
					LightService.DrainFuel(S.IcedDrain)
				end
			end
		end
	end)
	while active and generation == mine do
		task.wait(rng:NextNumber(S.IceEvery.Min, S.IceEvery.Max))
		if active and generation == mine and not Workspace:GetAttribute("LampIced") then
			setIced(true)
			Remotes.notify(nil, "The lamp is icing over! Someone climb up and chip it clear!", "Alarm")
		end
	end
end

function FreezingRain.Stop()
	active = false
	setIced(false)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Chill", nil)
	end
end

return FreezingRain
