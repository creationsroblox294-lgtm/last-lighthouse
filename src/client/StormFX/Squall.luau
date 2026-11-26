--!strict
-- Squall (Mild): a sullen grey-green day with a light rain... until a squall comes. A wall of
-- rain (StormEvent "SquallBand": two scrolling rain curtains a band's width apart, as tall as
-- the clouds) marches in from the sea and sweeps across the island. You can watch it come. As
-- it reaches you the light drops; inside it the rain pours down blindingly hard, the world goes
-- grey and blurred and the wind shakes you, and then it's gone, rolling away inland.
-- Textures: Blender (Squall: sheet) + Golden Rain drop/splash.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local RAIN = Color3.fromRGB(195, 210, 220)
local WALL = Color3.fromRGB(150, 165, 175)

type Band = { start: Vector3, dir: Vector3, speed: number, thick: number, t0: number, walls: { BasePart }, textures: { Texture } }

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local bands: { Band } = {}

	local rain = Common.fall(ctx, "Rain", {
		Texture = Common.tex(ctx, "Drop"),
		Rate = 300,
		Size = ns(0, 0.4, 1, 0.4),
		Squash = ns(0, 1.6, 1, 1.6),
		Brightness = 1.2,
		Color = ColorSequence.new(RAIN),
		Speed = NumberRange.new(80, 95),
		Slant = Vector3.new(8, 0, 3),
	})
	local splash = Instance.new("ParticleEmitter")
	splash.Texture = Common.tex(ctx, "Splash")
	splash.Color = ColorSequence.new(RAIN)
	splash.LightEmission = 0.4
	splash.Size = ns(0, 0.4, 1, 1.4)
	splash.Transparency = ns(0, 0.3, 1, 1)
	splash.Lifetime = NumberRange.new(0.25, 0.4)
	splash.Speed = NumberRange.new(0)
	splash.Rate = 0
	local splashRate = 20
	local anchor = Common.impacts(ctx, 140, 40, function()
		if rnd:NextNumber() * 140 < splashRate then
			splash:Emit(1)
		end
	end)
	splash.Parent = anchor
	Common.clouds(ctx, { Cover = 0.86, Density = 0.7, Color = Color3.fromRGB(120, 135, 130) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(225, 238, 232),
		Saturation = -0.2,
		Brightness = 0,
		Contrast = 0.12,
		Bloom = 0.5,
		BloomThreshold = 1.2,
	})
	-- the darkness that comes with a squall
	local dark = Instance.new("ColorCorrectionEffect")
	dark.Name = "SquallDark"
	dark.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "SquallBlur"
	blur.Size = 0
	blur.Parent = Lighting
	table.insert(ctx.cleanup, function()
		Common.tween(dark, Common.FADE, { Brightness = 0, Saturation = 0, Contrast = 0 })
		Common.tween(blur, Common.FADE, { Size = 0 })
		task.delay(Common.FADE + 0.5, function()
			dark:Destroy()
			blur:Destroy()
		end)
	end)

	local function wall(): (BasePart, { Texture })
		local p = Common.part(ctx, "SquallWall", Vector3.new(1800, 900, 1))
		local texs = {}
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local t = Instance.new("Texture")
			t.Texture = Common.tex(ctx, "Sheet")
			t.Face = face
			t.StudsPerTileU = 140
			t.StudsPerTileV = 280
			t.Color3 = WALL
			t.Transparency = 1
			t.Parent = p
			table.insert(texs, t)
		end
		return p, texs
	end

	local function addBand(data: { [string]: any })
		local front, tf = wall()
		local back, tb = wall()
		local textures = {}
		for _, t in tf do
			table.insert(textures, t)
		end
		for _, t in tb do
			table.insert(textures, t)
		end
		for _, t in textures do
			Common.tween(t, 3, { Transparency = 0.3 })
		end
		table.insert(bands, {
			start = data.start,
			dir = data.dir,
			speed = data.speed,
			thick = data.thick,
			t0 = data.t0,
			walls = { front, back },
			textures = textures,
		})
	end

	local scroll = 0
	local inside = 0 -- 0 out .. 1 deep inside a band
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local now = Workspace:GetServerTimeNow()
		scroll += dt * 140
		local nearest = math.huge
		for i = #bands, 1, -1 do
			local b = bands[i]
			local travelled = b.speed * (now - b.t0)
			if travelled > 1500 + b.thick then
				for _, w in b.walls do
					w:Destroy()
				end
				table.remove(bands, i)
			else
				local mid = b.start + b.dir * travelled
				local side = Vector3.new(-b.dir.Z, 0, b.dir.X)
				-- slide the band sideways with the camera so its ends never show
				local along = (camPos - mid):Dot(side)
				local base = mid + side * along + Vector3.new(0, 430, 0)
				b.walls[1].CFrame = CFrame.fromMatrix(base + b.dir * (b.thick / 2), side, Vector3.yAxis)
				b.walls[2].CFrame = CFrame.fromMatrix(base - b.dir * (b.thick / 2), side, Vector3.yAxis)
				for _, t in b.textures do
					t.OffsetStudsV = -scroll
				end
				-- fade out as it rolls away at the far side
				if travelled > 1300 then
					for _, t in b.textures do
						t.Transparency = 0.3 + 0.7 * math.clamp((travelled - 1300) / 200, 0, 1)
					end
				end
				local d = math.abs((camPos - mid):Dot(b.dir)) - b.thick / 2
				nearest = math.min(nearest, d)
			end
		end
		-- inside (d < 0) = full downpour; within 60 studs it builds as the wall arrives
		local goal = math.clamp(1 - nearest / 60, 0, 1)
		inside += (goal - inside) * math.min(1, dt * 2.5)
		local k = inside * ramp
		rain.Rate = 300 + 3200 * k
		rain.Speed = NumberRange.new(80 + 40 * k, 95 + 50 * k)
		splashRate = 20 + 120 * k
		dark.Brightness = -0.14 * k
		dark.Saturation = -0.35 * k
		dark.Contrast = 0.1 * k
		blur.Size = 3 * k
		if k > 0.3 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.006 * k, (rnd:NextNumber() - 0.5) * 0.006 * k, 0)
			end
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "SquallBand" and typeof(data) == "table" and typeof(data.start) == "Vector3" and typeof(data.dir) == "Vector3" then
			addBand(data)
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
		for _, b in bands do
			for _, t in b.textures do
				Common.tween(t, Common.FADE, { Transparency = 1 })
			end
		end
	end)
end
