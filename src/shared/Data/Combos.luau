--!strict
-- Combos de los roles (octubre de 2026). Dos por rol, de tres habilidades en orden, con
-- Config.Combo.StepWindowSeconds como mucho entre una y la siguiente (desde que la siguiente esté
-- lista, si aún se recargaba):
--   1. La primera prepara: deja una marca en lo que toca (el cepo atrapa, el hielo congela…). Cada
--      combo empieza con una habilidad distinta: la que usas primero decide cuál está en marcha.
--   2. La segunda enlaza: contra los marcados sus golpes son críticos seguros y hacen "damageBonus"
--      más de daño.
--   3. La tercera remata: lo mismo y un efecto extra ("finisher").
-- Conexión: el remate de un combo deja abierto el otro en su paso 1 (lo marcado sigue marcado y lo
-- que golpea el remate se suma), así que se sigue directamente por su paso 2: A → B → A… Cada combo
-- cerrado así sube la racha Config.Combo.ConnectStreakBonus más (ComboService).
-- Ningún combo usa la definitiva (V): con sus 90 s de recarga casi nunca se podría cerrar. Cada paso
-- enlazado la acerca (con tope por recarga) y cada combo completo seguido sube la racha, que acelera
-- las recargas (ComboService). "steps" son ids de Data/Roles.
-- "damageBonus" es distinto por rol para que enlazar valga parecido a todos (+30 % de daño en una
-- pelea larga contra un grupo, medido con la calculadora ServerStorage.Tools.Equilibrio): con las
-- conexiones casi todos los golpes de habilidad del mago van enlazados (críticos seguros) y no le hace
-- falta más; el guerrero cierra menos combos (el Grito tarda 12 s) y su remate es el Torbellino.

export type Combo = {
	name: string,
	steps: { string },
	mark: string, -- nombre de la marca que deja el primer paso
	icon: string, -- se ve sobre lo marcado (solo quien hizo la marca)
	finisher: string, -- qué hace de más el remate (para el jugador)
	short: string, -- el remate en pocas palabras (una línea por combo en el panel de Ajustes)
	damageBonus: number?, -- daño extra (fracción) de los golpes enlazados contra lo marcado
}

local Combos: { [string]: { Combo } } = {
	Cazador = {
		{
			name = "Presa acorralada",
			steps = { "Trap", "MarkPrey", "MultiShot" },
			mark = "Atrapado",
			icon = "⛓️",
			finisher = "Marcar vuelve a sujetar a los atrapados y el Disparo múltiple lanza 2 proyectiles más.",
			short = "vuelve a sujetar y +2 proyectiles",
			damageBonus = 0.1,
		},
		{
			name = "Tiro de gracia",
			steps = { "MarkPrey", "Trap", "PiercingShot" },
			mark = "Señalado",
			icon = "🎯",
			finisher = "La Flecha perforante dispara 2 flechas más en abanico.",
			short = "+2 flechas en abanico",
			damageBonus = 0.1,
		},
	},
	Mago = {
		{
			name = "Fuego y hielo",
			steps = { "FrostNova", "Blink", "Fireball" },
			mark = "Quebradizo",
			icon = "❄️",
			finisher = "La Bola de fuego rompe el hielo: críticos y explosión más grande.",
			short = "rompe el hielo: explosión mayor",
		},
		{
			name = "Lluvia de estrellas",
			steps = { "Fireball", "FrostNova", "Meteor" },
			mark = "Chamuscado",
			icon = "🔥",
			finisher = "El Meteoro deja el suelo ardiendo unos segundos.",
			short = "deja el suelo ardiendo",
		},
	},
	Guerrero = {
		{
			name = "Remolino de acero",
			steps = { "Charge", "WarCry", "Whirlwind" },
			mark = "Desequilibrado",
			icon = "💫",
			finisher = "El Grito aturde a los desequilibrados y el Torbellino gira 1 s más.",
			short = "aturde y gira 1 s más",
			damageBonus = 0.25,
		},
		{
			name = "Martillo y yunque",
			steps = { "WarCry", "Charge", "Smash" },
			mark = "Provocado",
			icon = "🔨",
			finisher = "El Rompehuesos golpea a todo lo que tienes alrededor, no solo delante.",
			short = "golpea a tu alrededor",
			damageBonus = 0.25,
		},
	},
	Medico = {
		{
			name = "Cura de urgencia",
			steps = { "HealingDart", "LeafShield", "AreaHeal" },
			mark = "Revitalizado",
			icon = "💚",
			finisher = "El Ungüento cura con críticos seguros, baja la fiebre y envenena a los monos de alrededor.",
			short = "baja la fiebre y envenena",
		},
		{
			name = "Nana de la selva",
			steps = { "LeafShield", "HealingDart", "SleepPowder" },
			mark = "Arropado",
			icon = "🍃",
			finisher = "El Polvo somnífero duerme más tiempo, cura a los aliados de la nube y los dormidos reciben un 30 % más de daño hasta despertar.",
			short = "cura y los dormidos reciben +30 %",
		},
	},
}

return Combos
