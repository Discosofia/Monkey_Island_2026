--!strict
-- Mueve el sol y la luna según la fase del día que manda el servidor y pinta la luz de la hora (Fase 18, B1).
-- Cada cliente lo calcula solo, así no hace falta enviar la hora por la red. La curva está en Config.Lighting.
-- El clima (WeatherController) y el aturdimiento (SurvivalHUDController) tienen sus propios efectos que se
-- suman encima de esta luz; aquí solo se toca la luz base.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)

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

-- Horas del reloj que cubre el día. El reloj corre a la misma velocidad de día y de noche.
local DAY_HOURS = 24 * Config.Match.DayLengthSeconds / (Config.Match.DayLengthSeconds + Config.Match.NightLengthSeconds)
local DAY_START_CLOCK = Config.Lighting.DayCenterClock - DAY_HOURS / 2

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

-- Sitio para los pesos de la luna (B2): recibe la luz de la curva y la hora, y devuelve la luz final.
local function adjust(sample: Sample, _clock: number): Sample
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

	RunService.Heartbeat:Connect(function()
		local state = MatchState.read()
		if not state then
			return
		end
		local clock = clockTimeFor(state, Workspace:GetServerTimeNow())
		Lighting.ClockTime = clock
		local s = adjust(sampleAt(clock), clock)
		Lighting.Ambient = s.Ambient
		Lighting.OutdoorAmbient = s.OutdoorAmbient
		Lighting.Brightness = s.Brightness
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
