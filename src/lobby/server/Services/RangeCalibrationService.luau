--!strict
-- Calibración del tiro en el campo de tiro del Lobby (Fase 24d). Mide cómo se comporta cada proyectil (arma o
-- habilidad, por su "source" en Combat/Projectiles) antes de tocar la balística: por jugador, por "source" y
-- por la distancia del tirador al impacto en tres cubos (Near, Mid, Far; Config.Range.Calibration), guarda
-- cuántos tiros hubo y cuántos dieron a un combatiente, la suma del tiempo de vuelo y del recorrido, el desvío
-- sobre las pantallas de ajuste (dx, dy y su dispersión, cuando el tiro acabó en una) y los grados entre la
-- puntería que mandó el cliente y la dirección final (ayuda del táctil y dispersión del arma; solo con un
-- control táctil, AimInputService). Solo cuentan los tiros de jugadores dentro del recinto. Tras cada tiro le
-- manda al tirador las estadísticas de ese "source" (Remotes.RangeCalibration, como mucho una vez cada
-- Config.Range.Calibration.SendInterval). «Borrar marcas» (BorrarMarcasPrompt) también las borra. El panel pide además borrar datos y cambiar la
-- distancia y el movimiento del muñeco por Remotes.RangeCalibrationControl, que se valida aquí (tipo y valor, dentro
-- del recinto, vivo, Config.Range.Calibration.ControlInterval por jugador). Solo en Studio,
-- el cliente puede pedir un volcado de todo (RangeCalibrationExport) que queda en ServerStorage.CalibracionExportada.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AimInputService = require(ServerScriptService.Combat.Services.AimInputService)
local Projectiles = require(ServerScriptService.Combat.Projectiles)
local RangeScreenMath = require(script.Parent.Parent.World.RangeScreenMath)
local RangeCalibrationDummyService = require(script.Parent.RangeCalibrationDummyService)

local SETTINGS = Config.Range.Calibration
local CLEAR_PROMPT = "BorrarMarcasPrompt"
-- Margen sobre el alcance del aviso por el retraso de la red.
local REACH_SLACK = 8
-- Lo que se le da de margen al recinto para contar al jugador como dentro.
local INSIDE_SLACK = 2
local EXPORT_MIN_INTERVAL = 1
local BUCKETS = { "Near", "Mid", "Far" }

type Bucket = {
	n: number,
	hits: number,
	flight: number,
	travelled: number,
	screenN: number,
	sumDx: number,
	sumDy: number,
	sumSq: number,
	assistN: number,
	assist: number,
}

type SourceStats = { buckets: { [string]: Bucket }, lastUsed: number, lastSent: number, scheduled: boolean }

local RangeCalibrationService = {}

local stats: { [Player]: { [string]: SourceStats } } = {}
local lastExport: { [Player]: number } = {}
local lastControl: { [Player]: number } = {}
local floorSlab: BasePart? = nil

local function newBucket(): Bucket
	return {
		n = 0,
		hits = 0,
		flight = 0,
		travelled = 0,
		screenN = 0,
		sumDx = 0,
		sumDy = 0,
		sumSq = 0,
		assistN = 0,
		assist = 0,
	}
end

-- true si "root" está dentro del recinto (la losa del suelo).
local function insideRange(root: BasePart): boolean
	local slab = floorSlab
	if not (slab and slab.Parent) then
		local range = Workspace:FindFirstChild("CampoDeTiro")
		local floor = range and range:FindFirstChild("Suelo")
		local found = floor and floor:FindFirstChild("Losa")
		slab = if found and found:IsA("BasePart") then found else nil
		floorSlab = slab
	end
	if not slab then
		return false
	end
	local at = slab.CFrame:PointToObjectSpace(root.Position)
	return math.abs(at.X) <= slab.Size.X / 2 + INSIDE_SLACK and math.abs(at.Z) <= slab.Size.Z / 2 + INSIDE_SLACK
end

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function bucketName(distance: number): string
	if distance <= SETTINGS.NearMax then
		return "Near"
	end
	return if distance >= SETTINGS.FarMin then "Far" else "Mid"
end

-- Lo que se manda de un cubo: medias ya hechas (sin el campo si no hay datos para esa medida).
local function bucketData(bucket: Bucket): { [string]: number }
	local data: { [string]: number } = { n = bucket.n, hits = bucket.hits }
	if bucket.n > 0 then
		data.meanFlight = bucket.flight / bucket.n
		data.meanTravel = bucket.travelled / bucket.n
	end
	if bucket.screenN > 0 then
		local meanDx = bucket.sumDx / bucket.screenN
		local meanDy = bucket.sumDy / bucket.screenN
		data.screenN = bucket.screenN
		data.meanDx = meanDx
		data.meanDy = meanDy
		data.spread = math.sqrt(math.max(0, bucket.sumSq / bucket.screenN - (meanDx * meanDx + meanDy * meanDy)))
	end
	if bucket.assistN > 0 then
		data.assistN = bucket.assistN
		data.meanAssist = bucket.assist / bucket.assistN
	end
	return data
end

local function snapshot(entry: SourceStats, source: string): { [string]: any }
	local data: { [string]: any } = {}
	for _, name in BUCKETS do
		data[name] = bucketData(entry.buckets[name])
	end
	-- Dispersión configurada del arma del Laboratorio, solo como referencia.
	local weapon = LabWeapons.weapons[source]
	local spread = if weapon then weapon.lab.spread else nil
	if spread then
		data.labSpread = {
			still = spread.still,
			moving = spread.moving,
			air = spread.air,
			perShot = spread.perShot,
			maxShots = spread.maxShots,
		}
	end
	return data
end

local function send(player: Player, source: string)
	local entry = if stats[player] then stats[player][source] else nil
	if not entry or not player.Parent then
		return
	end
	entry.lastSent = os.clock()
	entry.scheduled = false
	Remotes.RangeCalibration:FireClient(player, "Snapshot", source, snapshot(entry, source))
end

-- Manda ya, o dentro de lo que falta para el intervalo mínimo (así el último tiro de una ráfaga no se pierde).
local function queueSend(player: Player, source: string, entry: SourceStats)
	local wait = SETTINGS.SendInterval - (os.clock() - entry.lastSent)
	if wait <= 0 then
		send(player, source)
	elseif not entry.scheduled then
		entry.scheduled = true
		task.delay(wait, send, player, source)
	end
end

-- Quita la fuente que hace más que no se usa si hay demasiadas.
local function trim(own: { [string]: SourceStats })
	local count = 0
	local oldest: string? = nil
	local oldestTime = math.huge
	for source, entry in own do
		count += 1
		if entry.lastUsed < oldestTime then
			oldest = source
			oldestTime = entry.lastUsed
		end
	end
	if count > SETTINGS.MaxSources and oldest then
		own[oldest] = nil
	end
end

local function onImpact(
	shooter: Player,
	position: Vector3,
	instance: Instance?,
	_model: Model?,
	info: Projectiles.ImpactInfo?
)
	if not info then
		return
	end
	local source = info.source
	local root = livingRoot(shooter)
	if typeof(source) ~= "string" or not root or not insideRange(root) then
		return
	end
	local own = stats[shooter]
	if not own then
		own = {}
		stats[shooter] = own
	end
	local entry = own[source]
	if not entry then
		local buckets: { [string]: Bucket } = {}
		for _, name in BUCKETS do
			buckets[name] = newBucket()
		end
		entry = { buckets = buckets, lastUsed = 0, lastSent = -math.huge, scheduled = false }
		own[source] = entry
	end
	entry.lastUsed = os.clock()
	local bucket = entry.buckets[bucketName((position - info.origin).Magnitude)]
	bucket.n += 1
	if info.hitAny then
		bucket.hits += 1
	end
	bucket.flight += info.elapsed
	bucket.travelled += info.travelled
	if instance then
		local screenId, dx, dy = RangeScreenMath.locate(instance, position)
		if screenId then
			bucket.screenN += 1
			bucket.sumDx += dx
			bucket.sumDy += dy
			bucket.sumSq += dx * dx + dy * dy
		end
	end
	local aim = info.aimDirection
	if aim and aim.Magnitude > 1e-3 and AimInputService.isTouch(shooter) then
		local cosine = math.clamp(aim.Unit:Dot(info.direction.Unit), -1, 1)
		bucket.assistN += 1
		bucket.assist += math.deg(math.acos(cosine))
	end
	trim(own)
	queueSend(shooter, source, entry)
end

-- Borra las estadísticas de "player" y avisa a su cliente.
local function clear(player: Player)
	stats[player] = nil
	Remotes.RangeCalibration:FireClient(player, "Clear")
end

local function hook(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == CLEAR_PROMPT then
		instance.Triggered:Connect(function(player: Player)
			local root = livingRoot(player)
			local anchor = instance.Parent
			if
				root
				and anchor
				and anchor:IsA("BasePart")
				and (root.Position - anchor.Position).Magnitude <= instance.MaxActivationDistance + REACH_SLACK
			then
				clear(player)
			end
		end)
	end
end

-- Solo Studio: deja en ServerStorage.CalibracionExportada el JSON de todo lo medido por "player" (24f).
local function export(player: Player)
	local now = os.clock()
	if now - (lastExport[player] or -math.huge) < EXPORT_MIN_INTERVAL then
		return
	end
	lastExport[player] = now
	local sources: { [string]: any } = {}
	local own = stats[player]
	if own then
		for source, entry in own do
			local data = snapshot(entry, source)
			for _, name in BUCKETS do
				data[name] = { stats = data[name], raw = entry.buckets[name] }
			end
			sources[source] = data
		end
	end
	local range = Workspace:FindFirstChild("CampoDeTiro")
	local dummies = range and range:FindFirstChild("Munecos")
	local dummy = dummies and dummies:FindFirstChild("MuniecoCalibracion")
	local found = ServerStorage:FindFirstChild("CalibracionExportada")
	local value: StringValue
	if found and found:IsA("StringValue") then
		value = found
	else
		value = Instance.new("StringValue")
		value.Name = "CalibracionExportada"
		value.Parent = ServerStorage
	end
	value.Value = HttpService:JSONEncode({
		userId = player.UserId,
		time = os.time(),
		input = player:GetAttribute("AimInput"),
		dummyDistance = if dummy then dummy:GetAttribute("CalibrationDistance") else nil,
		dummyMoving = if dummy then dummy:GetAttribute("CalibrationMoving") else nil,
		sources = sources,
	})
end

-- Órdenes del panel: «Distance» (studs de la lista), «Moving» (boolean) y «Clear» (sin valor).
local function onControl(player: Player, kind: any, value: any)
	local now = os.clock()
	if now - (lastControl[player] or -math.huge) < SETTINGS.ControlInterval then
		return
	end
	lastControl[player] = now
	local root = livingRoot(player)
	if not (root and insideRange(root)) then
		return
	end
	if kind == "Distance" then
		if typeof(value) == "number" and table.find(SETTINGS.Distances, value) then
			RangeCalibrationDummyService.setDistance(value)
		end
	elseif kind == "Moving" then
		if typeof(value) == "boolean" then
			RangeCalibrationDummyService.setMoving(value)
		end
	elseif kind == "Clear" then
		clear(player)
	end
end

function RangeCalibrationService:Start()
	Projectiles.onImpact(onImpact)
	for _, instance in Workspace:GetDescendants() do
		hook(instance)
	end
	Workspace.DescendantAdded:Connect(hook)
	if RunService:IsStudio() then
		-- El cliente no manda datos: solo la orden.
		Remotes.RangeCalibrationExport.OnServerEvent:Connect(export)
	end
	Remotes.RangeCalibrationControl.OnServerEvent:Connect(onControl)
	Players.PlayerRemoving:Connect(function(player: Player)
		stats[player] = nil
		lastControl[player] = nil
		lastExport[player] = nil
	end)
end

return RangeCalibrationService
