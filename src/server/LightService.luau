--!strict
-- LightService: the lamp. Fuel, the safe circle, the rotating beam and the lights-out alarm.
--
-- - Fuel drains slowly, 3x faster in storms, 2x more if the lamp room is broken.
-- - Safe-circle radius depends on the lens tier and shrinks as fuel runs low.
-- - The beam rotates on its own; one player at the beam control in the lamp room can aim it.
-- - When fuel hits 0, a 15 s alarm starts. After that the creatures swarm (IsSwarming).
-- Clients draw the circle and beam from SharedState "Light"; the server only sends numbers.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SharedState = require(Shared:WaitForChild("SharedState"))
local StormDirector = require(script.Parent:WaitForChild("StormDirector"))

local L = Config.Light
local LightService = {}

local state: Configuration
local fuel: number = L.StartFuel
local lensTier = 1
local radius = 0
local beamAngle = 90 -- degrees around Y; direction = (cos, 0, sin)
local controller: Player? = nil
local aimTarget: number? = nil
local lightsOutSince: number? = nil
local leaking = false
local center = Config.World.TowerCenter
local lampPos = Config.World.LampPosition
local lampPart: BasePart? = nil
local lampLight: PointLight? = nil
local lastAim: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Signed difference a - b in degrees, in -180..180
local function angleDiff(a: number, b: number): number
	local d = (a - b) % 360
	if d > 180 then
		d -= 360
	end
	return d
end
LightService.AngleDiff = angleDiff

function LightService.IsLit(): boolean
	return fuel > 0
end

function LightService.GetFuel(): number
	return fuel
end

function LightService.GetRadius(): number
	return radius
end

function LightService.GetCenter(): Vector3
	return center
end

-- Is this spot inside the safe circle? (horizontal distance; the tower itself counts as lit)
function LightService.IsPointLit(pos: Vector3): boolean
	if fuel <= 0 then
		return false
	end
	local dx, dz = pos.X - center.X, pos.Z - center.Z
	return math.sqrt(dx * dx + dz * dz) <= radius
end

function LightService.IsSwarming(): boolean
	return lightsOutSince ~= nil and now() - lightsOutSince >= L.LightsOutGrace
end

-- Is this point inside the beam? extraDegrees widens the check for big targets.
function LightService.IsInBeam(pos: Vector3, extraDegrees: number?): boolean
	if fuel <= 0 then
		return false
	end
	local dx, dz = pos.X - center.X, pos.Z - center.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > L.BeamRange or dist < 1 then
		return false
	end
	local angle = math.deg(math.atan2(dz, dx))
	return math.abs(angleDiff(angle, beamAngle)) <= L.BeamHalfWidthDegrees + (extraDegrees or 0)
end

local function updateRadius()
	if fuel <= 0 then
		radius = 0
		return
	end
	local base = L.LensRadius[lensTier] or L.LensRadius[1]
	local frac = fuel / L.MaxFuel
	radius = base * (L.MinRadiusFraction + (1 - L.MinRadiusFraction) * frac)
end

local function updateLamp()
	local lamp = lampPart
	if not lamp then
		return
	end
	if fuel > 0 then
		lamp.Material = Enum.Material.Neon
		lamp.Color = if fuel / L.MaxFuel < L.LowFuelFraction
			then Color3.fromRGB(255, 150, 80)
			else Color3.fromRGB(255, 221, 140)
	else
		lamp.Material = Enum.Material.SmoothPlastic
		lamp.Color = Color3.fromRGB(60, 55, 45)
	end
	local light = lampLight
	if light then
		light.Enabled = fuel > 0
		light.Range = math.clamp(radius, 0, 60)
	end
end

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

local function publish()
	state:SetAttribute("Fuel", round1(fuel))
	state:SetAttribute("MaxFuel", L.MaxFuel)
	state:SetAttribute("Radius", round1(radius))
	state:SetAttribute("IsLit", fuel > 0)
	state:SetAttribute("BeamAngle", round1(beamAngle))
	state:SetAttribute("BeamSpeed", if aimTarget then 0 else L.BeamDegreesPerSecond)
	state:SetAttribute("Controller", if controller then controller.Name else "")
	state:SetAttribute("LightsOutAt", lightsOutSince or 0)
	state:SetAttribute("LensTier", lensTier)
end

local function setFuel(value: number)
	local before = fuel
	fuel = math.clamp(value, 0, L.MaxFuel)
	if before > 0 and fuel <= 0 then
		lightsOutSince = now()
		Remotes.notify(nil, `The lamp is out! Refuel it within {L.LightsOutGrace} seconds!`, "Alarm")
	elseif before <= 0 and fuel > 0 then
		if lightsOutSince then
			Remotes.notify(nil, "The lamp is burning again!", "Good")
		end
		lightsOutSince = nil
	end
	updateRadius()
	updateLamp()
end

function LightService.AddFuel(amount: number)
	setFuel(fuel + amount)
	publish()
end

function LightService.DrainFuel(amount: number)
	setFuel(fuel - amount)
	publish()
end

function LightService.SetLeaking(value: boolean)
	leaking = value
end

function LightService.SetLensTier(tier: number)
	lensTier = math.clamp(tier, 1, #L.LensRadius)
	updateRadius()
	publish()
end

local function releaseControl()
	controller = nil
	aimTarget = nil
end

function LightService.Reset()
	releaseControl()
	leaking = false
	lensTier = 1
	lightsOutSince = nil
	fuel = 0
	setFuel(L.StartFuel)
	lightsOutSince = nil
	publish()
end

local function tick(dt: number)
	local phase = StormDirector.GetPhase()
	if phase ~= "Lost" and phase ~= "Won" and fuel > 0 then
		local drain = L.DrainPerSecond
		if phase == "Storm" then
			drain *= L.StormDrainMultiplier
		end
		if leaking then
			drain *= L.LeakDrainMultiplier
		end
		-- Studio only: DebugDrainMultiplier attribute on Workspace speeds up fuel drain for testing
		local debugDrain = Workspace:GetAttribute("DebugDrainMultiplier")
		if RunService:IsStudio() and typeof(debugDrain) == "number" then
			drain *= debugDrain
		end
		setFuel(fuel - drain * dt)
	end

	-- Drop control if the aiming player leaves the lamp room
	local current = controller
	if current then
		local character = current.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not current.Parent or not root or not root:IsA("BasePart") or (root.Position - lampPos).Magnitude > L.ManualAimMaxDistance then
			releaseControl()
		end
	end

	local target = aimTarget
	if controller and target then
		local d = angleDiff(target, beamAngle)
		local step = L.ManualAimDegreesPerSecond * dt
		beamAngle = (beamAngle + math.clamp(d, -step, step)) % 360
	else
		beamAngle = (beamAngle + L.BeamDegreesPerSecond * dt) % 360
	end
	publish()
end

local function makeBeamConsole()
	local map = Workspace:FindFirstChild("Map")
	local lampRoom = map and map:FindFirstChild("Lighthouse") and map.Lighthouse:FindFirstChild("LampRoom")
	if not lampRoom then
		warn("[LightService] Map.Lighthouse.LampRoom not found")
		return
	end
	local lamp = lampRoom:FindFirstChild("Lamp")
	if lamp and lamp:IsA("BasePart") then
		lampPart = lamp
		local light = lamp:FindFirstChildOfClass("PointLight")
		lampLight = light
	end

	local console = lampRoom:FindFirstChild("BeamControl")
	if not console then
		local part = Instance.new("Part")
		part.Name = "BeamControl"
		part.Anchored = true
		part.Size = Vector3.new(2, 3, 2)
		part.CFrame = CFrame.new(center + Vector3.new(-7, 34.5, 7))
		part.Color = Color3.fromRGB(120, 90, 50)
		part.Material = Enum.Material.Metal
		part.Parent = lampRoom
		console = part
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Aim the beam"
	prompt.ObjectText = "Beam control"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = console
	prompt.Triggered:Connect(function(player: Player)
		if controller == player then
			releaseControl()
			Remotes.notify(player, "You let go of the beam.", nil)
		elseif controller == nil then
			controller = player
			aimTarget = beamAngle
			Remotes.notify(player, "Look where you want the beam to point. Walk away to let go.", nil)
		else
			local holder = controller
			Remotes.notify(player, `{if holder then holder.DisplayName else "Someone"} is aiming the beam.`, nil)
		end
		publish()
	end)
end

function LightService.Start()
	state = SharedState.get("Light")
	makeBeamConsole()

	Remotes.event("AimBeam").OnServerEvent:Connect(function(player: Player, angle: unknown)
		if player ~= controller then
			return
		end
		if typeof(angle) ~= "number" or angle ~= angle or math.abs(angle) > 1e6 then
			return
		end
		local t = os.clock()
		if t - (lastAim[player] or 0) < 0.05 then
			return
		end
		lastAim[player] = t
		aimTarget = angle % 360
	end)
	Remotes.event("ReleaseBeam").OnServerEvent:Connect(function(player: Player)
		if player == controller then
			releaseControl()
			publish()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAim[player] = nil
		if player == controller then
			releaseControl()
		end
	end)

	StormDirector.RunReset:Connect(LightService.Reset)
	LightService.Reset()

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(L.Tick)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
end

return LightService
