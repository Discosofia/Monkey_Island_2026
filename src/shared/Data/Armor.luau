--!strict
-- Armaduras (Fase 1.6). Se fabrican en la mesa de trabajo (Data/Recipes) y se llevan puestas.
-- El jugador guarda la que lleva en el atributo "Armor".
-- Su modelo (piezas sobre el torso, los brazos y los muslos) está en island/server/Combat/ArmorModels; "color" y "material"
-- son su color principal, para la interfaz. Cada rol la lleva con otro aspecto: "name" es el del
-- guerrero (y de los roles que aún no tienen la suya) y "roleNames" el de los demás (Crafting.armorName).

export type ArmorDefinition = {
	name: string,
	damageReduction: number, -- fracción del daño que se evita (0.25 = 25 %)
	color: Color3,
	material: Enum.Material,
	roleNames: { [string]: string }?,
}

local Armor: { [string]: ArmorDefinition } = {
	FurVest = {
		name = "Chaleco de pelaje",
		roleNames = { Cazador = "Capa de rastreador" },
		damageReduction = 0.25,
		color = Color3.fromRGB(150, 70, 45),
		material = Enum.Material.Fabric,
	},
	-- Fase 2.3 (forja de piedra).
	BoneArmor = {
		name = "Armadura de hueso",
		roleNames = { Cazador = "Armadura de cazador" },
		damageReduction = 0.4,
		color = Color3.fromRGB(225, 215, 190),
		material = Enum.Material.Slate,
	},
	-- Fase 4 (forja de piedra, con pelaje plateado de gorila).
	SilverArmor = {
		name = "Armadura de plata",
		roleNames = { Cazador = "Manto de cazador plateado" },
		damageReduction = 0.55,
		color = Color3.fromRGB(200, 205, 215),
		material = Enum.Material.Fabric,
	},
}

return Armor
