--!strict
-- El "feel" local de la esquiva (Fase 15, V3): lo único que el jugador siente en su cámara al esquivar.
--   - Empujón del campo de visión (esquiva, Evasivo y Embestida, en todos los places): sube rápido a
--     Config.Movement.Dodge.FovKick y vuelve en FovKickSeconds. Se suma a camera.FieldOfView solo la
--     DIFERENCIA de la curva entre fotogramas, para convivir con los tweens de zoom del rifle del
--     Laboratorio, y al acabar ha devuelto exactamente lo sumado. Lo multiplica el ajuste "speedLines"
--     (speedScale: apagado = sin empujón, suave = menos). Al empezar la esquiva también hay una sacudida
--     corta (CameraShake.play, con el ajuste "cameraShake").
--   - active(): verdadero durante el empuje y su arrastre; lo lee SpeedLinesController.
--   - Solo con la esquiva "Dash" (Movement.rules().dodgeStyle, el Laboratorio) y si se pide con
--     begin(dirección, true): inclinación de la cámara hacia el lado de la esquiva (tilt) y el arma de la
--     vista que se aparta (weaponShift). Los lee FirstPersonController cada fotograma.
--   DodgeFeel.begin(direction, view?, seconds?)   empieza el efecto (view: también inclinación y arma)
--   DodgeFeel.kick(degrees) / .speedScale() / .active()   empujón de FOV, escala del ajuste y "dura ahora"
--   DodgeFeel.tilt()                    giro de la cámara sobre su eje de vista (radianes)
--   DodgeFeel.weaponShift()             desplazamiento del arma en el espacio de la cámara (studs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(ReplicatedStorage.Shared.Settings)
local CameraShake = require(script.Parent.CameraShake)
local Movement = require(script.Parent.Movement)

local STEP_NAME = "DodgeFeelFov"

local DodgeFeel = {}

type Kick = { startedAt: number, strength: number }

local kicks: { Kick } = {}
-- Lo que se lleva sumado ahora al campo de visión (grados).
local applied = 0
local bound = false
-- La última esquiva con efecto de vista: cuándo empezó y de qué lado (-1 izquierda … 1 derecha).
local viewStartedAt = -math.huge
local viewSide = 0
-- Hasta cuándo (os.clock) dura el movimiento de la última esquiva.
local activeUntil = -math.huge

-- Curva del empujón: sube en una cuarta parte del tiempo y baja el resto (0 a 1).
local function kickCurve(elapsed: number, seconds: number): number
	if elapsed <= 0 or elapsed >= seconds then
		return 0
	end
	local rise = seconds * 0.25
	return if elapsed < rise then elapsed / rise else 1 - (elapsed - rise) / (seconds - rise)
end

local function stepFov()
	local settings = Config.Movement.Dodge
	local now = os.clock()
	local target = 0
	for index = #kicks, 1, -1 do
		local kick = kicks[index]
		if now - kick.startedAt >= settings.FovKickSeconds then
			table.remove(kicks, index)
		else
			target += kickCurve(now - kick.startedAt, settings.FovKickSeconds) * kick.strength
		end
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView += target - applied
	end
	applied = target
	if #kicks == 0 then
		bound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
end

-- Giro y desplazamiento de la vista: curva que arranca fuerte y se apaga (1 a 0).
local function viewCurve(seconds: number): number
	local alpha = (os.clock() - viewStartedAt) / seconds
	if alpha < 0 or alpha >= 1 then
		return 0
	end
	return (1 - alpha) * (1 - alpha)
end

-- Lo que multiplica el ajuste "speedLines" a las líneas y al empujón del campo de visión (0 = apagado).
function DodgeFeel.speedScale(): number
	return Config.Movement.SpeedLines.Scale[Settings.get().speedLines] or 1
end

-- Empujón del campo de visión de "degrees" grados (con el ajuste "speedLines"); lo usa también Slide.
function DodgeFeel.kick(degrees: number)
	local strength = degrees * DodgeFeel.speedScale()
	if strength > 0 then
		table.insert(kicks, { startedAt = os.clock(), strength = strength })
		if not bound then
			bound = true
			-- Después de la cámara de Roblox y de los tweens del zoom: se suma a donde la dejan.
			RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, stepFov)
		end
	end
end

-- true mientras dura el empuje de la esquiva y su arrastre (para las líneas de velocidad).
function DodgeFeel.active(): boolean
	return os.clock() < activeUntil
end

-- Empieza el efecto en "direction". "seconds": lo que dura el movimiento (empuje más arrastre), para
-- active(). Con "view" también la inclinación y el arma (solo en el estilo "Dash").
function DodgeFeel.begin(direction: Vector3, view: boolean?, seconds: number?)
	local settings = Config.Movement.Dodge
	DodgeFeel.kick(settings.FovKick)
	CameraShake.play(settings.StartShake, settings.StartShakeSeconds)
	activeUntil = os.clock() + (seconds or settings.FovKickSeconds)
	if view and Movement.rules().dodgeStyle == "Dash" then
		local camera = Workspace.CurrentCamera
		viewStartedAt = os.clock()
		viewSide = if camera then math.clamp(direction:Dot(camera.CFrame.RightVector), -1, 1) else 0
	end
end

function DodgeFeel.tilt(): number
	if Movement.rules().dodgeStyle ~= "Dash" then
		return 0
	end
	local settings = Config.Movement.Dodge
	-- Un giro positivo inclina la parte de arriba hacia la izquierda: al esquivar a la derecha, negativo.
	return -viewSide * math.rad(settings.LabTiltDegrees) * viewCurve(settings.LabTiltSeconds)
end

function DodgeFeel.weaponShift(): Vector3
	if Movement.rules().dodgeStyle ~= "Dash" then
		return Vector3.zero
	end
	local shift = Config.Movement.Dodge.LabWeaponShift
	local curve = viewCurve(Config.Movement.Dodge.LabTiltSeconds)
	-- Hacia el lado contrario a la esquiva y un poco atrás y abajo.
	return Vector3.new(-viewSide * shift, -shift * 0.3, shift * 0.3) * curve
end

return DodgeFeel
