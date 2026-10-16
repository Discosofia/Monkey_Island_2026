--!strict
-- Roles (GDD §6.3, Fase 3). Se eligen en el Lobby y son fijos durante la partida.
--   - "perks": ventajas pasivas (se suman a Data/Perks).
--   - "weapons": armas con las que aparece (además del hacha y el pico, Config.Combat.StarterTools).
--   - "items": ítems con los que empieza la partida (las flechas del cazador).
--   - "abilities": 4 activas y la definitiva, en el orden de sus huecos: Z, X, C, la definitiva V y la
--     cuarta activa R (con mando, R1 + A, B, X, Y y L1). La R va al final para que los huecos 1-4 sigan
--     siendo los de siempre. Las gestiona AbilityService y sus números están en Config.Abilities.

export type Ability = {
	id: string,
	name: string,
	short: string, -- texto del botón táctil
	description: string,
	cooldownSeconds: number,
	ultimate: boolean?,
}

export type Role = {
	name: string,
	icon: string,
	order: number,
	passive: string, -- texto para el jugador
	perks: { [string]: number },
	weapons: { string },
	items: { [string]: number }?,
	abilities: { Ability },
}

local Roles: { [string]: Role } = {
	Guerrero = {
		name = "Guerrero",
		icon = "⚔️",
		order = 1,
		passive = "+25 % de daño cuerpo a cuerpo y +20 de vida máxima.",
		perks = { MeleeDamage = 0.25, MaxHealth = 20 },
		weapons = { "StoneClub", "Honda" },
		abilities = {
			{
				id = "Whirlwind",
				name = "Torbellino",
				short = "Torbellino",
				description = "Gira con el arma y golpea a todo lo que tienes alrededor.",
				cooldownSeconds = 7,
			},
			{
				id = "Charge",
				name = "Embestida",
				short = "Embestida",
				description = "Cargas hacia delante, dañas y empujas a lo que atraviesas.",
				cooldownSeconds = 6,
			},
			{
				id = "WarCry",
				name = "Grito de guerra",
				short = "Grito",
				description = "Los monos cercanos van a por ti y recibes un 40 % menos de daño.",
				cooldownSeconds = 12,
			},
			{
				id = "Quake",
				name = "Pisotón",
				short = "Pisotón",
				description = "Pisas el suelo con fuerza: daño fuerte alrededor y aturde a los monos.",
				cooldownSeconds = 90,
				ultimate = true,
			},
			{
				id = "Smash",
				name = "Rompehuesos",
				short = "Rompe",
				description = "Un golpe brutal hacia delante que daña y tumba un momento a los monos.",
				cooldownSeconds = 8,
			},
		},
	},
	Cazador = {
		name = "Cazador",
		icon = "🏹",
		order = 2,
		passive = "+25 % de daño a distancia.",
		perks = { RangedDamage = 0.25 },
		weapons = { "Bow", "Machete" },
		items = { Arrow = 20 },
		abilities = {
			{
				id = "MultiShot",
				name = "Disparo múltiple",
				short = "Múltiple",
				description = "Lanzas un abanico de proyectiles hacia donde apuntas.",
				cooldownSeconds = 5,
			},
			{
				id = "MarkPrey",
				name = "Marcar presas",
				short = "Marcar",
				description = "Señala a los monos cercanos: el equipo los ve y les hace más daño.",
				cooldownSeconds = 15,
			},
			{
				id = "Trap",
				name = "Cepo",
				short = "Cepo",
				description = "Deja un cepo a tus pies; cuando un mono lo pisa, atrapa a todos los que tiene alrededor.",
				cooldownSeconds = 9,
			},
			{
				id = "ArrowRain",
				name = "Lluvia de proyectiles",
				short = "Lluvia",
				description = "Una zona donde apuntas recibe daño continuo durante unos segundos.",
				cooldownSeconds = 90,
				ultimate = true,
			},
			{
				id = "PiercingShot",
				name = "Flecha perforante",
				short = "Perforante",
				description = "Una flecha recta que atraviesa a todos los monos que encuentra en línea.",
				cooldownSeconds = 8,
			},
		},
	},
	Mago = {
		name = "Mago",
		icon = "🔮",
		order = 3,
		passive = "+25 % de daño de hechizos y habilidades un 15 % más rápidas.",
		perks = { SpellDamage = 0.25, CooldownRate = -0.15 },
		weapons = { "MagicStaff", "Machete" },
		abilities = {
			{
				id = "Fireball",
				name = "Bola de fuego",
				short = "Fuego",
				description = "Proyectil que explota al impactar y daña alrededor.",
				cooldownSeconds = 6,
			},
			{
				id = "FrostNova",
				name = "Nova de hielo",
				short = "Hielo",
				description = "Congela a los monos a tu alrededor y después los ralentiza.",
				cooldownSeconds = 11,
			},
			{
				id = "Blink",
				name = "Parpadeo",
				short = "Parpadeo",
				description = "Te teletransportas hacia donde miras.",
				cooldownSeconds = 7,
			},
			{
				id = "ChainLightning",
				name = "Rayo encadenado",
				short = "Rayo",
				description = "Un rayo que salta entre varios monos, algo más débil en cada salto.",
				cooldownSeconds = 90,
				ultimate = true,
			},
			{
				id = "Meteor",
				name = "Meteoro",
				short = "Meteoro",
				description = "Una roca ardiente cae del cielo donde apuntas y daña a todos los de alrededor.",
				cooldownSeconds = 10,
			},
		},
	},
	Medico = {
		name = "Médico",
		icon = "⛑️",
		order = 4,
		passive = "Reanima el doble de rápido y ve la vida de sus aliados.",
		perks = { ReviveSpeed = -0.5, SeeHealth = 1 },
		weapons = { "Blowgun", "Machete" },
		abilities = {
			{
				id = "AreaHeal",
				name = "Ungüento en área",
				short = "Ungüento",
				description = "Cura a los aliados cercanos (y a ti).",
				cooldownSeconds = 15,
			},
			{
				id = "HealingDart",
				name = "Dardo curativo",
				short = "Dardo",
				description = "Dardo que cura al aliado que alcanza (o pica un poco a un mono).",
				cooldownSeconds = 6,
			},
			{
				id = "LeafShield",
				name = "Escudo de hojas",
				short = "Escudo",
				description = "El aliado más cercano (o tú) recibe un escudo que absorbe daño.",
				cooldownSeconds = 12,
			},
			{
				id = "HealingTotem",
				name = "Tótem sanador",
				short = "Tótem",
				description = "Plantas un tótem donde apuntas que cura poco a poco a quien esté cerca.",
				cooldownSeconds = 90,
				ultimate = true,
			},
			{
				id = "SleepPowder",
				name = "Polvo somnífero",
				short = "Somnífero",
				description = "Lanzas una nube donde apuntas: a los monos les entra sueño y se duermen un momento (los jefes, no).",
				cooldownSeconds = 12,
			},
		},
	},
}

return Roles
