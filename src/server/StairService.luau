--!strict
-- Quick-travel on the lighthouse spiral stairs.
-- Every SpiralStair in Map.Lighthouse gets a "Go up" prompt at its foot and a "Go down"
-- prompt at its head. Walking still works (each flight also has an invisible SmoothRamp),
-- the prompts are for players who find the tight spiral awkward.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local StairService = {}

local COOLDOWN = 0.8
local lastUse: { [Player]: number } = {}

local function endsOf(stair: Instance): (CFrame?, CFrame?)
	local ramp = stair:FindFirstChild("SmoothRamp")
	if not ramp then
		return nil, nil
	end
	local parts: { BasePart } = {}
	for _, p in ramp:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	if #parts < 2 then
		return nil, nil
	end
	table.sort(parts, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	local first, last = parts[1], parts[#parts]
	-- a spot just off each end of the ramp, facing along the climb
	local bottomPos = first.Position - first.CFrame.LookVector * (first.Size.Z / 2 + 1.5)
	local topPos = last.Position + last.CFrame.LookVector * (last.Size.Z / 2 + 2)
	local flat = function(v: Vector3): Vector3
		local f = Vector3.new(v.X, 0, v.Z)
		return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, 1)
	end
	local bottom = CFrame.lookAt(bottomPos, bottomPos + flat(first.CFrame.LookVector))
	local top = CFrame.lookAt(topPos, topPos + flat(last.CFrame.LookVector))
	return bottom, top
end

local function makePrompt(cf: CFrame, text: string, dest: CFrame, folder: Instance)
	local anchor = Instance.new("Part")
	anchor.Name = "StairPrompt"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = cf + Vector3.new(0, 2.5, 0)
	anchor.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text
	prompt.ObjectText = "Stairs"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if (lastUse[player] or 0) + COOLDOWN > now then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (character and root and root:IsA("BasePart")) then
			return
		end
		-- must actually be standing at this end of the stairs
		if (root.Position - anchor.Position).Magnitude > 10 then
			return
		end
		lastUse[player] = now
		character:PivotTo(dest + Vector3.new(0, 3, 0))
	end)
end

function StairService.Start()
	local map = Workspace:WaitForChild("Map")
	local lighthouse = map:WaitForChild("Lighthouse")
	local folder = Instance.new("Folder")
	folder.Name = "StairPrompts"
	folder.Parent = lighthouse

	for _, stair in lighthouse:GetDescendants() do
		if stair.Name == "SpiralStair" then
			local bottom, top = endsOf(stair)
			if bottom and top then
				makePrompt(bottom, "Go up", top, folder)
				makePrompt(top, "Go down", bottom, folder)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return StairService
