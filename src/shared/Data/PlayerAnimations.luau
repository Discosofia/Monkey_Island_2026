--!strict
-- Animaciones del cuerpo del jugador (R15) que no son de armas: gestos de las habilidades de los
-- roles, comer, beber, curarse, arrastrarse caído y reanimar a un aliado. Las reproduce el propio
-- cliente (Client/BodyAnimations), así que los demás jugadores también las ven.
-- Se generan con ServerStorage.Tools.PlayerAnimationBuilder (ver ese archivo) y aquí se pega el id
-- publicado de cada una. Mientras un id esté vacío, en Studio se usa la secuencia generada
-- (ReplicatedStorage.PlayerAnimations); en el juego publicado, esa animación no se reproduce.

export type Key =
	"Quake"
	| "WarCry"
	| "Charge"
	| "Whirlwind"
	| "DodgeRoll"
	| "DodgeBack"
	| "CastForward"
	| "CastArea"
	| "Place"
	| "Consume"
	| "Bandage"
	| "Crawl"
	| "Revive"

export type PlayerAnimation = {
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean?, -- en bucle hasta que el código la para (Crawl, Revive, Whirlwind)
}

local PlayerAnimations = {
	-- Por encima de sujetar el arma (Hold, Action) y de los disparos (Action2).
	Animations = {
		Quake = { id = "", priority = Enum.AnimationPriority.Action3 }, -- pisotón del guerrero
		-- Grito de guerra. Mientras no exista (id vacío fuera de Studio), AbilityFxController hace la
		-- misma pose girando las articulaciones por código, que tiembla si lleva un arma en la mano.
		WarCry = { id = "", priority = Enum.AnimationPriority.Action3 },
		Charge = { id = "", priority = Enum.AnimationPriority.Action3 }, -- embestida con el hombro por delante
		-- Esquiva (DodgeController): voltereta hacia delante si te mueves hacia donde miras; salto
		-- atrás si estás quieto o vas hacia atrás.
		DodgeRoll = { id = "", priority = Enum.AnimationPriority.Action3 },
		DodgeBack = { id = "", priority = Enum.AnimationPriority.Action3 },
		-- Torbellino: agachado y con los brazos abiertos, en bucle mientras RoleController lo hace girar.
		Whirlwind = { id = "", priority = Enum.AnimationPriority.Action3, looped = true },
		CastForward = { id = "", priority = Enum.AnimationPriority.Action3 }, -- lanza con la mano al frente
		CastArea = { id = "", priority = Enum.AnimationPriority.Action3 }, -- brazos arriba y abiertos abajo
		Place = { id = "", priority = Enum.AnimationPriority.Action3 }, -- se agacha a dejar algo en el suelo
		Consume = { id = "", priority = Enum.AnimationPriority.Action3 }, -- mano a la boca (comer, beber)
		Bandage = { id = "", priority = Enum.AnimationPriority.Action3 }, -- se venda el antebrazo
		Crawl = { id = "", priority = Enum.AnimationPriority.Action4, looped = true }, -- caído, se arrastra
		Revive = { id = "", priority = Enum.AnimationPriority.Action4, looped = true }, -- de rodillas, reanima
	} :: { [Key]: PlayerAnimation },

	-- Gesto de cada habilidad de Data/Roles. El Torbellino no va aquí: dura lo que el giro y lo para
	-- RoleController. El Parpadeo no lleva (teletransporta).
	Abilities = {
		Quake = "Quake",
		WarCry = "WarCry",
		Charge = "Charge",
		MultiShot = "CastForward",
		MarkPrey = "CastForward",
		Trap = "Place",
		ArrowRain = "CastArea",
		Fireball = "CastForward",
		FrostNova = "CastArea",
		ChainLightning = "CastForward",
		AreaHeal = "CastArea",
		HealingDart = "CastForward",
		LeafShield = "CastArea",
		HealingTotem = "Place",
	} :: { [string]: Key },
}

return PlayerAnimations
