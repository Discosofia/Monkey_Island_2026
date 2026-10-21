--!strict
-- Estilos de los números de combate (cosmético NumberStyle, Fase 9 G9d), por id del cosmético: la
-- letra, tres franjas de color de arriba abajo (otras más claras para el crítico), el borde, cuánto
-- crece la caja (cada letra deja distinto aire arriba y abajo) y "glyph", la parte de la caja (de
-- arriba abajo, 0–1) que ocupan las cifras en esa letra, para que las tres franjas caigan sobre ellas.
-- Los dibuja UI/CombatTextColumn en el daño que hace quien lo lleva, y su imagen (unos números voxel)
-- Shared/RewardModels. Solo datos: sin dependencias, para que RewardModels lo pueda cargar en
-- cualquier sitio.
-- Tienen que verse distintos de los de serie (amarillos) a primera vista. Nunca verde ni morado: son
-- la curación y el veneno.

export type NumberStyle = {
	font: Font,
	colors: { Color3 },
	critColors: { Color3 },
	edge: Color3,
	scale: number,
	glyph: { number },
}

local NumberStyles: { [string]: NumberStyle } = {
	-- Lava: amarillo arriba, naranja en medio y rojo vivo abajo, con un borde grueso de basalto.
	MagmaNumbers = {
		font = Font.fromEnum(Enum.Font.LuckiestGuy),
		colors = { Color3.fromRGB(255, 225, 70), Color3.fromRGB(255, 115, 20), Color3.fromRGB(205, 30, 10) },
		critColors = { Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 150, 25), Color3.fromRGB(230, 40, 10) },
		edge = Color3.fromRGB(32, 16, 12),
		scale = 1.25,
		glyph = { 0.2, 0.8 },
	},
	-- Hielo: blanco arriba, celeste en medio y azul hondo abajo, con un borde azul marino.
	FrostNumbers = {
		font = Font.fromEnum(Enum.Font.LuckiestGuy),
		colors = { Color3.fromRGB(245, 252, 255), Color3.fromRGB(120, 205, 255), Color3.fromRGB(35, 105, 215) },
		critColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 230, 255), Color3.fromRGB(60, 140, 255) },
		edge = Color3.fromRGB(12, 25, 60),
		scale = 1.25,
		glyph = { 0.2, 0.8 },
	},
}

return NumberStyles
