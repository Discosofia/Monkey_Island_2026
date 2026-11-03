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
		local lineas = {}
		local suma = 0
		for _, caja in cajas[nombre] do
			local centro, tamano = MountModels.meshableBox(caja, hueso)
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

return Mallas
