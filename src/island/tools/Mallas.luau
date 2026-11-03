--!strict
-- Volcado de los bloques de las partes del cuerpo de un jefe, para `tools/mallas.py` (Fase 21).
-- En el Studio de la Isla, en modo edición (el clon evita la caché de `require`):
--   local m = game.ServerStorage.Tools.Mallas:Clone()
--   require(m).volcar("GorilaAlbino")   -- imprime las partes en la Salida; cópialas a tools/mallas/<Jefe>.txt
--   m:Destroy()
-- Con `monos` (una copia de ServerScriptService.Combat.Monkeys) se prueba un cambio del spec sin la caché.
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

function Mallas.volcar(bossId: string, monos: Instance?)
	local boss = (Bosses :: any)[bossId]
	assert(boss, `Jefe desconocido: {bossId}`)
	local carpeta = monos or ServerScriptService.Combat.Monkeys
	local MonkeyModels = require(carpeta.MonkeyModels :: ModuleScript) :: any

	local hechas: { [string]: boolean } = {}
	MonkeyModels.setBoxSink(function(main: BasePart, boxes: { BasePart })
		if hechas[main.Name] or not table.find(PARTES, main.Name) then
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

return Mallas
