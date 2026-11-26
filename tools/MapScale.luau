-- Studio tool (ServerStorage.MapScale). Makes the island twice as wide (heights unchanged),
-- scaling around the lighthouse so the tower stays put, then spreads the map objects out
-- to match and fills the extra ground with more trees, bushes, flowers and forage.
-- Run in order, each from its own command bar call (state lives in _G.MapScaleState):
--   local M = require(game.ServerStorage.MapScale:Clone())
--   M.record()                 -- remember how high every object sits above the ground
--   M.copySource()             -- copy the old island terrain out of the way (+6000 x)
--   M.terrainRows(1, 4) ...    -- rebuild dest chunk rows (16 rows of 128 studs)
--   M.clearSource()            -- delete the temporary copy
--   M.ocean()                  -- water out to 2600 studs around the tower
--   M.moveObjects()            -- spread the objects out and re-seat them on the ground
--   M.fill()                   -- extra trees / bushes / flowers / forage
local M = {}
local T = workspace.Terrain
local C = Vector3.new(-10, 0, 150) -- the lighthouse: the centre of the scale
local K = 2
local AIR, WATER = Enum.Material.Air, Enum.Material.Water
local YMIN, YMAX = -40, 40
local SRC_MIN = Vector3.new(-520, YMIN, -300)
local SRC_MAX = Vector3.new(504, YMAX, 620)
local TEMP_OFF = Vector3.new(6000, 0, 0)
local CHUNK = 128

local function dest(v: Vector3): Vector3
	return Vector3.new(C.X + (v.X - C.X) * K, v.Y, C.Z + (v.Z - C.Z) * K)
end
M.dest = dest
local function floor4(x) return 4 * math.floor(x / 4) end
local function ceil4(x) return 4 * math.ceil(x / 4) end
local DST_MIN = Vector3.new(floor4(dest(SRC_MIN).X), YMIN, floor4(dest(SRC_MIN).Z))
local DST_MAX = Vector3.new(ceil4(dest(SRC_MAX).X), YMAX, ceil4(dest(SRC_MAX).Z))
M.DST_MIN, M.DST_MAX = DST_MIN, DST_MAX

local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = { T }
ray.IgnoreWater = true
local function ground(x: number, z: number): (number, Enum.Material?)
	local h = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), ray)
	if h then
		return h.Position.Y, h.Material
	end
	return -28, nil
end
M.ground = ground

local MAP = workspace.Map
-- folders whose children are re-seated one by one on the ground
local SEAT = { "Forage", "Jungle", "Meadow", "PineGrove", "WreckBeach", "TidePools" }
-- folders whose children keep their height (sea level things)
local KEEP_Y = { "Ambience", "FishingWaters" }

local function items(): { Instance }
	local list = {}
	for _, f in SEAT do
		for _, c in MAP[f]:GetChildren() do
			if c:IsA("Model") or c:IsA("BasePart") then
				table.insert(list, c)
			end
		end
	end
	return list
end

function M.record()
	local n = 0
	for _, item in items() do
		local p = (item :: any):GetPivot().Position
		local g = ground(p.X, p.Z)
		item:SetAttribute("_ScaleOff", p.Y - g)
		item:SetAttribute("_ScaleWet", g < 0.3)
		n += 1
		if n % 300 == 0 then
			task.wait()
		end
	end
	return n
end

local function voxRegion(min: Vector3, max: Vector3): Region3int16
	return Region3int16.new(
		Vector3int16.new(min.X / 4, min.Y / 4, min.Z / 4),
		Vector3int16.new(max.X / 4 - 1, max.Y / 4 - 1, max.Z / 4 - 1)
	)
end

function M.copySource()
	local reg = T:CopyRegion(voxRegion(SRC_MIN, SRC_MAX))
	local corner = SRC_MIN + TEMP_OFF
	T:PasteRegion(reg, Vector3int16.new(corner.X / 4, corner.Y / 4, corner.Z / 4), true)
	return "copied"
end

local function chunkCount(): (number, number)
	return math.ceil((DST_MAX.X - DST_MIN.X) / CHUNK), math.ceil((DST_MAX.Z - DST_MIN.Z) / CHUNK)
end
M.chunkCount = chunkCount

-- rebuild one dest chunk from the temporary copy of the old island
function M.terrainChunk(x0: number, z0: number)
	local x1 = math.min(x0 + CHUNK, DST_MAX.X)
	local z1 = math.min(z0 + CHUNK, DST_MAX.Z)
	local sx0, sx1 = C.X + (x0 - C.X) / K, C.X + (x1 - C.X) / K
	local sz0, sz1 = C.Z + (z0 - C.Z) / K, C.Z + (z1 - C.Z) / K
	local rx0 = math.max(floor4(sx0) - 4, SRC_MIN.X)
	local rx1 = math.min(ceil4(sx1) + 4, SRC_MAX.X)
	local rz0 = math.max(floor4(sz0) - 4, SRC_MIN.Z)
	local rz1 = math.min(ceil4(sz1) + 4, SRC_MAX.Z)
	local sm, so = T:ReadVoxels(Region3.new(Vector3.new(rx0, YMIN, rz0) + TEMP_OFF, Vector3.new(rx1, YMAX, rz1) + TEMP_OFF), 4)
	local nx, ny, nz = sm.Size.X, sm.Size.Y, sm.Size.Z
	local dx, dz = (x1 - x0) / 4, (z1 - z0) / 4
	local dm, dov = {}, {}
	for i = 1, dx do
		local mi, oi = {}, {}
		for y = 1, ny do
			mi[y], oi[y] = {}, {}
		end
		dm[i], dov[i] = mi, oi
	end
	for i = 1, dx do
		local xs = C.X + (x0 + (i - 0.5) * 4 - C.X) / K
		local fi = (xs - rx0) / 4 + 0.5
		local a0 = math.clamp(math.floor(fi), 1, nx)
		local a1 = math.clamp(a0 + 1, 1, nx)
		local tx = math.clamp(fi - math.floor(fi), 0, 1)
		for k = 1, dz do
			local zs = C.Z + (z0 + (k - 0.5) * 4 - C.Z) / K
			local fk = (zs - rz0) / 4 + 0.5
			local b0 = math.clamp(math.floor(fk), 1, nz)
			local b1 = math.clamp(b0 + 1, 1, nz)
			local tz = math.clamp(fk - math.floor(fk), 0, 1)
			local w00, w10, w01, w11 = (1 - tx) * (1 - tz), tx * (1 - tz), (1 - tx) * tz, tx * tz
			local top = 0
			local topMat = Enum.Material.Ground
			for y = 1, ny do
				local occ, best, bw = 0, nil, -1
				local m = sm[a0][y][b0]
				if m ~= AIR and m ~= WATER then occ += so[a0][y][b0] * w00; if w00 > bw then best, bw = m, w00 end end
				m = sm[a1][y][b0]
				if m ~= AIR and m ~= WATER then occ += so[a1][y][b0] * w10; if w10 > bw then best, bw = m, w10 end end
				m = sm[a0][y][b1]
				if m ~= AIR and m ~= WATER then occ += so[a0][y][b1] * w01; if w01 > bw then best, bw = m, w01 end end
				m = sm[a1][y][b1]
				if m ~= AIR and m ~= WATER then occ += so[a1][y][b1] * w11; if w11 > bw then best, bw = m, w11 end end
				if occ > 0.03 and best then
					dm[i][y][k] = best
					dov[i][y][k] = math.min(occ, 1)
					top = y
					topMat = best
				end
			end
			-- solid underneath (the old island was a thin crust over a hollow)
			local under = if topMat == Enum.Material.Grass or topMat == Enum.Material.LeafyGrass then Enum.Material.Ground else topMat
			for y = 1, ny do
				if y < top then
					if dm[i][y][k] == nil then
						dm[i][y][k] = under
					end
					dov[i][y][k] = 1
				elseif dm[i][y][k] == nil then
					local ybot = YMIN + (y - 1) * 4
					if ybot < 0 then
						dm[i][y][k], dov[i][y][k] = WATER, 1
					else
						dm[i][y][k], dov[i][y][k] = AIR, 0
					end
				end
			end
		end
	end
	T:WriteVoxels(Region3.new(Vector3.new(x0, YMIN, z0), Vector3.new(x1, YMAX, z1)), 4, dm, dov)
end

-- rows of chunks, each row yields once (rows are along z)
function M.terrainRows(r0: number, r1: number)
	local cx, cz = chunkCount()
	for r = r0, math.min(r1, cz) do
		for c = 1, cx do
			M.terrainChunk(DST_MIN.X + (c - 1) * CHUNK, DST_MIN.Z + (r - 1) * CHUNK)
		end
		task.wait()
	end
	return string.format("rows %d-%d of %d done", r0, math.min(r1, cz), cz)
end

function M.clearSource()
	T:FillRegion(Region3.new(SRC_MIN + TEMP_OFF, SRC_MAX + TEMP_OFF), 4, AIR)
	return "cleared"
end

function M.ocean(radius: number?)
	local R = radius or 2600
	for x = C.X - R, C.X + R - 1, 400 do
		for z = C.Z - R, C.Z + R - 1, 400 do
			local reg = Region3.new(Vector3.new(x, -24, z), Vector3.new(x + 400, 0, z + 400)):ExpandToGrid(4)
			T:ReplaceMaterial(reg, 4, AIR, WATER)
		end
		task.wait()
	end
	return "ocean ok"
end

function M.moveObjects()
	local n = 0
	for _, item in items() do
		local cf = (item :: any):GetPivot()
		local np = dest(cf.Position)
		local y = cf.Y
		if not item:GetAttribute("_ScaleWet") then
			y = ground(np.X, np.Z) + (item:GetAttribute("_ScaleOff") or 0)
		end
		(item :: any):PivotTo(CFrame.new(np.X, y, np.Z) * cf.Rotation)
		item:SetAttribute("_ScaleOff", nil)
		item:SetAttribute("_ScaleWet", nil)
		n += 1
		if n % 300 == 0 then
			task.wait()
		end
	end
	for _, f in KEEP_Y do
		for _, c in MAP[f]:GetChildren() do
			if c:IsA("BasePart") or c:IsA("Model") then
				local cf = (c :: any):GetPivot()
				local np = dest(cf.Position);
				(c :: any):PivotTo(CFrame.new(np) * cf.Rotation)
			end
		end
	end
	-- the dock moves as one piece, keeping its shore end on the (new) shore
	local dock = MAP.OldDock
	local shore, best = nil, math.huge
	for _, d in dock:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.Position
			local dist = Vector2.new(p.X - C.X, p.Z - C.Z).Magnitude
			if dist < best then
				shore, best = p, dist
			end
		end
	end
	if shore then
		local move = dest(shore) - shore
		move = Vector3.new(move.X, 0, move.Z)
		for _, c in dock:GetChildren() do
			if c:IsA("BasePart") or c:IsA("Model") then
				(c :: any):PivotTo((c :: any):GetPivot() + move)
			end
		end
	end
	return n
end

-- extra copies to fill the bigger island: {folder, names, copies per original, min spacing, sand ok}
M.FILL = {
	{ "PineGrove", { Pine = true, Oak = true }, 2, 10, false },
	{ "Jungle", { Bush = true, Fern = true }, 2, 6, false },
	{ "Meadow", { Flowers = true, Rock = true, FallenLog = true }, 2, 5, true },
	{ "Forage", { BerryBush = true, AppleTree = true, PumpkinPatch = true, Mushrooms = true, CarrotPatch = true }, 2, 7, false },
}

function M.fill(seed: number?)
	local rng = Random.new(seed or 42)
	local made = 0
	for _, spec in M.FILL do
		local folder, names, copies, spacing, sandOk = MAP[spec[1]], spec[2], spec[3], spec[4], spec[5]
		-- spatial hash of what is already there
		local cell = spacing
		local grid: { [string]: { Vector3 } } = {}
		local function key(x, z) return math.floor(x / cell) .. "," .. math.floor(z / cell) end
		local function add(p: Vector3)
			local k = key(p.X, p.Z)
			grid[k] = grid[k] or {}
			table.insert(grid[k], p)
		end
		local function clear(p: Vector3): boolean
			local cx, cz = math.floor(p.X / cell), math.floor(p.Z / cell)
			for ix = cx - 1, cx + 1 do
				for iz = cz - 1, cz + 1 do
					for _, q in grid[ix .. "," .. iz] or {} do
						if (Vector2.new(q.X - p.X, q.Z - p.Z)).Magnitude < spacing then
							return false
						end
					end
				end
			end
			return true
		end
		local originals = {}
		for _, c in folder:GetChildren() do
			if (c:IsA("Model") or c:IsA("BasePart")) then
				add((c :: any):GetPivot().Position)
				if names[c.Name] then
					table.insert(originals, c)
				end
			end
		end
		for idx, orig in originals do
			local base = (orig :: any):GetPivot()
			local g0 = ground(base.X, base.Z)
			local off = base.Y - g0
			for _ = 1, copies do
				for _try = 1, 8 do
					local ang = rng:NextNumber(0, math.pi * 2)
					local r = rng:NextNumber(spacing, spacing * 3.2)
					local x, z = base.X + math.cos(ang) * r, base.Z + math.sin(ang) * r
					if Vector2.new(x - C.X, z - C.Z).Magnitude > 60 then
						local gy, mat = ground(x, z)
						local okMat = mat ~= nil and mat ~= WATER and (sandOk or mat ~= Enum.Material.Sand)
						if okMat and gy > 1.5 and clear(Vector3.new(x, 0, z)) then
							local copy = orig:Clone()
							local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0);
							(copy :: any):PivotTo(CFrame.new(x, gy + off, z) * yaw * base.Rotation)
							if copy:IsA("Model") then
								pcall(function()
									copy:ScaleTo(copy:GetScale() * rng:NextNumber(0.85, 1.15))
								end)
							end
							copy.Parent = folder
							add(Vector3.new(x, 0, z))
							made += 1
							break
						end
					end
				end
			end
			if idx % 40 == 0 then
				task.wait()
			end
		end
	end
	return made
end

return M
