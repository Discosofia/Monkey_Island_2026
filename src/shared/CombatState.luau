--!strict
-- Estado de combate de un jugador (Fase 10, C2): qué está haciendo y qué le impide hacer. Lo pone el
-- servidor (ServerScriptService.Combat.StateMachine) en los atributos del Player "CombatState" y
-- "CombatStateUntil" (hora del servidor en que termina); el cliente y el servidor lo leen aquí para
-- decidir si una acción vale (canAct). Caído (LifeState) cuenta como el estado "Downed".
--   - Aturdido ("Stunned", "GuardBroken"): no anda, no pega, ni habilidades, ni esquiva, ni guardia;
--     solo el Evasivo (C7, Combat/Evasive: la esquiva pulsada estando atrapado, isTrapped).
--   - Tambaleado ("Staggered", el golpe de una cadena en PvP o un parry recibido): no pega ni usa
--     habilidades hasta que se recupera.
--   - En guardia ("Parrying" al pulsar, "Blocking" mientras la mantiene; Combat/Guard, C5): no pega ni
--     usa habilidades, anda más despacio y no corre. Puede esquivar (y suelta la guardia).
--   - Inmovilizado no es un estado sino una condición: "StunnedUntil" (Combat/Status.holdPlayer) le
--     quita el movimiento y le deja pegar. Un aturdido también lo lleva. Lanzado ("LaunchedUntil",
--     Combat/Knockback), tampoco: el remate de la cadena dado en el aire, hasta que cae.
--   - "Evading": el Evasivo, lo que dura su invulnerabilidad.
-- Las prioridades (qué estado corta a cuál) están en Config.CombatStates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LifeState = require(ReplicatedStorage.Shared.LifeState)

export type State =
	"Idle"
	| "Attacking"
	| "Casting"
	| "Blocking"
	| "Parrying"
	| "Dodging"
	| "Evading"
	| "Staggered"
	| "Stunned"
	| "GuardBroken"
	| "Downed"

export type Action = "Attack" | "Ability" | "Dodge" | "Guard" | "Evasive"

local CombatState = {}

CombatState.ATTRIBUTE = "CombatState"
CombatState.UNTIL_ATTRIBUTE = "CombatStateUntil"
-- Hora del servidor en que se puede volver a usar el Evasivo (Combat/Evasive).
CombatState.EVASIVE_ATTRIBUTE = "EvasiveReadyAt"

-- Acciones que impide cada estado (las demás se pueden hacer).
local BLOCKS: { [State]: { [Action]: boolean } } = {
	Idle = {},
	Attacking = {},
	Casting = {},
	Blocking = { Attack = true, Ability = true },
	Parrying = { Attack = true, Ability = true },
	Dodging = {},
	Evading = { Attack = true, Ability = true, Guard = true, Evasive = true },
	Staggered = { Attack = true, Ability = true },
	Stunned = { Attack = true, Ability = true, Dodge = true, Guard = true },
	GuardBroken = { Attack = true, Ability = true, Dodge = true, Guard = true },
	Downed = { Attack = true, Ability = true, Dodge = true, Guard = true, Evasive = true },
}

-- El estado de "player" ahora mismo ("Idle" si el que tenía ya ha terminado).
function CombatState.get(player: Player): State
	if not LifeState.isAlive(player) then
		return "Downed"
	end
	local state = player:GetAttribute(CombatState.ATTRIBUTE)
	local untilTime = player:GetAttribute(CombatState.UNTIL_ATTRIBUTE)
	if typeof(state) ~= "string" or BLOCKS[state :: State] == nil then
		return "Idle"
	end
	if typeof(untilTime) == "number" and Workspace:GetServerTimeNow() >= untilTime then
		return "Idle"
	end
	return state :: State
end

-- true si "player" puede hacer "action" en su estado de ahora.
function CombatState.canAct(player: Player, action: Action): boolean
	return not BLOCKS[CombatState.get(player)][action]
end

local function attributeTime(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else -math.huge
end

-- Hasta cuándo (hora del servidor) está atrapado "player": aturdido, con la guardia rota, inmovilizado
-- o lanzado. Un aturdido siempre lleva también "StunnedUntil" (Status.stunPlayer).
function CombatState.trappedUntil(player: Player): number
	return math.max(attributeTime(player, "StunnedUntil"), attributeTime(player, "LaunchedUntil"))
end

-- true si "player" está atrapado ahora: su esquiva es el Evasivo (C7).
function CombatState.isTrapped(player: Player): boolean
	return Workspace:GetServerTimeNow() < CombatState.trappedUntil(player)
end

-- Segundos que le faltan a "player" para poder usar el Evasivo (0 si ya puede).
function CombatState.evasiveWait(player: Player): number
	return math.max(0, attributeTime(player, CombatState.EVASIVE_ATTRIBUTE) - Workspace:GetServerTimeNow())
end

-- true si "player" está en guardia (bloqueando o en la ventana del parry, C5): anda más despacio y no corre.
function CombatState.isGuarding(player: Player): boolean
	local state = CombatState.get(player)
	return state == "Blocking" or state == "Parrying"
end

return CombatState
