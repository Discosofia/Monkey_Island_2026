--!strict
-- Modelos de apuntado de las armas del Laboratorio en primera persona (Fase 19, W11). Al apuntar, la vista se
-- ve desde detrás de la mira y de cerca: el arma de perfil (Shared/LabWeaponModels) enseña la culata, la
-- correa y el cargador como un bloque enorme y tapa todo. Cada arma tiene aquí un segundo modelo, pensado para
-- verse desde el ojo: sin culata, con el cajón y el cañón estrechándose hacia delante y los rasgos de arma real
-- (carril con ranuras, visor, guardamanos ventilado, freno de boca), y con los mismos materiales, colores y
-- motivos del bando que el arma que ven los demás. El rifle no tiene: apunta por el visor y esconde el arma.
-- Mismos ejes que Shared/LabVoxel (+Y hacia la boca, "arriba" con at(lado, largo, arriba)); las piezas se
-- sueldan al mismo "Handle" y llevan el atributo "LabAim". FirstPersonController enseña estas piezas al apuntar
-- y las del arma de perfil al bajarla.
-- La mira del arma (Shared/UI/Sights) se dibuja encima, en el centro de la pantalla: el modelo deja libre la
-- línea de tiro, con todo por debajo de la altura de la mira (Config.Lab.AimView, en studs sobre la mano).

local LabVoxel = require(script.Parent.LabVoxel)
local LabWeaponSkins = require(script.Parent.LabWeaponSkins)
local LabWeaponModels = require(script.Parent.LabWeaponModels)

local at, cube = LabVoxel.at, LabVoxel.cube
local V = Vector3.new
local C = LabWeaponModels.COLORS

local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass

type Palette = LabWeaponModels.Palette
type Faction = LabWeaponModels.Faction
type Builder = (handle: BasePart, faction: Faction, palette: Palette) -> ()

-- Cuánto se baja todo el modelo respecto de la altura de la mira: así el cajón queda por debajo de la línea de
-- tiro y se ve su cara de arriba (el ojo mira un poco desde arriba); a ras de la mira solo se ve su cara trasera.
local DROP = 0.05

local LabAimModels = {}

-- Una pieza del modelo de apuntado: "side" y "along" y "up" en studs desde la mano, "size" en (lado, largo, alto).
local function piece(
	handle: BasePart,
	name: string,
	side: number,
	along: number,
	up: number,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = cube(handle, name, at(side, along, up - DROP), size, color, material)
	part:SetAttribute("LabAim", true)
	return part
end

-- Placa trasera del cajón, lo que ve el ojo: el borde del bando, con el emblema (calavera de hueso en los
-- Piratas; el hueco del tapón y una franja azul en los Guardianes) y dos remaches.
local function rearPlate(handle: BasePart, faction: Faction, p: Palette)
	piece(handle, "AimRearPlate", 0, -0.475, 0.05, V(0.35, 0.05, 0.3), p.trim, p.trimMaterial)
	for side = -1, 1, 2 do
		piece(handle, "AimRivet", side * 0.14, -0.5, 0.15, V(0.05, 0.05, 0.05), p.barrel, METAL)
	end
	if faction == "Guardians" then
		piece(handle, "AimRearPort", 0, -0.5, 0.05, V(0.12, 0.05, 0.12), p.barrel, METAL)
		piece(handle, "AimRearStripe", 0.12, -0.5, 0.05, V(0.06, 0.05, 0.3), C.LAB_BLUE, SMOOTH)
	else
		piece(handle, "AimSkull", 0, -0.5, 0.05, V(0.2, 0.05, 0.2), C.BONE, SMOOTH)
		for side = -1, 1, 2 do
			piece(handle, "AimSkullEye", side * 0.05, -0.53, 0.07, V(0.05, 0.03, 0.05), C.IRON, SMOOTH)
		end
	end
end

-- Lanzadardos: subfusil compacto. Cajón con carril ranurado, visor de punto rojo (el marco; el punto lo dibuja la
-- interfaz), tambor de cristal con dardos al costado, funda del cañón con ventilas y freno de boca.
local function dartGun(handle: BasePart, faction: Faction, p: Palette)
	-- Cajón escalonado: la parte de atrás baja y la de delante más alta, para que desde el ojo se lean los
	-- planos uno detrás de otro (cajón, funda, freno de boca) en vez de una sola pared.
	piece(handle, "AimBody", 0, -0.175, 0.025, V(0.45, 0.55, 0.45), p.body, p.bodyMaterial)
	piece(handle, "AimBody", 0, 0.5, 0.045, V(0.45, 0.8, 0.55), p.body, p.bodyMaterial)
	piece(handle, "AimRail", 0, 0.5, 0.33, V(0.24, 0.8, 0.04), p.trim, p.trimMaterial)
	for _, along in { 0.18, 0.34, 0.5, 0.66, 0.82 } do
		piece(handle, "AimSlot", 0, along, 0.355, V(0.26, 0.06, 0.04), p.barrel, METAL)
	end
	rearPlate(handle, faction, p)
	-- Visor: dos montantes finos y el techo, un marco alrededor de la mira (el punto lo dibuja la interfaz).
	for side = -1, 1, 2 do
		piece(handle, "AimDotPost", side * 0.12, 0.45, 0.485 + DROP, V(0.05, 0.12, 0.27), p.barrel, METAL)
	end
	piece(handle, "AimDotRoof", 0, 0.45, 0.64 + DROP, V(0.29, 0.12, 0.04), p.barrel, METAL)
	-- Tambor de cristal al costado izquierdo, con sus tapas, el soporte y tres dardos.
	piece(handle, "AimDrum", 0.36, 0.55, 0.15, V(0.25, 0.6, 0.3), C.DART, GLASS).Transparency = 0.5
	for _, along in { 0.2, 0.9 } do
		piece(handle, "AimDrumCap", 0.36, along, 0.15, V(0.3, 0.08, 0.35), p.trim, p.trimMaterial)
	end
	piece(handle, "AimDrumMount", 0.27, 0.55, 0.1, V(0.1, 0.5, 0.2), p.trim, p.trimMaterial)
	for index = -1, 1 do
		piece(handle, "AimDart", 0.36 + index * 0.08, 0.55, 0.15, V(0.06, 0.5, 0.06), C.DART, NEON)
	end
	-- Funda del cañón, más alta que el cajón, con ventilas arriba; el cañón, el freno de boca con sus ranuras y
	-- la base de la mira delantera, cada uno un escalón más alto.
	piece(handle, "AimShroud", 0, 1.3, 0.1, V(0.35, 0.8, 0.55), p.trim, p.trimMaterial)
	for _, along in { 1.05, 1.3, 1.55 } do
		piece(handle, "AimVent", 0, along, 0.375, V(0.2, 0.12, 0.03), p.barrel, METAL)
	end
	piece(handle, "AimBarrel", 0, 1.8, 0.2, V(0.18, 0.4, 0.2), p.barrel, METAL)
	piece(handle, "AimBrake", 0, 2.0, 0.27, V(0.3, 0.15, 0.3), p.trim, p.trimMaterial)
	for side = -1, 1, 2 do
		piece(handle, "AimBrakeSlot", side * 0.15, 2.0, 0.27, V(0.04, 0.1, 0.2), p.barrel, METAL)
	end
	piece(handle, "AimFrontBase", 0, 1.6, 0.4, V(0.1, 0.1, 0.06), p.barrel, METAL)
	if faction == "Guardians" then
		for side = -1, 1, 2 do
			piece(handle, "AimStripe", side * 0.17, 0.5, 0.36, V(0.04, 0.8, 0.04), C.LAB_BLUE, SMOOTH)
		end
		piece(handle, "AimSensor", 0, 1.6, 0.4, V(0.2, 0.15, 0.04), C.LAB_BLUE, SMOOTH)
		piece(handle, "AimIndicator", 0, -0.5, 0.2, V(0.2, 0.05, 0.05), C.LAB_GLOW, NEON)
	else
		for _, along in { 0.15, 0.85 } do
			piece(handle, "AimBand", 0, along, 0.05, V(0.5, 0.1, 0.6), C.GOLD, METAL)
		end
		for _, along in { 1.05, 1.2, 1.35 } do
			piece(handle, "AimRope", 0, along, 0.36, V(0.37, 0.07, 0.05), C.DARK_WOOD, FABRIC)
		end
	end
end

-- Lanzarredes: escopeta corta y gorda. Cajón escalonado y cañón ancho que se ensancha hacia delante, con la red
-- enrollada por encima y la boca enmarcada con un peso en cada esquina; un rollo de red atado al costado.
local function netHarpoon(handle: BasePart, faction: Faction, p: Palette)
	piece(handle, "AimBody", 0, -0.175, 0.025, V(0.45, 0.55, 0.45), p.body, p.bodyMaterial)
	piece(handle, "AimBody", 0, 0.35, 0.045, V(0.45, 0.7, 0.55), p.body, p.bodyMaterial)
	piece(handle, "AimBodyCap", 0, 0.35, 0.33, V(0.3, 0.7, 0.04), p.trim, p.trimMaterial)
	rearPlate(handle, faction, p)
	-- Cañón ancho y collar de unión.
	piece(handle, "AimLauncher", 0, 1.2, 0.1, V(0.75, 0.9, 0.6), p.body, p.bodyMaterial)
	piece(handle, "AimCollar", 0, 0.75, 0.1, V(0.85, 0.12, 0.68), p.trim, p.trimMaterial)
	-- La red enrollada encima: tiras cruzadas y dos tiras largas.
	for _, along in { 0.95, 1.2, 1.45 } do
		piece(handle, "AimNetCross", 0, along, 0.405, V(0.78, 0.07, 0.04), C.NET, FABRIC)
	end
	for side = -1, 1, 2 do
		piece(handle, "AimNetLong", side * 0.15, 1.2, 0.43, V(0.05, 0.8, 0.04), C.NET, FABRIC)
	end
	-- Boca enmarcada: el marco de arriba, los lados y un peso en cada esquina, que sobresalen como una mira.
	piece(handle, "AimMouthFrame", 0, 1.67, 0.37, V(0.8, 0.1, 0.1), p.trim, p.trimMaterial)
	for side = -1, 1, 2 do
		piece(handle, "AimMouthSide", side * 0.37, 1.67, 0.1, V(0.1, 0.1, 0.6), p.trim, p.trimMaterial)
		piece(handle, "AimWeight", side * 0.42, 1.75, 0.3, V(0.2, 0.2, 0.2), p.barrel, METAL)
	end
	-- Rollo de red atado al costado izquierdo, bajo, con sus correas y el nudo.
	piece(handle, "AimBale", 0.42, 0.45, 0.0, V(0.25, 0.6, 0.3), C.NET, FABRIC)
	for _, along in { 0.25, 0.65 } do
		piece(handle, "AimBaleStrap", 0.42, along, 0.0, V(0.29, 0.07, 0.34), C.DARK_WOOD, FABRIC)
	end
	piece(handle, "AimBaleKnot", 0.42, 0.45, 0.17, V(0.15, 0.15, 0.05), C.ROPE, FABRIC)
	if faction == "Guardians" then
		piece(handle, "AimRim", 0, 0.95, 0.1, V(0.8, 0.1, 0.65), C.LAB_BLUE, SMOOTH)
		for side = -1, 1, 2 do
			piece(handle, "AimReady", side * 0.39, 1.4, 0.2, V(0.05, 0.2, 0.2), C.LAB_GLOW, NEON)
		end
		piece(handle, "AimSensor", 0, 0.35, 0.37, V(0.2, 0.15, 0.04), C.LAB_BLUE, SMOOTH)
	else
		for _, along in { 1.0, 1.5 } do
			piece(handle, "AimHoop", 0, along, 0.1, V(0.8, 0.1, 0.65), C.GOLD, METAL)
		end
		piece(handle, "AimCoil", -0.45, 1.1, 0.0, V(0.2, 0.5, 0.3), C.ROPE, FABRIC)
	end
end

-- Cañón de suero: lanzagranadas. Cajón escalonado, tubo grueso con aros y la boca acampanada, el manómetro como
-- esfera en lo alto, el depósito de suero al costado izquierdo con sus burbujas y el asa a la derecha.
local function acidCannon(handle: BasePart, faction: Faction, p: Palette)
	piece(handle, "AimBody", 0, -0.175, 0.025, V(0.45, 0.55, 0.45), p.body, p.bodyMaterial)
	piece(handle, "AimBody", 0, 0.3, 0.045, V(0.45, 0.6, 0.55), p.body, p.bodyMaterial)
	piece(handle, "AimBodyCap", 0, 0.3, 0.33, V(0.3, 0.6, 0.04), p.trim, p.trimMaterial)
	rearPlate(handle, faction, p)
	piece(handle, "AimTube", 0, 1.25, 0.05, V(0.7, 1.3, 0.7), p.barrel, METAL)
	piece(handle, "AimCollar", 0, 0.65, 0.05, V(0.8, 0.12, 0.76), p.trim, p.trimMaterial)
	for _, along in { 0.9, 1.65 } do
		piece(handle, "AimTubeRing", 0, along, 0.05, V(0.78, 0.1, 0.74), p.trim, p.trimMaterial)
	end
	-- Campana de la boca, un escalón más alta que el tubo, con el aro de adorno.
	piece(handle, "AimBell", 0, 2.05, 0.0, V(0.9, 0.3, 0.8), p.trim, p.trimMaterial)
	piece(handle, "AimBellInside", 0, 2.22, 0.0, V(0.7, 0.05, 0.5), C.IRON, SMOOTH)
	-- Manómetro en lo alto del tubo: caja, esfera clara y aguja.
	piece(handle, "AimGaugeBox", -0.2, 0.9, 0.38, V(0.3, 0.3, 0.06), p.trim, p.trimMaterial)
	piece(handle, "AimGaugeFace", -0.2, 0.9, 0.415, V(0.22, 0.22, 0.03), C.BONE, SMOOTH)
	piece(handle, "AimGaugeNeedle", -0.17, 0.92, 0.435, V(0.04, 0.12, 0.02), C.IRON, SMOOTH)
	-- Depósito de suero al costado izquierdo, bajo: sillas, tapas, el suero morado y burbujas claras.
	for _, along in { 0.8, 1.3 } do
		piece(handle, "AimTankSaddle", 0.45, along, 0.0, V(0.25, 0.1, 0.12), p.barrel, METAL)
	end
	piece(handle, "AimSerum", 0.55, 1.05, 0.1, V(0.4, 0.9, 0.45), C.SERUM, SMOOTH)
	for _, along in { 0.55, 1.55 } do
		piece(handle, "AimTankCap", 0.55, along, 0.05, V(0.3, 0.1, 0.3), p.trim, p.trimMaterial)
	end
	piece(handle, "AimBubble", 0.5, 0.9, 0.25, V(0.12, 0.12, 0.05), C.BUBBLE, SMOOTH)
	piece(handle, "AimBubble", 0.62, 1.2, 0.25, V(0.08, 0.08, 0.05), C.BUBBLE, SMOOTH)
	-- Asa a la derecha: soporte y puño.
	piece(handle, "AimSideArm", -0.5, 1.15, 0.0, V(0.3, 0.12, 0.12), p.barrel, METAL)
	piece(handle, "AimSideGrip", -0.65, 1.15, -0.1, V(0.15, 0.5, 0.15), p.grip, p.gripMaterial)
	if faction == "Guardians" then
		piece(handle, "AimRim", 0, 1.4, 0.05, V(0.78, 0.15, 0.78), C.LAB_BLUE, SMOOTH)
		for side = -1, 1, 2 do
			piece(handle, "AimTankFrame", 0.55 + side * 0.2, 1.05, 0.05, V(0.05, 0.9, 0.1), C.LAB_BLUE, SMOOTH)
		end
		piece(handle, "AimReady", 0.1, 0.0, 0.36, V(0.12, 0.12, 0.04), C.LAB_GLOW, NEON)
	else
		for _, along in { 0.8, 1.3 } do
			piece(handle, "AimStrap", 0.55, along, 0.05, V(0.4, 0.06, 0.4), C.ROPE, FABRIC)
		end
		piece(handle, "AimBellRim", 0, 2.19, 0.0, V(0.95, 0.05, 0.85), C.GOLD, METAL)
	end
end

-- Skins por bajas (Shared/LabWeaponSkins) con modelo de apuntado: la Avispa del lanzadardos, el Kraken del
-- lanzarredes y el Dragón del cañón (el Escorpión es del rifle, que no tiene). El arma de perfil lleva su
-- bestia con bandas de colores alrededor del cuerpo y piezas propias; aquí se ven las bandas y lo que asoma
-- por delante y por los lados, con los mismos colores y cada grado (I, II, III) sumando una pieza más.
local WASP_BLACK = Color3.fromRGB(28, 26, 24)
local AMBER = Color3.fromRGB(255, 176, 30)
local WING = Color3.fromRGB(190, 165, 110)
local ABYSS = Color3.fromRGB(24, 62, 125)
local CORAL = Color3.fromRGB(235, 140, 110)
local SUCKER = Color3.fromRGB(240, 228, 196)
local CYAN = Color3.fromRGB(80, 220, 235)
local OBSIDIAN = Color3.fromRGB(26, 24, 34)
local EMBER = Color3.fromRGB(255, 130, 30)
local HORN = Color3.fromRGB(225, 215, 190)
local MEMBRANE = Color3.fromRGB(150, 78, 40)

-- Dónde van las bandas de cada arma: { largo, ancho, alto, arriba } alrededor del cajón y del cañón.
local RINGS: { [string]: { { number } } } = {
	LabDartGun = {
		{ 0.0, 0.5, 0.6, 0.05 },
		{ 0.25, 0.5, 0.6, 0.05 },
		{ 0.5, 0.5, 0.6, 0.05 },
		{ 0.75, 0.5, 0.6, 0.05 },
		{ 1.1, 0.4, 0.6, 0.1 },
		{ 1.4, 0.4, 0.6, 0.1 },
	},
	LabNetHarpoon = {
		{ 0.1, 0.5, 0.6, 0.05 },
		{ 0.45, 0.5, 0.6, 0.05 },
		{ 1.0, 0.8, 0.65, 0.1 },
		{ 1.3, 0.8, 0.65, 0.1 },
		{ 1.6, 0.8, 0.65, 0.1 },
	},
	LabAcidCannon = {
		{ 0.2, 0.5, 0.6, 0.05 },
		{ 0.95, 0.78, 0.74, 0.05 },
		{ 1.35, 0.78, 0.74, 0.05 },
		{ 1.75, 0.78, 0.74, 0.05 },
	},
}

-- Un adorno de la skin: un bloque de "color" en (lado, largo, arriba).
local function trinket(
	handle: BasePart,
	side: number,
	along: number,
	up: number,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	return piece(handle, "AimSkin", side, along, up, size, color, material)
end

local function skinLook(handle: BasePart, weaponId: string, skinId: string)
	local family = string.gsub(skinId, "I+$", "")
	local grade = #(string.match(skinId, "I+$") or "I")
	local first, second
	if family == "LabWasp" then
		first, second = AMBER, WASP_BLACK
	elseif family == "LabKraken" then
		first, second = ABYSS, CORAL
	else
		first, second = OBSIDIAN, EMBER
	end
	for index, ring in RINGS[weaponId] or {} do
		trinket(handle, 0, ring[1], ring[4], V(ring[2], 0.1, ring[3]), if index % 2 == 1 then first else second, SMOOTH)
	end
	if family == "LabWasp" then
		-- Ojos compuestos a los lados de la funda, aguijón (II) y alas de cristal ahumado (III).
		for side = -1, 1, 2 do
			trinket(handle, side * 0.25, 1.75, 0.2, V(0.15, 0.2, 0.2), WASP_BLACK, SMOOTH)
		end
		if grade >= 2 then
			trinket(handle, 0, 2.3, 0.27, V(0.12, 0.35, 0.12), AMBER, SMOOTH)
		end
		if grade >= 3 then
			for side = -1, 1, 2 do
				trinket(handle, side * 0.42, 0.55, 0.2, V(0.35, 0.9, 0.04), WING, GLASS).Transparency = 0.4
			end
		end
	elseif family == "LabKraken" then
		-- Ventosas cremas en dos filas por encima, ojos cian que brillan (I), pico (II) y tentáculos (III).
		for _, along in { 0.95, 1.2, 1.45, 1.7 } do
			for side = -1, 1, 2 do
				trinket(handle, side * 0.22, along, 0.38, V(0.1, 0.1, 0.06), SUCKER, SMOOTH)
			end
		end
		for side = -1, 1, 2 do
			trinket(handle, side * 0.3, 1.85, 0.3, V(0.1, 0.1, 0.1), CYAN, NEON)
		end
		if grade >= 2 then
			trinket(handle, 0, 2.0, 0.1, V(0.25, 0.3, 0.2), CORAL, SMOOTH)
		end
		if grade >= 3 then
			for side = -1, 1, 2 do
				trinket(handle, side * 0.55, 1.0, 0.0, V(0.12, 1.2, 0.12), CORAL, SMOOTH)
			end
		end
	else
		-- Grietas de brasa por encima, cuernos de hueso a los lados (más grandes en II) y alas de membrana (III).
		for _, along in { 0.9, 1.5 } do
			trinket(handle, 0, along, 0.38, V(0.06, 0.5, 0.03), EMBER, NEON)
		end
		local horn = if grade >= 2 then 0.3 else 0.2
		for side = -1, 1, 2 do
			trinket(handle, side * 0.32, 0.3, 0.2 + horn / 2, V(0.1, 0.2, horn), HORN, SMOOTH)
		end
		if grade >= 3 then
			for side = -1, 1, 2 do
				trinket(handle, side * 0.6, 0.8, 0.15, V(0.5, 0.8, 0.04), MEMBRANE, SMOOTH)
			end
		end
	end
end

local BUILDERS: { [string]: Builder } = {
	LabDartGun = dartGun,
	LabNetHarpoon = netHarpoon,
	LabAcidCannon = acidCannon,
}

-- true si "weaponId" tiene modelo de apuntado (el rifle no: apunta por el visor).
function LabAimModels.has(weaponId: string): boolean
	return BUILDERS[weaponId] ~= nil
end

-- Añade al "Handle" de "weaponId" las piezas del modelo de apuntado del bando "faction" y, si lleva una skin de
-- bajas de esa arma, los colores y adornos de la skin.
function LabAimModels.add(handle: BasePart, weaponId: string, faction: Faction, skinId: string?)
	local builder = BUILDERS[weaponId]
	if not builder then
		return
	end
	builder(handle, faction, LabWeaponModels.palette(faction))
	if skinId and LabWeaponSkins.fits(skinId, weaponId) then
		skinLook(handle, weaponId, skinId)
	end
end

return LabAimModels
