--!strict
-- Volcado de los bloques de las partes del cuerpo de un jefe, para `tools/mallas.py` (Fase 21).
-- En el Studio de la Isla, en modo edición (el clon evita la caché de `require`):
--   local m = game.ServerStorage.Tools.Mallas:Clone()
--   require(m).volcar("GorilaAlbino")   -- imprime las partes en la Salida; cópialas a tools/mallas/<Jefe>.txt
--   m:Destroy()
-- Con `monos` (una copia de ServerScriptService.Combat.Monkeys) se prueba un cambio del spec sin la caché. Con `partes`
-- (por ejemplo { "Torso" }) solo se vuelcan esas: la Salida de Studio se trunca por el principio si es muy larga.
-- Cada parte sale como
--   PART Right_Arm <n> <suma de control>
--   x y z ancho alto fondo RRGGBB   (studs, respecto al centro del primer bloque)
--   END
-- La suma de control la comprueba tools/mallas.py: avisa si algún número se estropea al copiar. Solo salen las
-- partes de un lado: el izquierdo es su reflejo (`--espejo Left_Arm=Right_Arm`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)

local PARTES = { "Torso", "Head", "Right Arm", "Right Leg" }

local Mallas = {}

function Mallas.volcar(bossId: string, monos: Instance?, partes: { string }?)
	local boss = (Bosses :: any)[bossId]
	assert(boss, `Jefe desconocido: {bossId}`)
	local carpeta = monos or ServerScriptService.Combat.Monkeys
	local MonkeyModels = require(carpeta.MonkeyModels :: ModuleScript) :: any

	local quiero = partes or PARTES
	local hechas: { [string]: boolean } = {}
	MonkeyModels.setBoxSink(function(main: BasePart, boxes: { BasePart })
		if hechas[main.Name] or not table.find(quiero, main.Name) then
			return
		end
		hechas[main.Name] = true
		local primero = main.Position
		local lineas = {}
		local suma = 0
		local todas = { main, table.unpack(boxes) }
		for _, caja in todas do
			local c = caja.Position - primero
			local x, y, z =
				tonumber(string.format("%.3f", c.X)) :: number,
				tonumber(string.format("%.3f", c.Y)) :: number,
				tonumber(string.format("%.3f", c.Z)) :: number
			local sx, sy, sz =
				tonumber(string.format("%.3f", caja.Size.X)) :: number,
				tonumber(string.format("%.3f", caja.Size.Y)) :: number,
				tonumber(string.format("%.3f", caja.Size.Z)) :: number
			local hex = caja.Color:ToHex()
			suma += x + y * 3 + z * 5 + sx * 7 + sy * 11 + sz * 13 + (tonumber(hex, 16) :: number) % 1000
			table.insert(lineas, string.format("%.3f %.3f %.3f %.3f %.3f %.3f %s", x, y, z, sx, sy, sz, hex))
		end
		print(
			`PART {string.gsub(main.Name, " ", "_")} {#todas} {string.format("%.2f", suma)}\n{table.concat(lineas, "\n")}\nEND`
		)
	end)
	local ok, err = pcall(function()
		local modelo = MonkeyModels.build(boss.baseSpecies, boss, Vector3.new(0, 900, 0), bossId)
		modelo:Destroy()
	end)
	MonkeyModels.setBoxSink(nil)
	assert(ok, err)
	print(`Volcado de {bossId} listo: escala {boss.scale}. Copia las partes a tools/mallas/{bossId}.txt`)
end

-- Volcado de una montura (Fase 21): una parte por hueso, con sus cajas en el espacio del hueso (su pieza invisible) y
-- solo las que puede llevar la malla (`MountModels.meshableBox`: las del aura, los cristales y las giradas se quedan
-- sueltas). Cada hueso sale en trozos de 18 líneas con la etiqueta `@@V <hueso> <nn>`, porque el log del Studio corta
-- cada mensaje a ~1.000 caracteres: `python tools/mallas.py --del-log` los junta en tools/mallas/<Montura>.txt.
--   local m = game.ServerStorage.Tools.Mallas:Clone()
--   require(m).volcarMontura("Llama", game.ReplicatedStorage.Shared:Clone())   -- el clon evita la caché de require
--   m:Destroy()
-- Con `huesos` (por ejemplo { "Body", "Head" }) solo se vuelcan esos.
function Mallas.volcarMontura(mountId: string, shared: Instance?, huesos: { string }?)
	local carpeta = shared or ReplicatedStorage.Shared
	local MountModels = require(carpeta.MountModels :: ModuleScript) :: any
	local mount = (require(carpeta.Data.Mounts :: ModuleScript) :: any)[mountId]
	assert(mount, `Montura desconocida: {mountId}`)
	print(`Volcado de {mountId} empieza`)
	local modelo = MountModels.build(mountId, true) :: Model
	assert(modelo, `{mountId} no tiene modelo`)

	local orden: { string } = {}
	local cajas: { [string]: { BasePart } } = {}
	for _, parte in modelo:GetChildren() do
		local hueso = parte:GetAttribute("Bone")
		if parte:IsA("BasePart") and typeof(hueso) == "string" then
			if not cajas[hueso] then
				cajas[hueso] = {}
				table.insert(orden, hueso)
			end
			table.insert(cajas[hueso], parte)
		end
	end
	for _, nombre in orden do
		if huesos and not table.find(huesos, nombre) then
			continue
		end
		local hueso = modelo:FindFirstChild(nombre) :: BasePart
		-- Los huesos con giro de reposo (la mandíbula del Quetzalcóatl) quedan en el modelo de cajas lejos de donde los
		-- deja la cadena de Motor6D en el juego, y `MountModels.build` coloca la malla con esa cadena: se mide contra
		-- el marco que dan los Motor6D (padre × C0), no contra la posición de la pieza (Q4c, 04-11-2026).
		local function marcoDelHueso(parte: BasePart): CFrame
			for _, motor in modelo:GetDescendants() do
				if motor:IsA("Motor6D") and motor.Part1 == parte and motor.Part0 then
					return marcoDelHueso(motor.Part0) * motor.C0 * motor.C1:Inverse()
				end
			end
			return parte.CFrame
		end
		local marco = Instance.new("Part")
		marco.CFrame = marcoDelHueso(hueso)
		local lineas = {}
		local suma = 0
		for _, caja in cajas[nombre] do
			local centro, tamano = MountModels.meshableBox(caja, marco)
			if not (centro and tamano) then
				continue
			end
			local x, y, z =
				tonumber(string.format("%.4f", centro.X)) :: number,
				tonumber(string.format("%.4f", centro.Y)) :: number,
				tonumber(string.format("%.4f", centro.Z)) :: number
			local sx, sy, sz =
				tonumber(string.format("%.4f", tamano.X)) :: number,
				tonumber(string.format("%.4f", tamano.Y)) :: number,
				tonumber(string.format("%.4f", tamano.Z)) :: number
			local hex = caja.Color:ToHex()
			suma += x + y * 3 + z * 5 + sx * 7 + sy * 11 + sz * 13 + (tonumber(hex, 16) :: number) % 1000
			table.insert(lineas, string.format("%.4f %.4f %.4f %.4f %.4f %.4f %s", x, y, z, sx, sy, sz, hex))
		end
		if #lineas == 0 then
			continue
		end
		table.insert(lineas, 1, `PART {nombre} {#lineas} {string.format("%.2f", suma)}`)
		table.insert(lineas, "END")
		for desde = 1, #lineas, 18 do
			print(
				`@@V {nombre} {string.format("%02d", (desde - 1) // 18 + 1)}\n{table.concat(
					lineas,
					"\n",
					desde,
					math.min(desde + 17, #lineas)
				)}`
			)
		end
	end
	modelo:Destroy()
	print(
		`Volcado de {mountId} listo: size {mount.size}. Ejecuta python tools/mallas.py --del-log <log> tools/mallas/{mountId}.txt`
	)
end

-- Volcado de una mascota (Fase 21): una parte por grupo de piezas que se mueven juntas (`PetModels.meshGroups`: la
-- cabeza, cada pata…) y otra, "Static", con todo lo fijo. Los bloques salen sin escalar (la mascota se escala con
-- `Data/Pets.size`) y respecto al origen de su grupo (la bisagra; el pivote en "Static"), así que las patas izquierda y
-- derecha son reflejo una de otra. Solo salen las piezas que puede llevar la malla (bloques alineados de plástico liso);
-- el resto se queda suelto. Mismos trozos `@@V` que las monturas: `python tools/mallas.py tools/mallas/<Mascota>.txt --del-log`.
--   local m = game.ServerStorage.Tools.Mallas:Clone()
--   require(m).volcarMascota("Capibara", game.ReplicatedStorage.Shared:Clone())   -- el clon evita la caché de require
--   m:Destroy()
function Mallas.volcarMascota(petId: string, shared: Instance?, grupos: { string }?)
	local carpeta = shared or ReplicatedStorage.Shared
	local PetModels = require(carpeta.PetModels :: ModuleScript) :: any
	local pet = (require(carpeta.Data.Pets :: ModuleScript) :: any)[petId]
	assert(pet, `Mascota desconocida: {petId}`)
	print(`Volcado de {petId} empieza`)
	local modelo = PetModels.build(petId, nil, true) :: Model
	assert(modelo, `{petId} no tiene modelo`)
	for _, grupo in PetModels.meshGroups(modelo) do
		if (grupos and not table.find(grupos, grupo.name)) or #grupo.boxes == 0 then
			continue
		end
		local lineas = {}
		local suma = 0
		for _, caja in grupo.boxes do
			local c, t = caja.center, caja.size
			local x, y, z =
				tonumber(string.format("%.4f", c.X)) :: number,
				tonumber(string.format("%.4f", c.Y)) :: number,
				tonumber(string.format("%.4f", c.Z)) :: number
			local sx, sy, sz =
				tonumber(string.format("%.4f", t.X)) :: number,
				tonumber(string.format("%.4f", t.Y)) :: number,
				tonumber(string.format("%.4f", t.Z)) :: number
			local hex = caja.part.Color:ToHex()
			suma += x + y * 3 + z * 5 + sx * 7 + sy * 11 + sz * 13 + (tonumber(hex, 16) :: number) % 1000
			table.insert(lineas, string.format("%.4f %.4f %.4f %.4f %.4f %.4f %s", x, y, z, sx, sy, sz, hex))
		end
		print(`Grupo {grupo.name}: {#grupo.boxes} bloques en malla, {grupo.loose} sueltos, bisagra {grupo.hinge}`)
		table.insert(lineas, 1, `PART {grupo.name} {#grupo.boxes} {string.format("%.2f", suma)}`)
		table.insert(lineas, "END")
		for desde = 1, #lineas, 18 do
			print(
				`@@V {grupo.name} {string.format("%02d", (desde - 1) // 18 + 1)}\n{table.concat(
					lineas,
					"\n",
					desde,
					math.min(desde + 17, #lineas)
				)}`
			)
		end
	end
	modelo:Destroy()
	print(
		`Volcado de {petId} listo: size {pet.size}. Ejecuta python tools/mallas.py tools/mallas/{petId}.txt --del-log y luego --jefe {petId} --escala 1`
	)
end

-- Volcado de una armadura o un traje (Fase 20 Q6): se viste un rig R15 de referencia (`CreateHumanoidModelFromDescription`
-- con una HumanoidDescription vacía, lejos del mapa y sin BodyColors) con la armadura `armorId` de su rol `rol`, o con el
-- traje `outfitId` en el grado `grado` (0..4; sin él, el de `armorId`), sin fusionar bloques y sin usar las mallas de
-- Data/ArmorMeshes. De cada pieza que puede llevar la malla (`ArmorModels.meshableBox`) sale una línea en el espacio de su
-- ancla, agrupada por `<Anclaje>_<Soft|Hard>` (Fabric y Leather, o el resto de materiales lisos); la izquierda y la derecha
-- no se espejan. Mismos trozos `@@V` que las monturas y las mascotas, con el id `Armor_<armorId>_<rol>` o
-- `Outfit_<outfitId>_<grado>`, y una línea `@@REF <id> <Anclaje> x y z` por ancla con su tamaño en el rig de referencia
-- (`ref` de Data/ArmorMeshes). Al final cuenta las piezas que quedan sueltas por grupo y en total.
--   local m = game.ServerStorage.Tools.Mallas:Clone()
--   require(m).volcarArmadura("FurVest", "Guerrero", game.ReplicatedStorage.Shared:Clone())
--   require(m).volcarArmadura(nil, "Cazador", game.ReplicatedStorage.Shared:Clone(), "BlueFireStalkerOutfit", 4)
--   m:Destroy()
-- Luego `python tools/armadura.py exportar Armor_FurVest_Guerrero` (ver su docstring).
function Mallas.volcarArmadura(armorId: string?, rol: string, shared: Instance?, outfitId: string?, grado: number?)
	local carpeta = (shared or ReplicatedStorage.Shared) :: Instance
	-- La copia de Config del clon (la que usa su VoxelMerge): sin fusionar, para volcar las piezas tal como las construyen.
	local config = require(carpeta.Config :: ModuleScript) :: any
	config.Budgets.Merge = false
	local ArmorModels = require(carpeta.ArmorModels :: ModuleScript) :: any
	local id = if outfitId then `Outfit_{outfitId}_{grado or 0}` else `Armor_{armorId}_{rol}`
	print(`Volcado de {id} empieza`)

	local rig =
		Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	for _, hijo in rig:GetChildren() do
		if hijo:IsA("BodyColors") then
			hijo:Destroy()
		end
	end
	rig.Parent = workspace
	rig:PivotTo(CFrame.new(0, 4000, 4000))
	local ok, err = pcall(function()
		local modelo = ArmorModels.wear(rig, armorId, rol, outfitId, grado, true) :: Model?
		assert(modelo, `{id}: no hay nada que vestir (¿armadura, rol o traje desconocidos?)`)

		local lineasDe: { [string]: { string } } = {}
		local sumas: { [string]: number } = {}
		local sueltas: { [string]: number } = {}
		local anclas: { [string]: Vector3 } = {}
		for _, pieza in modelo:GetChildren() do
			local ancla = if pieza:IsA("BasePart") then ArmorModels.anchorOf(pieza) else nil
			if not ancla then
				continue
			end
			local centro, tamano, grupo = ArmorModels.meshableBox(pieza, ancla)
			if not (centro and tamano and grupo) then
				-- Suelta: se cuenta en el grupo que tendría por su material (en las anclas que no son R15, en su nombre).
				local clase = `{ancla.Name}_{ArmorModels.meshClass((pieza :: BasePart).Material)}`
				sueltas[clase] = (sueltas[clase] or 0) + 1
				continue
			end
			anclas[ancla.Name] = ancla.Size
			local x, y, z =
				tonumber(string.format("%.4f", centro.X)) :: number,
				tonumber(string.format("%.4f", centro.Y)) :: number,
				tonumber(string.format("%.4f", centro.Z)) :: number
			local sx, sy, sz =
				tonumber(string.format("%.4f", tamano.X)) :: number,
				tonumber(string.format("%.4f", tamano.Y)) :: number,
				tonumber(string.format("%.4f", tamano.Z)) :: number
			local hex = (pieza :: BasePart).Color:ToHex()
			sumas[grupo] = (sumas[grupo] or 0)
				+ x
				+ y * 3
				+ z * 5
				+ sx * 7
				+ sy * 11
				+ sz * 13
				+ (tonumber(hex, 16) :: number) % 1000
			lineasDe[grupo] = lineasDe[grupo] or {}
			table.insert(lineasDe[grupo], string.format("%.4f %.4f %.4f %.4f %.4f %.4f %s", x, y, z, sx, sy, sz, hex))
		end

		local grupos: { string } = {}
		for grupo in lineasDe do
			table.insert(grupos, grupo)
		end
		table.sort(grupos)
		local enMalla = 0
		for _, grupo in grupos do
			local lineas = lineasDe[grupo]
			enMalla += #lineas
			print(`Grupo {grupo}: {#lineas} bloques en malla, {sueltas[grupo] or 0} sueltos`)
			table.insert(lineas, 1, `PART {grupo} {#lineas} {string.format("%.2f", sumas[grupo])}`)
			table.insert(lineas, "END")
			for desde = 1, #lineas, 18 do
				print(
					`@@V {grupo} {string.format("%02d", (desde - 1) // 18 + 1)}\n{table.concat(
						lineas,
						"\n",
						desde,
						math.min(desde + 17, #lineas)
					)}`
				)
			end
		end
		local nombres: { string } = {}
		for nombre in anclas do
			table.insert(nombres, nombre)
		end
		table.sort(nombres)
		for _, nombre in nombres do
			local t = anclas[nombre]
			print(`@@REF {id} {nombre} {string.format("%.4f %.4f %.4f", t.X, t.Y, t.Z)}`)
		end
		local sueltasTotal = 0
		local etiquetas: { string } = {}
		for clase, n in sueltas do
			sueltasTotal += n
			table.insert(etiquetas, clase)
		end
		table.sort(etiquetas)
		for _, clase in etiquetas do
			print(`Sueltas en {clase}: {sueltas[clase]}`)
		end
		print(
			`Volcado de {id} listo: {enMalla} bloques en {#grupos} grupos de malla, {sueltasTotal} piezas sueltas en total.`
		)
	end)
	rig:Destroy()
	assert(ok, err)
end

return Mallas
