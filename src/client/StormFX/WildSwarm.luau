--!strict
-- Wild Swarm (Moderate): a hot, bruised dusk and a forest that won't keep still. The pine
-- canopies near you thrash and shudder with something moving inside them, leaves rain down,
-- and pairs of glowing eyes open in the branches, watch you, blink and vanish. Then a swarm
-- (StormEvent "BatSwarm"): thousands of bats boil up out of the trees and stream across the
-- sky in a flapping black river. If it passes over you in the open they mob you (StormEvent
-- "BatsHit"): bats fill the screen, the edges go red and everything shakes. If it pours over
-- the lighthouse the lamp vanishes in a whirl of wings (StormEvent "BatsLamp").
-- Textures: Blender (Wild Swarm: bat flipbook, eyes) + Sea Breeze leaf, Drizzle haze, Silent
-- Fog vignette.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local DUSK = Color3.fromRGB(255, 170, 120)
local EYE_COLOURS = { Color3.fromRGB(255, 60, 40), Color3.fromRGB(255, 200, 60), Color3.fromRGB(150, 255, 80) }
local SHAKE_RANGE = 110 -- trees this close to the camera thrash
local TRAVEL = 900 -- must match Storms/WildSwarm

type Swarm = { start: Vector3, dir: Vector3, speed: number, t0: number, part: BasePart, bats: ParticleEmitter, low: ParticleEmitter }
type Leaves = { part: BasePart, home: CFrame }
type Tree = { pivot: Vector3, leaves: { Leaves }, phase: number, rate: number, amp: number, shaking: boolean }

local function bats(ctx: Common.Ctx): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Common.tex(ctx, "Bat")
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(14, 22)
	e.FlipbookStartRandom = true
	e.Color = ColorSequence.new(Color3.fromRGB(25, 18, 22))
	e.LightInfluence = 0.3
	e.Size = ns(0, 1.6, 1, 2.2)
	e.Transparency = ns(0, 1, 0.08, 0, 0.85, 0, 1, 1)
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Rate = 0
	return e
end

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local player = Players.LocalPlayer
	local swarms: { Swarm } = {}

	Common.around(ctx, "Leaves", Vector3.new(90, 20, 90), {
		Texture = Common.tex(ctx, "Leaf"),
		Rate = 30,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(80, 110, 50), Color3.fromRGB(120, 90, 40)),
		Size = ns(0, 0.5, 1, 0.4),
		Transparency = ns(0, 1, 0.1, 0, 0.85, 0, 1, 1),
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(1, -3, 0.5),
		RotSpeed = NumberRange.new(-200, 200),
		Offset = Vector3.new(0, 14, 0),
	})
	Common.around(ctx, "Dust", Vector3.new(120, 20, 120), {
		Texture = Common.tex(ctx, "Haze"),
		Rate = 6,
		LightEmission = 0,
		LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(120, 80, 90)),
		Size = ns(0, 14, 1, 26),
		Transparency = ns(0, 1, 0.3, 0.82, 0.7, 0.82, 1, 1),
		Lifetime = NumberRange.new(5, 7),
	})
	Common.clouds(ctx, { Cover = 0.75, Density = 0.5, Color = Color3.fromRGB(150, 90, 110) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(255, 220, 215),
		Saturation = 0.05,
		Brightness = -0.02,
		Contrast = 0.2,
		Bloom = 0.6,
		BloomThreshold = 1.1,
		Rays = 0.1,
	})

	-- the trees
	local trees: { Tree } = {}
	local map = Workspace:FindFirstChild("Map")
	local grove = map and map:FindFirstChild("PineGrove")
	if grove then
		for _, t in grove:GetChildren() do
			if t:IsA("Model") then
				local list = {}
				for _, p in t:GetChildren() do
					if p.Name == "Leaves" and p:IsA("BasePart") then
						table.insert(list, { part = p, home = p.CFrame })
					end
				end
				if #list > 0 then
					table.insert(trees, {
						pivot = t:GetPivot().Position,
						leaves = list,
						phase = rnd:NextNumber(0, 10),
						rate = rnd:NextNumber(5, 11),
						amp = rnd:NextNumber(0.015, 0.05),
						shaking = false,
					})
				end
			end
		end
	end
	local function settle(tr: Tree)
		for _, l in tr.leaves do
			if l.part.Parent then
				l.part.CFrame = l.home
			end
		end
		tr.shaking = false
	end
	table.insert(ctx.cleanup, function()
		for _, tr in trees do
			if tr.shaking then
				settle(tr)
			end
		end
	end)

	-- eyes in the branches
	type Eyes = { gui: BillboardGui, img: ImageLabel, born: number, life: number, part: BasePart }
	local eyes: { Eyes } = {}
	local nextEyes = 1
	local function openEyes(camPos: Vector3)
		if #trees == 0 or #eyes >= 7 then
			return
		end
		local close = {}
		for _, tr in trees do
			local d = (Vector3.new(tr.pivot.X, camPos.Y, tr.pivot.Z) - camPos).Magnitude
			if d > 18 and d < 90 then
				table.insert(close, tr)
			end
		end
		if #close > 0 then
			local tr = close[rnd:NextInteger(1, #close)]
			local leaf = tr.leaves[rnd:NextInteger(1, #tr.leaves)]
			local anchor = Common.part(ctx, "EyeAnchor", Vector3.one)
			anchor.CFrame = CFrame.new(leaf.home.Position + Vector3.new(rnd:NextNumber(-2, 2), -1.5, rnd:NextNumber(-2, 2)))
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(3.6, 1.8)
			gui.LightInfluence = 0
			gui.MaxDistance = 120
			gui.Adornee = anchor
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = Common.tex(ctx, "Eyes")
			img.ImageColor3 = EYE_COLOURS[rnd:NextInteger(1, #EYE_COLOURS)]
			img.ImageTransparency = 1
			img.Parent = gui
			gui.Parent = anchor
			table.insert(eyes, { gui = gui, img = img, born = os.clock(), life = rnd:NextNumber(3, 6), part = anchor })
		end
	end

	-- the mobbing: bats across the screen, red edges, shaking
	local mob = Common.part(ctx, "Mob", Vector3.new(10, 8, 2))
	local mobBats = bats(ctx)
	mobBats.Size = ns(0, 0.8, 1, 1.2)
	mobBats.Speed = NumberRange.new(10, 18)
	mobBats.SpreadAngle = Vector2.new(70, 50)
	mobBats.Lifetime = NumberRange.new(0.6, 1)
	mobBats.EmissionDirection = Enum.NormalId.Back -- straight at your face
	mobBats.Parent = mob
	local gui = Instance.new("ScreenGui")
	gui.Name = "Mobbed"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local red = Instance.new("ImageLabel")
	red.BackgroundTransparency = 1
	red.Size = UDim2.fromScale(1, 1)
	red.Image = Common.tex(ctx, "Vignette")
	red.ImageColor3 = Color3.fromRGB(200, 20, 20)
	red.ImageTransparency = 1
	red.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local mobbed = 0
	table.insert(ctx.cleanup, function()
		Common.tween(red, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	local function addSwarm(data: { [string]: any })
		local part = Common.part(ctx, "BatSwarm", Vector3.new(50, 14, 30))
		local flock = bats(ctx)
		flock.Rate = 260
		flock.Speed = NumberRange.new(data.speed * 0.9, data.speed * 1.1)
		flock.SpreadAngle = Vector2.new(14, 10)
		flock.EmissionDirection = Enum.NormalId.Front
		flock.Acceleration = Vector3.new(0, 1.5, 0)
		flock.Parent = part
		-- a second, lower and looser stream that skims the ground
		local low = bats(ctx)
		low.Rate = 90
		low.Speed = NumberRange.new(data.speed * 0.8, data.speed)
		low.SpreadAngle = Vector2.new(30, 20)
		low.EmissionDirection = Enum.NormalId.Front
		low.Acceleration = Vector3.new(0, -3, 0)
		low.Parent = part
		-- the eruption out of the tree
		local burst = bats(ctx)
		burst.Speed = NumberRange.new(10, 30)
		burst.SpreadAngle = Vector2.new(60, 60)
		burst.EmissionDirection = Enum.NormalId.Top
		burst.Parent = part
		part.CFrame = CFrame.lookAt(data.start, data.start + data.dir)
		burst:Emit(150)
		table.insert(swarms, { start = data.start, dir = data.dir, speed = data.speed, t0 = data.t0, part = part, bats = flock, low = low })
	end

	local function lampMobbed()
		local l = Common.lamp()
		if not l then
			return
		end
		local whirl = Common.part(ctx, "LampBats", Vector3.new(16, 10, 16))
		whirl.CFrame = l.CFrame
		local e = bats(ctx)
		e.Speed = NumberRange.new(6, 12)
		e.SpreadAngle = Vector2.new(180, 40)
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Parent = whirl
		e:Emit(220)
		task.delay(3, function()
			whirl:Destroy()
		end)
	end

	local clock = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		clock += dt
		local now = Workspace:GetServerTimeNow()
		-- the canopies near you thrash; anything that strays out of range settles back
		for _, tr in trees do
			local d = (Vector3.new(tr.pivot.X, 0, tr.pivot.Z) - Vector3.new(camPos.X, 0, camPos.Z)).Magnitude
			if d < SHAKE_RANGE and ramp > 0.05 then
				tr.shaking = true
				-- bursts of thrashing with stillness between, as if something is moving through
				local gust = math.max(0, math.sin(clock * 0.9 + tr.phase)) ^ 3
				local a = tr.amp * ramp * (0.25 + gust)
				local rx = math.sin(clock * tr.rate + tr.phase) * a
				local rz = math.cos(clock * tr.rate * 1.3 + tr.phase) * a
				local pivot = CFrame.new(tr.pivot)
				for _, l in tr.leaves do
					if l.part.Parent then
						l.part.CFrame = pivot * CFrame.Angles(rx, 0, rz) * pivot:Inverse() * l.home
					end
				end
			elseif tr.shaking then
				settle(tr)
			end
		end
		-- eyes
		nextEyes -= dt
		if nextEyes <= 0 and ramp > 0.5 then
			nextEyes = rnd:NextNumber(0.8, 2)
			openEyes(camPos)
		end
		for i = #eyes, 1, -1 do
			local e = eyes[i]
			local age = os.clock() - e.born
			if age > e.life then
				e.part:Destroy()
				table.remove(eyes, i)
			else
				local fade = math.min(age / 0.6, 1, (e.life - age) / 0.4)
				local blink = if (age % 2.3) < 0.12 then 1 else 0
				e.img.ImageTransparency = 1 - fade * (1 - blink)
			end
		end
		-- swarms
		for i = #swarms, 1, -1 do
			local s = swarms[i]
			local travelled = s.speed * (now - s.t0)
			if travelled > TRAVEL + 200 then
				s.part:Destroy()
				table.remove(swarms, i)
			else
				local k = math.min(travelled, TRAVEL)
				-- climbs out of the trees then rides a wave just above the canopy
				local rise = math.min(1, travelled / 60) * 20 + math.sin(travelled / 70) * 6
				local p = s.start + s.dir * k + Vector3.new(0, rise, 0)
				s.part.CFrame = CFrame.lookAt(p, p + s.dir)
				local on = if travelled < TRAVEL then 1 else 0
				s.bats.Rate = 260 * on * ramp
				s.low.Rate = 90 * on * ramp
			end
		end
		-- mobbed
		if mobbed > 0 then
			mobbed = math.max(0, mobbed - dt / 2.5)
			local camera = Workspace.CurrentCamera
			if camera then
				mob.CFrame = camera.CFrame * CFrame.new(0, 0, -6)
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.04 * mobbed, (rnd:NextNumber() - 0.5) * 0.04 * mobbed, 0)
			end
			mobBats.Rate = 120 * mobbed
			red.ImageTransparency = 1 - 0.7 * mobbed
		else
			mobBats.Rate = 0
		end
	end)
	table.insert(ctx.cleanup, function()
		for _, e in eyes do
			e.part:Destroy()
		end
		table.clear(eyes)
		for _, s in swarms do
			s.bats.Rate = 0
			s.low.Rate = 0
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "BatSwarm" and typeof(data) == "table" and typeof(data.start) == "Vector3" and typeof(data.dir) == "Vector3" then
			addSwarm(data)
		elseif kind == "BatsHit" then
			mobbed = 1
			local camera = Workspace.CurrentCamera
			if camera then
				mob.CFrame = camera.CFrame * CFrame.new(0, 0, -6)
			end
			mobBats:Emit(80)
		elseif kind == "BatsLamp" then
			lampMobbed()
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
	end)
end
