--!strict
-- Juego de pelota de Dunas: PLACEHOLDER de la Fase 26a. Cumple el contrato (Modes/Types) y no hace nada
-- útil; no está en Config.Arena.Modes, así que no se puede elegir. La lógica real llega en el grupo 26e.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(script.Parent.Types)

local Ballgame = {}

function Ballgame.format(requested: number): number
	return math.clamp(math.floor(requested), Config.Arena.MinFormat, Config.Arena.MaxFormat)
end

function Ballgame.publish(_format: number) end

function Ballgame.full(): boolean
	return false
end

function Ballgame.enough(): boolean
	return false
end

function Ballgame.abandoned(_ctx: Types.Context): boolean
	return false
end

function Ballgame.reset() end

function Ballgame.start(_ctx: Types.Context) end

function Ballgame.tick(_ctx: Types.Context, _phase: Arena.Phase) end

function Ballgame.capture(_teamId: string) end

function Ballgame.stop() end

return Ballgame :: Types.Mode
