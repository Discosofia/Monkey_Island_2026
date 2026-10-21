-- Calculadora de la economía y la retención: Ámbar, misiones, huevos, talentos, equipo de la partida,
-- pase de temporada y reglas de pago. La usa la skill economia-retencion
-- (.claude/skills/economia-retencion). Se ejecuta en Studio, en modo edición (sin pulsar Play), desde
-- la barra de comandos o con el MCP, y devuelve un informe en tablas:
--
--   local m = game.ServerStorage.Tools.Economia:Clone() -- copia: así no usa la versión vieja en caché
--   print(require(m).informe()); m:Destroy()
--
-- No cambia nada: cada informe lee una copia nueva de ReplicatedStorage.Shared. Argumentos (opcionales):
--   informe(opciones, propuesta)
-- "opciones" cambia OPCIONES_BASE ({ dias = 45, perfiles = { habitual = { minutosIsla = 90 } } });
-- "propuesta" cambia datos solo para ese informe (números de Config o cualquier módulo de Data) para
-- probar una idea ANTES de tocar el repo.
-- Las reglas de la sección "Alertas" son las de la skill (references/limites.md, tabla LIMITES).
--
-- Lo que mide:
--   1. Misiones: minutos de juego que pide cada una con los RITMOS supuestos y su dificultad real.
--   2. Perfiles de jugador (casual, habitual, intenso, amigos) durante OPCIONES.dias días reales:
--      Ámbar ganado por fuente y gastado, día en que compra todas las mejoras, huevos eclosionados,
--      misiones cumplidas y día en que llena los talentos de su rol.
--   3. Partida: el día más temprano en que se puede tener cada nivel de arma y armadura, y lo que trae
--      de nuevo cada día de la partida.
--   4. Pase de temporada (Data/Seasons, la primera temporada): nivel de cada perfil por día, día en que
--      gana el último nivel, de dónde sale la XP y lo que da la pista gratis. La simulación empieza el
--      día 1 de la temporada (la última semana, ×Config.Season.LastWeekMultiplier). Las semanales aún
--      no existen: OPCIONES.pase.xpSemanalSupuesta las simula (XP por semana, el primer día que juega).
--   5. Reglas de pago: nada que se compre con Robux puede dar poder, Ámbar ni tiempo de huevo, ni ser
--      aleatorio sin enseñar las probabilidades.
--   6. Alertas.
--
-- Los RITMOS (lo que hace un jugador por minuto en la Isla) son SUPUESTOS: cámbialos con datos de
-- TelemetryService / Analytics cuando los haya y apunta de dónde salen en references/modelo-economico.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- ===================================== Opciones =====================================

local OPCIONES_BASE = {
	dias = 30, -- días reales simulados (una temporada)
	-- Lo que hace un jugador por minuto jugado en la Isla, por evento de Data/Missions (supuestos).
	ritmos = {
		Kill = 1.0, -- monos derrotados
		Gather = 5, -- recursos recogidos (unidades)
		Craft = 0.15, -- objetos fabricados (~2,5 por día de partida)
		Build = 0.12, -- piezas construidas
		Ability = 2.5, -- habilidades usadas
		Combo = 0.35, -- combos cerrados
		Damage = 300, -- daño hecho a monos
		Egg = 0.03, -- huevos salvados (~1 cada 2 días de partida)
		Revive = 0.05, -- reanimaciones (solo con grupo)
		Alpha = 0.04, -- alfas derrotados
	} :: { [string]: number },
	-- Dunas: resultado medio de una partida (fracciones) y lo que hace un jugador en ella.
	dunas = { victoria = 0.45, empate = 0.1, capturas = 1.5, bajas = 5, minutos = 10 },
	-- Perfiles: días que juega por semana, minutos en la Isla por día de juego (cada día es una partida
	-- nueva desde el día 1), partidas de Dunas por día, probabilidad de ganar (rescate) cuando juega una
	-- partida entera, si juega con amigos y su rol.
	perfiles = {
		casual = {
			nombre = "Casual",
			diasPorSemana = 3,
			minutosIsla = 40,
			partidasDunas = 0,
			ganaRescate = 0,
			amigos = false,
			rol = "Guerrero",
		},
		habitual = {
			nombre = "Habitual",
			diasPorSemana = 5,
			minutosIsla = 60,
			partidasDunas = 1,
			ganaRescate = 0,
			amigos = false,
			rol = "Cazador",
		},
		intenso = {
			nombre = "Intenso",
			diasPorSemana = 7,
			minutosIsla = 150,
			partidasDunas = 3,
			ganaRescate = 0.6,
			amigos = false,
			rol = "Mago",
		},
		amigos = {
			nombre = "Grupo de amigos",
			diasPorSemana = 4,
			minutosIsla = 90,
			partidasDunas = 2,
			ganaRescate = 0.3,
			amigos = true,
			rol = "Medico",
		},
	} :: { [string]: any },
	ordenPerfiles = { "casual", "habitual", "intenso", "amigos" },
	-- Minutos que tarda en caer un jefe desde que aparece (para contar si un jugador llega a él).
	minutosJefe = 3,
	-- Pase: XP de misiones semanales supuesta por semana (0 = aún no hay; con todas cumplidas, 5 × 700
	-- + 700 del plan = 4.200).
	pase = { xpSemanalSupuesta = 0 },
	secciones = { misiones = true, perfiles = true, partida = true, pase = true, pago = true },
}

-- ===================================== Propuesta =====================================
-- Vacía = el juego tal como está. Ejemplos:
--   config = { Match = { AmberPerDay = 15 }, Daily = { GeneralMissions = 3 } },
--   datos = { Missions = { Kills = { target = 40 } }, Upgrades = { StrongHeart = { costs = { 80, 160, 320 } } } },
type Propuesta = { config: any?, datos: any? }

local OPCIONES = OPCIONES_BASE
local PROPUESTA: Propuesta = {}

-- ===================================== Límites =====================================
-- Copia de .claude/skills/economia-retencion/references/limites.md: si cambias uno, cambia los dos.

local LIMITES = {
	-- Minutos de juego en la Isla que pide una misión diaria según su dificultad ("difficulty").
	misionMinutos = { Facil = { 3, 15 }, Media = { 15, 35 }, Dificil = { 35, 90 } },
	-- Al menos una diaria del pool pide esto o más minutos (si no, todas caben en la primera hora).
	diariaMasLarga = 35,
	-- Pase: día en que lo termina el habitual, nivel mínimo del casual, día mínimo del intenso y parte
	-- de la XP que viene de misiones (para el habitual).
	paseHabitualDia = { 20, 26 },
	paseCasualNivel = 12,
	paseIntensoDiaMin = 12,
	paseMisiones = { 0.4, 0.7 },
	-- El habitual gasta al menos esta fracción del Ámbar que gana en el periodo.
	ambarGastado = 0.6,
	-- Día de partida más temprano en que se puede tener el nivel 3 y el 4 de armas de rol y armadura.
	equipoNivel3Dia = 4,
	equipoNivel4Dia = 6,
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

local function claves(tabla: { [string]: any }, orden: ((string, string) -> boolean)?): { string }
	local lista = {}
	for clave in tabla do
		table.insert(lista, clave)
	end
	table.sort(lista, orden)
	return lista
end

-- Media ponderada de f(clave) con los pesos de "pesos".
local function mediaPonderada(pesos: { [string]: number }, f: (string) -> number): number
	local total, suma = 0, 0
	for clave, peso in pesos do
		total += peso
		suma += peso * f(clave)
	end
	return if total > 0 then suma / total else 0
end

-- ¿Juega el día "dia" (1 = lunes) un perfil que juega "porSemana" días? Repartidos por la semana.
local function juega(dia: number, porSemana: number): boolean
	local d = (dia - 1) % 7
	return math.floor((d + 1) * porSemana / 7) > math.floor(d * porSemana / 7)
end

-- ===================================== Informe =====================================

local function main(copia: Instance): string
	local Config = require(copia.Config) :: any
	local Data = copia.Data
	mezclar(Config, PROPUESTA.config or {})
	for nombre, cambios in PROPUESTA.datos or {} do
		local modulo = Data:FindFirstChild(nombre)
		assert(modulo and modulo:IsA("ModuleScript"), `PROPUESTA.datos: no existe Shared.Data.{nombre}`)
		mezclar(require(modulo) :: any, cambios)
	end

	local Missions = require(Data.Missions) :: any
	local Upgrades = require(Data.Upgrades) :: any
	local ArenaGear = require(Data.ArenaGear) :: any
	local Talents = require(Data.Talents) :: any
	local Roles = require(Data.Roles) :: any
	local Recipes = require(Data.Recipes) :: any
	local Monkeys = require(Data.Monkeys) :: any
	local Bosses = require(Data.Bosses) :: any
	local ResourceNodes = require(Data.ResourceNodes) :: any
	local Buildables = require(Data.Buildables) :: any
	local Weapons = require(Data.Weapons) :: any
	local Armor = require(Data.Armor) :: any
	local Items = require(Data.Items) :: any
	local Progression = require(copia.Progression) :: any
	local SeasonsModulo = Data:FindFirstChild("Seasons")
	local Pase = if copia:FindFirstChild("SeasonPass") then require(copia.SeasonPass) :: any else nil
	local temporada = if SeasonsModulo and Pase then (require(SeasonsModulo) :: any)[1] else nil

	local M = Config.Match
	local MINUTOS_DIA = (M.DayLengthSeconds + M.NightLengthSeconds) / 60
	local R = OPCIONES.ritmos

	linea("# Economía y retención")
	linea(
		`{OPCIONES.dias} días reales · un día de partida = {n(MINUTOS_DIA)} min · ritmos supuestos (OPCIONES.ritmos)`
	)
	linea("")

	-- ---------------------------------------------------------------- Misiones
	-- Minutos de Isla que pide una misión con los ritmos (las noches cuentan al acabar cada día de partida).
	local function minutosMision(mision: any): number
		if mision.event == "Night" then
			return mision.target * MINUTOS_DIA
		elseif mision.event == "ReachDay" then
			return (mision.target - 1) * MINUTOS_DIA
		end
		local ritmo = R[mision.event]
		if not ritmo or ritmo <= 0 then
			return math.huge
		end
		return mision.target / ritmo
	end

	local function claseMinutos(minutos: number): string
		for _, clase in { "Facil", "Media", "Dificil" } do
			if minutos <= LIMITES.misionMinutos[clase][2] then
				return clase
			end
		end
		return "MuyDificil"
	end

	local generales, deRol = {}, {} :: { [string]: { string } }
	for id, mision in Missions do
		if mision.role then
			deRol[mision.role] = deRol[mision.role] or {}
			table.insert(deRol[mision.role], id)
		elseif not mision.weekly then
			table.insert(generales, id)
		end
	end
	table.sort(generales)

	if OPCIONES.secciones.misiones then
		linea("## 1. Misiones")
		linea("| Misión | Evento | Objetivo | Minutos | Dificultad real | Marcada |")
		linea("|---|---|---|---|---|---|")
		local masLarga = 0
		for _, id in claves(Missions) do
			local mision = Missions[id]
			local minutos = minutosMision(mision)
			if not mision.weekly then
				masLarga = math.max(masLarga, minutos)
			end
			local clase = claseMinutos(minutos)
			linea(
				`| {mision.icon} {id}{if mision.role then ` ({mision.role})` else ""} | {mision.event} | {mision.target} | {n(
					minutos
				)} | {clase} | {mision.difficulty or "-"} |`
			)
			if mision.difficulty and not mision.weekly then
				local rango = LIMITES.misionMinutos[mision.difficulty]
				if rango and (minutos < rango[1] or minutos > rango[2]) then
					alerta(
						`Misión {id}: marcada {mision.difficulty} pero pide {n(minutos)} min (rango {rango[1]}–{rango[2]})`
					)
				end
			end
		end
		if masLarga < LIMITES.diariaMasLarga then
			alerta(
				`Misiones diarias: la más larga pide {n(masLarga)} min; todas se cumplen en la primera hora de una partida (mínimo {LIMITES.diariaMasLarga} para la más larga)`
			)
		end
		linea("")
	end

	-- ---------------------------------------------------------------- Perfiles
	local hatchHoras = Config.Egg.HatchHours
	local pesosIsla = Config.Pets.RarityWeights
	local horasHuevoIsla = mediaPonderada(pesosIsla, function(r)
		return hatchHoras[r]
	end)
	local descarteIsla = mediaPonderada(pesosIsla, function(r)
		return Config.Egg.DiscardAmber[r]
	end)
	local rescateSegundos = 0
	do
		local total = 0
		for _, opcion in Config.Egg.RescueRoll do
			total += opcion.weight
		end
		for _, opcion in Config.Egg.RescueRoll do
			-- La eclosión inmediata cuenta como el tiempo que le quede (aprox.: media de un huevo).
			local segundos = if opcion.hatch then horasHuevoIsla * 3600 * 0.5 else opcion.hours * 3600
			rescateSegundos += segundos * opcion.weight / total
		end
	end

	local costesMejoras = {}
	for _, mejora in Upgrades do
		for _, coste in mejora.costs do
			table.insert(costesMejoras, coste)
		end
	end
	table.sort(costesMejoras)
	local totalMejoras = 0
	for _, coste in costesMejoras do
		totalMejoras += coste
	end

	local puntosRol = {}
	for roleId, talentos in Talents do
		local puntos = 0
		for _, talento in talentos do
			puntos += talento.maxRank
		end
		puntosRol[roleId] = puntos
	end
	-- XP de rol para tener todos los puntos de talento del rol (un punto por nivel sobre el 1).
	local function xpParaTalentos(roleId: string): number
		local xp = 0
		while Progression.level(xp) - 1 < (puntosRol[roleId] or 0) do
			xp += 10
		end
		return xp
	end

	-- Una partida de "minutos" en la Isla (empieza en el día 1).
	local function partida(minutos: number, perfil: any)
		local dias = math.floor(minutos / MINUTOS_DIA)
		local jefes = 0
		for indice = 1, #M.BossRotation do
			local diaJefe = indice * M.BossIntervalDays
			if minutos >= (diaJefe - 1) * MINUTOS_DIA + OPCIONES.minutosJefe then
				jefes += 1
			end
		end
		local completa = minutos >= M.BeaconUnlockDay * MINUTOS_DIA
		local rescate = if completa then perfil.ganaRescate else 0
		local muertes = R.Kill * minutos
		local huevos = R.Egg * minutos
		local reanima = if perfil.amigos then R.Revive * minutos else 0
		local ambar = M.AmberPerDay * dias
			+ M.AmberPerKill * muertes
			+ M.AmberPerRevive * reanima
			+ M.AmberPerBoss * jefes
			+ M.AmberPerEgg * huevos
			+ M.AmberForRescue * rescate
		local xpRol = Config.Data.RoleXpPerDay * dias + Config.Data.RoleXpPerKill * muertes
		return {
			dias = dias,
			jefes = jefes,
			rescate = rescate,
			huevos = huevos,
			ambar = ambar,
			xpRol = xpRol,
		}
	end

	local function dunas(partidas: number): number
		if partidas <= 0 then
			return 0
		end
		local A = Config.Arena.Amber
		local D = OPCIONES.dunas
		local porPartida = D.victoria * A.Win
			+ D.empate * A.Tie
			+ (1 - D.victoria - D.empate) * A.Loss
			+ D.capturas * A.PerCapture
			+ math.min(D.bajas * A.PerKill, A.MaxFromKills)
		return math.min(porPartida * partidas, A.DailyCap)
	end

	-- Misiones del día cumplidas (valor esperado) con "minutos" de Isla.
	local function misionesDelDia(minutos: number, rol: string)
		local cumplidas, ambar, huevo, xp = 0, 0, 0, 0
		local function sumar(lista: { string }, cuantas: number)
			if #lista == 0 or cuantas <= 0 then
				return
			end
			local fraccion, a, h, x = 0, 0, 0, 0
			for _, id in lista do
				local mision = Missions[id]
				if minutosMision(mision) <= minutos then
					fraccion += 1
					a += mision.reward.amber or 0
					h += mision.reward.eggSeconds or 0
					x += mision.reward.xp or 0
				end
			end
			cumplidas += cuantas * fraccion / #lista
			ambar += cuantas * a / #lista
			huevo += cuantas * h / #lista
			xp += cuantas * x / #lista
		end
		sumar(generales, Config.Daily.GeneralMissions)
		sumar(deRol[rol] or {}, 1)
		return cumplidas, Config.Daily.GeneralMissions + 1, ambar, huevo, xp
	end

	-- XP de pase de las partidas de un día (Isla y Dunas), antes del tope y del extra de amigos.
	local function xpPartidas(p: any, partidasDunas: number): (number, number)
		local S = Config.Season
		local isla = p.dias * S.IslandXp.PerDay
			+ p.jefes * S.IslandXp.PerBoss
			+ p.huevos * S.IslandXp.PerEgg
			+ p.rescate * S.IslandXp.Rescue
		local D = OPCIONES.dunas
		local porDunas = D.victoria * S.ArenaXp.Win
			+ D.empate * S.ArenaXp.Tie
			+ (1 - D.victoria - D.empate) * S.ArenaXp.Loss
			+ D.capturas * S.ArenaXp.PerCapture
		return isla, porDunas * partidasDunas
	end

	local function simular(perfil: any)
		local r = {
			diasActivos = 0,
			ambar = { Partidas = 0, Dunas = 0, Calendario = 0, Misiones = 0, Descartes = 0, Pase = 0 },
			-- Pase: XP ganada, por fuente, nivel ganado al final de cada día y día en que llega al último.
			pase = {
				xp = 0,
				fuentes = { Isla = 0, Dunas = 0, Misiones = 0, Semanales = 0, Amigos = 0, Doble = 0 },
				recortada = 0,
				nivelDia = {} :: { number },
				terminaDia = nil :: number?,
				huevoSegundos = 0,
			},
			gastado = 0,
			saldo = 0,
			mejorasDia = nil :: number?,
			equipoDunasDia = nil :: number?,
			huevosEclosionados = 0,
			huevosDescartados = 0,
			misiones = 0,
			misionesPosibles = 0,
			xpRol = 0,
			talentosDia = nil :: number?,
		}
		local pendientes = table.clone(costesMejoras)
		local costeDunas = 0
		if perfil.partidasDunas > 0 then
			for _, item in ArenaGear.items do
				if item.role == perfil.rol and item.order == 1 then
					costeDunas += item.cost
				end
			end
		end
		local xpTalentos = xpParaTalentos(perfil.rol)
		local paso = 1 -- calendario
		-- Nido: segundos totales del huevo, transcurridos, bonos; mochila (cuántos esperan).
		local nido: any = nil
		local mochila = 0
		local acumuladoHuevos = 0
		local function nuevoHuevo(horas: number)
			if not nido then
				nido = { total = horas * 3600, pasado = 0, juego = 0, gratis = 0 }
			elseif mochila < Config.Egg.BagSize then
				mochila += 1
			else
				r.huevosDescartados += 1
				r.ambar.Descartes += descarteIsla
			end
		end
		local function tiempoJuego(segundos: number)
			if nido then
				local hueco = math.max(0, nido.total * Config.Egg.PlayCapFraction - nido.juego)
				nido.juego += math.min(segundos, hueco)
			end
		end
		local function listo(): boolean
			return nido ~= nil and nido.pasado + nido.juego + nido.gratis >= nido.total
		end

		for dia = 1, OPCIONES.dias do
			if nido then
				nido.pasado += 24 * 3600
			end
			if Pase then
				-- Se apunta al terminar el día (antes de jugar, el del día anterior).
				r.pase.nivelDia[dia - 1] = Pase.earnedLevel(r.pase.xp)
			end
			if juega(dia, perfil.diasPorSemana) then
				r.diasActivos += 1
				-- Lobby: calendario, eclosión.
				local premio = Config.Daily.Calendar[paso]
				r.ambar.Calendario += premio.amber or 0
				if premio.eggSeconds then
					if nido then
						nido.gratis += premio.eggSeconds
					else
						r.ambar.Calendario += premio.eggSeconds / 3600 * Config.Daily.AmberPerUnusedEggHour
					end
				end
				if premio.egg then
					nuevoHuevo(mediaPonderada(premio.egg, function(rr)
						return hatchHoras[rr]
					end))
				end
				paso = paso % #Config.Daily.Calendar + 1
				if listo() then
					r.huevosEclosionados += 1
					nido = nil
					if mochila > 0 then
						mochila -= 1
						nuevoHuevo(horasHuevoIsla)
					end
				end
				-- Isla.
				local p = partida(perfil.minutosIsla, perfil)
				r.ambar.Partidas += p.ambar
				r.xpRol += p.xpRol
				tiempoJuego(p.dias * Config.Egg.SecondsPerDaySurvived)
				if p.rescate > 0 and nido then
					tiempoJuego(rescateSegundos * p.rescate)
				end
				acumuladoHuevos += p.huevos
				while acumuladoHuevos >= 1 do
					acumuladoHuevos -= 1
					nuevoHuevo(horasHuevoIsla)
				end
				local cumplidas, posibles, ambarMisiones, huevoMisiones, xpMisiones =
					misionesDelDia(perfil.minutosIsla, perfil.rol)
				r.misiones += cumplidas
				r.misionesPosibles += posibles
				r.ambar.Misiones += ambarMisiones
				if nido then
					tiempoJuego(huevoMisiones)
				else
					r.ambar.Misiones += huevoMisiones / 3600 * Config.Daily.AmberPerUnusedEggHour
				end
				-- Dunas.
				r.ambar.Dunas += dunas(perfil.partidasDunas)
				-- Pase de temporada: XP del día y premios gratis de los niveles ganados (los no cosméticos
				-- solo con nivel ganado; aquí todo es ganado jugando).
				if temporada and dia <= Config.Season.Days then
					local S = Config.Season
					local P = r.pase
					local mult = if dia > S.Days - S.LastWeekDays then S.LastWeekMultiplier else 1
					local isla, deDunas = xpPartidas(p, perfil.partidasDunas)
					local partidas = math.min(isla + deDunas, S.DailyMatchXpCap)
					P.recortada += isla + deDunas - partidas
					local reparto = if isla + deDunas > 0 then partidas / (isla + deDunas) else 0
					local amigos = if perfil.amigos then partidas * S.FriendsBonus else 0
					local semanal = 0
					local semana = (dia - 1) // 7
					if OPCIONES.pase.xpSemanalSupuesta > 0 and P.ultimaSemana ~= semana then
						P.ultimaSemana = semana
						semanal = OPCIONES.pase.xpSemanalSupuesta
					end
					local base = partidas + amigos + xpMisiones + semanal
					P.fuentes.Isla += isla * reparto
					P.fuentes.Dunas += deDunas * reparto
					P.fuentes.Misiones += xpMisiones
					P.fuentes.Semanales += semanal
					P.fuentes.Amigos += amigos
					P.fuentes.Doble += base * (mult - 1)
					local antes = Pase.earnedLevel(P.xp)
					local buclesAntes = Pase.loopsEarned(P.xp)
					P.xp += base * mult
					local despues = Pase.earnedLevel(P.xp)
					for nivel = antes + 1, despues do
						local gratis = temporada.levels[nivel] and temporada.levels[nivel].free
						if gratis then
							r.ambar.Pase += gratis.amber or 0
							if gratis.eggSeconds then
								P.huevoSegundos += gratis.eggSeconds
								if nido then
									tiempoJuego(gratis.eggSeconds)
								else
									r.ambar.Pase += gratis.eggSeconds / 3600 * Config.Daily.AmberPerUnusedEggHour
								end
							end
							if gratis.egg then
								nuevoHuevo(mediaPonderada(gratis.egg, function(rr)
									return hatchHoras[rr]
								end))
							end
						end
					end
					for bucle = buclesAntes + 1, Pase.loopsEarned(P.xp) do
						local enBucle = Pase.loopReward(bucle)
						r.ambar.Pase += enBucle.amber or 0
						if enBucle.eggSeconds then
							if nido then
								tiempoJuego(enBucle.eggSeconds)
							else
								r.ambar.Pase += enBucle.eggSeconds / 3600 * Config.Daily.AmberPerUnusedEggHour
							end
						end
					end
					if despues >= S.Levels and not P.terminaDia then
						P.terminaDia = dia
					end
				end
				-- Gastos: mejoras de la más barata a la más cara; luego el equipo de Dunas de su rol.
				local ganado = 0
				for _, valor in r.ambar do
					ganado += valor
				end
				r.saldo = ganado - r.gastado
				while #pendientes > 0 and r.saldo >= pendientes[1] do
					r.gastado += pendientes[1]
					r.saldo -= pendientes[1]
					table.remove(pendientes, 1)
				end
				if #pendientes == 0 and not r.mejorasDia then
					r.mejorasDia = dia
				end
				if #pendientes == 0 and costeDunas > 0 and not r.equipoDunasDia and r.saldo >= costeDunas then
					r.gastado += costeDunas
					r.saldo -= costeDunas
					r.equipoDunasDia = dia
				end
				if not r.talentosDia and r.xpRol >= xpTalentos then
					r.talentosDia = dia
				end
			end
		end
		if Pase then
			r.pase.nivelDia[OPCIONES.dias] = Pase.earnedLevel(r.pase.xp)
		end
		return r
	end

	-- Todos los perfiles se simulan aunque su tabla no se enseñe (el pase los usa).
	local resultados = {}
	for _, clave in OPCIONES.ordenPerfiles do
		local r = simular(OPCIONES.perfiles[clave])
		local ganado = 0
		for _, valor in r.ambar do
			ganado += valor
		end
		r.ganado = ganado
		resultados[clave] = r
	end
	if OPCIONES.secciones.perfiles then
		linea("## 2. Perfiles de jugador")
		linea(
			`Mejoras de la tienda: {#costesMejoras} rangos, {totalMejoras} Ámbar en total. Huevo de la Isla: {n(
				horasHuevoIsla
			)} h de media.`
		)
		linea("")
		linea(
			"| Perfil | Días activos | Ámbar: partidas · Dunas · calendario · misiones · descartes · pase | Ganado | Gastado | Sin usar | Mejoras completas | Huevos eclosionados (descartados) | Misiones cumplidas | Talentos llenos |"
		)
		linea("|---|---|---|---|---|---|---|---|---|---|")
		for _, clave in OPCIONES.ordenPerfiles do
			local perfil = OPCIONES.perfiles[clave]
			local r = resultados[clave]
			local ganado = r.ganado
			local a = r.ambar
			linea(
				`| {perfil.nombre} ({perfil.diasPorSemana}/sem, {perfil.minutosIsla} min) | {r.diasActivos} | {n(
					a.Partidas,
					0
				)} · {n(a.Dunas, 0)} · {n(a.Calendario, 0)} · {n(a.Misiones, 0)} · {n(a.Descartes, 0)} · {n(
					a.Pase,
					0
				)} | {n(ganado, 0)} | {n(r.gastado, 0)} | {n(r.saldo, 0)} | {if r.mejorasDia
					then `día {r.mejorasDia}`
					else "no"} | {r.huevosEclosionados} ({r.huevosDescartados}) | {pct(
					if r.misionesPosibles > 0 then r.misiones / r.misionesPosibles else 0
				)} | {if r.talentosDia then `día {r.talentosDia} ({perfil.rol})` else "no"} |`
			)
		end
		local habitual = resultados.habitual
		if habitual and habitual.ganado > 0 then
			local gastado = habitual.gastado / habitual.ganado
			if gastado < LIMITES.ambarGastado then
				alerta(
					`Ámbar: el habitual solo gasta el {pct(gastado)} de lo que gana en {OPCIONES.dias} días (mínimo {pct(
						LIMITES.ambarGastado
					)}): falta un sumidero`
				)
			end
		end
		linea("")
	end

	-- ---------------------------------------------------------------- Partida
	if OPCIONES.secciones.partida then
		linea("## 3. Partida: cuándo se puede tener cada cosa")
		-- Día de partida más temprano en que se consigue cada ítem.
		local diaItem: { [string]: number } = {}
		local function poner(itemId: string, dia: number)
			if diaItem[itemId] == nil or dia < diaItem[itemId] then
				diaItem[itemId] = dia
			end
		end
		for _, nodo in ResourceNodes do
			poner(nodo.itemId, 1)
			if nodo.extra then
				poner(nodo.extra.itemId, 1)
			end
		end
		for _, mono in Monkeys do
			local dia = if mono.groups > 0 then 1 else math.huge
			for _, entrada in Config.Siege.SpeciesByDay do
				if Monkeys[entrada.species] == mono then
					dia = math.min(dia, entrada.day)
				end
			end
			for _, botin in mono.loot do
				poner(botin.itemId, dia)
			end
		end
		for indice, bossId in M.BossRotation do
			local jefe = Bosses[bossId]
			if jefe and jefe.lootItemId then
				poner(jefe.lootItemId, indice * M.BossIntervalDays)
			end
		end
		for _, botin in Config.Supply.Loot do
			poner(botin.itemId, 1)
		end
		-- Estaciones construibles (la forja): el día de sus materiales.
		local diaEstacion: { [string]: number } = { Workbench = 1, Campfire = 1 }
		local function diaCoste(coste: { any }): number
			local dia = 1
			for _, c in coste do
				dia = math.max(dia, diaItem[c.itemId] or math.huge)
			end
			return dia
		end
		-- Lo que sale de alguna receta (lo demás que "upgrades" sustituye, como el arma inicial del rol, ya
		-- se tiene desde el día 1).
		local fabricado: { [string]: boolean } = {}
		for _, receta in Recipes do
			local salida = receta.weaponId or receta.armorId
			if salida then
				fabricado[salida] = true
			end
		end
		-- Recetas: hasta que no cambie nada (las mejoras dependen de lo anterior de la cadena).
		local diaReceta: { [string]: number } = {}
		local diaSalida: { [string]: number } = {}
		for _ = 1, 10 do
			for _, construible in Buildables do
				if construible.station then
					diaEstacion[construible.station] =
						math.min(diaEstacion[construible.station] or math.huge, diaCoste(construible.cost))
				end
			end
			for id, receta in Recipes do
				local dia = math.max(diaCoste(receta.cost), diaEstacion[receta.station] or 1)
				if receta.upgrades and fabricado[receta.upgrades] then
					dia = math.max(dia, diaSalida[receta.upgrades] or math.huge)
				end
				diaReceta[id] = dia
				local salida = receta.weaponId or receta.armorId or receta.itemId or receta.offhand
				if salida then
					diaSalida[salida] = math.min(diaSalida[salida] or math.huge, dia)
					if receta.itemId then
						poner(receta.itemId, dia)
					end
				end
			end
		end
		-- Cadenas de mejora: arma de cada rol y armadura.
		local function cadena(inicio: (any) -> boolean): { string }
			local lista = {}
			local actual: string? = nil
			for id, receta in Recipes do
				if inicio(receta) and (receta.upgrades == nil or not fabricado[receta.upgrades]) then
					actual = id
				end
			end
			while actual do
				table.insert(lista, actual)
				local salida = Recipes[actual].weaponId or Recipes[actual].armorId
				local siguiente = nil
				for id, receta in Recipes do
					if receta.upgrades == salida then
						siguiente = id
					end
				end
				actual = siguiente
			end
			return lista
		end
		local function dia(valor: number): string
			return if valor == math.huge then "nunca" else tostring(valor)
		end
		linea("Día de partida más temprano posible (sin contar la suerte del botín). Nivel 1 = con lo que empiezas.")
		linea("")
		linea("| Equipo | Nivel 2 | Nivel 3 | Nivel 4 |")
		linea("|---|---|---|---|")
		local filas = {}
		for _, roleId in
			claves(Roles, function(a, b)
				return Roles[a].order < Roles[b].order
			end)
		do
			table.insert(filas, {
				nombre = `{Roles[roleId].icon} Arma de {roleId}`,
				lista = cadena(function(receta)
					return receta.role == roleId and receta.weaponId ~= nil
				end),
			})
		end
		table.insert(filas, {
			nombre = "🛡️ Armadura",
			lista = cadena(function(receta)
				return receta.armorId ~= nil and receta.role == nil
			end),
			armadura = true,
		})
		for _, fila in filas do
			-- Las armas de rol empiezan en el nivel 1 (la del rol); la primera receta es el nivel 2. La
			-- armadura empieza sin nada: su primera receta es el nivel 1.
			local desplazamiento = if fila.armadura then 0 else 1
			local celdas = { "-", "-", "-" }
			for indice, recetaId in fila.lista do
				local nivel = indice + desplazamiento
				local receta = Recipes[recetaId]
				local nombre = if receta.weaponId and Weapons[receta.weaponId]
					then Weapons[receta.weaponId].name
					elseif receta.armorId and Armor[receta.armorId] then Armor[receta.armorId].name
					else recetaId
				if nivel >= 2 and nivel <= 4 then
					celdas[nivel - 1] = `{nombre} (día {dia(diaReceta[recetaId])})`
				end
				if nivel == 3 and diaReceta[recetaId] < LIMITES.equipoNivel3Dia then
					alerta(
						`Partida: {fila.nombre} nivel 3 ({nombre}) se puede tener el día {dia(diaReceta[recetaId])} (mínimo {LIMITES.equipoNivel3Dia})`
					)
				elseif nivel == 4 and diaReceta[recetaId] < LIMITES.equipoNivel4Dia then
					alerta(
						`Partida: {fila.nombre} nivel 4 ({nombre}) se puede tener el día {dia(diaReceta[recetaId])} (mínimo {LIMITES.equipoNivel4Dia})`
					)
				end
			end
			linea(`| {fila.nombre} | {celdas[1]} | {celdas[2]} | {celdas[3]} |`)
		end
		linea("")
		-- Lo que trae de nuevo cada día de la partida.
		linea("| Día | Novedades |")
		linea("|---|---|")
		for d = 1, M.BeaconUnlockDay do
			local cosas = {}
			for indice, bossId in M.BossRotation do
				if indice * M.BossIntervalDays == d and Bosses[bossId] then
					local jefe = Bosses[bossId]
					local botin = Items[jefe.lootItemId]
					table.insert(cosas, `jefe {jefe.name} ({if botin then botin.name else jefe.lootItemId})`)
				end
			end
			for _, entrada in Config.Siege.SpeciesByDay do
				if entrada.day == d and d > 1 then
					table.insert(cosas, `asedio con {entrada.species}`)
				end
			end
			local recetasNuevas = 0
			for _, valor in diaReceta do
				if valor == d then
					recetasNuevas += 1
				end
			end
			if recetasNuevas > 0 then
				table.insert(cosas, `{recetasNuevas} recetas`)
			end
			if d == M.BeaconUnlockDay then
				table.insert(cosas, "baliza")
			end
			linea(`| {d} | {if #cosas > 0 then table.concat(cosas, " · ") else "—"} |`)
		end
		-- Botín de jefe que no pide ninguna receta ni construible.
		local usados: { [string]: boolean } = {}
		for _, receta in Recipes do
			for _, c in receta.cost do
				usados[c.itemId] = true
			end
		end
		for _, construible in Buildables do
			for _, c in construible.cost do
				usados[c.itemId] = true
			end
		end
		for _, bossId in M.BossRotation do
			local jefe = Bosses[bossId]
			if jefe and jefe.lootItemId and not usados[jefe.lootItemId] then
				linea(`- El botín de {jefe.name} ({jefe.lootItemId}) no lo pide ninguna receta ni construible.`)
			end
		end
		linea("")
	end

	-- ---------------------------------------------------------------- Pase
	if OPCIONES.secciones.pase then
		linea("## 4. Pase de temporada")
		if not temporada then
			linea("Sin pase todavía (Data/Seasons o Shared/SeasonPass no existen).")
		else
			local S = Config.Season
			-- Lo que da la pista gratis y cuántos cosméticos hay en cada pista.
			local ambarGratis, huevoGratis, cosmeticosGratis, cosmeticosPremium = 0, 0, 0, 0
			for _, entrada in temporada.levels do
				local gratis = entrada.free or {}
				ambarGratis += gratis.amber or 0
				huevoGratis += gratis.eggSeconds or 0
				cosmeticosGratis += if gratis.cosmetic then 1 else 0
				cosmeticosPremium += if entrada.premium and entrada.premium.cosmetic then 1 else 0
			end
			linea(
				`«{temporada.name}»: {S.Days} días, {S.Levels} niveles × {S.LevelXp} XP ({S.Levels * S.LevelXp} en total), ×{S.LastWeekMultiplier} los últimos {S.LastWeekDays} días, tope de partidas {S.DailyMatchXpCap}/día, amigos +{pct(
					S.FriendsBonus
				)}. Pista gratis: {ambarGratis} Ámbar, {n(huevoGratis / 3600)} h de huevo, {cosmeticosGratis} cosméticos; premium: {cosmeticosPremium} cosméticos. Semanales supuestas: {OPCIONES.pase.xpSemanalSupuesta} XP/semana.`
			)
			linea("")
			linea(
				"| Perfil | Nivel día 7 · 14 · 21 · 30 | Último nivel | XP: Isla · Dunas · misiones · semanales · amigos · ×2 | Misiones (con semanales) | XP sobre el tope |"
			)
			linea("|---|---|---|---|---|---|")
			for _, clave in OPCIONES.ordenPerfiles do
				local perfil = OPCIONES.perfiles[clave]
				local P = resultados[clave].pase
				local f = P.fuentes
				local nivel = function(d: number): string
					return tostring(P.nivelDia[math.min(d, OPCIONES.dias)] or 0)
				end
				-- El ×2 dobla todas las fuentes por igual: la parte de las misiones no cambia.
				local sinDoble = f.Isla + f.Dunas + f.Misiones + f.Semanales + f.Amigos
				local misiones = if sinDoble > 0 then (f.Misiones + f.Semanales) / sinDoble else 0
				P.parteMisiones = misiones
				linea(
					`| {perfil.nombre} | {nivel(7)} · {nivel(14)} · {nivel(21)} · {nivel(S.Days)} | {if P.terminaDia
						then `día {P.terminaDia}`
						else "no"} | {n(f.Isla, 0)} · {n(f.Dunas, 0)} · {n(f.Misiones, 0)} · {n(f.Semanales, 0)} · {n(
						f.Amigos,
						0
					)} · {n(f.Doble, 0)} | {pct(misiones)} | {n(P.recortada, 0)} |`
				)
			end
			local habitual = resultados.habitual and resultados.habitual.pase
			if habitual then
				local rango = LIMITES.paseHabitualDia
				if not habitual.terminaDia or habitual.terminaDia < rango[1] or habitual.terminaDia > rango[2] then
					alerta(
						`Pase: el habitual {if habitual.terminaDia
							then `gana el último nivel el día {habitual.terminaDia}`
							else `no lo termina (nivel {habitual.nivelDia[S.Days] or 0})`} (meta: entre el día {rango[1]} y el {rango[2]})`
					)
				end
				local partes = LIMITES.paseMisiones
				if habitual.parteMisiones < partes[1] or habitual.parteMisiones > partes[2] then
					alerta(
						`Pase: las misiones dan el {pct(habitual.parteMisiones)} de la XP del habitual (meta: {pct(
							partes[1]
						)}–{pct(partes[2])})`
					)
				end
			end
			local casual = resultados.casual and resultados.casual.pase
			if casual and (casual.nivelDia[S.Days] or 0) < LIMITES.paseCasualNivel then
				alerta(
					`Pase: el casual llega al nivel {casual.nivelDia[S.Days] or 0} (mínimo {LIMITES.paseCasualNivel})`
				)
			end
			local intenso = resultados.intenso and resultados.intenso.pase
			if intenso and intenso.terminaDia and intenso.terminaDia < LIMITES.paseIntensoDiaMin then
				alerta(`Pase: el intenso lo termina el día {intenso.terminaDia} (mínimo {LIMITES.paseIntensoDiaMin})`)
			end
			-- Regla de pago: lo no cosmético de la pista gratis solo con nivel ganado (Shared/SeasonPass).
			local premioGratis = nil
			for nivel, entrada in temporada.levels do
				if entrada.free and not Pase.isCosmeticOnly(entrada.free) then
					premioGratis = nivel
					break
				end
			end
			if premioGratis then
				local estado = Pase.normalize({ id = temporada.id, xp = 0, bought = S.Levels }, temporada.id)
				if Pase.unlocked(temporada, estado, premioGratis, "Free") then
					alerta(`Pago: el nivel {premioGratis} gratis (no cosmético) se desbloquea con niveles comprados`)
				end
			end
		end
		linea("")
	end

	-- ---------------------------------------------------------------- Pago
	if OPCIONES.secciones.pago then
		linea("## 5. Reglas de pago")
		-- Todo lo que se vende con Robux en Data y Config: entradas con gamePassId o productId distinto de 0
		-- (en ellas o en su "source", como los cosméticos de Data/Cosmetics).
		local COSMETICOS = {
			Trail = true,
			Title = true,
			Aura = true,
			Outfit = true,
			WeaponSkin = true,
			PetSkin = true,
			Emote = true,
			Frame = true,
		}
		local ventas = {}
		local function revisar(tabla: any, ruta: string, visto: { [any]: boolean })
			if typeof(tabla) ~= "table" or visto[tabla] then
				return
			end
			visto[tabla] = true
			local fuente = if typeof(tabla.source) == "table" then tabla.source else tabla
			local pase = fuente.gamePassId
			local producto = fuente.productId
			if (typeof(pase) == "number" and pase ~= 0) or (typeof(producto) == "number" and producto ~= 0) then
				table.insert(ventas, { ruta = ruta, entrada = tabla })
			end
			for clave, valor in tabla do
				if typeof(valor) == "table" and clave ~= "source" then
					revisar(valor, `{ruta}.{tostring(clave)}`, visto)
				end
			end
		end
		local visto = {}
		revisar(Config, "Config", visto)
		for _, modulo in Data:GetChildren() do
			if modulo:IsA("ModuleScript") then
				revisar(require(modulo), `Data.{modulo.Name}`, visto)
			end
		end
		linea("| Se vende | Qué da | Estado |")
		linea("|---|---|---|")
		for _, venta in ventas do
			local e = venta.entrada
			local estado
			local que = e.kind or e.grants or "?"
			if e.kind and COSMETICOS[e.kind] then
				estado = "✅ cosmético"
			elseif e.grants == "Premium" or e.grants == "Levels" or e.grants == "Cosmetic" then
				estado = "✅ pase o cosmético"
			else
				estado = "❌ no es cosmético"
				alerta(`Pago: {venta.ruta} se vende con Robux y no es cosmético ({que})`)
			end
			local premio = e.reward
			if typeof(premio) == "table" then
				for _, clave in { "amber", "eggSeconds", "egg", "items" } do
					if premio[clave] ~= nil then
						estado = `❌ da {clave}`
						alerta(`Pago: {venta.ruta} da {clave} por Robux (solo cosméticos)`)
					end
				end
				if premio.egg then
					alerta(
						`Pago: {venta.ruta} es aleatorio de pago: probabilidades a la vista y PolicyService.ArePaidRandomItemsRestricted`
					)
				end
			end
			linea(`| {venta.ruta} | {que} | {estado} |`)
		end
		if #ventas == 0 then
			linea("| — | Nada a la venta con id | ✅ |")
		end
		-- Premios premium del pase: solo cosméticos.
		if SeasonsModulo then
			local Seasons = require(SeasonsModulo) :: any
			for _, otra in Seasons do
				if typeof(otra) == "table" and typeof(otra.levels) == "table" then
					local seasonId = otra.id
					for nivel, datos in otra.levels do
						local premio = datos.premium
						if typeof(premio) == "table" then
							for clave in premio do
								if clave ~= "cosmetic" then
									alerta(
										`Pago: {seasonId} nivel {nivel} premium da "{clave}" (la premium solo da cosméticos)`
									)
								end
							end
						end
					end
				end
			end
		end
		linea("")
	end

	linea("## 6. Alertas")
	if #alertas == 0 then
		linea("✅ Todo dentro de los límites.")
	else
		for _, texto in alertas do
			linea(texto)
		end
	end
	return table.concat(lineas, "\n")
end

local Economia = {}

-- Informe con "opciones" (cambios sobre OPCIONES_BASE) y "propuesta" (ver PROPUESTA). Los dos opcionales.
function Economia.informe(opciones: any?, propuesta: Propuesta?): string
	OPCIONES = copiaProfunda(OPCIONES_BASE)
	mezclar(OPCIONES, opciones or {})
	PROPUESTA = propuesta or {}
	lineas = {}
	alertas = {}
	local copia = ReplicatedStorage:WaitForChild("Shared"):Clone()
	copia.Name = "_EconomiaShared"
	copia.Parent = ServerStorage
	local ok, resultado = pcall(main, copia)
	copia:Destroy()
	if not ok then
		error(resultado, 0)
	end
	return resultado
end

return Economia
