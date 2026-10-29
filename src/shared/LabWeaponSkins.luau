--!strict
-- Skins de las armas del Laboratorio en ruinas por bajas (L5b, Data/Cosmetics "LabKills"): una bestia por
-- arma, con los grados I, II y III que se ganan con Config.Lab.SkinKills bajas:
--   - Lanzadardos: Avispa (ámbar, negro y alas de cristal ahumado).
--   - Rifle: Escorpión (ocre del desierto, quitina negra y ámbar).
--   - Lanzarredes: Kraken (azul abisal, coral y ventosas crema; cian que brilla).
--   - Cañón: Dragón (obsidiana, naranja brasa y cuerno hueso).
-- Cada skin añade piezas voxel sobre el arma del bando (Shared/LabWeaponModels), con sus propios colores
-- iguales en los dos bandos, más un acento del bando: luz azul en los Guardianes, remache de oro en los
-- Piratas. Cada grado cambia la silueta y suma piezas que se ven por detrás. Algunos grados quitan piezas
-- base por nombre para sustituirlas (la boca del cañón del Dragón). Lo que se dispara conserva su color.
-- Las piezas grandes de la espalda del grado III llevan el atributo "LabBack": la primera persona
-- (laboratorio/FirstPersonController) las esconde y apaga las partículas, que solo valen para los demás.
-- Sin verde (curación), morado (veneno) ni rojo (daño recibido). Mismos ejes que Shared/LabVoxel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local LabVoxel = require(ReplicatedStorage.Shared.LabVoxel)

local at, cube = LabVoxel.at, LabVoxel.cube
local V = Vector3.new

local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local SAND = Enum.Material.Sandstone
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local SLATE = Enum.Material.Slate

-- Acento del bando: luz azul (Guardianes) o remache de oro (Piratas).
local LAB_GLOW = Color3.fromRGB(120, 200, 255)
local GOLD = Color3.fromRGB(234, 194, 80)
-- Avispa.
local AMBER = Color3.fromRGB(255, 176, 30)
local HONEY = Color3.fromRGB(255, 200, 60)
local WASP_BLACK = Color3.fromRGB(28, 26, 24)
local WING = Color3.fromRGB(190, 165, 110)
-- Escorpión.
local OCHRE = Color3.fromRGB(196, 146, 72)
local CHITIN = Color3.fromRGB(30, 26, 28)
local STING = Color3.fromRGB(255, 180, 40)
-- Kraken.
local ABYSS = Color3.fromRGB(24, 62, 125)
local CORAL = Color3.fromRGB(235, 140, 110)
local SUCKER = Color3.fromRGB(240, 228, 196)
local CYAN = Color3.fromRGB(80, 220, 235)
-- Dragón.
local OBSIDIAN = Color3.fromRGB(26, 24, 34)
local EMBER = Color3.fromRGB(255, 130, 30)
local HORN = Color3.fromRGB(225, 215, 190)
local MEMBRANE = Color3.fromRGB(150, 78, 40)
local SMOKE = Color3.fromRGB(110, 108, 116)

local LabWeaponSkins = {}

-- Marca una pieza grande de la espalda (la primera persona la esconde).
local function mark(part: BasePart): BasePart
	part:SetAttribute("LabBack", true)
	return part
end

local function glass(part: BasePart, transparency: number): BasePart
	part.Transparency = transparency
	return part
end

-- Quita de la herramienta las piezas base llamadas "name" (la skin las sustituye).
local function drop(handle: BasePart, name: string)
	local tool = handle.Parent
	local piece = if tool then tool:FindFirstChild(name) else nil
	if piece then
		piece:Destroy()
	end
end

-- Acento del bando en "where": luz azul que brilla o remache de oro.
local function accent(handle: BasePart, faction: string, where: CFrame): BasePart
	if faction == "Pirates" then
		return cube(handle, "SkinRivet", where, V(0.1, 0.1, 0.1), GOLD, METAL)
	end
	return cube(handle, "SkinLight", where, V(0.1, 0.1, 0.1), LAB_GLOW, NEON)
end

-- Partículas pequeñas (la skin del grado III): suben o caen sin cruzar la mira. "gravity": aceleración.
local function emitter(part: BasePart, color: Color3, rate: number, size: number, speed: number, gravity: Vector3)
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "SkinParticles"
	particles.Color = ColorSequence.new(color)
	particles.Rate = rate
	particles.Lifetime = NumberRange.new(0.6, 1.1)
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.Acceleration = gravity
	particles.SpreadAngle = Vector2.new(60, 60)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	particles.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	particles.LightEmission = 0.6
	particles.Parent = part
end

-- ---------------------------------------------------------------------------------------------------
-- Avispa (Lanzadardos): cajón de -0,45 a 0,85 (alto de -0,25 a 0,35); tambor encima (de -0,2 a 0,6, hasta
-- 0,8 de alto); funda del cañón de 0,85 a 1,65 (ancho 0,35); freno de boca hasta 2,03; cargador de cristal
-- debajo (de 0 a 0,65, hasta -1,15); empuñadura delantera en 1,1; culata hasta -1,8.
-- ---------------------------------------------------------------------------------------------------

-- Franjas de avispa: funda, cajón, cargador y culata. Los ojos van a los lados de la funda, ante la boca.
local function waspStripes(handle: BasePart)
	for index, along in { 0.9, 1.22, 1.58 } do
		cube(
			handle,
			"SkinStripe",
			at(0, along, 0.1),
			V(0.4, 0.1, 0.4),
			if index % 2 == 1 then AMBER else WASP_BLACK,
			SMOOTH
		)
	end
	-- Abdomen rayado: bandas ámbar y negras alrededor del cajón.
	for index, along in { -0.2, 0.05, 0.3, 0.55 } do
		cube(
			handle,
			"SkinBody",
			at(0, along, 0.05),
			V(0.6, 0.1, 0.66),
			if index % 2 == 1 then AMBER else WASP_BLACK,
			SMOOTH
		)
	end
	for _, along in { 0.05, 0.45 } do
		cube(handle, "SkinBand", at(0, along, -0.55), V(0.44, 0.08, 0.42), AMBER, SMOOTH)
	end
	for index, along in { -1.3, -1.6 } do
		cube(
			handle,
			"SkinBody",
			at(0, along, -0.05),
			V(0.44, 0.1, 0.65),
			if index == 1 then AMBER else WASP_BLACK,
			SMOOTH
		)
	end
	for side = -1, 1, 2 do
		cube(handle, "SkinEye", at(side * 0.2, 1.62, 0.1), V(0.1, 0.14, 0.2), WASP_BLACK, SMOOTH)
	end
	for _, along in { -0.2, 0.6 } do
		cube(handle, "SkinCap", at(0, along, 0.83), V(0.58, 0.06, 0.1), AMBER, SMOOTH)
	end
	cube(handle, "SkinBase", at(0, 0.4, -1.27), V(0.42, 0.62, 0.06), AMBER, SMOOTH)
end

-- Alas plegadas a los lados del cajón.
local function waspFoldedWings(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		glass(cube(handle, "SkinWing", at(side * 0.3, 0.15, 0.15), V(0.05, 0.9, 0.35), WING, GLASS), 0.25)
		cube(handle, "SkinWingVein", at(side * 0.3, 0.15, 0.15), V(0.07, 0.94, 0.05), WASP_BLACK, SMOOTH)
		accent(handle, faction, at(side * 0.3, -0.3, 0.05))
	end
end

-- Aguijón de neón que se afina ante la boca, dos mandíbulas y dos antenas hacia delante sobre el tambor.
local function waspStinger(handle: BasePart)
	cube(handle, "SkinStinger", at(0, 2.15, 0.1), V(0.22, 0.2, 0.22), HONEY, NEON)
	cube(handle, "SkinStinger", at(0, 2.33, 0.1), V(0.14, 0.2, 0.14), HONEY, NEON)
	cube(handle, "SkinStingerTip", at(0, 2.48, 0.1), V(0.07, 0.1, 0.07), WASP_BLACK, SMOOTH)
	for side = -1, 1, 2 do
		cube(handle, "SkinMandible", at(side * 0.22, 2.0, 0.1), V(0.08, 0.35, 0.08), WASP_BLACK, SMOOTH)
		cube(handle, "SkinAntenna", at(side * 0.15, 0.85, 0.72), V(0.05, 0.4, 0.05), WASP_BLACK, SMOOTH)
		cube(handle, "SkinAntennaTip", at(side * 0.15, 1.08, 0.72), V(0.1, 0.1, 0.1), HONEY, NEON)
	end
end

-- Alas abiertas: escalones de cristal que suben y se echan hacia atrás.
local function waspOpenWings(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		for step = 1, 4 do
			local length = 0.9 - (step - 1) * 0.1
			local along = 0.3 - (step - 1) * 0.08
			glass(
				cube(
					handle,
					"SkinWing",
					at(side * (0.38 + (step - 1) * 0.14), along, 0.3 + (step - 1) * 0.12),
					V(0.15, length, 0.1),
					WING,
					GLASS
				),
				0.25
			)
			cube(
				handle,
				"SkinWingVein",
				at(side * (0.38 + (step - 1) * 0.14), along + length / 2, 0.3 + (step - 1) * 0.12),
				V(0.17, 0.05, 0.12),
				WASP_BLACK,
				SMOOTH
			)
		end
		accent(handle, faction, at(side * 0.3, 0.55, 0.3))
	end
end

-- Alas grandes de cristal sobre la culata (se ven por detrás) con chispas de zumbido.
local function waspBigWings(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		for step = 1, 5 do
			local length = if step <= 2 then 1.2 elseif step == 3 then 1.1 elseif step == 4 then 0.9 else 0.7
			local wing = mark(
				glass(
					cube(
						handle,
						"SkinWing",
						at(side * (0.3 + step * 0.17), -0.9 - step * 0.08, 0.4 + step * 0.13),
						V(0.17, length, 0.3),
						WING,
						GLASS
					),
					0.25
				)
			)
			if step == 5 then
				emitter(wing, HONEY, 4, 0.12, 1.5, V(0, 2, 0))
			end
		end
		mark(cube(handle, "SkinWingVein", at(side * 0.5, -1.0, 0.45), V(0.07, 1.2, 0.07), WASP_BLACK, SMOOTH))
		mark(cube(handle, "SkinWingVein", at(side * 0.9, -1.2, 0.95), V(0.07, 0.8, 0.07), WASP_BLACK, SMOOTH))
		mark(accent(handle, faction, at(side * 0.3, -0.7, 0.4)))
	end
end

-- Panal que brilla a los lados del cargador, y miel que gotea de su base.
local COMB = { { 0.1, -0.45 }, { 0.3, -0.55 }, { 0.2, -0.7 }, { 0.4, -0.85 }, { 0.3, -1.0 } }
local function waspComb(handle: BasePart)
	for side = -1, 1, 2 do
		for _, cell in COMB do
			cube(handle, "SkinComb", at(side * 0.2, cell[1], cell[2]), V(0.06, 0.14, 0.14), HONEY, NEON)
		end
	end
end

-- Cuerpo de avispa entero (solo el grado III): jaula de panal sobre el tambor, abdomen que termina en
-- punta tras la culata y dos patas articuladas a cada lado de la empuñadura delantera.
local function waspBody(handle: BasePart)
	for side = -1, 1, 2 do
		for _, along in { -0.2, 0.6 } do
			cube(handle, "SkinCage", at(side * 0.27, along, 0.57), V(0.08, 0.08, 0.5), AMBER, SMOOTH)
		end
		for _, along in { 0.95, 1.25 } do
			cube(handle, "SkinLeg", at(side * 0.22, along, -0.3), V(0.2, 0.06, 0.06), WASP_BLACK, SMOOTH)
			cube(handle, "SkinLeg", at(side * 0.3, along, -0.45), V(0.06, 0.06, 0.3), WASP_BLACK, SMOOTH)
			cube(handle, "SkinFoot", at(side * 0.3, along, -0.64), V(0.1, 0.1, 0.06), AMBER, SMOOTH)
		end
	end
	for index, along in { -0.0, 0.2, 0.4 } do
		cube(handle, "SkinHex", at(if index == 2 then 0.12 else -0.12, along, 0.82), V(0.15, 0.15, 0.1), HONEY, NEON)
	end
	cube(handle, "SkinTail", at(0, -1.95, -0.05), V(0.25, 0.2, 0.3), AMBER, SMOOTH)
	cube(handle, "SkinTailTip", at(0, -2.12, -0.05), V(0.12, 0.15, 0.15), WASP_BLACK, SMOOTH)
	-- Pelusa del tórax sobre el cajón, placas del abdomen en la culata, pinchos sobre la funda, remates de
	-- las patas y gotas de miel colgando del cargador.
	for side = -1, 1, 2 do
		for index, along in { -0.4, 0.75 } do
			cube(
				handle,
				"SkinFur",
				at(side * 0.15, along, 0.4),
				V(0.12, 0.12, 0.1),
				if index % 2 == 1 then HONEY else AMBER,
				SMOOTH
			)
		end
		for _, along in { -1.3, -1.45, -1.6 } do
			cube(handle, "SkinPlate", at(side * 0.23, along, -0.05), V(0.05, 0.12, 0.45), WASP_BLACK, SMOOTH)
		end
		for _, along in { 0.95, 1.25 } do
			cube(handle, "SkinKnee", at(side * 0.3, along, -0.3), V(0.1, 0.1, 0.1), AMBER, SMOOTH)
		end
		cube(handle, "SkinDrip", at(side * 0.1, 0.4, -1.3), V(0.06, 0.06, 0.15), HONEY, NEON)
	end
	for _, along in { 1.0, 1.25, 1.5 } do
		cube(handle, "SkinSpike", at(0, along, 0.33), V(0.08, 0.15, 0.1), WASP_BLACK, SMOOTH)
	end
	cube(handle, "SkinDrip", at(0, 0.4, -1.4), V(0.06, 0.06, 0.15), HONEY, NEON)
end

-- ---------------------------------------------------------------------------------------------------
-- Escorpión (Rifle): cajón de -0,45 a 0,65; guardamanos de 0,65 a 1,35 (ancho 0,3, hasta 0,25 de alto);
-- cañón fino hasta 2,35 (ancho 0,18, centrado en 0,1); freno de boca de 2,22 a 2,58; mira encima de -0,45 a
-- 1,03 (tubo hasta 0,77 de alto); cargador de banana bajo el cajón (de 0 a 0,5); culata hasta -1,8.
-- ---------------------------------------------------------------------------------------------------

-- Caparazón: segmentos sobre el guardamanos, anillos en el cañón y una cresta negra por el centro.
local function scorpionPlates(handle: BasePart)
	for index, along in { 0.75, 0.95, 1.15, 1.35 } do
		local width = 0.38 - (index - 1) * 0.02
		cube(handle, "SkinShell", at(0, along, 0.3), V(width, 0.16, 0.16), OCHRE, SAND)
	end
	for _, along in { 1.6, 1.85, 2.1 } do
		cube(handle, "SkinPlate", at(0, along, 0.1), V(0.28, 0.16, 0.28), OCHRE, SAND)
	end
	cube(handle, "SkinPlateRidge", at(0, 1.05, 0.42), V(0.08, 1.0, 0.08), CHITIN, SMOOTH)
end

-- Placas del caparazón sobre el tubo de la mira.
local function scorpionScopeShell(handle: BasePart)
	for _, along in { 0.0, 0.3, 0.6 } do
		cube(handle, "SkinScopeShell", at(0, along, 0.84), V(0.36, 0.22, 0.1), OCHRE, SAND)
	end
end

-- Sacos de veneno que brillan a los lados de la mira (se ven desde la primera persona).
local function scorpionSacs(handle: BasePart)
	for side = -1, 1, 2 do
		cube(handle, "SkinSac", at(side * 0.22, 0.2, 0.62), V(0.1, 0.5, 0.15), STING, NEON)
	end
end

-- Púas negras a lo largo del lomo de la mira (grado III).
local function scorpionSpines(handle: BasePart)
	for _, along in { 0.0, 0.3, 0.6 } do
		cube(handle, "SkinSpine", at(0, along, 0.98), V(0.08, 0.14, 0.14), CHITIN, SMOOTH)
	end
end

-- Placas del caparazón a los lados del guardamanos y bandas negras en la culata.
local function scorpionFlanks(handle: BasePart)
	for side = -1, 1, 2 do
		for _, along in { 0.8, 1.0, 1.2 } do
			cube(handle, "SkinSidePlate", at(side * 0.2, along, 0.1), V(0.1, 0.15, 0.3), OCHRE, SAND)
		end
		for _, along in { -1.25, -1.45, -1.65 } do
			cube(handle, "SkinStockBand", at(side * 0.2, along, 0.05), V(0.1, 0.12, 0.45), CHITIN, SMOOTH)
		end
	end
end

-- Cola de bloques que sube por detrás de la culata y acaba en un aguijón. "path": puntos (largo, alto) que se
-- rellenan cada 0,2 con bloques que se tocan y adelgazan hacia la punta; cada tercero lleva una placa ocre.
local function scorpionTail(handle: BasePart, path: { { number } }, thick: number, drips: boolean)
	local points: { Vector2 } = {}
	for index = 1, #path - 1 do
		local from, to = V(path[index][1], path[index][2], 0), V(path[index + 1][1], path[index + 1][2], 0)
		local steps = math.ceil((to - from).Magnitude / 0.2)
		for step = 0, steps - 1 do
			local point = from:Lerp(to, step / steps)
			table.insert(points, Vector2.new(math.round(point.X / 0.05) * 0.05, math.round(point.Y / 0.05) * 0.05))
		end
	end
	local tip = path[#path]
	table.insert(points, Vector2.new(tip[1], tip[2]))
	for index, point in points do
		local size = thick * (1 - 0.45 * (index - 1) / (#points - 1))
		mark(cube(handle, "SkinTail", at(0, point.X, point.Y), V(size, size, size), CHITIN, SMOOTH))
		if index % 3 == 0 then
			mark(
				cube(
					handle,
					"SkinTailPlate",
					at(0, point.X, point.Y + size / 2),
					V(size * 0.6, size * 0.8, 0.06),
					OCHRE,
					SAND
				)
			)
		end
	end
	-- Aguijón grande que brilla, con la punta negra curvada hacia delante.
	local sting = mark(cube(handle, "SkinSting", at(0, tip[1] + 0.05, tip[2] - 0.22), V(0.2, 0.2, 0.3), STING, NEON))
	mark(cube(handle, "SkinStingTip", at(0, tip[1] + 0.2, tip[2] - 0.42), V(0.1, 0.2, 0.15), CHITIN, SMOOTH))
	if drips then
		emitter(sting, STING, 3, 0.12, 0.2, V(0, -10, 0))
	end
end

-- La cola sube por detrás de la culata y se arquea sobre la mira, con el aguijón colgando hacia delante.
local TAIL_ARCH = { { -1.75, 0.3 }, { -1.95, 0.7 }, { -1.95, 1.15 }, { -1.7, 1.5 }, { -1.3, 1.6 }, { -0.9, 1.4 } }
local TAIL_HIGH = {
	{ -1.75, 0.3 },
	{ -2.0, 0.7 },
	{ -2.05, 1.2 },
	{ -1.9, 1.7 },
	{ -1.5, 2.0 },
	{ -1.0, 2.1 },
	{ -0.5, 2.0 },
	{ 0.0, 1.8 },
	{ 0.4, 1.5 },
	{ 0.6, 1.2 },
}

-- Patas cortas bajo el cajón: "pairs" a cada lado.
local function scorpionLegs(handle: BasePart, pairs: number)
	for side = -1, 1, 2 do
		for index = 1, pairs do
			local along = -0.2 + (index - 1) * 0.35
			cube(handle, "SkinLeg", at(side * 0.3, along, -0.1), V(0.15, 0.1, 0.1), CHITIN, SMOOTH)
			cube(handle, "SkinLeg", at(side * 0.38, along, -0.3), V(0.1, 0.1, 0.3), CHITIN, SMOOTH)
			cube(handle, "SkinFoot", at(side * 0.44, along, -0.5), V(0.1, 0.1, 0.1), OCHRE, SAND)
		end
	end
end

-- Pinzas a los lados de la boca, con la punta hacia dentro. "big": añade el pulgar de abajo y una púa.
local function scorpionClaws(handle: BasePart, faction: string, big: boolean)
	for side = -1, 1, 2 do
		cube(handle, "SkinClaw", at(side * 0.3, 2.3, 0.1), V(0.12, 0.7, 0.12), CHITIN, SMOOTH)
		cube(handle, "SkinClawTip", at(side * 0.16, 2.78, 0.1), V(0.08, 0.2, 0.08), OCHRE, SAND)
		cube(handle, "SkinClawBase", at(side * 0.3, 1.95, 0.1), V(0.2, 0.2, 0.2), OCHRE, SAND)
		accent(handle, faction, at(side * 0.3, 1.95, 0.25))
		if big then
			cube(handle, "SkinClaw", at(side * 0.22, 2.7, 0.1), V(0.2, 0.12, 0.12), CHITIN, SMOOTH)
			cube(handle, "SkinThumb", at(side * 0.3, 2.15, -0.1), V(0.1, 0.35, 0.1), OCHRE, SAND)
			cube(handle, "SkinClawSpike", at(side * 0.3, 2.3, 0.28), V(0.08, 0.4, 0.08), CHITIN, SMOOTH)
		end
	end
end

-- ---------------------------------------------------------------------------------------------------
-- Kraken (Lanzarredes): cañón cuadrado de 0,55 a 1,45 (±0,375, alto de -0,25 a 0,45); boca enmarcada en
-- 1,47 con un peso en cada esquina (1,55); fardo de red encima (de -0,1 a 0,7, hasta 0,73 de alto);
-- corredera de bombeo debajo (0,67 a 1,23, hasta -0,7); punta del arpón hasta 2,2; culata hasta -1,8.
-- ---------------------------------------------------------------------------------------------------

-- Tentáculo de bloques que se tocan por "path" (lado, largo, alto; el lado se refleja con "mirror"). Cada
-- 0,2 va un bloque que adelgaza hacia la punta de coral, y cada tercero lleva una ventosa por fuera;
-- "glowing": ventosas cian que brillan. "back": lo de la espalda (la primera persona lo esconde).
local function tentacle(
	handle: BasePart,
	path: { { number } },
	mirror: number,
	thick: number,
	glowing: boolean,
	back: boolean
)
	local points: { Vector3 } = {}
	for index = 1, #path - 1 do
		local from = V(path[index][1], path[index][2], path[index][3])
		local to = V(path[index + 1][1], path[index + 1][2], path[index + 1][3])
		local steps = math.ceil((to - from).Magnitude / 0.2)
		for step = 0, steps - 1 do
			table.insert(points, from:Lerp(to, step / steps))
		end
	end
	local last = path[#path]
	table.insert(points, V(last[1], last[2], last[3]))
	for index, point in points do
		local size = thick * (1 - 0.4 * (index - 1) / (#points - 1))
		local piece = cube(
			handle,
			"SkinTentacle",
			at(mirror * point.X, point.Y, point.Z),
			V(size, size, size),
			if index == #points then CORAL else ABYSS,
			SMOOTH
		)
		local sucker: BasePart? = nil
		if index % 3 == 0 and index < #points then
			sucker = cube(
				handle,
				"SkinSucker",
				at(mirror * (point.X + size * 0.55), point.Y, point.Z),
				V(0.08, 0.08, 0.08),
				if glowing then CYAN else SUCKER,
				if glowing then NEON else SMOOTH
			)
		end
		if back then
			mark(piece)
			if sucker then
				mark(sucker)
			end
		end
	end
end

-- Ojos a los lados del cañón: blanco con pupila negra y el acento del bando encima.
local function krakenEyes(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		cube(handle, "SkinEye", at(side * 0.43, 0.85, 0.15), V(0.1, 0.3, 0.3), SUCKER, SMOOTH)
		cube(handle, "SkinPupil", at(side * 0.49, 0.85, 0.15), V(0.05, 0.15, 0.15), CHITIN, SMOOTH)
		accent(handle, faction, at(side * 0.43, 0.85, 0.42))
	end
end

-- Pico en la boca, alrededor del arpón: dos mandíbulas de quitina y la punta de coral.
local function krakenBeak(handle: BasePart)
	for side = -1, 1, 2 do
		cube(handle, "SkinBeak", at(side * 0.17, 1.62, 0.1), V(0.1, 0.25, 0.3), CHITIN, SMOOTH)
	end
	cube(handle, "SkinBeakTip", at(0, 1.6, 0.27), V(0.2, 0.2, 0.1), CORAL, SMOOTH)
end

-- Manto: casquete azul sobre el fardo de red, con manchas de ventosa.
local function krakenMantle(handle: BasePart, glowing: boolean)
	cube(handle, "SkinMantle", at(0, 0.3, 0.88), V(0.5, 0.75, 0.12), ABYSS, SMOOTH)
	for _, along in { 0.05, 0.3, 0.55 } do
		cube(
			handle,
			"SkinSpot",
			at(0, along, 0.97),
			V(0.15, 0.1, 0.06),
			if glowing then CYAN else SUCKER,
			if glowing then NEON else SMOOTH
		)
	end
end

-- Un ojo grande a cada lado de la culata (se ve por detrás) y burbujas que suben.
local function krakenBigEyes(handle: BasePart)
	for side = -1, 1, 2 do
		local eye = mark(cube(handle, "SkinBigEye", at(side * 0.22, -1.45, 0.1), V(0.1, 0.5, 0.5), SUCKER, SMOOTH))
		mark(cube(handle, "SkinIris", at(side * 0.26, -1.45, 0.1), V(0.05, 0.35, 0.35), CYAN, NEON))
		mark(cube(handle, "SkinPupil", at(side * 0.29, -1.45, 0.1), V(0.05, 0.15, 0.15), CHITIN, SMOOTH))
		emitter(eye, CYAN, 3, 0.1, 1.5, V(0, 3, 0))
	end
end

-- Recorridos de los tentáculos (lado, largo, alto) para el lado derecho; el izquierdo es el reflejo.
local ARM_LOW =
	{ { 0.5, 1.55, -0.3 }, { 0.62, 1.2, -0.42 }, { 0.66, 0.8, -0.4 }, { 0.58, 0.45, -0.25 }, { 0.5, 0.2, -0.1 } }
local ARM_HIGH = { { 0.5, 1.55, 0.5 }, { 0.62, 1.2, 0.6 }, { 0.64, 0.8, 0.62 }, { 0.5, 0.4, 0.55 }, { 0.3, 0.1, 0.5 } }
local ARM_SIDE =
	{ { 0.4, 1.5, 0.1 }, { 0.8, 1.45, 0.15 }, { 0.98, 1.1, 0.1 }, { 0.95, 0.7, -0.05 }, { 0.8, 0.4, -0.2 } }
-- Más largos: el de arriba sube y se enrosca sobre el fardo (se ve desde la primera persona).
local ARM_HIGH_LONG = {
	{ 0.5, 1.55, 0.5 },
	{ 0.65, 1.25, 0.65 },
	{ 0.7, 0.85, 0.8 },
	{ 0.55, 0.45, 0.95 },
	{ 0.3, 0.2, 1.05 },
	{ 0.1, 0.1, 1.2 },
}
-- Por detrás de la culata (lado, largo, alto): suben o cuelgan como una melena.
local ARM_REAR_HIGH =
	{ { 0.15, -1.75, 0.2 }, { 0.35, -2.05, 0.5 }, { 0.5, -2.35, 0.9 }, { 0.4, -2.65, 1.3 }, { 0.2, -2.8, 1.5 } }

-- ---------------------------------------------------------------------------------------------------
-- Dragón (Cañón): tubo de 0,4 a 1,7 (ancho 0,7); campana de 1,7 a 2,0 (ancho 1,0, de -0,4 a 0,6 de alto);
-- depósito de 0,4 a 1,3 sobre el tubo (de 0,53 a 1,03 de alto); manómetro a la derecha y asa a la izquierda.
-- ---------------------------------------------------------------------------------------------------

-- Hocico: la garganta de brasa sustituye el interior de la campana, con dientes de hueso alrededor.
local function dragonSnout(handle: BasePart, faction: string)
	drop(handle, "BellInside")
	drop(handle, "Bell")
	drop(handle, "BellRim")
	-- Campana de obsidiana con labio de brasa: la cabeza del dragón.
	cube(handle, "SkinBell", at(0, 1.85, 0.1), V(1.0, 0.3, 1.0), OBSIDIAN, SLATE)
	cube(handle, "SkinLip", at(0, 1.99, 0.1), V(1.08, 0.06, 1.08), EMBER, SMOOTH)
	cube(handle, "SkinThroat", at(0, 2.04, 0.1), V(0.7, 0.05, 0.7), EMBER, NEON)
	for offset = -1, 1 do
		cube(handle, "SkinTooth", at(offset * 0.3, 2.1, 0.55), V(0.12, 0.18, 0.1), HORN, SMOOTH)
		cube(handle, "SkinTooth", at(offset * 0.3, 2.1, -0.35), V(0.12, 0.18, 0.1), HORN, SMOOTH)
	end
	for _, up in { -0.05, 0.25 } do
		for side = -1, 1, 2 do
			cube(handle, "SkinTooth", at(side * 0.45, 2.1, up), V(0.1, 0.18, 0.12), HORN, SMOOTH)
		end
	end
	for side = -1, 1, 2 do
		cube(handle, "SkinNostril", at(side * 0.2, 1.9, 0.63), V(0.12, 0.15, 0.05), OBSIDIAN, SLATE)
	end
	-- Escamas: anillos de brasa en el tubo y placas a sus dos lados.
	for _, along in { 0.9, 1.35 } do
		cube(handle, "SkinScale", at(0, along, 0.1), V(0.82, 0.08, 0.82), EMBER, SMOOTH)
	end
	for side = -1, 1, 2 do
		for index, along in { 0.6, 0.8, 1.0, 1.2, 1.4, 1.6 } do
			cube(
				handle,
				"SkinPlateSide",
				at(side * 0.37, along, 0.0 + (index % 2) * 0.2),
				V(0.06, 0.14, 0.14),
				EMBER,
				SMOOTH
			)
		end
	end
	accent(handle, faction, at(0.5, 1.7, 0.45))
	accent(handle, faction, at(-0.5, 1.7, 0.45))
end

-- Cuernos hacia atrás, ojos que brillan, mandíbula, cresta sobre el depósito y alas plegadas a sus lados.
local function dragonHead(handle: BasePart, folded: boolean)
	for side = -1, 1, 2 do
		for step = 1, 3 do
			cube(
				handle,
				"SkinHorn",
				at(side * (0.4 + (step - 1) * 0.05), 1.95 - (step - 1) * 0.25, 0.55 + (step - 1) * 0.2),
				V(0.14, 0.25, 0.2),
				HORN,
				SMOOTH
			)
		end
		cube(handle, "SkinEye", at(side * 0.52, 1.8, 0.3), V(0.06, 0.15, 0.12), EMBER, NEON)
		if folded then
			cube(handle, "SkinFold", at(side * 0.3, 0.05, 0.62), V(0.1, 0.5, 0.4), MEMBRANE, SMOOTH)
			cube(handle, "SkinFoldBone", at(side * 0.3, 0.05, 0.86), V(0.14, 0.55, 0.08), HORN, SMOOTH)
			cube(handle, "SkinClaw", at(side * 0.3, 0.35, 0.62), V(0.12, 0.12, 0.15), HORN, SMOOTH)
		end
	end
	cube(handle, "SkinJaw", at(0, 1.85, -0.45), V(1.0, 0.3, 0.1), OBSIDIAN, SLATE)
	for index, along in { 0.5, 0.75, 1.0, 1.25 } do
		local height = 0.15 + (index % 2) * 0.1
		cube(handle, "SkinCrest", at(0, along, 1.03 + height / 2), V(0.1, 0.15, height), OBSIDIAN, SLATE)
	end
end

-- Grado III: alas abiertas hacia arriba y a los lados del depósito (se ven en primera persona), púas
-- por el lomo, escamas de brasa en el depósito, una cola por detrás de la culata (LabBack) y brasas y
-- humo por la boca.
local function dragonWings(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		for step = 1, 5 do
			-- Membrana: escalera de paneles que sube y se abre; la rama de hueso va por su borde de arriba.
			local up = 0.9 + step * 0.2
			local out = 0.4 + step * 0.17
			glass(
				cube(handle, "SkinWing", at(side * out, 0.85 - step * 0.05, up), V(0.12, 0.95, 0.25), MEMBRANE, SMOOTH),
				0.15
			)
			cube(handle, "SkinWingBone", at(side * out, 1.35 - step * 0.1, up + 0.16), V(0.14, 0.2, 0.1), HORN, SMOOTH)
		end
		cube(handle, "SkinWingVein", at(side * 0.55, 0.8, 1.35), V(0.14, 0.7, 0.05), EMBER, NEON)
		cube(handle, "SkinWingVein", at(side * 0.8, 0.75, 1.7), V(0.14, 0.5, 0.05), EMBER, NEON)
		cube(handle, "SkinFoldBone", at(side * 0.5, 0.4, 0.95), V(0.2, 0.1, 0.5), HORN, SMOOTH)
		cube(handle, "SkinPlate", at(side * 0.3, 0.85, 1.05), V(0.1, 0.8, 0.08), EMBER, SMOOTH)
		accent(handle, faction, at(side * 0.5, 0.4, 1.2))
	end
	-- Cola: curva por detrás de la culata, afinándose hasta una punta de hueso.
	for step, point in
		{ { -1.9, -0.1 }, { -2.15, -0.2 }, { -2.4, -0.15 }, { -2.6, 0.05 }, { -2.75, 0.3 }, { -2.85, 0.55 } }
	do
		local size = 0.32 - step * 0.03
		mark(cube(handle, "SkinTail", at(0, point[1], point[2]), V(size, 0.3, size), OBSIDIAN, SLATE))
	end
	for side = -1, 1, 2 do
		-- Aletas a los lados de la campana y placas de brasa en el cajón.
		for step = 1, 3 do
			cube(
				handle,
				"SkinFin",
				at(side * 0.58, 1.9 - step * 0.2, 0.25 + step * 0.1),
				V(0.1, 0.25, 0.35),
				OBSIDIAN,
				SLATE
			)
		end
		for index, along in { -0.3, -0.1, 0.1, 0.3 } do
			cube(
				handle,
				"SkinPlateSide",
				at(side * 0.27, along, 0.0 + (index % 2) * 0.2),
				V(0.06, 0.15, 0.15),
				EMBER,
				SMOOTH
			)
		end
	end
	mark(cube(handle, "SkinTailTip", at(0, -2.95, 0.8), V(0.12, 0.25, 0.2), HORN, SMOOTH))
	mark(cube(handle, "SkinTailEmber", at(0, -2.4, -0.3), V(0.1, 0.1, 0.1), EMBER, NEON))
	for index, along in { 0.5, 0.75, 1.0, 1.25 } do
		cube(handle, "SkinSpine", at(0, along, 1.4 + (index % 2) * 0.1), V(0.1, 0.15, 0.2), HORN, SMOOTH)
	end
	local throat = handle.Parent and handle.Parent:FindFirstChild("SkinThroat")
	if throat and throat:IsA("BasePart") then
		emitter(throat, EMBER, 5, 0.12, 1.5, V(0, 3, 0))
		emitter(throat, SMOKE, 2, 0.35, 1, V(0, 2, 0))
	end
end

-- ---------------------------------------------------------------------------------------------------

type Builder = (handle: BasePart, faction: string) -> ()

local BUILDERS: { [string]: Builder } = {
	LabWasp = function(handle, faction)
		waspStripes(handle)
		waspFoldedWings(handle, faction)
	end,
	LabWaspII = function(handle, faction)
		waspStripes(handle)
		waspOpenWings(handle, faction)
		waspStinger(handle)
		waspComb(handle)
	end,
	LabWaspIII = function(handle, faction)
		waspStripes(handle)
		waspOpenWings(handle, faction)
		waspStinger(handle)
		waspBigWings(handle, faction)
		waspComb(handle)
		waspBody(handle)
	end,
	LabScorpion = function(handle, faction)
		scorpionPlates(handle)
		scorpionScopeShell(handle)
		scorpionClaws(handle, faction, false)
		scorpionSacs(handle)
		scorpionFlanks(handle)
	end,
	LabScorpionII = function(handle, faction)
		scorpionPlates(handle)
		scorpionScopeShell(handle)
		scorpionClaws(handle, faction, true)
		scorpionSacs(handle)
		scorpionFlanks(handle)
		scorpionLegs(handle, 2)
		scorpionTail(handle, TAIL_ARCH, 0.3, false)
	end,
	LabScorpionIII = function(handle, faction)
		scorpionPlates(handle)
		scorpionScopeShell(handle)
		scorpionSpines(handle)
		scorpionClaws(handle, faction, true)
		scorpionSacs(handle)
		scorpionFlanks(handle)
		scorpionLegs(handle, 3)
		scorpionTail(handle, TAIL_HIGH, 0.36, true)
	end,
	LabKraken = function(handle, _faction)
		for side = -1, 1, 2 do
			tentacle(handle, ARM_LOW, side, 0.2, false, false)
		end
		krakenBeak(handle)
	end,
	LabKrakenII = function(handle, faction)
		for side = -1, 1, 2 do
			tentacle(handle, ARM_LOW, side, 0.22, true, false)
			tentacle(handle, ARM_HIGH, side, 0.2, true, false)
		end
		krakenBeak(handle)
		krakenEyes(handle, faction)
		krakenMantle(handle, false)
	end,
	LabKrakenIII = function(handle, faction)
		for side = -1, 1, 2 do
			tentacle(handle, ARM_LOW, side, 0.24, true, false)
			tentacle(handle, ARM_HIGH_LONG, side, 0.22, true, false)
			tentacle(handle, ARM_SIDE, side, 0.22, true, false)
			tentacle(handle, ARM_REAR_HIGH, side, 0.24, true, true)
		end
		krakenBeak(handle)
		krakenEyes(handle, faction)
		krakenMantle(handle, true)
		krakenBigEyes(handle)
	end,
	LabDragon = function(handle, faction)
		dragonSnout(handle, faction)
	end,
	LabDragonII = function(handle, faction)
		dragonSnout(handle, faction)
		dragonHead(handle, true)
	end,
	LabDragonIII = function(handle, faction)
		dragonSnout(handle, faction)
		dragonHead(handle, false)
		dragonWings(handle, faction)
	end,
}

-- true si "skinId" es una skin de arma del Laboratorio.
function LabWeaponSkins.has(skinId: string): boolean
	return BUILDERS[skinId] ~= nil
end

-- true si "skinId" es una skin del arma "weaponId" (Data/Cosmetics "weapon").
function LabWeaponSkins.fits(skinId: string, weaponId: string): boolean
	local cosmetic = Cosmetics[skinId]
	return BUILDERS[skinId] ~= nil and cosmetic ~= nil and cosmetic.weapon == weaponId
end

-- Añade las piezas de la skin "skinId" al arma de "handle" (la base del bando "faction").
function LabWeaponSkins.apply(handle: BasePart, skinId: string, faction: string)
	local builder = BUILDERS[skinId]
	if builder then
		builder(handle, faction)
	end
end

return LabWeaponSkins
