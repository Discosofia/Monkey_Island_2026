--!strict
-- El contrato de un modo de juego de Dunas (Config.Arena.Modes). ArenaMatchService se queda con lo común
-- (Waiting, Countdown, Results, la cancelación y el aviso de fin) y le pide al modo en curso lo que cambia:
-- cuántos faltan para empezar, cómo se puntúa, cuándo acaba y quién gana. Como Laboratorio/server/Modes/Types.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Arena)

-- Lo que ArenaMatchService le presta al modo.
export type Context = {
	setPhase: (phase: Arena.Phase, seconds: number?) -> (),
	-- El equipo ganador (nil: empate).
	finish: (winner: string?) -> (),
	isSolo: () -> boolean,
}

export type Mode = {
	-- El formato válido de este modo más cercano al pedido (jugadores por equipo).
	format: (requested: number) -> number,
	-- Pone en ReplicatedStorage lo que el HUD lee de este modo con este formato.
	publish: (format: number) -> (),
	-- En Waiting: ¿están los dos equipos completos? (con todos listos, empieza la cuenta atrás).
	full: () -> boolean,
	-- En Waiting, al acabar la espera: ¿hay gente en los dos equipos?
	enough: () -> boolean,
	-- En Countdown y en plena partida: ¿se ha quedado un equipo vacío? (nunca en solitario)
	abandoned: (ctx: Context) -> boolean,
	-- Vuelve a Waiting: marcador a cero.
	reset: () -> (),
	-- Empieza la partida: marcador y estadísticas del modo a cero, fase Battle, puertas y aparición de todos.
	start: (ctx: Context) -> (),
	-- Cada tick en Battle y SuddenDeath.
	tick: (ctx: Context, phase: Arena.Phase) -> (),
	-- Un equipo ha anotado a su manera (captura de bandera, gol…). Solo cuenta en plena partida.
	capture: (teamId: string) -> (),
	-- Se cambia de modo: deshace lo que el modo cambió. Se puede llamar sin haber empezado.
	stop: () -> (),
}

return {}
