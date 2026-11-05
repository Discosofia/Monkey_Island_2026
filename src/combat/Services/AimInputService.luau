--!strict
-- Qué control usa cada jugador (Config.AimAssist): el cliente avisa con Remotes.ReportInput ("Touch" |
-- "Mouse" | "Gamepad") cuando cambia. El servidor guarda el último tipo, lo publica como atributo del
-- Player "AimInput" (el tipo declarado, sin retraso) y dice si cuenta como táctil para la ayuda de
-- puntería (CombatService.aimShot): pasar a táctil no cuenta hasta pasado SwitchDelaySeconds, y pasar a
-- ratón o mando, al momento. Sin ningún aviso aún, no es táctil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AimViews = require(ReplicatedStorage.Shared.Data.AimViews)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type State = { kind: string, effectiveAt: number, lastReport: number }

local VALID: { [string]: boolean } = { Touch = true, Mouse = true, Gamepad = true }

local states: { [Player]: State } = {}

local AimInputService = {}

-- true si "player" usa un control táctil desde hace lo bastante para que cuente.
function AimInputService.isTouch(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.kind == "Touch" and os.clock() >= state.effectiveAt
end

function AimInputService:Start()
	local settings = Config.AimAssist
	Remotes.ReportInput.OnServerEvent:Connect(function(player: Player, kind: unknown)
		if typeof(kind) ~= "string" or not VALID[kind] then
			return
		end
		local now = os.clock()
		local state = states[player]
		-- Mitad del intervalo del cliente: la red agrupa avisos y no debe perderse un cambio legítimo.
		if state and now - state.lastReport < settings.ReportMinInterval * 0.5 then
			return
		end
		local previous = if state then state.kind else nil
		local effectiveAt = 0
		if kind == "Touch" then
			-- Sigue contando si ya era táctil; si viene de otro control, espera un poco.
			effectiveAt = if previous == "Touch" and state then state.effectiveAt else now + settings.SwitchDelaySeconds
		end
		states[player] = { kind = kind, effectiveAt = effectiveAt, lastReport = now }
		player:SetAttribute("AimInput", kind)
	end)
	-- La vista con que apunta (Data/AimViews), como atributo "AimView": la calibración del campo de tiro la lee.
	Remotes.ReportAimView.OnServerEvent:Connect(function(player: Player, view: unknown)
		if typeof(view) == "string" and AimViews.names[view] ~= nil then
			player:SetAttribute("AimView", view)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

return AimInputService
