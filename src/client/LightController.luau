--!strict
-- LightController: draws the safe circle and the rotating beam from SharedState "Light",
-- and sends the aim direction while this player is at the beam control.
-- The server only sends numbers; everything you see here is built on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))

local L = Config.Light
local LightController = {}

local SEGMENTS = 48
local WALL_HEIGHT = 70
local WARM = Color3.fromRGB(255, 214, 130)
local LOW = Color3.fromRGB(255, 110, 70)

local function angleDiff(a: number, b: number): number
	local d = (a - b) % 360
	if d > 180 then
		d -= 360
	end
	return d
end

function LightController.Start()
	local player = Players.LocalPlayer
	local state = SharedState.get("Light")
	local center = Config.World.TowerCenter
	local lampPos = Config.World.LampPosition

	local folder = Instance.new("Folder")
	folder.Name = "LightVisuals"
	folder.Parent = Workspace

	-- Safe circle: a faint wall of light
	local ring: { BasePart } = {}
	for i = 1, SEGMENTS do
		local p = Instance.new("Part")
		p.Name = "SafeCircle"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Transparency = 0.88
		p.Color = WARM
		p.Parent = folder
		ring[i] = p
	end

	local function drawRing()
		local radius = SharedState.number(state, "Radius", 0)
		local fuel = SharedState.number(state, "Fuel", 0)
		local maxFuel = SharedState.number(state, "MaxFuel", 100)
		local visible = radius > 1
		local color = if fuel / maxFuel < L.LowFuelFraction then LOW else WARM
		local segLength = 2 * math.pi * radius / SEGMENTS + 0.3
		for i, p in ring do
			if not visible then
				p.Transparency = 1
			else
				local a = (i - 0.5) / SEGMENTS * math.pi * 2
				local pos = Vector3.new(center.X + math.cos(a) * radius, WALL_HEIGHT / 2 - 5, center.Z + math.sin(a) * radius)
				p.Size = Vector3.new(segLength, WALL_HEIGHT, 0.2)
				p.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
				p.Transparency = 0.88
				p.Color = color
			end
		end
	end
	state:GetAttributeChangedSignal("Radius"):Connect(drawRing)
	state:GetAttributeChangedSignal("Fuel"):Connect(function()
		-- colour only changes when crossing the low-fuel line; cheap enough to redraw
		drawRing()
	end)
	drawRing()

	-- The beam: a long translucent bar with a spotlight
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 236, 180)
	beam.Transparency = 0.75
	beam.Size = Vector3.new(7, 3, L.BeamRange)
	beam.Parent = folder
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 25
	spot.Range = 60
	spot.Brightness = 4
	spot.Color = beam.Color
	spot.Parent = beam

	local shownAngle = SharedState.number(state, "BeamAngle", 0)
	local serverAngle = shownAngle
	local lastUpdate = os.clock()
	state:GetAttributeChangedSignal("BeamAngle"):Connect(function()
		serverAngle = SharedState.number(state, "BeamAngle", 0)
		lastUpdate = os.clock()
	end)

	RunService.RenderStepped:Connect(function(dt)
		local lit = state:GetAttribute("IsLit") == true
		-- Blackout Storm: lightning has choked the lamp, and the beam only coughs now and then
		local choked = Workspace:GetAttribute("Blackout") == true
		beam.Transparency = if not lit then 1 elseif choked then (if math.random() < 0.06 then 0.85 else 1) else 0.75
		spot.Enabled = lit and not choked
		if not lit then
			return
		end
		local speed = SharedState.number(state, "BeamSpeed", 0)
		local predicted = serverAngle + speed * math.min(os.clock() - lastUpdate, 0.5)
		shownAngle += angleDiff(predicted, shownAngle) * math.min(1, dt * 12)
		local a = math.rad(shownAngle)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local target = lampPos + dir * L.BeamRange + Vector3.new(0, -45, 0)
		local length = (target - lampPos).Magnitude
		beam.Size = Vector3.new(7, 3, length)
		beam.CFrame = CFrame.lookAt(lampPos, target) * CFrame.new(0, 0, -length / 2)
	end)

	-- Aiming: while you hold the beam control, the beam follows your camera
	local aimRemote = Remotes.event("AimBeam")
	task.spawn(function()
		while true do
			task.wait(0.1)
			if state:GetAttribute("Controller") == player.Name then
				local camera = Workspace.CurrentCamera
				if camera then
					local look = camera.CFrame.LookVector
					if math.abs(look.X) + math.abs(look.Z) > 0.01 then
						aimRemote:FireServer(math.deg(math.atan2(look.Z, look.X)))
					end
				end
			end
		end
	end)
end

return LightController
