-- Studio tool (ServerStorage.IslandShape). Breaks up the round coastline: big peninsulas
-- and bays plus low-frequency wobble. Uses IslandExpand for the old edge / hill heights.
-- Protected angles keep their shore (wreck beach, tide pools, the dock).
-- Run: local S = require(game.ServerStorage.IslandShape:Clone()); S.strip(-460, 460)
-- (split into a few calls: each strip of x columns yields once).
local X = require(game.ServerStorage.IslandExpand:Clone())
local S = {}
local T = workspace.Terrain
local CEN = Vector2.new(0, 170)
local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Include; ray.FilterDescendantsInstances = { T }; ray.IgnoreWater = false
local function smooth(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
-- {angle deg, amount studs (+ out / - in), width deg}
S.FEATURES = {
	{ 35, 115, 11 },   -- south-east peninsula
	{ 62, -55, 7 },    -- cove beside it
	{ 100, -85, 9 },   -- south bay
	{ 150, 95, 13 },   -- south-west headland
	{ 192, -75, 8 },   -- west bay
	{ -55, -65, 8 },   -- north-east inlet
	{ -160, 60, 9 },   -- north-west point
}
S.PROTECT = { -- angles (deg) that keep the old shore: wreck beach, tide pools, the dock
	{ -132, 22 }, { -10, 20 }, { -95, 26 },
}
local function adiff(a, b) return (a - b + 180) % 360 - 180 end
function S.edge(x, z)
	local a = math.deg(math.atan2(z - CEN.Y, x - CEN.X))
	local base = X.edge(x, z)
	local ar = math.rad(a)
	local delta = math.noise(math.cos(ar) * 1.4, math.sin(ar) * 1.4, 17.7) * 55 + math.noise(math.cos(ar) * 3.5, math.sin(ar) * 3.5, 23.1) * 18
	for _, f in S.FEATURES do
		local d = adiff(a, f[1]) / f[3]
		delta += f[2] * math.exp(-d * d)
	end
	local keep = 1
	for _, p in S.PROTECT do keep = math.min(keep, smooth((math.abs(adiff(a, p[1])) - p[2] * 0.5) / (p[2] * 0.5))) end
	return base + delta * keep, base
end
local function beachH(inland) return 0.4 + (math.clamp(inland, 0, 26) / 26) ^ 0.8 * 5.6 end
local function write(x, z, h, mat)
	T:FillBlock(CFrame.new(x, (h + 60) / 2, z), Vector3.new(4, 60 - h, 4), Enum.Material.Air)
	T:FillBlock(CFrame.new(x, (h - 28) / 2, z), Vector3.new(4, h + 28, 4), mat)
end
function S.column(x, z)
	local d = (Vector2.new(x, z) - CEN).Magnitude
	local e2, e1 = S.edge(x, z)
	if d < math.min(e1, e2) - 34 or d > math.max(e1, e2) + 6 then return 0 end
	if X.streamDist(x, z) < 14 then return 0 end
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -260, 0), ray)
	local water = (not hit) or hit.Material == Enum.Material.Water or hit.Position.Y < 0.3
	local curH = hit and hit.Position.Y or -22
	if d < e2 then
		local inland = e2 - d
		if inland < 26 then
			local h = beachH(inland)
			if water or math.abs(curH - h) > 0.8 or hit.Material ~= Enum.Material.Sand then write(x, z, h, Enum.Material.Sand); return 1 end
		else
			if water or hit.Material == Enum.Material.Sand then
				local h = math.max(X.height(x, z, inland), 6)
				if not water then h = math.max(h, curH) end
				write(x, z, h, Enum.Material.Grass); return 1
			end
		end
		return 0
	else
		if water then return 0 end
		local floorY = -1.5 - math.min(20, (d - e2) * 0.45)
		T:FillBlock(CFrame.new(x, 30, z), Vector3.new(4, 60, 4), Enum.Material.Air)
		T:FillBlock(CFrame.new(x, floorY / 2, z), Vector3.new(4, -floorY, 4), Enum.Material.Water)
		T:FillBlock(CFrame.new(x, (floorY - 28) / 2, z), Vector3.new(4, floorY + 28, 4), Enum.Material.Sand)
		return 1
	end
end
function S.strip(x0, x1)
	local n = 0
	for x = x0, x1, 4 do
		for z = -300, 640, 4 do n += S.column(x, z) end
		task.wait()
	end
	return n
end
return S
