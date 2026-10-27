--!strict
-- Estructuras de la parcela permanente (Fase 12, P3; Shared/Plot): cada una con 3 niveles (I/II/III).
-- Subir un nivel cuesta Ámbar (del perfil) y materiales (de la Bolsa de la partida; desde P4, del
-- cofre). El nivel se guarda en el perfil y nunca baja. En la partida, cada estructura tiene vida: a 0
-- queda rota y no da su efecto hasta que se repara o hasta el amanecer (PlotService).
--   - "size": caja que ocupa en la parcela (la de su pieza invisible "Bounds", Shared/PlotModels); su
--     sitio y su giro, Config.Plot.Layout.
--   - "buildableId": la pieza de Data/Buildables que hace su papel en la partida (la cama marca dónde
--     reapareces, el nido es el de los huevos): la buscan otros sistemas por ese atributo.
--   - "station": estación de crafteo (Data/Stations) que abre su aviso; "extraStation" en un nivel, otra
--     más en el mismo sitio (la forja III también es forja volcánica).
--   - Efectos por nivel (solo los que tiene cada estructura): "discount" (parte de los materiales que se
--     ahorra en las recetas de "stations"), "bandages" y "food" (lo que deja en la Bolsa al amanecer),
--     "downedFactor" (multiplica Config.Life.DownedSeconds) y "restRegen" (vida por segundo cerca de la
--     cama, sin daño reciente). El cofre, la incubadora y el nido dan su efecto en P4 y P5.
-- Precios de prueba (27-10-2026): 600 / 2.400 / 6.000 Ámbar por estructura, 63.000 las 7 al nivel III.
-- Con el Ámbar que sobra medido en la calculadora (Economia, 60 días), el grupo de amigos las tiene en
-- unos 3 meses y el intenso en algo más de 1. Los fija P6 con la sección "Parcela" de Economia.

export type Cost = { itemId: string, amount: number }

export type Level = {
	amber: number,
	cost: { Cost },
	health: number,
	effect: string, -- lo que da, en una línea (la ventana Parcela)
	discount: number?,
	stations: { string }?,
	extraStation: string?,
	bandages: number?,
	food: { [string]: number }?,
	downedFactor: number?,
	restRegen: number?,
}

export type Structure = {
	name: string,
	icon: string, -- emoji anterior a 2020
	description: string,
	size: Vector3,
	buildableId: string?,
	station: string?,
	hitSound: string?,
	levels: { Level },
}

local FORGE_STATIONS = { "Forge", "VolcanicForge" }
local HEALER_STATIONS = { "Healer" }

local PlotStructures: { [string]: Structure } = {
	Forge = {
		name = "Forja",
		icon = "⚒️",
		description = "Tu forja: el equipo de la forja de piedra, con menos materiales.",
		size = Vector3.new(6, 5, 6),
		buildableId = "StoneForge",
		station = "Forge",
		hitSound = "StructureHitStone",
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Stone", amount = 30 }, { itemId = "Wood", amount = 10 } },
				health = 500,
				effect = "−10 % de materiales en la forja",
				discount = 0.1,
				stations = FORGE_STATIONS,
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Stone", amount = 40 },
					{ itemId = "Bone", amount = 10 },
					{ itemId = "BigFang", amount = 3 },
				},
				health = 800,
				effect = "−20 % de materiales en la forja",
				discount = 0.2,
				stations = FORGE_STATIONS,
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Stone", amount = 40 },
					{ itemId = "Obsidian", amount = 10 },
					{ itemId = "ThickBone", amount = 3 },
				},
				health = 1200,
				effect = "−30 % de materiales y forja volcánica",
				discount = 0.3,
				stations = FORGE_STATIONS,
				extraStation = "VolcanicForge",
			},
		},
	},
	Healer = {
		name = "Taller del curandero",
		icon = "🌿",
		description = "Tu taller: vendas gratis cada amanecer y curas más baratas.",
		size = Vector3.new(7, 6, 6),
		buildableId = "HealerTent",
		station = "Healer",
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Fiber", amount = 20 }, { itemId = "Wood", amount = 10 } },
				health = 400,
				effect = "1 venda al amanecer · −10 % en curas",
				bandages = 1,
				discount = 0.1,
				stations = HEALER_STATIONS,
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Fiber", amount = 30 },
					{ itemId = "RedFur", amount = 6 },
					{ itemId = "Leather", amount = 6 },
				},
				health = 650,
				effect = "2 vendas al amanecer · −20 % en curas",
				bandages = 2,
				discount = 0.2,
				stations = HEALER_STATIONS,
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Liana", amount = 6 },
					{ itemId = "Shell", amount = 10 },
					{ itemId = "SilverFur", amount = 2 },
				},
				health = 950,
				effect = "3 vendas al amanecer · −30 % en curas",
				bandages = 3,
				discount = 0.3,
				stations = HEALER_STATIONS,
			},
		},
	},
	Garden = {
		name = "Huerto",
		icon = "🍌",
		description = "Tu huerto: cada amanecer deja plátanos y bananos en tu Bolsa.",
		size = Vector3.new(6, 2, 7),
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Wood", amount = 15 }, { itemId = "Fiber", amount = 15 } },
				health = 300,
				effect = "2 de fruta cada amanecer",
				food = { Banana = 1, Plantain = 1 },
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Wood", amount = 25 },
					{ itemId = "Bone", amount = 6 },
					{ itemId = "Shell", amount = 8 },
				},
				health = 500,
				effect = "4 de fruta cada amanecer",
				food = { Banana = 2, Plantain = 2 },
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Stone", amount = 30 },
					{ itemId = "Liana", amount = 6 },
					{ itemId = "GoldenFur", amount = 6 },
				},
				health = 750,
				effect = "6 de fruta cada amanecer",
				food = { Banana = 3, Plantain = 3 },
			},
		},
	},
	Bed = {
		name = "Cama",
		icon = "🛏️",
		description = "Tu cama: reapareces en ella antes y, descansando a su lado, recuperas vida.",
		size = Vector3.new(4, 1.6, 7),
		buildableId = "Bed",
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Wood", amount = 15 }, { itemId = "Fiber", amount = 10 } },
				health = 300,
				effect = "Reapareces en 50 s · +1 vida/s a su lado",
				downedFactor = 50 / 60,
				restRegen = 1,
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Wood", amount = 20 },
					{ itemId = "Leather", amount = 8 },
					{ itemId = "GreyFur", amount = 8 },
				},
				health = 500,
				effect = "Reapareces en 40 s · +2 vida/s a su lado",
				downedFactor = 40 / 60,
				restRegen = 2,
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Wood", amount = 30 },
					{ itemId = "OrangeFur", amount = 4 },
					{ itemId = "SilverFur", amount = 2 },
				},
				health = 750,
				effect = "Reapareces en 30 s · +3 vida/s a su lado",
				downedFactor = 30 / 60,
				restRegen = 3,
			},
		},
	},
	Chest = {
		name = "Cofre",
		icon = "📦",
		description = "Tu cofre: guarda materiales y consumibles de una partida a otra (llega en P4).",
		size = Vector3.new(4, 3, 3),
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Wood", amount = 25 } },
				health = 400,
				effect = "Cofre pequeño (pronto)",
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Wood", amount = 30 },
					{ itemId = "Stone", amount = 20 },
					{ itemId = "ShipMetal", amount = 2 },
				},
				health = 650,
				effect = "Cofre mediano (pronto)",
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Stone", amount = 40 },
					{ itemId = "ShipMetal", amount = 6 },
					{ itemId = "GoldenFur", amount = 4 },
				},
				health = 950,
				effect = "Cofre grande (pronto)",
			},
		},
	},
	Incubator = {
		name = "Incubadora",
		icon = "🌡️",
		description = "Tu incubadora: acelera el huevo de tu nido del Lobby (llega en P5).",
		size = Vector3.new(4, 4, 4),
		hitSound = "StructureHitStone",
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Stone", amount = 15 }, { itemId = "Fiber", amount = 15 } },
				health = 350,
				effect = "Huevo del nido más rápido (pronto)",
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Stone", amount = 25 },
					{ itemId = "Shell", amount = 10 },
					{ itemId = "GoldenFur", amount = 4 },
				},
				health = 600,
				effect = "Huevo del nido más rápido aún (pronto)",
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Obsidian", amount = 8 },
					{ itemId = "Shell", amount = 12 },
					{ itemId = "SilverFur", amount = 2 },
				},
				health = 900,
				effect = "Un segundo hueco en el nido (pronto)",
			},
		},
	},
	Nest = {
		name = "Nido",
		icon = "🥚",
		description = "Tu nido: defiende en él los huevos que encuentres en la partida.",
		size = Vector3.new(6, 3, 6),
		buildableId = "Nest",
		levels = {
			{
				amber = 600,
				cost = { { itemId = "Wood", amount = 15 }, { itemId = "Fiber", amount = 15 } },
				health = 600,
				effect = "Nido para los huevos de la partida",
			},
			{
				amber = 2400,
				cost = {
					{ itemId = "Wood", amount = 20 },
					{ itemId = "Liana", amount = 4 },
					{ itemId = "GoldenFur", amount = 4 },
				},
				health = 900,
				effect = "Más vida (y mejor huevo, pronto)",
			},
			{
				amber = 6000,
				cost = {
					{ itemId = "Liana", amount = 8 },
					{ itemId = "GoldenFur", amount = 8 },
					{ itemId = "OrangeFur", amount = 4 },
				},
				health = 1300,
				effect = "Aún más vida (y mejor huevo, pronto)",
			},
		},
	},
}

return PlotStructures
