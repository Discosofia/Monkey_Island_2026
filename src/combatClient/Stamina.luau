--!strict
-- Estamina del jugador local (GDD §6.1, Fase 2.1), de 0 a 100. Vive solo en el cliente:
-- la gastan correr (el controlador de movimiento de cada place) y esquivar (DodgeController), y la
-- lee el HUD. Se recupera sola tras un momento sin gastarla, al ritmo que diga el place (en la Isla,
-- a la mitad con hambre o sed bajas).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Stamina = {}

Stamina.MAX = 100

local current = Stamina.MAX
local lastSpentAt = -math.huge

function Stamina.get(): number
	return current
end

-- Gasta "amount" si hay suficiente. Devuelve false (sin gastar nada) si no alcanza.
function Stamina.tryConsume(amount: number): boolean
	if current < amount then
		return false
	end
	current -= amount
	lastSpentAt = os.clock()
	return true
end

-- Gasto continuo (correr): baja hasta 0 como mucho. Las mejoras y talentos lo abaratan.
function Stamina.drain(amount: number)
	current = math.max(0, current - amount * Progression.perk(Players.LocalPlayer, "SprintCost"))
	lastSpentAt = os.clock()
end

-- Llamado cada frame por el controlador de movimiento del place. "regenFactor" multiplica el ritmo
-- de recuperación (1 si no se pasa).
function Stamina.update(deltaTime: number, regenFactor: number?)
	if os.clock() - lastSpentAt < Config.Survival.StaminaRegenDelay then
		return
	end
	local rate = Config.Survival.StaminaRegenPerSecond * (regenFactor or 1)
	current = math.min(Stamina.MAX, current + rate * deltaTime)
end

return Stamina
