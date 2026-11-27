--!strict
-- Ember Storm (Severe): a smoky orange sky, a hot wind (Workspace "WindDir") full of glowing
-- embers (Blender: ember) and ash. Dry lightning cracks down into the pines (StormEvent
-- "TreeStrike") and they go up: trees with the attribute "Burning" roar with flame, pour black
-- smoke, throw sparks downwind and light the ground orange, while their needles char black. Beat a
-- fire out (StormEvent "FireOut") and it dies in a hiss of steam; leave it and it collapses in a
-- burst of ash and sparks (StormEvent "BurntDown"). Sparks land as spot fires on the ground near
-- you (StormEvent "Embers"). Too close to the heat (player attribute "Scorched") and the edges of
-- the screen glow and swim.
-- Textures: Blender (Ember Storm: ember) + Rolling Thunder flame/smoke, Drizzle haze, Silent Fog
-- vignette, Lucky Lightning spark.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local FIRE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 30, 10)),
})
local CHAR = Color3.fromRGB(35, 25, 20)

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer
	local windDir: Vector3 = (Workspace:GetAttribute("WindDir") :: Vector3?) or Vector3.new(1, 0, 0)

	local embers = Common.around(ctx, "Embers", Vector3.new(110, 40, 110), {
		Texture = Common.tex(ctx, "Ember"),
		Rate = 60,
		Brightness = 3,
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 70)),
		Size = ns(0, 0.3, 0.5, 0.5, 1, 0),
		Transparency = ns(0, 1, 0.1, 0, 0.8, 0, 1, 1),
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(1, 3),
		Acceleration = windDir * 14 + Vector3.new(0, 3, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	Common.around(ctx, "Ash", Vector3.new(90, 30, 90), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 40,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(90, 80, 75)),
		Size = ns(0, 0.25, 1, 0.2),
		Transparency = ns(0, 1, 0.1, 0.2, 0.8, 0.2, 1, 1),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = windDir * 5 + Vector3.new(0, -1.5, 0),
		RotSpeed = NumberRange.new(-200, 200),
	})
	Common.around(ctx, "Smoke", Vector3.new(220, 40, 220), {
		Texture = Common.tex(ctx, "Smoke"),
		Rate = 6,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(110, 70, 55)),
		Size = ns(0, 30, 1, 55),
		Transparency = ns(0, 1, 0.3, 0.75, 0.7, 0.75, 1, 1),
		Lifetime = NumberRange.new(6, 8),
		Speed = NumberRange.new(2, 4),
		Acceleration = windDir * 3,
		Offset = Vector3.new(0, 30, 0),
	})
	Common.clouds(ctx, { Cover = 0.85, Density = 0.65, Color = Color3.fromRGB(120, 65, 45) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 205, 170),
		Saturation = 0.05,
		Brightness = -0.02,
		Contrast = 0.2,
		Bloom = 1,
		BloomThreshold = 0.9,
	})
	local _ = embers

	-- burning trees
	type Blaze = { tree: Model, holder: BasePart, light: PointLight, flames: ParticleEmitter, leaves: { { part: BasePart, color: Color3 } }, since: number }
	local blazes: { [Model]: Blaze } = {}
	local function charLeaves(tree: Model): { { part: BasePart, color: Color3 } }
		local list = {}
		for _, p in tree:GetChildren() do
			if p.Name == "Leaves" and p:IsA("BasePart") then
				table.insert(list, { part = p, color = p.Color })
			end
		end
		return list
	end
	local function canopy(tree: Model): CFrame
		local trunk = tree:FindFirstChild("Trunk")
		if trunk and trunk:IsA("BasePart") then
			return CFrame.new(trunk.Position + Vector3.new(0, trunk.Size.Y * 0.25, 0))
		end
		return tree:GetPivot()
	end
	local function startBlaze(tree: Model)
		if blazes[tree] then
			return
		end
		-- a box wrapped round the canopy: the flames pour off its surface, so they lick out of the
		-- needles instead of hiding inside them
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, p in tree:GetChildren() do
			if p.Name == "Leaves" and p:IsA("BasePart") then
				lo = lo:Min(p.Position - p.Size / 2)
				hi = hi:Max(p.Position + p.Size / 2)
			end
		end
		local holder = Common.part(ctx, "Blaze", Vector3.new(10, 18, 10))
		if lo.X < math.huge then
			holder.Size = (hi - lo) + Vector3.new(2, 4, 2)
			holder.CFrame = CFrame.new((lo + hi) / 2)
		else
			holder.CFrame = canopy(tree)
		end
		local flames = Instance.new("ParticleEmitter")
		flames.Texture = Common.tex(ctx, "Flame")
		flames.Color = FIRE
		flames.LightEmission = 1
		flames.Brightness = 2
		flames.Size = ns(0, 4, 0.5, 8, 1, 2.5)
		flames.Transparency = ns(0, 0.25, 0.8, 0.5, 1, 1)
		flames.Lifetime = NumberRange.new(0.6, 1.1)
		flames.Speed = NumberRange.new(3, 7)
		flames.Shape = Enum.ParticleEmitterShape.Box
		flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		flames.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		flames.Acceleration = windDir * 6 + Vector3.new(0, 14, 0)
		flames.RotSpeed = NumberRange.new(-60, 60)
		flames.Rotation = NumberRange.new(0, 360)
		flames.Rate = 90
		flames.Parent = holder
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = Common.tex(ctx, "Smoke")
		smoke.Color = ColorSequence.new(Color3.fromRGB(60, 45, 40), Color3.fromRGB(30, 25, 25))
		smoke.LightInfluence = 1
		smoke.Size = ns(0, 6, 1, 22)
		smoke.Transparency = ns(0, 0.4, 1, 1)
		smoke.Lifetime = NumberRange.new(4, 6)
		smoke.Speed = NumberRange.new(8, 14)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Acceleration = windDir * 5
		smoke.RotSpeed = NumberRange.new(-20, 20)
		smoke.Rate = 8
		smoke.Parent = holder
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Common.tex(ctx, "Ember")
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90))
		sparks.LightEmission = 1
		sparks.Brightness = 3
		sparks.Size = ns(0, 0.4, 1, 0)
		sparks.Lifetime = NumberRange.new(1.5, 3)
		sparks.Speed = NumberRange.new(8, 16)
		sparks.SpreadAngle = Vector2.new(40, 40)
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Acceleration = windDir * 12
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.Rate = 25
		sparks.Parent = holder
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 50)
		light.Range = 36
		light.Brightness = 3
		light.Shadows = false
		light.Parent = holder
		blazes[tree] = { tree = tree, holder = holder, light = light, flames = flames, leaves = charLeaves(tree), since = os.clock() }
	end
	local function endBlaze(tree: Model, restore: boolean)
		local b = blazes[tree]
		if not b then
			return
		end
		blazes[tree] = nil
		for _, e in b.holder:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Rate = 0
			end
		end
		Common.tween(b.light, 1.5, { Brightness = 0 })
		task.delay(6, function()
			b.holder:Destroy()
		end)
		-- the needles recover (slowly if it was beaten out; at once if the tree's gone, so it
		-- regrows green)
		for _, l in b.leaves do
			if l.part.Parent then
				if restore then
					Common.tween(l.part, 3, { Color = l.color })
				else
					l.part.Color = l.color
				end
			end
		end
	end
	local conns: { RBXScriptConnection } = {}
	local map = Workspace:FindFirstChild("Map")
	local grove = map and map:FindFirstChild("PineGrove")
	if grove then
		for _, t in grove:GetChildren() do
			if t:IsA("Model") then
				if t:GetAttribute("Burning") then
					startBlaze(t)
				end
				table.insert(conns, t:GetAttributeChangedSignal("Burning"):Connect(function()
					if t:GetAttribute("Burning") then
						startBlaze(t)
					else
						endBlaze(t, t:GetAttribute("Felled") ~= true)
					end
				end))
			end
		end
	end
	table.insert(ctx.cleanup, function()
		for _, c in conns do
			c:Disconnect()
		end
		local all = {}
		for t in blazes do
			table.insert(all, t)
		end
		for _, t in all do
			endBlaze(t, true)
		end
	end)

	local function bolt(from: Vector3, to: Vector3)
		local segs = 9
		local prev = from
		for k = 1, segs do
			local p = from:Lerp(to, k / segs)
			if k < segs then
				p += Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)) * 14
			end
			local seg = Common.boltSegment(ctx, prev, p, 1.2, Color3.fromRGB(255, 230, 200), Color3.fromRGB(255, 140, 60), 0.6)
			Common.tween(seg, 0.45, { Transparency = 1 })
			task.delay(0.6, function()
				seg:Destroy()
			end)
			prev = p
		end
	end
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "EmberFlash"
	flash.Parent = Lighting
	local flashLevel = 0
	local function puff(at: Vector3, color: Color3, count: number, up: number)
		local holder = Common.part(ctx, "Puff", Vector3.new(8, 8, 8))
		holder.CFrame = CFrame.new(at)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.tex(ctx, "Smoke")
		e.Color = ColorSequence.new(color)
		e.LightInfluence = 1
		e.Size = ns(0, 6, 1, 18)
		e.Transparency = ns(0, 0.3, 1, 1)
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(up * 0.5, up)
		e.SpreadAngle = Vector2.new(60, 60)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 0
		e.Parent = holder
		e:Emit(count)
		task.delay(3, function()
			holder:Destroy()
		end)
	end

	-- spot fires
	local function spotFire(at: Vector3, seconds: number, radius: number)
		local holder = Common.part(ctx, "SpotFire", Vector3.new(radius * 2, 1, radius * 2))
		holder.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
		local f = Instance.new("ParticleEmitter")
		f.Texture = Common.tex(ctx, "Flame")
		f.Color = FIRE
		f.LightEmission = 1
		f.Size = ns(0, 1.5, 0.5, 3, 1, 0.5)
		f.Transparency = ns(0, 0.3, 1, 1)
		f.Lifetime = NumberRange.new(0.4, 0.8)
		f.Speed = NumberRange.new(3, 6)
		f.SpreadAngle = Vector2.new(15, 15)
		f.EmissionDirection = Enum.NormalId.Top
		f.Acceleration = windDir * 4
		f.Rate = 40
		f.Parent = holder
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 140, 50)
		l.Range = 18
		l.Brightness = 2
		l.Parent = holder
		-- the embers come down first
		local fall = Instance.new("ParticleEmitter")
		fall.Texture = Common.tex(ctx, "Ember")
		fall.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90))
		fall.LightEmission = 1
		fall.Size = ns(0, 0.5, 1, 0.2)
		fall.Lifetime = NumberRange.new(0.6, 0.9)
		fall.Speed = NumberRange.new(20, 30)
		fall.EmissionDirection = Enum.NormalId.Bottom
		fall.Orientation = Enum.ParticleOrientation.VelocityParallel
		fall.Rate = 0
		fall.Parent = holder
		task.delay(seconds, function()
			f.Rate = 0
			Common.tween(l, 1, { Brightness = 0 })
		end)
		task.delay(seconds + 2, function()
			holder:Destroy()
		end)
	end

	-- scorched: glowing, swimming edges
	local gui = Instance.new("ScreenGui")
	gui.Name = "Scorch"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local edge = Instance.new("ImageLabel")
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Image = Common.tex(ctx, "Vignette")
	edge.ImageColor3 = Color3.fromRGB(255, 110, 20)
	edge.ImageTransparency = 1
	edge.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local blur = Instance.new("BlurEffect")
	blur.Name = "Heat"
	blur.Size = 0
	blur.Parent = Lighting
	table.insert(ctx.cleanup, function()
		Common.tween(edge, Common.FADE, { ImageTransparency = 1 })
		Common.tween(blur, Common.FADE, { Size = 0 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
			blur:Destroy()
			flash:Destroy()
		end)
	end)

	local heat = 0
	table.insert(ctx.onFrame, function(dt, _camPos, ramp)
		local clock = os.clock()
		for _, b in blazes do
			-- flicker, and char the needles over the first ten seconds
			b.light.Brightness = 2.5 + math.sin(clock * 13 + b.since) * 0.8 + rnd:NextNumber() * 0.6
			local k = math.min(1, (clock - b.since) / 10)
			for _, l in b.leaves do
				if l.part.Parent then
					l.part.Color = l.color:Lerp(CHAR, k)
				end
			end
		end
		flashLevel = math.max(0, flashLevel - dt * 3)
		flash.Brightness = 0.35 * flashLevel
		local hot = player:GetAttribute("Scorched") == true
		heat += ((if hot then 1 else 0) - heat) * math.min(1, dt * 3)
		edge.ImageTransparency = 1 - heat * (0.5 + 0.2 * math.sin(clock * 7)) * ramp
		blur.Size = 4 * heat * ramp
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "TreeStrike" and typeof(data.at) == "Vector3" then
			local top = data.at + Vector3.new(0, 24, 0)
			bolt(top + Vector3.new(rnd:NextNumber(-40, 40), 380, rnd:NextNumber(-40, 40)), top)
			flashLevel = 1
			puff(top, Color3.fromRGB(255, 200, 140), 20, 20)
		elseif kind == "FireOut" and typeof(data.tree) == "Instance" and data.tree:IsA("Model") then
			puff(canopy(data.tree).Position, Color3.fromRGB(230, 230, 230), 40, 18)
		elseif kind == "BurntDown" and typeof(data.at) == "Vector3" then
			puff(data.at + Vector3.new(0, 10, 0), Color3.fromRGB(70, 60, 55), 60, 30)
			spotFire(data.at, 4, 6)
		elseif kind == "Embers" and typeof(data.at) == "Vector3" then
			spotFire(data.at, tonumber(data.seconds) or 7, tonumber(data.radius) or 6)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
