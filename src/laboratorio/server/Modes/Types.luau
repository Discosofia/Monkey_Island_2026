--!strict
-- El contrato de un modo de juego del Laboratorio (Config.Lab.Modes). LabMatchService se queda con lo
-- común (Waiting, Countdown, Results, el marcador, los resultados y la cancelación) y le pide al modo en
-- curso lo que cambia: cuántos faltan para empezar, cómo se puntúa, cuándo acaba y quién gana.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Arena)

-- El ganador: el id de un bando, o un jugador (Todos contra todos).
export type Winner = string | Player

-- Lo que LabMatchService le presta al modo.
export type Context = {
	setPhase: (phase: Arena.Phase, seconds: number?) -> (),
	finish: (winner: Winner?) -> (),
	isSolo: () -> boolean,
}

export type Mode = {
	-- El formato válido de este modo más cercano al pedido (jugadores por bando, o el total de la sala).
	format: (requested: number) -> number,
	-- Pone en ReplicatedStorage lo que el HUD lee de este modo con este formato (LabKillsToWin…).
	publish: (format: number) -> (),
	-- En Waiting: ¿está la sala completa? (con todos listos, empieza la cuenta atrás).
	full: () -> boolean,
	-- En Waiting, al acabar la espera: ¿hay gente para jugar?
	enough: () -> boolean,
	-- En Countdown y en plena partida: ¿se ha ido tanta gente que no se puede seguir? (nunca en solitario)
	abandoned: (ctx: Context) -> boolean,
	-- Empieza la partida: fase Battle, compuertas y aparición de todos.
	start: (ctx: Context) -> (),
	-- Cada tick en Battle, SuddenDeath e Intermission.
	tick: (ctx: Context, phase: Arena.Phase) -> (),
	-- Un rival ha derribado a "victim" en plena partida.
	onKnockedOut: (victim: Player, attacker: Player) -> (),
	-- La partida termina (o se cambia de modo): deshace lo que el modo cambió. Se puede llamar sin haber empezado.
	stop: () -> (),
	-- Panel de pruebas: un punto para "player".
	debugScore: (player: Player) -> (),
	-- Panel de pruebas: "Saltar fase". Devuelve true si el modo lo ha resuelto.
	debugSkip: ((ctx: Context) -> boolean)?,
}

return {}
