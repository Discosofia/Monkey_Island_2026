--!strict
-- Animaciones del cuerpo del jugador (R15) que no son de armas: gestos de las habilidades de los
-- roles, comer, beber, curarse, arrastrarse caído y reanimar a un aliado. Las reproduce el propio
-- cliente (Client/BodyAnimations), así que los demás jugadores también las ven.
-- Se generan con ServerStorage.Tools.PlayerAnimationBuilder (ver ese archivo) y aquí se pega el id
-- publicado de cada una. Mientras un id esté vacío, en Studio se usa la secuencia generada
-- (ReplicatedStorage.PlayerAnimations); en el juego publicado, esa animación no se reproduce.

export type Key = "Quake" | "CastForward" | "CastArea" | "Place" | "Consume" | "Bandage" | "Crawl" | "Revive"

export type PlayerAnimation = {
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean?, -- en bucle hasta que el código la para (Crawl, Revive)
}

local PlayerAnimations = {
	-- Por encima de sujetar el arma (Hold, Action) y de los disparos (Action2).
	Animations = {
		Quake = { id = "", priority = Enum.AnimationPriority.Action3 }, -- pisotón del guerrero
		CastForward = { id = "", priority = Enum.AnimationPriority.Action3 }, -- lanza con la mano al frente
		CastArea = { id = "", priority = Enum.AnimationPriority.Action3 }, -- brazos arriba y abiertos abajo
		Place = { id = "", priority = Enum.AnimationPriority.Action3 }, -- se agacha a dejar algo en el suelo
		Consume = { id = "", priority = Enum.AnimationPriority.Action3 }, -- mano a la boca (comer, beber)
		Bandage = { id = "", priority = Enum.AnimationPriority.Action3 }, -- se venda el antebrazo
		Crawl = { id = "", priority = Enum.AnimationPriority.Action4, looped = true }, -- caído, se arrastra
		Revive = { id = "", priority = Enum.AnimationPriority.Action4, looped = true }, -- de rodillas, reanima
	} :: { [Key]: PlayerAnimation },

	-- Gesto de cada habilidad de Data/Roles (las que mueven al personaje por sí mismas, como la
	-- Embestida, el Torbellino o el Parpadeo, no llevan; el Grito de guerra tiene su pose en
	-- AbilityFxController).
	Abilities = {
		Quake = "Quake",
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
