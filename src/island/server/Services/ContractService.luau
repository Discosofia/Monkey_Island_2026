--!strict
-- Contrato de expedición de la partida (Fase 9, G6; Data/Contracts, Config.Contracts, Shared/Contract).
--   - Al arrancar el servidor toca uno al azar. Es de todo el grupo: lo que hace cualquiera cuenta.
--   - Sus pasos se abren en su día (al amanecer) y el que no se ha cumplido cuando abre el siguiente se
--     pierde. Los objetivos con "scales" crecen con los jugadores que hay en la partida.
--   - Cuenta con los mismos avisos que las misiones (Retention.onProgress: monos, recursos, piezas,
--     jefes, cajas de suministro, la baliza…) y él mismo mira quién llega a una guarida ("Visit").
--   - Al cumplir un paso, todos los que están en la partida se llevan su premio: Ámbar, XP del pase
--     (de partida: con el tope del día) y los objetos del paso para esta partida.
-- Publica el estado en ReplicatedStorage ("Contract") para la tarjeta del HUD y los resultados.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Contract = require(ReplicatedStorage.Shared.Contract)
local Contracts = require(ReplicatedStorage.Shared.Data.Contracts)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Retention = require(ServerScriptService.ServerShared.Retention)
local SeasonPass = require(ServerScriptService.ServerShared.SeasonPass)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)

local C = Config.Contracts

local ContractService = {}

local contractIds: { string } = {}
local contract: Contracts.Contract
local state: Contract.State
-- Lo que ya ha contado el paso abierto en los "distinct" (especies).
local seen: { [string]: boolean } = {}

-- Aviso a todos: plantilla en español y sus argumentos, que traduce cada cliente.
local function announce(text: string, args: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text, args)
	end
end

local function targetFor(step: Contracts.Step): number
	if not step.scales then
		return step.target
	end
	local players = math.max(1, #Players:GetPlayers())
	return math.ceil(step.target * (1 + C.TargetPerExtraPlayer * (players - 1)))
end

local function newState(contractId: string): Contract.State
	local steps: { Contract.StepState } = {}
	for _, step in Contracts[contractId].steps do
		table.insert(steps, { status = "locked", progress = 0, target = targetFor(step) })
	end
	return { id = contractId, index = 0, steps = steps }
end

-- Premio del paso "index" para un jugador.
local function reward(player: Player, index: number)
	local step = contract.steps[index]
	local prize = C.StepRewards[index] or {}
	-- Cada línea es una frase con argumentos (Shared/Strings), como las que da Retention.grant.
	local lines: { any } = {}
	if prize.amber then
		lines = Retention.grant(player, { amber = prize.amber }, true, "Contract")
	end
	if prize.xp then
		local gain = SeasonPass.addXp(player, "Match", prize.xp)
		if gain and gain.xp > 0 then
			table.insert(lines, { Strings.later("⭐ +{xp} XP de pase"), { xp = gain.xp } })
		end
	end
	if step.items then
		for itemId, amount in step.items do
			InventoryService.collect(player, itemId, amount)
		end
		table.insert(lines, Rewards.itemsArg(step.items))
	end
	Remotes.Notify:FireClient(
		player,
		"📜 ¡Paso del contrato cumplido! {icon} {title}: {lines}",
		{ icon = step.icon, title = { step.title }, lines = { list = lines, sep = " · " } }
	)
end

local function complete(index: number)
	local entry = state.steps[index]
	entry.status = "done"
	entry.progress = entry.target
	Contract.write(state)
	for _, player in Players:GetPlayers() do
		task.spawn(reward, player, index)
	end
end

-- Pone al día los objetivos que crecen con el grupo (al entrar o salir alguien) y cumple el paso
-- abierto si ya llega.
local function retarget()
	for index, entry in state.steps do
		if entry.status == "locked" or entry.status == "active" then
			entry.target = targetFor(contract.steps[index])
		end
	end
	local entry = state.steps[state.index]
	if entry and entry.status == "active" and entry.progress >= entry.target then
		complete(state.index)
	else
		Contract.write(state)
	end
end

-- Abre los pasos cuyo día ha llegado; el abierto que no se cumplió se pierde.
local function openUpTo(day: number)
	for index, step in contract.steps do
		local entry = state.steps[index]
		if entry.status == "locked" and step.day <= day then
			local previous = state.steps[index - 1]
			if previous and previous.status == "active" then
				previous.status = "failed"
				announce(
					"📜 Se acabó el plazo del paso «{title}» del contrato",
					{ title = { contract.steps[index - 1].title } }
				)
			end
			entry.status = "active"
			entry.target = targetFor(step)
			state.index = index
			table.clear(seen)
			announce(
				"📜 Contrato: nuevo paso. {icon} {step}",
				{ icon = step.icon, step = { step.text, { target = entry.target } } }
			)
		end
	end
	Contract.write(state)
end

-- Cuenta un aviso para el paso abierto.
local function count(event: string, amount: number, key: string?)
	if MatchService.isOver() then
		return
	end
	local index = state.index
	local entry = state.steps[index]
	local step = contract.steps[index]
	if not entry or entry.status ~= "active" or step.event ~= event then
		return
	elseif step.key and key ~= step.key then
		return
	elseif step.keys and not (key and table.find(step.keys, key)) then
		return
	end
	if step.distinct then
		if not key or seen[key] then
			return
		end
		seen[key] = true
		entry.progress += 1
	else
		entry.progress += amount
	end
	if entry.progress >= entry.target then
		complete(index)
	else
		Contract.write(state)
	end
end

-- "Visit": alguien vivo a menos de VisitRadius de la guarida del bioma.
local function checkVisit()
	local step = contract.steps[state.index]
	local entry = state.steps[state.index]
	if not (step and entry and entry.status == "active" and step.event == "Visit" and step.key) then
		return
	end
	local marker = Workspace:FindFirstChild(`Guarida_{step.key}`, true)
	if not (marker and marker:IsA("BasePart")) then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and LifeState.isAlive(player) then
			local distance = (character:GetPivot().Position - marker.Position).Magnitude
			if distance <= C.VisitRadius then
				count("Visit", 1, step.key)
				return
			end
		end
	end
end

local function start(contractId: string)
	contract = Contracts[contractId]
	state = newState(contractId)
	table.clear(seen)
	local match = MatchState.read()
	openUpTo(if match then match.day else 1)
end

function ContractService:Init()
	for contractId in Contracts do
		table.insert(contractIds, contractId)
	end
	table.sort(contractIds)
	start(contractIds[Random.new():NextInteger(1, #contractIds)])
	Retention.onProgress(function(_player: Player, event: string, amount: number, key: string?)
		count(event, amount, key)
	end)
	DayNightService.onPhaseStarted(function(day: number, phase: MatchState.Phase)
		if phase == "Day" and not MatchService.isOver() then
			openUpTo(day)
		end
	end)
end

function ContractService:Start()
	Players.PlayerAdded:Connect(retarget)
	Players.PlayerRemoving:Connect(function()
		task.defer(retarget)
	end)
	while true do
		task.wait(C.CheckSeconds)
		checkVisit()
	end
end

-- Prueba (panel de Studio): cumple el paso abierto.
function ContractService.debugCompleteStep()
	local entry = state.steps[state.index]
	if entry and entry.status == "active" then
		complete(state.index)
	end
end

-- Prueba (panel de Studio): empieza el siguiente contrato (los pasos de los días pasados, abiertos).
function ContractService.debugNextContract(): string
	local current = table.find(contractIds, state.id) or 0
	start(contractIds[current % #contractIds + 1])
	return contract.name
end

return ContractService
