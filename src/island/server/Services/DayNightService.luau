--!strict
-- Ciclo de día y noche de la partida (GDD §5.1).
-- Lleva la cuenta de días, cambia de fase cuando se acaba el tiempo y avisa a los jugadores.
-- Otros sistemas se enteran del cambio de fase con onPhaseStarted (por ejemplo, los monos).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DayNightService = {}

local skipRequested = false
local stopped = false
local phaseListeners: { (day: number, phase: MatchState.Phase) -> () } = {}

-- Detiene el ciclo (fin de la partida, MatchService). La fase actual se queda congelada.
function DayNightService.stop()
	stopped = true
	skipRequested = true
end

-- Llama a "callback" al empezar cada fase (también la primera: día 1). Regístralo en Init.
function DayNightService.onPhaseStarted(callback: (day: number, phase: MatchState.Phase) -> ())
	table.insert(phaseListeners, callback)
end

-- Termina la fase actual ya (panel de pruebas, p. ej. La Gran Tropa de prueba).
function DayNightService.skipPhase()
	skipRequested = true
end

local function phaseLength(phase: MatchState.Phase): number
	if phase == "Day" then
		return Config.Match.DayLengthSeconds
	end
	return Config.Match.NightLengthSeconds
end

local function announce(day: number, phase: MatchState.Phase)
	if phase == "Night" then
		Remotes.Notify:FireAllClients("🌙 Cae la noche. ¡Quédate cerca del Basecamp!")
	elseif day == 1 then
		Remotes.Notify:FireAllClients("☀️ Día 1: explora la isla y vuelve antes de la noche")
	else
		Remotes.Notify:FireAllClients("☀️ Amanece: día {day}", { day = day })
	end
end

-- Espera hasta que termine la fase (o hasta que se pida saltarla en Studio).
local function waitForPhaseEnd(phase: MatchState.Phase, endsAt: number)
	local warned = false
	while Workspace:GetServerTimeNow() < endsAt and not skipRequested do
		local remaining = endsAt - Workspace:GetServerTimeNow()
		if phase == "Day" and not warned and remaining <= Config.Match.DuskWarningSeconds then
			warned = true
			Remotes.Notify:FireAllClients(
				"🌅 Anochece en {seconds} segundos. ¡Vuelve al Basecamp!",
				{ seconds = Config.Match.DuskWarningSeconds }
			)
		end
		task.wait(0.25)
	end
	skipRequested = false
end

function DayNightService:Start()
	Remotes.DebugSkipPhase.OnServerEvent:Connect(function()
		-- En el juego publicado se ignora: nadie puede saltarse la noche.
		if RunService:IsStudio() then
			DayNightService.skipPhase()
		end
	end)

	local day = 1
	local phase: MatchState.Phase = "Day"
	while not stopped do
		local startedAt = Workspace:GetServerTimeNow()
		local endsAt = startedAt + phaseLength(phase)
		MatchState.write({
			day = day,
			phase = phase,
			phaseStartedAt = startedAt,
			phaseEndsAt = endsAt,
		})
		announce(day, phase)
		for _, listener in phaseListeners do
			task.spawn(listener, day, phase)
		end

		waitForPhaseEnd(phase, endsAt)
		if stopped then
			break
		end

		if phase == "Day" then
			phase = "Night"
		else
			phase = "Day"
			day += 1
		end
	end
end

return DayNightService
