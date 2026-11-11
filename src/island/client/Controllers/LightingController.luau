--!strict
-- Mueve el sol y la luna según la fase del día que manda el servidor y pinta la luz de la hora (Fase 18, B1).
-- Cada cliente lo calcula solo, así no hace falta enviar la hora por la red. La curva está en Config.Lighting.
-- El clima (WeatherController) y el aturdimiento (SurvivalHUDController) tienen sus propios efectos que se
-- suman encima de esta luz; aquí solo se toca la luz base.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MoonPhase = require(ReplicatedStorage.Shared.MoonPhase)

type Frame = typeof(Config.Lighting.Keyframes[1])

-- Valores de la luz ya interpolados para una hora.
type Sample = {
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number,
	ColorShift: Color3,
	AtmColor: Color3,
	AtmDecay: Color3,
	AtmDensity: number,
	AtmHaze: number,
	GradeBrightness: number,
	GradeContrast: number,
	GradeSaturation: number,
	GradeTint: Color3,
	Exposure: number,
}

local frames = Config.Lighting.Keyframes

-- Hora forzada solo para grabar vídeos: DebugService (Studio) la pone en este atributo del jugador mientras
-- dura su time-lapse al amanecer, y aquí sustituye a la del servidor. Sin el atributo no cambia nada.
local FORCED_CLOCK_ATTRIBUTE = "DebugClock"

-- Horas del reloj que cubre el día. El reloj corre a la misma velocidad de día y de noche.
local DAY_HOURS = 24 * Config.Match.DayLengthSeconds / (Config.Match.DayLengthSeconds + Config.Match.NightLengthSeconds)
local DAY_START_CLOCK = Config.Lighting.DayCenterClock - DAY_HOURS / 2

-- Hora fijada por una cinemática (Lighting, número 0-24) y segundos opcionales de su fundido de entrada.
local CINEMATIC_CLOCK_ATTRIBUTE = "CinematicClockTime"
local CINEMATIC_CLOCK_SECONDS_ATTRIBUTE = "CinematicClockSeconds"
local CLOCK_IN_SECONDS = 0.4
local CLOCK_OUT_SECONDS = 0.8
-- Horas de más (o de menos) que se dibujan respecto al ciclo real; vale 0 fuera de las escenas.
local clockOffset = 0

local LightingController = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function mix(a: { number }, b: { number }, t: number): Color3
	return color(a):Lerp(color(b), t)
end

-- Interpola la curva entre las dos filas que rodean la hora. Es circular: después de la última fila viene la
-- primera, 24 horas más tarde.
local function sampleAt(clock: number): Sample
	local count = #frames
	local firstH = frames[1].h
	if clock < firstH then
		clock += 24
	end
	local before, after = frames[count], frames[1]
	local beforeH, afterH = frames[count].h, firstH + 24
	for i = 1, count - 1 do
		if clock >= frames[i].h and clock < frames[i + 1].h then
			before, after = frames[i], frames[i + 1]
			beforeH, afterH = before.h, after.h
			break
		end
	end
	local span = afterH - beforeH
	local t = if span > 0 then math.clamp((clock - beforeH) / span, 0, 1) else 0
	-- Suaviza los extremos para que no se note el cambio de fila.
	t = t * t * (3 - 2 * t)
	local function n(a: number, b: number): number
		return a + (b - a) * t
	end
	return {
		Ambient = mix(before.Ambient, after.Ambient, t),
		OutdoorAmbient = mix(before.OutdoorAmbient, after.OutdoorAmbient, t),
		Brightness = n(before.Brightness, after.Brightness),
		ColorShift = mix(before.ColorShift, after.ColorShift, t),
		AtmColor = mix(before.AtmColor, after.AtmColor, t),
		AtmDecay = mix(before.AtmDecay, after.AtmDecay, t),
		AtmDensity = n(before.AtmDensity, after.AtmDensity),
		AtmHaze = n(before.AtmHaze, after.AtmHaze),
		GradeBrightness = n(before.GradeBrightness, after.GradeBrightness),
		GradeContrast = n(before.GradeContrast, after.GradeContrast),
		GradeSaturation = n(before.GradeSaturation, after.GradeSaturation),
		GradeTint = mix(before.GradeTint, after.GradeTint, t),
		Exposure = n(before.Exposure, after.Exposure),
	}
end

-- Cuánto pesa la noche a esa hora (0 de día, 1 en plena noche), con la misma suavidad que la curva.
local function nightWeight(clock: number): number
	local dist = math.abs((clock - Config.Lighting.DayCenterClock + 12) % 24 - 12)
	local moon = Config.Moon
	local t = math.clamp((dist - moon.NightFadeStart) / (moon.NightFadeEnd - moon.NightFadeStart), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Pesos de la luna (B2): recibe la luz de la curva y la hora, y devuelve la luz final. La fase escala la
-- luz de la noche (más oscura con la luna nueva, más clara con la llena); de día no cambia nada. La luna roja
-- (B3) no toca esta luz: su tinte es un ColorCorrection aparte (combatClient/RedMoonSkyController).
local function adjust(sample: Sample, clock: number): Sample
	local phase = MoonPhase.current()
	if not phase then
		return sample
	end
	local scale = 1 + (phase.NightLight - 1) * nightWeight(clock)
	if scale == 1 then
		return sample
	end
	local black = Color3.new()
	sample.Ambient = black:Lerp(sample.Ambient, scale)
	sample.OutdoorAmbient = black:Lerp(sample.OutdoorAmbient, scale)
	sample.Brightness *= scale
	return sample
end

local function clockTimeFor(state: MatchState.State, now: number): number
	local length = state.phaseEndsAt - state.phaseStartedAt
	local progress = if length > 0 then math.clamp((now - state.phaseStartedAt) / length, 0, 1) else 0
	if state.phase == "Day" then
		return DAY_START_CLOCK + DAY_HOURS * progress
	end
	return (DAY_START_CLOCK + DAY_HOURS + (24 - DAY_HOURS) * progress) % 24
end

function LightingController:Start()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DayCycleGrade"
	grade.Parent = Lighting

	RunService.Heartbeat:Connect(function(dt)
		local state = MatchState.read()
		if not state then
			return
		end
		local forced = Players.LocalPlayer:GetAttribute(FORCED_CLOCK_ATTRIBUTE)
		local clock = if typeof(forced) == "number" then forced else clockTimeFor(state, Workspace:GetServerTimeNow())
		-- Una cinemática fija su propia hora con el atributo CinematicClockTime (SceneLight, evento clock): el ciclo
		-- real sigue corriendo por debajo y solo cambia lo que se dibuja. El desfase (horas, por el camino corto) se
		-- acerca a la hora fijada en CLOCK_IN_SECONDS (o en los segundos del atributo CinematicClockSeconds) y de
		-- vuelta a 0 en CLOCK_OUT_SECONDS, sin salto brusco al empezar ni al acabar.
		local pinned = Lighting:GetAttribute(CINEMATIC_CLOCK_ATTRIBUTE)
		local goal = 0
		local speed = 12 / CLOCK_OUT_SECONDS
		if typeof(pinned) == "number" then
			goal = (pinned - clock + 12) % 24 - 12
			local custom = Lighting:GetAttribute(CINEMATIC_CLOCK_SECONDS_ATTRIBUTE)
			speed = 12 / math.max(if typeof(custom) == "number" then custom else CLOCK_IN_SECONDS, 0.05)
		end
		local step = speed * dt
		clockOffset = if clockOffset < goal
			then math.min(clockOffset + step, goal)
			else math.max(clockOffset - step, goal)
		if clockOffset ~= 0 then
			clock = (clock + clockOffset) % 24
		end
		Lighting.ClockTime = clock
		local moon = MoonPhase.current()
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if moon and sky then
			-- La luna del cielo crece hacia la llena y se encoge hacia la nueva.
			-- Una cinemática puede fijar el tamaño (CinematicMoonSize) y la luna roja (CinematicRedMoon, SceneLight).
			local moonSize = Lighting:GetAttribute("CinematicMoonSize")
			sky.MoonAngularSize = if typeof(moonSize) == "number" then moonSize else moon.MoonSize
			-- La luna roja (B3) cambia la imagen; el tinte del cielo lo pone RedMoonSkyController.
			local forcedRed = Lighting:GetAttribute("CinematicRedMoon")
			local redMoon = if typeof(forcedRed) == "number" then forcedRed > 0.5 else LiveEvents.redMoon()
			sky.MoonTextureId = if redMoon then Config.Moon.RedMoonTexture else moon.MoonTexture
		end
		local s = adjust(sampleAt(clock), clock)
		Lighting.Ambient = s.Ambient
		Lighting.OutdoorAmbient = s.OutdoorAmbient
		-- Una cinemática puede bajar la luz del mundo con el atributo (SceneLight, evento brightness): número 0..1.
		local brightnessScale = Lighting:GetAttribute("CinematicBrightnessScale")
		Lighting.Brightness = s.Brightness * (if typeof(brightnessScale) == "number" then brightnessScale else 1)
		Lighting.ColorShift_Top = s.ColorShift
		Lighting.ExposureCompensation = s.Exposure
		atmosphere.Color = s.AtmColor
		atmosphere.Decay = s.AtmDecay
		atmosphere.Density = s.AtmDensity
		atmosphere.Haze = s.AtmHaze
		grade.Brightness = s.GradeBrightness
		grade.Contrast = s.GradeContrast
		grade.Saturation = s.GradeSaturation
		grade.TintColor = s.GradeTint
	end)
end

return LightingController
