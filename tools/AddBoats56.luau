--!strict
-- Adds Boat5 and Boat6 to the harbor: moored stern-to off the T-head at the end of the dock,
-- bows out to sea, so they row straight out without crossing the other boats' paths.
-- Run once in Studio (Edit) after tools/BuildLobby.luau + tools/BuildLobbyBoards.luau.
-- Clones Boat1 / Boat3 (with their PadGlow, lantern, benches, seats) and re-makes the parts
-- that join a boat to the dock: gangplank, exit point, sign, sign post and mooring post.

local lobby = workspace:WaitForChild("Lobby")
local boats = lobby:WaitForChild("Boats")
local dock = lobby:WaitForChild("Dock")

local DECK_Y = 3.2 -- dock planks (tools/BuildLobby.luau)
local HEAD_EDGE_X = 3172.6 -- the T-head's far (sea-side) edge, where its pilings stand
local BOAT_X = HEAD_EDGE_X - 11.6 -- hull centre: the stern just clears the pilings

local SPOTS = {
	{ name = "Boat5", number = 5, from = "Boat1", z = -12 },
	{ name = "Boat6", number = 6, from = "Boat3", z = 12 },
}

local function nearest(folder: Instance, name: string, to: Vector3): BasePart?
	local best, bestD = nil, math.huge
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") and p.Name == name then
			local d = (p.Position - to).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

for _, spot in SPOTS do
	local old = boats:FindFirstChild(spot.name)
	if old then
		old:Destroy()
	end
	local src = boats:FindFirstChild(spot.from) :: Model
	local srcBase = src:GetAttribute("BaseCFrame") :: CFrame
	local base = CFrame.new(BOAT_X, srcBase.Position.Y, spot.z) * srcBase.Rotation
	local boat = src:Clone()
	boat.Name = spot.name
	boat:SetAttribute("Number", spot.number)
	boat:SetAttribute("Count", nil)
	boat:SetAttribute("Capacity", nil)
	boat:SetAttribute("CastOffAt", nil)
	boat:SetAttribute("BaseCFrame", base)
	local shift = base * srcBase:Inverse()
	for _, d in boat:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = shift * d.CFrame
		end
	end

	-- from the T-head down to the stern
	local top = Vector3.new(HEAD_EDGE_X + 0.8, DECK_Y + 0.05, spot.z)
	local stern = (base * CFrame.new(0, -1.3, 8.2)).Position
	local gp = boat:FindFirstChild("Gangplank") :: BasePart
	gp.Size = Vector3.new(3, 0.3, (top - stern).Magnitude + 0.6)
	gp.CFrame = CFrame.lookAt((top + stern) / 2, top)

	-- where you're put back when you leave the boat
	local exit = boat:FindFirstChild("Exit") :: BasePart
	exit.CFrame = CFrame.new(HEAD_EDGE_X + 4.5, DECK_Y + 3, spot.z)

	-- the sign, on a post at the side of the boarding spot
	local sideZ = spot.z + (if spot.z < 0 then 4.2 else -4.2)
	local sign = boat:FindFirstChild("Sign") :: BasePart
	sign.CFrame = CFrame.new(HEAD_EDGE_X + 2.2, DECK_Y + 5.6, sideZ)
	local srcPost = nearest(dock, "SignPost", (srcBase * CFrame.new(-7.4, 3, 6)).Position)
	if srcPost then
		local post = srcPost:Clone()
		post.Name = "SignPost"
		post.CFrame = CFrame.new(HEAD_EDGE_X + 2.2, DECK_Y + 3, sideZ)
		post.Parent = dock
	end

	-- mooring: a short post on the T-head's edge, roped to the stern
	local rope = boat:FindFirstChildWhichIsA("RopeConstraint", true)
	if rope then
		local srcMoor = rope.Attachment1 and rope.Attachment1.Parent
		local moor: BasePart
		if srcMoor and srcMoor:IsA("BasePart") then
			moor = srcMoor:Clone()
			for _, c in moor:GetChildren() do
				c:Destroy()
			end
		else
			moor = Instance.new("Part")
			moor.Size = Vector3.new(0.7, 2, 0.7)
			moor.Material = Enum.Material.Wood
			moor.Anchored = true
		end
		moor.Name = "MooringPost"
		moor.CFrame = CFrame.new(HEAD_EDGE_X + 0.9, DECK_Y + 1, spot.z - sideZ + spot.z)
		moor.Parent = dock
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0.6, 0)
		a1.Parent = moor
		local a0 = rope.Attachment0
		if a0 then
			a0.CFrame = CFrame.new(0, 0.8, 8)
		end
		rope.Attachment1 = a1
		rope.Length = 5
	end
	boat.Parent = boats

	-- open the rope rail on the T-head where you step down into the boat
	for _, p in dock:GetChildren() do
		if p:IsA("BasePart") and math.abs(p.Position.X - HEAD_EDGE_X) < 0.3 and p.Size.Z > 7
			and math.abs(p.Position.Y - (DECK_Y + 1.6)) < 0.3 and math.abs(p.Position.Z - spot.z) < 1 then
			p:Destroy()
		end
	end
end

return "Boat5 and Boat6 added"
