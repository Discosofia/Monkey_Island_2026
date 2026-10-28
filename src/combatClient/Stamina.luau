--!strict
-- Estamina del jugador local (GDD §6.1, Fase 2.1), de 0 a Config.Survival.StaminaMax. La gastan correr
-- (LocomotionController, el mismo en todos los places) y esquivar (DodgeController), y la lee el HUD. Se
-- recupera sola tras un momento sin gastarla, al ritmo que diga el place (en la Isla, más despacio con
-- hambre o sed bajas).
-- Desde la Fase 10 (C2) manda el servidor (Combat/StaminaServer, atributo "Stamina" del Player): aquí
-- se predice con los mismos números para que el HUD y la esquiva respondan al momento, se le avisa de
-- cuándo se empieza y se deja de correr (setSprinting) y, si las dos se separan más de
-- Config.Survival.StaminaSyncTolerance, se toma la del servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Stamina = {}

Stamina.MAX = Config.Survival.StaminaMax

local current = Stamina.MAX
local lastSpentAt = -math.huge
local sprinting = false

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

-- LocomotionController dice si el jugador corre; el servidor solo se entera de los cambios.
function Stamina.setSprinting(value: boolean)
	if value ~= sprinting then
		sprinting = value
		Remotes.Sprint:FireServer(value)
	end
end

-- Llamado cada frame por LocomotionController. "regenFactor" multiplica el ritmo
-- de recuperación (1 si no se pasa).
function Stamina.update(deltaTime: number, regenFactor: number?)
	local server = Players.LocalPlayer:GetAttribute("Stamina")
	if typeof(server) == "number" and math.abs(server - current) > Config.Survival.StaminaSyncTolerance then
		current = server
	end
	if os.clock() - lastSpentAt < Config.Survival.StaminaRegenDelay then
		return
	end
	local rate = Config.Survival.StaminaRegenPerSecond * (regenFactor or 1)
	current = math.min(Stamina.MAX, current + rate * deltaTime)
end

return Stamina
