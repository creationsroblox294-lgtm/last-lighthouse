--!nocheck
-- Run after BuildLighthouse. CSG unions keep a convex "Default" collision hull that fills the
-- stair holes (CollisionFidelity can't be set from the command bar), so the holed slabs are made
-- non-collidable and get invisible run-length-merged collision strips with the stairwell left open.
local L = workspace.Map.Lighthouse
local C = Vector3.new(55, 0, -80)

local function inOct(x, z, a)
	for k = 0, 7 do
		local th = math.rad(k * 45)
		if x * math.sin(th) + z * math.cos(th) > a then
			return false
		end
	end
	return true
end

local function inHole(x, z, st)
	local dx, dz = x - st.x, z - st.z
	local r = math.sqrt(dx * dx + dz * dz)
	if r < 1.3 then
		return true
	end
	if r > st.R + 0.6 then
		return false
	end
	local a = math.deg(math.atan2(dx, dz))
	local a0 = st.k * 45 + st.s * (8.5 - 12) * 24
	local a1 = st.k * 45 + st.s * (15.5 - 12) * 24
	local lo, hi = math.min(a0, a1), math.max(a0, a1)
	local margin = math.deg(0.5 / math.max(r, 0.5))
	for _, off in { -360, 0, 360 } do
		if a + off >= lo - margin and a + off <= hi + margin then
			return true
		end
	end
	return false
end

local function collider(parent, name, a, yTop, t, st)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	local cell = 1
	for zi = -a, a - cell, cell do
		local runStart = nil
		for xi = -a, a, cell do
			local cx, cz = xi + cell / 2, zi + cell / 2
			local solid = xi < a and inOct(cx, cz, a - 0.1)
			if solid and st then
				for _, c in { { cx, cz }, { xi, zi }, { xi + cell, zi }, { xi, zi + cell }, { xi + cell, zi + cell } } do
					if inHole(c[1], c[2], st) then
						solid = false
						break
					end
				end
			end
			if solid and not runStart then
				runStart = xi
			end
			if not solid and runStart then
				local p = Instance.new("Part")
				p.Name = "FloorCollision"
				p.Anchored = true
				p.Transparency = 1
				p.CastShadow = false
				p.Size = Vector3.new(xi - runStart, t, cell)
				p.CFrame = CFrame.new(C.X + (runStart + xi) / 2, yTop - t / 2, C.Z + zi + cell / 2)
				p.Parent = f
				runStart = nil
			end
		end
	end
	f.Parent = parent
end

collider(L.BunkRoom, "FloorCollision", 13.0, 52.2, 1, { x = 4.24, z = -4.24, R = 4.5, k = 3, s = -1 })
collider(L.LampRoom, "DeckCollision", 14.9, 68.4, 1, { x = -2.83, z = -2.83, R = 3.8, k = 5, s = 1 })
for _, p in { L.BunkRoom.Floor, L.LampRoom.GalleryDeck, L.LampRoom.Floor } do
	p.CanCollide = false
	p.CanQuery = false
end
