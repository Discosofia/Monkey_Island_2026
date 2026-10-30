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
--   8. Totales por escena y el Lobby con 20 jugadores con y sin LOD de detalle (R5).
--   9. Pico de efectos de cada jefe por calidad (R6: combatClient/BossFx contra Config.Budgets.Vfx).
--   10. Impactos de las armas por calidad (W5: combatClient/ImpactFx con una ráfaga de 10 tiradores).
--   11. Alertas: lo que, tras fusionar, pasa del presupuesto.
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
					-- Armas de rol: tope por nivel (rango). Machete y Honda son de rango I; sus mejoras, de rango II.
					local rango = if rol
						then nivel
						elseif id == "Machete" or id == "Honda" then 1
						elseif id == "SharpMachete" or id == "LianaSling" then 2
						else nil
					local presupuesto = if rango then M.ForgeWeaponRank[rango] else nil
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
						if cosmetico.rarity == "Epic"
							then M.WeaponSkinEpic
							elseif cosmetico.rarity == "Rare" then M.WeaponSkinRare
							else M.WeaponSkinMythic
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
					-- Solo el mítico y el legendario tienen presupuesto propio (grado 4); los demás trajes, sin límite.
					local presupuesto = if cosmetico.rarity == "Mythic"
						then M.OutfitMythicGrade4
						elseif cosmetico.rarity == "Legendary" then M.OutfitLegendaryGrade4
						else nil
					fila(
						`{id} ({cosmetico.rarity}, grado {ArmorModels.MAX_GRADE})`,
						medir(pieza, fusionSoldada),
						presupuesto
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
	end)

	-- ---------------------------------- 7. Monos y jefes ----------------------------------
	seccion("## 7. Monos y jefes", S.monos, function()
		local servidor = ServerScriptService:FindFirstChild("Combat")
		local carpeta = servidor and servidor:FindFirstChild("Monkeys")
		local modulo = carpeta and carpeta:FindFirstChild("MonkeyModels")
		if not (modulo and modulo:IsA("ModuleScript")) then
			linea("MonkeyModels no está en este place (ServerScriptService.Combat.Monkeys).")
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
		linea("")
		linea(
			"Pendiente R6: simular la partida de cada escena (mapa, enemigos, estructuras) con las cifras de las secciones 1 a 7."
		)
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
