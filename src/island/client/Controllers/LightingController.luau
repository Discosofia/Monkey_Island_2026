--!strict
-- Mueve el sol y la luna según la fase del día que manda el servidor.
-- Cada cliente lo calcula solo, así no hace falta enviar la hora por la red.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MatchState = require(ReplicatedStorage.Shared.MatchState)

-- Hora del reloj de Roblox (0-24) al empezar el día y la noche.
local SUNRISE_CLOCK = 6
local SUNSET_CLOCK = 18

local LightingController = {}

local function clockTimeFor(state: MatchState.State, now: number): number
	local length = state.phaseEndsAt - state.phaseStartedAt
	local progress = if length > 0 then math.clamp((now - state.phaseStartedAt) / length, 0, 1) else 0
	if state.phase == "Day" then
		return SUNRISE_CLOCK + (SUNSET_CLOCK - SUNRISE_CLOCK) * progress
	end
	return (SUNSET_CLOCK + (24 - SUNSET_CLOCK + SUNRISE_CLOCK) * progress) % 24
end

function LightingController:Start()
	RunService.Heartbeat:Connect(function()
		local state = MatchState.read()
		if state then
			Lighting.ClockTime = clockTimeFor(state, Workspace:GetServerTimeNow())
		end
	end)
end

return LightingController
