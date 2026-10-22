--!strict
-- Escalado de un combo en PvP (Fase 10, C7; Config.ComboScaling): cuantos más golpes seguidos recibe un
-- jugador de otros jugadores, menos le hace cada uno y menos le dura el tambaleo. Así ningún combo largo
-- (ni dos rivales a la vez) quita la vida entera sin dejar responder.
--   - Se cuenta por víctima (no por atacante) y se reinicia tras ResetSeconds sin recibir, al bloquear o
--     parar un golpe y con el Evasivo (reset).
--   - Cada habilidad cuenta como un golpe aunque pegue varias veces (el Torbellino, la Lluvia): sus
--     golpes llevan la misma clave ("key"). Los del arma cuentan uno a uno. El veneno no cuenta.
-- Lo usa CombatService.damagePvP; la calculadora (sección 9, "escalaCombo") hace la misma cuenta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local SETTINGS = Config.ComboScaling

type Sequence = {
	hits: number,
	lastAt: number,
	keys: { [string]: boolean },
}

local ComboScaling = {}

local sequences: { [Player]: Sequence } = {}

-- Fracción del daño del golpe número "hit" de un combo.
function ComboScaling.damageFactor(hit: number): number
	if hit < SETTINGS.FromHit then
		return 1
	end
	return math.max(SETTINGS.MinDamage, 1 - SETTINGS.DamageStep * (hit - SETTINGS.FromHit + 1))
end

-- Fracción del tambaleo del golpe número "hit" de un combo.
function ComboScaling.hitstunFactor(hit: number): number
	if hit < SETTINGS.FromHit then
		return 1
	end
	return math.max(SETTINGS.MinHitstun, 1 - SETTINGS.HitstunStep * (hit - SETTINGS.FromHit + 1))
end

-- Apunta que a "victim" le entra un golpe (con "key", los de una misma habilidad cuentan una vez) y
-- devuelve qué número de golpe es en su combo.
function ComboScaling.register(victim: Player, key: string?): number
	local time = Workspace:GetServerTimeNow()
	local sequence = sequences[victim]
	if not sequence or time - sequence.lastAt >= SETTINGS.ResetSeconds then
		sequence = { hits = 0, lastAt = time, keys = {} }
		sequences[victim] = sequence
	end
	sequence.lastAt = time
	if not (key and sequence.keys[key]) then
		sequence.hits += 1
		if key then
			sequence.keys[key] = true
		end
	end
	return sequence.hits
end

-- Número del último golpe que le ha entrado a "victim" en su combo (0 si no hay combo en marcha).
function ComboScaling.current(victim: Player): number
	local sequence = sequences[victim]
	if not sequence or Workspace:GetServerTimeNow() - sequence.lastAt >= SETTINGS.ResetSeconds then
		return 0
	end
	return sequence.hits
end

-- Termina el combo que recibe "victim" (ha bloqueado, parado o usado el Evasivo).
function ComboScaling.reset(victim: Player)
	sequences[victim] = nil
end

Players.PlayerRemoving:Connect(function(player)
	sequences[player] = nil
end)

return ComboScaling
