-- Cartoon (99 Nights style) forest: blocky layered pines with buttress roots, cube bushes.
-- Studio tool, lives in ServerStorage.CartoonForest. Every tree has a "Trunk" part so
-- ResourceService can put the Chop prompt on it.
--
-- Usage from the command bar (clone so edits to the module are picked up):
--   local F = require(game.ServerStorage.CartoonForest:Clone())
--   local rng = Random.new(1)
--   local g = F.ground(x, z)            -- nil on water / sand / rock / steep ground
--   if g then F.pine(g, rng).Parent = workspace.Map.PineGrove end
local F = {}
local WOOD = {Color3.fromRGB(96, 66, 44), Color3.fromRGB(84, 58, 40), Color3.fromRGB(104, 74, 50)}
local PINE = {Color3.fromRGB(42, 88, 50), Color3.fromRGB(36, 78, 46), Color3.fromRGB(50, 98, 56), Color3.fromRGB(46, 84, 44)}
local LEAF = {Color3.fromRGB(78, 132, 58), Color3.fromRGB(66, 120, 52), Color3.fromRGB(90, 142, 64)}
local BUSH = {Color3.fromRGB(58, 112, 52), Color3.fromRGB(70, 124, 56), Color3.fromRGB(50, 100, 48), Color3.fromRGB(82, 134, 60)}

local function pick(rng, t) return t[rng:NextInteger(1, #t)] end
local function shade(c, rng, a) local k = 1 + rng:NextNumber(-a, a) return Color3.new(math.clamp(c.R*k,0,1), math.clamp(c.G*k,0,1), math.clamp(c.B*k,0,1)) end
local function part(parent, name, size, cf, color, collide, cls)
  local p = Instance.new(cls or "Part")
  p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
  p.Material = Enum.Material.SmoothPlastic; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
  p.CanCollide = collide; p.CanTouch = false; p.CanQuery = collide; p.Parent = parent
  return p
end

local function roots(m, base, tw, rng, wood)
  for i = 0, 3 do
    local a = math.rad(i * 90 + rng:NextNumber(-12, 12))
    local h = rng:NextNumber(2.6, 4.2); local len = rng:NextNumber(2.2, 3.4)
    local dir = CFrame.Angles(0, a, 0)
    -- wedge slopes down and away from the trunk
    local cf = base * dir * CFrame.new(0, h/2 - 0.3, -(tw/2 + len/2 - 0.2)) * CFrame.Angles(0, math.pi, 0)
    part(m, "Root", Vector3.new(tw * 0.6, h, len), cf, shade(wood, rng, 0.08), false, "WedgePart")
  end
end

function F.pine(pos, rng, scale)
  scale = scale or rng:NextNumber(0.85, 1.35)
  local m = Instance.new("Model"); m.Name = "Pine"
  local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi*2), 0)
  local tw = 2.2 * scale
  local th = rng:NextNumber(30, 40) * scale
  local wood = pick(rng, WOOD)
  part(m, "Trunk", Vector3.new(tw, th * 0.62, tw), base * CFrame.new(0, th * 0.31 - 0.5, 0), wood, true)
  roots(m, base, tw, rng, wood)
  local green = pick(rng, PINE)
  local tiers = rng:NextInteger(4, 5)
  local y0 = th * 0.3
  local span = th - y0
  for i = 0, tiers - 1 do
    local f = i / tiers
    local w = (15 - 10.5 * f) * scale * rng:NextNumber(0.92, 1.08)
    local y = y0 + span * f
    local h = (span / tiers) * 0.95
    local rot = CFrame.Angles(0, (i % 2) * math.rad(45) + rng:NextNumber(-0.15, 0.15), 0)
    -- wide skirt + narrower cap so each tier reads as a stepped block
    part(m, "Leaves", Vector3.new(w, h * 0.55, w), base * CFrame.new(0, y + h*0.27, 0) * rot, shade(green, rng, 0.06), false)
    part(m, "Leaves", Vector3.new(w * 0.68, h * 0.6, w * 0.68), base * CFrame.new(0, y + h*0.8, 0) * rot * CFrame.Angles(0, math.rad(45), 0), shade(green, rng, 0.08), false)
  end
  part(m, "Leaves", Vector3.new(2.4, 3.2, 2.4) * scale, base * CFrame.new(0, th + 1.2*scale, 0) * CFrame.Angles(0, math.rad(45), 0), shade(green, rng, 0.05), false)
  m.WorldPivot = base
  return m
end

function F.leafy(pos, rng, scale)
  scale = scale or rng:NextNumber(0.9, 1.25)
  local m = Instance.new("Model"); m.Name = "Oak"
  local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi*2), 0)
  local tw = 2.6 * scale; local th = rng:NextNumber(13, 17) * scale
  local wood = pick(rng, WOOD)
  part(m, "Trunk", Vector3.new(tw, th, tw), base * CFrame.new(0, th/2 - 0.5, 0), wood, true)
  roots(m, base, tw, rng, wood)
  local green = pick(rng, LEAF)
  local c = base * CFrame.new(0, th + 3*scale, 0)
  part(m, "Leaves", Vector3.new(13, 8, 13) * scale, c, shade(green, rng, 0.05), false)
  for _ = 1, rng:NextInteger(3, 5) do
    local a = rng:NextNumber(0, math.pi*2)
    local s = rng:NextNumber(5, 8) * scale
    part(m, "Leaves", Vector3.new(s, s*0.8, s), c * CFrame.new(math.cos(a)*6*scale, rng:NextNumber(-1, 4)*scale, math.sin(a)*6*scale) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), shade(green, rng, 0.1), false)
  end
  m.WorldPivot = base
  return m
end

function F.bush(pos, rng)
  local m = Instance.new("Model"); m.Name = "Bush"
  local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi*2), 0)
  local green = pick(rng, BUSH)
  local s = rng:NextNumber(3.2, 5)
  part(m, "Leaf", Vector3.new(s, s*0.85, s), base * CFrame.new(0, s*0.38, 0), shade(green, rng, 0.06), false)
  for _ = 1, rng:NextInteger(0, 2) do
    local t = s * rng:NextNumber(0.55, 0.8)
    part(m, "Leaf", Vector3.new(t, t*0.85, t), base * CFrame.new(rng:NextNumber(-s*0.6, s*0.6), t*0.35, rng:NextNumber(-s*0.6, s*0.6)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), shade(green, rng, 0.1), false)
  end
  m.WorldPivot = base
  return m
end

local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.IgnoreWater = false
function F.ground(x, z)
  params.FilterDescendantsInstances = {workspace.Terrain}
  local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
  if not r or r.Material == Enum.Material.Water or r.Material == Enum.Material.Sand or r.Material == Enum.Material.Rock or r.Material == Enum.Material.Basalt then return nil end
  if r.Normal.Y < 0.8 then return nil end
  return r.Position
end
return F
