--!strict
-- Armaduras (Fase 1.6). Se fabrican en la mesa de trabajo (Data/Recipes) y se llevan puestas.
-- El jugador guarda la que lleva en el atributo "Armor".

export type ArmorDefinition = {
	name: string,
	damageReduction: number, -- fracción del daño que se evita (0.25 = 25 %)
	color: Color3,
	material: Enum.Material,
}

local Armor: { [string]: ArmorDefinition } = {
	FurVest = {
		name = "Chaleco de pelaje",
		damageReduction = 0.25,
		color = Color3.fromRGB(150, 70, 45),
		material = Enum.Material.Fabric,
	},
}

return Armor
