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

return Mallas
