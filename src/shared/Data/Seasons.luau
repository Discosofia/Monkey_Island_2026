--!strict
-- Temporadas del pase (Fase 9; Shared/SeasonPass, ServerShared/SeasonPass), en orden. Cada una dura
-- Config.Season.Days días desde "startsAt" (00:00 UTC) y después hay Config.Season.RestDays de descanso
-- (sin XP; lo que no se reclamó se entrega solo) antes de la siguiente. Lista para preparar una:
-- .claude/skills/economia-retencion/references/nueva-temporada.md.
--
-- "levels": un premio por nivel (1..Config.Season.Levels) en cada pista:
--   - free: Ámbar, provisiones ("items"), tiempo de huevo ("eggSeconds", con el tope de lo ganado
--     jugando), un huevo ("egg") o un cosmético ("cosmetic", id de Data/Cosmetics). Lo que no es
--     cosmético solo se desbloquea con nivel GANADO jugando, nunca con niveles comprados.
--   - premium: solo un cosmético (la premium se compra con Robux: nada que dé ventaja, Ámbar ni
--     tiempo de huevo; la calculadora lo comprueba).
-- Los cosméticos de la temporada llevan source = { season = "<id>" } en Data/Cosmetics.

export type PassReward = {
	amber: number?,
	items: { [string]: number }?,
	eggSeconds: number?,
	egg: { [string]: number }?,
	cosmetic: string?,
}

export type Level = { free: PassReward?, premium: PassReward? }

export type Season = {
	id: string,
	name: string,
	icon: string,
	color: Color3,
	startsAt: number, -- segundos UTC (DateTime)
	levels: { Level },
}

local function utc(year: number, month: number, day: number): number
	return DateTime.fromUniversalTime(year, month, day).UnixTimestamp
end

local MIN = 60
local HOUR = 60 * MIN

local Seasons: { Season } = {
	{
		id = "T1",
		name = "El Despertar del Volcán",
		icon = "🌋",
		color = Color3.fromRGB(255, 120, 50),
		-- Provisional (lunes): la fecha de verdad se pone antes de publicar (docs/LANZAMIENTO.md).
		startsAt = utc(2026, 10, 19),
		-- Contenido de la temporada (grupo G11 del plan): trajes y armas de fuego azul y azufre (G11a);
		-- mascotas, marcos y estelas (G11b); emotes (G11c); los tres grados de la Llama primal (N1, N15, N30);
		-- títulos, números, estallidos y nidos en el resto (G11d). Un premio premium en cada nivel.
		levels = {
			{ free = { cosmetic = "TitleCastaway" }, premium = { cosmetic = "PrimalFlameAura" } },
			{ free = { amber = 75 }, premium = { cosmetic = "EmoteGorillaRoar" } },
			{ free = { items = { Banana = 5, Bandage = 2 } }, premium = { cosmetic = "SulfurMace" } },
			{ free = { eggSeconds = 30 * MIN, cosmetic = "BronzeFrame" }, premium = { cosmetic = "TitleVolcanoSon" } },
			{ free = { amber = 100 }, premium = { cosmetic = "BlueFireGuardianOutfit" } },
			{
				free = { items = { Torch = 1, Antidote = 1 }, cosmetic = "EmoteMonkeySalute" },
				premium = { cosmetic = "MagmaNumbers" },
			},
			{ free = { eggSeconds = 30 * MIN }, premium = { cosmetic = "SulfurBow" } },
			{ free = { amber = 100, cosmetic = "SulfurMachete" }, premium = { cosmetic = "VolcanicBurst" } },
			{ free = { items = { SuperBandage = 1 } }, premium = { cosmetic = "EmoteFireDance" } },
			{ free = { amber = 150 }, premium = { cosmetic = "BlueFireStalkerOutfit" } },
			{ free = { eggSeconds = 45 * MIN }, premium = { cosmetic = "MagmaStepTrail" } },
			{
				free = { items = { Bandage = 3 }, cosmetic = "LavaTurtleSkin" },
				premium = { cosmetic = "VolcanicNest" },
			},
			{ free = { amber = 100 }, premium = { cosmetic = "SulfurStaff" } },
			{ free = { eggSeconds = 45 * MIN }, premium = { cosmetic = "BlueFireNumbers" } },
			{ free = { cosmetic = "AshTrail" }, premium = { cosmetic = "PrimalFlameAuraII" } },
			{ free = { amber = 125 }, premium = { cosmetic = "BlueFireTrail" } },
			{ free = { items = { ReviveKit = 1 } }, premium = { cosmetic = "EmoteEruption" } },
			{ free = { eggSeconds = HOUR }, premium = { cosmetic = "SulfurBlowgun" } },
			{ free = { amber = 125 }, premium = { cosmetic = "TitleAshWalker" } },
			{ free = { egg = { Rare = 1 } }, premium = { cosmetic = "BlueFireInvokerOutfit" } },
			{ free = { items = { Antidote = 2, SuperBandage = 1 } }, premium = { cosmetic = "BlueFireFrame" } },
			{ free = { amber = 150, cosmetic = "SilverFrame" }, premium = { cosmetic = "BlueFireBurst" } },
			{ free = { eggSeconds = HOUR }, premium = { cosmetic = "MagmaJaguarSkin" } },
			{ free = { items = { Torch = 2, Banana = 5 } }, premium = { cosmetic = "TitleMagmaTamer" } },
			{ free = { amber = 200 }, premium = { cosmetic = "BlueFireHealerOutfit" } },
			{ free = { eggSeconds = HOUR }, premium = { cosmetic = "TitleBlueFlameGuardian" } },
			{ free = { items = { ReviveKit = 1, SuperBandage = 2 } }, premium = { cosmetic = "MoltenObsidianFrame" } },
			{ free = { amber = 200 }, premium = { cosmetic = "SulfurCraterNest" } },
			{ free = { eggSeconds = 90 * MIN }, premium = { cosmetic = "TitlePrimalKing" } },
			{ free = { cosmetic = "TitleVolcanoLord", amber = 300 }, premium = { cosmetic = "PrimalFlameAuraIII" } },
		},
	},
}

return Seasons
