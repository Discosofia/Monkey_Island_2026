-- Calculadora de equilibrio de las habilidades: jugadores (roles), monos, jefes y mascotas. La usa la
-- skill habilidades-roblox (.claude/skills/habilidades-roblox). Se ejecuta en Studio, en modo edición
-- (sin pulsar Play), desde la barra de comandos o con el MCP, y devuelve un informe en tablas:
--
--   local m = game.ServerStorage.Tools.Equilibrio:Clone() -- copia: así no usa la versión vieja en caché
--   print(require(m).informe()); m:Destroy()
--
-- No cambia nada: cada informe lee una copia nueva de ReplicatedStorage.Shared. Argumentos (opcionales):
--   informe(opciones, propuesta)
-- "opciones" cambia OPCIONES_BASE ({ soloRol = "Mago", talentos = "max" }); "propuesta" cambia datos
-- solo para ese informe (números de Config, huecos de Data/Roles, combos, otros módulos de Data o el
-- modelo de una habilidad nueva) para probar una idea ANTES de tocar el repo.
-- Las reglas de la sección "Alertas" son las de la skill (references/equilibrio.md, tabla LIMITES).
--
-- Lo que mide (todo contra monos, con Config.Combat.PlayerDamageMultiplier y el crítico esperado):
--   1. Fichas: cada habilidad por separado (daño por uso, DPS sostenido, segundos de arma, control,
--      curación).
--   2. Simulación de SEGUNDOS s por rol, contra 1 objetivo y contra un grupo, con dos jugadores: uno
--      que pulsa lo que esté listo y otro que enlaza el combo. Daño acumulado en el tiempo.
--   3. Tiempo para matar monos y duración de los jefes.
--   4. Amenaza de los monos y jefes al jugador.
--   5. Mascotas.
--   6. Arena de Dunas (solo con secciones.arena = true): cuánto tarda cada rol en tumbar a cada otro
--      rol en un duelo, con el daño contra jugadores de la arena (Config.Arena) y las defensas.
--   7. Alertas: lo que se sale de los límites.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- ===================================== Opciones =====================================

local OPCIONES_BASE = {
	talentos = "ninguno", -- "ninguno" o "max" (todos los talentos del rol al máximo)
	-- Equipamiento de la arena (Data/ArenaGear) puesto por rol: { Guerrero = { "BoneMaul" } }.
	equipo = {} :: { [string]: { string } },
	armas = {} :: { [string]: string }, -- [rol] = id de Data/Weapons; sin él, la primera del rol
	critico = nil :: number?, -- probabilidad de crítico de las armas (nil = la del arma)
	-- true: las cerbatanas disparan su munición opcional (dardos venenosos, "boostItemId"), que
	-- multiplica su veneno por "poisonMultiplier" (Data/Items).
	dardosVenenosos = false,
	grupo = 4, -- monos en el escenario de grupo
	aliados = 4, -- jugadores del equipo (curaciones en área y vida de los jefes)
	segundos = 60, -- duración de la simulación
	-- Para medir cuánto vale enlazar el combo: más que una recarga de la definitiva, porque parte del
	-- premio es acercarla (Config.Combo.UltRefundSeconds) y en 60 s apenas se nota.
	segundosCombo = 180,
	lanzamiento = 0.3, -- segundos sin poder atacar con el arma al lanzar una habilidad
	-- Fracción del tiempo que se pega de verdad en una pelea (moverse, esquivar, buscar ángulo):
	-- solo para la sección 3. La simulación supone el 100 %.
	actividad = 0.6,
	dias = { 1, 8 },
	-- Mejoras de las armas de rol de la forja (Data/Recipes, "upgrades") que se suelen tener desde ese
	-- día: 1 con botín de categoría 1, 2 con el de categoría 2 y 3. Para medir los jefes de cada día.
	armasPorDia = { [1] = 0, [3] = 1, [6] = 2 } :: { [number]: number },
	-- Marca de las mascotas (sección 5): fracción del daño del equipo que va al mono marcado (el más
	-- cercano al dueño); el resto se reparte entre los demás monos del grupo.
	focoMarca = 0.5,
	jugadoresJefe = { 1, 4, 8, 20 }, -- tamaños de equipo para la duración de los jefes
	especies = { "MonoArdilla", "AulladorRojo", "Mandril", "Chimpance", "Gorila" },
	soloRol = nil :: string?, -- "Mago" para ver solo ese rol en las secciones 1 y 2
	secciones = { fichas = true, simulacion = true, ttk = true, enemigos = true, mascotas = true, arena = false },
}

-- ===================================== Propuesta =====================================
-- Vacía = el juego tal como está. Ejemplos:
--   config = { Abilities = { FireballDamage = 30 }, Combo = { PayoffSeconds = 5 } },
--   roles = { Mago = { [1] = { cooldownSeconds = 5 } } },
--   roles = { Cazador = { [2] = { id = "Boomerang", name = "Bumerán", cooldownSeconds = 8 } } },
--   modelos = { Boomerang = function(A, perk, remate, combo) return { familia = "Daño", golpes = {
--       { cantidad = 14 * perk("RangedDamage"), en = 0.4, objetivos = { fijo = 2 } },
--       { cantidad = 14 * perk("RangedDamage"), en = 1.0, objetivos = { fijo = 2 } } } } end },
--   combos = { Cazador = { steps = { "Trap", "Boomerang", "MultiShot" } } },
--   datos = { Monkeys = { Orangutan = { grab = 1.5 } }, Pets = { MonoX7 = { attackDamage = 14 } } },
--     (cualquier módulo de Shared/Data: Monkeys, Bosses, Pets, Weapons, Talents, Perks, Armor…)
type Propuesta = { config: any?, roles: any?, modelos: any?, combos: any?, datos: any? }

-- Los de la llamada en curso (Equilibrio.informe).
local OPCIONES = OPCIONES_BASE
local PROPUESTA: Propuesta = {}
-- Números de la sección 6 del último informe (Equilibrio.ultimaArena), para comparar variantes del
-- equipamiento sin leer el texto: tiempos[atacante][defensor] = { con = s, sin = s }.
local ultimaArena: any = nil

-- ===================================== Límites =====================================
-- Copia de .claude/skills/habilidades-roblox/references/equilibrio.md §3: si cambias uno, cambia los dos.

local LIMITES = {
	recargaActiva = { 4, 25 },
	recargaDefinitiva = { 60, 120 },
	segArmaActiva = { 0.5, 4.0 }, -- daño de un uso contra el grupo, en segundos de arma del rol
	segArmaDefinitiva = { 12, 30 },
	dpsActivaVsArma = 0.8, -- el DPS sostenido de una activa (grupo) no pasa de esto × el del arma
	controlPorHabilidad = 0.35, -- fracción del tiempo que una habilidad tiene controlado a un mono
	controlPorRol = 0.45, -- todas las del rol juntas (con los remates del combo)
	controlJefeEquipo = 0.30, -- 1 de cada rol pegando al jefe (ya con BossControlMultiplier)
	bonusCombo = { 0.05, 0.35 }, -- daño extra del que enlaza combos frente al que no (grupo)
	repartoRoles = 0.20, -- daño en grupo de Guerrero, Cazador y Mago: ± esto respecto a su media
	repartoRolesUno = 0.30, -- contra 1 objetivo
	golpeEnemigoDia1 = 40, -- golpe más fuerte de un mono (con crítico) a un jugador sin armadura
	golpeEnemigoMax = 60, -- con la dificultad al máximo
	golpeJefe = 65, -- golpe más fuerte de un jefe en furia, con crítico, sin armadura
	bloqueoEnemigo = 0.6, -- fracción del tiempo que un solo mono te deja sin moverte
	mascotaVsArma = 0.4, -- DPS de una mascota frente al DPS medio de las armas de rol
	-- Con la marca de una mascota sobre un jefe, "Marcar presas" del cazador sigue sumando al menos
	-- esta fracción de lo que suma sin ella.
	marcaMascotaPresas = 0.5,
	jefeSegundos = { 90, 240 }, -- duración de un jefe con OPCIONES.aliados jugadores
	jefeSoloSegundos = 360, -- y con un jugador solo, como mucho
	curacionPorSegundo = 8, -- curación sostenida del médico a un aliado (de 100 de vida)
	-- Arena de Dunas (references/equilibrio.md §3): un duelo entre dos jugadores del mismo rol (Guerrero, Cazador o Mago), con
	-- OPCIONES.actividad, dura esto (s). El médico es de apoyo: su duelo puede ser más largo.
	arenaDueloEspejo = { 8, 10 },
}

-- ===================================== Utilidades =====================================

local lineas: { string } = {}
local alertas: { string } = {}

local function linea(texto: string)
	table.insert(lineas, texto)
end

local function alerta(texto: string)
	table.insert(alertas, "⚠️ " .. texto)
end

local function n(valor: number?, decimales: number?): string
	if valor == nil then
		return "-"
	end
	local d = decimales or 1
	local texto = string.format("%." .. d .. "f", valor)
	if d > 0 then
		texto = texto:gsub("0+$", ""):gsub("%.$", "")
	end
	return texto
end

local function pct(valor: number): string
	return string.format("%d %%", math.round(valor * 100))
end

local function mezclar(destino: any, origen: any)
	for clave, valor in origen do
		if typeof(valor) == "table" and typeof(destino[clave]) == "table" then
			mezclar(destino[clave], valor)
		else
			destino[clave] = valor
		end
	end
end

local function fuera(valor: number, rango: { number }): boolean
	return valor < rango[1] - 1e-6 or valor > rango[2] + 1e-6
end

-- Monos que alcanza un área de radio "r" en un grupo típico (están repartidos, no apiñados).
local function tipicosEnRadio(r: number): number
	if r <= 4 then
		return 1.2
	elseif r <= 8 then
		return 2
	elseif r <= 10 then
		return 2.5
	elseif r <= 14 then
		return 3.5
	end
	return 4.5
end

-- ===================================== Modelos de las habilidades =====================================
-- Cada modelo convierte los números de Config en una "ficha" que la calculadora sabe medir. Reproduce
-- lo que hace su función en AbilityService: si cambias esa función, cambia también su modelo.
--   A: Config.Abilities · perk(nombre): ventaja del rol con talentos · remate: va enlazada en el combo
--   combo: Config.Combo
-- Ficha:
--   familia     texto ("Daño en área", "Control", "Curación"…)
--   golpes      { { cantidad, en (s desde el uso), objetivos, minObjetivos? } } daño a cada objetivo
--   objetivos   { fijo = n } · { radio = r } (estimado por tipicosEnRadio) · { abanico = flechas }
--               · { radio = r, menos = 1 } (el área sin el impactado)
--   bloqueo     segundos que no se puede atacar con el arma (giros, cargas)
--   control     { segundos, objetivos, tipo = "Stun" | "Freeze" | "Root" | "Sleep", jefes? }
--               (jefes = false: no afecta a los jefes, no cuenta en el control del equipo sobre un jefe)
--   lento       { segundos, factor, objetivos }
--   provoca     { segundos, objetivos }
--   vulnerable  { valor, segundos, objetivos, en? } (los marcados reciben "valor" más de daño desde "en")
--   veneno      { dps, segundos, objetivos } (Combat/Status.poison: no se suma al de la cerbatana, gana el
--               más fuerte)
--   mitiga      { valor, segundos } (el lanzador recibe "valor" menos de daño)
--   cura        { cantidad, objetivos (aliados), ticks?, cada? } · escudo { cantidad, segundos }
--   movilidad   studs · critSeguro: el remate hace críticos seguros (curaciones)

type Objetivos = { fijo: number?, radio: number?, abanico: number?, menos: number? }
type Golpe = { cantidad: number, en: number, objetivos: Objetivos, minObjetivos: number? }
type Ficha = {
	familia: string,
	golpes: { Golpe }?,
	bloqueo: number?,
	control: { segundos: number, objetivos: Objetivos, tipo: string, jefes: boolean? }?,
	lento: { segundos: number, factor: number, objetivos: Objetivos }?,
	provoca: { segundos: number, objetivos: Objetivos }?,
	vulnerable: { valor: number, segundos: number, objetivos: Objetivos, en: number? }?,
	veneno: { dps: number, segundos: number, objetivos: Objetivos }?,
	mitiga: { valor: number, segundos: number }?,
	cura: { cantidad: number, objetivos: Objetivos, ticks: number?, cada: number? }?,
	escudo: { cantidad: number, segundos: number }?,
	movilidad: number?,
	critSeguro: boolean?,
	nota: string?,
}
type Perk = (nombre: string) -> number
type Modelo = (A: any, perk: Perk, remate: boolean, combo: any) -> Ficha

local MODELOS: { [string]: Modelo } = {
	-- Guerrero.
	Whirlwind = function(A, perk, remate, combo)
		local segundos = perk("WhirlwindSeconds") + (if remate then combo.WhirlwindExtraSeconds else 0)
		local golpes = {}
		for i = 1, math.max(1, math.round(segundos / A.WhirlwindInterval)) do
			table.insert(golpes, {
				cantidad = A.WhirlwindDamage * perk("MeleeDamage"),
				en = (i - 1) * A.WhirlwindInterval,
				objetivos = { radio = A.WhirlwindRadius },
			})
		end
		return { familia = "Daño en área", golpes = golpes, bloqueo = segundos }
	end,
	Charge = function(A, perk)
		return {
			familia = "Daño + movilidad",
			golpes = {
				{
					cantidad = A.ChargeDamage * perk("MeleeDamage") * perk("ChargeDamage"),
					en = 0.15,
					objetivos = { fijo = 2 },
				},
			},
			bloqueo = A.ChargeSeconds,
			movilidad = A.ChargeDistance,
		}
	end,
	WarCry = function(A, perk, remate, combo)
		return {
			familia = "Defensa + provocar",
			provoca = { segundos = A.WarCrySeconds, objetivos = { radio = A.WarCryRadius } },
			mitiga = { valor = perk("WarCryReduction"), segundos = A.WarCrySeconds },
			control = if remate then { segundos = combo.WarCryStun, objetivos = { fijo = 2 }, tipo = "Stun" } else nil,
		}
	end,
	Quake = function(A, perk)
		return {
			familia = "Daño en área + control",
			golpes = {
				{ cantidad = A.QuakeDamage * perk("MeleeDamage"), en = 0.2, objetivos = { radio = A.QuakeRadius } },
			},
			control = { segundos = perk("QuakeStun"), objetivos = { radio = A.QuakeRadius }, tipo = "Stun" },
		}
	end,
	Smash = function(A, perk, remate)
		-- Al cono de delante entran ~2 de un grupo; como remate golpea alrededor.
		local objetivos = if remate then { radio = A.SmashRange } else { fijo = 2 }
		return {
			familia = "Daño frontal + control",
			golpes = {
				{
					cantidad = A.SmashDamage * perk("MeleeDamage") * perk("SmashDamage"),
					en = 0.25,
					objetivos = objetivos,
				},
			},
			control = { segundos = A.SmashStun, objetivos = objetivos, tipo = "Stun" },
			bloqueo = 0.4,
		}
	end,
	-- Cazador.
	MultiShot = function(A, perk, remate, combo)
		local flechas = math.floor(perk("MultiShotCount")) + (if remate then combo.MultiShotExtraArrows else 0)
		return {
			familia = "Daño en abanico",
			golpes = {
				{ cantidad = A.MultiShotDamage * perk("RangedDamage"), en = 0.3, objetivos = { abanico = flechas } },
			},
		}
	end,
	MarkPrey = function(A, perk, remate, combo)
		return {
			familia = "Apoyo (más daño recibido)",
			vulnerable = {
				valor = perk("MarkedBonus"),
				segundos = perk("MarkSeconds"),
				objetivos = { radio = A.MarkRadius },
			},
			control = if remate
				then { segundos = combo.MarkPreyRoot, objetivos = { fijo = 2 }, tipo = "Root" }
				else nil,
		}
	end,
	Trap = function(A, perk)
		return {
			familia = "Control + daño",
			golpes = {
				{ cantidad = A.TrapDamage * perk("RangedDamage"), en = 2, objetivos = { radio = A.TrapCatchRadius } },
			},
			control = { segundos = perk("TrapRoot"), objetivos = { radio = A.TrapCatchRadius }, tipo = "Root" },
			nota = "supone que lo pisan a los 2 s",
		}
	end,
	ArrowRain = function(A, perk)
		local golpes = {}
		local cada = A.RainSeconds / A.RainTicks
		for i = 1, A.RainTicks do
			table.insert(golpes, {
				cantidad = A.RainDamage * perk("RangedDamage") * perk("RainDamage"),
				en = 0.2 + (i - 1) * cada,
				objetivos = { radio = A.RainRadius },
			})
		end
		return { familia = "Daño en área continuo", golpes = golpes, nota = "supone que no salen de la zona" }
	end,
	PiercingShot = function(A, perk, remate, combo)
		-- Cada flecha atraviesa a ~2 de un grupo en línea; contra uno solo, todas le dan.
		local golpes = {}
		for _ = 1, 1 + (if remate then combo.PierceExtraArrows else 0) do
			table.insert(golpes, {
				cantidad = A.PierceDamage * perk("RangedDamage") * perk("PierceDamage"),
				en = 0.3,
				objetivos = { fijo = 2 },
			})
		end
		return { familia = "Daño en línea (atraviesa)", golpes = golpes }
	end,
	-- Mago.
	Fireball = function(A, perk, remate, combo)
		local escala = perk("SpellDamage") * perk("FireballDamage")
		local radio = A.FireballSplashRadius * (if remate then 1 + combo.FireballSplashBonus else 1)
		local llegada = 30 / A.FireballSpeed
		return {
			familia = "Daño + área",
			golpes = {
				{ cantidad = A.FireballDamage * escala, en = llegada, objetivos = { fijo = 1 } },
				{ cantidad = A.FireballSplashDamage * escala, en = llegada, objetivos = { radio = radio, menos = 1 } },
			},
		}
	end,
	FrostNova = function(A, perk)
		local congela = perk("NovaFreeze")
		return {
			familia = "Control en área",
			golpes = { { cantidad = A.NovaDamage * perk("SpellDamage"), en = 0, objetivos = { radio = A.NovaRadius } } },
			control = { segundos = congela, objetivos = { radio = A.NovaRadius }, tipo = "Freeze" },
			lento = {
				segundos = congela + A.NovaSlowSeconds,
				factor = A.NovaSlowFactor,
				objetivos = { radio = A.NovaRadius },
			},
		}
	end,
	Blink = function(_A, perk)
		return { familia = "Movilidad", movilidad = perk("BlinkDistance") }
	end,
	ChainLightning = function(A, perk)
		local golpes = {}
		local dano = A.ChainDamage * perk("SpellDamage")
		for salto = 0, math.floor(perk("ChainJumps")) do
			table.insert(
				golpes,
				{ cantidad = dano, en = salto * 0.08, objetivos = { fijo = 1 }, minObjetivos = salto + 1 }
			)
			dano *= A.ChainFalloff
		end
		return { familia = "Daño en cadena", golpes = golpes }
	end,
	Meteor = function(A, perk, remate, combo)
		local escala = perk("SpellDamage")
		local golpes = {
			{ cantidad = A.MeteorDamage * escala, en = A.MeteorDelay, objetivos = { radio = A.MeteorRadius } },
		}
		-- Remate: el suelo arde (un golpe por segundo).
		for i = 1, if remate then combo.MeteorBurnTicks else 0 do
			table.insert(golpes, {
				cantidad = combo.MeteorBurnDamage * escala,
				en = A.MeteorDelay + i,
				objetivos = { radio = A.MeteorRadius },
			})
		end
		local lento = perk("MeteorSlow")
		return {
			familia = "Daño en área retardado",
			golpes = golpes,
			lento = if lento > 0
				then { segundos = lento, factor = A.NovaSlowFactor, objetivos = { radio = A.MeteorRadius } }
				else nil,
		}
	end,
	-- Médico.
	AreaHeal = function(A, perk, remate, combo)
		return {
			familia = "Curación en área",
			cura = { cantidad = A.AreaHealAmount * perk("HealPower"), objetivos = { radio = A.AreaHealRadius } },
			critSeguro = remate,
			-- Remate de "Cura de urgencia": envenena a los monos del radio.
			veneno = if remate and combo.SalvePoisonDps
				then {
					dps = combo.SalvePoisonDps,
					segundos = combo.SalvePoisonSeconds,
					objetivos = { radio = A.AreaHealRadius },
				}
				else nil,
		}
	end,
	HealingDart = function(A, perk, remate)
		return {
			familia = "Curación a distancia",
			cura = { cantidad = A.DartHeal * perk("HealPower"), objetivos = { fijo = 1 } },
			critSeguro = remate, -- enlazado (paso 2 de "Nana de la selva"), crítico seguro (heal)
		}
	end,
	LeafShield = function(A, perk, remate, combo)
		local cantidad = perk("ShieldAmount") * (if remate then 1 + combo.ShieldBonus else 1)
		return { familia = "Escudo", escudo = { cantidad = cantidad, segundos = A.ShieldSeconds } }
	end,
	SleepPowder = function(A, perk, remate, combo)
		local duerme = perk("PowderSleep") + (if remate then combo.PowderExtraSleep else 0)
		return {
			familia = "Control en área",
			golpes = { { cantidad = A.PowderDamage, en = 0.5, objetivos = { radio = A.PowderRadius } } },
			lento = {
				segundos = A.PowderDrowsySeconds,
				factor = A.PowderSlowFactor,
				objetivos = { radio = A.PowderRadius },
			},
			-- Los jefes no se duermen.
			control = {
				segundos = duerme,
				objetivos = { radio = A.PowderRadius },
				tipo = "Sleep",
				jefes = false,
			},
			-- Remate de "Nana de la selva": los dormidos reciben más daño hasta despertar.
			vulnerable = if remate and combo.PowderExposed
				then {
					valor = combo.PowderExposed,
					segundos = duerme,
					objetivos = { radio = A.PowderRadius },
					en = 0.5 + A.PowderDrowsySeconds,
				}
				else nil,
			cura = if remate
				then { cantidad = combo.PowderHeal * perk("HealPower"), objetivos = { fijo = 2 } }
				else nil,
			critSeguro = remate,
		}
	end,
	HealingTotem = function(A, perk)
		return {
			familia = "Curación continua en área",
			cura = {
				cantidad = A.TotemHealPerSecond * perk("HealPower"),
				objetivos = { radio = A.TotemRadius },
				ticks = A.TotemSeconds,
				cada = 1,
			},
		}
	end,
}

-- ===================================== Carga de los datos =====================================

local function main(copia: Instance): string
	local modelos = table.clone(MODELOS)
	local Config = require(copia.Config) :: any
	local Data = copia.Data
	local Roles = require(Data.Roles) :: any
	local Talents = require(Data.Talents) :: any
	local Perks = require(Data.Perks) :: any
	local Combos = require(Data.Combos) :: any
	local Weapons = require(Data.Weapons) :: any
	local Monkeys = require(Data.Monkeys) :: any
	local Bosses = require(Data.Bosses) :: any
	local Pets = require(Data.Pets) :: any
	local Armor = require(Data.Armor) :: any
	local Items = require(Data.Items) :: any
	local Recipes = require(Data.Recipes) :: any
	local Progression = require(copia.Progression) :: any
	local ArenaGear = require(Data.ArenaGear) :: any

	mezclar(Config, PROPUESTA.config or {})
	for roleId, huecos in PROPUESTA.roles or {} do
		for hueco, cambios in huecos do
			local actual = Roles[roleId].abilities[hueco]
			if actual then
				mezclar(actual, cambios)
			else
				Roles[roleId].abilities[hueco] = cambios
			end
		end
	end
	for id, modelo in PROPUESTA.modelos or {} do
		modelos[id] = modelo
	end
	mezclar(Combos, PROPUESTA.combos or {})
	for nombre, cambios in PROPUESTA.datos or {} do
		local modulo = Data:FindFirstChild(nombre)
		assert(modulo and modulo:IsA("ModuleScript"), `PROPUESTA.datos: no existe Shared.Data.{nombre}`)
		mezclar(require(modulo) :: any, cambios)
	end

	local A = Config.Abilities
	local COMBO = Config.Combo
	local CRIT = Config.Crit.Multiplier
	local PDM = Config.Combat.PlayerDamageMultiplier

	local ordenRoles = {}
	for roleId in Roles do
		table.insert(ordenRoles, roleId)
	end
	table.sort(ordenRoles, function(a, b)
		return Roles[a].order < Roles[b].order
	end)
	local function visible(roleId: string): boolean
		return OPCIONES.soloRol == nil or OPCIONES.soloRol == roleId
	end

	local function perksDe(roleId: string): Perk
		local rangos = {}
		if OPCIONES.talentos == "max" then
			for talentId, talento in Talents[roleId] or {} do
				rangos[Progression.talentKey(roleId, talentId)] = talento.maxRank
			end
		end
		local equipo = {}
		for _, gearId in OPCIONES.equipo[roleId] or {} do
			local item = ArenaGear.items[gearId]
			assert(item, `OPCIONES.equipo: no existe {gearId} en Data/ArenaGear`)
			table.insert(equipo, item.perks)
		end
		local valores = Progression.computePerks(roleId, rangos, {}, nil, equipo)
		return function(nombre: string): number
			local valor = valores[nombre]
			if valor == nil then
				valor = Perks[nombre]
			end
			assert(valor ~= nil, `Ventaja desconocida: {nombre} (Data/Perks)`)
			return valor
		end
	end

	-- Daño real por segundo de un veneno de "dps" (Combat/Status.poison): cada golpe pasa por
	-- PlayerDamageMultiplier y se redondea, sin críticos.
	local function venenoReal(dps: number): number
		if dps <= 0 then
			return 0
		end
		local tick = A.PoisonTickSeconds or 1
		return math.max(1, math.round(dps * tick * PDM)) / tick
	end

	-- Arma del rol: id, daño por golpe con la ventaja del rol (como CombatService), DPS base y real.
	-- "veneno": daño real por segundo del veneno de las cerbatanas (Data/Weapons "poison") en el mono al
	-- que dispara; cuenta en los DPS del arma.
	type Arma = {
		id: string,
		golpe: number,
		dpsBase: number,
		dpsReal: number,
		critico: number,
		cura: number,
		veneno: number,
		venenoBase: number, -- el veneno por segundo sin PlayerDamageMultiplier (contra jugadores)
		venenoSegundos: number,
	}
	-- "forzada": id de un arma para esta medida (las mejoras de la forja, sección 3).
	local function armaDe(roleId: string, perk: Perk, forzada: string?): Arma
		local id = forzada or OPCIONES.armas[roleId] or Roles[roleId].weapons[1]
		local arma = Weapons[id]
		local ventaja = if arma.kind == "Melee"
			then "MeleeDamage"
			elseif arma.spell then "SpellDamage"
			else "RangedDamage"
		local golpe = math.round(arma.damage * perk(ventaja))
		local critico = OPCIONES.critico or arma.critChance or Config.Crit.DefaultWeaponChance
		local veneno = if arma.poison then arma.poison.dps * perk(ventaja) else 0
		local refuerzo = if arma.poison then arma.poison.boostItemId else nil
		if OPCIONES.dardosVenenosos and refuerzo then
			veneno *= Items[refuerzo].poisonMultiplier or 1
		end
		local dpsGolpes = golpe / arma.cooldownSeconds
		return {
			id = id,
			golpe = golpe,
			dpsBase = dpsGolpes + veneno,
			dpsReal = dpsGolpes * PDM * (1 + critico * (CRIT - 1)) + venenoReal(veneno),
			critico = critico,
			cura = (arma.healOnHit or 0) / arma.cooldownSeconds,
			veneno = venenoReal(veneno),
			venenoBase = veneno,
			venenoSegundos = if arma.poison then arma.poison.seconds else 0,
		}
	end

	local function resolver(objetivos: Objetivos?, grupo: number): number
		if not objetivos then
			return 0
		end
		local cuantos
		if objetivos.fijo then
			cuantos = objetivos.fijo
		elseif objetivos.abanico then
			-- Contra uno solo entran unas 2 flechas; contra un grupo, el 70 % alcanza a alguien.
			cuantos = if grupo <= 1 then math.min(objetivos.abanico, 2) else objetivos.abanico * 0.7
			return cuantos
		elseif objetivos.radio then
			cuantos = tipicosEnRadio(objetivos.radio) - (objetivos.menos or 0)
		else
			cuantos = 1
		end
		return math.max(0, math.min(cuantos, grupo - (objetivos.menos or 0)))
	end

	-- Como AbilityService: con la ventaja propia de la habilidad si la tiene ("<id>Cooldown").
	local function recargaDe(ability: any, perk: Perk): number
		local propia = if Perks[`{ability.id}Cooldown`] ~= nil then perk(`{ability.id}Cooldown`) else 1
		return ability.cooldownSeconds * perk("CooldownRate") * propia
	end

	local function fichaDe(ability: any, perk: Perk, remate: boolean): Ficha?
		local modelo = modelos[ability.id]
		if not modelo then
			alerta(`{ability.id}: no tiene modelo en MODELOS (Tools/Equilibrio); no se puede medir`)
			return nil
		end
		return modelo(A, perk, remate, COMBO)
	end

	-- Daño base (antes de PDM y críticos) de un uso contra "grupo" monos.
	-- (El veneno, entero, como si no hubiera otro: la simulación sí descuenta el de la cerbatana.)
	local function danoDeUso(ficha: Ficha, grupo: number): number
		local total = 0
		for _, golpe in ficha.golpes or {} do
			if grupo >= (golpe.minObjetivos or 1) then
				total += golpe.cantidad * resolver(golpe.objetivos, grupo)
			end
		end
		if ficha.veneno then
			total += ficha.veneno.dps * ficha.veneno.segundos * resolver(ficha.veneno.objetivos, grupo)
		end
		return total
	end

	local function danoEnVentana(ficha: Ficha, grupo: number, ventana: number): number
		local total = 0
		for _, golpe in ficha.golpes or {} do
			if golpe.en <= ventana and grupo >= (golpe.minObjetivos or 1) then
				total += golpe.cantidad * resolver(golpe.objetivos, grupo)
			end
		end
		if ficha.veneno then
			total += ficha.veneno.dps * math.min(ficha.veneno.segundos, ventana) * resolver(
				ficha.veneno.objetivos,
				grupo
			)
		end
		return total
	end

	local function curaDeUso(ficha: Ficha): number
		local cura = ficha.cura
		if not cura then
			return 0
		end
		return cura.cantidad * (cura.ticks or 1) * resolver(cura.objetivos, OPCIONES.aliados)
	end

	-- ===================================== 1. Fichas =====================================

	type Resumen = { dpsGrupo: number, dpsUno: number, combos: number, curaPorSegundo: number }
	local controlRol: { [string]: number } = {}
	local controlRolJefe: { [string]: number } = {} -- sin lo que no afecta a los jefes

	if OPCIONES.secciones.fichas then
		linea(`## 1. Fichas (grupo de {OPCIONES.grupo}, talentos: {OPCIONES.talentos})`)
		linea("Daño real = base × PlayerDamageMultiplier × crítico esperado del arma. Seg. arma = daño de un uso")
		linea("al grupo ÷ DPS del arma del rol. Control = fracción del tiempo que tiene quieto a cada mono.")
		for _, roleId in ordenRoles do
			if visible(roleId) then
				local perk = perksDe(roleId)
				local arma = armaDe(roleId, perk)
				local factor = PDM * (1 + arma.critico * (CRIT - 1))
				linea("")
				local veneno = if arma.veneno > 0
					then ` + veneno {n(arma.veneno)}/s real {n(arma.venenoSegundos)} s`
					else ""
				linea(
					`### {Roles[roleId].icon} {roleId}: arma {arma.id} ({arma.golpe} por golpe{veneno}, DPS real {n(
						arma.dpsReal
					)}, crítico {pct(arma.critico)}) · vida {100 + perk("MaxHealth")}`
				)
				local savia = perk("SapShield")
				if savia > 0 then
					linea(
						`Savia protectora: escudo de {n(savia)} durante {n(A.SapShieldSeconds)} s al curar a un aliado, cada {n(
							A.SapShieldCooldown
						)} s como mucho ({n(savia / A.SapShieldCooldown)}/s si cura sin parar).`
					)
				end
				linea(
					"| Habilidad | Recarga | Familia | Daño 1 obj | Daño grupo | DPS grupo | Seg. arma | Pico 2 s | Control | Cura | Otros |"
				)
				linea("|---|---|---|---|---|---|---|---|---|---|---|")
				local controlTotal, controlJefe = 0, 0
				for _, ability in Roles[roleId].abilities do
					local ficha = fichaDe(ability, perk, false)
					if ficha then
						local recarga = recargaDe(ability, perk)
						local uno = danoDeUso(ficha, 1)
						local grupo = danoDeUso(ficha, OPCIONES.grupo)
						local segArma = grupo / arma.dpsBase
						local dpsGrupo = grupo * factor / recarga
						local control = 0
						if ficha.control then
							control = ficha.control.segundos / recarga
							-- Con el remate del combo algunas suman control (Grito, Marcar): se cuenta aparte.
						end
						local fichaRemate = fichaDe(ability, perk, true)
						local controlRemate = if fichaRemate and fichaRemate.control
							then fichaRemate.control.segundos / recarga
							else 0
						controlTotal += math.max(control, controlRemate)
						local fichaControl = if fichaRemate and fichaRemate.control
							then fichaRemate.control
							else ficha.control
						if not (fichaControl and fichaControl.jefes == false) then
							controlJefe += math.max(control, controlRemate)
						end
						local otros = {}
						if ficha.movilidad then
							table.insert(otros, `{n(ficha.movilidad)} studs`)
						end
						if ficha.vulnerable then
							table.insert(
								otros,
								`+{pct(ficha.vulnerable.valor)} daño {n(ficha.vulnerable.segundos)} s ({pct(
									ficha.vulnerable.segundos / recarga
								)} del tiempo)`
							)
						end
						if ficha.mitiga then
							table.insert(
								otros,
								`−{pct(ficha.mitiga.valor)} daño recibido {n(ficha.mitiga.segundos)} s ({pct(
									ficha.mitiga.segundos / recarga
								)})`
							)
						end
						if ficha.provoca then
							table.insert(otros, `provoca {n(ficha.provoca.segundos)} s`)
						end
						if ficha.lento then
							table.insert(otros, `lento ×{n(ficha.lento.factor, 2)} {n(ficha.lento.segundos)} s`)
						end
						if ficha.escudo then
							table.insert(
								otros,
								`escudo {n(ficha.escudo.cantidad)} ({n(ficha.escudo.cantidad / recarga)}/s)`
							)
						end
						if ficha.nota then
							table.insert(otros, ficha.nota)
						end
						local cura = curaDeUso(ficha)
						local textoControl = if control > 0 or controlRemate > 0
							then `{pct(math.max(control, controlRemate))}{if controlRemate > control
								then " (remate)"
								else ""}`
							else "-"
						linea(
							`| {ability.name}{if ability.ultimate then " (V)" else ""} | {n(recarga)} s | {ficha.familia} | {n(
								uno * factor
							)} | {n(grupo * factor)} | {n(dpsGrupo)} | {n(segArma, 2)} | {n(
								danoEnVentana(ficha, OPCIONES.grupo, 2) * factor
							)} | {textoControl} | {if cura > 0 then `{n(cura)} ({n(cura / recarga)}/s)` else "-"} | {table.concat(
								otros,
								"; "
							)} |`
						)

						-- Reglas.
						local nombre = `{roleId} · {ability.name}`
						if ability.ultimate then
							if fuera(recarga, LIMITES.recargaDefinitiva) then
								alerta(
									`{nombre}: recarga {n(recarga)} s fuera de {LIMITES.recargaDefinitiva[1]}–{LIMITES.recargaDefinitiva[2]} s`
								)
							end
							if grupo > 0 and fuera(segArma, LIMITES.segArmaDefinitiva) then
								alerta(
									`{nombre}: vale {n(segArma, 1)} s de arma, fuera de {LIMITES.segArmaDefinitiva[1]}–{LIMITES.segArmaDefinitiva[2]}`
								)
							end
						else
							if fuera(recarga, LIMITES.recargaActiva) then
								alerta(
									`{nombre}: recarga {n(recarga)} s fuera de {LIMITES.recargaActiva[1]}–{LIMITES.recargaActiva[2]} s`
								)
							end
							if grupo > 0 and fuera(segArma, LIMITES.segArmaActiva) then
								alerta(
									`{nombre}: vale {n(segArma, 2)} s de arma, fuera de {LIMITES.segArmaActiva[1]}–{LIMITES.segArmaActiva[2]}`
								)
							end
							if dpsGrupo > LIMITES.dpsActivaVsArma * arma.dpsReal then
								alerta(
									`{nombre}: su DPS en grupo ({n(dpsGrupo)}) pasa del {pct(LIMITES.dpsActivaVsArma)} del arma ({n(
										arma.dpsReal
									)})`
								)
							end
						end
						if math.max(control, controlRemate) > LIMITES.controlPorHabilidad then
							alerta(
								`{nombre}: controla a cada mono el {pct(math.max(control, controlRemate))} del tiempo (máx. {pct(
									LIMITES.controlPorHabilidad
								)})`
							)
						end
					end
				end
				controlRol[roleId] = controlTotal
				controlRolJefe[roleId] = controlJefe
				linea(`Control de todo el rol (con remates): {pct(controlTotal)} del tiempo por mono.`)
				if controlTotal > LIMITES.controlPorRol then
					alerta(
						`{roleId}: entre todas sus habilidades controla a un mono el {pct(controlTotal)} del tiempo (máx. {pct(
							LIMITES.controlPorRol
						)})`
					)
				end
			end
		end
		-- Todo el equipo contra un jefe (se resisten: BossControlMultiplier).
		local equipo = 0
		for _, valor in controlRolJefe do
			equipo += valor
		end
		equipo *= A.BossControlMultiplier
		linea("")
		linea(
			`Control de un equipo con un jugador de cada rol sobre un jefe: {pct(equipo)} del tiempo (no hay rendimientos decrecientes).`
		)
		if equipo > LIMITES.controlJefeEquipo then
			alerta(
				`Un equipo de 4 roles tiene quieto a un jefe el {pct(equipo)} del tiempo (máx. {pct(
					LIMITES.controlJefeEquipo
				)})`
			)
		end
		linea("")
	end

	-- ===================================== 2. Simulación =====================================
	-- Un jugador sin moverse que pega con el arma del rol cuando no lanza habilidades. Contra el grupo,
	-- los monos no mueren (se mide el daño, no las muertes). "combos": empieza el combo que pueda
	-- (todos sus pasos listos a tiempo), lo enlaza, y al cerrarlo sigue por el otro combo del rol desde
	-- su paso 2 (la conexión, como ComboService.complete). Mientras espera un paso, lanza las
	-- habilidades de los combos que vayan a estar listas otra vez a tiempo.

	type Sim = {
		total: number,
		arma: number,
		habilidades: number,
		cura: number,
		combos: number,
		conexiones: number,
		curva: { [number]: number },
	}
	local CORTES = { 2, 5, 10, 30, 60 }

	-- Contra jugadores (sección 6): el daño del arma y el de las habilidades llevan su multiplicador de
	-- la arena en vez de PlayerDamageMultiplier (que es solo contra monos).
	type Pvp = { arma: number, habilidades: number }

	local function simular(
		roleId: string,
		grupo: number,
		conCombos: boolean,
		armaForzada: string?,
		duracion: number?,
		pvp: Pvp?
	): Sim
		local fin = duracion or OPCIONES.segundos
		local perk = perksDe(roleId)
		local arma = armaDe(roleId, perk, armaForzada)
		local critico = 1 + arma.critico * (CRIT - 1)
		local abilities = Roles[roleId].abilities
		local combos: { any } = if conCombos then Combos[roleId] or {} else {}
		local huecoDe: { [string]: number } = {}
		for hueco, ability in abilities do
			huecoDe[ability.id] = hueco
		end
		local listo: { number } = {}
		for hueco in abilities do
			listo[hueco] = 0
		end
		local pendientes: { { en: number, cantidad: number, criticoSeguro: number, bonus: number } } = {}
		local resultado: Sim =
			{ total = 0, arma = 0, habilidades = 0, cura = 0, combos = 0, conexiones = 0, curva = {} }
		-- activo: índice del combo en marcha en "combos" (0 = ninguno); conectado: empezó por la conexión.
		local activo, paso, pasoHasta, racha, conectado = 0, 0, -math.huge, 0, false
		local devuelto = 0 -- segundos que los combos han quitado ya a la recarga de la definitiva en curso
		local vulnerableDesde, vulnerableHasta, vulnerableValor = -1, -1, 0
		-- Veneno: el de la cerbatana en el mono al que dispara y el de una habilidad en "venenoCuantos"
		-- monos (uno de ellos, ese mismo). No se suman: en el mismo mono gana el más fuerte.
		local venenoArmaHasta = -1
		local venenoHasta, venenoDps, venenoCuantos = -1, 0, 0
		local armaLista, bloqueoHasta = 0, 0
		local t, dt = 0, 0.05
		local corte = 1

		local function factorRacha(): number
			return if racha >= 2 then 1 - COMBO.StreakCooldownBonus * (racha - 1) else 1
		end

		-- Como ComboService.stepDeadline: la ventana del paso "k" del combo "c" cuenta desde que esté listo.
		local function plazo(c: number, k: number): number
			local combo = combos[c]
			local hueco = if combo then huecoDe[combo.steps[k] or ""] else nil
			local desde = if hueco then math.max(t, listo[hueco]) else t
			return desde + COMBO.StepWindowSeconds
		end

		local function aplicar(cantidad: number, aCritico: number, deHabilidad: boolean, bonus: number)
			-- aCritico: parte del daño (0-1) que es golpe de combo (crítico seguro y "damageBonus" del combo).
			local enlace = CRIT * (1 + bonus)
			local base = if pvp then (if deHabilidad then pvp.habilidades else pvp.arma) else PDM
			local mult = base * (aCritico * enlace + (1 - aCritico) * critico)
			if t >= vulnerableDesde and t < vulnerableHasta then
				mult *= 1 + vulnerableValor
			end
			local dano = cantidad * mult
			resultado.total += dano
			if deHabilidad then
				resultado.habilidades += dano
			else
				resultado.arma += dano
			end
		end

		-- Lo que gotean los venenos en "dt" (ya en daño real: venenoReal).
		local function gotear()
			local venenoArma = if pvp then arma.venenoBase * pvp.arma else arma.veneno
			local delArma = if t < venenoArmaHasta then venenoArma else 0
			local deHabilidad = 0
			if t < venenoHasta and venenoCuantos > 0 then
				-- En el mono de la cerbatana solo cuenta lo que el de la habilidad tiene de más.
				deHabilidad = math.max(0, venenoDps - delArma) + venenoDps * (venenoCuantos - 1)
			end
			local mult = if t >= vulnerableDesde and t < vulnerableHasta then 1 + vulnerableValor else 1
			resultado.total += (delArma + deHabilidad) * mult * dt
			resultado.arma += delArma * mult * dt
			resultado.habilidades += deHabilidad * mult * dt
		end

		local function lanzar(hueco: number)
			local ability = abilities[hueco]
			local id = ability.id
			local enlazado = false
			local bonus = 0
			local combo = combos[activo]
			local indice = if combo then table.find(combo.steps, id) else nil
			if ability.ultimate then
				devuelto = 0
			end
			if combo and indice and indice > 1 and paso == indice - 1 and t <= pasoHasta then
				enlazado = true
				bonus = combo.damageBonus or 0
				paso, pasoHasta = indice, plazo(activo, indice + 1)
				if not ability.ultimate then
					-- Como ComboService.refundUltimate: con tope por recarga (UltRefundMaxSeconds).
					local margen = if COMBO.UltRefundMaxSeconds then COMBO.UltRefundMaxSeconds - devuelto else math.huge
					for otro, otra in abilities do
						if otra.ultimate then
							local quita = math.max(0, math.min(COMBO.UltRefundSeconds, margen, listo[otro] - t))
							listo[otro] -= quita
							devuelto += quita
						end
					end
				end
				if indice >= #combo.steps then
					local extra = if conectado then COMBO.ConnectStreakBonus or 0 else 0
					racha = math.min(COMBO.MaxStreak, racha + 1 + extra)
					resultado.combos += 1
					if conectado then
						resultado.conexiones += 1
					end
					-- Conexión (ComboService.complete): el remate deja abierto el otro combo en su paso 1.
					if #combos >= 2 then
						activo = activo % #combos + 1
						paso, pasoHasta, conectado = 1, plazo(activo, 2), true
					else
						activo, paso = 0, 0
					end
				end
			else
				-- Como ComboService.opener: a mitad de combo marca, pero no empieza otro.
				local enMarcha = activo > 0 and paso >= 2 and t <= pasoHasta
				for c, otro in combos do
					if otro.steps[1] == id and not enMarcha then
						local renueva = c == activo and paso == 1 and t <= pasoHasta
						conectado = renueva and conectado
						activo, paso = c, 1
						pasoHasta = math.max(plazo(c, 2), if renueva then pasoHasta else -math.huge)
						break
					end
				end
			end
			local ficha = fichaDe(ability, perk, enlazado)
			listo[hueco] = t + recargaDe(ability, perk) * factorRacha()
			if not ficha then
				return
			end
			bloqueoHasta = t + math.max(OPCIONES.lanzamiento, ficha.bloqueo or 0)
			-- Los marcados por el paso 1 son, como mucho, los que alcanzó (aprox. los 2-3 primeros).
			local marcados = math.min(grupo, 3)
			for _, golpe in ficha.golpes or {} do
				if grupo >= (golpe.minObjetivos or 1) then
					local cuantos = resolver(golpe.objetivos, grupo)
					local seguro = if enlazado and cuantos > 0 then math.min(1, marcados / cuantos) else 0
					table.insert(pendientes, {
						en = t + golpe.en,
						cantidad = golpe.cantidad * cuantos,
						criticoSeguro = seguro,
						bonus = bonus,
					})
				end
			end
			if ficha.vulnerable then
				-- Solo en los que alcanza: con un área pequeña, parte del grupo se queda fuera.
				local cuantos = resolver(ficha.vulnerable.objetivos, grupo)
				vulnerableDesde = t + (ficha.vulnerable.en or 0)
				vulnerableHasta = vulnerableDesde + ficha.vulnerable.segundos
				vulnerableValor = ficha.vulnerable.valor * math.min(1, cuantos / grupo)
			end
			if ficha.veneno then
				venenoHasta = t + ficha.veneno.segundos
				venenoDps = if pvp then ficha.veneno.dps * pvp.habilidades else venenoReal(ficha.veneno.dps)
				venenoCuantos = resolver(ficha.veneno.objetivos, grupo)
			end
			local cura = curaDeUso(ficha)
			if cura > 0 then
				resultado.cura += cura * (if ficha.critSeguro then CRIT else 1)
			end
			if ficha.escudo then
				resultado.cura += ficha.escudo.cantidad * 0.8 -- parte del escudo se pierde sin usar
			end
		end

		local function elegir(): number?
			if #combos == 0 then
				for hueco in abilities do
					if t >= listo[hueco] then
						return hueco
					end
				end
				return nil
			end
			local enCombo: { [number]: boolean } = {}
			for _, combo in combos do
				for _, id in combo.steps do
					if huecoDe[id] then
						enCombo[huecoDe[id]] = true
					end
				end
			end
			-- Cuándo hará falta otra vez cada habilidad de los combos: esperando un paso, cuando estén
			-- listos los que faltan; sin combo en marcha, cuando lo esté el primer combo que se pueda hacer.
			local inicio = t
			local esperado: number? = nil
			if activo > 0 and paso >= 1 and t <= pasoHasta then
				-- Siguiente paso del combo en marcha.
				local combo = combos[activo]
				esperado = huecoDe[combo.steps[paso + 1]]
				if esperado and t >= listo[esperado] then
					return esperado
				end
				for k, id in combo.steps do
					local hueco = huecoDe[id]
					if hueco and k > paso then
						inicio = math.max(inicio, listo[hueco])
					end
				end
			else
				activo, paso, conectado = 0, 0, false
				-- ¿Se puede empezar alguno? El paso k tiene que estar listo antes de que se cierre su ventana.
				inicio = math.huge
				for _, combo in combos do
					local puede, listoCombo = true, t
					for k, id in combo.steps do
						local hueco = huecoDe[id]
						if not hueco then
							puede, listoCombo = false, math.huge
						else
							if listo[hueco] > t + (k - 1) * (COMBO.StepWindowSeconds - 0.5) then
								puede = false
							end
							listoCombo = math.max(listoCombo, listo[hueco])
						end
					end
					if puede then
						return huecoDe[combo.steps[1]]
					end
					inicio = math.min(inicio, listoCombo)
				end
			end
			for hueco, ability in abilities do
				if t >= listo[hueco] then
					if not enCombo[hueco] then
						return hueco
					end
					-- Del combo, pero estará lista otra vez antes de que haga falta (usarla suelta no
					-- rompe el combo en marcha: ComboService solo mira el paso siguiente).
					if hueco ~= esperado and t + recargaDe(ability, perk) * factorRacha() <= inicio then
						return hueco
					end
				end
			end
			return nil
		end

		while t <= fin + 1e-6 do
			local i = 1
			while i <= #pendientes do
				local evento = pendientes[i]
				if evento.en <= t then
					aplicar(evento.cantidad, evento.criticoSeguro, true, evento.bonus)
					table.remove(pendientes, i)
				else
					i += 1
				end
			end
			if t >= bloqueoHasta then
				local hueco = elegir()
				if hueco then
					lanzar(hueco)
				elseif t >= armaLista then
					armaLista = t + Weapons[arma.id].cooldownSeconds
					aplicar(arma.golpe, 0, false, 0)
					resultado.cura += arma.cura * Weapons[arma.id].cooldownSeconds
					if arma.veneno > 0 then
						venenoArmaHasta = t + arma.venenoSegundos
					end
				end
			end
			gotear()
			if CORTES[corte] and t >= CORTES[corte] - 1e-6 then
				resultado.curva[CORTES[corte]] = resultado.total
				corte += 1
			end
			t += dt
		end
		return resultado
	end

	local resumen: { [string]: Resumen } = {}
	if OPCIONES.secciones.simulacion or OPCIONES.secciones.ttk then
		for _, roleId in ordenRoles do
			local uno = simular(roleId, 1, true)
			local grupoCon = simular(roleId, OPCIONES.grupo, true)
			resumen[roleId] = {
				dpsUno = uno.total / OPCIONES.segundos,
				dpsGrupo = grupoCon.total / OPCIONES.segundos,
				combos = grupoCon.combos,
				curaPorSegundo = grupoCon.cura / OPCIONES.segundos,
			}
		end
	end

	if OPCIONES.secciones.simulacion then
		linea(`## 2. Daño en el tiempo ({OPCIONES.segundos} s, todo listo al empezar)`)
		linea(
			'Daño acumulado real contra monos. "Sin combos": pulsa lo que esté listo. "Combos": enlaza los combos (🔗 = cerrados por una conexión).'
		)
		linea("| Rol | Escenario | Jugador | 2 s | 5 s | 10 s | 30 s | 60 s | DPS | % habilidades | Combos | Cura/s |")
		linea("|---|---|---|---|---|---|---|---|---|---|---|---|")
		local totalesGrupo: { [string]: number } = {}
		local totalesUno: { [string]: number } = {}
		for _, roleId in ordenRoles do
			if visible(roleId) then
				for _, grupo in { 1, OPCIONES.grupo } do
					local sin = simular(roleId, grupo, false)
					local con = simular(roleId, grupo, true)
					for _, par in { { "sin combos", sin }, { "combos", con } } do
						local sim = par[2] :: Sim
						local c = sim.curva
						linea(
							`| {roleId} | {if grupo == 1 then "1 objetivo" else `grupo de {grupo}`} | {par[1]} | {n(
								c[2],
								0
							)} | {n(c[5], 0)} | {n(c[10], 0)} | {n(c[30], 0)} | {n(c[60], 0)} | {n(
								sim.total / OPCIONES.segundos
							)} | {pct(sim.habilidades / math.max(1, sim.total))} | {sim.combos}{if sim.conexiones
									> 0
								then ` ({sim.conexiones} 🔗)`
								else ""} | {n(sim.cura / OPCIONES.segundos)} |`
						)
					end
					if grupo > 1 and Combos[roleId] and roleId ~= "Medico" then
						totalesGrupo[roleId] = con.total
					elseif grupo == 1 and roleId ~= "Medico" then
						totalesUno[roleId] = con.total
					end
					if
						roleId == "Medico"
						and grupo > 1
						and con.cura / OPCIONES.segundos > LIMITES.curacionPorSegundo * OPCIONES.aliados
					then
						alerta(
							`Médico: cura {n(con.cura / OPCIONES.segundos)}/s al equipo (máx. {LIMITES.curacionPorSegundo}/s por aliado)`
						)
					end
				end
			end
		end
		-- Lo que vale enlazar el combo, en una pelea más larga que una recarga de la definitiva.
		local valores = {}
		for _, roleId in ordenRoles do
			if visible(roleId) and Combos[roleId] and roleId ~= "Medico" then
				local medidas = {}
				for _, grupo in { OPCIONES.grupo, 1 } do
					local sin = simular(roleId, grupo, false, nil, OPCIONES.segundosCombo)
					local con = simular(roleId, grupo, true, nil, OPCIONES.segundosCombo)
					local bonus = con.total / math.max(1, sin.total) - 1
					table.insert(medidas, `{if bonus >= 0 then "+" else ""}{pct(bonus)}`)
					if grupo > 1 and fuera(bonus, LIMITES.bonusCombo) then
						alerta(
							`{roleId}: enlazar el combo da {pct(bonus)} de daño en grupo en {OPCIONES.segundosCombo} s (objetivo {pct(
								LIMITES.bonusCombo[1]
							)}–{pct(LIMITES.bonusCombo[2])})`
						)
					end
				end
				table.insert(valores, `{roleId} {table.concat(medidas, " / ")}`)
			end
		end
		if #valores > 0 then
			linea("")
			linea(
				`Daño extra por enlazar el combo en {OPCIONES.segundosCombo} s (grupo / 1 objetivo): {table.concat(
					valores,
					" · "
				)}.`
			)
		end
		for _, par in
			{
				{ totalesGrupo, LIMITES.repartoRoles, "en grupo" },
				{ totalesUno, LIMITES.repartoRolesUno, "contra 1 objetivo" },
			}
		do
			local totales, margen, texto = par[1] :: { [string]: number }, par[2] :: number, par[3] :: string
			local suma, cuenta = 0, 0
			for _, valor in totales do
				suma += valor
				cuenta += 1
			end
			if cuenta >= 2 then
				local media = suma / cuenta
				for roleId, valor in totales do
					if math.abs(valor / media - 1) > margen then
						alerta(
							`{roleId}: hace {pct(valor / media - 1)} de daño {texto} respecto a la media de los roles de daño (margen ±{pct(
								margen
							)})`
						)
					end
				end
			end
		end
		linea("")
	end

	-- ===================================== 3. Tiempo para matar =====================================

	local function multiplicadorDia(dia: number, porDia: number): number
		return math.min(1 + (dia - 1) * porDia, Config.Difficulty.MaxMultiplier)
	end

	if OPCIONES.secciones.ttk then
		linea(
			`## 3. Tiempo para matar (s, DPS medio de 60 s con combos contra 1 objetivo × actividad {pct(
				OPCIONES.actividad
			)})`
		)
		local cabecera = { "| Rol" }
		local separador = { "|---" }
		for _, especie in OPCIONES.especies do
			for _, dia in OPCIONES.dias do
				table.insert(cabecera, ` {Monkeys[especie].name} d{dia}`)
				table.insert(separador, "---")
			end
		end
		linea(table.concat(cabecera, " |") .. " |")
		linea(table.concat(separador, "|") .. "|")
		for _, roleId in ordenRoles do
			local fila = { `| {roleId}` }
			for _, especie in OPCIONES.especies do
				for _, dia in OPCIONES.dias do
					local vida = Monkeys[especie].maxHealth * multiplicadorDia(dia, Config.Difficulty.HealthPerDay)
					table.insert(fila, ` {n(vida / (resumen[roleId].dpsUno * OPCIONES.actividad))}`)
				end
			end
			linea(table.concat(fila, " |") .. " |")
		end
		-- Jefes: cada uno con las armas de rol que se suelen tener el día en que aparece. El equipo es
		-- uno de cada rol repetido (DPS medio de los 4 roles por jugador).
		local function vidaPorJugadores(jugadores: number): number
			local ajustes = Config.Bosses
			if ajustes then
				return math.min(
					ajustes.MaxHealthMultiplier,
					ajustes.HealthBase + ajustes.HealthPerExtraPlayer * (math.max(1, jugadores) - 1)
				)
			end
			-- Antes de octubre de 2026 (contaba a todos los jugadores del servidor).
			return math.clamp(0.6 + 0.2 * jugadores, 0.8, 3)
		end
		local function armaDeNivel(roleId: string, nivel: number): string
			local id = OPCIONES.armas[roleId] or Roles[roleId].weapons[1]
			for _ = 1, nivel do
				local siguiente = nil
				for _, receta in Recipes do
					if receta.upgrades == id and receta.role == roleId and receta.weaponId then
						siguiente = receta.weaponId
					end
				end
				if not siguiente then
					break
				end
				id = siguiente
			end
			return id
		end
		local function nivelDelDia(dia: number): number
			local nivel, desde = 0, -1
			for diaNivel, valor in OPCIONES.armasPorDia do
				if diaNivel <= dia and diaNivel > desde then
					nivel, desde = valor, diaNivel
				end
			end
			return nivel
		end
		local dpsPorNivel: { [number]: number } = {}
		local function dpsJugador(nivel: number): number
			if not dpsPorNivel[nivel] then
				local suma = 0
				for _, roleId in ordenRoles do
					suma += simular(roleId, 1, true, armaDeNivel(roleId, nivel)).total / OPCIONES.segundos
				end
				dpsPorNivel[nivel] = suma / #ordenRoles * OPCIONES.actividad
			end
			return dpsPorNivel[nivel]
		end

		linea("")
		linea(
			`Jefes (s hasta derrotarlo; vida × jugadores que pelean{if Config.Bosses
				then ""
				else " (fórmula antigua: todos los del servidor)"}):`
		)
		local cabeceraJefes = { "| Jefe | Día | Armas | Vida base" }
		for _, jugadores in OPCIONES.jugadoresJefe do
			table.insert(cabeceraJefes, ` {jugadores} jug.`)
		end
		linea(table.concat(cabeceraJefes, " |") .. " |")
		linea("|---|---|---|---" .. string.rep("|---", #OPCIONES.jugadoresJefe) .. "|")
		for indice, bossId in Config.Match.BossRotation do
			local jefe = Bosses[bossId]
			local dia = indice * Config.Match.BossIntervalDays
			local nivel = nivelDelDia(dia)
			local fila = { `| {jefe.name} | {dia} | mejora {nivel} | {jefe.maxHealth}` }
			for _, jugadores in OPCIONES.jugadoresJefe do
				local segundos = jefe.maxHealth * vidaPorJugadores(jugadores) / (dpsJugador(nivel) * jugadores)
				table.insert(fila, ` {n(segundos, 0)}`)
				if jugadores == OPCIONES.aliados and fuera(segundos, LIMITES.jefeSegundos) then
					alerta(
						`{jefe.name} ({bossId}): dura {n(segundos, 0)} s con {jugadores} jugadores (objetivo {LIMITES.jefeSegundos[1]}–{LIMITES.jefeSegundos[2]} s)`
					)
				elseif jugadores == 1 and segundos > LIMITES.jefeSoloSegundos then
					alerta(
						`{jefe.name} ({bossId}): un jugador solo tarda {n(segundos, 0)} s (máx. {LIMITES.jefeSoloSegundos} s)`
					)
				end
			end
			linea(table.concat(fila, " |") .. " |")
		end
		local multiplicadores = {}
		for _, jugadores in OPCIONES.jugadoresJefe do
			table.insert(multiplicadores, `{jugadores}: ×{n(vidaPorJugadores(jugadores), 2)}`)
		end
		linea(`Vida según jugadores: {table.concat(multiplicadores, " · ")}.`)
		linea("")
	end

	-- ===================================== 4. Amenaza de los enemigos =====================================

	if OPCIONES.secciones.enemigos then
		local hueso = Armor.BoneArmor and Armor.BoneArmor.damageReduction or 0
		local inmunidad = Config.Combat.PlayerControlImmunitySeconds or 0
		linea("## 4. Amenaza de monos y jefes (vida base del jugador: 100)")
		linea(
			"Golpe máx. = el más fuerte posible (salto ×2, alfa, crítico). DPS con crítico esperado. Caído en = s hasta 100 de daño."
		)
		linea(
			`Te deja quieto = si todos sus golpes entran; tras soltarte, {inmunidad} s en los que no te pueden volver a sujetar.`
		)
		linea("| Mono | Cat. | Día | DPS | Golpe máx. | Caído en | Con hueso | Especial | Te deja quieto |")
		linea("|---|---|---|---|---|---|---|---|---|")
		local especies = {}
		for id in Monkeys do
			table.insert(especies, id)
		end
		table.sort(especies, function(a, b)
			return Monkeys[a].tier < Monkeys[b].tier or (Monkeys[a].tier == Monkeys[b].tier and a < b)
		end)
		local diaMax = math.ceil((Config.Difficulty.MaxMultiplier - 1) / Config.Difficulty.DamagePerDay) + 1
		for _, id in especies do
			local mono = Monkeys[id]
			if mono.damage > 0 then
				local probCritico = Config.Crit.MonkeyTierChance[mono.tier] or 0
				for _, dia in { OPCIONES.dias[1], diaMax } do
					local dano = mono.damage * multiplicadorDia(dia, Config.Difficulty.DamagePerDay)
					local alfa = if mono.alpha then Config.Monkeys.AlphaDamageMultiplier else 1
					local dps = dano / mono.attackCooldownSeconds * (1 + probCritico * (CRIT - 1))
					local golpeMax = dano
						* alfa
						* (if mono.pounce then 2 else 1)
						* (if probCritico > 0 then CRIT else 1)
					local especial = {}
					local quieto = 0
					if mono.grab then
						-- Tras soltarte no te puede volver a agarrar hasta su primer golpe pasada la
						-- inmunidad (Status.holdPlayer).
						local ciclo = math.ceil((mono.grab + inmunidad) / mono.attackCooldownSeconds - 1e-6)
							* mono.attackCooldownSeconds
						quieto = mono.grab / ciclo
						table.insert(especial, `agarre {mono.grab} s`)
					end
					if mono.stomp then
						local escala = dano / mono.damage
						table.insert(
							especial,
							`pisotón {n(mono.stomp.damage * escala)} + {mono.stomp.stunSeconds} s cada {mono.stomp.cooldownSeconds} s`
						)
						quieto = math.max(
							quieto,
							mono.stomp.stunSeconds
								/ math.max(mono.stomp.cooldownSeconds, mono.stomp.stunSeconds + inmunidad)
						)
						dps += mono.stomp.damage * escala / mono.stomp.cooldownSeconds
					end
					if mono.throws then
						table.insert(
							especial,
							`piedra {n(mono.throws.damage * dano / mono.damage)} a {mono.throws.range} studs`
						)
					end
					if mono.roar then
						table.insert(
							especial,
							`rugido −{pct(1 - Config.Combat.IntimidatedDamageMultiplier)} daño {mono.roar.seconds} s`
						)
					end
					if mono.pounce then
						table.insert(especial, "salto ×2")
					end
					linea(
						`| {mono.name}{if mono.alpha
							then " (alfa ×" .. Config.Monkeys.AlphaDamageMultiplier .. ")"
							else ""} | {mono.tier} | {dia} | {n(dps)} | {n(golpeMax, 0)} | {n(100 / dps)} | {n(
							100 / (dps * (1 - hueso))
						)} | {table.concat(especial, "; ")} | {if quieto > 0
							then pct(math.min(1, quieto))
							else "-"} |`
					)
					local limite = if dia == OPCIONES.dias[1] then LIMITES.golpeEnemigoDia1 else LIMITES.golpeEnemigoMax
					if golpeMax > limite then
						alerta(
							`{mono.name} día {dia}: su golpe más fuerte quita {n(golpeMax, 0)} de 100 (máx. {limite})`
						)
					end
					if quieto >= LIMITES.bloqueoEnemigo and dia == OPCIONES.dias[1] then
						alerta(`{mono.name}: puede dejarte sin moverte el {pct(math.min(1, quieto))} del tiempo`)
					end
				end
			end
		end
		linea("")
		linea("| Jefe | Fase | Golpe | Golpe máx. (crítico) | Especiales (daño con crítico) |")
		linea("|---|---|---|---|---|")
		for _, jefe in Bosses do
			for _, fase in { 1, 3 } do
				local golpe = math.round(jefe.damage * (1 + 0.2 * (fase - 1)))
				local maximo = golpe * CRIT
				local especiales = {}
				for _, especial in jefe.specials do
					if especial.fromPhase <= fase then
						local texto = especial.id
						if especial.id == "stomp" then
							texto = `pisotón {n(golpe * 0.8 * CRIT, 0)} + 1,5 s`
						elseif especial.id == "rockRain" then
							texto = `{especial.count or 5} rocas de {n(golpe * 0.7, 0)}`
						elseif especial.id == "charge" then
							texto = `embestida {n(golpe * CRIT, 0)} + 1 s`
						elseif especial.id == "grab" then
							texto = `agarre {n(golpe * 0.6 * CRIT, 0)} + 3 s`
						elseif especial.id == "summon" then
							texto = `llama {especial.count or 3} {especial.species}`
						elseif especial.id == "extinguish" then
							texto = "apaga antorchas + 1 s"
						end
						table.insert(especiales, `{texto} (cada {especial.cooldownSeconds} s)`)
					end
				end
				linea(`| {jefe.name} | {fase} | {golpe} | {n(maximo, 0)} | {table.concat(especiales, "; ")} |`)
				if maximo > LIMITES.golpeJefe then
					alerta(
						`{jefe.name} fase {fase}: golpe con crítico de {n(maximo, 0)} (máx. {LIMITES.golpeJefe} sin armadura)`
					)
				end
			end
		end
		linea("")
	end

	-- ===================================== 5. Mascotas =====================================

	if OPCIONES.secciones.mascotas then
		local dpsArmas, cuenta = 0, 0
		for _, roleId in ordenRoles do
			dpsArmas += armaDe(roleId, perksDe(roleId)).dpsReal
			cuenta += 1
		end
		dpsArmas /= cuenta
		linea(`## 5. Mascotas (cada {Config.Pets.TickSeconds} s; DPS medio de las armas de rol: {n(dpsArmas)})`)
		linea("| Mascota | Rareza | Tipo | DPS | % del arma | Cura/s | Ventajas |")
		linea("|---|---|---|---|---|---|---|")
		local ids = {}
		for id in Pets do
			table.insert(ids, id)
		end
		local orden = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
		table.sort(ids, function(a, b)
			return (orden[Pets[a].rarity] or 9) < (orden[Pets[b].rarity] or 9)
		end)
		-- Marca de las mascotas que señalan a un mono ("marks", el pointer): no hace daño, pero todo el que
		-- le pega hace Config.Pets.MarkBonus más mientras dura (PetService la renueva en cada tick). Se mide
		-- como DPS equivalente: con su dueño solo (con su arma) y con el equipo (OPCIONES.aliados, que
		-- meten al marcado OPCIONES.focoMarca de su daño). Sobre un jefe (× MarkBossMultiplier) se mira lo
		-- que le deja a "Marcar presas" del cazador: las dos marcas no se suman (gana la mayor), así que
		-- con la mascota en el equipo la del cazador solo añade la diferencia mientras dura.
		local P = Config.Pets
		local cobertura = if P.MarkSeconds then math.min(1, P.MarkSeconds / P.TickSeconds) else 0
		local marcaMedia = (P.MarkBonus or 0) * cobertura
		local cazador = perksDe("Cazador")
		local presasBonus, presasCobertura = 0, 0
		for _, habilidad in Roles.Cazador.abilities do
			if habilidad.id == "MarkPrey" then
				presasBonus = cazador("MarkedBonus")
				presasCobertura = math.min(1, cazador("MarkSeconds") / recargaDe(habilidad, cazador))
			end
		end
		local marcarPresas = presasBonus * presasCobertura
		local notas = {}
		for _, id in ids do
			local mascota = Pets[id]
			-- No pasan por PlayerDamageMultiplier (CombatService: "pet").
			local dps = (mascota.attackDamage or 0) / Config.Pets.TickSeconds * (1 + Config.Crit.PetChance * (CRIT - 1))
			local cura = (mascota.healPerTick or 0) / Config.Pets.TickSeconds
			local ventajas = {}
			for perk, valor in mascota.perks or {} do
				table.insert(ventajas, `{perk} {if valor > 0 then "+" else ""}{n(valor, 2)}`)
			end
			local dpsMostrado = if dps > 0 then n(dps) else "-"
			local pctMostrado = if dps > 0 then pct(dps / dpsArmas) else "-"
			local medido = dps
			if mascota.marks then
				local solo = marcaMedia * dpsArmas
				local equipo = solo * OPCIONES.aliados * OPCIONES.focoMarca
				local jefe = (P.MarkBonus or 0) * (P.MarkBossMultiplier or 1)
				local presasConMascota = presasCobertura * math.max(0, presasBonus - jefe * cobertura)
				medido = math.max(dps, solo, equipo)
				-- Solo · con el equipo.
				dpsMostrado = `≈{n(solo)} · {n(equipo)}`
				pctMostrado = `{pct(solo / dpsArmas)} · {pct(equipo / dpsArmas)}`
				table.insert(ventajas, `marca +{pct(P.MarkBonus)} el {pct(cobertura)} del tiempo`)
				table.insert(
					notas,
					`- {mascota.name}: marca +{pct(P.MarkBonus)} durante {P.MarkSeconds} s cada {P.TickSeconds} s. Equivale a ≈{n(
						solo
					)} DPS con su dueño solo ({pct(solo / dpsArmas)} del arma) y ≈{n(equipo)} con {OPCIONES.aliados} jugadores que meten al marcado el {pct(
						OPCIONES.focoMarca
					)} de su daño ({pct(equipo / dpsArmas)}). A un jefe: +{n(jefe * cobertura * 100, 1)} % del daño del equipo; "Marcar presas" del cazador suma +{n(
						marcarPresas * 100,
						1
					)} % sola y +{n(presasConMascota * 100, 1)} % con esta mascota en el equipo.`
				)
				if marcarPresas > 0 and presasConMascota < LIMITES.marcaMascotaPresas * marcarPresas then
					alerta(
						`{mascota.name}: con su marca en un jefe, "Marcar presas" del cazador solo suma +{n(
							presasConMascota * 100,
							1
						)} % (sola, +{n(marcarPresas * 100, 1)} %; mín. el {pct(LIMITES.marcaMascotaPresas)})`
					)
				end
			end
			linea(
				`| {mascota.name} | {mascota.rarity} | {mascota.kind} | {dpsMostrado} | {pctMostrado} | {if cura
						> 0
					then n(cura, 2)
					else "-"} | {table.concat(ventajas, ", ")} |`
			)
			if medido > LIMITES.mascotaVsArma * dpsArmas then
				alerta(
					`{mascota.name}: su DPS ({n(medido)}) es el {pct(medido / dpsArmas)} del de un arma de rol (máx. {pct(
						LIMITES.mascotaVsArma
					)})`
				)
			end
		end
		if #notas > 0 then
			linea("")
			for _, nota in notas do
				linea(nota)
			end
		end
		linea("")
	end

	-- ===================================== 6. Arena =====================================
	-- Un duelo de dos jugadores, cada uno contra el otro como "1 objetivo" de la simulación, con los
	-- multiplicadores de Config.Arena (lo que contra jugadores hacen DunasCombatRules y CombatService).
	-- Lo que aguanta el que recibe: su vida (100 + MaxHealth), lo que su Grito de guerra le quita de
	-- media (reducción × duración ÷ recarga) y lo que se cura o se protege él solo por segundo (Ungüento
	-- y Tótem le alcanzan, el Escudo de hojas se lo pone él si no hay aliados y la cerbatana le cura al
	-- acertar). Segundos para tumbar = vida ÷ (DPS del atacante × actividad × (1 − reducción) − sustento).
	if OPCIONES.secciones.arena then
		local arenaConfig = Config.Arena
		local pvp: Pvp = {
			arma = arenaConfig.WeaponDamageMultiplier or 1,
			habilidades = arenaConfig.AbilityDamageMultiplier,
		}
		linea(
			`## 6. Arena de Dunas (duelos; armas ×{n(pvp.arma, 2)}, habilidades ×{n(pvp.habilidades, 2)}, actividad {pct(
				OPCIONES.actividad
			)}, {OPCIONES.segundos} s)`
		)
		linea(
			"Segundos que tarda el de la fila en tumbar al de la columna (con combos; entre paréntesis, sin combos)."
		)
		type Aguante = { vida: number, reduccion: number, sustento: number }
		local dps: { [string]: { con: number, sin: number } } = {}
		local aguante: { [string]: Aguante } = {}
		for _, roleId in ordenRoles do
			local perk = perksDe(roleId)
			-- Cada arma puede llevar su propio ajuste en la arena (Config.Arena.WeaponMultipliers).
			local armaId = armaDe(roleId, perk).id
			local propio = (arenaConfig.WeaponMultipliers or {})[armaId] or 1
			local pvpRol: Pvp = { arma = pvp.arma * propio, habilidades = pvp.habilidades }
			local con = simular(roleId, 1, true, nil, nil, pvpRol)
			local sin = simular(roleId, 1, false, nil, nil, pvpRol)
			dps[roleId] = { con = con.total / OPCIONES.segundos, sin = sin.total / OPCIONES.segundos }
			local curacion = arenaConfig.HealingMultiplier or 1
			local reduccion, sustento = 0, armaDe(roleId, perk).cura * curacion
			for _, ability in Roles[roleId].abilities do
				local recarga = recargaDe(ability, perk)
				local ficha = fichaDe(ability, perk, false)
				if ficha and ficha.mitiga then
					reduccion += ficha.mitiga.valor * ficha.mitiga.segundos / recarga
				end
				if ficha and ficha.cura and ability.id ~= "HealingDart" then
					sustento += ficha.cura.cantidad * (ficha.cura.ticks or 1) / recarga * curacion
				end
				if ficha and ficha.escudo then
					sustento += ficha.escudo.cantidad / recarga
				end
			end
			aguante[roleId] = { vida = 100 + perk("MaxHealth"), reduccion = reduccion, sustento = sustento }
		end
		local function segundos(atacante: string, defensor: string, conCombos: boolean): number
			local def = aguante[defensor]
			local efectivo = (if conCombos then dps[atacante].con else dps[atacante].sin)
					* OPCIONES.actividad
					* (1 - def.reduccion)
				- def.sustento
			return if efectivo > 0 then def.vida / efectivo else math.huge
		end
		local cabecera = { "| Atacante \\ Defensor |" }
		local separador = { "|---|" }
		for _, roleId in ordenRoles do
			local def = aguante[roleId]
			table.insert(
				cabecera,
				` {Roles[roleId].icon} {roleId} ({def.vida} vida{if def.reduccion > 0
					then `, −{pct(def.reduccion)}`
					else ""}{if def.sustento > 0 then `, +{n(def.sustento)}/s` else ""}) |`
			)
			table.insert(separador, "---|")
		end
		linea(table.concat(cabecera))
		linea(table.concat(separador))
		for _, atacante in ordenRoles do
			local fila =
				{ `| {Roles[atacante].icon} {atacante} (DPS {n(dps[atacante].con)} / {n(dps[atacante].sin)}) |` }
			for _, defensor in ordenRoles do
				local con, sin = segundos(atacante, defensor, true), segundos(atacante, defensor, false)
				local texto = if con == math.huge then "∞" else n(con)
				texto ..= ` ({if sin == math.huge then "∞" else n(sin)})`
				if atacante == defensor then
					texto = `**{texto}**`
				end
				table.insert(fila, ` {texto} |`)
			end
			linea(table.concat(fila))
		end
		local tiempos = {}
		for _, atacante in ordenRoles do
			tiempos[atacante] = {}
			for _, defensor in ordenRoles do
				tiempos[atacante][defensor] =
					{ con = segundos(atacante, defensor, true), sin = segundos(atacante, defensor, false) }
			end
		end
		ultimaArena = { tiempos = tiempos, dps = dps, aguante = aguante }
		for _, roleId in ordenRoles do
			local espejo = segundos(roleId, roleId, true)
			if roleId ~= "Medico" and fuera(espejo, LIMITES.arenaDueloEspejo) then
				alerta(
					`Arena: un duelo {roleId} contra {roleId} dura {if espejo == math.huge then "∞" else n(espejo)} s (objetivo {LIMITES.arenaDueloEspejo[1]}–{LIMITES.arenaDueloEspejo[2]} s)`
				)
			end
		end
		linea("")
	end

	linea("## 7. Alertas")
	if #alertas == 0 then
		linea("✅ Todo dentro de los límites.")
	else
		for _, texto in alertas do
			linea(texto)
		end
	end
	return table.concat(lineas, "\n")
end

local function copiaProfunda(valor: any): any
	if typeof(valor) ~= "table" then
		return valor
	end
	local resultado = {}
	for clave, dentro in valor do
		resultado[clave] = copiaProfunda(dentro)
	end
	return resultado
end

local Equilibrio = {}

-- Los números de la arena del último informe con secciones.arena (ver ultimaArena), o nil.
function Equilibrio.ultimaArena(): any
	return ultimaArena
end

-- Informe con "opciones" (cambios sobre OPCIONES_BASE) y "propuesta" (ver PROPUESTA). Los dos opcionales.
function Equilibrio.informe(opciones: any?, propuesta: Propuesta?): string
	OPCIONES = copiaProfunda(OPCIONES_BASE)
	mezclar(OPCIONES, opciones or {})
	PROPUESTA = propuesta or {}
	lineas = {}
	alertas = {}
	local copia = ReplicatedStorage:WaitForChild("Shared"):Clone()
	copia.Name = "_EquilibrioShared"
	copia.Parent = ServerStorage
	local ok, resultado = pcall(main, copia)
	copia:Destroy()
	if not ok then
		error(resultado, 0)
	end
	return resultado
end

return Equilibrio
