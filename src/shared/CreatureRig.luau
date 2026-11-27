--!strict
-- CreatureRig: plays animations made in Blender on a creature's skinned-mesh bones.
--
-- Blender exports, for every animated bone and every sample, the bone's frame in model space
-- (metres, Z up): {x, y, z, qx, qy, qz, qw}  (see ReplicatedStorage.CreatureAnimData.<Kind>).
-- At load we convert those once into Bone.Transform values for the Roblox rig (fixing axes,
-- scale and each bone's import orientation), so playback is only interpolation.
--
-- Usage (client):
--   local player = CreatureRig.newPlayer(model, "FogCrawler")
--   player:play("Crawl", speed)      -- clips: whatever the data module contains
--   player:step(dt)                  -- every frame

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureRig = {}

type Clip = { loop: boolean, frames: { { [string]: CFrame } } }
type Rig = { fps: number, clips: { [string]: Clip }, animated: { string } }

local rigs: { [string]: Rig } = {}

-- Blender axes -> Roblox axes: (x, y, z) -> (-x, z, y)
local K = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))

local function rawFrame(t: { number }): CFrame
	return CFrame.new(t[1], t[2], t[3], t[4], t[5], t[6], t[7])
end

local function collectBones(root: Instance): ({ Bone }, { [string]: Bone })
	local ordered: { Bone } = {}
	local byName: { [string]: Bone } = {}
	local function visit(inst: Instance)
		for _, child in inst:GetChildren() do
			if child:IsA("Bone") then
				table.insert(ordered, child)
				byName[child.Name] = child
			end
			visit(child)
		end
	end
	visit(root)
	return ordered, byName
end

local function bodyOf(model: Model): MeshPart
	local body = model:FindFirstChild("Body", true)
	assert(body and body:IsA("MeshPart"), "creature model needs a MeshPart named Body")
	return body
end

-- Build (once per kind) the Bone.Transform table for every clip frame
function CreatureRig.load(kind: string, sample: Model): Rig
	local cached = rigs[kind]
	if cached then
		return cached
	end
	local dataModule = ReplicatedStorage:WaitForChild("CreatureAnimData"):WaitForChild(kind)
	assert(dataModule:IsA("ModuleScript"), "animation data must be a ModuleScript")
	local data = require(dataModule) :: any
	local body = bodyOf(sample)
	local ordered, byName = collectBones(body)

	-- Rest frames of every bone in the mesh's space
	local restSpace: { [Bone]: CFrame } = {}
	for _, bone in ordered do
		local parent = bone.Parent
		local parentSpace = if parent and parent:IsA("Bone") then restSpace[parent] else CFrame.identity
		restSpace[bone] = parentSpace * bone.CFrame
	end

	-- Scale (studs per metre) and offset, measured from two animated bones
	local rootName = data.bones[1]
	local farName = data.bones[#data.bones]
	local a, b = byName[rootName], byName[farName]
	local ka = (K * rawFrame(data.rest[rootName])).Position
	local kb = (K * rawFrame(data.rest[farName])).Position
	local scale = (restSpace[b].Position - restSpace[a].Position).Magnitude / math.max((kb - ka).Magnitude, 1e-4)
	local offset = restSpace[a].Position - ka * scale

	-- Per-bone orientation correction between Blender and the imported Roblox bone
	local correction: { [string]: CFrame } = {}
	local animatedSet: { [string]: boolean } = {}
	for _, name in data.bones do
		local bone = byName[name]
		if bone then
			local kr = (K * rawFrame(data.rest[name])).Rotation
			correction[name] = kr:Inverse() * restSpace[bone].Rotation
			animatedSet[name] = true
		end
	end

	local clips: { [string]: Clip } = {}
	for clipName, clip in data.clips do
		local frames = {}
		for i, row in clip.frames do
			local desired: { [string]: CFrame } = {}
			for j, name in data.bones do
				if correction[name] then
					local f = K * rawFrame(row[j])
					desired[name] = CFrame.new(f.Position * scale + offset) * f.Rotation * correction[name]
				end
			end
			local animSpace: { [Bone]: CFrame } = {}
			local transforms: { [string]: CFrame } = {}
			for _, bone in ordered do
				local parent = bone.Parent
				local parentSpace = if parent and parent:IsA("Bone") then animSpace[parent] else CFrame.identity
				local base = parentSpace * bone.CFrame
				local want = desired[bone.Name]
				if want then
					transforms[bone.Name] = base:Inverse() * want
					animSpace[bone] = want
				else
					animSpace[bone] = base
				end
			end
			frames[i] = transforms
		end
		clips[clipName] = { loop = clip.loop, frames = frames }
	end

	local animated = {}
	for name in animatedSet do
		table.insert(animated, name)
	end
	local rig: Rig = { fps = data.fps, clips = clips, animated = animated }
	rigs[kind] = rig
	return rig
end

-------------------------------------------------------------------------------
-- Player: one per creature instance
-------------------------------------------------------------------------------
local Player = {}
Player.__index = Player

export type AnimPlayer = typeof(setmetatable({} :: {
	rig: Rig,
	bones: { [string]: Bone },
	clip: Clip?,
	clipName: string,
	time: number,
	speed: number,
	fadeFrom: { [string]: CFrame },
	fade: number,
	last: { [string]: CFrame },
}, Player))

function CreatureRig.newPlayer(model: Model, kind: string): AnimPlayer
	local rig = CreatureRig.load(kind, model)
	local _, byName = collectBones(bodyOf(model))
	local self = setmetatable({
		rig = rig,
		bones = byName,
		clip = nil,
		clipName = "",
		time = 0,
		speed = 1,
		fadeFrom = {},
		fade = 1,
		last = {},
	}, Player)
	return self
end

-- Switch clip (cross-fades from the current pose over fadeSeconds)
function Player.play(self: AnimPlayer, clipName: string, speed: number?, fadeSeconds: number?)
	self.speed = speed or 1
	if clipName == self.clipName then
		return
	end
	local clip = self.rig.clips[clipName]
	if not clip then
		return
	end
	self.clip = clip
	self.clipName = clipName
	self.time = 0
	self.fadeFrom = table.clone(self.last)
	self.fade = if fadeSeconds == 0 then 1 else 0
	self.fadeRate = 1 / (fadeSeconds or 0.32)
end

function Player.isFinished(self: AnimPlayer): boolean
	local clip = self.clip
	if not clip or clip.loop then
		return false
	end
	return self.time * self.rig.fps >= #clip.frames - 1
end

function Player.step(self: AnimPlayer, dt: number)
	local clip = self.clip
	if not clip then
		return
	end
	self.time += dt * self.speed
	local count = #clip.frames
	local pos = self.time * self.rig.fps
	local i0, i1, alpha
	if clip.loop then
		pos %= count
		i0 = math.floor(pos) + 1
		i1 = i0 % count + 1
		alpha = pos % 1
	else
		pos = math.min(pos, count - 1)
		i0 = math.floor(pos) + 1
		i1 = math.min(i0 + 1, count)
		alpha = pos % 1
	end
	if self.fade < 1 then
		self.fade = math.min(1, self.fade + dt * ((self :: any).fadeRate or 5))
	end
	local f0, f1 = clip.frames[i0], clip.frames[i1]
	for name, bone in self.bones do
		local a, b = f0[name], f1[name]
		if a and b then
			local cf = a:Lerp(b, alpha)
			if self.fade < 1 then
				local from = self.fadeFrom[name]
				if from then
					-- eased cross-fade: the old pose lets go gently instead of linearly
					local k = self.fade * self.fade * (3 - 2 * self.fade)
					cf = from:Lerp(cf, k)
				end
			end
			bone.Transform = cf
			self.last[name] = cf
		end
	end
end

return CreatureRig
