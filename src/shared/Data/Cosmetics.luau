--!strict
-- Cosméticos de pago (GDD §14, Fase 6): solo cambian el aspecto, nunca dan ventaja.
-- Cada uno es un Game Pass. Crea los pases en el Creator Hub (docs/LANZAMIENTO.md) y pon aquí su ID
-- en "gamePassId". Con 0 sale como "Próximamente" (en Studio se pueden probar gratis con
-- Config.Cosmetics.FreeInStudio). Tipos: Trail (estela), Title (título sobre la cabeza), Aura.

export type Cosmetic = {
	name: string,
	icon: string,
	kind: "Trail" | "Title" | "Aura",
	description: string,
	order: number,
	gamePassId: number,
	color: Color3,
	title: string?,
}

local Cosmetics: { [string]: Cosmetic } = {
	GoldenTrail = {
		name = "Estela dorada",
		icon = "✨",
		kind = "Trail",
		description = "Dejas un rastro dorado al moverte.",
		order = 1,
		gamePassId = 0,
		color = Color3.fromRGB(255, 205, 70),
	},
	JungleTrail = {
		name = "Estela de la selva",
		icon = "🌿",
		kind = "Trail",
		description = "Un rastro verde de hojas.",
		order = 2,
		gamePassId = 0,
		color = Color3.fromRGB(90, 210, 90),
	},
	TitleKing = {
		name = "Título: Rey de la selva",
		icon = "👑",
		kind = "Title",
		description = "Muestra «Rey de la selva» sobre tu cabeza.",
		order = 3,
		gamePassId = 0,
		color = Color3.fromRGB(255, 215, 90),
		title = "👑 Rey de la selva",
	},
	BananaAura = {
		name = "Aura de banana",
		icon = "🍌",
		kind = "Aura",
		description = "Brillitos amarillos a tu alrededor.",
		order = 4,
		gamePassId = 0,
		color = Color3.fromRGB(255, 235, 90),
	},
}

return Cosmetics
