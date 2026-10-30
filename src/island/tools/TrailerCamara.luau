--!strict
-- Cámara por caminos para grabar los vídeos (docs/videos). Sin dependencias del juego: se puede pegar tal
-- cual por MCP en el Studio de Dunas o del Laboratorio. Corre en modo edición (RunService.PreRender); si
-- allí no avanza, se graba en Run (F8).
--
--   local C = require(game.ServerStorage.Tools.TrailerCamara:Clone()) -- el Clone evita la caché de require
--   C.guia(true)                                  -- recuadro 9:16 para componer (apagar al grabar)
--   C.camino({
--       { pos = Vector3.new(0, 20, 0), mira = Vector3.new(0, 10, 50), fov = 70 },
--       { pos = Vector3.new(30, 12, 40), mira = Vector3.new(0, 10, 50) },
--   }, 8, { cuentaAtras = 3 })                    -- 3 s para dar a grabar en OBS
--   C.orbita(centro, 40, 15, 360, 10)             -- vuelta alrededor de un punto
--   C.parar()                                     -- corta y deja la cámara en Fixed

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrailerCamara = {}

export type Punto = { pos: Vector3, mira: Vector3, fov: number? }
export type Opciones = {
	cuentaAtras: number?, -- segundos quietos en el primer punto antes de moverse
	suave: boolean?, -- aceleración suave al empezar y al acabar (por defecto sí)
	alCuadro: ((dt: number, t: number) -> ())?, -- cada cuadro, con los segundos desde que arranca el camino
	alTerminar: (() -> ())?, -- al llegar al final (no se llama si se corta con parar)
}

local FOV_POR_DEFECTO = 70
local PASO_ORBITA = 15 -- grados entre punto y punto de la órbita

local conexion: RBXScriptConnection? = nil
local guiaGui: ScreenGui? = nil
local guiaConexion: RBXScriptConnection? = nil
local cuentaGui: ScreenGui? = nil

-- Dónde colgar las interfaces: el PlayerGui en Play y la CoreGui en modo edición.
local function contenedorGui(): Instance?
	local jugador = Players.LocalPlayer
	if jugador then
		local pg = jugador:FindFirstChildOfClass("PlayerGui")
		if pg then
			return pg
		end
	end
	local ok, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	return if ok then core else nil
end

local function nuevaGui(nombre: string): ScreenGui?
	local padre = contenedorGui()
	if not padre then
		return nil
	end
	local viejo = padre:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = nombre
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = padre
	return gui
end

-- Catmull-Rom uniforme entre p1 y p2 (p0 y p3 son los vecinos).
local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

-- Posición, mirada y fov del camino en u (0 a 1).
local function muestra(puntos: { Punto }, fovs: { number }, u: number): (Vector3, Vector3, number)
	local n = #puntos
	if n == 1 then
		return puntos[1].pos, puntos[1].mira, fovs[1]
	end
	local tramos = n - 1
	local s = math.clamp(u, 0, 1) * tramos
	local i = math.min(math.floor(s) + 1, tramos)
	local f = s - (i - 1)
	local a, b = puntos[math.max(i - 1, 1)], puntos[math.min(i + 2, n)]
	local p1, p2 = puntos[i], puntos[i + 1]
	local pos = catmull(a.pos, p1.pos, p2.pos, b.pos, f)
	local mira = catmull(a.mira, p1.mira, p2.mira, b.mira, f)
	return pos, mira, fovs[i] + (fovs[i + 1] - fovs[i]) * f
end

local function suavizar(u: number): number
	return u * u * (3 - 2 * u)
end

local function cortarBucle()
	if conexion then
		conexion:Disconnect()
		conexion = nil
	end
	if cuentaGui then
		cuentaGui:Destroy()
		cuentaGui = nil
	end
end

-- Corta el camino y deja la cámara en Fixed (el estado normal de la cámara de edición).
function TrailerCamara.parar()
	cortarBucle()
	local camara = Workspace.CurrentCamera
	if camara then
		camara.CameraType = Enum.CameraType.Fixed
	end
end

-- Mueve la cámara por los puntos en "segundos". Cada punto lleva dónde está la cámara, a dónde mira y,
-- si quiere, su campo de visión. Con un solo punto la deja quieta ese tiempo.
function TrailerCamara.camino(puntos: { Punto }, segundos: number, opciones: Opciones?)
	assert(#puntos >= 1, "TrailerCamara.camino: hacen falta puntos")
	cortarBucle()
	local camara = Workspace.CurrentCamera
	local opts: Opciones = opciones or {}
	local suave = opts.suave ~= false
	local espera = opts.cuentaAtras or 0
	local alCuadro, alTerminar = opts.alCuadro, opts.alTerminar

	local fovs: { number } = {}
	local previo = camara.FieldOfView
	for i, p in puntos do
		previo = p.fov or (if i == 1 then FOV_POR_DEFECTO else previo)
		fovs[i] = previo
	end

	camara.CameraType = Enum.CameraType.Scriptable
	local function pon(u: number)
		local pos, mira, fov = muestra(puntos, fovs, if suave then suavizar(u) else u)
		camara.FieldOfView = fov
		camara.CFrame = CFrame.lookAt(pos, mira)
	end
	pon(0)

	if espera > 0 then
		cuentaGui = nuevaGui("TrailerCuentaAtras")
		if cuentaGui then
			local texto = Instance.new("TextLabel")
			texto.Name = "Numero"
			texto.AnchorPoint = Vector2.new(0.5, 0.5)
			texto.Position = UDim2.fromScale(0.5, 0.5)
			texto.Size = UDim2.fromOffset(200, 200)
			texto.BackgroundTransparency = 1
			texto.TextColor3 = Color3.new(1, 1, 1)
			texto.TextStrokeTransparency = 0
			texto.TextSize = 150
			texto.Font = Enum.Font.BuilderSansBold
			texto.Text = tostring(math.ceil(espera))
			texto.Parent = cuentaGui
		end
	end

	local transcurrido = 0 -- segundos desde que acabó la cuenta atrás
	local cuenta = espera
	conexion = RunService.PreRender:Connect(function(dt: number)
		if cuenta > 0 then
			cuenta -= dt
			if cuentaGui then
				local numero = cuentaGui:FindFirstChild("Numero") :: TextLabel?
				if numero then
					numero.Text = tostring(math.max(1, math.ceil(cuenta)))
				end
				if cuenta <= 0 then
					cuentaGui:Destroy()
					cuentaGui = nil
				end
			end
			return
		end
		transcurrido += dt
		local u = if segundos > 0 then math.min(transcurrido / segundos, 1) else 1
		pon(u)
		if alCuadro then
			alCuadro(dt, transcurrido)
		end
		if u >= 1 then
			-- La cámara se queda en el último cuadro (Scriptable) hasta que se llame a parar.
			cortarBucle()
			if alTerminar then
				alTerminar()
			end
		end
	end)
end

-- Vuelta alrededor de "centro": la cámara a "radio" studs y "alto" por encima, girando "grados" (360 es
-- una vuelta entera; negativo, al revés), siempre mirando al centro.
function TrailerCamara.orbita(
	centro: Vector3,
	radio: number,
	alto: number,
	grados: number,
	segundos: number,
	opciones: Opciones?
)
	local pasos = math.max(3, math.ceil(math.abs(grados) / PASO_ORBITA))
	local puntos: { Punto } = {}
	for i = 0, pasos do
		local a = math.rad(grados * i / pasos)
		table.insert(puntos, {
			pos = centro + Vector3.new(math.sin(a) * radio, alto, math.cos(a) * radio),
			mira = centro,
		})
	end
	TrailerCamara.camino(puntos, segundos, opciones)
end

-- Recuadro 9:16 centrado para componer los planos que luego se recortan en vertical (Shorts y TikTok):
-- marco fino y el resto de la pantalla oscurecido al 60 %. Se apaga antes de grabar.
function TrailerCamara.guia(activa: boolean)
	if guiaConexion then
		guiaConexion:Disconnect()
		guiaConexion = nil
	end
	if guiaGui then
		guiaGui:Destroy()
		guiaGui = nil
	end
	if not activa then
		return
	end
	local gui = nuevaGui("TrailerGuia")
	if not gui then
		return
	end
	guiaGui = gui

	local function barra(nombre: string): Frame
		local f = Instance.new("Frame")
		f.Name = nombre
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 0.4
		f.BorderSizePixel = 0
		f.Parent = gui
		return f
	end
	local izquierda, derecha = barra("Izquierda"), barra("Derecha")
	local marco = Instance.new("Frame")
	marco.Name = "Marco"
	marco.BackgroundTransparency = 1
	marco.BorderSizePixel = 0
	marco.Parent = gui
	local linea = Instance.new("UIStroke")
	linea.Color = Color3.new(1, 1, 1)
	linea.Thickness = 1
	linea.Parent = marco

	local function coloca()
		local camara = Workspace.CurrentCamera
		local vp = camara.ViewportSize
		local ancho = math.min(vp.X, vp.Y * 9 / 16)
		local lado = (vp.X - ancho) / 2
		izquierda.Position = UDim2.fromOffset(0, 0)
		izquierda.Size = UDim2.fromOffset(lado, vp.Y)
		derecha.Position = UDim2.fromOffset(lado + ancho, 0)
		derecha.Size = UDim2.fromOffset(lado, vp.Y)
		marco.Position = UDim2.fromOffset(lado, 0)
		marco.Size = UDim2.fromOffset(ancho, vp.Y)
	end
	coloca()
	guiaConexion = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(coloca)
end

return TrailerCamara
