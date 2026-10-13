--!strict
-- Ventajas de un jugador en la Isla (Fase 3): las dan su rol, sus talentos y las mejoras de la tienda.
-- Todas se suman sobre su valor por defecto (Shared/Progression las calcula y RoleService las publica
-- como atributos "Perk_<nombre>"). Cada sistema lee la suya con Progression.perk(player, nombre).

local Perks: { [string]: number } = {
	ReviveSpeed = 1, -- multiplica el tiempo de mantener "Reanimar" (0.5 = el doble de rápido)
	ReviveHealth = 0, -- vida extra (fracción) con la que se levanta quien reanimas
	HealPower = 1, -- multiplica lo que curan tus vendas, ungüentos y tu habilidad
	SeeHealth = 0, -- 1 = ves la vida de tus aliados sobre sus cabezas
	RangedDamage = 1, -- multiplica el daño a distancia (honda)
	MarkSeconds = 10, -- duración de "Marcar presas"
	MarkedBonus = 0.2, -- daño extra (fracción) que reciben los monos que marcas
	HarvestSpeed = 1, -- multiplica el tiempo de mantener los avisos de recolección
	HarvestBonus = 0, -- material extra en cada recolección
	ToolPower = 0, -- potencia extra por golpe del hacha y el pico
	MaxHealth = 0, -- vida máxima extra
	HungerRate = 1, -- multiplica lo rápido que bajan el hambre y la sed
	SprintCost = 1, -- multiplica la estamina que gasta correr
	StartKit = 0, -- cada punto: empiezas con 5 de madera, piedra y fibra
}

return Perks
