--!strict
-- Equipamiento de la arena de Dunas: se compra con Ámbar (en la base o en el Lobby) y solo cuenta en
-- la arena. Cada rol tiene tres ranuras (arma, armadura y amuleto); en cada una lleva lo básico
-- (gratis, sin cambios) o una de dos variantes. Progresión horizontal (docs/GDD.md, "La arena"):
-- ninguna variante es mejor sin más; cada una cambia cómo juegas el rol a cambio de algo ("perks":
-- lo que suma a sus ventajas de Data/Perks, en positivo y en negativo). Se miden con la calculadora
-- (ServerStorage.Tools.Equilibrio, opción "equipo") para que ninguna se salga del duelo de 8–10 s.

export type Slot = "Weapon" | "Armor" | "Amulet"

export type Gear = {
	role: string, -- id de Data/Roles
	slot: Slot,
	name: string,
	icon: string,
	description: string, -- para el jugador: qué gana y qué pierde
	cost: number, -- Ámbar
	perks: { [string]: number },
	order: number, -- orden dentro de su ranura
}

local ArenaGear = {}

ArenaGear.SLOTS = { "Weapon", "Armor", "Amulet" } :: { Slot }
ArenaGear.SLOT_NAMES = { Weapon = "Arma", Armor = "Armadura", Amulet = "Amuleto" }

-- Precio por ranura: la primera compra (un amuleto) cuesta lo de 1–2 partidas.
local COST = { Weapon = 200, Armor = 150, Amulet = 100 }

ArenaGear.items = {
	-- ⚔️ Guerrero.
	BoneMaul = {
		role = "Guerrero",
		slot = "Weapon",
		order = 1,
		name = "Maza de hueso grueso",
		icon = "🦴",
		description = "Rompehuesos pega un 40 % más, pero tarda un 40 % más en recargarse",
		cost = COST.Weapon,
		perks = { SmashDamage = 0.4, SmashCooldown = 0.4 },
	},
	LightClub = {
		role = "Guerrero",
		slot = "Weapon",
		order = 2,
		name = "Garrote ligero",
		icon = "🌀",
		description = "Torbellino dura 1 s más, pero tus golpes cuerpo a cuerpo hacen un 6 % menos",
		cost = COST.Weapon,
		perks = { WhirlwindSeconds = 1, MeleeDamage = -0.06 },
	},
	AmberScales = {
		role = "Guerrero",
		slot = "Armor",
		order = 1,
		name = "Peto de escamas de ámbar",
		icon = "🛡️",
		description = "Grito de guerra protege también a los aliados cercanos, pero protege un 10 % menos",
		cost = COST.Armor,
		perks = { WarCryAllies = 1, WarCryReduction = -0.1 },
	},
	JaguarHide = {
		role = "Guerrero",
		slot = "Armor",
		order = 2,
		name = "Coraza de jaguar",
		icon = "🐆",
		description = "+15 de vida, pero vas un 8 % más lento",
		cost = COST.Armor,
		perks = { MaxHealth = 15, MoveSpeed = -0.08 },
	},
	AmbushBracers = {
		role = "Guerrero",
		slot = "Amulet",
		order = 1,
		name = "Brazales de emboscada",
		icon = "🚩",
		description = "Con la bandera rival casi no te frenas, pero tienes 10 de vida menos",
		cost = COST.Amulet,
		perks = { CarrySpeed = 0.1, MaxHealth = -10 },
	},
	BerserkerFang = {
		role = "Guerrero",
		slot = "Amulet",
		order = 2,
		name = "Colmillo del berserker",
		icon = "🦷",
		description = "Embestida pega un 40 % más, pero Grito de guerra protege un 15 % menos",
		cost = COST.Amulet,
		perks = { ChargeDamage = 0.4, WarCryReduction = -0.15 },
	},

	-- 🏹 Cazador.
	LianaBow = {
		role = "Cazador",
		slot = "Weapon",
		order = 1,
		name = "Arco de liana",
		icon = "🎯",
		description = "Flecha perforante pega un 30 % más, pero Disparo múltiple lanza una flecha menos",
		cost = COST.Weapon,
		perks = { PierceDamage = 0.3, MultiShotCount = -1 },
	},
	ShortBow = {
		role = "Cazador",
		slot = "Weapon",
		order = 2,
		name = "Arco corto",
		icon = "🏹",
		description = "Disparo múltiple lanza 2 flechas más, pero tus disparos hacen un 7 % menos",
		cost = COST.Weapon,
		perks = { MultiShotCount = 2, RangedDamage = -0.07 },
	},
	TrackerCape = {
		role = "Cazador",
		slot = "Armor",
		order = 1,
		name = "Capa de rastreador",
		icon = "👁️",
		description = "Marcar presas dura 2 s más, pero tienes 10 de vida menos",
		cost = COST.Armor,
		perks = { MarkSeconds = 2, MaxHealth = -10 },
	},
	LeatherJerkin = {
		role = "Cazador",
		slot = "Armor",
		order = 2,
		name = "Jubón de cuero",
		icon = "🧥",
		description = "+15 de vida, pero vas un 5 % más lento",
		cost = COST.Armor,
		perks = { MaxHealth = 15, MoveSpeed = -0.05 },
	},
	ThornTrap = {
		role = "Cazador",
		slot = "Amulet",
		order = 1,
		name = "Cepo de espinas",
		icon = "⛓️",
		description = "El cepo sujeta 0,6 s más, pero tus marcas suman un 5 % menos de daño",
		cost = COST.Amulet,
		perks = { TrapRoot = 0.6, MarkedBonus = -0.05 },
	},
	HummingbirdFeathers = {
		role = "Cazador",
		slot = "Amulet",
		order = 2,
		name = "Plumas de colibrí",
		icon = "🪶",
		description = "Vas un 8 % más rápido, pero tienes 10 de vida menos",
		cost = COST.Amulet,
		perks = { MoveSpeed = 0.08, MaxHealth = -10 },
	},

	-- 🔮 Mago.
	VolcanicStaff = {
		role = "Mago",
		slot = "Weapon",
		order = 1,
		name = "Bastón volcánico",
		icon = "🌋",
		description = "Bola de fuego pega un 25 % más, pero Nova de hielo congela 0,3 s menos",
		cost = COST.Weapon,
		perks = { FireballDamage = 0.25, NovaFreeze = -0.3 },
	},
	CrystalStaff = {
		role = "Mago",
		slot = "Weapon",
		order = 2,
		name = "Bastón de cristal",
		icon = "❄️",
		description = "Nova de hielo congela 0,4 s más, pero Bola de fuego pega un 20 % menos",
		cost = COST.Weapon,
		perks = { NovaFreeze = 0.4, FireballDamage = -0.2 },
	},
	AmuletMantle = {
		role = "Mago",
		slot = "Armor",
		order = 1,
		name = "Manto de amuletos",
		icon = "🧿",
		description = "+15 de vida, pero Parpadeo llega 5 studs menos",
		cost = COST.Armor,
		perks = { MaxHealth = 15, BlinkDistance = -5 },
	},
	LightRobe = {
		role = "Mago",
		slot = "Armor",
		order = 2,
		name = "Túnica ligera",
		icon = "💨",
		description = "Parpadeo llega 8 studs más lejos, pero tienes 10 de vida menos",
		cost = COST.Armor,
		perks = { BlinkDistance = 8, MaxHealth = -10 },
	},
	TranspositionAmulet = {
		role = "Mago",
		slot = "Amulet",
		order = 1,
		name = "Amuleto de transposición",
		icon = "⏳",
		description = "Tus habilidades se recargan un 6 % antes, pero tus hechizos hacen un 5 % menos",
		cost = COST.Amulet,
		perks = { CooldownRate = -0.06, SpellDamage = -0.05 },
	},
	MeteorEye = {
		role = "Mago",
		slot = "Amulet",
		order = 2,
		name = "Ojo del meteoro",
		icon = "☄️",
		description = "El Meteoro ralentiza 1 s a los que alcanza, pero el Rayo encadenado salta una vez menos",
		cost = COST.Amulet,
		perks = { MeteorSlow = 1, ChainJumps = -1 },
	},

	-- ⛑️ Médico.
	ShamanBlowgun = {
		role = "Medico",
		slot = "Weapon",
		order = 1,
		name = "Cerbatana del chamán",
		icon = "🌿",
		description = "Curas un 20 % más, pero tus dardos hacen un 15 % menos de daño",
		cost = COST.Weapon,
		perks = { HealPower = 0.2, RangedDamage = -0.15 },
	},
	ThornBlowgun = {
		role = "Medico",
		slot = "Weapon",
		order = 2,
		name = "Cerbatana de espinas",
		icon = "🌵",
		description = "Tus dardos hacen un 15 % más de daño, pero curas un 20 % menos",
		cost = COST.Weapon,
		perks = { RangedDamage = 0.15, HealPower = -0.2 },
	},
	HealerVest = {
		role = "Medico",
		slot = "Armor",
		order = 1,
		name = "Peto de curandero",
		icon = "🍃",
		description = "El Escudo de hojas absorbe 8 más, pero tienes 10 de vida menos",
		cost = COST.Armor,
		perks = { ShieldAmount = 8, MaxHealth = -10 },
	},
	HerbBandolier = {
		role = "Medico",
		slot = "Armor",
		order = 2,
		name = "Bandolera de hierbas",
		icon = "🎒",
		description = "+15 de vida, pero el Escudo de hojas absorbe 6 menos",
		cost = COST.Armor,
		perks = { MaxHealth = 15, ShieldAmount = -6 },
	},
	DenseDust = {
		role = "Medico",
		slot = "Amulet",
		order = 1,
		name = "Polvo somnífero denso",
		icon = "💤",
		description = "El Polvo somnífero duerme 0,5 s más, pero curas un 10 % menos",
		cost = COST.Amulet,
		perks = { PowderSleep = 0.5, HealPower = -0.1 },
	},
	ThickSap = {
		role = "Medico",
		slot = "Amulet",
		order = 2,
		name = "Savia espesa",
		icon = "🍯",
		description = "La Savia protectora te da 6 de escudo más, pero el Escudo de hojas absorbe 6 menos",
		cost = COST.Amulet,
		perks = { SapShield = 6, ShieldAmount = -6 },
	},
} :: { [string]: Gear }

-- Las variantes de "roleId" en "slot", en orden.
function ArenaGear.options(roleId: string, slot: Slot): { string }
	local ids = {}
	for id, item in ArenaGear.items do
		if item.role == roleId and item.slot == slot then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return ArenaGear.items[a].order < ArenaGear.items[b].order
	end)
	return ids
end

-- Las ventajas del equipamiento puesto ("loadout": ranura → id; lo que no sea de ese rol no cuenta).
function ArenaGear.perksOf(roleId: string, loadout: { [string]: any }?): { { [string]: number } }
	local list = {}
	for _, slot in ArenaGear.SLOTS do
		local id = if loadout then loadout[slot] else nil
		local item = if typeof(id) == "string" then ArenaGear.items[id] else nil
		if item and item.role == roleId and item.slot == slot then
			table.insert(list, item.perks)
		end
	end
	return list
end

return ArenaGear
