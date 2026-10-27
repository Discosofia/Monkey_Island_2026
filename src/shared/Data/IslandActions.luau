--!strict
-- Lo que un administrador puede hacer al momento en las partidas de la Isla (T4b), en la suya o en
-- todas (ServerShared/AdminNet). Lo hace island/server/Services/AdminEventsService.

export type Info = { icon: string, name: string, order: number }

local IslandActions: { [string]: Info } = {
	Boss = { icon = "👑", name = "Jefe", order = 1 },
	Alpha = { icon = "🐒", name = "Tropa con alfa", order = 2 },
	SkipPhase = { icon = "⏩", name = "Día/noche", order = 3 },
	Supplies = { icon = "📦", name = "Provisiones", order = 4 },
	Rain = { icon = "🌧️", name = "Lluvia", order = 5 },
	Storm = { icon = "⛈️", name = "Tormenta", order = 6 },
	Clear = { icon = "☀️", name = "Despejado", order = 7 },
	Eruption = { icon = "🌋", name = "Erupción", order = 8 },
}

return IslandActions
