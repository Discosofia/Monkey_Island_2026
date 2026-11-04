--!strict
-- Balística de los proyectiles (Fase 24, 24e): cómo vuela y cuánto pesa cada uno. Es el mismo dato para el servidor
-- (Combat/Projectiles) y para quien lo dibuja (AbilityFxController); la cuenta está en Shared/Ballistics.
-- Se busca por "source" (el id de la habilidad o del arma) y, si no está, por el aspecto del proyectil
-- ("Stone", "Arrow", "Spell", "Dart"). Lo que no está aquí (las armas del Laboratorio) vuela recto, sin frenado y
-- con todo su daño: ya se equilibran como son.
--   drop      studs que cae al llegar al alcance máximo (la gravedad sale de aquí y del tiempo de vuelo)
--   drag      frenado del aire, 1/s: la rapidez baja como e^(-drag × t), así que la bala pierde ritmo de lejos
--   mass      empuje al impactar a un mono: mass × Config.Ballistics.PushScale / masa del blanco
--   falloff   daño según la distancia al impactar: 1 hasta start × alcance, baja en línea recta hasta min en el
--             alcance (start y min son fracciones). Solo lo usan las armas, no las habilidades.

export type Profile = {
	drop: number,
	drag: number,
	mass: number,
	falloff: { start: number, min: number }?,
}

local Ballistics: { [string]: Profile } = {
	-- Aspectos de las armas.
	Stone = { drop = 3, drag = 0.25, mass = 1, falloff = { start = 0.5, min = 0.8 } },
	Spell = { drop = 3, drag = 0.15, mass = 0.8, falloff = { start = 0.5, min = 0.85 } },
	Arrow = { drop = 0, drag = 0.05, mass = 0.6, falloff = { start = 0.6, min = 0.85 } },
	Dart = { drop = 0, drag = 0.1, mass = 0.3, falloff = { start = 0.6, min = 0.85 } },
	-- Habilidades proyectil: sin falloff (su daño ya cuenta con el alcance).
	Fireball = { drop = 3, drag = 0.15, mass = 2 },
	MultiShot = { drop = 0, drag = 0.05, mass = 0.4 },
	TrueShot = { drop = 0, drag = 0, mass = 3 },
	PiercingShot = { drop = 0, drag = 0.05, mass = 1 },
	HealingDart = { drop = 0, drag = 0.1, mass = 0.3 },
}

return Ballistics
