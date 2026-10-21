--!strict
-- Rarezas del botín (GDD §9.1, Fase 4): nombre y color con que se muestran en el inventario y el diario.
-- Mítico (Fase 9, G9) es solo de cosméticos, por encima de Legendario: nunca sale de un huevo ni del
-- botín. Cuanto más raro, más detalle lleva el diseño (Data/Cosmetics).

export type Rarity = { name: string, color: Color3, order: number }

local Rarities: { [string]: Rarity } = {
	Common = { name = "Común", color = Color3.fromRGB(225, 225, 225), order = 1 },
	Uncommon = { name = "Poco común", color = Color3.fromRGB(120, 220, 120), order = 2 },
	Rare = { name = "Raro", color = Color3.fromRGB(90, 160, 255), order = 3 },
	Epic = { name = "Épico", color = Color3.fromRGB(200, 110, 255), order = 4 },
	Legendary = { name = "Legendario", color = Color3.fromRGB(255, 180, 50), order = 5 },
	Mythic = { name = "Mítico", color = Color3.fromRGB(255, 70, 110), order = 6 },
}

return Rarities
