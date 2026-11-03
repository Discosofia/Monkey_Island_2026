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
--   7. Monos, alfas y jefes (combat/Monkeys/MonkeyModels): bloques de diseño, piezas del modelo final (ya unido con
--      UnionAsync), triángulos y ms de unión, contra los topes. Con informe({ foto = true }) imprime la tabla para
--      RendimientoBase.luau (ModuleScript junto a esta calculadora) y, si existe, la columna Δ tris frente a ella.
--   8. Totales por escena y el Lobby con 20 jugadores con y sin LOD de detalle (R5).
--   8b. Escena de la Isla: monos (mezcla de tropas), un jefe, 5 jugadores con equipo medio, el mapa alrededor del
--       Basecamp (Matches.MapRadius) y el pico de efectos contra IslandTriangles, y la tabla «Reparto del margen».
--   8c. Lobby (20 jugadores, con LOD de detalle en los 19 de lejos) y Dunas (10) contra LobbyTriangles y DunasTriangles.
--   Las secciones 1 a 6 llevan además la columna «Triángulos / tope» (los topes que aún no existen en Config.Budgets
--   ponen «—» y no alertan).
--   9. Pico de efectos de cada jefe por calidad (R6: combatClient/BossFx contra Config.Budgets.Vfx).
--   10. Impactos de las armas por calidad (W5: combatClient/ImpactFx con una ráfaga de 10 tiradores).
--   11. Alertas: lo que, tras fusionar, pasa del presupuesto.
-- Pendiente: los modelos de ViewportFrame (RewardModels) y los nodos del mapa (MapBuilder) se miden en R3.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- ===================================== Opciones =====================================

local OPCIONES_BASE = {
	-- Solo los modelos cuyo id contiene este texto (sin distinguir mayúsculas); nil = todos.
	filtro = nil :: string?,
	-- true: al final del informe, la tabla de monos y jefes lista para pegar en RendimientoBase.luau.
	foto = false,
	secciones = {
		armas = true,
		armaduras = true,
		mascotas = true,
		monturas = true,
		construibles = true,
		laboratorio = true,
		monos = true,
		escenas = true,
		isla = true,
		lobbydunas = true,
		efectos = true,
		impactos = true,
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
	-- Triángulos estimados por tipo de pieza (los bloques y las uniones se miden; esto es lo que no se puede leer).
	triangulos = {
		bloque = 12, -- Part Block: 6 caras, 2 triángulos cada una
		bola = 224, -- Part Ball (esfera de Roblox, ~ 14 × 8 × 2)
		cilindro = 64, -- Part Cylinder (~ 16 lados: 2 tapas y la pared)
		cuna = 8, -- WedgePart
		cunaEsquina = 6, -- CornerWedgePart
		mallaEspecial = 224, -- SpecialMesh (esfera, cilindro, cuña…): se cuenta como una esfera
	},
}

-- ===================================== Utilidades =====================================

local lineas: { string } = {}
local alertas: { string } = {}
-- Piezas, triángulos y bloques de diseño de cada mono y jefe medido (informe({ foto = true }) la imprime).
local FOTO: { [string]: { piezas: number, tris: number, diseno: number } } = {}

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

type Medida = {
	ahora: number,
	tras: number,
	detalle: number,
	movidas: number?,
	movidasTras: number?,
	tris: number?, -- triángulos del modelo ya fusionado
}

local VoxelMerge: any = nil
local OPCIONES_FUSION = { force = true }

-- Piezas de un modelo ahora, y tras fusionarlo con "fusionar" sobre un clon (el original no cambia).
local triangulos: (Instance, boolean?) -> number

local function medir(modelo: Instance, fusionar: (Instance) -> ()): Medida
	local ahora = VoxelMerge.count(modelo)
	local clon = modelo:Clone()
	fusionar(clon)
	local tras, detalle = VoxelMerge.count(clon)
	local tris = triangulos(clon)
	clon:Destroy()
	return { ahora = ahora, tras = tras, detalle = detalle, tris = tris }
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

-- Una fila de tabla. Si tras fusionar pasa del presupuesto (o sus triángulos del tope "topeTris"), alerta.
local function fila(nombre: string, medida: Medida, presupuesto: number?, extra: string?, topeTris: number?)
	local pasado = presupuesto ~= nil and medida.tras > presupuesto * (1 + LIMITES.margenAlerta)
	local sufijo = if pasado then " ⚠️" else ""
	local tris = medida.tris
	local pasadoTris = tris ~= nil and topeTris ~= nil and tris > topeTris
	local celdaTris = if tris
		then `{tris}{if pasadoTris then " ⚠️" else ""} / {if topeTris then tostring(topeTris) else "—"}`
		else "—"
	linea(
		`| {nombre} | {medida.ahora} | {medida.tras}{sufijo} | {celda(presupuesto)} | {medida.detalle} | {celdaTris} |{if extra
			then " " .. extra .. " |"
			else ""}`
	)
	if pasado and presupuesto then
		alerta(`{nombre}: {medida.tras} piezas tras fusionar (presupuesto {presupuesto}, ahora {medida.ahora})`)
	end
	if pasadoTris and tris and topeTris then
		alerta(`{nombre}: {tris} triángulos tras fusionar (tope {topeTris})`)
	end
end

local CABECERA = "| Modelo | Ahora | Tras fusionar | Presupuesto | Detalle | Triángulos / tope |"
local SEPARADOR = "|---|---|---|---|---|---|"

local function cabecera()
	linea(CABECERA)
	linea(SEPARADOR)
end

-- Ejecuta "cuerpo" y, si falla, lo dice en una línea para que el informe siga.
local function intentar(nombre: string, cuerpo: () -> ())
	local ok, mensaje = pcall(cuerpo)
	if not ok then
		linea(`| {nombre} | no se pudo construir en modo edición: {tostring(mensaje)} | | | | |`)
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

-- Triángulos que dibuja un modelo (los de las piezas visibles): las uniones y mallas, su TriangleCount; las demás
-- piezas, la estimación de LIMITES.triangulos. Si una unión no deja leer TriangleCount, se cuenta como sus bloques de
-- diseño (atributo DesignBlocks) a 12 cada uno, que es de más.
local function trisPieza(parte: Instance): number
	local T = LIMITES.triangulos
	if not parte:IsA("BasePart") or parte.Transparency >= 1 then
		return 0
	end
	if parte:FindFirstChildOfClass("SpecialMesh") then
		return T.mallaEspecial
	elseif parte:IsA("PartOperation") or parte:IsA("MeshPart") then
		local ok, cuenta = pcall(function()
			return (parte :: any).TriangleCount
		end)
		if ok and typeof(cuenta) == "number" and cuenta > 0 then
			return cuenta
		end
		return ((parte:GetAttribute("DesignBlocks") :: number?) or 1) * T.bloque
	elseif parte:IsA("WedgePart") then
		return T.cuna
	elseif parte:IsA("CornerWedgePart") then
		return T.cunaEsquina
	elseif parte:IsA("Part") then
		return if parte.Shape == Enum.PartType.Ball
			then T.bola
			elseif parte.Shape == Enum.PartType.Cylinder then T.cilindro
			else T.bloque
	end
	return 0
end

-- Con "sinDetalle", las piezas con la etiqueta "Detalle" no cuentan (las que oculta el LOD a los jugadores lejos).
triangulos = function(modelo: Instance, sinDetalle: boolean?): number
	local total = 0
	local lista = modelo:GetDescendants()
	table.insert(lista, modelo)
	for _, parte in lista do
		if sinDetalle and CollectionService:HasTag(parte, "Detalle") then
			continue
		end
		total += trisPieza(parte)
	end
	return total
end

-- ===================================== Informe =====================================

type Medicion = { diseno: number, piezas: number, tris: number, ms: number }

-- Triángulos de un tipo de equipo (armadura, arma…): suma y máximo de lo que existe. Los campos «Sin» son los
-- triángulos sin las piezas Detalle.
type Estadistica = {
	n: number,
	sumaPiezas: number,
	sumaTris: number,
	sumaSin: number,
	maxPiezas: number,
	maxTris: number,
	maxSin: number,
}
type Valores = { piezas: number, tris: number }

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

	-- La foto de referencia (RendimientoBase.luau, junto a esta calculadora) para la columna Δ de la sección 7.
	-- Se pide una copia del módulo para no usar la versión en caché. Una copia suelta de la calculadora no tiene
	-- padre: se busca en ServerStorage.Tools.
	local BASE: { [string]: { piezas: number, tris: number, diseno: number } }? = nil
	do
		local carpetaTools = script.Parent or ServerStorage:FindFirstChild("Tools")
		local moduloBase = carpetaTools and carpetaTools:FindFirstChild("RendimientoBase")
		if moduloBase and moduloBase:IsA("ModuleScript") then
			local ok, datos = pcall(function()
				return require(moduloBase:Clone())
			end)
			if ok and typeof(datos) == "table" then
				BASE = datos
			end
		end
	end

	-- Un tope que puede no existir todavía en Config.Budgets: nil = sin tope, la celda pone «—» y no alerta.
	local function topeTabla(tabla: any, clave: string | number): number?
		if typeof(tabla) ~= "table" then
			return nil
		end
		local valor = tabla[clave]
		return if typeof(valor) == "number" then valor else nil
	end
	local function celdaTope(valor: number?): string
		return if valor then tostring(valor) else "—"
	end
	-- Como tope(), pero el general puede no existir todavía: nil = sin tope.
	local function topeOpc(id: string, clave: string, general: any): number?
		local excepcion = B.Exceptions[id]
		if excepcion and typeof(excepcion[clave]) == "number" then
			return excepcion[clave]
		end
		return if typeof(general) == "number" then general else nil
	end

	-- MonkeyModels, si este place lo tiene (la Isla), y las medidas de sus modelos (con caché: la sección 7 y la
	-- escena de la Isla miden lo mismo).
	local MonkeyModels: any = nil
	local function cargarMonos(): any
		if MonkeyModels then
			return MonkeyModels
		end
		local servidor = ServerScriptService:FindFirstChild("Combat")
		local carpeta = servidor and servidor:FindFirstChild("Monkeys")
		local modulo = carpeta and carpeta:FindFirstChild("MonkeyModels")
		if modulo and modulo:IsA("ModuleScript") then
			MonkeyModels = require(modulo)
		end
		return MonkeyModels
	end
	local medidasMonos: { [string]: Medicion } = {}
	local function medirConstruido(clave: string, modelo: Instance): Medicion
		local medida: Medicion = {
			diseno = (modelo:GetAttribute("DesignBlocks") :: number?) or 0,
			piezas = VoxelMerge.count(modelo),
			tris = triangulos(modelo),
			ms = (modelo:GetAttribute("UnionMs") :: number?) or 0,
		}
		modelo:Destroy()
		medidasMonos[clave] = medida
		return medida
	end
	local function medirMono(id: string, alfa: boolean): Medicion
		local clave = if alfa then `{id} (alfa)` else id
		return medidasMonos[clave]
			or medirConstruido(clave, cargarMonos().build(id, Monkeys[id], Vector3.zero, nil, alfa or nil))
	end
	local function medirJefe(id: string): Medicion
		local clave = `{id} (jefe)`
		if medidasMonos[clave] then
			return medidasMonos[clave]
		end
		local definicion = Bosses[id]
		local aspecto = table.clone(Monkeys[definicion.baseSpecies])
		aspecto.name = definicion.name
		aspecto.scale = definicion.scale
		aspecto.bodyColor = definicion.bodyColor
		aspecto.faceColor = definicion.faceColor
		return medirConstruido(clave, cargarMonos().build(definicion.baseSpecies, aspecto, Vector3.zero, id))
	end

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
					-- Armas de rol: tope por nivel (rango). Machete y Honda son de rango I; sus mejoras, de rango II.
					local rango = if rol
						then nivel
						elseif id == "Machete" or id == "Honda" then 1
						elseif id == "SharpMachete" or id == "LianaSling" then 2
						else nil
					local presupuesto = if rango then M.ForgeWeaponRank[rango] else nil
					fila(
						`{id}{if rol then ` ({rol} {nivel})` else ""}`,
						medir(herramienta, fusionSoldada),
						presupuesto,
						nil,
						if rango then topeTabla(M.WeaponTriangles, rango) else nil
					)
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
						if cosmetico.rarity == "Epic"
							then M.WeaponSkinEpic
							elseif cosmetico.rarity == "Rare" then M.WeaponSkinRare
							else M.WeaponSkinMythic,
						nil,
						topeTabla(M.WeaponSkinTriangles, cosmetico.rarity)
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
						fila(
							`{id} (rango {rango})`,
							medir(pieza, fusionSoldada),
							M.ArmorRank[rango],
							nil,
							topeTabla(M.ArmorTriangles, rango)
						)
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
					-- Solo el mítico y el legendario tienen presupuesto propio (grado 4); los demás trajes, sin límite.
					local presupuesto = if cosmetico.rarity == "Mythic"
						then M.OutfitMythicGrade4
						elseif cosmetico.rarity == "Legendary" then M.OutfitLegendaryGrade4
						else nil
					fila(
						`{id} ({cosmetico.rarity}, grado {ArmorModels.MAX_GRADE})`,
						medir(pieza, fusionSoldada),
						presupuesto,
						nil,
						if presupuesto then topeTabla(M.OutfitTriangles, cosmetico.rarity) else nil
					)
					personaje:Destroy()
					-- Los legendarios y los míticos, además, grado a grado (1 a 3, sin presupuesto) para ver cómo crece cada uno.
					if cosmetico.rarity == "Legendary" or cosmetico.rarity == "Mythic" then
						for grado = 1, ArmorModels.MAX_GRADE - 1 do
							local otro = r15Falso()
							local piezaGrado = ArmorModels.wear(otro, nil, cosmetico.role, id, grado)
							if piezaGrado then
								fila(`{id} ({cosmetico.rarity}, grado {grado})`, medir(piezaGrado, fusionSoldada), nil)
							end
							otro:Destroy()
						end
					end
				end)
			end
		end
	end)

	-- ---------------------------------- 3. Mascotas ----------------------------------
	seccion("## 3. Mascotas y sus skins", S.mascotas, function()
		local PetModels = require(copia.PetModels) :: any
		linea(
			"| Modelo | Ahora | Tras fusionar | Presupuesto | Detalle | Triángulos / tope | Se mueven (ahora · tras) |"
		)
		linea("|---|---|---|---|---|---|---|")

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
				tris = triangulos(modelo), -- tras la fusión por grupos (si VoxelMerge cambia las piezas del modelo)
			}
		end

		local function filaMascota(nombre: string, medida: Medida)
			local animadas = tope(nombre, "PetAnimated", M.PetAnimated)
			fila(
				nombre,
				medida,
				tope(nombre, "PetTotal", M.PetTotal),
				`{medida.movidas} · {medida.movidasTras}`,
				topeOpc(nombre, "PetTriangles", M.PetTriangles)
			)
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
					fila(
						`{id} ({Mounts[id].rarity})`,
						medir(modelo, fusionSoldada),
						presupuestos[Mounts[id].rarity],
						nil,
						topeTabla(M.MountTriangles, Mounts[id].rarity)
					)
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
						fila(
							`{armaId} {bando} (base)`,
							medir(herramienta, fusionSoldada),
							M.LabWeaponBase,
							nil,
							topeOpc(armaId, "LabWeaponTriangles", M.LabWeaponTriangles)
						)
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
									M.LabWeaponSkin3,
									nil,
									topeOpc(armaId, "LabWeaponTriangles", M.LabWeaponTriangles)
								)
								herramienta:Destroy()
							end)
						end
					end
				end
			end
		end
		-- Brazos del rig de la vista en primera persona (Fase 19, W10): piezas sin contar el arma (el Handle de prueba).
		intentar("LabViewModelRig", function()
			local LabViewModelRig = require(copia.LabViewModelRig) :: any
			local arma = Instance.new("Model")
			local mango = Instance.new("Part")
			mango.Name = "Handle"
			mango.Parent = arma
			local rig = LabViewModelRig.build(arma, mango, "Guardians", Color3.new(1, 1, 1))
			local piezas = 0
			for _, parte in rig.model:GetDescendants() do
				if parte:IsA("BasePart") and parte.Name ~= "Handle" then
					piezas += 1
				end
			end
			fila(
				"Brazos de la vista (rig sin arma)",
				{ ahora = piezas, tras = piezas, detalle = 0 },
				M.LabViewModelArms
			)
			rig.model:Destroy()
		end)
		-- Modelos de apuntado de la primera persona (Fase 19, W11): solo las piezas "LabAim", sin fusionar (se
		-- crean al sacar el arma y solo las ve quien apunta).
		intentar("LabAimModels", function()
			local LabWeaponModels = require(copia.LabWeaponModels) :: any
			local LabAimModels = require(copia.LabAimModels) :: any
			for _, armaId in claves(Weapons) do
				if Weapons[armaId].lab and LabAimModels.has(armaId) and pasa(armaId) then
					for _, bando in LIMITES.bandos do
						local skins: { string | boolean } = { false }
						for _, skinId in claves(Cosmetics) do
							if Cosmetics[skinId].weapon == armaId and LabWeaponSkins.has(skinId) then
								table.insert(skins, skinId)
							end
						end
						for _, skinId in skins do
							local herramienta = Instance.new("Tool")
							local mango = LabWeaponModels.build(herramienta, armaId, bando, nil)
							LabAimModels.add(mango, armaId, bando, if typeof(skinId) == "string" then skinId else nil)
							local piezas = 0
							for _, parte in herramienta:GetChildren() do
								if parte:IsA("BasePart") and parte:GetAttribute("LabAim") then
									piezas += 1
								end
							end
							fila(
								`{armaId} {bando} apuntando{if typeof(skinId) == "string" then ` + {skinId}` else ""}`,
								{ ahora = piezas, tras = piezas, detalle = 0 },
								M.LabAimModel
							)
							herramienta:Destroy()
						end
					end
				end
			end
		end)
	end)

	-- ---------------------------------- 7. Monos y jefes ----------------------------------
	seccion("## 7. Monos y jefes", S.monos, function()
		if not cargarMonos() then
			linea("MonkeyModels no está en este place (ServerScriptService.Combat.Monkeys).")
			return
		end
		linea("Modelo final, ya unido con UnionAsync (mergeBoxes); no se les aplica VoxelMerge.")
		linea(
			"Bloques de diseño: los que hay antes de unir (DesignBlocks). Unión: lo que tardó UnionAsync al construirlo. Triángulos: ver `triangulos` (estimación para Ball, Cylinder y mallas)."
		)
		linea("Los topes con «—» todavía no existen en Config.Budgets: no alertan.")
		linea(
			`| Modelo | Tier | Bloques de diseño | Piezas | Triángulos | Unión (ms) | Topes |{if BASE
				then " Δ tris |"
				else ""}`
		)
		linea(`|---|---|---|---|---|---|---|{if BASE then "---|" else ""}`)
		local function filaMono(
			nombre: string,
			tier: string,
			medida: Medicion,
			claveTope: string | number,
			piezasTope: number
		)
			local topeDiseno = topeTabla(M.MonkeyDesign, claveTope)
			local topeTris = topeTabla(M.MonkeyTriangles, claveTope)
			local marcas = ""
			local function revisar(valor: number, limite: number?, que: string)
				if limite and valor > limite then
					marcas = " ⚠️"
					alerta(`{nombre}: {valor} {que} (tope {limite})`)
				end
			end
			revisar(medida.diseno, topeDiseno, "bloques de diseño")
			revisar(medida.piezas, piezasTope, "piezas")
			revisar(medida.tris, topeTris, "triángulos")
			FOTO[nombre] = { piezas = medida.piezas, tris = medida.tris, diseno = medida.diseno }
			local delta = ""
			if BASE then
				local antes = BASE[nombre]
				delta = ` {if antes then string.format("%+d", medida.tris - antes.tris) else "—"} |`
			end
			linea(
				`| {nombre} | {tier} | {medida.diseno} | {medida.piezas} | {medida.tris} | {medida.ms} | diseño {celdaTope(
					topeDiseno
				)} / piezas {piezasTope} / tris {celdaTope(topeTris)}{marcas} |{delta}`
			)
		end
		for _, id in claves(Monkeys) do
			if pasa(id) then
				local definicion = Monkeys[id]
				intentar(id, function()
					filaMono(id, tostring(definicion.tier), medirMono(id, false), definicion.tier, M.Monkey)
				end)
				if definicion.alpha == true then
					intentar(`{id} (alfa)`, function()
						filaMono(`{id} (alfa)`, tostring(definicion.tier), medirMono(id, true), "Alpha", M.Monkey)
					end)
				end
			end
		end
		for _, id in claves(Bosses) do
			if pasa(id) then
				intentar(id, function()
					filaMono(`{id} (jefe)`, "jefe", medirJefe(id), "Boss", tope(id, "Boss", M.Boss))
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

		-- Lobby con 20 y LOD de detalle (R5): el peor jugador posible (el equipo con más piezas de cada tipo) y
		-- cuánto cuesta en los otros 19 con y sin DetailLodController. No cuenta el escenario del Lobby (lo genera
		-- LobbyBuilder y no está en este place): es lo que los cosméticos se comen del tope de piezas.
		linea("### Lobby con jugadores: cosméticos con y sin LOD de detalle")
		local WeaponTools = require(copia.WeaponTools) :: any
		local ArmorModels = require(copia.ArmorModels) :: any
		local PetModels = require(copia.PetModels) :: any
		local MountModels = require(copia.MountModels) :: any
		local sinFusion = function(_: Instance) end
		-- Se queda con la medida de más piezas tras fusionar.
		local function mayor(actual: Medida?, nueva: Medida): Medida
			return if actual == nil or nueva.tras > actual.tras then nueva else actual
		end
		local peor: { [string]: Medida? } = {}
		local function probar(tipo: string, cuerpo: () -> Medida)
			local ok, medida = pcall(cuerpo)
			if ok then
				peor[tipo] = mayor(peor[tipo], medida)
			end
		end
		for rol in { Guerrero = 1, Cazador = 1, Mago = 1, Medico = 1 } do
			probar("Armadura", function()
				local personaje = r15Falso()
				local pieza = ArmorModels.wear(personaje, ArmorModels.BY_GRADE[ArmorModels.MAX_GRADE], rol)
				local medida = medir(pieza, fusionSoldada)
				personaje:Destroy()
				return medida
			end)
			probar("Arma", function()
				local herramienta = WeaponTools.build(WeaponTools.roleWeapon(rol, WeaponTools.MAX_LEVEL))
				local medida = medir(herramienta, fusionSoldada)
				herramienta:Destroy()
				return medida
			end)
		end
		probar("Traje", function()
			local mayorTraje: Medida? = nil
			for _, id in claves(Cosmetics) do
				local cosmetico = Cosmetics[id]
				if cosmetico.kind == "Outfit" and cosmetico.rarity == "Mythic" then
					local personaje = r15Falso()
					local pieza = ArmorModels.wear(personaje, nil, cosmetico.role, id, ArmorModels.MAX_GRADE)
					if pieza then
						mayorTraje = mayor(mayorTraje, medir(pieza, fusionSoldada))
					end
					personaje:Destroy()
				end
			end
			return assert(mayorTraje, "sin trajes míticos")
		end)
		for petId in Pets do
			probar("Mascota", function()
				local modelo = PetModels.build(petId)
				local medida = medir(modelo, sinFusion)
				modelo:Destroy()
				return medida
			end)
		end
		for mountId in Mounts do
			probar("Montura", function()
				local modelo = MountModels.build(mountId)
				local medida = medir(modelo, fusionSoldada)
				modelo:Destroy()
				return medida
			end)
		end

		linea("| Pieza del peor jugador | Piezas | De ellas, Detalle |")
		linea("|---|---|---|")
		local conDetalle, sinDetalle = 0, 0
		for _, tipo in { "Armadura", "Traje", "Arma", "Mascota", "Montura" } do
			local medida = peor[tipo]
			if medida then
				-- La armadura y el traje son alternativas: se cuenta el traje, que pesa más, y no los dos.
				linea(`| {tipo} | {medida.tras} | {medida.detalle} |`)
				if tipo ~= "Armadura" then
					conDetalle += medida.tras
					sinDetalle += medida.tras - medida.detalle
				end
			end
		end
		linea("")
		local otros = B.Matches.LobbyPlayers - 1
		linea("| Jugadores | Sin LOD | Con LOD (los otros lejos) | Ahorro |")
		linea("|---|---|---|---|")
		local sin = conDetalle * (otros + 1)
		local con = conDetalle + sinDetalle * otros
		linea(`| Yo + {otros} | {sin} | {con} | {sin - con} ({math.round((sin - con) / math.max(sin, 1) * 100)} %) |`)
		linea("")
		linea(
			"Mascotas y monturas no se fusionan (R4 no compensó), así que no llevan piezas Detalle: el LOD no las toca."
		)
		if con > B.Matches.LobbyParts then
			alerta(
				`Lobby con {B.Matches.LobbyPlayers}: solo los cosméticos suman {con} piezas (tope {B.Matches.LobbyParts})`
			)
		end
	end)

	-- ---------------------------------- Equipo de un jugador (8b y 8c) ----------------------------------
	-- La media y el máximo de piezas y triángulos de lo que existe de cada tipo. Se mide la primera vez que se pide.
	local equipoCache: { [string]: Estadistica }? = nil
	local function recogerEquipo(): { [string]: Estadistica }
		if equipoCache then
			return equipoCache
		end
		local WeaponTools = require(copia.WeaponTools) :: any
		local ArmorModels = require(copia.ArmorModels) :: any
		local PetModels = require(copia.PetModels) :: any
		local MountModels = require(copia.MountModels) :: any
		local sinFusion = function(_: Instance) end
		local equipo: { [string]: Estadistica } = {}
		equipoCache = equipo
		local function registrar(tipo: string, piezas: number, tris: number, trisSin: number)
			local e = equipo[tipo]
			if not e then
				e = {
					n = 0,
					sumaPiezas = 0,
					sumaTris = 0,
					sumaSin = 0,
					maxPiezas = 0,
					maxTris = 0,
					maxSin = 0,
				}
				equipo[tipo] = e
			end
			e.n += 1
			e.sumaPiezas += piezas
			e.sumaTris += tris
			e.sumaSin += trisSin
			e.maxPiezas = math.max(e.maxPiezas, piezas)
			e.maxTris = math.max(e.maxTris, tris)
			e.maxSin = math.max(e.maxSin, trisSin)
		end
		-- "tipoExtra": una segunda lista donde también cuenta (las mascotas estándar y las especiales).
		local function anotar(tipo: string, modelo: Instance, fusionar: (Instance) -> (), tipoExtra: string?)
			local clon = modelo:Clone()
			fusionar(clon)
			local piezas, tris, trisSin = VoxelMerge.count(clon), triangulos(clon), triangulos(clon, true)
			clon:Destroy()
			registrar(tipo, piezas, tris, trisSin)
			if tipoExtra then
				registrar(tipoExtra, piezas, tris, trisSin)
			end
		end
		for _, armaduraId in ArmorModels.BY_GRADE do
			for _, rol in LIMITES.rolesArmadura do
				intentar(`{armaduraId} {rol}`, function()
					local personaje = r15Falso()
					anotar(
						"Armadura",
						assert(ArmorModels.wear(personaje, armaduraId, rol), "sin modelo"),
						fusionSoldada
					)
					personaje:Destroy()
				end)
			end
		end
		for _, id in claves(Cosmetics) do
			local cosmetico = Cosmetics[id]
			if cosmetico.kind == "Outfit" then
				intentar(id, function()
					local personaje = r15Falso()
					local pieza = ArmorModels.wear(personaje, nil, cosmetico.role, id, ArmorModels.MAX_GRADE)
					if pieza then
						anotar("Traje", pieza, fusionSoldada)
					end
					personaje:Destroy()
				end)
			end
		end
		for _, id in claves(Weapons) do
			if not Weapons[id].lab then
				intentar(id, function()
					local herramienta = WeaponTools.build(id)
					anotar("Arma", herramienta, fusionSoldada)
					herramienta:Destroy()
				end)
			end
		end
		-- Los aspectos de arma también los lleva el jugador: cuentan en la familia Arma, como en la sección 1.
		for _, id in claves(Cosmetics) do
			local cosmetico = Cosmetics[id]
			if
				cosmetico.kind == "WeaponSkin"
				and not (cosmetico.weapon and Weapons[cosmetico.weapon] and Weapons[cosmetico.weapon].lab)
			then
				intentar(id, function()
					local armaId = if cosmetico.role
						then WeaponTools.roleWeapon(cosmetico.role, WeaponTools.MAX_LEVEL)
						else cosmetico.weapon
					assert(armaId, "sin arma para el aspecto")
					local herramienta = WeaponTools.build(armaId, id)
					anotar("Arma", herramienta, fusionSoldada)
					herramienta:Destroy()
				end)
			end
		end
		for _, id in claves(Pets) do
			intentar(id, function()
				local modelo = PetModels.build(id)
				local rareza = Pets[id].rarity
				local especial = rareza == "Mythic" or rareza == "Legendary"
				anotar("Mascota", modelo, sinFusion, if especial then "MascotaEspecial" else "MascotaEstandar")
				modelo:Destroy()
			end)
		end
		for _, id in claves(Mounts) do
			intentar(id, function()
				local modelo = MountModels.build(id)
				anotar("Montura", modelo, fusionSoldada)
				modelo:Destroy()
			end)
		end
		return equipo
	end

	-- Lo que lleva un jugador, por familia: la media (o el peor caso) de lo que existe. "sinDetalle": triángulos sin las
	-- piezas Detalle (el jugador lejano con el LOD). La vestimenta es la armadura o el traje, el que pese más.
	local function valoresEquipo(
		equipo: { [string]: Estadistica },
		peor: boolean,
		sinDetalle: boolean
	): { [string]: Valores }
		local function valores(e: Estadistica?): Valores
			if not e then
				return { piezas = 0, tris = 0 }
			end
			local piezas = if peor then e.maxPiezas else e.sumaPiezas / e.n
			local tris = if peor
				then (if sinDetalle then e.maxSin else e.maxTris)
				else (if sinDetalle then e.sumaSin else e.sumaTris) / e.n
			return { piezas = piezas, tris = tris }
		end
		local armadura, traje = valores(equipo.Armadura), valores(equipo.Traje)
		return {
			Vestimenta = if traje.tris > armadura.tris then traje else armadura,
			Arma = valores(equipo.Arma),
			Mascota = valores(equipo.Mascota),
			Montura = valores(equipo.Montura),
			MascotaEstandar = valores(equipo.MascotaEstandar),
			MascotaEspecial = valores(equipo.MascotaEspecial),
		}
	end
	local function sumaEquipo(v: { [string]: Valores }): (number, number)
		local piezas, tris = 0, 0
		for _, clave in { "Vestimenta", "Arma", "Mascota", "Montura" } do
			piezas += v[clave].piezas
			tris += v[clave].tris
		end
		return piezas, tris
	end

	-- ---------------------------------- Mapa (8b) ----------------------------------
	-- Las piezas de Workspace a menos de Matches.MapRadius de la pieza del Basecamp, sin personajes ni monos. Devuelve
	-- piezas, triángulos y una nota (no vacía si no se pudo medir).
	local function medirMapa(): (number, number, string)
		local nombreAncla = Config.Basecamp.ZonePartName
		local ancla = workspace:FindFirstChild(nombreAncla, true)
		if not ancla or not ancla:IsA("BasePart") then
			return 0, 0, `mapa no medido (no hay una pieza «{nombreAncla}» en Workspace)`
		end
		local radio = topeTabla(B.Matches, "MapRadius") or 350
		local etiquetaEnemigo = if Config.Combat then Config.Combat.EnemyTag else nil
		local function dinamica(parte: BasePart): boolean
			local actual = parte.Parent
			while actual and actual ~= workspace do
				if
					actual:FindFirstChildOfClass("Humanoid")
					or (etiquetaEnemigo and CollectionService:HasTag(actual, etiquetaEnemigo))
				then
					return true
				end
				actual = actual.Parent
			end
			return false
		end
		local piezas, tris = 0, 0
		for _, parte in workspace:GetPartBoundsInRadius(ancla.Position, radio) do
			if not parte:IsA("Terrain") and not dinamica(parte) then
				piezas += 1
				tris += trisPieza(parte)
			end
		end
		if piezas == 0 then
			return 0, 0, "mapa no medido (no hay piezas alrededor del Basecamp: ¿otro place?)"
		end
		return piezas, tris, ""
	end

	-- ---------------------------------- 8b. Escena de la Isla ----------------------------------
	seccion("## 8b. Escena de la Isla", S.isla, function()
		if not cargarMonos() then
			linea("MonkeyModels no está en este place (ServerScriptService.Combat.Monkeys).")
			return
		end
		local P = B.Matches
		local jugadores = 5

		-- Monos: la mezcla de especies según las tropas de Data/Monkeys. Cada tropa tiene de media (groupMin +
		-- groupMax) / 2 monos y, si la especie tiene alfa, uno de ellos lo es.
		local pesoTotal, piezasMono, trisMono = 0, 0, 0
		local jefeId, jefeMedida = nil :: string?, nil :: Medicion?
		for _, id in claves(Monkeys) do
			local definicion = Monkeys[id]
			local tropa = (definicion.groupMin + definicion.groupMax) / 2
			local alfas = if definicion.alpha == true then 1 else 0
			intentar(id, function()
				local normales = definicion.groups * (tropa - alfas)
				local medida = medirMono(id, false)
				pesoTotal += normales
				piezasMono += normales * medida.piezas
				trisMono += normales * medida.tris
				if alfas > 0 then
					local medidaAlfa = medirMono(id, true)
					pesoTotal += definicion.groups
					piezasMono += definicion.groups * medidaAlfa.piezas
					trisMono += definicion.groups * medidaAlfa.tris
				end
			end)
		end
		local piezasMedia = piezasMono / math.max(pesoTotal, 1)
		local trisMedia = trisMono / math.max(pesoTotal, 1)
		for _, id in claves(Bosses) do
			intentar(id, function()
				local medida = medirJefe(id)
				if jefeMedida == nil or medida.tris > jefeMedida.tris then
					jefeId, jefeMedida = id, medida
				end
			end)
		end

		local equipo = recogerEquipo()
		local mediaV = valoresEquipo(equipo, false, false)
		local peorV = valoresEquipo(equipo, true, false)

		local cercanos = P.MonkeysNearPlayer
		local n = if typeof(cercanos) == "number" then cercanos else 0
		if n == 0 then
			linea("Config.Budgets.Matches.MonkeysNearPlayer todavía no existe: la escena no cuenta monos.")
		end
		linea(
			`Monos con la mezcla de especies de las tropas (media por mono: {math.round(piezasMedia * 10) / 10} piezas, {math.round(
				trisMedia
			)} triángulos); el jefe de más triángulos; {jugadores} jugadores con el equipo medio de lo que existe (armadura o traje, arma, mascota y montura); el mapa alrededor del Basecamp y el pico de efectos en calidad Alta. Las piezas de la tabla no incluyen el mapa ni los efectos (IslandSiegeParts los mide aparte).`
		)
		linea("")
		local piezasMapa, trisMapa, notaMapa = medirMapa()
		local piezasEfectos = B.Vfx.High
		local trisEfectos = piezasEfectos * LIMITES.triangulos.bloque
		linea("| Concepto | Piezas | Triángulos |")
		linea("|---|---|---|")
		local piezasMonos, trisMonos = n * piezasMedia, n * trisMedia
		linea(`| {n} monos | {math.round(piezasMonos)} | {math.round(trisMonos)} |`)
		local piezasJefe, trisJefe =
			if jefeMedida then jefeMedida.piezas else 0, if jefeMedida then jefeMedida.tris else 0
		linea(`| 1 jefe ({jefeId or "—"}) | {piezasJefe} | {trisJefe} |`)
		local piezasJugador, trisJugador = sumaEquipo(mediaV)
		linea(
			`| {jugadores} jugadores, equipo medio | {math.round(piezasJugador * jugadores)} | {math.round(
				trisJugador * jugadores
			)} |`
		)
		linea(`| Mapa (radio {topeTabla(P, "MapRadius") or 350}) | — | {math.round(trisMapa)} |`)
		linea(`| Efectos (pico Alto: {piezasEfectos} piezas × {LIMITES.triangulos.bloque}) | — | {trisEfectos} |`)
		local piezasTotal = piezasMonos + piezasJefe + piezasJugador * jugadores
		local trisTotal = trisMonos + trisJefe + trisJugador * jugadores + trisMapa + trisEfectos
		local topeTris, topePiezas = topeTabla(P, "IslandTriangles"), topeTabla(P, "IslandSiegeParts")
		linea(`| Total | {math.round(piezasTotal)} | {math.round(trisTotal)} |`)
		linea(
			`| Tope (Matches) | {celdaTope(topePiezas)} (IslandSiegeParts) | {celdaTope(topeTris)} (IslandTriangles) |`
		)
		if topePiezas and piezasTotal > topePiezas then
			alerta(`Escena de la Isla: {math.round(piezasTotal)} piezas (IslandSiegeParts {topePiezas})`)
		end
		if topeTris and trisTotal > topeTris then
			alerta(`Escena de la Isla: {math.round(trisTotal)} triángulos (IslandTriangles {topeTris})`)
		end
		local cuota = topeTabla(P, "MonkeyTriangleShare")
		if cuota and topeTris then
			local presupuestoMonos = topeTris * cuota
			linea(
				`| Monos y jefe contra su parte | | {math.round(trisMonos + trisJefe)} de {math.round(presupuestoMonos)} ({cuota * 100} % de IslandTriangles) |`
			)
			if trisMonos + trisJefe > presupuestoMonos then
				alerta(
					`Escena de la Isla: los monos y el jefe suman {math.round(trisMonos + trisJefe)} triángulos (parte de los monos {math.round(
						presupuestoMonos
					)})`
				)
			end
		else
			linea(
				"Config.Budgets.Matches.MonkeyTriangleShare todavía no existe: sin parte de los triángulos para los monos."
			)
		end
		linea("")
		if notaMapa ~= "" then
			linea(`Mapa: {notaMapa}; cuenta 0 triángulos.`)
		else
			linea(
				`Mapa: {piezasMapa} piezas y {math.round(trisMapa)} triángulos alrededor de «{Config.Basecamp.ZonePartName}» (radio {topeTabla(
					P,
					"MapRadius"
				) or 350}). El terreno (Terrain) no se cuenta.`
			)
		end
		-- Solo informativo: el margen que queda si los 5 jugadores llevan lo más pesado de cada tipo.
		local piezasPeor, trisPeor = sumaEquipo(peorV)
		linea(
			`Con los {jugadores} jugadores con el PEOR equipo (solo informativo, sin alerta): {math.round(
				piezasMonos + piezasJefe + piezasPeor * jugadores
			)} piezas y {math.round(trisMonos + trisJefe + trisPeor * jugadores + trisMapa + trisEfectos)} triángulos en total.`
		)

		-- La foto: el equipo medio y el peor de cada familia, para ver el Δ de los grupos de modelos.
		local familiasFoto = {
			{ "Montura", "Montura" },
			{ "Mascota", "Mascota" },
			{ "Armadura/Traje", "Vestimenta" },
			{ "Arma", "Arma" },
		}
		for _, par in familiasFoto do
			local media, peor = mediaV[par[2]], peorV[par[2]]
			FOTO[`Equipo: {par[1]} (media)`] =
				{ piezas = math.round(media.piezas), tris = math.round(media.tris), diseno = 0 }
			FOTO[`Equipo: {par[1]} (máx)`] =
				{ piezas = math.round(peor.piezas), tris = math.round(peor.tris), diseno = 0 }
		end

		-- ---- Reparto del margen ----
		linea("")
		linea("### Reparto del margen")
		if not topeTris then
			linea("Config.Budgets.Matches.IslandTriangles todavía no existe: no hay margen que repartir.")
			return
		end
		local jefeReserva = topeTabla(M.MonkeyTriangles, "Boss") or trisJefe
		local margen = topeTris - trisMonos - jefeReserva - trisMapa - trisEfectos
		local porJugador = margen / jugadores
		linea(
			`Margen = IslandTriangles {topeTris} − monos {math.round(trisMonos)} − jefe {jefeReserva}{if topeTabla(
					M.MonkeyTriangles,
					"Boss"
				)
				then " (tope Boss)"
				else " (medido)"} − mapa {math.round(trisMapa)} − efectos {trisEfectos} = {math.round(margen)}; entre {jugadores} jugadores, {math.round(
				porJugador
			)} cada uno. El equipo medio ya ocupa {math.round(trisJugador)}, y quedan {math.round(
				porJugador - trisJugador
			)} por jugador para repartir en este orden.`
		)
		if margen < 0 then
			alerta(`Escena de la Isla: el margen del equipo es negativo ({math.round(margen)} triángulos)`)
		end
		type Familia = { nombre: string, objetivo: number, hoy: number, max: number, foto: string? }
		local hayRareza = false
		for _, definicion in Pets do
			if typeof(definicion.rarity) == "string" then
				hayRareza = true
				break
			end
		end
		local familias: { Familia } = {
			{ nombre = "Montura", objetivo = 2, hoy = mediaV.Montura.tris, max = peorV.Montura.tris, foto = "Montura" },
		}
		if hayRareza then
			table.insert(familias, {
				nombre = "Mascota estándar",
				objetivo = 1.5,
				hoy = mediaV.MascotaEstandar.tris,
				max = peorV.MascotaEstandar.tris,
				foto = nil,
			})
			table.insert(familias, {
				nombre = "Mascota especial (Mythic y Legendary)",
				objetivo = 2,
				hoy = mediaV.MascotaEspecial.tris,
				max = peorV.MascotaEspecial.tris,
				foto = nil,
			})
		else
			table.insert(familias, {
				nombre = "Mascota",
				objetivo = 1.75,
				hoy = mediaV.Mascota.tris,
				max = peorV.Mascota.tris,
				foto = "Mascota",
			})
		end
		table.insert(familias, {
			nombre = "Armadura/Traje",
			objetivo = 1.6, -- +60 %: es el 84 % del equipo medio, y el margen no da para +100 % (decidido el 03-11-2026)
			hoy = mediaV.Vestimenta.tris,
			max = peorV.Vestimenta.tris,
			foto = "Armadura/Traje",
		})
		table.insert(
			familias,
			{ nombre = "Arma", objetivo = 2, hoy = mediaV.Arma.tris, max = peorV.Arma.tris, foto = "Arma" }
		)
		linea("")
		linea(
			"| Familia | Hoy (media por jugador) | Hoy (máx.) | Objetivo | Extra que pide | Margen restante | Llega |"
		)
		linea("|---|---|---|---|---|---|---|")
		local libre = porJugador - trisJugador
		for _, familia in familias do
			local pide = (familia.objetivo - 1) * familia.hoy
			local concede = math.min(pide, math.max(libre, 0))
			libre -= concede
			local llega = "—"
			if pide > 0 then
				llega = if concede >= pide - 0.5
					then "✅"
					else `⚠️ solo +{math.floor(concede / familia.hoy * 100)} %`
			end
			local delta = ""
			local antes = if BASE and familia.foto then BASE[`Equipo: {familia.foto} (media)`] else nil
			if antes then
				delta = string.format(" (Δ %+d)", math.round(familia.hoy) - antes.tris)
			end
			linea(
				`| {familia.nombre} | {math.round(familia.hoy)}{delta} | {math.round(familia.max)} | +{math.round(
					(familia.objetivo - 1) * 100
				)} % | {math.round(pide)} | {math.round(libre)} | {llega} |`
			)
		end
		linea("")
		local sobra = math.max(libre, 0) * jugadores
		if sobra <= 0 then
			linea("No sobra margen: los monos y la parcela se quedan como están (solo técnicas gratis).")
		else
			local aMonos = math.min(sobra, trisMonos)
			linea(
				`Sobran {math.round(sobra)} triángulos en total ({math.round(libre)} por jugador): a los monos, que van primero, {math.round(
					aMonos
				)} (+{math.round(aMonos / math.max(trisMonos, 1) * 100)} %); a la parcela y los construibles, {math.round(
					sobra - aMonos
				)}.`
			)
		end
	end)

	-- ---------------------------------- 8c. Lobby y Dunas ----------------------------------
	seccion("## 8c. Lobby y Dunas", S.lobbydunas, function()
		local P = B.Matches
		local equipo = recogerEquipo()
		local _, trisMedio = sumaEquipo(valoresEquipo(equipo, false, false))
		local _, trisMedioSin = sumaEquipo(valoresEquipo(equipo, false, true))
		local _, trisPeor = sumaEquipo(valoresEquipo(equipo, true, false))
		local _, trisPeorSin = sumaEquipo(valoresEquipo(equipo, true, true))
		local lobby = topeTabla(P, "LobbyPlayers") or 20
		local dunas = topeTabla(P, "DunasPlayers") or 10
		local otros = lobby - 1
		local topeLobby, topeDunas = topeTabla(P, "LobbyTriangles"), topeTabla(P, "DunasTriangles")
		linea(
			`Solo los cosméticos de los jugadores con el equipo medio de lo que existe (armadura o traje, arma, mascota y montura); no se cuenta el mapa de estos places. En el Lobby, los otros {otros} aplican el LOD de detalle (sin las piezas con la etiqueta «Detalle»). Las mascotas no se fusionan, así que no llevan Detalle.`
		)
		linea("")
		linea("| Escena | Jugadores | Triángulos | Tope | Con el PEOR equipo (informativo) |")
		linea("|---|---|---|---|---|")
		local lobbySin = trisMedio * lobby
		local lobbyCon = trisMedio + trisMedioSin * otros
		local lobbyPeorCon = trisPeor + trisPeorSin * otros
		linea(
			`| Lobby, sin LOD | {lobby} | {math.round(lobbySin)} | {celdaTope(topeLobby)} | {math.round(
				trisPeor * lobby
			)} |`
		)
		linea(
			`| Lobby, con LOD | {lobby} | {math.round(lobbyCon)} | {celdaTope(topeLobby)} | {math.round(lobbyPeorCon)} |`
		)
		local dunasTotal = trisMedio * dunas
		linea(
			`| Dunas | {dunas} | {math.round(dunasTotal)} | {celdaTope(topeDunas)} | {math.round(trisPeor * dunas)} |`
		)
		if topeLobby and lobbyCon > topeLobby then
			alerta(`Lobby con {lobby}: {math.round(lobbyCon)} triángulos de cosméticos (LobbyTriangles {topeLobby})`)
		end
		if topeDunas and dunasTotal > topeDunas then
			alerta(
				`Dunas con {dunas}: {math.round(dunasTotal)} triángulos de cosméticos (DunasTriangles {topeDunas})`
			)
		end
		if not (topeLobby and topeDunas) then
			linea("")
			linea("Los topes con «—» todavía no existen en Config.Budgets.Matches: no alertan.")
		end
	end)

	-- ---------------------------------- 9. Efectos ----------------------------------
	seccion("## 9. Pico de efectos por calidad", S.efectos, function()
		local V = B.Vfx
		local calidades = { "Low", "Medium", "High" }
		local nombres = { Low = "Bajo", Medium = "Medio", High = "Alto" }
		-- BossFx se clona (como esta calculadora) para no usar la versión en caché, y lee la copia de Config.
		local moduloFx = ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("BossFx"):Clone()
		moduloFx.Parent = ServerStorage
		local BossFx = require(moduloFx) :: any
		BossFx.setConfig(Config)
		local carpeta = Instance.new("Folder")
		carpeta.Name = "_BossFxMedicion"
		carpeta.Parent = ServerStorage

		-- Qué efectos lanza cada habilidad de los jefes (Data/Bosses) y cuántos a la vez.
		local function efectos(jefe: any, habilidad: any): { { clase: string, veces: number, params: any } }
			local base = { position = Vector3.zero, uncapped = true, seed = 7 }
			local function con(extra: any): any
				local copiaParams = table.clone(base)
				mezclar(copiaParams, extra)
				return copiaParams
			end
			if habilidad.id == "stomp" then
				return { { clase = "stomp", veces = 1, params = con({ warn = 0.9, radius = 20 }) } }
			elseif habilidad.id == "rockRain" then
				local lava = jefe.eruption == true
				return {
					{
						clase = if lava then "lavaBomb" else "rock",
						veces = habilidad.count or 5,
						params = con({ warn = 1.6, flight = if lava then 1.1 else 0.4, radius = 6 }),
					},
				}
			elseif habilidad.id == "charge" then
				return { { clase = "charge", veces = 1, params = con({ direction = Vector3.zAxis }) } }
			elseif habilidad.id == "grab" then
				return { { clase = "grab", veces = 1, params = con({}) } }
			elseif habilidad.id == "extinguish" then
				return { { clase = "roar", veces = 1, params = con({ radius = Config.BossFx.RoarRadiusStuds }) } }
			end
			return {}
		end

		-- Cuenta las BasePart que deja un efecto (veces seguidas, como en una lluvia) y los marcadores de peligro.
		local function medirEfecto(clase: string, estilo: string, calidad: string, veces: number, params: any)
			local antes = #carpeta:GetChildren()
			local piezas = 0
			for _ = 1, veces do
				piezas += BossFx.play(clase, estilo, carpeta, calidad, params).pieces
			end
			local marcadores = 0
			for _, pieza in carpeta:GetChildren() do
				if pieza.Name == "BossMarker" then
					marcadores += 1
				end
			end
			local contadas = #carpeta:GetChildren() - antes
			carpeta:ClearAllChildren()
			return piezas, contadas, marcadores
		end

		linea(
			`Pico de piezas de efectos de cada jefe por cliente (el mayor de sus ataques; la lluvia de rocas o de lava cuenta todas las de su "count" a la vez, con sus marcadores). Tope: Bajo {V.Low} · Medio {V.Medium} · Alto {V.High} (Config.Budgets.Vfx).`
		)
		linea("")
		linea("| Jefe | Bajo | Medio | Alto | Detalle (efecto × veces → piezas Bajo/Medio/Alto) |")
		linea("|---|---|---|---|---|")
		for _, id in claves(Bosses) do
			if not pasa(id) then
				continue
			end
			local jefe = Bosses[id]
			local picos = { Low = 0, Medium = 0, High = 0 }
			local detalle = {}
			for _, habilidad in jefe.specials do
				for _, efecto in efectos(jefe, habilidad) do
					local porCalidad = {}
					for _, calidad in calidades do
						local piezas, contadas, marcadores =
							medirEfecto(efecto.clase, id, calidad, efecto.veces, efecto.params)
						table.insert(porCalidad, tostring(piezas))
						picos[calidad] = math.max(picos[calidad], piezas)
						if piezas ~= contadas then
							alerta(
								`{id} {efecto.clase} ({nombres[calidad]}): BossFx dice {piezas} piezas y hay {contadas}`
							)
						end
						local peligroso = efecto.clase == "stomp"
							or efecto.clase == "rock"
							or efecto.clase == "lavaBomb"
						if peligroso and marcadores ~= efecto.veces then
							alerta(
								`{id} {efecto.clase} ({nombres[calidad]}): falta el marcador de peligro ({marcadores}/{efecto.veces})`
							)
						end
					end
					table.insert(detalle, `{efecto.clase}×{efecto.veces} → {table.concat(porCalidad, "/")}`)
				end
			end
			linea(`| {id} | {picos.Low} | {picos.Medium} | {picos.High} | {table.concat(detalle, " · ")} |`)
			for _, calidad in calidades do
				if picos[calidad] > V[calidad] then
					alerta(
						`{id}: efectos en calidad {nombres[calidad]} suman {picos[calidad]} piezas (tope {V[calidad]})`
					)
				end
			end
		end
		carpeta:Destroy()
		moduloFx:Destroy()
		linea("")
		linea(
			"Las piezas se piden todas al empezar el efecto (las que aparecen más tarde esperan ocultas), así que esta cuenta es el pico real. No suma efectos distintos a la vez ni las bombas de la erupción del volcán (WeatherService)."
		)
	end)

	-- ---------------------------------- 10. Impactos de armas ----------------------------------
	seccion("## 10. Impactos de armas", S.impactos, function()
		local V = B.Vfx
		local I = Config.ImpactFx
		local calidades = { "Low", "Medium", "High" }
		local nombres = { Low = "Bajo", Medium = "Medio", High = "Alto" }
		-- Ráfaga de referencia: tiradores a la vez, balas de cada uno y segundos que dura (lanzadardos del Laboratorio).
		local tiradores, balas, segundos = 10, 24, 3
		local porSegundo = tiradores * balas / segundos
		local topePulpa = I.Pulp.High * 2
		linea(
			`Pico de piezas de ImpactFx por cliente. Marcas: pool circular de Config.Budgets.ImpactMarks (se recicla la más vieja); pulpa: pool de {topePulpa} cubitos (2 × Pulp.High) que viven 0,45 s; más 1 ancla con los emisores de chispas y polvo. Caso: {tiradores} tiradores, {balas} balas cada uno en {segundos} s ({porSegundo} impactos/s). Tope: Bajo {V.Low} · Medio {V.Medium} · Alto {V.High} (Config.Budgets.Vfx).`
		)
		linea("")
		linea(
			"| Calidad | Impactos en pared mientras dura una marca | Marcas a la vez | Pulpa si todo da en cuerpos | Ancla | Total | Tope |"
		)
		linea("|---|---|---|---|---|---|---|")
		for _, calidad in calidades do
			local enPared = math.floor(porSegundo * (I.MarkSeconds + I.MarkFadeSeconds))
			local marcas = math.min(B.ImpactMarks[calidad], enPared)
			-- Cubitos vivos a la vez: impactos de 0,45 s × cubitos por impacto, acotado por el pool.
			local pulpa = math.min(topePulpa, math.ceil(porSegundo * 0.45) * I.Pulp[calidad])
			local total = marcas + pulpa + 1
			linea(`| {nombres[calidad]} | {enPared} | {marcas} | {pulpa} | 1 | {total} | {V[calidad]} |`)
			if total > V[calidad] then
				alerta(
					`Impactos de armas en calidad {nombres[calidad]}: ráfaga de {tiradores} tiradores suma {total} piezas (tope {V[calidad]})`
				)
			end
		end
		linea("")
		linea(
			"Las marcas siempre llegan al tope del pool con esa ráfaga (por eso el pool las acota) y la pulpa al suyo; el peor caso mezcla las dos. Los efectos de los jefes comparten el mismo tope Vfx (sección 9), pero los impactos de armas de ráfaga no suelen coincidir con un pisotón o una lluvia de rocas."
		)
	end)

	linea("## 11. Alertas")
	if #alertas == 0 then
		linea("✅ Todo dentro de los límites.")
	else
		for _, texto in alertas do
			linea(texto)
		end
	end
	if OPCIONES.foto then
		-- La tabla de monos, alfas y jefes para pegar en src/island/tools/RendimientoBase.luau.
		linea("")
		linea("## Foto (pegar en RendimientoBase.luau)")
		linea("return {")
		for _, nombre in claves(FOTO) do
			local f = FOTO[nombre]
			linea(`\t["{nombre}"] = \{ piezas = {f.piezas}, tris = {f.tris}, diseno = {f.diseno} },`)
		end
		linea("}")
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
	FOTO = {}
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
