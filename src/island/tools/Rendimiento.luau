-- Calculadora del presupuesto de piezas (Fase 16): cuenta las piezas de cada modelo del juego, antes y después de
-- fusionarlas (Shared/VoxelMerge), contra Config.Budgets. La usa la skill modelos-3d-roblox
-- (.claude/skills/modelos-3d-roblox, §6). Se ejecuta en Studio, en modo edición (sin pulsar Play), desde la barra
-- de comandos o con el MCP, y devuelve un informe en tablas:
--
--   local m = game.ServerStorage.Tools.Rendimiento:Clone() -- copia: así no usa la versión vieja en caché
--   print(require(m).informe()); m:Destroy()
--
-- No cambia nada del repo ni del place: cada informe lee una copia nueva de ReplicatedStorage.Shared, y "tras
-- fusionar" se mide sobre un clon del modelo (VoxelMerge con force = true, aunque Config.Budgets.Merge sea false).
-- Argumentos (opcionales):
--   informe(opciones, propuesta)
-- "opciones" cambia OPCIONES_BASE ({ filtro = "Lab", secciones = { monos = false } }); "propuesta" cambia datos
-- solo para ese informe (números de Config, como Budgets, o cualquier módulo de Data).
-- Límite: los módulos que se piden por ReplicatedStorage.Shared (WeaponTools, ArmorModels, LabWeaponModels…) leen
-- esa carpeta y no la copia; si un cambio suyo no se ve, vuelve a abrir el place (es la caché de require).
--
-- Lo que mide (cada fila: piezas ahora · piezas tras fusionar · presupuesto · piezas "Detalle" que quedan):
--   1. Armas de la forja (WeaponTools) y los aspectos de arma de rol y de familia.
--   2. Armaduras por rango y rol, y los trajes (ArmorModels, sobre un R15 falso hecho de Parts).
--   3. Mascotas y sus skins (PetModels): total y piezas que se mueven cada fotograma. Las piezas que se mueven
--      igual (misma "firma" de articulación) se funden entre sí; las que no, no.
--   4. Monturas (MountModels): fusión por hueso.
--   5. Construibles (BuildModels) y estructuras de la parcela (PlotModels) a sus tres niveles.
--   6. Armas del Laboratorio (LabWeaponModels y LabWeaponSkins): arma × bando × aspecto.
--   7. Monos y jefes (island/server/Monkeys/MonkeyModels): piezas del modelo final, ya unido con UnionAsync.
--   8. Totales por escena (pendiente R5/R6).
--   9. Pico de efectos por calidad (pendiente R6).
--   10. Alertas: lo que, tras fusionar, pasa del presupuesto.
-- Pendiente: los modelos de ViewportFrame (RewardModels) y los nodos del mapa (MapBuilder) se miden en R3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- ===================================== Opciones =====================================

local OPCIONES_BASE = {
	-- Solo los modelos cuyo id contiene este texto (sin distinguir mayúsculas); nil = todos.
	filtro = nil :: string?,
	secciones = {
		armas = true,
		armaduras = true,
		mascotas = true,
		monturas = true,
		construibles = true,
		laboratorio = true,
		monos = true,
		escenas = true,
		efectos = true,
	},
}

-- ===================================== Propuesta =====================================
-- Vacía = el juego tal como está. Ejemplo:
--   config = { Budgets = { Models = { PetTotal = 200 } } },
--   datos = { Pets = { Tucan = { size = 2 } } },
type Propuesta = { config: any?, datos: any? }

-- Los de la llamada en curso (Rendimiento.informe).
local OPCIONES = OPCIONES_BASE
local PROPUESTA: Propuesta = {}

-- ===================================== Límites =====================================
-- Los presupuestos son los de Config.Budgets (se leen de la copia). Aquí, lo que la calculadora añade:
local LIMITES = {
	-- Piezas por encima del presupuesto (en fracción) que cuentan como alerta: 0 = ni una más.
	margenAlerta = 0,
	-- Instantes (s) de la animación de una mascota con los que se reconoce qué piezas se mueven igual.
	posesMascota = { 0.37, 1.13, 2.29 },
	-- Bandos del Laboratorio y roles que visten armadura.
	bandos = { "Guardians", "Pirates" },
	rolesArmadura = { "Guerrero", "Cazador", "Mago", "Medico" },
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

-- ¿Pasa el id el filtro de OPCIONES.filtro?
local function pasa(id: string): boolean
	local filtro = OPCIONES.filtro
	return filtro == nil or string.find(string.lower(id), string.lower(filtro), 1, true) ~= nil
end

local function seccion(titulo: string, activa: boolean, cuerpo: () -> ())
	linea(titulo)
	if not activa then
		linea("(desactivada en las opciones)")
		linea("")
		return
	end
	local ok, mensaje = pcall(cuerpo)
	if not ok then
		linea(`No se pudo medir: {tostring(mensaje)}`)
	end
	linea("")
end

-- ===================================== Medición =====================================

type Medida = { ahora: number, tras: number, detalle: number, movidas: number?, movidasTras: number? }

local VoxelMerge: any = nil
local OPCIONES_FUSION = { force = true }

-- Piezas de un modelo ahora, y tras fusionarlo con "fusionar" sobre un clon (el original no cambia).
local function medir(modelo: Instance, fusionar: (Instance) -> ()): Medida
	local ahora = VoxelMerge.count(modelo)
	local clon = modelo:Clone()
	fusionar(clon)
	local tras, detalle = VoxelMerge.count(clon)
	clon:Destroy()
	return { ahora = ahora, tras = tras, detalle = detalle }
end

-- Fusión por soldaduras: las piezas colgadas de un ancla (arma, armadura, montura).
local function fusionSoldada(clon: Instance)
	VoxelMerge.mergeWelded(clon, OPCIONES_FUSION)
end

-- Fusión de un modelo de piezas fijas, sin soldaduras (construibles y parcela): todo en el marco del modelo.
local function fusionEstatica(clon: Instance)
	VoxelMerge.mergeStatic(clon, OPCIONES_FUSION)
end

local function celda(valor: number?): string
	return if valor then tostring(valor) else "-"
end

-- Una fila de tabla. Si tras fusionar pasa del presupuesto, alerta.
local function fila(nombre: string, medida: Medida, presupuesto: number?, extra: string?)
	local pasado = presupuesto ~= nil and medida.tras > presupuesto * (1 + LIMITES.margenAlerta)
	local sufijo = if pasado then " ⚠️" else ""
	linea(
		`| {nombre} | {medida.ahora} | {medida.tras}{sufijo} | {celda(presupuesto)} | {medida.detalle} |{if extra
			then " " .. extra .. " |"
			else ""}`
	)
	if pasado and presupuesto then
		alerta(`{nombre}: {medida.tras} piezas tras fusionar (presupuesto {presupuesto}, ahora {medida.ahora})`)
	end
end

local CABECERA = "| Modelo | Ahora | Tras fusionar | Presupuesto | Detalle |"
local SEPARADOR = "|---|---|---|---|---|"

local function cabecera()
	linea(CABECERA)
	linea(SEPARADOR)
end

-- Ejecuta "cuerpo" y, si falla, lo dice en una línea para que el informe siga.
local function intentar(nombre: string, cuerpo: () -> ())
	local ok, mensaje = pcall(cuerpo)
	if not ok then
		linea(`| {nombre} | no se pudo construir en modo edición: {tostring(mensaje)} | | | |`)
	end
end

-- Un R15 falso hecho de Parts, con los miembros que usa ArmorModels.wear.
local function r15Falso(): Model
	local personaje = Instance.new("Model")
	personaje.Name = "R15Falso"
	local function miembro(nombre: string, tamano: Vector3, posicion: Vector3)
		local pieza = Instance.new("Part")
		pieza.Name = nombre
		pieza.Size = tamano
		pieza.CFrame = CFrame.new(posicion)
		pieza.Anchored = true
		pieza.Parent = personaje
	end
	miembro("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0))
	miembro("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0))
	for lado, x in { Left = -1.5, Right = 1.5 } do
		miembro(lado .. "UpperArm", Vector3.new(1, 1.2, 1), Vector3.new(x, 3.4, 0))
		miembro(lado .. "LowerArm", Vector3.new(1, 0.8, 1), Vector3.new(x, 2.5, 0))
		miembro(lado .. "UpperLeg", Vector3.new(1, 1.3, 1), Vector3.new(x / 3, 1.5, 0))
	end
	return personaje
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
	VoxelMerge = require(copia.VoxelMerge)
	local B = Config.Budgets
	local M = B.Models
	-- El tope de un modelo: su excepción aprobada (Budgets.Exceptions) o el de su tipo.
	local function tope(id: string, clave: string, general: number): number
		local excepcion = B.Exceptions[id]
		return if excepcion and excepcion[clave] then excepcion[clave] else general
	end

	local Cosmetics = require(Data.Cosmetics) :: any
	local Weapons = require(Data.Weapons) :: any
	local Pets = require(Data.Pets) :: any
	local Mounts = require(Data.Mounts) :: any
	local Buildables = require(Data.Buildables) :: any
	local PlotStructures = require(Data.PlotStructures) :: any
	local Monkeys = require(Data.Monkeys) :: any
	local Bosses = require(Data.Bosses) :: any
	local S = OPCIONES.secciones

	linea(
		`Fusión: {if B.Merge then "activada" else "desactivada"} (Config.Budgets.Merge). "Tras fusionar" se mide siempre.`
	)
	linea("")

	-- ---------------------------------- 1. Armas de la forja ----------------------------------
	seccion("## 1. Armas de la forja y sus aspectos", S.armas, function()
		local WeaponTools = require(copia.WeaponTools) :: any
		cabecera()
		local ids = claves(Weapons, function(a, b)
			local rolA, nivelA = WeaponTools.roleLevel(a)
			local rolB, nivelB = WeaponTools.roleLevel(b)
			if (rolA or "~") ~= (rolB or "~") then
				return (rolA or "~") < (rolB or "~")
			end
			return if nivelA ~= nivelB then nivelA < nivelB else a < b
		end)
		for _, id in ids do
			if not Weapons[id].lab and pasa(id) then
				intentar(id, function()
					local rol, nivel = WeaponTools.roleLevel(id)
					local herramienta = WeaponTools.build(id)
					local presupuesto = if rol and nivel == WeaponTools.MAX_LEVEL then M.ForgeWeaponLevel4 else nil
					fila(`{id}{if rol then ` ({rol} {nivel})` else ""}`, medir(herramienta, fusionSoldada), presupuesto)
					herramienta:Destroy()
				end)
			end
		end
		-- Aspectos de arma (Data/Cosmetics "WeaponSkin") de rol: sobre el arma de nivel 4; de familia, sobre la suya.
		for _, id in claves(Cosmetics) do
			local cosmetico = Cosmetics[id]
			if
				cosmetico.kind == "WeaponSkin"
				and pasa(id)
				and not (cosmetico.weapon and Weapons[cosmetico.weapon] and Weapons[cosmetico.weapon].lab)
			then
				intentar(id, function()
					local armaId = if cosmetico.role
						then WeaponTools.roleWeapon(cosmetico.role, WeaponTools.MAX_LEVEL)
						else cosmetico.weapon
					assert(armaId, "sin arma para el aspecto")
					local herramienta = WeaponTools.build(armaId, id)
					fila(
						`{id} ({cosmetico.rarity}, sobre {armaId})`,
						medir(herramienta, fusionSoldada),
						M.WeaponSkinMythic
					)
					herramienta:Destroy()
				end)
			end
		end
	end)

	-- ---------------------------------- 2. Armaduras y trajes ----------------------------------
	seccion("## 2. Armaduras y trajes", S.armaduras, function()
		local ArmorModels = require(copia.ArmorModels) :: any
		cabecera()
		for rango, armaduraId in ArmorModels.BY_GRADE do
			for _, rol in LIMITES.rolesArmadura do
				local id = `{armaduraId} {rol}`
				if pasa(id) then
					intentar(id, function()
						local personaje = r15Falso()
						local pieza = ArmorModels.wear(personaje, armaduraId, rol)
						assert(pieza, "sin modelo")
						fila(`{id} (rango {rango})`, medir(pieza, fusionSoldada), M.ArmorRank[rango])
						personaje:Destroy()
					end)
				end
			end
		end
		for _, id in claves(Cosmetics) do
			local cosmetico = Cosmetics[id]
			if cosmetico.kind == "Outfit" and pasa(id) then
				intentar(id, function()
					local personaje = r15Falso()
					local pieza = ArmorModels.wear(personaje, nil, cosmetico.role, id, ArmorModels.MAX_GRADE)
					assert(pieza, "sin modelo")
					-- Solo el mítico tiene presupuesto propio (grado 4); los demás trajes, sin límite fijado.
					local presupuesto = if cosmetico.rarity == "Mythic" then M.OutfitMythicGrade4 else nil
					fila(
						`{id} ({cosmetico.rarity}, grado {ArmorModels.MAX_GRADE})`,
						medir(pieza, fusionSoldada),
						presupuesto
					)
					personaje:Destroy()
				end)
			end
		end
	end)

	-- ---------------------------------- 3. Mascotas ----------------------------------
	seccion("## 3. Mascotas y sus skins", S.mascotas, function()
		local PetModels = require(copia.PetModels) :: any
		linea("| Modelo | Ahora | Tras fusionar | Presupuesto | Detalle | Se mueven (ahora · tras) |")
		linea("|---|---|---|---|---|---|")

		local function firma(delta: CFrame): string
			local componentes = { delta:GetComponents() }
			local texto = {}
			for _, valor in componentes do
				table.insert(texto, string.format("%d", math.round(valor * 1000)))
			end
			return table.concat(texto, ",")
		end
		local FIRMA_FIJA = firma(CFrame.identity) .. "|" .. firma(CFrame.identity)

		local function medirMascota(modelo: Model): Medida
			local partes: { BasePart } = {}
			for _, hijo in modelo:GetChildren() do
				if hijo:IsA("BasePart") then
					table.insert(partes, hijo)
				end
			end
			local reposo = {}
			for indice, parte in partes do
				reposo[indice] = parte.CFrame
			end
			-- Tres poses de la marcha: las piezas con el mismo movimiento relativo comparten articulación.
			local poses = {}
			for _, instante in LIMITES.posesMascota do
				PetModels.animate(modelo, instante, 1)
				local marcos = {}
				for indice, parte in partes do
					marcos[indice] = parte.CFrame
				end
				table.insert(poses, marcos)
			end
			for indice, parte in partes do
				parte.CFrame = reposo[indice]
			end
			local grupos: { [string]: { BasePart } } = {}
			local orden: { string } = {}
			for indice, parte in partes do
				local base = poses[1][indice]:Inverse()
				local clave = firma(poses[2][indice] * base) .. "|" .. firma(poses[3][indice] * base)
				if not grupos[clave] then
					grupos[clave] = {}
					table.insert(orden, clave)
				end
				table.insert(grupos[clave], parte)
			end
			local movidas, movidasTras, tras, detalle = 0, 0, 0, 0
			for _, clave in orden do
				local resultado = VoxelMerge.merge(grupos[clave], CFrame.identity, OPCIONES_FUSION)
				tras += resultado.after
				detalle += resultado.detail
				if clave ~= FIRMA_FIJA then
					movidas += resultado.before
					movidasTras += resultado.after
				end
			end
			return {
				ahora = #partes,
				tras = tras,
				detalle = detalle,
				movidas = movidas,
				movidasTras = movidasTras,
			}
		end

		local function filaMascota(nombre: string, medida: Medida)
			local animadas = tope(nombre, "PetAnimated", M.PetAnimated)
			fila(nombre, medida, tope(nombre, "PetTotal", M.PetTotal), `{medida.movidas} · {medida.movidasTras}`)
			if (medida.movidasTras or 0) > animadas then
				alerta(`{nombre}: {medida.movidasTras} piezas se mueven cada fotograma (presupuesto {animadas})`)
			end
		end

		for _, petId in claves(Pets) do
			if pasa(petId) then
				intentar(petId, function()
					local modelo = PetModels.build(petId)
					assert(modelo, "sin constructor")
					filaMascota(petId, medirMascota(modelo))
					modelo:Destroy()
				end)
				for _, skinId in claves(Cosmetics) do
					if Cosmetics[skinId].kind == "PetSkin" and PetModels.hasSkin(skinId, petId) then
						intentar(`{petId} + {skinId}`, function()
							local modelo = PetModels.build(petId, skinId)
							assert(modelo, "sin constructor")
							filaMascota(`{petId} + {skinId} ({Cosmetics[skinId].rarity})`, medirMascota(modelo))
							modelo:Destroy()
						end)
					end
				end
			end
		end
	end)

	-- ---------------------------------- 4. Monturas ----------------------------------
	seccion("## 4. Monturas", S.monturas, function()
		local MountModels = require(copia.MountModels) :: any
		cabecera()
		local presupuestos = { Rare = M.MountRare, Legendary = M.MountLegendary, Mythic = M.MountMythic }
		for _, id in claves(Mounts) do
			if pasa(id) then
				intentar(id, function()
					local modelo = MountModels.build(id)
					assert(modelo, "sin constructor")
					fila(`{id} ({Mounts[id].rarity})`, medir(modelo, fusionSoldada), presupuestos[Mounts[id].rarity])
					modelo:Destroy()
				end)
			end
		end
	end)

	-- ---------------------------------- 5. Construibles y parcela ----------------------------------
	seccion("## 5. Construibles y parcela", S.construibles, function()
		local BuildModels = require(copia.BuildModels) :: any
		local PlotModels = require(copia.PlotModels) :: any
		cabecera()
		for _, id in claves(Buildables) do
			if pasa(id) then
				intentar(id, function()
					local modelo = BuildModels.build(id)
					fila(`{id} (construible)`, medir(modelo, fusionEstatica), tope(id, "Buildable", M.Buildable))
					modelo:Destroy()
				end)
			end
		end
		for _, id in claves(PlotStructures) do
			if pasa(id) then
				for nivel = 1, 3 do
					intentar(`{id} {nivel}`, function()
						local modelo = PlotModels.build(id, nivel)
						fila(`{id} nivel {nivel} (parcela)`, medir(modelo, fusionEstatica), M.PlotStructure[nivel])
						modelo:Destroy()
					end)
				end
			end
		end
	end)

	-- ---------------------------------- 6. Laboratorio ----------------------------------
	seccion("## 6. Armas del Laboratorio", S.laboratorio, function()
		local WeaponTools = require(copia.WeaponTools) :: any
		local LabWeaponSkins = require(copia.LabWeaponSkins) :: any
		cabecera()
		for _, armaId in claves(Weapons) do
			if Weapons[armaId].lab and pasa(armaId) then
				for _, bando in LIMITES.bandos do
					intentar(`{armaId} {bando}`, function()
						local herramienta = WeaponTools.build(armaId, bando)
						fila(`{armaId} {bando} (base)`, medir(herramienta, fusionSoldada), M.LabWeaponBase)
						herramienta:Destroy()
					end)
					for _, skinId in claves(Cosmetics) do
						local cosmetico = Cosmetics[skinId]
						if cosmetico.weapon == armaId and LabWeaponSkins.has(skinId) then
							intentar(`{armaId} {bando} {skinId}`, function()
								local herramienta = WeaponTools.build(armaId, `{bando}:{skinId}`)
								fila(
									`{armaId} {bando} + {skinId} (grado {cosmetico.grade})`,
									medir(herramienta, fusionSoldada),
									M.LabWeaponSkin3
								)
								herramienta:Destroy()
							end)
						end
					end
				end
			end
		end
	end)

	-- ---------------------------------- 7. Monos y jefes ----------------------------------
	seccion("## 7. Monos y jefes", S.monos, function()
		local servidor = ServerScriptService:FindFirstChild("Server")
		local carpeta = servidor and servidor:FindFirstChild("Monkeys")
		local modulo = carpeta and carpeta:FindFirstChild("MonkeyModels")
		if not (modulo and modulo:IsA("ModuleScript")) then
			linea("MonkeyModels no está en este place (ServerScriptService.Server.Monkeys): solo se mide en la Isla.")
			return
		end
		local MonkeyModels = require(modulo) :: any
		linea("Piezas del modelo final, ya unido con UnionAsync (mergeBoxes); no se les aplica VoxelMerge.")
		linea("| Modelo | Piezas | Presupuesto |")
		linea("|---|---|---|")
		local function filaMono(nombre: string, modelo: Instance, presupuesto: number)
			local piezas = VoxelMerge.count(modelo)
			local pasado = piezas > presupuesto
			linea(`| {nombre} | {piezas}{if pasado then " ⚠️" else ""} | {presupuesto} |`)
			if pasado then
				alerta(`{nombre}: {piezas} piezas (presupuesto {presupuesto})`)
			end
		end
		for _, id in claves(Monkeys) do
			if pasa(id) then
				intentar(id, function()
					local modelo = MonkeyModels.build(id, Monkeys[id], Vector3.zero)
					filaMono(id, modelo, M.Monkey)
					modelo:Destroy()
				end)
			end
		end
		for _, id in claves(Bosses) do
			if pasa(id) then
				intentar(id, function()
					local definicion = Bosses[id]
					local aspecto = table.clone(Monkeys[definicion.baseSpecies])
					aspecto.name = definicion.name
					aspecto.scale = definicion.scale
					aspecto.bodyColor = definicion.bodyColor
					aspecto.faceColor = definicion.faceColor
					local modelo = MonkeyModels.build(definicion.baseSpecies, aspecto, Vector3.zero, id)
					filaMono(`{id} (jefe)`, modelo, tope(id, "Boss", M.Boss))
					modelo:Destroy()
				end)
			end
		end
	end)

	-- ---------------------------------- 8. Totales por escena ----------------------------------
	seccion("## 8. Totales por escena", S.escenas, function()
		local P = B.Matches
		linea("| Escena | Piezas | Otros límites |")
		linea("|---|---|---|")
		linea(`| Isla, asedio final | {P.IslandSiegeParts} | {P.IslandSiegeDrawCalls} draw calls |`)
		linea(`| Dunas 5v5 | {P.DunasParts} | |`)
		linea(`| Laboratorio 5v5 | {P.LaboratorioParts} | |`)
		linea(`| Lobby con {P.LobbyPlayers} | {P.LobbyParts} | |`)
		linea(
			`| Todas | | {P.MovedPartsPerFrame} piezas movidas por fotograma, {P.MemoryMB} MB, servidor a {P.ServerFps} FPS |`
		)
		linea("")
		linea("Pendiente R5/R6: simular la partida de cada escena (mapa, personajes con su equipo, mascotas, monturas")
		linea("y estructuras) con las cifras de las secciones 1 a 7, y el Lobby con 20 y el LOD de detalle.")
	end)

	-- ---------------------------------- 9. Efectos ----------------------------------
	seccion("## 9. Pico de efectos por calidad", S.efectos, function()
		local V = B.Vfx
		linea("| Calidad | Pico de piezas por cliente |")
		linea("|---|---|")
		linea(`| Bajo | {V.Low} |`)
		linea(`| Medio | {V.Medium} |`)
		linea(`| Alto | {V.High} |`)
		linea("")
		linea("Pendiente R6: contar el pico de los efectos de cada jefe (combatClient/BossFx) en las tres calidades.")
	end)

	linea("## 10. Alertas")
	if #alertas == 0 then
		linea("✅ Todo dentro de los límites.")
	else
		for _, texto in alertas do
			linea(texto)
		end
	end
	return table.concat(lineas, "\n")
end

local Rendimiento = {}

-- Informe con "opciones" (cambios sobre OPCIONES_BASE) y "propuesta" (ver PROPUESTA). Los dos opcionales.
function Rendimiento.informe(opciones: any?, propuesta: Propuesta?): string
	OPCIONES = copiaProfunda(OPCIONES_BASE)
	mezclar(OPCIONES, opciones or {})
	PROPUESTA = propuesta or {}
	lineas = {}
	alertas = {}
	local copia = ReplicatedStorage:WaitForChild("Shared"):Clone()
	copia.Name = "_RendimientoShared"
	copia.Parent = ServerStorage
	local ok, resultado = pcall(main, copia)
	copia:Destroy()
	if not ok then
		error(resultado, 0)
	end
	return resultado
end

return Rendimiento
