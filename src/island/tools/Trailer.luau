--!strict
-- Escenas para grabar el tráiler (docs/videos). Corre en modo edición, en el Studio de la Isla, lejos de
-- ella (no toca nada de la isla salvo la escena "isla", que solo mueve el reloj y lo devuelve):
--
--   local m = game.ServerStorage.Tools.Trailer:Clone() -- el Clone evita la caché de require
--   local T = require(m)
--   T.escena("roles")   -- solo monta la escena (para componer a mano); ids: roles, jefes, huevo, mascotas,
--                       -- monturas, isla
--   T.toma("roles")     -- la monta y lanza su camino de cámara (3 s de cuenta atrás para dar a grabar)
--   T.limpiar()         -- quita Workspace.Trailer, devuelve la luz y deja la cámara en Fixed
--
-- Es un diorama: los jugadores y los jefes están quietos (son los de Portada); las mascotas, las monturas y
-- el huevo se animan en el bucle de la cámara (TrailerCamara.alCuadro).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggModel = require(Shared:WaitForChild("EggModel")) :: any
local PetModels = require(Shared:WaitForChild("PetModels")) :: any
local MountModels = require(Shared:WaitForChild("MountModels")) :: any
local Bosses = require(Shared.Data.Bosses) :: any
local Pets = require(Shared.Data.Pets) :: any
local Portada = require(script.Parent:WaitForChild("Portada")) :: any
local TrailerCamara = require(script.Parent:WaitForChild("TrailerCamara")) :: any

local Trailer = {}

-- Lejos de la isla y de la escena de Portada (4000, 0, 0).
local ORIGEN = Vector3.new(4000, 0, 3000)
local NOMBRE = "Trailer"
local CUENTA_ATRAS = 3 -- segundos para dar a grabar en OBS

type Escena = {
	sinCarpeta: boolean?, -- la escena no construye nada (isla)
	montar: (carpeta: Folder?) -> any,
	camino: (carpeta: Folder?, contexto: any, cuentaAtras: number) -> (),
}

local function v(x: number, y: number, z: number): Vector3
	return ORIGEN + Vector3.new(x, y, z)
end

local function suelo(carpeta: Folder, ancho: number, largo: number, color: Color3)
	local p = Instance.new("Part")
	p.Name = "Suelo"
	p.Size = Vector3.new(ancho, 2, largo)
	p.CFrame = CFrame.new(v(0, -1, 0))
	p.Color = color
	p.Material = Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = false
	p.Parent = carpeta
end

-- Guarda la luz en la carpeta (Trailer.limpiar la devuelve igual que Portada.clear).
local function guardarLuz(carpeta: Folder)
	for _, nombre in Portada.GUARDADAS do
		carpeta:SetAttribute(`Luz_{nombre}`, (Lighting :: any)[nombre])
	end
end

-- Luz de día clara y plana, para las escenas de mascotas, huevo y monturas.
local function luzClara(carpeta: Folder)
	guardarLuz(carpeta)
	Lighting.ClockTime = 15
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(170, 165, 180)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 165, 180)
	Lighting.ColorShift_Top = Color3.new(1, 1, 1)
	Lighting.FogEnd = 100000
end

-- Luz dorada de atardecer, para los roles y los jefes: Portada.iluminacion es de noche y sin volcán detrás
-- se queda a oscuras.
local function luzDorada(carpeta: Folder)
	guardarLuz(carpeta)
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(150, 120, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 140, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 190, 120)
	Lighting.FogEnd = 100000
end

-- Un punto de cámara con su campo de visión.
local function punto(pos: Vector3, mira: Vector3, fov: number?)
	return { pos = pos, mira = mira, fov = fov }
end

-- ===================================== Escenas =====================================

-- Los 4 roles con su mejor equipo, en fila, y un travelling de izquierda a derecha.
local roles: Escena = {
	montar = function(carpeta)
		local c = carpeta :: Folder
		luzDorada(c)
		suelo(c, 300, 200, Color3.fromRGB(120, 96, 80))
		for i, equipo in Portada.EQUIPOS do
			local copia = table.clone(equipo)
			copia.x, copia.z, copia.giro = (i - 2.5) * 9, 0, 0
			Portada.jugador(c, copia, ORIGEN)
			task.wait()
		end
	end,
	camino = function(_, _, cuentaAtras)
		TrailerCamara.camino({
			punto(v(-32, 6, 26), v(-13, 5, 0), 55),
			punto(v(-12, 5.5, 24), v(-4, 5, 0), 52),
			punto(v(12, 5.5, 24), v(4, 5, 0), 52),
			punto(v(32, 6, 26), v(13, 5, 0), 55),
		}, 10, { cuentaAtras = cuentaAtras })
	end,
}

-- Los 4 jefes en fila (el de Ceniza, el final, el último), en su fase 3, con un empujón de cámara a cada uno.
local SEPARACION_JEFES = 60
local ALTO_JEFE = 3.4 -- studs de alto por punto de escala (como Portada.vista)

local jefes: Escena = {
	montar = function(carpeta)
		local c = carpeta :: Folder
		luzDorada(c)
		suelo(c, 400, 200, Color3.fromRGB(120, 96, 80))
		local lista = {}
		for _, datos in Portada.JEFES do
			if datos.id ~= "GorilaDeCeniza" then
				table.insert(lista, datos.id)
			end
		end
		table.insert(lista, "GorilaDeCeniza")
		local info = {}
		for i, id in lista do
			local x = (i - (#lista + 1) / 2) * SEPARACION_JEFES
			Portada.jefe(c, { id = id, x = x, z = 0, giro = 0 }, ORIGEN)
			table.insert(info, { x = x, alto = Bosses[id].scale * ALTO_JEFE })
			task.wait()
		end
		return info
	end,
	camino = function(_, info, cuentaAtras)
		local function empujon(i: number)
			local b = info[i]
			if not b then
				return
			end
			local centro = v(b.x, b.alto * 0.5, 0)
			local d = b.alto * 2.4
			TrailerCamara.camino(
				{
					punto(centro + Vector3.new(-d * 0.35, 0, d), centro, 58),
					punto(centro + Vector3.new(-d * 0.12, b.alto * 0.08, d * 0.55), centro, 52),
				},
				2.6,
				{
					cuentaAtras = if i == 1 then cuentaAtras else nil,
					alTerminar = function()
						empujon(i + 1)
					end,
				}
			)
		end
		empujon(1)
	end,
}

-- Huevo legendario que tiembla cada vez más, estalla y deja salir una mascota que sube girando.
local TIEMPO_HUEVO = 3.5 -- segundos hasta que estalla
local PETS_DEL_HUEVO = { "JaguarCristal", "Quetzal", "Capibara", "Tucan" }

local huevo: Escena = {
	montar = function(carpeta)
		local c = carpeta :: Folder
		luzClara(c)
		suelo(c, 120, 120, Color3.fromRGB(96, 92, 108))
		local modelo = EggModel.build("Legendary", "HuevoTrailer")
		modelo.Parent = c
		local base = v(0, EggModel.HALF_HEIGHT, 0)
		modelo:PivotTo(CFrame.new(base))
		return { huevo = modelo, base = base, estallado = false, mascota = nil }
	end,
	camino = function(c, estado, cuentaAtras)
		local carpeta = c :: Folder
		TrailerCamara.camino(
			{
				punto(v(0, 3.5, 14), v(0, 2.5, 0), 55),
				punto(v(0, 3.2, 8.5), v(0, 3, 0), 55),
			},
			7.5,
			{
				cuentaAtras = cuentaAtras,
				alCuadro = function(_, t)
					if t < TIEMPO_HUEVO then
						local fuerza = (t / TIEMPO_HUEVO) ^ 2
						local temblor = math.sin(t * (24 + t * 8)) * (0.03 + 0.2 * fuerza)
						estado.huevo:PivotTo(
							CFrame.new(estado.base + Vector3.new(temblor * 0.3, 0, 0)) * CFrame.Angles(0, 0, temblor)
						)
						return
					end
					if not estado.estallado then
						estado.estallado = true
						estado.huevo:Destroy()
						EggModel.burst(estado.base, "Legendary", carpeta)
						for _, id in PETS_DEL_HUEVO do
							local mascota = PetModels.build(id)
							if mascota then
								mascota.Parent = carpeta
								estado.mascota = mascota
								break
							end
						end
					end
					local mascota = estado.mascota
					if mascota then
						local tt = t - TIEMPO_HUEVO
						local altura = mascota:GetAttribute("Height")
						local lift = if typeof(altura) == "number" then altura else 1.5
						local sube = math.min(tt / 0.6, 1)
						mascota:PivotTo(
							CFrame.new(v(0, 0.6 + lift * 0.5 + sube * 2.2, 0)) * CFrame.Angles(0, tt * 1.8, 0)
						)
						PetModels.animate(mascota, t, 0)
					end
				end,
			}
		)
	end,
}

-- Desfile de mascotas: todas en fila mirando a la cámara, andando en el sitio, y un travelling a lo largo.
local SEPARACION_MASCOTAS = 7

local mascotas: Escena = {
	montar = function(carpeta)
		local c = carpeta :: Folder
		luzClara(c)
		suelo(c, 400, 80, Color3.fromRGB(96, 92, 108))
		local ids = {}
		for id in Pets do
			table.insert(ids, id)
		end
		table.sort(ids)
		local lista = {}
		for _, id in ids do
			local modelo = PetModels.build(id)
			if modelo then -- los que no tienen constructor se omiten
				table.insert(lista, modelo)
			end
		end
		local info = { modelos = lista, ancho = 0 }
		for i, modelo in lista do
			local x = (i - (#lista + 1) / 2) * SEPARACION_MASCOTAS
			local altura = modelo:GetAttribute("Height")
			local lift = if typeof(altura) == "number" then altura else 1.5
			modelo:PivotTo(CFrame.new(v(x, lift, 0)) * CFrame.Angles(0, math.pi, 0))
			modelo.Parent = c
		end
		info.ancho = #lista * SEPARACION_MASCOTAS
		return info
	end,
	camino = function(_, info, cuentaAtras)
		local mitad = info.ancho / 2
		local puntos = {}
		for i = 0, 4 do
			local x = -mitad + (info.ancho * i) / 4
			table.insert(puntos, punto(v(x - 6, 3.5, 14), v(x + 4, 1.8, 0), 55))
		end
		TrailerCamara.camino(puntos, 16, {
			cuentaAtras = cuentaAtras,
			alCuadro = function(_, t)
				for i, modelo in info.modelos do
					PetModels.animate(modelo, t + i * 0.37, 1)
				end
			end,
		})
	end,
}

-- Llama, Jaguar y Quetzalcóatl; este último planeando. Mirando a la cámara en tres cuartos.
local MONTURAS = { "Llama", "Jaguar", "Quetzalcoatl" }
local SEPARACION_MONTURAS = 30
local ALTURA_PLANEO = 12

local monturas: Escena = {
	montar = function(carpeta)
		local c = carpeta :: Folder
		luzClara(c)
		suelo(c, 200, 80, Color3.fromRGB(96, 92, 108))
		local info = {}
		for i, id in MONTURAS do
			local modelo = MountModels.build(id)
			if modelo then
				local x = (i - 2) * SEPARACION_MONTURAS
				local alto = if id == "Quetzalcoatl" then ALTURA_PLANEO else 0
				modelo:PivotTo(CFrame.new(v(x, alto, 0)) * CFrame.Angles(0, math.rad(-120), 0))
				modelo.Parent = c
				table.insert(info, { modelo = modelo, x = x, alto = alto, planea = id == "Quetzalcoatl" })
			end
		end
		return info
	end,
	camino = function(_, info, cuentaAtras)
		TrailerCamara.camino(
			{
				punto(v(-46, 5, 34), v(-30, 3, 0), 58),
				punto(v(-14, 5, 32), v(0, 4, 0), 56),
				punto(v(16, 7, 34), v(30, 11, 0), 58),
				punto(v(46, 9, 34), v(30, 12, 0), 58),
			},
			12,
			{
				cuentaAtras = cuentaAtras,
				alCuadro = function(dt, t)
					for _, m in info do
						local alto = m.alto
						if m.planea then
							alto += math.sin(t * 1.4) * 0.8
						end
						local cf = CFrame.new(v(m.x, alto, 0)) * CFrame.Angles(0, math.rad(-120), 0)
						m.modelo:PivotTo(cf)
						MountModels.animate(m.modelo, dt, if m.planea then 0 else 0.5, if m.planea then 1 else 0, {})
					end
				end,
			}
		)
	end,
}

-- Vuelo de dron sobre la isla real, del amanecer a la noche. No construye nada: solo mueve el reloj.
-- La isla tiene el centro en el origen, el volcán al noreste (x +, z -) y la playa al sur (z +).
local DURACION_ISLA = 24
local RELOJ_AMANECER = 5.5
local RELOJ_NOCHE = 21
local relojIsla: number? = nil -- ClockTime que había antes de la escena "isla"

local isla: Escena = {
	sinCarpeta = true,
	montar = function()
		if relojIsla == nil then
			relojIsla = Lighting.ClockTime
		end
		Lighting.ClockTime = RELOJ_AMANECER
	end,
	camino = function(_, _, cuentaAtras)
		TrailerCamara.camino(
			{
				punto(Vector3.new(-300, 70, 1050), Vector3.new(-100, 10, 750), 70),
				punto(Vector3.new(-150, 60, 800), Vector3.new(0, 20, 400), 70),
				punto(Vector3.new(-20, 75, 350), Vector3.new(200, 30, -100), 70),
				punto(Vector3.new(120, 110, -50), Vector3.new(399, 150, -399), 70),
				punto(Vector3.new(330, 260, -250), Vector3.new(399, 140, -399), 65),
				punto(Vector3.new(560, 300, -420), Vector3.new(399, 130, -399), 60),
			},
			DURACION_ISLA,
			{
				cuentaAtras = cuentaAtras,
				alCuadro = function(_, t)
					Lighting.ClockTime = RELOJ_AMANECER
						+ (RELOJ_NOCHE - RELOJ_AMANECER) * math.min(t / DURACION_ISLA, 1)
				end,
				alTerminar = function()
					if relojIsla ~= nil then
						Lighting.ClockTime = relojIsla
						relojIsla = nil
					end
				end,
			}
		)
	end,
}

local ESCENAS: { [string]: Escena } = {
	roles = roles,
	jefes = jefes,
	huevo = huevo,
	mascotas = mascotas,
	monturas = monturas,
	isla = isla,
}

-- ===================================== API =====================================

-- Quita la escena montada, devuelve la luz y deja la cámara en Fixed.
function Trailer.limpiar()
	TrailerCamara.parar()
	local carpeta = Workspace:FindFirstChild(NOMBRE)
	if carpeta then
		for _, nombre in Portada.GUARDADAS do
			local valor = carpeta:GetAttribute(`Luz_{nombre}`)
			if valor ~= nil then
				(Lighting :: any)[nombre] = valor
			end
		end
		carpeta:Destroy()
	end
	if relojIsla ~= nil then
		Lighting.ClockTime = relojIsla
		relojIsla = nil
	end
end

-- Monta la escena (sin mover la cámara). Devuelve la carpeta (nil en "isla") y lo que necesite su camino.
local function monta(id: string): (Folder?, any)
	local def = ESCENAS[id]
	assert(def, `Escena desconocida: {id}`)
	Trailer.limpiar()
	if def.sinCarpeta then
		return nil, def.montar(nil)
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = NOMBRE
	-- Dentro del Workspace desde el principio: las uniones de los rigs solo recolocan sus piezas allí.
	carpeta.Parent = Workspace
	return carpeta, def.montar(carpeta)
end

function Trailer.escena(id: string): Folder?
	local carpeta = monta(id)
	return carpeta
end

-- Monta la escena y lanza su camino de cámara. "cuentaAtras": segundos antes de moverse (3 por defecto).
function Trailer.toma(id: string, cuentaAtras: number?)
	local carpeta, contexto = monta(id)
	ESCENAS[id].camino(carpeta, contexto, cuentaAtras or CUENTA_ATRAS)
end

return Trailer
