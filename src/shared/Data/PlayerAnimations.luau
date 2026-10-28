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
	| "Smash"
	| "Whirlwind"
	| "DodgeRoll"
	| "DodgeBack"
	| "Slide"
	| "CastForward"
	| "CastArea"
	| "Place"
	| "Consume"
	| "Bandage"
	| "Crawl"
	| "Revive"
	| "Hammer"
	| "Craft"
	| "Ride"

export type PlayerAnimation = {
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean?, -- en bucle hasta que el código la para (Crawl, Revive, Whirlwind)
	-- Segundos hasta el golpe del gesto: BodyAnimations.playAbility lo estira a la preparación de la
	-- habilidad (C8, "castSeconds" de Data/Roles).
	impactSeconds: number?,
}

local PlayerAnimations = {
	-- Por encima de sujetar el arma (Hold, Action) y de los disparos (Action2).
	Animations = {
		Quake = { id = "rbxassetid://123577573211433", priority = Enum.AnimationPriority.Action3 }, -- pisotón del guerrero
		-- Grito de guerra. Mientras no exista (id vacío fuera de Studio), AbilityFxController hace la
		-- misma pose girando las articulaciones por código, que tiembla si lleva un arma en la mano.
		WarCry = { id = "rbxassetid://127375051692539", priority = Enum.AnimationPriority.Action3 },
		Charge = { id = "rbxassetid://106518569968843", priority = Enum.AnimationPriority.Action3 }, -- embestida con el hombro por delante
		-- Rompehuesos: golpe de dos manos al suelo.
		Smash = { id = "rbxassetid://117133122045501", priority = Enum.AnimationPriority.Action3, impactSeconds = 0.25 },
		-- Esquiva (DodgeController): voltereta hacia delante si te mueves hacia donde miras; salto
		-- atrás si estás quieto o vas hacia atrás.
		DodgeRoll = { id = "rbxassetid://137704861516961", priority = Enum.AnimationPriority.Action3 },
		DodgeBack = { id = "rbxassetid://80943980651716", priority = Enum.AnimationPriority.Action3 },
		-- Deslizamiento (Fase 15, V2; combatClient/Slide): agachado y echado hacia atrás, con una pierna
		-- estirada, en bucle hasta que Slide la para. Solo piernas y tronco: los brazos siguen con el arma.
		-- PROVISIONAL, sin publicar: id vacío (en Studio usa la secuencia de PlayerAnimationBuilder; en el
		-- juego publicado no se reproduce). La pose definitiva es la V4.
		Slide = { id = "", priority = Enum.AnimationPriority.Action3, looped = true },
		-- Torbellino: agachado y con los brazos abiertos, en bucle mientras RoleController lo hace girar.
		Whirlwind = { id = "rbxassetid://86446930487394", priority = Enum.AnimationPriority.Action3, looped = true },
		CastForward = { id = "rbxassetid://140190769864612", priority = Enum.AnimationPriority.Action3 }, -- lanza con la mano al frente
		CastArea = { id = "rbxassetid://106681770579969", priority = Enum.AnimationPriority.Action3 }, -- brazos arriba y abiertos abajo
		Place = { id = "rbxassetid://118305114446106", priority = Enum.AnimationPriority.Action3 }, -- se agacha a dejar algo en el suelo
		Consume = { id = "rbxassetid://106673766007156", priority = Enum.AnimationPriority.Action3 }, -- mano a la boca (comer, beber)
		Bandage = { id = "rbxassetid://130660240768152", priority = Enum.AnimationPriority.Action3 }, -- se venda el antebrazo
		Hammer = { id = "rbxassetid://92131567033850", priority = Enum.AnimationPriority.Action3 }, -- dos martillazos (construir, quitar)
		Craft = { id = "rbxassetid://71536295123191", priority = Enum.AnimationPriority.Action3 }, -- manos trabajando (fabricar, cocinar)
		Crawl = { id = "rbxassetid://120906840673143", priority = Enum.AnimationPriority.Action4, looped = true }, -- caído, se arrastra
		Revive = { id = "rbxassetid://109653278143351", priority = Enum.AnimationPriority.Action4, looped = true }, -- de rodillas, reanima
		-- Montado (Fase 11, UI/MountRiders): a horcajadas sobre la montura, con las riendas, en bucle.
		Ride = { id = "rbxassetid://88188843088858", priority = Enum.AnimationPriority.Action4, looped = true },
	} :: { [Key]: PlayerAnimation },

	-- Gesto de cada habilidad de Data/Roles. El Torbellino no va aquí: dura lo que el giro y lo para
	-- RoleController. El Parpadeo no lleva (teletransporta).
	Abilities = {
		Quake = "Quake",
		Leap = "Quake", -- se agacha y se impulsa con el pisotón; el arco lo hace RoleController
		WarCry = "WarCry",
		Charge = "Charge",
		MultiShot = "CastForward",
		MarkPrey = "CastForward",
		Trap = "Place",
		ArrowRain = "CastArea",
		TrueShot = "CastForward",
		Fireball = "CastForward",
		FrostNova = "CastArea",
		ChainLightning = "CastForward",
		LavaBeam = "CastForward",
		AreaHeal = "CastArea",
		HealingDart = "CastForward",
		LeafShield = "CastArea",
		HealingTotem = "Place",
		Resurgence = "CastArea",
		Smash = "Smash",
		PiercingShot = "CastForward",
		Meteor = "CastArea",
		SleepPowder = "CastForward",
	} :: { [string]: Key },
}

return PlayerAnimations
