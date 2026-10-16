--!strict
-- Ventajas de un jugador en la Isla (Fase 3): las dan su rol, sus talentos y las mejoras de la tienda.
-- Todas se suman sobre su valor por defecto (Shared/Progression las calcula y RoleService las publica
-- como atributos "Perk_<nombre>"). Cada sistema lee la suya con Progression.perk(player, nombre).

local Perks: { [string]: number } = {
	-- Combate en general.
	MeleeDamage = 1, -- multiplica el daño cuerpo a cuerpo (armas y habilidades del guerrero)
	RangedDamage = 1, -- multiplica el daño a distancia (honda, arco y habilidades del cazador)
	SpellDamage = 1, -- multiplica el daño de los hechizos (bastón y habilidades del mago)
	CooldownRate = 1, -- multiplica el tiempo de espera de las habilidades
	-- Guerrero.
	WhirlwindSeconds = 2, -- duración de "Torbellino"
	ChargeDamage = 1, -- multiplica el daño de "Embestida"
	WarCryReduction = 0.4, -- daño que se ahorra (fracción) durante "Grito de guerra"
	QuakeStun = 2, -- segundos que aturde el "Pisotón"
	SmashDamage = 1, -- multiplica el daño de "Rompehuesos"
	-- Cazador.
	MultiShotCount = 5, -- proyectiles de "Disparo múltiple"
	MarkSeconds = 5, -- duración de "Marcar presas" (con 15 s de recarga, un tercio del tiempo)
	MarkedBonus = 0.2, -- daño extra (fracción) que reciben los monos que marcas
	TrapRoot = 1.8, -- segundos que sujeta el "Cepo"
	RainDamage = 1, -- multiplica el daño de "Lluvia de proyectiles"
	PierceDamage = 1, -- multiplica el daño de "Flecha perforante"
	-- Mago.
	FireballDamage = 1, -- multiplica el daño de "Bola de fuego"
	NovaFreeze = 1.2, -- segundos que congela "Nova de hielo"
	BlinkDistance = 25, -- studs que avanza "Parpadeo"
	ChainJumps = 4, -- saltos de "Rayo encadenado"
	MeteorSlow = 0, -- segundos que el "Meteoro" ralentiza a los que alcanza
	-- Médico.
	ReviveSpeed = 1, -- multiplica el tiempo de mantener "Reanimar" (0.5 = el doble de rápido)
	ReviveHealth = 0, -- vida extra (fracción) con la que se levanta quien reanimas
	HealPower = 1, -- multiplica lo que curan tus vendas, ungüentos y habilidades
	SeeHealth = 0, -- 1 = ves la vida de tus aliados sobre sus cabezas
	ShieldAmount = 24, -- daño que absorbe el "Escudo de hojas"
	PowderSleep = 1.5, -- segundos que duerme el "Polvo somnífero"
	-- Recolección (mejoras de la tienda y mascotas).
	HarvestSpeed = 1, -- multiplica el tiempo de mantener los avisos de recolección
	HarvestBonus = 0, -- material extra en cada recolección
	ToolPower = 0, -- potencia extra por golpe del hacha y el pico
	-- Supervivencia.
	MaxHealth = 0, -- vida máxima extra
	HungerRate = 1, -- multiplica lo rápido que bajan el hambre y la sed
	SprintCost = 1, -- multiplica la estamina que gasta correr
	StartKit = 0, -- cada punto: empiezas con 5 de madera, piedra y fibra
}

return Perks
