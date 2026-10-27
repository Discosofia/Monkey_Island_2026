--!strict
-- Eventos de mitad de partida (Fase 9, G7; MidEventService, Config.MidEvents). Cada partida tiene los
-- tres, cada uno en uno de sus "days" (al azar al empezar la partida) y en su fase: de día empiezan
-- un poco después del amanecer; de noche, al anochecer. Al anochecer del día anterior se avisa del de
-- mañana ("eve", también en la línea de estado del HUD toda esa noche) y al empezar, con "start".
-- Mientras dura, "status" sale en la línea de estado del HUD.
--   ToxicRain: lluvia tóxica. El agua del río da fiebre (la hervida de la hoguera y los cocos, no), los
--     mordiscos dan el doble y no quita la sed. Los médicos reciben antídotos y su Ungüento en área
--     baja la fiebre (WeatherService, SurvivalService, IslandCombatRules).
--   Saboteurs: noche de macacos saboteadores. Cada oleada del asedio trae además macacos que van a
--     por las estacas, los muros y barricadas y las estaciones del núcleo (SiegeService).
--   Eruption: erupción preliminar. Piroclastos sobre las zonas altas (el volcán y las montañas) y dos
--     cajas militares allí arriba con obsidiana, una esquirla de jefe y provisiones; abrirlas activa
--     el PvP (WeatherService, SupplyService).

export type EventId = "ToxicRain" | "Saboteurs" | "Eruption"

export type MidEvent = {
	id: EventId,
	name: string,
	icon: string,
	days: { number }, -- uno de estos al azar en cada partida
	phase: "Day" | "Night",
	eve: string,
	start: string,
	status: string,
}

local MidEvents: { MidEvent } = {
	{
		id = "ToxicRain",
		name = "Lluvia tóxica",
		icon = "☣️",
		days = { 3, 4 },
		phase = "Day",
		eve = "Mañana cae lluvia tóxica: hierve agua en la hoguera y lleva antídotos",
		start = "☣️ ¡Lluvia tóxica! El agua del río da fiebre (bebe agua hervida o cocos) y los mordiscos infectan el doble",
		status = "☣️ Lluvia tóxica: agua del río contaminada · mordiscos ×2 de fiebre",
	},
	{
		id = "Saboteurs",
		name = "Noche de macacos saboteadores",
		icon = "🔧",
		days = { 5 },
		phase = "Night",
		eve = "Mañana por la noche vienen macacos saboteadores: van a por las trampas, los muros y las estaciones",
		start = "🔧 ¡Macacos saboteadores! Esta noche van a por las estacas, los muros y las estaciones: defiéndelas",
		status = "🔧 Macacos saboteadores: defiende trampas, muros y estaciones",
	},
	{
		id = "Eruption",
		name = "Erupción preliminar",
		icon = "🌋",
		days = { 7 },
		phase = "Day",
		eve = "Mañana el volcán despierta: lloverán piroclastos en las zonas altas y caerán cajas militares",
		start = "🌋 ¡Erupción preliminar! Llueven piroclastos en el volcán y las montañas, y han caído 2 cajas militares allí arriba",
		status = "🌋 Erupción: piroclastos en las zonas altas · cajas militares",
	},
}

return MidEvents
