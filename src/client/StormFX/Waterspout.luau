--!strict
-- Waterspout (Catastrophic): a low green-black sky and driving rain, and out of it drop the
-- spouts: tall twisting columns of spray (Blender: funnel mesh + wall streaks, an inner core
-- turning the other way) reaching right up into a churning wall cloud. A skirt of spray boils
-- round each foot (dirt and leaves once it's ashore), wreckage whirls round it and fish glint
-- as they're carried up. Each one follows the server (StormEvent "Spouts"). If one snatches you
-- (StormEvent "SpoutGrab") you're whirled up the column and flung out of it. When one tears
-- across the lighthouse (StormEvent "SpoutTower") everything shakes; when it drops a fish
-- (StormEvent "SpoutFish") it lands with a splat of spray.
-- Textures: Blender (Waterspout: wall) + Hurricane drop/leaf, Fish Rain splash/spray/glint,
-- Drizzle haze, Rolling Thunder smoke.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local WALL = Color3.fromRGB(190, 205, 205)
local CORE = Color3.fromRGB(120, 140, 140)
local SPRAY = Color3.fromRGB(225, 238, 240)
local CLOUD = Color3.fromRGB(55, 65, 65)
local RAIN = Color3.fromRGB(190, 205, 210)
local HEIGHT = 300 -- the funnel mesh is 300 studs tall

type Spout = {
	model: Model,
	walls: { BasePart },
	foot: BasePart,
	skirt: ParticleEmitter,
	dirt: ParticleEmitter,
	top: BasePart,
	cloud: ParticleEmitter,
	glints: ParticleEmitter,
	debris: { { part: BasePart, r: number, y: number, a: number, w: number } },
	pos: Vector3,
	target: Vector3,
	vel: Vector3,
	turn: number,
	ground: number,
	land: boolean,
	probeAt: number,
	life: number, -- 0..1 grow in, fades when dying
	dying: boolean,
}

return function(ctx: Common.Ctx)
	local player = Players.LocalPlayer
	local rnd = Random.new()

	Common.clouds(ctx, { Cover = 0.95, Density = 0.75, Color = Color3.fromRGB(70, 85, 80) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(200, 220, 210),
		Saturation = -0.3,
		Brightness = -0.05,
		Contrast = 0.25,
		Bloom = 0.4,
		BloomThreshold = 1.3,
	})
	local rain = Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 2200,
		Size = ns(0, 0.4, 1, 0.4),
		Squash = ns(0, 1.8, 1, 1.8),
		Brightness = 1.1,
		Color = ColorSequence.new(RAIN),
		Speed = NumberRange.new(90, 110),
		Slant = Vector3.new(25, 0, 10),
	})
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel

	local terrain = Workspace.Terrain
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = { terrain }
	probe.IgnoreWater = false

	local assets = ReplicatedStorage:FindFirstChild("StormAssets")
	local template = assets and assets:FindFirstChild("WaterspoutFunnel")
	local spouts: { [number]: Spout } = {}

	local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = parent
		return e
	end

	local function makeSpout(id: number, at: Vector3): Spout?
		if not (template and template:IsA("Model")) then
			return nil
		end
		local m = Instance.new("Model")
		m.Name = "Waterspout" .. id
		local walls = {}
		for layer = 1, 2 do
			local w = template:Clone()
			for _, d in w:GetDescendants() do
				if d:IsA("MeshPart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
					d.Material = Enum.Material.SmoothPlastic
					d.TextureID = Common.tex(ctx, "Wall")
					d.Color = if layer == 1 then WALL else CORE
					d.Transparency = 1
					pcall(function()
						(d :: any).DoubleSided = true
					end)
					if layer == 2 then
						d.Size *= Vector3.new(0.62, 1, 0.62)
					end
					d.Parent = m
					table.insert(walls, d)
				end
			end
			w:Destroy()
		end
		m.Parent = ctx.folder
		local foot = Common.part(ctx, "SpoutFoot", Vector3.new(40, 2, 40))
		local skirt = emitter(foot, {
			Texture = Common.tex(ctx, "Splash"),
			Color = ColorSequence.new(SPRAY),
			LightEmission = 0.2,
			LightInfluence = 0.6,
			Size = ns(0, 14, 1, 45),
			Transparency = ns(0, 0.25, 1, 1),
			Lifetime = NumberRange.new(1.6, 2.8),
			Speed = NumberRange.new(20, 40),
			SpreadAngle = Vector2.new(75, 75),
			Acceleration = Vector3.new(0, -16, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-80, 80),
			Rate = 0,
		})
		emitter(foot, {
			Name = "Mist",
			Texture = Common.tex(ctx, "Haze"),
			Color = ColorSequence.new(Color3.fromRGB(200, 215, 215)),
			LightInfluence = 0.8,
			Size = ns(0, 20, 1, 50),
			Transparency = ns(0, 1, 0.3, 0.55, 1, 1),
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(6, 14),
			SpreadAngle = Vector2.new(80, 80),
			Rate = 12,
		})
		local dirt = emitter(foot, {
			Texture = Common.tex(ctx, "Leaf"),
			Color = ColorSequence.new(Color3.fromRGB(90, 110, 60), Color3.fromRGB(110, 85, 55)),
			LightInfluence = 1,
			Size = ns(0, 1.5, 1, 1),
			Lifetime = NumberRange.new(2, 4),
			Speed = NumberRange.new(30, 60),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, -8, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
			Rate = 0,
		})
		local glints = emitter(foot, {
			Texture = Common.tex(ctx, "Glint"),
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 2.5,
			Size = ns(0, 1.2, 1, 0.8),
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(45, 75),
			SpreadAngle = Vector2.new(6, 6),
			Rate = 0,
		})
		local top = Common.part(ctx, "SpoutCloud", Vector3.new(160, 10, 160))
		local cloud = emitter(top, {
			Texture = Common.tex(ctx, "Smoke"),
			Color = ColorSequence.new(CLOUD),
			LightInfluence = 1,
			Size = ns(0, 60, 1, 110),
			Transparency = ns(0, 1, 0.25, 0.2, 0.8, 0.3, 1, 1),
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(4, 10),
			SpreadAngle = Vector2.new(180, 10),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-25, -10),
			Rate = 0,
		})
		local debris = {}
		for i = 1, 7 do
			local p = Instance.new("Part")
			p.Name = "SpoutDebris"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = if i % 2 == 0 then Enum.Material.WoodPlanks else Enum.Material.Wood
			p.Color = Color3.fromRGB(110, 85, 60)
			p.Size = Vector3.new(rnd:NextNumber(2, 6), 0.5, rnd:NextNumber(0.8, 1.6))
			p.Transparency = 1
			p.Parent = m
			table.insert(debris, { part = p, r = rnd:NextNumber(14, 30), y = rnd:NextNumber(5, 120), a = rnd:NextNumber(0, 6.3), w = rnd:NextNumber(2.5, 4) })
		end
		return {
			model = m,
			walls = walls,
			foot = foot,
			skirt = skirt,
			dirt = dirt,
			top = top,
			cloud = cloud,
			glints = glints,
			debris = debris,
			pos = at,
			target = at,
			vel = Vector3.zero,
			turn = rnd:NextNumber(0, 6.3),
			ground = 0,
			land = false,
			probeAt = 0,
			life = 0,
			dying = false,
		}
	end

	local function destroySpout(s: Spout)
		s.model:Destroy()
		s.foot:Destroy()
		s.top:Destroy()
	end
	table.insert(ctx.cleanup, function()
		for _, s in spouts do
			s.dying = true
		end
	end)

	-- the screen: spray across your eyes when you're close to one, and the grab
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpoutSpray"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local veil = Instance.new("Frame")
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(215, 230, 232)
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(veil, 1, { BackgroundTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	local shake = 0
	local held: { id: number, t0: number, a: number, r: number, y0: number }? = nil

	local function grabbedBy(id: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and hum and hum.Health > 0) then
			return
		end
		local s = spouts[id]
		local centre = if s then s.pos else root.Position
		local off = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
		held = { id = id, t0 = os.clock(), a = math.atan2(off.Z, off.X), r = math.max(6, math.min(off.Magnitude, 14)), y0 = root.Position.Y }
		hum:ChangeState(Enum.HumanoidStateType.FallingDown)
		shake = 1
	end

	local function release(root: BasePart, hum: Humanoid, centre: Vector3)
		local off = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
		local out = if off.Magnitude > 0.5 then off.Unit else Vector3.xAxis
		local round = Vector3.new(-out.Z, 0, out.X)
		root.AssemblyLinearVelocity = out * 70 + round * 40 + Vector3.new(0, 25, 0)
		veil.BackgroundTransparency = 0.2
		Common.tween(veil, 1.4, { BackgroundTransparency = 1 })
		task.delay(2.2, function()
			if hum.Parent and hum.Health > 0 then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end

	local function splat(at: Vector3)
		local holder = Common.part(ctx, "FishSplat", Vector3.new(4, 1, 4))
		holder.CFrame = CFrame.new(at)
		local e = emitter(holder, {
			Texture = Common.tex(ctx, "Spray"),
			Color = ColorSequence.new(SPRAY),
			LightInfluence = 0.6,
			Size = ns(0, 2, 1, 6),
			Transparency = ns(0, 0.2, 1, 1),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(10, 20),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -40, 0),
			Rate = 0,
		})
		e:Emit(18)
		task.delay(2, function()
			holder:Destroy()
		end)
	end

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Spouts" and typeof(data.list) == "table" then
			local seen = {}
			for _, e in data.list do
				local id = e.id
				seen[id] = true
				local at = Vector3.new(e.x, 0, e.z)
				local s = spouts[id]
				if not s then
					local made = makeSpout(id, at)
					if made then
						spouts[id] = made
						s = made
					end
				end
				if s then
					s.vel = (at - s.target) / 0.5
					s.target = at
				end
			end
			for id, s in spouts do
				if not seen[id] then
					s.dying = true
				end
			end
		elseif kind == "SpoutGrab" and typeof(data.id) == "number" then
			grabbedBy(data.id)
		elseif kind == "SpoutTower" and typeof(data.at) == "Vector3" then
			local camera = Workspace.CurrentCamera
			if camera and (camera.CFrame.Position - data.at).Magnitude < 250 then
				shake = math.max(shake, 0.8)
			end
		elseif kind == "SpoutFish" and typeof(data.to) == "Vector3" then
			task.delay(0.6, splat, data.to)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)

	local near = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local closest = math.huge
		for id, s in spouts do
			-- follow the server smoothly
			s.pos += s.vel * dt
			s.pos += (s.target + s.vel * 0.25 - s.pos) * math.min(1, dt * 1.5)
			if s.dying then
				s.life = math.max(0, s.life - dt / 3)
				if s.life <= 0 then
					destroySpout(s)
					spouts[id] = nil
					continue
				end
			else
				s.life = math.min(1, s.life + dt / 4)
			end
			s.probeAt -= dt
			if s.probeAt <= 0 then
				s.probeAt = 0.4
				local hit = Workspace:Raycast(Vector3.new(s.pos.X, 200, s.pos.Z), Vector3.new(0, -400, 0), probe)
				s.land = hit ~= nil and hit.Material ~= Enum.Material.Water
				s.ground = if hit then hit.Position.Y else 0
			end
			s.turn += dt * 2.2
			-- lean into its travel, and wobble
			local lean = Vector3.new(s.vel.Z, 0, -s.vel.X) * 0.006
			local base = Vector3.new(s.pos.X, s.ground - 2, s.pos.Z)
			-- grows down out of the cloud: the column drops from above as life rises
			local drop = (1 - s.life) * HEIGHT * 0.9
			local cf = CFrame.new(base + Vector3.new(0, drop, 0)) * CFrame.Angles(lean.X + math.sin(s.turn * 0.3) * 0.03, 0, lean.Z + math.cos(s.turn * 0.27) * 0.03)
			for i, w in s.walls do
				local spin = if i == 1 then -s.turn else s.turn * 1.6
				w.CFrame = cf * CFrame.new(0, HEIGHT / 2, 0) * CFrame.Angles(0, spin, 0)
				w.Transparency = 1 - s.life * (if i == 1 then 0.62 else 0.45)
			end
			s.foot.CFrame = CFrame.new(base + Vector3.new(0, 2, 0))
			s.skirt.Rate = (if s.land then 15 else 55) * s.life * ramp
			s.dirt.Rate = (if s.land then 60 else 0) * s.life * ramp
			s.glints.Rate = 8 * s.life * ramp
			s.top.CFrame = CFrame.new(base + Vector3.new(0, HEIGHT - 10, 0))
			s.cloud.Rate = 6 * ramp
			for _, d in s.debris do
				d.a += d.w * dt
				d.y += dt * 18
				if d.y > 200 then
					d.y = rnd:NextNumber(4, 20)
				end
				local r = d.r + d.y * 0.18
				d.part.CFrame = CFrame.new(base + Vector3.new(math.cos(d.a) * r, d.y, math.sin(d.a) * r)) * CFrame.Angles(d.a * 2, d.a * 3, 0)
				d.part.Transparency = 1 - s.life
			end
			local dist = Vector3.new(camPos.X - s.pos.X, 0, camPos.Z - s.pos.Z).Magnitude
			closest = math.min(closest, dist)
		end
		-- close to one: spray on the screen and the ground trembling
		local want = math.clamp(1 - (closest - 20) / 90, 0, 1)
		near += (want - near) * math.min(1, dt * 3)
		if not held then
			veil.BackgroundTransparency = 1 - near * 0.35
		end
		local camera = Workspace.CurrentCamera
		local amount = math.max(shake, near * 0.35)
		if camera and amount > 0.01 then
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * amount, (rnd:NextNumber() - 0.5) * 0.03 * amount, 0)
		end
		shake = math.max(0, shake - dt * 0.8)
		-- being carried up the column
		if held then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			local s = spouts[held.id]
			if not (root and root:IsA("BasePart") and hum and hum.Health > 0) then
				held = nil
				return
			end
			local centre = if s then s.pos else root.Position
			local t = os.clock() - held.t0
			held.a += dt * (3 + t * 2)
			local y = held.y0 + 55 * math.min(1, t / 2.2) ^ 0.8
			local pos = Vector3.new(centre.X + math.cos(held.a) * held.r, y, centre.Z + math.sin(held.a) * held.r)
			root.CFrame = CFrame.new(pos) * CFrame.Angles(t * 5, held.a * 2, t * 3)
			root.AssemblyLinearVelocity = Vector3.zero
			veil.BackgroundTransparency = 0.45 + 0.2 * math.sin(t * 20)
			shake = 0.8
			if t > 2.2 or not s then
				held = nil
				release(root, hum, centre)
			end
		end
	end)
end
