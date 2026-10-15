--!strict
-- Modelos de las armaduras (Data/Armor) que lleva puestas el personaje. CraftingService los pone al
-- fabricarlas y al reaparecer. Todas las piezas van soldadas al torso (UpperTorso en R15, Torso en
-- R6) y se ajustan a su tamaño, así quedan bien en cualquier avatar. Respecto al torso: -Z es el
-- pecho, +Z la espalda y +Y los hombros.
--   - Chaleco de pelaje: chaleco rojo ceñido, abierto por delante, con hombreras, cuello y ribete de
--     pelaje dorado, cordones de fibra y flecos cortos.
--   - Armadura de hueso: peto de cuero con costillas y esternón de hueso, hombreras de hueso con
--     púas, cuello de pelaje rojo y cinturón.
--   - Armadura de plata: manto de pelaje plateado de gorila sobre los hombros y la espalda, peto de
--     cuero cruzado por dos placas de hueso grueso, medallón de plata y púas en las hombreras.

local Armor = require(game:GetService("ReplicatedStorage").Shared.Data.Armor)

local FUR = Color3.fromRGB(150, 70, 45)
local FUR_DARK = Color3.fromRGB(122, 55, 36)
local GOLDEN_FUR = Color3.fromRGB(235, 190, 80)
local FIBER = Color3.fromRGB(150, 135, 85)
local LEATHER = Color3.fromRGB(70, 47, 30)
local LEATHER_DARK = Color3.fromRGB(48, 32, 20)
local BONE = Color3.fromRGB(230, 220, 195)
local BONE_DARK = Color3.fromRGB(190, 175, 145)
local SILVER_FUR = Color3.fromRGB(215, 220, 228)
local SILVER_FUR_DARK = Color3.fromRGB(170, 175, 185)
local SILVER = Color3.fromRGB(200, 205, 215)

local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic

-- Los cilindros de Roblox van a lo largo de su X: así quedan a lo largo de la Y.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- Y así a lo largo de Z (discos que miran al frente).
local FACING = CFrame.Angles(0, math.rad(90), 0)

local ArmorModels = {}

type Builder = {
	block: (size: Vector3, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	rod: (length: number, diameter: number, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	ball: (diameter: number, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	spike: (length: number, width: number, color: Color3, at: CFrame) -> (),
}

-- Piezas soldadas al torso dentro de "model"; "at" es respecto al torso.
local function builder(model: Model, torso: BasePart): Builder
	local function place(piece: BasePart, at: CFrame): BasePart
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		piece.CFrame = torso.CFrame * at
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = piece
		weld.Parent = piece
		piece.Parent = model
		return piece
	end
	local function part(size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local piece = Instance.new("Part")
		piece.Name = "Armor"
		piece.Size = size
		piece.Color = color
		piece.Material = material
		if shape then
			piece.Shape = shape
		end
		return piece
	end
	return {
		block = function(size, color, material, at)
			return place(part(size, color, material), at)
		end,
		rod = function(length, diameter, color, material, at)
			return place(part(Vector3.new(length, diameter, diameter), color, material, Enum.PartType.Cylinder), at)
		end,
		ball = function(diameter, color, material, at)
			return place(part(Vector3.one * diameter, color, material, Enum.PartType.Ball), at)
		end,
		-- Púa: dos medias cuñas espalda con espalda que apuntan hacia la +Y de "at".
		spike = function(length, width, color, at)
			for side = -1, 1, 2 do
				local half = Instance.new("WedgePart")
				half.Name = "Armor"
				half.Size = Vector3.new(width, length, width * 0.8)
				half.Color = color
				half.Material = SMOOTH
				local flip = if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
				place(half, at * CFrame.new(0, 0, side * width * 0.4) * flip)
			end
		end,
	}
end

-- ===================================== Chaleco de pelaje =====================================

local function furVest(make: Builder, size: Vector3)
	local width, height, depth = size.X, size.Y, size.Z
	local skin = 0.1 -- grosor del pelaje
	local gap = 0.03 -- separación del torso
	local front = -(depth / 2 + gap + skin / 2)
	local back = depth / 2 + gap + skin / 2
	local outer = width / 2 + gap + skin / 2
	-- Los paneles suben hasta el borde de arriba de las hombreras: se solapan con ellas y no queda
	-- ninguna rendija entre el chaleco y los hombros.
	local panelHeight = height + gap + skin
	local panelY = (gap + skin) / 2
	-- Espalda y costados, ceñidos al torso.
	make.block(Vector3.new(width + 2 * (gap + skin), panelHeight, skin), FUR_DARK, FABRIC, CFrame.new(0, panelY, back))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(skin, panelHeight, depth + 2 * gap),
			FUR_DARK,
			FABRIC,
			CFrame.new(side * outer, panelY, 0)
		)
		-- Panel delantero: deja una abertura estrecha en el centro.
		local inner = 0.16
		local panelWidth = width / 2 + gap + skin - inner
		make.block(
			Vector3.new(panelWidth, panelHeight, skin),
			FUR,
			FABRIC,
			CFrame.new(side * (inner + panelWidth / 2), panelY, front)
		)
		-- Ribete dorado en el borde de la abertura.
		make.block(
			Vector3.new(0.1, panelHeight, skin + 0.04),
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * (inner + 0.05), panelY, front)
		)
		-- Hombrera: tapa el hombro de delante a atrás y deja libre el cuello.
		local neck = width * 0.2
		local shoulderWidth = outer + skin / 2 - neck
		make.block(
			Vector3.new(shoulderWidth, skin, depth + 2 * (gap + skin)),
			FUR,
			FABRIC,
			CFrame.new(side * (neck + shoulderWidth / 2), height / 2 + gap + skin / 2, 0)
		)
		-- Mechón de pelaje redondeando el borde del hombro.
		make.ball(0.42, FUR, FABRIC, CFrame.new(side * (outer - 0.04), height / 2 + 0.04, 0))
		-- Cuello de pelaje dorado a cada lado.
		make.rod(
			depth * 0.9,
			0.24,
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * neck, height / 2 + 0.1, 0) * CFrame.Angles(0, math.rad(90), 0)
		)
	end
	-- Cuello por detrás y ribete dorado fino abajo.
	make.rod(width * 0.4 + 0.24, 0.24, GOLDEN_FUR, FABRIC, CFrame.new(0, height / 2 + 0.1, depth / 2 - 0.02))
	make.block(
		Vector3.new(width + 2 * (gap + skin) + 0.04, 0.14, depth + 2 * (gap + skin) + 0.04),
		GOLDEN_FUR,
		FABRIC,
		CFrame.new(0, -height / 2 + 0.05, 0)
	)
	-- Cordones de fibra en cruz que cierran la abertura.
	for _, laceY in { height * 0.2, -height * 0.05 } do
		for _, tilt in { 0.5, -0.5 } do
			make.block(
				Vector3.new(0.36, 0.05, 0.04),
				FIBER,
				FABRIC,
				CFrame.new(0, laceY, front - 0.07) * CFrame.Angles(0, 0, tilt)
			)
		end
	end
	-- Flecos cortos bajo el ribete, por delante (no en la abertura).
	for index = 0, 5 do
		local x = -width / 2 + 0.2 + index * (width - 0.4) / 5
		if math.abs(x) > 0.3 then
			make.block(Vector3.new(0.1, 0.18, 0.05), FUR, FABRIC, CFrame.new(x, -height / 2 - 0.1, front))
		end
	end
end

-- ===================================== Armadura de hueso =====================================

local function boneArmor(make: Builder, size: Vector3)
	local width, height, depth = size.X, size.Y, size.Z
	local front = -(depth / 2 + 0.1)
	-- Peto de cuero y cuello de pelaje rojo.
	make.block(Vector3.new(width + 0.1, height * 0.9, depth + 0.16), LEATHER, FABRIC, CFrame.new(0, -height * 0.03, 0))
	make.block(Vector3.new(width * 0.75, 0.25, depth + 0.25), FUR, FABRIC, CFrame.new(0, height / 2 - 0.05, 0))
	-- Costillas delante y detrás, con el esternón y las ataduras de fibra en el centro.
	for _, ribY in { 0.25, 0.08, -0.09, -0.26 } do
		make.rod(width * 0.82, 0.16, BONE, SMOOTH, CFrame.new(0, height * ribY, front))
		make.block(Vector3.new(0.26, 0.22, 0.06), FIBER, FABRIC, CFrame.new(0, height * ribY, front - 0.1))
	end
	for _, ribY in { 0.2, 0, -0.2 } do
		make.rod(width * 0.78, 0.15, BONE_DARK, SMOOTH, CFrame.new(0, height * ribY, depth / 2 + 0.1))
	end
	make.rod(height * 0.7, 0.18, BONE, SMOOTH, CFrame.new(0, 0, front - 0.04) * UPRIGHT)
	-- Hombreras de hueso grandes, hacia fuera, con una púa.
	for side = -1, 1, 2 do
		local shoulder = side * (width / 2 + 0.22)
		make.ball(width * 0.55, BONE, SMOOTH, CFrame.new(shoulder, height / 2 - 0.05, 0))
		make.spike(
			0.5,
			0.18,
			BONE_DARK,
			CFrame.new(shoulder + side * 0.15, height / 2 + width * 0.25, 0) * CFrame.Angles(0, 0, -side * 0.5)
		)
	end
	-- Cinturón con hebilla de hueso.
	make.block(Vector3.new(width + 0.2, 0.18, depth + 0.22), LEATHER_DARK, FABRIC, CFrame.new(0, -height / 2 + 0.08, 0))
	make.ball(0.26, BONE_DARK, SMOOTH, CFrame.new(0, -height / 2 + 0.08, -(depth / 2 + 0.12)))
end

-- ===================================== Armadura de plata =====================================

local function silverArmor(make: Builder, size: Vector3)
	local width, height, depth = size.X, size.Y, size.Z
	local front = -(depth / 2 + 0.12)
	-- Peto de cuero cruzado por dos placas de hueso grueso, con un medallón de plata.
	make.block(
		Vector3.new(width + 0.12, height * 0.92, depth + 0.18),
		LEATHER,
		FABRIC,
		CFrame.new(0, -height * 0.03, 0)
	)
	for _, tilt in { 0.55, -0.55 } do
		make.block(
			Vector3.new(0.24, height * 0.95, 0.12),
			BONE,
			SMOOTH,
			CFrame.new(0, -height * 0.05, front) * CFrame.Angles(0, 0, tilt)
		)
	end
	local medallion =
		make.rod(0.12, 0.55, SILVER, Enum.Material.Metal, CFrame.new(0, -height * 0.05, front - 0.1) * FACING)
	medallion.Reflectance = 0.25
	make.ball(0.2, BONE, SMOOTH, CFrame.new(0, -height * 0.05, front - 0.16))
	-- Manto de pelaje plateado: sobre los hombros, mechones grandes y capa por la espalda.
	make.block(
		Vector3.new(width + 0.45, height * 0.3, depth + 0.45),
		SILVER_FUR,
		FABRIC,
		CFrame.new(0, height / 2 - 0.1, 0)
	)
	make.block(
		Vector3.new(width * 0.95, height * 1.1, 0.14),
		SILVER_FUR_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.15, depth / 2 + 0.16)
	)
	for side = -1, 1, 2 do
		-- Hombreras de pelaje grandes y hacia fuera, con dos púas de hueso grueso cada una.
		local shoulder = side * (width / 2 + 0.2)
		make.ball(width * 0.62, SILVER_FUR, FABRIC, CFrame.new(shoulder, height / 2, 0))
		for _, offset in { -0.18, 0.18 } do
			make.spike(
				0.5,
				0.18,
				BONE,
				CFrame.new(shoulder + side * 0.1, height / 2 + width * 0.3, offset) * CFrame.Angles(0, 0, -side * 0.35)
			)
		end
	end
	-- Cinturón de cuero con hebilla de plata.
	make.block(Vector3.new(width + 0.22, 0.2, depth + 0.24), LEATHER_DARK, FABRIC, CFrame.new(0, -height / 2 + 0.08, 0))
	local buckle = make.block(
		Vector3.new(0.34, 0.26, 0.08),
		SILVER,
		Enum.Material.Metal,
		CFrame.new(0, -height / 2 + 0.08, -(depth / 2 + 0.14))
	)
	buckle.Reflectance = 0.25
end

local BUILDERS: { [string]: (make: Builder, size: Vector3) -> () } = {
	FurVest = furVest,
	BoneArmor = boneArmor,
	SilverArmor = silverArmor,
}

-- Viste a "character" con la armadura "armorId" (sustituye a la que llevara). Devuelve el modelo, o
-- nil si no hay torso o la armadura no existe.
function ArmorModels.wear(character: Model, armorId: string): Model?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local build = BUILDERS[armorId]
	if not (torso and torso:IsA("BasePart") and build and Armor[armorId]) then
		return nil
	end
	local previous = character:FindFirstChild("ArmorPiece")
	if previous then
		previous:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "ArmorPiece"
	build(builder(model, torso), torso.Size)
	model.Parent = character
	return model
end

return ArmorModels
