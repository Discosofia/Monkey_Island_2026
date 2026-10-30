--!strict
-- Posiciones recientes de los combatientes (Fase 10, C3): dónde estaba cada mono, muñeco o personaje
-- en el último Config.Net.HistorySeconds, a Config.Net.HistoryRate muestras por segundo. Sirve para
-- rebobinar al golpear (Combat/Hitbox): el atacante ve a los demás con su retraso de red y el servidor
-- mira dónde estaban cuando los vio, con el tope de Combat/Latency.
-- Cada combatiente guarda un anillo fijo de muestras (sin crear tablas en cada muestra).
-- Poses (Fase 19, W6): de los personajes R15 de los jugadores se guarda además el CFrame de cada una de
-- sus 15 piezas relativo a la posición de la raíz (se le resta; la orientación es la del mundo, así no hace
-- falta guardar el giro de la raíz), en las mismas muestras, para probar el disparo contra la pieza donde
-- estaba (Hitbox.sweepBodies). El anillo dura el mayor de Config.Net.HistorySeconds y
-- Config.Combat.Zones.PoseHistorySeconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local SIZE = math.ceil(
	math.max(Config.Net.HistorySeconds, Config.Combat.Zones.PoseHistorySeconds) * Config.Net.HistoryRate
) + 1
local INTERVAL = 1 / Config.Net.HistoryRate

-- Las piezas de un R15, en el orden en que se guardan en cada muestra.
local POSE_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local PART_COUNT = #POSE_PARTS

type Ring = {
	times: { number },
	positions: { Vector3 },
	newest: number,
	count: number,
	-- Solo personajes R15 de jugadores: las piezas, su tamaño actual (Vector3.zero si falta) y, de cada
	-- muestra, los PART_COUNT CFrames menos la posición de la raíz (la muestra i empieza en (i - 1) × PART_COUNT + 1).
	parts: { BasePart? }?,
	sizes: { Vector3 }?,
	poses: { CFrame }?,
}

local PositionHistory = {}

-- Nombres de las piezas del R15 en el orden de las poses (no cambiar).
PositionHistory.POSE_PARTS = POSE_PARTS

local rings: { [Model]: Ring } = {}
local started = false

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

-- Prepara las piezas de un personaje R15 de jugador en su anillo.
local function setupPose(ring: Ring, model: Model)
	if not (Players:GetPlayerFromCharacter(model) and model:FindFirstChild("UpperTorso")) then
		return
	end
	local parts: { BasePart? } = table.create(PART_COUNT)
	for index, name in POSE_PARTS do
		local part = model:FindFirstChild(name)
		parts[index] = if part and part:IsA("BasePart") then part else nil
	end
	ring.parts = parts
	ring.sizes = table.create(PART_COUNT, Vector3.zero)
	ring.poses = table.create(SIZE * PART_COUNT, CFrame.identity)
end

local function record(model: Model, time: number)
	local root = rootOf(model)
	if not root then
		return
	end
	local ring = rings[model]
	if not ring then
		ring = { times = table.create(SIZE, 0), positions = table.create(SIZE, Vector3.zero), newest = 0, count = 0 }
		setupPose(ring, model)
		rings[model] = ring
	end
	ring.newest = ring.newest % SIZE + 1
	ring.count = math.min(ring.count + 1, SIZE)
	ring.times[ring.newest] = time
	ring.positions[ring.newest] = root.Position
	local parts, sizes, poses = ring.parts, ring.sizes, ring.poses
	if parts and sizes and poses then
		local rootPosition = root.Position
		local base = (ring.newest - 1) * PART_COUNT
		for index = 1, PART_COUNT do
			local part = parts[index]
			if part and part.Parent then
				poses[base + index] = part.CFrame - rootPosition
				sizes[index] = part.Size
			else
				sizes[index] = Vector3.zero
			end
		end
	end
end

-- Las dos muestras entre las que cae "seconds" atrás: la más vieja, la más nueva y cuánto (0 a 1) hay de la
-- vieja a la nueva. Si "seconds" va más allá de lo guardado, la más vieja (alfa 0); si es ahora, la última.
local function locate(ring: Ring, seconds: number): (number, number, number)
	local target = os.clock() - seconds
	local times = ring.times
	local later = ring.newest
	if target >= times[later] then
		return later, later, 0
	end
	for _ = 2, ring.count do
		local earlier = (later - 2) % SIZE + 1
		local time = times[earlier]
		if time <= target then
			return earlier, later, (target - time) / math.max(times[later] - time, 1e-3)
		end
		later = earlier
	end
	return later, later, 0
end

-- Dónde estaba la raíz de "model" hace "seconds" (interpolando entre muestras), o nil si no hay
-- muestras. Si "seconds" va más allá de lo guardado, la más vieja.
function PositionHistory.at(model: Model, seconds: number): Vector3?
	local ring = rings[model]
	if not ring or ring.count == 0 then
		return nil
	end
	local earlier, later, alpha = locate(ring, seconds)
	if earlier == later then
		return ring.positions[later]
	end
	return ring.positions[earlier]:Lerp(ring.positions[later], alpha)
end

-- Escribe en "out" (un array de PART_COUNT CFrames que reutiliza quien llama; sin crear tablas) la pose
-- de las piezas de "model" hace "seconds", relativa a la posición de su raíz de entonces (sumándole
-- PositionHistory.at sale el CFrame del mundo), y en "sizes" su tamaño. Devuelve
-- false si no hay historia de pose (no es un R15 de jugador o aún no hay muestras). Una pieza que faltaba
-- tiene tamaño Vector3.zero.
function PositionHistory.poseInto(model: Model, seconds: number, out: { CFrame }, sizes: { Vector3 }): boolean
	local ring = rings[model]
	local poses, ringSizes = if ring then ring.poses else nil, if ring then ring.sizes else nil
	if not (ring and poses and ringSizes) or ring.count == 0 then
		return false
	end
	local earlier, later, alpha = locate(ring, seconds)
	local baseEarlier = (earlier - 1) * PART_COUNT
	local baseLater = (later - 1) * PART_COUNT
	for index = 1, PART_COUNT do
		sizes[index] = ringSizes[index]
		if earlier == later then
			out[index] = poses[baseLater + index]
		else
			out[index] = poses[baseEarlier + index]:Lerp(poses[baseLater + index], alpha)
		end
	end
	return true
end

-- Cómo estaban las piezas de "model" hace "seconds": nombre de pieza → CFrame relativo a la posición de la
-- raíz de ese instante (la raíz rebobinada es PositionHistory.at; CFrame del mundo = pose + raíz). nil si no hay historia de pose. Crea una tabla:
-- para el disparo, Hitbox usa poseInto.
function PositionHistory.poseAt(model: Model, seconds: number): { [string]: CFrame }?
	local out: { CFrame } = table.create(PART_COUNT, CFrame.identity)
	local sizes: { Vector3 } = table.create(PART_COUNT, Vector3.zero)
	if not PositionHistory.poseInto(model, seconds, out, sizes) then
		return nil
	end
	local pose: { [string]: CFrame } = {}
	for index, name in POSE_PARTS do
		if sizes[index] ~= Vector3.zero then
			pose[name] = out[index]
		end
	end
	return pose
end

-- Empieza a guardar las posiciones de lo que devuelva "list" (Hitbox.combatants). Olvida a los que
-- ya no están.
function PositionHistory.start(list: () -> { Model })
	if started then
		return
	end
	started = true
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < INTERVAL then
			return
		end
		elapsed = 0
		local time = os.clock()
		local present: { [Model]: boolean } = {}
		for _, model in list() do
			present[model] = true
			record(model, time)
		end
		for model in rings do
			if not present[model] then
				rings[model] = nil
			end
		end
	end)
end

return PositionHistory
