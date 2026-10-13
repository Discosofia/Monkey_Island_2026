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
}

return Stations
