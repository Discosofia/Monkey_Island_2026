--!strict
-- Reglas del combate que cambian de un place a otro. El combate (Services/CombatService,
-- AbilityService, ComboService y los módulos de esta carpeta) es el mismo en la Isla y en la arena de
-- Dunas; lo que depende de cada place se registra aquí en el Init de uno de sus servicios
-- (CombatRules.set). Lo que no se registre usa los valores neutros de abajo: sin PvP, todos los
-- jugadores son aliados, sin zona segura, sin munición ni inventario y sin telemetría.
--   - Isla (Services/IslandCombatRules): PvP opt-in por el tótem, Basecamp seguro, caer y reanimar
--     (LifeService), fiebre del mono, munición del inventario, recompensa PvP y misiones diarias.
--   - Dunas: equipos (atributo "Team"), reaparecer en la base, números de la arena y la telemetría de
--     las mecánicas (Services/ArenaTelemetryService).
--   - Laboratorio (Fase 13, Services/LabCombatRules): sin roles, habilidades ni guardia; las armas del
--     Laboratorio (Data/LabWeapons, sin remate ni crítico), su cargador y dispersión (takeShot, V8) y reaparecer.
-- El movimiento (Fase 15: correr sin estamina, deslizarse, esquiva con voltereta o impulso) también se
-- registra aquí (campo "movement") y se publica en atributos de ReplicatedStorage para el cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

-- Mecánicas de combate que se cuentan (Fase 10, C7), por rol de "player" y por place:
--   Parries, Blocks, GuardBreaks  el que defiende (Combat/Guard)
--   Evasives                      el que lo usa (Combat/Evasive)
--   ChainFinishers                el que da el remate de la cadena y alcanza algo (CombatService)
--   Feints                        el que amaga (C8)
--   WallBangs                     el que empuja contra el muro (C10)
--   ShotsHit, ShotsMissed         el que dispara un proyectil, según dé a alguien o no (C9,
--                                 Combat/Projectiles): la tasa de acierto real para la calculadora
--   ShotFinishers                 el que dispara el remate de un arma a distancia (C9b, CombatService)
--   CoversBroken                  el que rompe una cobertura de Dunas (C11, CoverService)
--   AltarCaptures                 cada uno de los que toman el altar de Dunas (C11, AltarService)
--   Slides                        el que se desliza (Fase 15, V2, CombatService.onSlide)
--   Headshots                     el que da un disparo a la cabeza de un jugador (Fase 15, V7, CombatService)
export type Mechanic =
	"Parries"
	| "Blocks"
	| "GuardBreaks"
	| "Evasives"
	| "ChainFinishers"
	| "Feints"
	| "WallBangs"
	| "ShotsHit"
	| "ShotsMissed"
	| "ShotFinishers"
	| "CoversBroken"
	| "AltarCaptures"
	| "Slides"
	| "Headshots"

export type Telemetry = {
	damageDealt: (player: Player, source: string, amount: number) -> (),
	healed: (player: Player, source: string, amount: number) -> (),
	abilityUsed: (player: Player, abilityId: string, linkedStep: number?) -> (),
	comboCompleted: (player: Player, streak: number) -> (),
	held: (player: Player, seconds: number, cause: string) -> (),
	mechanic: (player: Player, mechanic: Mechanic) -> (),
	-- Cómo se llama en la telemetría lo que ha herido a un jugador (un mono, un jefe…).
	causeOf: (source: Instance?) -> string,
}

export type Movement = {
	staminaFree: boolean,
	slide: boolean,
	dodgeStyle: string,
	-- Tecla del deslizamiento (nombre de Enum.KeyCode): "LeftAlt", o "C" en el Laboratorio.
	slideKey: string,
}

export type Rules = {
	-- true si "attacker" puede herir a "victim" (ya se ha comprobado que son distintos, que "victim"
	-- está vivo y que no está esquivando).
	canHitPlayer: (attacker: Player, victim: Player) -> boolean,
	-- true si "healer" puede curar o proteger a "player" (las curaciones del médico, sus escudos…).
	isAlly: (healer: Player, player: Player) -> boolean,
	-- true si a "player" no le pueden herir los enemigos (monos) ahora mismo: la zona segura.
	isSafe: (player: Player) -> boolean,
	-- Un golpe deja a "player" sin vida. "attacker": el jugador que lo ha hecho (PvP) o nil.
	knockOut: (player: Player, attacker: Player?, cause: string) -> (),
	-- "attacker" ha herido a "victim" con "amount" de daño (golpes, veneno y golpe mortal; ya pasado el
	-- escudo). Por defecto no hace nada; el Laboratorio anota al último atacante para las caídas.
	onPvPHit: (attacker: Player, victim: Player, amount: number) -> (),
	-- Gasta una unidad de munición ("itemId", Data/Items). false si no le queda: no dispara.
	useAmmo: (player: Player, itemId: string) -> boolean,
	-- Gasta un disparo del cargador del arma (Fase 15, V8; el Laboratorio). nil si no puede disparar (sin balas
	-- o recargando): no sale el tiro. Si puede, devuelve la dispersión en grados de este tiro (0: exacto).
	-- "zoomed": el jugador tiene la mira acercada. Por defecto dispara siempre y sin dispersión.
	takeShot: (player: Player, weaponId: string, weapon: Weapons.WeaponDefinition, zoomed: boolean) -> number?,
	-- Gasta una munición opcional que mejora el disparo (los dardos venenosos). false si no tiene.
	useBoost: (player: Player, itemId: string) -> boolean,
	-- El hacha y el pico trabajan el árbol o la roca de delante.
	strikeResource: (player: Player, root: BasePart, tool: Weapons.ToolDefinition) -> (),
	-- Sube (o baja, con "amount" negativo) la fiebre del mono.
	addFever: (player: Player, amount: number) -> (),
	-- Fiebre que baja el Ungüento en área del médico a cada uno que cura, sin contar el remate (la
	-- lluvia tóxica de la Isla). 0: nada.
	salveFeverCure: () -> number,
	-- Avanza las misiones diarias del jugador ("Ability", "Combo"…; serverShared/Retention).
	progressMission: (player: Player, kind: string) -> (),
	-- Herramientas comunes que se dan además de las armas del rol (el hacha y el pico en la Isla).
	starterTools: (player: Player) -> { string },
	-- Armas que se dan EN LUGAR de las del rol (el Laboratorio), o nil: las del rol (atributo "Role").
	roleWeapons: (player: Player) -> { string }?,
	-- false: no hay habilidades de rol (Z/X/C/R/V) ni combos (el Laboratorio).
	abilities: boolean,
	-- false: no hay guardia ni parry; los golpes entran sin esperar el parry del defensor.
	guard: boolean,
	-- true: las armas a distancia hacen más daño a la cabeza de un jugador (Fase 15, V7; Dunas y el
	-- Laboratorio) y sus disparos se prueban contra posiciones rebobinadas (Combat/Hitbox.sweepPlayers).
	headshots: boolean,

	-- Ritmo al que se recupera la estamina de "player" (1 = normal; Combat/StaminaServer).
	staminaRegenFactor: (player: Player) -> number,
	-- Daño y duración de los aturdimientos de las habilidades contra jugadores (fracción), y daño de
	-- las armas contra jugadores.
	pvpDamageMultiplier: number,
	pvpControlMultiplier: number,
	-- Las definitivas (V) contra jugadores, además de pvpDamageMultiplier.
	pvpUltimateMultiplier: number,
	pvpWeaponMultiplier: number,
	-- Ajuste de algunas armas sobre pvpWeaponMultiplier (id de Data/Weapons → fracción).
	pvpWeaponMultipliers: { [string]: number },
	-- Multiplica las curaciones que hace un jugador (el médico) en este place.
	healMultiplier: number,
	-- true: contra jugadores funciona todo lo que contra los monos (veneno, ralentizar, marcas,
	-- expuesto y los pasos del combo). En la Isla, false: el PvP opt-in solo hace daño y aturde.
	pvpStatus: boolean,
	-- Movimiento del place (Fase 15, V1): staminaFree, correr sin gastar estamina (el Lobby); slide,
	-- deslizarse al correr (V2); dodgeStyle, "Roll" (voltereta) o "Dash" (impulso; V3). El cliente no lee
	-- ServerScriptService: se publica como atributos de ReplicatedStorage (MovementStaminaFree,
	-- MovementSlide, MovementDodgeStyle, MovementSlideKey) y los lee CombatClient/Movement.rules.
	movement: Movement,
	telemetry: Telemetry,
}

local function never(): boolean
	return false
end

local function always(): boolean
	return true
end

local function nothing() end

local rules: Rules = {
	canHitPlayer = never,
	isAlly = always,
	isSafe = never,
	knockOut = function(player: Player)
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Health = 0
		end
	end,
	onPvPHit = nothing,
	useAmmo = always,
	takeShot = function()
		return 0
	end,
	useBoost = never,
	strikeResource = nothing,
	addFever = nothing,
	salveFeverCure = function()
		return 0
	end,
	progressMission = nothing,
	starterTools = function()
		return {}
	end,
	roleWeapons = function()
		return nil
	end,
	abilities = true,
	guard = true,
	headshots = false,
	staminaRegenFactor = function()
		return 1
	end,
	pvpDamageMultiplier = Config.Abilities.PvPDamageMultiplier,
	pvpControlMultiplier = Config.Abilities.PvPControlMultiplier,
	pvpUltimateMultiplier = Config.Abilities.PvPUltimateMultiplier,
	pvpWeaponMultiplier = 1,
	pvpWeaponMultipliers = {},
	healMultiplier = 1,
	pvpStatus = false,
	movement = { staminaFree = false, slide = true, dodgeStyle = "Roll", slideKey = "LeftAlt" },
	telemetry = {
		damageDealt = nothing,
		healed = nothing,
		abilityUsed = nothing,
		comboCompleted = nothing,
		held = nothing,
		mechanic = nothing,
		causeOf = function()
			return "Otro"
		end,
	},
}

local CombatRules = {}

-- Publica el movimiento del place para el cliente (CombatClient/Movement.rules).
local function publishMovement()
	local movement = rules.movement
	ReplicatedStorage:SetAttribute("MovementStaminaFree", movement.staminaFree)
	ReplicatedStorage:SetAttribute("MovementSlide", movement.slide)
	ReplicatedStorage:SetAttribute("MovementDodgeStyle", movement.dodgeStyle)
	ReplicatedStorage:SetAttribute("MovementSlideKey", movement.slideKey)
end

-- Cambia las reglas que se pasen; las demás se quedan como estaban.
function CombatRules.set(overrides: { [string]: any })
	local current = rules :: any
	for key, value in overrides do
		assert(current[key] ~= nil, `CombatRules: regla desconocida "{key}"`)
		current[key] = value
	end
	if overrides.movement ~= nil then
		publishMovement()
	end
end

-- Las reglas en vigor. Se leen en cada uso (no al cargar), porque el place las registra en su Init.
function CombatRules.get(): Rules
	return rules
end

-- Al cargar el módulo el cliente ya tiene valores (los neutros) hasta que el place registre los suyos.
publishMovement()

return CombatRules
