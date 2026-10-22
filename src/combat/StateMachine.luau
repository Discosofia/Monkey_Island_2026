--!strict
-- Máquina de estados de combate de los jugadores (Fase 10, C2). Pone el estado en los atributos del
-- Player que lee Shared/CombatState ("CombatState" y "CombatStateUntil", hora del servidor), así el
-- cliente sabe al momento qué puede hacer y el servidor lo comprueba con CombatState.canAct.
--   - Un estado nuevo solo entra si su prioridad (Config.CombatStates.Priority) es igual o mayor que la
--     del que hay, o si el que hay ya ha terminado: un aturdimiento corta un ataque, no al revés.
--   - Cada jugador lleva un "ticket": al terminar un estado, su temporizador solo lo quita si nadie ha
--     puesto otro mientras tanto (si no, el primer golpe de un combo soltaba al aturdido a mitad).
--   - Al reaparecer o al salir, se olvida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)

local PRIORITY = Config.CombatStates.Priority

local StateMachine = {}

local tickets: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Quita el estado de "player" (vuelve a "Idle").
function StateMachine.reset(player: Player)
	tickets[player] = (tickets[player] or 0) + 1
	player:SetAttribute(CombatState.ATTRIBUTE, nil)
	player:SetAttribute(CombatState.UNTIL_ATTRIBUTE, nil)
end

-- Pone a "player" en "state" durante "seconds". Devuelve false si el estado que tiene tiene más
-- prioridad y aún no ha terminado (no cambia nada).
function StateMachine.enter(player: Player, state: CombatState.State, seconds: number): boolean
	local current = CombatState.get(player)
	if current ~= "Idle" and (PRIORITY[state] or 0) < (PRIORITY[current] or 0) then
		return false
	end
	local ticket = (tickets[player] or 0) + 1
	tickets[player] = ticket
	local untilTime = now() + seconds
	-- Un estado igual que aún dura más no se acorta.
	local currentUntil = player:GetAttribute(CombatState.UNTIL_ATTRIBUTE)
	if current == state and typeof(currentUntil) == "number" and currentUntil > untilTime then
		untilTime = currentUntil
	end
	player:SetAttribute(CombatState.ATTRIBUTE, state)
	player:SetAttribute(CombatState.UNTIL_ATTRIBUTE, untilTime)
	task.delay(untilTime - now(), function()
		if tickets[player] == ticket and player.Parent then
			StateMachine.reset(player)
		end
	end)
	return true
end

-- Termina "state" si es el que tiene "player" ahora (al soltar la guardia, al acabar un ataque).
function StateMachine.leave(player: Player, state: CombatState.State)
	if CombatState.get(player) == state then
		StateMachine.reset(player)
	end
end

-- Lo llama CombatService al empezar.
function StateMachine.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			StateMachine.reset(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tickets[player] = nil
	end)
end

return StateMachine
