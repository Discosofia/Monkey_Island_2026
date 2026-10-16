--!strict
-- Combos de los roles (octubre de 2026). Tres habilidades en orden, con Config.Combo.StepWindowSeconds
-- como mucho entre una y la siguiente (desde que la siguiente esté lista, si aún se recargaba):
--   1. La primera prepara: deja una marca en lo que toca (el cepo atrapa, el hielo congela…).
--   2. La segunda enlaza: contra los marcados sus golpes son críticos seguros y hacen "damageBonus"
--      más de daño.
--   3. La tercera remata: lo mismo y un efecto extra ("finisher").
-- Ningún combo usa la definitiva (V): con sus 90 s de recarga casi nunca se podría cerrar. Cada paso
-- enlazado la acerca (con tope por recarga) y cada combo completo seguido sube la racha, que acelera
-- las recargas (ComboService). "steps" son ids de Data/Roles.
-- "damageBonus" es distinto por rol para que enlazar valga parecido a todos (+20–30 % de daño en una
-- pelea larga contra un grupo, medido con la calculadora ServerStorage.Tools.Equilibrio): el mago
-- cierra un combo cada ~9 s y su remate es la Bola de fuego; el cazador remata con flechas pequeñas
-- y su combo vale sobre todo por sujetar a los monos y la marca para el equipo.

export type Combo = {
	name: string,
	steps: { string },
	mark: string, -- nombre de la marca que deja el primer paso
	icon: string, -- se ve sobre lo marcado (solo quien hizo la marca)
	finisher: string, -- qué hace de más el remate (para el jugador)
	damageBonus: number?, -- daño extra (fracción) de los golpes enlazados contra lo marcado
}

local Combos: { [string]: Combo } = {
	Cazador = {
		name = "Presa acorralada",
		steps = { "Trap", "MarkPrey", "MultiShot" },
		mark = "Atrapado",
		icon = "⛓️",
		finisher = "Marcar vuelve a sujetar a los atrapados y el Disparo múltiple lanza 2 proyectiles más.",
		damageBonus = 0.5,
	},
	Mago = {
		name = "Fuego y hielo",
		steps = { "FrostNova", "Blink", "Fireball" },
		mark = "Quebradizo",
		icon = "❄️",
		finisher = "La Bola de fuego rompe el hielo: críticos y explosión más grande.",
		damageBonus = 0.25,
	},
	Guerrero = {
		name = "Remolino de acero",
		steps = { "Charge", "WarCry", "Whirlwind" },
		mark = "Desequilibrado",
		icon = "💫",
		finisher = "El Grito aturde a los desequilibrados y el Torbellino gira 1 s más.",
		damageBonus = 0.25,
	},
	Medico = {
		name = "Cura de urgencia",
		steps = { "HealingDart", "LeafShield", "AreaHeal" },
		mark = "Revitalizado",
		icon = "💚",
		finisher = "El Ungüento cura con críticos seguros y baja la fiebre.",
	},
}

return Combos
