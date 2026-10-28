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

-- Cañón de "length" desde "from" (a lo largo), con su boca.
local function barrel(handle: BasePart, palette: Palette, from: number, length: number, width: number)
	cube(handle, "Barrel", at(0, from + length / 2, 0.1), Vector3.new(width, length, width), palette.barrel, METAL)
	cube(
		handle,
		"Muzzle",
		at(0, from + length - 0.05, 0.1),
		Vector3.new(width + 0.1, 0.15, width + 0.1),
		palette.trim,
		palette.trimMaterial
	)
end

-- Lanzadardos: cajón corto, cañón fino, bidón de dardos debajo y tres dardos de repuesto encima.
local function buildDartGun(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.3, 0.6)
	barrel(handle, palette, 0.85, 0.9, 0.2)
	cube(handle, "Canister", at(0, 0.2, -0.45), Vector3.new(0.35, 0.6, 0.3), DART, GLASS).Transparency = 0.2
	for _, along in { -0.15, 0.55 } do
		cube(
			handle,
			"CanisterCap",
			at(0, along, -0.45),
			Vector3.new(0.4, 0.1, 0.35),
			palette.trim,
			palette.trimMaterial
		)
	end
	for side = -1, 1 do
		cube(handle, "Dart", at(side * 0.12, 0.3, 0.42), Vector3.new(0.05, 0.5, 0.05), DART, NEON)
	end
	if faction == "Guardians" then
		cube(handle, "Sensor", at(0, 0.7, 0.42), Vector3.new(0.15, 0.15, 0.15), LAB_BLUE, SMOOTH)
	else
		-- Plumas negras y doradas en la cola de los dardos.
		for side = -1, 1 do
			cube(
				handle,
				"Fletch",
				at(side * 0.12, 0.02, 0.42),
				Vector3.new(0.1, 0.1, 0.1),
				if side == 0 then GOLD else IRON,
				FABRIC
			)
		end
	end
	return handle
end

-- Rifle: culata y cañón largos, mira encima y la recámara de la banana que brilla en amarillo.
local function buildBananaRifle(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.1, 0.5)
	barrel(handle, palette, 0.65, 2.0, 0.2)
	for side = -1, 1, 2 do
		local chamber = cube(handle, "Chamber", at(side * 0.23, 0.15, 0.05), Vector3.new(0.05, 0.5, 0.2), BANANA, NEON)
		glow(chamber, BANANA, 3)
	end
	-- Mira: tubo encima del cajón con su lente.
	cube(handle, "Scope", at(0, 0.15, 0.45), Vector3.new(0.25, 0.9, 0.25), palette.trim, palette.trimMaterial)
	for _, along in { -0.1, 0.4 } do
		cube(handle, "ScopeMount", at(0, along, 0.3), Vector3.new(0.1, 0.1, 0.15), palette.barrel, METAL)
	end
	if faction == "Guardians" then
		local lens = cube(handle, "Lens", at(0, 0.62, 0.45), Vector3.new(0.2, 0.05, 0.2), LAB_GLOW, NEON)
		glow(lens, LAB_GLOW, 3)
		cube(handle, "Antenna", at(0.1, -0.3, 0.75), Vector3.new(0.05, 0.05, 0.4), LAB_DARK, SMOOTH)
		cube(handle, "AntennaTip", at(0.1, -0.3, 0.97), Vector3.new(0.1, 0.1, 0.1), LAB_BLUE, NEON)
	else
		-- Catalejo de latón con anillos de oro y un pañuelo negro atado a la culata.
		cube(handle, "Lens", at(0, 0.62, 0.45), Vector3.new(0.2, 0.05, 0.2), GOLD, GLASS)
		for _, along in { -0.2, 0.15, 0.5 } do
			cube(handle, "ScopeRing", at(0, along, 0.45), Vector3.new(0.3, 0.05, 0.3), GOLD, METAL)
		end
		cube(handle, "Bandana", at(0, -1.3, 0.05), Vector3.new(0.4, 0.2, 0.6), IRON, FABRIC)
		cube(handle, "BandanaTail", at(0.25, -1.4, -0.2), Vector3.new(0.05, 0.25, 0.35), IRON, FABRIC)
		for _, along in { 1.2, 2.0 } do
			cube(handle, "BarrelBand", at(0, along, 0.1), Vector3.new(0.3, 0.1, 0.3), GOLD, METAL)
		end
	end
	return handle
end

-- Lanzarredes: boca ancha y cuadrada con la red plegada y la punta del arpón asomando; un peso en cada
-- esquina.
local function buildNetHarpoon(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.0, 0.6)
	cube(handle, "Launcher", at(0, 1.0, 0.1), Vector3.new(0.8, 1.0, 0.8), palette.body, palette.bodyMaterial)
	cube(handle, "Mouth", at(0, 1.48, 0.1), Vector3.new(0.6, 0.05, 0.6), IRON, SMOOTH)
	cube(handle, "Net", at(0, 1.45, 0.1), Vector3.new(0.5, 0.1, 0.5), NET, FABRIC)
	cube(handle, "Shaft", at(0, 1.7, 0.1), Vector3.new(0.1, 0.5, 0.1), palette.barrel, METAL)
	cube(handle, "Tip", at(0, 2.0, 0.1), Vector3.new(0.25, 0.2, 0.25), palette.trim, METAL)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			cube(
				handle,
				"Weight",
				at(x * 0.42, 1.45, 0.1 + z * 0.42),
				Vector3.new(0.2, 0.2, 0.2),
				palette.barrel,
				METAL
			)
		end
	end
	if faction == "Guardians" then
		cube(handle, "Rim", at(0, 1.3, 0.1), Vector3.new(0.85, 0.1, 0.85), LAB_BLUE, SMOOTH)
		local light = cube(handle, "Ready", at(0.43, 0.7, 0.1), Vector3.new(0.05, 0.2, 0.2), LAB_GLOW, NEON)
		glow(light, LAB_GLOW, 3)
	else
		-- Rollo de cuerda en un lado y aros de oro.
		cube(handle, "Coil", at(0.5, 0.9, 0.1), Vector3.new(0.2, 0.5, 0.5), ROPE, FABRIC)
		cube(handle, "CoilCore", at(0.6, 0.9, 0.1), Vector3.new(0.05, 0.2, 0.2), DARK_WOOD, WOOD)
		for _, along in { 0.6, 1.3 } do
			cube(handle, "Hoop", at(0, along, 0.1), Vector3.new(0.85, 0.1, 0.85), GOLD, METAL)
		end
	end
	return handle
end

-- Cañón de suero: tubo grueso con boca acampanada y un depósito de suero morado encima.
local function buildAcidCannon(tool: Tool, faction: Faction): BasePart
	local palette = PALETTES[faction]
	local handle = frame(tool, palette, faction, 1.0, 0.65)
	cube(handle, "Tube", at(0, 1.05, 0.1), Vector3.new(0.55, 1.1, 0.55), palette.barrel, METAL)
	cube(handle, "Bell", at(0, 1.7, 0.1), Vector3.new(0.8, 0.25, 0.8), palette.trim, palette.trimMaterial)
	cube(handle, "BellInside", at(0, 1.83, 0.1), Vector3.new(0.5, 0.05, 0.5), IRON, SMOOTH)
	-- Sin luz propia: con ella el morado se ve rosa.
	cube(handle, "Serum", at(0, 0.05, 0.6), Vector3.new(0.35, 0.8, 0.35), SERUM, SMOOTH)
	if faction == "Guardians" then
		-- Depósito con armazón blanco y aros azules.
		for _, along in { -0.35, 0.45 } do
			cube(handle, "TankCap", at(0, along, 0.6), Vector3.new(0.45, 0.1, 0.45), LAB_WHITE, SMOOTH)
		end
		for side = -1, 1, 2 do
			cube(handle, "TankFrame", at(side * 0.2, 0.05, 0.6), Vector3.new(0.05, 0.8, 0.1), LAB_BLUE, SMOOTH)
		end
		cube(handle, "Hose", at(0, 0.6, 0.45), Vector3.new(0.1, 0.4, 0.1), LAB_DARK, SMOOTH)
	else
		-- Botella de cristal con tapón de corcho atada con cuerda.
		cube(handle, "Cork", at(0, 0.5, 0.6), Vector3.new(0.2, 0.15, 0.2), PIRATE_WOOD, WOOD)
		for _, along in { -0.15, 0.25 } do
			cube(handle, "Strap", at(0, along, 0.6), Vector3.new(0.4, 0.05, 0.4), ROPE, FABRIC)
		end
		cube(handle, "BellRim", at(0, 1.62, 0.1), Vector3.new(0.9, 0.05, 0.9), GOLD, METAL)
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
	return handle
end

return LabWeaponModels
