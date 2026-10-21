--!strict
-- Estaciones de crafteo del Basecamp (GDD §9.3). Cada receta (Data/Recipes) dice en cuál se hace.
-- En el mapa, una estación es cualquier Model o Part con el atributo "CraftingStation" = <id>.

export type StationDefinition = {
	name: string,
	icon: string,
	actionText: string, -- verbo del aviso al acercarse
}

local Stations: { [string]: StationDefinition } = {
	Workbench = { name = "Mesa de trabajo", icon = "🔨", actionText = "Usar" },
	Campfire = { name = "Hoguera", icon = "🔥", actionText = "Cocinar" },
	-- Fase 2.3: se construyen con el martillo en el núcleo del Basecamp (Data/Buildables).
	Healer = { name = "Taller del curandero", icon = "🌿", actionText = "Usar" },
	Forge = { name = "Forja de piedra", icon = "⚒️", actionText = "Forjar" },
	-- Fase 9 (G5): el nivel 4 del equipo, con obsidiana y el cristal del jefe de la cueva.
	VolcanicForge = { name = "Forja volcánica", icon = "🌋", actionText = "Forjar" },
}

return Stations
