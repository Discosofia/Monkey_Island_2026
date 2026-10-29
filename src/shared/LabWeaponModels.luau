--!strict
-- Modelos voxel de las cuatro armas del Laboratorio en ruinas (Fase 13, Data/LabWeapons), uno por
-- facción con la misma silueta y la misma empuñadura (los mismos números):
--   - Guardianes del laboratorio: plástico blanco con franja azul, luces azules y un sensor.
--   - Piratas invasores: latón, madera y hierro negro, cuerda en la empuñadura y un amuleto de hueso
--     colgando (se ve también por detrás).
-- Lo que se dispara se ve igual en las dos: dardos azul claro, banana amarilla, red y suero morado.
-- Ejes (como Shared/WeaponTools): +Y va de la mano hacia la boca del arma; la mano está en "Grip".
-- Las piezas se colocan con "at(lado, largo, arriba)" en studs, en bloques de rejilla (Shared/LabVoxel).
-- La facción la elige el atributo "LabFaction" del jugador (WeaponTools.skinOf) y, encima del arma del
-- bando, puede ir una skin ganada por bajas (L5b, Shared/LabWeaponSkins): el atributo "<arma>Skin".
-- "look" y "lookOf" juntan las dos en un texto: "Pirates:LabWaspII" (o solo "Pirates").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LabVoxel = require(ReplicatedStorage.Shared.LabVoxel)
local LabWeaponSkins = require(ReplicatedStorage.Shared.LabWeaponSkins)
local VoxelMerge = require(ReplicatedStorage.Shared.VoxelMerge)

export type Faction = "Guardians" | "Pirates"

type Palette = {
	body: Color3,
	bodyMaterial: Enum.Material,
	trim: Color3,
	trimMaterial: Enum.Material,
	stock: Color3,
	stockMaterial: Enum.Material,
	barrel: Color3,
	grip: Color3,
	gripMaterial: Enum.Material,
}

local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

-- Guardianes: blanco, gris claro y azul (nunca verde: es el color de la curación).
local LAB_WHITE = Color3.fromRGB(232, 236, 240)
local LAB_GREY = Color3.fromRGB(176, 184, 194)
local LAB_BLUE = Color3.fromRGB(40, 115, 215)
local LAB_DARK = Color3.fromRGB(52, 58, 68)
local LAB_GLOW = Color3.fromRGB(120, 200, 255)
-- Piratas: latón, oro, madera y hierro negro.
local BRASS = Color3.fromRGB(196, 152, 58)
local GOLD = Color3.fromRGB(234, 194, 80)
local PIRATE_WOOD = Color3.fromRGB(112, 72, 40)
local DARK_WOOD = Color3.fromRGB(72, 46, 26)
local IRON = Color3.fromRGB(34, 31, 30)
local ROPE = Color3.fromRGB(178, 150, 100)
local BONE = Color3.fromRGB(232, 222, 196)
-- Lo que dispara cada una (igual en las dos facciones; AbilityFxController usa los mismos tonos).
local DART = Color3.fromRGB(150, 215, 255)
local BANANA = Color3.fromRGB(255, 225, 60)
local NET = Color3.fromRGB(205, 190, 150)
local SERUM = Color3.fromRGB(120, 50, 195) -- sin neón ni luz: con ellos sale rosa
local BUBBLE = Color3.fromRGB(190, 140, 240)

local PALETTES: { [Faction]: Palette } = {
	Guardians = {
		body = LAB_WHITE,
		bodyMaterial = SMOOTH,
		trim = LAB_GREY,
		trimMaterial = SMOOTH,
		stock = LAB_WHITE,
		stockMaterial = SMOOTH,
		barrel = LAB_DARK,
		grip = LAB_DARK,
		gripMaterial = SMOOTH,
	},
	Pirates = {
		body = BRASS,
		bodyMaterial = METAL,
		trim = GOLD,
		trimMaterial = METAL,
		stock = PIRATE_WOOD,
		stockMaterial = WOOD,
		barrel = IRON,
		grip = ROPE,
		gripMaterial = FABRIC,
	},
}

local at, cube, glow = LabVoxel.at, LabVoxel.cube, LabVoxel.glow

local LabWeaponModels = {}

-- Culata, empuñadura y cajón comunes. "length": largo del cajón; "height": su alto. Devuelve el
-- "Handle" (invisible: marca la mano, en y = -0.8).
local function frame(tool: Tool, palette: Palette, faction: Faction, length: number, height: number): BasePart
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 1.2, 0.3)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	cube(handle, "Stock", at(0, -1.45, 0.05), Vector3.new(0.3, 0.6, height), palette.stock, palette.stockMaterial)
	cube(
		handle,
		"StockPad",
		at(0, -1.8, 0.05),
		Vector3.new(0.35, 0.1, height + 0.05),
		palette.trim,
		palette.trimMaterial
	)
	cube(handle, "Grip", at(0, -0.8, 0), Vector3.new(0.3, 0.7, 0.35), palette.grip, palette.gripMaterial)
	cube(
		handle,
		"Body",
		at(0, -0.45 + length / 2, 0.05),
		Vector3.new(0.45, length, height),
		palette.body,
		palette.bodyMaterial
	)
	if faction == "Guardians" then
		-- Franja azul a los dos lados y una luz azul encima, detrás.
		for side = -1, 1, 2 do
			cube(
				handle,
				"Stripe",
				at(side * 0.235, -0.45 + length / 2, 0.05),
				Vector3.new(0.05, length - 0.1, 0.15),
				LAB_BLUE,
				SMOOTH
			)
			cube(handle, "StockStripe", at(side * 0.16, -1.45, 0.05), Vector3.new(0.05, 0.5, 0.1), LAB_BLUE, SMOOTH)
		end
		local light = cube(
			handle,
			"Indicator",
			at(0, -0.35, 0.05 + height / 2 + 0.03),
			Vector3.new(0.2, 0.15, 0.05),
			LAB_GLOW,
			NEON
		)
		glow(light, LAB_GLOW, 4)
	else
		-- Remaches de oro, cuerda en la empuñadura y un amuleto de hueso colgando de la culata.
		for _, along in { -0.4, -0.45 + length - 0.1 } do
			cube(handle, "Band", at(0, along, 0.05), Vector3.new(0.5, 0.1, height + 0.05), GOLD, METAL)
		end
		for _, along in { -1.0, -0.8, -0.6 } do
			cube(handle, "Rope", at(0, along, 0), Vector3.new(0.35, 0.05, 0.4), DARK_WOOD, FABRIC)
		end
		cube(handle, "Cord", at(0.17, -1.55, -0.25), Vector3.new(0.05, 0.05, 0.3), ROPE, FABRIC)
		cube(handle, "Skull", at(0.17, -1.6, -0.5), Vector3.new(0.2, 0.2, 0.2), BONE, SMOOTH)
		for side = -1, 1, 2 do
			cube(handle, "SkullEye", at(0.17 + side * 0.05, -1.71, -0.48), Vector3.new(0.05, 0.05, 0.05), IRON, SMOOTH)
		end
	end
	tool.Grip = CFrame.new(0, -0.8, 0)
	return handle
end

-- Lanzadardos: subfusil compacto. Tambor de cristal con tres dardos a la vista sobre el cajón, cargador de
-- cristal debajo, funda del cañón con ventilas, empuñadura delantera, miras y freno de boca.
local function buildDartGun(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.3, 0.6)
	-- Tambor de dardos encima del cajón: dos tapas y el cristal con los dardos dentro.
	for _, along in { -0.2, 0.6 } do
		cube(handle, "DrumCap", at(0, along, 0.57), Vector3.new(0.55, 0.1, 0.45), palette.trim, palette.trimMaterial)
	end
	cube(handle, "Drum", at(0, 0.2, 0.57), Vector3.new(0.5, 0.7, 0.4), DART, GLASS).Transparency = 0.5
	for side = -1, 1 do
		cube(handle, "Dart", at(side * 0.15, 0.2, 0.57), Vector3.new(0.1, 0.55, 0.1), DART, NEON)
	end
	-- Cargador de cristal curvo debajo (dos tramos, el de abajo más adelantado), con su brocal y su base.
	cube(handle, "MagCollar", at(0, 0.25, -0.3), Vector3.new(0.4, 0.6, 0.1), palette.trim, palette.trimMaterial)
	cube(handle, "Magazine", at(0, 0.25, -0.55), Vector3.new(0.3, 0.5, 0.4), DART, GLASS).Transparency = 0.5
	cube(handle, "Magazine", at(0, 0.4, -0.95), Vector3.new(0.3, 0.5, 0.4), DART, GLASS).Transparency = 0.5
	cube(handle, "MagBase", at(0, 0.4, -1.2), Vector3.new(0.4, 0.6, 0.1), palette.trim, palette.trimMaterial)
	for side = -1, 1, 2 do
		cube(handle, "MagDart", at(side * 0.07, 0.32, -0.75), Vector3.new(0.08, 0.35, 0.6), DART, NEON)
	end
	-- Funda del cañón con dos ventilas por lado, el cañón y el freno de boca.
	cube(handle, "Shroud", at(0, 1.25, 0.1), Vector3.new(0.35, 0.8, 0.35), palette.trim, palette.trimMaterial)
	for side = -1, 1, 2 do
		for _, along in { 1.05, 1.4 } do
			cube(handle, "Vent", at(side * 0.19, along, 0.1), Vector3.new(0.05, 0.18, 0.15), palette.barrel, METAL)
		end
	end
	cube(handle, "Barrel", at(0, 1.8, 0.1), Vector3.new(0.18, 0.4, 0.18), palette.barrel, METAL)
	cube(handle, "Muzzle", at(0, 1.95, 0.1), Vector3.new(0.3, 0.15, 0.3), palette.trim, palette.trimMaterial)
	-- Empuñadura delantera bajo la funda.
	cube(handle, "ForeMount", at(0, 1.1, -0.08), Vector3.new(0.3, 0.35, 0.1), palette.trim, palette.trimMaterial)
	cube(handle, "ForeGrip", at(0, 1.1, -0.35), Vector3.new(0.22, 0.25, 0.45), palette.grip, palette.gripMaterial)
	-- Detalles de armero: puerto de expulsión a los dos lados y mejilla en la culata.
	for side = -1, 1, 2 do
		cube(handle, "Port", at(side * 0.25, 0.3, 0.1), Vector3.new(0.05, 0.35, 0.15), palette.barrel, METAL)
	end
	cube(handle, "Cheek", at(0, -1.45, 0.3), Vector3.new(0.32, 0.5, 0.15), palette.trim, palette.trimMaterial)
	-- Miras: la trasera sobre el cajón y la delantera sobre la funda.
	cube(handle, "RearSight", at(0, -0.3, 0.45), Vector3.new(0.15, 0.1, 0.15), palette.barrel, METAL)
	cube(handle, "FrontSight", at(0, 1.55, 0.37), Vector3.new(0.1, 0.1, 0.2), palette.barrel, METAL)
	if faction == "Guardians" then
		cube(handle, "Sensor", at(0, 1.6, 0.3), Vector3.new(0.2, 0.15, 0.1), LAB_BLUE, SMOOTH)
		local light = cube(handle, "ShroudLight", at(0, 0.95, 0.3), Vector3.new(0.1, 0.1, 0.05), LAB_GLOW, NEON)
		glow(light, LAB_GLOW, 3)
	else
		-- Plumas negras y doradas en la cola de los dardos y una cuerda en la empuñadura delantera.
		for side = -1, 1 do
			cube(
				handle,
				"Fletch",
				at(side * 0.15, -0.3, 0.57),
				Vector3.new(0.1, 0.1, 0.1),
				if side == 0 then GOLD else IRON,
				FABRIC
			)
		end
		for _, up in { -0.25, -0.4 } do
			cube(handle, "ForeRope", at(0, 1.1, up), Vector3.new(0.26, 0.3, 0.05), DARK_WOOD, FABRIC)
		end
	end
	return handle
end

-- Rifle: francotirador largo y fino. Mira grande de tubo con lente, cañón con guardamanos ventilado, freno
-- de boca, bípode plegado bajo el cañón, ventana amarilla en la recámara y cargador curvo de banana.
local function buildBananaRifle(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.1, 0.5)
	-- Recámara: marco del color del bando y ventana de banana que brilla, a los dos lados.
	for side = -1, 1, 2 do
		cube(
			handle,
			"ChamberFrame",
			at(side * 0.26, 0.15, 0.05),
			Vector3.new(0.1, 0.6, 0.35),
			palette.trim,
			palette.trimMaterial
		)
		local chamber = cube(handle, "Chamber", at(side * 0.32, 0.15, 0.05), Vector3.new(0.05, 0.45, 0.2), BANANA, NEON)
		glow(chamber, BANANA, 3)
	end
	-- Cañón fino, guardamanos con una ventila por lado y freno de boca con dos ranuras.
	cube(handle, "Barrel", at(0, 1.5, 0.1), Vector3.new(0.18, 1.7, 0.18), palette.barrel, METAL)
	cube(handle, "Handguard", at(0, 1.0, 0.1), Vector3.new(0.3, 0.7, 0.3), palette.trim, palette.trimMaterial)
	for side = -1, 1, 2 do
		cube(handle, "Vent", at(side * 0.16, 1.0, 0.1), Vector3.new(0.05, 0.4, 0.12), palette.barrel, METAL)
		cube(handle, "BrakeSlot", at(side * 0.17, 2.4, 0.1), Vector3.new(0.05, 0.2, 0.22), IRON, SMOOTH)
	end
	cube(handle, "Muzzle", at(0, 2.4, 0.1), Vector3.new(0.3, 0.35, 0.3), palette.trim, palette.trimMaterial)
	-- Bípode plegado bajo el cañón: la base y las dos patas pegadas.
	cube(handle, "BipodMount", at(0, 0.8, -0.1), Vector3.new(0.3, 0.15, 0.1), palette.barrel, METAL)
	for side = -1, 1, 2 do
		cube(handle, "BipodLeg", at(side * 0.1, 1.15, -0.15), Vector3.new(0.08, 0.7, 0.1), palette.barrel, METAL)
	end
	-- Mira grande: tubo con su campana, ocular y lente, sobre dos pilares.
	for _, along in { -0.2, 0.6 } do
		cube(handle, "ScopeMount", at(0, along, 0.39), Vector3.new(0.15, 0.1, 0.15), palette.barrel, METAL)
	end
	cube(handle, "Scope", at(0, 0.2, 0.62), Vector3.new(0.3, 1.2, 0.3), palette.trim, palette.trimMaterial)
	cube(handle, "ScopeBell", at(0, 0.9, 0.62), Vector3.new(0.42, 0.25, 0.42), palette.barrel, METAL)
	cube(handle, "ScopeEye", at(0, -0.45, 0.62), Vector3.new(0.36, 0.15, 0.36), palette.barrel, METAL)
	-- Cargador curvo de banana bajo el cajón, con su rabito.
	cube(handle, "MagCollar", at(0, 0.1, -0.27), Vector3.new(0.36, 0.45, 0.15), palette.trim, palette.trimMaterial)
	for index, step in { { 0.05, -0.4 }, { 0.15, -0.62 }, { 0.32, -0.82 } } do
		cube(handle, "Banana", at(0, step[1], step[2]), Vector3.new(0.28, 0.35, 0.25 + 0.01 * index), BANANA, SMOOTH)
	end
	cube(handle, "BananaStem", at(0, 0.5, -0.95), Vector3.new(0.1, 0.12, 0.12), DARK_WOOD, WOOD)
	cube(handle, "Cheek", at(0, -1.45, 0.3), Vector3.new(0.32, 0.5, 0.15), palette.trim, palette.trimMaterial)
	if faction == "Guardians" then
		local lens = cube(handle, "Lens", at(0, 1.03, 0.62), Vector3.new(0.3, 0.05, 0.3), LAB_GLOW, NEON)
		glow(lens, LAB_GLOW, 3)
		cube(handle, "Antenna", at(0.1, -0.3, 0.75), Vector3.new(0.05, 0.05, 0.4), LAB_DARK, SMOOTH)
		cube(handle, "AntennaTip", at(0.1, -0.3, 0.97), Vector3.new(0.1, 0.1, 0.1), LAB_BLUE, NEON)
	else
		-- Catalejo con anillos de oro y un pañuelo negro atado a la culata.
		cube(handle, "Lens", at(0, 1.03, 0.62), Vector3.new(0.3, 0.05, 0.3), GOLD, GLASS)
		for _, along in { -0.1, 0.5 } do
			cube(handle, "ScopeRing", at(0, along, 0.62), Vector3.new(0.38, 0.05, 0.38), GOLD, METAL)
		end
		cube(handle, "Bandana", at(0, -1.3, 0.05), Vector3.new(0.4, 0.2, 0.6), IRON, FABRIC)
		cube(handle, "BandanaTail", at(0.25, -1.4, -0.2), Vector3.new(0.05, 0.25, 0.35), IRON, FABRIC)
		cube(handle, "BarrelBand", at(0, 1.9, 0.1), Vector3.new(0.26, 0.08, 0.26), GOLD, METAL)
	end
	return handle
end

-- Lanzarredes: escopeta corta y gorda. Cañón cuadrado y ancho con la boca enmarcada, un peso en cada
-- esquina, la red plegada y la punta del arpón asomando; corredera de bombeo debajo y un fardo de red atado
-- encima del cajón (se ve desde la primera persona).
local function buildNetHarpoon(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.0, 0.6)
	-- Cañón ancho de 0,55 a 1,45 y collar de unión con el cajón.
	cube(handle, "Launcher", at(0, 1.0, 0.1), Vector3.new(0.75, 0.9, 0.7), palette.body, palette.bodyMaterial)
	cube(handle, "Collar", at(0, 0.58, 0.1), Vector3.new(0.85, 0.12, 0.8), palette.trim, palette.trimMaterial)
	-- Boca cuadrada: marco por los cuatro lados, hueco oscuro, red plegada y la punta del arpón.
	for side = -1, 1, 2 do
		cube(
			handle,
			"MouthFrame",
			at(side * 0.37, 1.47, 0.1),
			Vector3.new(0.1, 0.1, 0.8),
			palette.trim,
			palette.trimMaterial
		)
		cube(
			handle,
			"MouthFrame",
			at(0, 1.47, 0.1 + side * 0.37),
			Vector3.new(0.65, 0.1, 0.1),
			palette.trim,
			palette.trimMaterial
		)
	end
	cube(handle, "Mouth", at(0, 1.46, 0.1), Vector3.new(0.6, 0.05, 0.6), IRON, SMOOTH)
	cube(handle, "Net", at(0, 1.52, 0.1), Vector3.new(0.5, 0.1, 0.5), NET, FABRIC)
	cube(handle, "Shaft", at(0, 1.75, 0.1), Vector3.new(0.1, 0.45, 0.1), palette.barrel, METAL)
	cube(handle, "Tip", at(0, 2.0, 0.1), Vector3.new(0.25, 0.15, 0.25), palette.trim, METAL)
	cube(handle, "TipPoint", at(0, 2.13, 0.1), Vector3.new(0.1, 0.12, 0.1), palette.trim, METAL)
	-- Un peso en cada esquina.
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			cube(
				handle,
				"Weight",
				at(x * 0.42, 1.55, 0.1 + z * 0.42),
				Vector3.new(0.2, 0.2, 0.2),
				palette.barrel,
				METAL
			)
		end
	end
	-- Corredera de bombeo bajo el cañón: carril, puño con tres estrías y tope.
	cube(handle, "PumpRail", at(0, 1.0, -0.33), Vector3.new(0.2, 0.9, 0.1), palette.barrel, METAL)
	cube(handle, "Pump", at(0, 0.95, -0.55), Vector3.new(0.38, 0.55, 0.3), palette.grip, palette.gripMaterial)
	for _, along in { 0.8, 0.95, 1.1 } do
		cube(handle, "PumpRib", at(0, along, -0.72), Vector3.new(0.42, 0.05, 0.1), palette.barrel, METAL)
	end
	-- Fardo de red atado sobre el cajón, con dos correas y un nudo.
	cube(handle, "NetBale", at(0, 0.3, 0.55), Vector3.new(0.55, 0.8, 0.35), NET, FABRIC)
	for _, along in { 0.05, 0.55 } do
		cube(handle, "BaleStrap", at(0, along, 0.55), Vector3.new(0.6, 0.08, 0.4), DARK_WOOD, FABRIC)
	end
	cube(handle, "BaleKnot", at(0, 0.3, 0.78), Vector3.new(0.2, 0.2, 0.1), ROPE, FABRIC)
	cube(handle, "Cheek", at(0, -1.45, 0.3), Vector3.new(0.32, 0.5, 0.15), palette.trim, palette.trimMaterial)
	if faction == "Guardians" then
		cube(handle, "Rim", at(0, 0.75, 0.1), Vector3.new(0.8, 0.1, 0.75), LAB_BLUE, SMOOTH)
		for side = -1, 1, 2 do
			local light = cube(handle, "Ready", at(side * 0.39, 1.2, 0.1), Vector3.new(0.05, 0.2, 0.3), LAB_GLOW, NEON)
			glow(light, LAB_GLOW, 3)
		end
		cube(handle, "Sensor", at(0, 1.1, 0.5), Vector3.new(0.2, 0.15, 0.1), LAB_BLUE, SMOOTH)
	else
		-- Rollo de cuerda en un lado, aros de oro y una calavera de hueso en el tope de la corredera.
		cube(handle, "Coil", at(0.5, 0.9, 0.1), Vector3.new(0.2, 0.5, 0.5), ROPE, FABRIC)
		cube(handle, "CoilCore", at(0.6, 0.9, 0.1), Vector3.new(0.05, 0.2, 0.2), DARK_WOOD, WOOD)
		for _, along in { 0.8, 1.25 } do
			cube(handle, "Hoop", at(0, along, 0.1), Vector3.new(0.8, 0.1, 0.75), GOLD, METAL)
		end
		cube(handle, "PumpSkull", at(0, 1.3, -0.5), Vector3.new(0.2, 0.2, 0.2), BONE, SMOOTH)
	end
	return handle
end

-- Cañón de suero: lanzagranadas. Tubo grueso y corto con boca acampanada (BellInside, la boca que la skin
-- del Dragón sustituye), un depósito alto de suero morado con burbujas sobre el tubo, un manómetro redondo
-- en el lado derecho y un asa lateral a la izquierda.
local function buildAcidCannon(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 0.9, 0.6)
	-- Tubo de 0,4 a 1,7, collar de unión con el cajón, dos aros y la campana (1,7 a 2,0).
	cube(handle, "Tube", at(0, 1.05, 0.1), Vector3.new(0.7, 1.3, 0.7), palette.barrel, METAL)
	cube(handle, "Collar", at(0, 0.45, 0.1), Vector3.new(0.8, 0.12, 0.8), palette.trim, palette.trimMaterial)
	for _, along in { 0.7, 1.45 } do
		cube(handle, "TubeRing", at(0, along, 0.1), Vector3.new(0.78, 0.1, 0.78), palette.trim, palette.trimMaterial)
	end
	cube(handle, "Bell", at(0, 1.85, 0.1), Vector3.new(1.0, 0.3, 1.0), palette.trim, palette.trimMaterial)
	cube(handle, "BellInside", at(0, 2.02, 0.1), Vector3.new(0.7, 0.05, 0.7), IRON, SMOOTH)
	-- Depósito alto sobre el tubo (sin luz propia: con ella el morado se ve rosa), con sus tapas, dos
	-- sillas de apoyo y burbujas claras pegadas a los lados.
	for _, along in { 0.55, 1.15 } do
		cube(handle, "TankSaddle", at(0, along, 0.48), Vector3.new(0.45, 0.12, 0.1), palette.barrel, METAL)
	end
	cube(handle, "Serum", at(0, 0.85, 0.78), Vector3.new(0.5, 0.9, 0.5), SERUM, SMOOTH)
	for _, along in { 0.35, 1.35 } do
		cube(handle, "TankCap", at(0, along, 0.78), Vector3.new(0.6, 0.1, 0.6), palette.trim, palette.trimMaterial)
	end
	for side = -1, 1, 2 do
		cube(handle, "Bubble", at(side * 0.27, 0.7, 0.9), Vector3.new(0.06, 0.14, 0.14), BUBBLE, SMOOTH)
		cube(handle, "Bubble", at(side * 0.27, 1.0, 0.65), Vector3.new(0.06, 0.1, 0.1), BUBBLE, SMOOTH)
	end
	cube(handle, "Bubble", at(0.1, 0.95, 1.04), Vector3.new(0.12, 0.12, 0.06), BUBBLE, SMOOTH)
	-- Manómetro redondo a la derecha: caja, esfera clara y aguja.
	cube(handle, "GaugeBox", at(0.4, 0.95, 0.0), Vector3.new(0.1, 0.4, 0.4), palette.trim, palette.trimMaterial)
	cube(handle, "GaugeFace", at(0.47, 0.95, 0.0), Vector3.new(0.05, 0.28, 0.28), BONE, SMOOTH)
	cube(handle, "GaugeNeedle", at(0.51, 0.97, 0.04), Vector3.new(0.03, 0.05, 0.14), IRON, SMOOTH)
	-- Asa lateral a la izquierda: soporte y puño colgando.
	cube(handle, "SideArm", at(-0.5, 0.95, 0.1), Vector3.new(0.3, 0.12, 0.12), palette.barrel, METAL)
	cube(handle, "SideGrip", at(-0.65, 0.95, -0.1), Vector3.new(0.15, 0.15, 0.5), palette.grip, palette.gripMaterial)
	if faction == "Guardians" then
		-- Armazón azul del depósito, franja azul en el tubo y luz de presión junto al manómetro.
		for side = -1, 1, 2 do
			cube(handle, "TankFrame", at(side * 0.27, 0.85, 0.78), Vector3.new(0.05, 0.9, 0.1), LAB_BLUE, SMOOTH)
		end
		cube(handle, "Rim", at(0, 1.2, 0.1), Vector3.new(0.78, 0.15, 0.78), LAB_BLUE, SMOOTH)
		local light = cube(handle, "Ready", at(0.4, 1.3, 0.0), Vector3.new(0.1, 0.12, 0.12), LAB_GLOW, NEON)
		glow(light, LAB_GLOW, 3)
	else
		-- Correas de cuerda atando el depósito, corcho en la tapa, aro de oro y una calavera en el tubo.
		for _, along in { 0.6, 1.1 } do
			cube(handle, "Strap", at(0, along, 0.78), Vector3.new(0.56, 0.06, 0.56), ROPE, FABRIC)
		end
		cube(handle, "Cork", at(0, 1.45, 0.78), Vector3.new(0.2, 0.12, 0.2), PIRATE_WOOD, WOOD)
		cube(handle, "BellRim", at(0, 1.99, 0.1), Vector3.new(1.05, 0.05, 1.05), GOLD, METAL)
		cube(handle, "PumpSkull", at(-0.37, 1.1, 0.1), Vector3.new(0.05, 0.22, 0.22), BONE, SMOOTH)
	end
	return handle
end

local BUILDERS: { [string]: (tool: Tool, faction: Faction) -> BasePart } = {
	LabDartGun = buildDartGun,
	LabBananaRifle = buildBananaRifle,
	LabNetHarpoon = buildNetHarpoon,
	LabAcidCannon = buildAcidCannon,
}

-- true si "weaponId" es un arma del Laboratorio.
function LabWeaponModels.has(weaponId: string): boolean
	return BUILDERS[weaponId] ~= nil
end

-- La facción de un valor de atributo: "Pirates" o, si no, "Guardians".
function LabWeaponModels.faction(value: any): Faction
	return if value == "Pirates" then "Pirates" else "Guardians"
end

-- true si "skinId" es una skin de arma del Laboratorio (Shared/LabWeaponSkins).
function LabWeaponModels.hasSkin(skinId: string): boolean
	return LabWeaponSkins.has(skinId)
end

-- Lee un aspecto: "Pirates:LabWaspII", "Pirates", "Guardians", un id de skin suelto o nada. Devuelve el
-- bando y la skin (nil si no lleva).
function LabWeaponModels.look(value: any): (Faction, string?)
	if typeof(value) ~= "string" then
		return "Guardians", nil
	end
	local factionText, skinId = string.match(value, "^(%a+):(%w+)$")
	if factionText then
		return LabWeaponModels.faction(factionText), skinId
	end
	if LabWeaponSkins.has(value) then
		return "Guardians", value
	end
	return LabWeaponModels.faction(value), nil
end

-- El aspecto de "player" para el arma "weaponId" como texto: su bando ("LabFaction") y, si lleva una skin
-- de esa arma ("<arma>Skin"), "<bando>:<skin>".
function LabWeaponModels.lookOf(player: Player, weaponId: string): string
	local faction = LabWeaponModels.faction(player:GetAttribute("LabFaction"))
	local skinId = player:GetAttribute(`{weaponId}Skin`)
	if typeof(skinId) == "string" and LabWeaponSkins.fits(skinId, weaponId) then
		return `{faction}:{skinId}`
	end
	return faction
end

-- Pone en "tool" las piezas del arma "weaponId" con el aspecto de "faction" y, si "skinId" es una skin de
-- esa arma, las piezas de la skin encima.
function LabWeaponModels.build(tool: Tool, weaponId: string, faction: Faction, skinId: string?): BasePart
	local handle = BUILDERS[weaponId](tool, faction)
	if skinId and LabWeaponSkins.fits(skinId, weaponId) then
		LabWeaponSkins.apply(handle, skinId, faction)
	end
	VoxelMerge.mergeWelded(tool)
	return handle
end

return LabWeaponModels
