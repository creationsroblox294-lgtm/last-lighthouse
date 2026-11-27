--!strict
-- CreatureController: animates every creature on this client with its Blender animations.
-- The server sets attributes on each creature model:
--   Creature   which rig/data to use ("FogCrawler", ...)
--   Anim       clip name ("Idle", "Crawl", "Lunge", "Flinch", "Death")
--   AnimSpeed  playback speed (the server matches it to how fast the creature moves)
-- Creatures far from the camera update less often to keep frame rate up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CreatureRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CreatureRig"))
local Common = require(script.Parent:WaitForChild("StormFX"):WaitForChild("Common"))

local CreatureController = {}

type Entry = { player: CreatureRig.AnimPlayer, model: Model, accum: number }
local entries: { [Model]: Entry } = {}

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local kind = model:GetAttribute("Creature")
	if typeof(kind) ~= "string" then
		return
	end
	-- wait for the visual body to replicate
	local visual = model:WaitForChild("Visual", 10)
	local body = visual and visual:WaitForChild("Body", 10)
	if not body then
		return
	end
	local ok, player = pcall(CreatureRig.newPlayer, model, kind)
	if not ok then
		warn("[CreatureController]", player)
		return
	end
	local entry: Entry = { player = player, model = model, accum = 0 }
	entries[model] = entry
	-- fade in out of a puff of fog instead of popping into existence
	local parts: { BasePart } = {}
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local function setFade(v: number)
		for _, p in parts do
			p.LocalTransparencyModifier = v
		end
	end
	local function puff(count: number)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Common.TEX.Wisp
		e.Color = ColorSequence.new(Color3.fromRGB(150, 160, 175))
		e.LightInfluence = 0.6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(1.5, 4)
		e.SpreadAngle = Vector2.new(180, 40)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Drag = 1.2
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-30, 30)
		e.Rate = 0
		e.Parent = body
		e:Emit(count)
		task.delay(2.5, function()
			e:Destroy()
		end)
	end
	if model:GetAttribute("Anim") ~= "Death" then
		setFade(1)
		puff(10)
		local start = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - start) / 0.8, 0, 1)
			setFade(1 - k * k * (3 - 2 * k))
			if k >= 1 then
				conn:Disconnect()
			end
		end)
	end
	local dying = false
	local function refresh()
		local anim = model:GetAttribute("Anim")
		local speed = model:GetAttribute("AnimSpeed")
		if typeof(anim) == "string" then
			player:play(anim, if typeof(speed) == "number" then speed else 1)
		end
		-- dissolve into fog once the death animation has mostly played
		if anim == "Death" and not dying then
			dying = true
			task.delay(1.1, function()
				if not model.Parent then
					return
				end
				puff(16)
				local start = os.clock()
				local conn: RBXScriptConnection
				conn = RunService.RenderStepped:Connect(function()
					local k = math.clamp((os.clock() - start) / 1.3, 0, 1)
					setFade(k * k * (3 - 2 * k))
					if k >= 1 or not model.Parent then
						conn:Disconnect()
					end
				end)
			end)
		end
	end
	model:GetAttributeChangedSignal("Anim"):Connect(refresh)
	model:GetAttributeChangedSignal("AnimRestart"):Connect(function()
		player.clipName = "" -- force the current clip to start over
		refresh()
	end)
	model:GetAttributeChangedSignal("AnimSpeed"):Connect(function()
		local speed = model:GetAttribute("AnimSpeed")
		if typeof(speed) == "number" then
			player.speed = speed
		end
	end)
	refresh()
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
		end
	end)
end

function CreatureController.Start()
	local runtime = Workspace:WaitForChild("Runtime")
	local enemies = runtime:WaitForChild("Enemies")
	enemies.ChildAdded:Connect(function(child)
		task.spawn(track, child)
	end)
	for _, child in enemies:GetChildren() do
		task.spawn(track, child)
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		for model, entry in entries do
			local root = model.PrimaryPart
			local distance = if root then (root.Position - camPos).Magnitude else 0
			local interval = if distance > 220 then 0.1 elseif distance > 120 then 0.05 else 0
			entry.accum += dt
			if entry.accum >= interval then
				entry.player:step(entry.accum)
				entry.accum = 0
			end
		end
	end)
end

return CreatureController
