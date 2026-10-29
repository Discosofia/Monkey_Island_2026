--!strict
-- Velocidad del jugador local (Fase 15, V1): el ÚNICO sitio del cliente que escribe Humanoid.WalkSpeed,
-- igual en la Isla, el Lobby, Dunas y el Laboratorio. La velocidad es
--     base (andar o correr, o la de un proveedor "addBase": la montura, el gateo) × modificadores
-- y cada sistema aporta lo suyo con addBase / addModifier (LocomotionController registra los del juego).
-- Las reglas de movimiento del place (staminaFree, slide, dodgeStyle, slideKey) las publica CombatRules como
-- atributos de ReplicatedStorage y se leen con Movement.rules().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Rules = {
	staminaFree: boolean,
	slide: boolean,
	dodgeStyle: string,
	slideKey: string,
	slideFromWalk: boolean,
}

type Entry = { name: string, fn: (player: Player) -> number? }

local Movement = {}

local bases: { Entry } = {}
local modifiers: { Entry } = {}

-- Añade o, si el nombre ya existe, reemplaza (conservando su orden) una entrada.
local function register(list: { Entry }, name: string, fn: (player: Player) -> number?)
	for _, entry in list do
		if entry.name == name then
			entry.fn = fn
			return
		end
	end
	table.insert(list, { name = name, fn = fn })
end

-- Multiplicador de velocidad: nil, no aplica; 0, quieto. Se multiplican todos.
function Movement.addModifier(name: string, fn: (player: Player) -> number?)
	register(modifiers, name, fn)
end

-- Velocidad base que sustituye a andar y correr (monturas, gateo). Gana el primero registrado que
-- devuelva un número.
function Movement.addBase(name: string, fn: (player: Player) -> number?)
	register(bases, name, fn)
end

-- Velocidad que toca ahora: base × todos los modificadores.
function Movement.speedFor(player: Player, sprinting: boolean): number
	local speed: number? = nil
	for _, entry in bases do
		speed = entry.fn(player)
		if speed then
			break
		end
	end
	local result = speed or (if sprinting then Config.Movement.SprintSpeed else Config.Movement.WalkSpeed)
	for _, entry in modifiers do
		local factor = entry.fn(player)
		if factor then
			result *= factor
		end
	end
	return result
end

-- Escribe la velocidad solo si cambia.
function Movement.apply(humanoid: Humanoid, speed: number)
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

-- Reglas de movimiento de este place (CombatRules.movement); los neutros si aún no se han publicado.
function Movement.rules(): Rules
	local staminaFree = ReplicatedStorage:GetAttribute("MovementStaminaFree")
	local slide = ReplicatedStorage:GetAttribute("MovementSlide")
	local dodgeStyle = ReplicatedStorage:GetAttribute("MovementDodgeStyle")
	local slideKey = ReplicatedStorage:GetAttribute("MovementSlideKey")
	local slideFromWalk = ReplicatedStorage:GetAttribute("MovementSlideFromWalk")
	return {
		staminaFree = if typeof(staminaFree) == "boolean" then staminaFree else false,
		slide = if typeof(slide) == "boolean" then slide else true,
		dodgeStyle = if typeof(dodgeStyle) == "string" then dodgeStyle else "Roll",
		slideKey = if typeof(slideKey) == "string" then slideKey else "LeftAlt",
		slideFromWalk = if typeof(slideFromWalk) == "boolean" then slideFromWalk else false,
	}
end

return Movement
