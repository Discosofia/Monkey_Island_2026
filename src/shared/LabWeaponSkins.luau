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
local WING = Color3.fromRGB(165, 170, 185)
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
-- Avispa (Lanzadardos): cañón en 1,0 a 1,75; cajón de -0,45 a 0,85; bidón debajo.
-- ---------------------------------------------------------------------------------------------------

-- Franjas de avispa en el cañón y el bidón.
local function waspStripes(handle: BasePart)
	for _, along in { 1.0, 1.3, 1.6 } do
		cube(handle, "SkinStripe", at(0, along, 0.1), V(0.28, 0.1, 0.28), AMBER, SMOOTH)
	end
	for _, along in { 0.1, 0.3 } do
		cube(handle, "SkinBand", at(0, along, -0.45), V(0.4, 0.08, 0.35), AMBER, SMOOTH)
	end
	cube(handle, "SkinBand", at(0, 0.2, -0.45), V(0.4, 0.08, 0.35), WASP_BLACK, SMOOTH)
	-- Abdomen rayado: bandas ámbar y negras alrededor del cajón.
	for index, along in { -0.2, 0.05, 0.3, 0.55 } do
		cube(
			handle,
			"SkinBody",
			at(0, along, 0.05),
			V(0.52, 0.1, 0.65),
			if index % 2 == 1 then AMBER else WASP_BLACK,
			SMOOTH
		)
	end
end

-- Alas plegadas a los lados del cajón.
local function waspFoldedWings(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		glass(cube(handle, "SkinWing", at(side * 0.3, 0.15, 0.15), V(0.05, 0.9, 0.35), WING, GLASS), 0.45)
		cube(handle, "SkinWingVein", at(side * 0.3, 0.15, 0.15), V(0.07, 0.9, 0.05), WASP_BLACK, SMOOTH)
		accent(handle, faction, at(side * 0.3, -0.3, 0.05))
	end
end

-- Aguijón de neón en la boca y dos antenas.
local function waspStinger(handle: BasePart)
	cube(handle, "SkinStinger", at(0, 1.9, 0.1), V(0.1, 0.25, 0.1), HONEY, NEON)
	cube(handle, "SkinStingerTip", at(0, 2.08, 0.1), V(0.05, 0.1, 0.05), WASP_BLACK, SMOOTH)
	for side = -1, 1, 2 do
		cube(handle, "SkinAntenna", at(side * 0.12, 0.85, 0.5), V(0.05, 0.05, 0.3), WASP_BLACK, SMOOTH)
		cube(handle, "SkinAntennaTip", at(side * 0.12, 0.85, 0.72), V(0.1, 0.1, 0.1), HONEY, NEON)
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
				0.45
			)
			cube(
				handle,
				"SkinWingVein",
				at(side * (0.38 + (step - 1) * 0.14), along + length / 2, 0.3 + (step - 1) * 0.12),
				V(0.15, 0.05, 0.12),
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
					0.45
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

-- Panal que brilla a los lados del bidón.
local function waspComb(handle: BasePart)
	for side = -1, 1, 2 do
		for index, along in { 0.0, 0.2, 0.4 } do
			cube(
				handle,
				"SkinComb",
				at(side * 0.2, along, if index % 2 == 0 then -0.5 else -0.4),
				V(0.08, 0.14, 0.14),
				HONEY,
				NEON
			)
		end
	end
end

-- ---------------------------------------------------------------------------------------------------
-- Escorpión (Rifle): cañón de 0,65 a 2,65; culata hasta -1,8; cajón de -0,45 a 0,65.
-- ---------------------------------------------------------------------------------------------------

-- Placas segmentadas en el cañón.
local function scorpionPlates(handle: BasePart)
	for index, along in { 0.95, 1.25, 1.55, 1.85, 2.15 } do
		local width = 0.34 - (index - 1) * 0.02
		cube(handle, "SkinPlate", at(0, along, 0.1), V(width, 0.2, width), OCHRE, SAND)
	end
	cube(handle, "SkinPlateRidge", at(0, 1.55, 0.3), V(0.1, 1.4, 0.1), CHITIN, SMOOTH)
end

-- Cola de bloques que parte de la culata y acaba en un aguijón. "path": (largo, alto) de cada segmento.
local function scorpionTail(handle: BasePart, path: { { number } }, drips: boolean)
	local last = nil
	for index, point in path do
		local size = 0.26 - (index - 1) * 0.015
		last = mark(cube(handle, "SkinTail", at(0, point[1], point[2]), V(size, 0.25, size), CHITIN, SMOOTH))
		if index % 2 == 0 then
			mark(cube(handle, "SkinTailPlate", at(0, point[1], point[2] + size / 2), V(0.12, 0.2, 0.05), OCHRE, SAND))
		end
	end
	local tip = path[#path]
	local sting = mark(cube(handle, "SkinSting", at(0, tip[1] + 0.12, tip[2] - 0.2), V(0.12, 0.2, 0.2), STING, NEON))
	if drips and last then
		emitter(sting, STING, 3, 0.12, 0.2, V(0, -10, 0))
	end
end

local TAIL_ARCH =
	{ { -1.7, 0.25 }, { -1.85, 0.5 }, { -1.9, 0.75 }, { -1.8, 1.0 }, { -1.55, 1.15 }, { -1.25, 1.15 }, { -1.0, 1.0 } }
local TAIL_HIGH = {
	{ -1.7, 0.25 },
	{ -1.9, 0.55 },
	{ -2.0, 0.9 },
	{ -1.95, 1.25 },
	{ -1.75, 1.55 },
	{ -1.45, 1.75 },
	{ -1.1, 1.75 },
	{ -0.85, 1.55 },
	{ -0.75, 1.3 },
}

-- Patas cortas bajo el cajón (tres a cada lado).
local function scorpionLegs(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		for _, along in { -0.15, 0.2, 0.55 } do
			cube(handle, "SkinLeg", at(side * 0.3, along, -0.1), V(0.15, 0.1, 0.1), CHITIN, SMOOTH)
			cube(handle, "SkinLeg", at(side * 0.38, along, -0.3), V(0.1, 0.1, 0.3), CHITIN, SMOOTH)
			cube(handle, "SkinFoot", at(side * 0.44, along, -0.5), V(0.1, 0.1, 0.1), OCHRE, SAND)
		end
		accent(handle, faction, at(side * 0.26, -0.3, 0.3))
	end
end

-- Pinzas a los lados de la boca, con la punta hacia dentro.
local function scorpionClaws(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		cube(handle, "SkinClaw", at(side * 0.3, 2.3, 0.1), V(0.12, 0.7, 0.12), CHITIN, SMOOTH)
		cube(handle, "SkinClaw", at(side * 0.22, 2.7, 0.1), V(0.2, 0.12, 0.12), CHITIN, SMOOTH)
		cube(handle, "SkinClawTip", at(side * 0.16, 2.78, 0.1), V(0.08, 0.2, 0.08), OCHRE, SAND)
		cube(handle, "SkinClawBase", at(side * 0.3, 1.95, 0.1), V(0.2, 0.2, 0.2), OCHRE, SAND)
	end
	accent(handle, faction, at(0.3, 1.95, 0.25))
	accent(handle, faction, at(-0.3, 1.95, 0.25))
end

-- ---------------------------------------------------------------------------------------------------
-- Kraken (Lanzarredes): lanzador de 0,5 a 1,5; boca en 1,48; punta del arpón hasta 2,1.
-- ---------------------------------------------------------------------------------------------------

-- Tentáculo de "count" bloques que parte de "origin" (lado, largo, alto) hacia fuera. "backward": se curva
-- hacia atrás. Las ventosas van del lado de dentro; "glowing": brillan en cian.
local function tentacle(handle: BasePart, origin: Vector3, count: number, backward: boolean, glowing: boolean)
	local sideSign = if origin.X >= 0 then 1 else -1
	local upSign = if origin.Z >= 0.1 then 1 else -1
	local position = origin
	local size = 0.22
	for index = 1, count do
		local along = if backward then 0.24 - 0.09 * index else 0.2
		position += V(sideSign * 0.09, along, upSign * (if origin.Z == 0.1 then 0.02 else 0.06))
		size = math.max(0.08, size - 0.015)
		cube(
			handle,
			"SkinTentacle",
			at(position.X, position.Y, position.Z),
			V(size, size, size),
			if index == count then CORAL else ABYSS,
			SMOOTH
		)
		if index % 2 == 1 and index < count then
			cube(
				handle,
				"SkinSucker",
				at(position.X - sideSign * size * 0.55, position.Y, position.Z),
				V(0.08, 0.08, 0.08),
				if glowing then CYAN else SUCKER,
				if glowing then NEON else SMOOTH
			)
		end
	end
end

-- Un ojo en cada lateral del lanzador.
local function krakenEyes(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		cube(handle, "SkinEye", at(side * 0.5, 1.2, 0.1), V(0.1, 0.3, 0.3), SUCKER, SMOOTH)
		cube(handle, "SkinPupil", at(side * 0.56, 1.2, 0.1), V(0.05, 0.15, 0.15), CHITIN, SMOOTH)
		accent(handle, faction, at(side * 0.5, 0.85, 0.35))
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

-- ---------------------------------------------------------------------------------------------------
-- Dragón (Cañón): tubo de 0,5 a 1,6; campana en 1,7 (1,575 a 1,825); depósito encima.
-- ---------------------------------------------------------------------------------------------------

-- Hocico: la garganta de brasa sustituye el interior de la campana, con dientes de hueso alrededor.
local function dragonSnout(handle: BasePart, faction: string)
	drop(handle, "BellInside")
	cube(handle, "SkinThroat", at(0, 1.83, 0.1), V(0.5, 0.05, 0.5), EMBER, NEON)
	for offset = -1, 1 do
		cube(handle, "SkinTooth", at(offset * 0.27, 1.9, 0.5), V(0.1, 0.15, 0.1), HORN, SMOOTH)
		cube(handle, "SkinTooth", at(offset * 0.27, 1.9, -0.3), V(0.1, 0.15, 0.1), HORN, SMOOTH)
	end
	for _, up in { 0.0, 0.2 } do
		for side = -1, 1, 2 do
			cube(handle, "SkinTooth", at(side * 0.4, 1.9, up), V(0.1, 0.15, 0.1), HORN, SMOOTH)
		end
	end
	for side = -1, 1, 2 do
		cube(handle, "SkinNostril", at(side * 0.12, 1.45, 0.42), V(0.1, 0.15, 0.1), OBSIDIAN, SLATE)
	end
	-- Escamas: anillos de brasa en el tubo.
	for _, along in { 0.75, 1.05, 1.35 } do
		cube(handle, "SkinScale", at(0, along, 0.1), V(0.65, 0.08, 0.65), EMBER, SMOOTH)
	end
	accent(handle, faction, at(0.3, 1.45, 0.4))
	accent(handle, faction, at(-0.3, 1.45, 0.4))
end

-- Cuernos hacia atrás, ojos que brillan, mandíbula y cresta en el tubo.
local function dragonHead(handle: BasePart)
	for side = -1, 1, 2 do
		for step = 1, 3 do
			cube(
				handle,
				"SkinHorn",
				at(side * (0.35 + (step - 1) * 0.05), 1.6 - (step - 1) * 0.2, 0.5 + (step - 1) * 0.2),
				V(0.12, 0.2, 0.2),
				HORN,
				SMOOTH
			)
		end
		cube(handle, "SkinEye", at(side * 0.42, 1.55, 0.3), V(0.06, 0.15, 0.12), EMBER, NEON)
	end
	cube(handle, "SkinJaw", at(0, 1.7, -0.35), V(0.7, 0.3, 0.1), OBSIDIAN, SLATE)
	for index, along in { 0.7, 0.95, 1.2, 1.45 } do
		local height = 0.15 + (index - 1) * 0.05
		cube(handle, "SkinCrest", at(0, along, 0.38 + height / 2), V(0.1, 0.15, height), OBSIDIAN, SLATE)
	end
end

-- Alas sobre la culata (se ven por detrás), púas a lo largo del lomo y brasas y humo por la boca.
local function dragonWings(handle: BasePart, faction: string)
	for side = -1, 1, 2 do
		for step = 1, 4 do
			local height = 0.5 + step * 0.1
			-- Membrana marrón rojiza y algo translúcida entre los huesos.
			mark(
				glass(
					cube(
						handle,
						"SkinWing",
						at(side * (0.3 + step * 0.17), -1.1 - step * 0.1, 0.4 + step * 0.18),
						V(0.12, 1.3 - step * 0.15, height),
						MEMBRANE,
						SMOOTH
					),
					0.2
				)
			)
			mark(
				cube(
					handle,
					"SkinWingBone",
					at(side * (0.3 + step * 0.17), -0.5 - step * 0.1, 0.55 + step * 0.18 + height / 2),
					V(0.14, 0.14, 0.1),
					HORN,
					SMOOTH
				)
			)
		end
		mark(cube(handle, "SkinWingVein", at(side * 0.6, -1.3, 0.8), V(0.14, 1.0, 0.05), EMBER, NEON))
		mark(cube(handle, "SkinWingVein", at(side * 0.8, -1.5, 1.15), V(0.14, 0.7, 0.05), EMBER, NEON))
		mark(accent(handle, faction, at(side * 0.3, -0.55, 0.4)))
	end
	for index, along in { -0.3, -0.05, 0.2, 0.45, 0.7 } do
		local height = 0.2 + (index % 2) * 0.1
		cube(handle, "SkinSpine", at(0, along, 0.8 + height / 2), V(0.1, 0.15, height), HORN, SMOOTH)
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
	end,
	LabWaspIII = function(handle, faction)
		waspStripes(handle)
		waspStinger(handle)
		waspBigWings(handle, faction)
		waspComb(handle)
	end,
	LabScorpion = function(handle, _faction)
		scorpionPlates(handle)
	end,
	LabScorpionII = function(handle, faction)
		scorpionPlates(handle)
		scorpionTail(handle, TAIL_ARCH, false)
		scorpionLegs(handle, faction)
	end,
	LabScorpionIII = function(handle, faction)
		scorpionPlates(handle)
		scorpionLegs(handle, faction)
		scorpionClaws(handle, faction)
		scorpionTail(handle, TAIL_HIGH, true)
	end,
	LabKraken = function(handle, _faction)
		for side = -1, 1, 2 do
			tentacle(handle, V(side * 0.3, 1.5, 0.1), 6, false, false)
		end
	end,
	LabKrakenII = function(handle, faction)
		for side = -1, 1, 2 do
			tentacle(handle, V(side * 0.3, 1.5, 0.35), 6, false, true)
			tentacle(handle, V(side * 0.3, 1.5, -0.15), 6, false, true)
		end
		krakenEyes(handle, faction)
	end,
	LabKrakenIII = function(handle, faction)
		for side = -1, 1, 2 do
			tentacle(handle, V(side * 0.3, 1.5, 0.35), 7, true, true)
			tentacle(handle, V(side * 0.3, 1.5, -0.15), 7, true, true)
			tentacle(handle, V(side * 0.4, 1.4, 0.1), 7, true, true)
		end
		krakenEyes(handle, faction)
		krakenBigEyes(handle)
	end,
	LabDragon = function(handle, faction)
		dragonSnout(handle, faction)
	end,
	LabDragonII = function(handle, faction)
		dragonSnout(handle, faction)
		dragonHead(handle)
	end,
	LabDragonIII = function(handle, faction)
		dragonSnout(handle, faction)
		dragonHead(handle)
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
