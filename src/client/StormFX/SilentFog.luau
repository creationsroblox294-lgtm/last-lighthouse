--!strict
-- Silent Fog (Moderate): no wind, no rain: a pale, smothering, dead-still fog that swallows
-- everything past a few dozen studs. Then eyes open in it (StormEvent "Watcher"): two pale
-- points low in the fog, watching you. Look straight at them and they blink and sink away
-- (this client reports StormAct "WatcherSeen"). Don't, and the edges of your vision darken
-- and pulse like a heartbeat... until the eyes flare red and something lunges out of the fog
-- (StormEvent "WatcherLunge").
-- Textures: Blender (SilentFog: vignette) + Drizzle haze + Aurora wisp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Common = require(script.Parent:WaitForChild("Common"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ns = Common.ns

local FOG = Color3.fromRGB(205, 210, 210)
local EYE = Color3.fromRGB(235, 245, 220)
local RED = Color3.fromRGB(255, 60, 40)

type Watch = { id: number, at: Vector3, born: number, lunge: number, eyes: { BasePart }, light: PointLight, seen: boolean, gone: boolean }

return function(ctx: Common.Ctx)
	local rnd = Random.new()
	local watches: { [number]: Watch } = {}
	local shake = 0

	-- the fog rolls right up to you, at every height
	for i, spec in { { -3, 6, 40, 18, 34 }, { 6, 20, 26, 26, 46 } } do
		Common.around(ctx, "Fog" .. i, Vector3.new(110, spec[2], 110), {
			Texture = Common.tex(ctx, "Haze"),
			Rate = spec[3],
			LightEmission = 0,
			LightInfluence = 1,
			Color = ColorSequence.new(FOG),
			Size = ns(0, spec[4], 1, spec[5]),
			Transparency = ns(0, 1, 0.3, 0.6, 0.7, 0.6, 1, 1),
			Lifetime = NumberRange.new(12, 18),
			Speed = NumberRange.new(0.1, 0.4),
			RotSpeed = NumberRange.new(-4, 4),
			Offset = Vector3.new(0, spec[1], 0),
		})
	end
	Common.clouds(ctx, { Cover = 1, Density = 0.6, Color = Color3.fromRGB(200, 205, 205) })
	Common.grade(ctx, {
		Tint = Color3.fromRGB(235, 240, 238),
		Saturation = -0.6,
		Brightness = 0.02,
		Contrast = -0.05,
	})
	local windBefore = Workspace.GlobalWind
	Workspace.GlobalWind = Vector3.zero -- not a breath of wind
	table.insert(ctx.cleanup, function()
		Workspace.GlobalWind = windBefore
	end)

	-- dread: the edges of your vision close in while something unseen watches you
	local gui = Instance.new("ScreenGui")
	gui.Name = "FogDread"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	local vignette = Instance.new("ImageLabel")
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Image = Common.tex(ctx, "Vignette")
	vignette.ImageColor3 = Color3.new(0, 0, 0)
	vignette.ImageTransparency = 1
	vignette.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(ctx.cleanup, function()
		Common.tween(vignette, Common.FADE, { ImageTransparency = 1 })
		task.delay(Common.FADE + 0.5, function()
			gui:Destroy()
		end)
	end)

	local function eye(at: Vector3): BasePart
		local e = Common.part(ctx, "Eye", Vector3.new(0.35, 0.22, 0.2))
		e.Material = Enum.Material.Neon
		e.Color = EYE
		e.Transparency = 1
		e.CFrame = CFrame.new(at)
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = Common.tex(ctx, "Wisp")
		glow.Color = ColorSequence.new(EYE)
		glow.LightEmission = 1
		glow.LightInfluence = 0
		glow.Size = ns(0, 1.6, 1, 1.6)
		glow.Transparency = ns(0, 0.6, 1, 0.6)
		glow.Lifetime = NumberRange.new(0.2)
		glow.Speed = NumberRange.new(0)
		glow.Rate = 0
		glow.LockedToPart = true
		glow.Parent = e
		return e
	end

	local function setEyes(w: Watch, t: number)
		for _, e in w.eyes do
			e.Transparency = t
			local g = e:FindFirstChildOfClass("ParticleEmitter")
			if g then
				g.Rate = if t < 0.9 then 12 else 0
			end
		end
	end

	local function openWatch(data: { [string]: any })
		local at = (data.at :: Vector3) + Vector3.new(0, 4.6, 0)
		local w: Watch = {
			id = data.id,
			at = at,
			born = os.clock(),
			lunge = tonumber(data.lunge) or 7,
			eyes = { eye(at), eye(at) },
			light = Instance.new("PointLight"),
			seen = false,
			gone = false,
		}
		w.light.Color = EYE
		w.light.Range = 6
		w.light.Brightness = 0
		w.light.Parent = w.eyes[1]
		watches[w.id] = w
	end

	local function sinkAway(w: Watch, flare: boolean)
		if w.gone then
			return
		end
		w.gone = true
		for _, e in w.eyes do
			if flare then
				e.Color = RED
				e.Size *= 1.6
			end
			Common.tween(e, if flare then 0.5 else 1.2, { Transparency = 1, CFrame = e.CFrame - Vector3.new(0, if flare then -0.5 else 2, 0) })
		end
		Common.tween(w.light, 0.8, { Brightness = 0 })
		task.delay(1.4, function()
			for _, e in w.eyes do
				e:Destroy()
			end
			watches[w.id] = nil
		end)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local pulse = 0
	table.insert(ctx.onFrame, function(dt, camPos, ramp)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local look = camera.CFrame.LookVector
		local dread = 0
		for _, w in watches do
			if w.gone then
				continue
			end
			local age = os.clock() - w.born
			if age > w.lunge + 1.5 then
				sinkAway(w, false) -- whatever it was, it went elsewhere
				continue
			end
			-- the eyes face you, a little apart, and blink now and then
			local toCam = Vector3.new(camPos.X - w.at.X, 0, camPos.Z - w.at.Z)
			toCam = if toCam.Magnitude > 0.1 then toCam.Unit else Vector3.zAxis
			local side = Vector3.new(-toCam.Z, 0, toCam.X)
			local sway = Vector3.new(0, math.sin(age * 0.8) * 0.15, 0)
			w.eyes[1].CFrame = CFrame.lookAt(w.at + side * 0.45 + sway, w.at + side * 0.45 + toCam)
			w.eyes[2].CFrame = CFrame.lookAt(w.at - side * 0.45 + sway, w.at - side * 0.45 + toCam)
			local blink = (age % 3.7) < 0.12
			setEyes(w, if blink then 1 else math.clamp(1 - age / 1.5, 0.05, 1))
			w.light.Brightness = 0.6 * math.min(1, age / 1.5)
			-- are you looking straight at it?
			local to = w.at - camPos
			if to.Magnitude < 60 and look:Dot(to.Unit) > 0.9 and age > 0.6 then
				local character = Players.LocalPlayer.Character
				params.FilterDescendantsInstances = { ctx.folder, character :: Instance }
				if not Workspace:Raycast(camPos, to, params) then
					w.seen = true
					Remotes.event("StormAct"):FireServer("WatcherSeen", w.id)
					sinkAway(w, false)
					continue
				end
			end
			-- unseen: the dread builds as the lunge comes closer
			dread = math.max(dread, math.clamp(age / w.lunge, 0, 1))
		end
		-- a heartbeat: the vignette thumps, faster as it gets closer
		pulse += dt * (1.2 + dread * 2.5)
		local beat = math.max(0, math.sin(pulse * math.pi * 2)) ^ 6
		vignette.ImageTransparency = 1 - (0.25 + 0.45 * beat) * dread * ramp
		if shake > 0.01 then
			camera.CFrame *= CFrame.Angles((rnd:NextNumber() - 0.5) * 0.03 * shake, (rnd:NextNumber() - 0.5) * 0.03 * shake, 0)
			shake = math.max(0, shake - dt * 2)
		end
	end)

	local eventConn = Remotes.event("StormEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "Watcher" and typeof(data.at) == "Vector3" and typeof(data.id) == "number" then
			openWatch(data)
		elseif kind == "WatcherLunge" and typeof(data.id) == "number" then
			local w = watches[data.id]
			if w then
				sinkAway(w, true)
				shake = 0.9
			end
		end
	end)
	table.insert(ctx.cleanup, function()
		eventConn:Disconnect()
		for _, w in watches do
			sinkAway(w, false)
		end
	end)
end
