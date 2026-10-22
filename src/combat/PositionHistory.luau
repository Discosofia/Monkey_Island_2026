--!strict
-- Posiciones recientes de los combatientes (Fase 10, C3): dónde estaba cada mono, muñeco o personaje
-- en el último Config.Net.HistorySeconds, a Config.Net.HistoryRate muestras por segundo. Sirve para
-- rebobinar al golpear (Combat/Hitbox): el atacante ve a los demás con su retraso de red y el servidor
-- mira dónde estaban cuando los vio, con el tope de Combat/Latency.
-- Cada combatiente guarda un anillo fijo de muestras (sin crear tablas en cada muestra).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local SIZE = math.ceil(Config.Net.HistorySeconds * Config.Net.HistoryRate) + 1
local INTERVAL = 1 / Config.Net.HistoryRate

type Ring = { times: { number }, positions: { Vector3 }, newest: number, count: number }

local PositionHistory = {}

local rings: { [Model]: Ring } = {}
local started = false

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function record(model: Model, time: number)
	local root = rootOf(model)
	if not root then
		return
	end
	local ring = rings[model]
	if not ring then
		ring = { times = table.create(SIZE, 0), positions = table.create(SIZE, Vector3.zero), newest = 0, count = 0 }
		rings[model] = ring
	end
	ring.newest = ring.newest % SIZE + 1
	ring.count = math.min(ring.count + 1, SIZE)
	ring.times[ring.newest] = time
	ring.positions[ring.newest] = root.Position
end

-- Dónde estaba la raíz de "model" hace "seconds" (interpolando entre muestras), o nil si no hay
-- muestras. Si "seconds" va más allá de lo guardado, la más vieja.
function PositionHistory.at(model: Model, seconds: number): Vector3?
	local ring = rings[model]
	if not ring or ring.count == 0 then
		return nil
	end
	local target = os.clock() - seconds
	local index = ring.newest
	local laterTime, laterPosition = ring.times[index], ring.positions[index]
	if target >= laterTime then
		return laterPosition
	end
	for _ = 2, ring.count do
		index = (index - 2) % SIZE + 1
		local time, position = ring.times[index], ring.positions[index]
		if time <= target then
			local alpha = (target - time) / math.max(laterTime - time, 1e-3)
			return position:Lerp(laterPosition, alpha)
		end
		laterTime, laterPosition = time, position
	end
	return laterPosition
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
