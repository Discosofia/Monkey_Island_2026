--!strict
-- Estilos de los números de combate (cosmético NumberStyle, Fase 9 G9d), por id del cosmético: la
-- letra, el brillo de arriba abajo (tres colores, uno más claro para el crítico), el borde y cuánto
-- crece la caja (cada letra deja distinto aire arriba y abajo). Los dibuja UI/CombatTextColumn en el
-- daño que hace quien lo lleva, y su imagen (unos números voxel) Shared/RewardModels. Solo datos: sin
-- dependencias, para que RewardModels lo pueda cargar en cualquier sitio.
-- Nunca verde ni morado: son la curación y el veneno.

export type NumberStyle = {
	font: Font,
	colors: { Color3 },
	critColors: { Color3 },
	edge: Color3,
	scale: number,
}

local NumberStyles: { [string]: NumberStyle } = {
	-- Lava que se enfría: blanco amarillento arriba, naranja y rojo oscuro abajo, con borde de basalto.
	MagmaNumbers = {
		font = Font.fromEnum(Enum.Font.LuckiestGuy),
		colors = { Color3.fromRGB(255, 235, 140), Color3.fromRGB(255, 130, 25), Color3.fromRGB(165, 35, 10) },
		critColors = { Color3.fromRGB(255, 255, 225), Color3.fromRGB(255, 185, 45), Color3.fromRGB(215, 45, 10) },
		edge = Color3.fromRGB(40, 26, 22),
		scale = 1.25,
	},
}

return NumberStyles
