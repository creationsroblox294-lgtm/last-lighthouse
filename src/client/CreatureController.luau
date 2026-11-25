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
	local function refresh()
		local anim = model:GetAttribute("Anim")
		local speed = model:GetAttribute("AnimSpeed")
		if typeof(anim) == "string" then
			player:play(anim, if typeof(speed) == "number" then speed else 1)
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
