--!strict
-- Medición de rendimiento del servidor (Fase 16, R2). Solo mide mientras algún administrador tiene
-- abierta la pestaña "📈 Rendimiento" del panel (Shared/UI/AdminPanel), cada Config.Performance.SampleSeconds:
--   - Stats del servidor: instancias, primitivas, primitivas en movimiento, FPS, paso de físicas y memoria.
--   - Piezas (BasePart) de Workspace por categoría, con un solo recorrido repartido en fotogramas.
--   - La muestra del cliente del administrador (draw calls, triángulos, memoria y FPS), que él mismo manda
--     por Remotes.AdminPerf y el servidor valida y reenvía al panel.
-- Performance.count() también lo usa island/Services/PerformanceService para su registro en la Salida.
-- Categorías: personajes (sin armadura ni herramientas), armadura (ArmorPiece), herramientas (Tool), mascotas
-- y monturas (modelos con "Pet"/"Mascota" o "Mount"/"Montura" en el nombre; hoy se dibujan en el cliente, así
-- que en el servidor salen a 0), estructuras (carpeta de construibles), enemigos (etiqueta EnemyTag), efectos
-- (antecesor "Fx"/"Efecto"/"Effect"), mapa (el resto anclado) y otros (el resto suelto).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestCooldown = require(script.Parent.RequestCooldown)

local Performance = {}

Performance.CATEGORIES =
	{ "characters", "armor", "tools", "pets", "mounts", "structures", "enemies", "fx", "map", "other" }

-- Estadísticas del cliente que acepta el servidor (con su tope, contra valores absurdos).
local CLIENT_FIELDS: { [string]: number } = {
	drawCalls = 1e6,
	triangles = 1e9,
	memory = 1e5,
	fps = 1e4,
}

local subscribers: { [Player]: boolean } = {}
local started = false
local frames = 0
local canSubscribe = RequestCooldown.new(1)
local canReport = RequestCooldown.new(2)

local function readStat(name: string): number?
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and typeof(value) == "number" then value else nil
end

-- Qué es una pieza según sus antecesores hasta Workspace.
local function classify(part: BasePart): string
	local armor, tool, pet, mount, character = false, false, false, false, false
	local structures, enemy, fx = false, false, false
	local ancestor: Instance? = part.Parent
	while ancestor and ancestor ~= Workspace do
		local name = ancestor.Name
		if name == "ArmorPiece" then
			armor = true
		elseif ancestor:IsA("Tool") then
			tool = true
		elseif name == Building.STRUCTURES_FOLDER then
			structures = true
		elseif string.find(name, "Pet", 1, true) or string.find(name, "Mascota", 1, true) then
			pet = true
		elseif string.find(name, "Mount", 1, true) or string.find(name, "Montura", 1, true) then
			mount = true
		elseif
			string.find(name, "Fx", 1, true)
			or string.find(name, "Efecto", 1, true)
			or string.find(name, "Effect", 1, true)
		then
			fx = true
		end
		if ancestor:IsA("Model") then
			if Players:GetPlayerFromCharacter(ancestor) then
				character = true
			elseif CollectionService:HasTag(ancestor, Config.Combat.EnemyTag) then
				enemy = true
			end
		end
		ancestor = ancestor.Parent
	end
	if character then
		return if armor then "armor" elseif tool then "tools" else "characters"
	elseif enemy then
		return "enemies"
	elseif pet then
		return "pets"
	elseif mount then
		return "mounts"
	elseif structures then
		return "structures"
	elseif fx then
		return "fx"
	end
	return if part.Anchored then "map" else "other"
end

-- Cuenta las piezas de Workspace por categoría. Cede cada Config.Performance.CountChunk instancias.
-- Devuelve (total, categorías).
function Performance.count(): (number, { [string]: number })
	local cats: { [string]: number } = {}
	for _, id in Performance.CATEGORIES do
		cats[id] = 0
	end
	local total = 0
	local seen = 0
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("BasePart") then
			local kind = classify(instance)
			cats[kind] += 1
			total += 1
		end
		seen += 1
		if seen % Config.Performance.CountChunk == 0 then
			task.wait()
		end
	end
	return total, cats
end

-- Una muestra completa del servidor; fps = los fotogramas del servidor desde la muestra anterior.
local function sample(fps: number): { [string]: any }
	local total, cats = Performance.count()
	local memory = 0
	pcall(function()
		memory = Stats:GetTotalMemoryUsageMb()
	end)
	return {
		players = #Players:GetPlayers(),
		instances = readStat("InstanceCount") or 0,
		primitives = readStat("PrimitivesCount") or 0,
		moving = readStat("MovingPrimitivesCount") or 0,
		physics = readStat("PhysicsStepTimeMs") or -1,
		memory = memory,
		fps = fps,
		parts = total,
		cats = cats,
	}
end

local function subscribersList(): { Player }
	local list = {}
	for player in subscribers do
		table.insert(list, player)
	end
	return list
end

local function run()
	local last = os.clock()
	frames = 0
	while true do
		task.wait(Config.Performance.SampleSeconds)
		if next(subscribers) then
			local now = os.clock()
			local fps = frames / math.max(now - last, 0.001)
			last = now
			frames = 0
			local data = sample(fps)
			for _, player in subscribersList() do
				if player.Parent then
					Remotes.AdminPerf:FireClient(player, "Server", data)
				end
			end
			-- Contar cuesta tiempo: los FPS de la siguiente muestra empiezan ahora.
			last = os.clock()
			frames = 0
		else
			last = os.clock()
			frames = 0
		end
	end
end

-- isAdmin: la comprobación de permisos de ServerShared/Admin.
function Performance.start(_placeName: string, isAdmin: (Player) -> boolean)
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function()
		frames += 1
	end)
	Players.PlayerRemoving:Connect(function(player)
		subscribers[player] = nil
	end)
	Remotes.AdminPerf.OnServerEvent:Connect(function(player: Player, op: any, data: any)
		if not isAdmin(player) then
			return
		end
		if op == "Sub" then
			if canSubscribe(player) then
				subscribers[player] = if data == true then true else nil
			end
		elseif op == "Client" and subscribers[player] and typeof(data) == "table" and canReport(player) then
			local clean: { [string]: number } = {}
			for field, limit in CLIENT_FIELDS do
				local value = (data :: any)[field]
				if typeof(value) == "number" and value == value then
					clean[field] = math.clamp(value, 0, limit)
				end
			end
			Remotes.AdminPerf:FireClient(player, "Client", clean)
		end
	end)
	task.spawn(run)
end

return Performance
