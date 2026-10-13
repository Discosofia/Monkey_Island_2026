--!strict
-- Estamina del jugador local (GDD §6.1, Fase 2.1), de 0 a 100. Vive solo en el cliente:
-- la gastan correr (SurvivalController) y esquivar (DodgeController), y la lee el HUD.
-- Se recupera sola tras un momento sin gastarla; con hambre o sed bajas, a la mitad de ritmo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Survival = require(ReplicatedStorage.Shared.Survival)

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

-- Gasto continuo (correr): baja hasta 0 como mucho.
function Stamina.drain(amount: number)
	current = math.max(0, current - amount)
	lastSpentAt = os.clock()
end

-- Llamado cada frame por SurvivalController.
function Stamina.update(deltaTime: number)
	if os.clock() - lastSpentAt < Config.Survival.StaminaRegenDelay then
		return
	end
	local player = Players.LocalPlayer
	local low = Config.Survival.LowThreshold
	local weak = Survival.get(player, Survival.HUNGER) <= low or Survival.get(player, Survival.THIRST) <= low
	local rate = Config.Survival.StaminaRegenPerSecond * (if weak then 0.5 else 1)
	current = math.min(Stamina.MAX, current + rate * deltaTime)
end

return Stamina
