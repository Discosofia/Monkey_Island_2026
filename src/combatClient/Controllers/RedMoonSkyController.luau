--!strict
-- Cielo de la luna roja (Fase 18, B3), en los 4 places. Mientras el evento en vivo "RedMoon" está en marcha
-- tiñe la pantalla con un ColorCorrection propio, que se suma a la luz base (la curva de la Isla o la fija del
-- Lobby, Dunas y el Laboratorio) sin tocarla. En la Isla pesa del todo de noche y Sky.DayWeight de día; en los
-- demás places pesa del todo siempre. Donde no hay ciclo de día (sin MatchState) cambia también la luna del
-- Sky por la roja; en la Isla lo hace LightingController. Los números están en Config.LiveEvents.RedMoon.Sky.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local MatchState = require(ReplicatedStorage.Shared.MatchState)

local sky = Config.LiveEvents.RedMoon.Sky

local RedMoonSkyController = {}

function RedMoonSkyController:Start()
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RedMoonGrade"
	grade.Enabled = false
	grade.Parent = Lighting
	local tint = Color3.fromRGB(sky.Tint[1], sky.Tint[2], sky.Tint[3])
	local amount = 0
	local savedTexture: string? = nil

	RunService.Heartbeat:Connect(function(dt)
		local state = MatchState.read()
		local target = 0
		if LiveEvents.redMoon() then
			target = if state and state.phase == "Day" then sky.DayWeight else 1
		end
		local step = dt / sky.FadeSeconds
		amount = if amount < target then math.min(amount + step, target) else math.max(amount - step, target)
		grade.Enabled = amount > 0.001
		grade.TintColor = Color3.new(1, 1, 1):Lerp(tint, amount)
		grade.Brightness = sky.Brightness * amount
		grade.Saturation = sky.Saturation * amount

		-- Sin ciclo de día no hay LightingController: la luna roja se pone aquí.
		local moonSky = if state then nil else Lighting:FindFirstChildOfClass("Sky")
		if moonSky then
			if LiveEvents.redMoon() then
				if savedTexture == nil then
					savedTexture = moonSky.MoonTextureId
				end
				moonSky.MoonTextureId = Config.Moon.RedMoonTexture
			elseif savedTexture ~= nil then
				moonSky.MoonTextureId = savedTexture
				savedTexture = nil
			end
		end
	end)
end

return RedMoonSkyController
