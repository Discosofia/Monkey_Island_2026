--!strict
-- Imágenes 3D de los premios (Fase 9): modelos voxel pequeños que se ven en las tarjetas del pase de
-- temporada (UI/SeasonPassPanel, dentro de un ViewportFrame), nunca en el mundo. Cajas alineadas a una
-- rejilla de UNIT studs, con 3–5 tonos planos, como los monos y las mascotas voxel.
--
--   RewardModels.forReward(reward)       -- el modelo de un premio (Data/Seasons, Config.Reward)
--   RewardModels.cosmetic(character, id) -- la imagen de un cosmético: su modelo propio o tu avatar
--   RewardModels.avatar(character, id)   -- tu avatar en miniatura con un cosmético puesto
--   RewardModels.frame(viewport, model)  -- lo mete en el ViewportFrame con su cámara y su luz
--
-- Todos salen de pie en el origen, con el frente hacia -Z. Los ViewportFrame no dibujan partículas,
-- estelas (Trail) ni BillboardGui: el aura y la estela se hacen con bloques de neón, y el título lo
-- pone la tarjeta como texto. Los cosméticos que no se llevan encima tienen su propio modelo: el
-- estilo de los números (unos números voxel con sus colores y su borde), el de los estallidos (una
-- estrella de cómic con su "!"), la decoración del nido (alrededor de un nido pequeño) y las skins de
-- mascota (la mascota con la skin). Un aura por grados lleva más piezas en cada grado.

local ComicBurst = require(script.Parent.UI.ComicBurst)
local CosmeticSlots = require(script.Parent.CosmeticSlots)
local Cosmetics = require(script.Parent.Data.Cosmetics)
local EggModel = require(script.Parent.EggModel)
local NestDecor = require(script.Parent.NestDecor)
local NumberStyles = require(script.Parent.UI.NumberStyles)
local PetModels = require(script.Parent.PetModels)
local Pets = require(script.Parent.Data.Pets)

local UNIT = 0.25

local AMBER = Color3.fromRGB(235, 140, 30)
local AMBER_LIGHT = Color3.fromRGB(255, 195, 70)
local AMBER_DARK = Color3.fromRGB(170, 80, 20)
local BASALT = Color3.fromRGB(55, 48, 45)
local WOOD = Color3.fromRGB(110, 72, 40)
local LIGHT_WOOD = Color3.fromRGB(175, 130, 80)
local FIBER = Color3.fromRGB(150, 135, 85)
local SAND = Color3.fromRGB(230, 195, 120)
local GLASS = Color3.fromRGB(200, 230, 245)
local BANANA = Color3.fromRGB(250, 215, 60)
local BANANA_SHADE = Color3.fromRGB(215, 170, 35)
local STEM = Color3.fromRGB(95, 70, 35)
local CLOTH = Color3.fromRGB(240, 235, 222)
local CLOTH_SHADE = Color3.fromRGB(205, 198, 182)
local CROSS_RED = Color3.fromRGB(210, 45, 45)
local HOLE = Color3.fromRGB(110, 100, 90)
local READY_GOLD = Color3.fromRGB(242, 178, 36)
local KIT_RED = Color3.fromRGB(190, 40, 40)
local KIT_DARK = Color3.fromRGB(120, 25, 25)
local WHITE = Color3.fromRGB(245, 245, 245)
local IRON = Color3.fromRGB(70, 70, 75)
-- Antídoto: verde de curación (el morado es del veneno).
local POTION = Color3.fromRGB(90, 220, 110)
local CORK = Color3.fromRGB(165, 120, 75)
local FLAME_RED = Color3.fromRGB(230, 70, 25)
local FLAME_ORANGE = Color3.fromRGB(255, 140, 30)
local FLAME_YELLOW = Color3.fromRGB(255, 225, 90)
local STRAW = Color3.fromRGB(205, 175, 105)
-- Letras de 3 × 5 celdas (de arriba abajo) para los números voxel.
local GLYPHS: { [string]: { string } } = {
	["9"] = { "111", "101", "111", "001", "111" },
	["!"] = { "1", "1", "1", "0", "1" },
}

local RewardModels = {}

-- Caja en celdas: centro (x, y, z) y tamaño (ancho, alto, fondo), con "at" para girarla o moverla.
local function box(
	model: Model,
	center: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	at: CFrame?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size * UNIT
	part.CFrame = (at or CFrame.identity) * CFrame.new(center * UNIT)
	part.Parent = model
	return part
end

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

-- Un cristal de ámbar: prisma fino que se afila en escalones hasta la punta, con una arista clara.
local function crystal(model: Model, at: CFrame, height: number)
	box(model, Vector3.new(0, height * 0.4, 0), Vector3.new(2, height * 0.8, 2), AMBER, nil, at)
	box(model, Vector3.new(0, height * 0.8 + 0.6, 0), Vector3.new(1.4, 1.2, 1.4), AMBER, nil, at)
	box(model, Vector3.new(0, height * 0.8 + 1.6, 0), Vector3.new(0.8, 0.8, 0.8), AMBER_LIGHT, nil, at)
	box(model, Vector3.new(0, 0.4, 0), Vector3.new(2.4, 0.8, 2.4), AMBER_DARK, nil, at)
	box(
		model,
		Vector3.new(-0.75, height * 0.45, -0.75),
		Vector3.new(0.5, height * 0.7, 0.5),
		AMBER_LIGHT,
		Enum.Material.Neon,
		at
	)
end

-- Racimo de cristales que salen en abanico de una piedra de basalto: 3, 5 o 7 según la cantidad.
function RewardModels.amber(amount: number): Model
	local model = newModel("Ambar")
	box(model, Vector3.new(0, 0.6, 0), Vector3.new(9, 1.2, 7), BASALT, Enum.Material.Slate)
	box(model, Vector3.new(0.5, 1.4, 0.4), Vector3.new(6, 0.6, 5), BASALT, Enum.Material.Slate)
	local count = if amount <= 75 then 3 elseif amount <= 150 then 5 else 7
	-- Ángulo alrededor del centro (grados), distancia en celdas, alto e inclinación hacia fuera.
	local spots = {
		{ around = 0, out = 0, h = 7, lean = 0 },
		{ around = 200, out = 2, h = 5, lean = 24 },
		{ around = 340, out = 2, h = 5.5, lean = 22 },
		{ around = 110, out = 2.4, h = 4, lean = 30 },
		{ around = 270, out = 2.4, h = 3.5, lean = 34 },
		{ around = 160, out = 3.2, h = 2.5, lean = 45 },
		{ around = 30, out = 3.2, h = 3, lean = 40 },
	}
	for index = 1, count do
		local spot = spots[index]
		local angle = math.rad(spot.around)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- Gira en vertical hacia "direction" (eje horizontal perpendicular) y un poco sobre sí mismo.
		local axis = Vector3.new(-direction.Z, 0, direction.X)
		local at = CFrame.new(direction * spot.out * UNIT + Vector3.new(0, 1.4 * UNIT, 0))
			* CFrame.fromAxisAngle(if spot.lean > 0 then axis else Vector3.yAxis, -math.rad(spot.lean))
			* CFrame.Angles(0, math.rad(index * 23), 0)
		crystal(model, at, spot.h)
	end
	return model
end

-- Reloj de arena (tiempo para el huevo del nido), junto a un huevo.
function RewardModels.eggTime(): Model
	local model = newModel("TiempoDeHuevo")
	local egg = EggModel.build("Rare")
	egg:ScaleTo(0.55)
	egg:PivotTo(CFrame.new(-0.85, 0.95, 0.2))
	for _, child in egg:GetChildren() do
		child.Parent = model
	end
	egg:Destroy()
	local at = CFrame.new(1.1, 0, -0.2) * CFrame.Angles(0, math.rad(-20), 0)
	for _, y in { 0.5, 9.5 } do
		box(model, Vector3.new(0, y, 0), Vector3.new(6, 1, 6), WOOD, Enum.Material.Wood, at)
	end
	for _, x in { -2.5, 2.5 } do
		for _, z in { -2.5, 2.5 } do
			box(model, Vector3.new(x, 5, z), Vector3.new(0.8, 8, 0.8), LIGHT_WOOD, Enum.Material.Wood, at)
		end
	end
	local glassTop = box(model, Vector3.new(0, 7.2, 0), Vector3.new(3.6, 3.6, 3.6), GLASS, Enum.Material.Glass, at)
	glassTop.Transparency = 0.55
	local glassBottom = box(model, Vector3.new(0, 2.8, 0), Vector3.new(3.6, 3.6, 3.6), GLASS, Enum.Material.Glass, at)
	glassBottom.Transparency = 0.55
	box(model, Vector3.new(0, 5, 0), Vector3.new(1, 1, 1), GLASS, Enum.Material.Glass, at).Transparency = 0.4
	-- Arena: casi toda abajo, un poco arriba y el hilo que cae.
	box(model, Vector3.new(0, 1.9, 0), Vector3.new(3, 1.8, 3), SAND, Enum.Material.Sand, at)
	box(model, Vector3.new(0, 6.1, 0), Vector3.new(2, 1, 2), SAND, Enum.Material.Sand, at)
	box(model, Vector3.new(0, 4.2, 0), Vector3.new(0.3, 2.4, 0.3), SAND, nil, at)
	return model
end

function RewardModels.egg(rarity: string): Model
	local model = EggModel.build(rarity)
	model:PivotTo(CFrame.new(0, EggModel.HALF_HEIGHT, 0))
	return model
end

-- Banano curvo: tramos que suben en arco, con la sombra por debajo y las puntas pardas.
local function banana(model: Model, at: CFrame)
	local steps = {
		{ x = -4, y = 4.2, angle = 52 },
		{ x = -2.6, y = 2.4, angle = 30 },
		{ x = -0.9, y = 1.5, angle = 10 },
		{ x = 0.9, y = 1.5, angle = -10 },
		{ x = 2.6, y = 2.4, angle = -30 },
		{ x = 4, y = 4.2, angle = -52 },
	}
	for _, step in steps do
		local piece = at * CFrame.new(step.x * UNIT, step.y * UNIT, 0) * CFrame.Angles(0, 0, math.rad(step.angle))
		box(model, Vector3.zero, Vector3.new(2.2, 2, 2), BANANA, nil, piece)
		box(model, Vector3.new(0, -0.8, 0), Vector3.new(2.2, 0.6, 1.6), BANANA_SHADE, nil, piece)
	end
	local tipAt = at * CFrame.new(-5 * UNIT, 5.6 * UNIT, 0) * CFrame.Angles(0, 0, math.rad(60))
	box(model, Vector3.zero, Vector3.new(1, 1.4, 1), STEM, nil, tipAt)
	local endAt = at * CFrame.new(4.9 * UNIT, 5.4 * UNIT, 0) * CFrame.Angles(0, 0, math.rad(-60))
	box(model, Vector3.zero, Vector3.new(0.8, 0.8, 0.8), STEM, nil, endAt)
end

-- Rollo de venda: octógono de cajas con la tela en vueltas (anillos algo más oscuros), el hueco del
-- centro, la cinta que cuelga y una cruz roja en el canto. "band": la super venda lleva una faja roja.
local function roll(model: Model, at: CFrame, band: boolean)
	box(model, Vector3.new(0, 3, 0), Vector3.new(6, 4, 4), CLOTH, nil, at)
	box(model, Vector3.new(0, 3, 0), Vector3.new(4, 6, 4), CLOTH, nil, at)
	box(model, Vector3.new(0, 3, -2.02), Vector3.new(3.2, 3.2, 0.1), CLOTH_SHADE, nil, at)
	box(model, Vector3.new(0, 3, -2.06), Vector3.new(2.4, 2.4, 0.1), CLOTH, nil, at)
	box(model, Vector3.new(0, 3, -2.1), Vector3.new(1.2, 1.2, 0.1), HOLE, nil, at)
	box(model, Vector3.new(2.4, 0.6, -0.9), Vector3.new(2.6, 0.3, 2), CLOTH_SHADE, nil, at)
	box(model, Vector3.new(0, 6.05, 0), Vector3.new(0.6, 0.1, 2.4), CROSS_RED, nil, at)
	box(model, Vector3.new(0, 6.05, 0), Vector3.new(2.4, 0.1, 0.6), CROSS_RED, nil, at)
	if band then
		box(model, Vector3.new(0, 3, 0.9), Vector3.new(6.2, 4.2, 1), CROSS_RED, nil, at)
		box(model, Vector3.new(0, 3, 0.9), Vector3.new(4.2, 6.2, 1), CROSS_RED, nil, at)
		box(model, Vector3.new(0, 6.25, 0.9), Vector3.new(1.4, 0.4, 1.2), READY_GOLD, nil, at)
	end
end

-- Frasco del antídoto: panza redondeada en escalones (cristal con el líquido verde dentro), cuello,
-- corcho y una etiqueta con la cruz.
local function flask(model: Model, at: CFrame)
	box(model, Vector3.new(0, 2.4, 0), Vector3.new(3.4, 2.6, 3.4), POTION, nil, at)
	box(model, Vector3.new(0, 2.4, 0), Vector3.new(2.4, 3.4, 2.4), POTION, nil, at)
	for _, size in
		{
			Vector3.new(4.4, 3.4, 4.4),
			Vector3.new(3.4, 4.6, 3.4),
			Vector3.new(4.4, 2.2, 2.2),
			Vector3.new(2.2, 2.2, 4.4),
		}
	do
		local glass = box(model, Vector3.new(0, 2.6, 0), size, GLASS, Enum.Material.Glass, at)
		glass.Transparency = 0.6
	end
	local neck = box(model, Vector3.new(0, 5.4, 0), Vector3.new(1.6, 1.6, 1.6), GLASS, Enum.Material.Glass, at)
	neck.Transparency = 0.45
	box(model, Vector3.new(0, 6.7, 0), Vector3.new(1.4, 1.2, 1.4), CORK, Enum.Material.Wood, at)
	box(model, Vector3.new(0, 2.5, -2.25), Vector3.new(2.4, 1.8, 0.1), WHITE, nil, at)
	box(model, Vector3.new(0, 2.5, -2.32), Vector3.new(1.4, 0.4, 0.06), CROSS_RED, nil, at)
	box(model, Vector3.new(0, 2.5, -2.32), Vector3.new(0.4, 1.4, 0.06), CROSS_RED, nil, at)
end

-- Antorcha: mango de madera, cuerda en la cabeza y la llama en tres colores.
local function torch(model: Model, at: CFrame)
	local tilt = at * CFrame.Angles(0, 0, math.rad(-12))
	box(model, Vector3.new(0, 4, 0), Vector3.new(1.2, 8, 1.2), WOOD, Enum.Material.Wood, tilt)
	box(model, Vector3.new(0, 8.4, 0), Vector3.new(2.2, 2, 2.2), FIBER, Enum.Material.Fabric, tilt)
	box(model, Vector3.new(0, 10, 0), Vector3.new(2.4, 1.6, 2.4), FLAME_RED, Enum.Material.Neon, tilt)
	box(model, Vector3.new(0, 11.4, 0), Vector3.new(1.8, 1.8, 1.8), FLAME_ORANGE, Enum.Material.Neon, tilt)
	box(model, Vector3.new(0.2, 12.8, 0), Vector3.new(1, 1.4, 1), FLAME_YELLOW, Enum.Material.Neon, tilt)
end

-- Kit de reanimación: maletín rojo con tapa más oscura, cruz blanca, cierres y asa.
local function kit(model: Model, at: CFrame)
	box(model, Vector3.new(0, 2.5, 0), Vector3.new(8, 5, 5), KIT_RED, nil, at)
	box(model, Vector3.new(0, 4.6, 0), Vector3.new(8.2, 0.8, 5.2), KIT_DARK, nil, at)
	box(model, Vector3.new(0, 2.4, -2.55), Vector3.new(3.4, 1, 0.2), WHITE, nil, at)
	box(model, Vector3.new(0, 2.4, -2.55), Vector3.new(1, 3.4, 0.2), WHITE, nil, at)
	for side = -1, 1, 2 do
		box(model, Vector3.new(side * 3, 4.1, -2.6), Vector3.new(0.8, 0.8, 0.2), IRON, Enum.Material.Metal, at)
		box(model, Vector3.new(side * 1.4, 5.6, 0), Vector3.new(0.6, 1.4, 0.6), IRON, Enum.Material.Metal, at)
	end
	box(model, Vector3.new(0, 6.3, 0), Vector3.new(3.4, 0.6, 0.6), IRON, Enum.Material.Metal, at)
end

type ItemBuilder = (model: Model, at: CFrame) -> ()
local ITEMS: { [string]: ItemBuilder } = {
	Banana = banana,
	Bandage = function(model, at)
		roll(model, at, false)
	end,
	SuperBandage = function(model, at)
		roll(model, at, true)
		roll(model, at * CFrame.new(-0.9, 1.5, 0.6) * CFrame.Angles(0, math.rad(35), 0), false)
	end,
	Antidote = flask,
	Torch = torch,
	ReviveKit = kit,
}

-- ¿Tiene imagen este ítem? (los que no, salen en la tarjeta solo con su nombre).
function RewardModels.hasItem(itemId: string): boolean
	return ITEMS[itemId] ~= nil
end

-- Provisiones: hasta dos ítems uno junto al otro (los de "items" con imagen, en el orden dado).
function RewardModels.items(itemIds: { string }): Model
	local model = newModel("Provisiones")
	local shown = {}
	for _, itemId in itemIds do
		if ITEMS[itemId] and #shown < 2 then
			table.insert(shown, itemId)
		end
	end
	for index, itemId in shown do
		local x = if #shown == 1 then 0 else (index - 1.5) * 2.6
		ITEMS[itemId](model, CFrame.new(x, 0, (index - 1) * 0.6) * CFrame.Angles(0, math.rad(-15 + index * 10), 0))
	end
	return model
end

-- Modelo del premio (lo más valioso: cosmético > huevo > Ámbar > tiempo de huevo > provisiones).
-- Los cosméticos los hace RewardModels.avatar con el personaje del jugador: aquí devuelven nil.
function RewardModels.forReward(reward: { [string]: any }): Model?
	if reward.cosmetic then
		return nil
	elseif reward.egg then
		local best, bestWeight = "Rare", -1
		for rarity, weight in reward.egg do
			if weight > bestWeight then
				best, bestWeight = rarity, weight
			end
		end
		return RewardModels.egg(best)
	elseif reward.amber then
		return RewardModels.amber(reward.amber)
	elseif reward.eggSeconds then
		return RewardModels.eggTime()
	elseif reward.items then
		local ids = {}
		for itemId in reward.items do
			table.insert(ids, itemId)
		end
		table.sort(ids)
		return RewardModels.items(ids)
	end
	return nil
end

-- Texto voxel ("text", con GLYPHS) en el plano XY mirando a -Z, con el borde detrás: cada celda lleva
-- detrás un cubo más grande del color "edge", que juntos hacen la silueta. "colors" tiñe por filas de
-- arriba abajo (arriba, en medio, abajo, con mezclas entre ellas).
local function voxelText(model: Model, text: string, colors: { Color3 }, edge: Color3, cell: number, at: CFrame)
	local width = 0
	for index = 1, #text do
		width += #GLYPHS[string.sub(text, index, index)][1] + 1
	end
	local rowColors = {
		colors[1],
		colors[1]:Lerp(colors[2], 0.5),
		colors[2],
		colors[2]:Lerp(colors[3], 0.5),
		colors[3],
	}
	local x = -(width - 1) / 2
	for index = 1, #text do
		local glyph = GLYPHS[string.sub(text, index, index)]
		for row, line in glyph do
			for column = 1, #line do
				if string.sub(line, column, column) == "1" then
					-- Se mira desde -Z: la derecha de la pantalla es -X.
					local center = Vector3.new(-(x + column - 1), 3 - row, 0)
					local cframe = at * CFrame.new(center * cell)
					box(model, Vector3.zero, Vector3.one * cell / UNIT, rowColors[row], nil, cframe)
					box(model, Vector3.new(0, 0, 0.3 * cell / UNIT), Vector3.one * 1.5 * cell / UNIT, edge, nil, cframe)
				end
			end
		end
		x += #glyph[1] + 1
	end
end

-- Estilo de los números: un "99" voxel con los colores y el borde del estilo, algo torcido.
function RewardModels.numberStyle(cosmeticId: string): Model?
	local style = NumberStyles[cosmeticId]
	if not style then
		return nil
	end
	local model = newModel("EstiloDeNumeros")
	voxelText(model, "99", style.colors, style.edge, 0.45, CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-6)))
	model.WorldPivot = CFrame.identity
	return model
end

-- Estilo de los estallidos: la estrella de cómic del crítico con sus colores (estrella de fondo de
-- doce puntas, la de encima, rayos detrás y dos nubecitas) y un "!" voxel con su borde delante.
function RewardModels.burstStyle(cosmeticId: string): Model?
	if not ComicBurst.hasStyle(cosmeticId) then
		return nil
	end
	local colors = ComicBurst.palette("Crit", cosmeticId)
	local model = newModel("EstiloDeEstallido")
	local at = CFrame.new(0, 2.2, 0)
	local spin = function(degrees: number, z: number): CFrame
		return at * CFrame.new(0, 0, z) * CFrame.Angles(0, 0, math.rad(degrees))
	end
	for index = 0, 7 do
		local ray = box(
			model,
			Vector3.zero,
			Vector3.new(0.35, 22, 0.2),
			colors.rays,
			Enum.Material.Neon,
			spin(index * 45 + 22, 0.5)
		)
		ray.Transparency = 0.3
	end
	-- Una estrella de "points" puntas de "length" celdas: cada punta en tres tramos que se afinan.
	local function star(points: number, length: number, color: Color3, z: number, turn: number)
		box(model, Vector3.zero, Vector3.new(length * 0.95, length * 0.95, 0.4), color, nil, spin(turn, z))
		box(model, Vector3.zero, Vector3.new(length * 0.95, length * 0.95, 0.4), color, nil, spin(turn + 45, z))
		for index = 0, points - 1 do
			local angle = turn + index * 360 / points
			for step, piece in { { 0.62, 0.55, 0.5 }, { 0.92, 0.36, 0.32 }, { 1.16, 0.18, 0.18 } } do
				local place = spin(angle, z - step * 0.01) * CFrame.new(0, piece[1] * length * UNIT, 0)
				box(model, Vector3.zero, Vector3.new(length * piece[2], length * piece[3], 0.4), color, nil, place)
			end
		end
	end
	star(12, 7, colors.outer, 0.2, 0)
	star(8, 4.6, colors.inner, 0, 22)
	for _, spot in { Vector3.new(-1.9, 1.5, -0.3), Vector3.new(1.8, -1.6, -0.3) } do
		box(model, Vector3.zero, Vector3.new(2.2, 1.6, 0.6), colors.puff, nil, at * CFrame.new(spot))
		box(model, Vector3.new(0.5, 0.5, 0), Vector3.new(1.4, 1.4, 0.6), colors.puff, nil, at * CFrame.new(spot))
	end
	box(
		model,
		Vector3.zero,
		Vector3.new(1.2, 1.2, 0.4),
		colors.star,
		Enum.Material.Neon,
		at * CFrame.new(1.7, 1.6, -0.25)
	)
	voxelText(
		model,
		"!",
		{ colors.text, colors.text, colors.text:Lerp(colors.edge, 0.2) },
		colors.edge,
		0.36,
		at * CFrame.new(0, 0.1, -0.45) * CFrame.Angles(0, 0, math.rad(-8))
	)
	model.WorldPivot = CFrame.identity
	return model
end

-- Decoración del nido: la decoración alrededor de un nido de ramitas pequeño con un huevo dentro.
function RewardModels.nestDecor(cosmeticId: string): Model?
	local radius = 2.4
	local decor = NestDecor.build(cosmeticId, radius)
	if not decor then
		return nil
	end
	local model = newModel("DecoracionDelNido")
	box(model, Vector3.new(0, 0.6, 0), Vector3.new(14, 1.2, 14), STRAW, Enum.Material.Fabric)
	box(
		model,
		Vector3.new(0, 0.6, 0),
		Vector3.new(14, 1.2, 14),
		STRAW,
		Enum.Material.Fabric,
		CFrame.Angles(0, math.rad(45), 0)
	)
	for layer = 0, 1 do
		for index = 1, 12 do
			local angle = (index + layer * 0.5) * math.pi * 2 / 12
			local at = CFrame.new(
				math.cos(angle) * radius * 0.85,
				(0.35 + layer * 0.42),
				math.sin(angle) * radius * 0.85
			) * CFrame.Angles(0, -angle, 0)
			box(
				model,
				Vector3.zero,
				Vector3.new(1.8, 1.8, 5.2),
				if index % 2 == 0 then WOOD else LIGHT_WOOD,
				Enum.Material.Wood,
				at
			)
		end
	end
	local egg = EggModel.build("Rare")
	egg:ScaleTo(0.8)
	egg:PivotTo(CFrame.new(0, 0.6 + EggModel.HALF_HEIGHT * 0.8, 0))
	for _, child in egg:GetChildren() do
		child.Parent = model
	end
	egg:Destroy()
	for _, child in decor:GetChildren() do
		child.Parent = model
	end
	decor:Destroy()
	model.WorldPivot = CFrame.identity
	return model
end

-- Skin de mascota: la mascota de la skin (o la primera de su familia) con la skin puesta.
function RewardModels.petSkin(cosmeticId: string): Model?
	local cosmetic = Cosmetics[cosmeticId]
	if not cosmetic then
		return nil
	end
	local petId = cosmetic.petId
	if not petId then
		local candidates = {}
		for id in Pets do
			if CosmeticSlots.fitsPet(cosmetic, id) then
				table.insert(candidates, id)
			end
		end
		table.sort(candidates)
		petId = candidates[1]
	end
	local model = if petId then PetModels.build(petId, cosmeticId) else nil
	if model then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	end
	return model
end

-- La imagen de un cosmético: los que no se llevan encima (números, estallidos, nido, mascota) tienen
-- su modelo; los demás, tu avatar con él puesto (RewardModels.avatar).
function RewardModels.cosmetic(character: Model?, cosmeticId: string): Model?
	local cosmetic = Cosmetics[cosmeticId]
	local kind = if cosmetic then cosmetic.kind else nil
	if kind == "NumberStyle" then
		return RewardModels.numberStyle(cosmeticId)
	elseif kind == "BurstStyle" then
		return RewardModels.burstStyle(cosmeticId)
	elseif kind == "NestDecor" then
		return RewardModels.nestDecor(cosmeticId)
	elseif kind == "PetSkin" then
		return RewardModels.petSkin(cosmeticId)
	end
	return RewardModels.avatar(character, cosmeticId)
end

-- Tu avatar en miniatura con el cosmético "cosmeticIds" puesto (uno o varios, como la estela y el aura
-- a la vez en el Armario): estela (cinta de bloques de neón que se desvanece detrás) o aura (anillo de
-- bloques brillantes alrededor). Sin personaje, nil.
function RewardModels.avatar(character: Model?, cosmeticIds: string | { string }): Model?
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	if not clone then
		return nil
	end
	for _, descendant in clone:GetDescendants() do
		if
			descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("Tool")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Sound")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- De pie en el origen, mirando a -Z.
	local _, size = clone:GetBoundingBox()
	clone:PivotTo(CFrame.new(0, size.Y / 2, 0))
	for _, cosmeticId in if typeof(cosmeticIds) == "table" then cosmeticIds else { cosmeticIds } do
		local cosmetic = Cosmetics[cosmeticId]
		if cosmetic and cosmetic.kind == "Trail" then
			-- Cinta que sale de la espalda hacia atrás y a un lado, cada vez más transparente.
			for step = 1, 7 do
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = false
				part.Material = Enum.Material.Neon
				part.Color = cosmetic.color
				part.Transparency = 0.1 + step * 0.11
				part.Size = Vector3.new(0.35, 2.2 - step * 0.15, 0.7)
				part.CFrame = CFrame.new(step * 0.38, size.Y * 0.45 + math.sin(step * 0.9) * 0.25, 0.9 + step * 0.55)
				part.Parent = clone
			end
		elseif cosmetic and cosmetic.kind == "Aura" then
			-- Más bloques en cada grado; desde el II, lenguas de fuego a los pies; en el III, un halo de
			-- brasas sobre la cabeza.
			local grade = cosmetic.grade or 1
			if grade >= 2 then
				for index = 1, 10 do
					local angle = (index + 0.5) / 10 * math.pi * 2
					local tall = 0.7 + (index % 3) * 0.35 + (grade - 2) * 0.3
					local part = Instance.new("Part")
					part.Anchored = true
					part.CanCollide = false
					part.Material = Enum.Material.Neon
					part.Color = cosmetic.color:Lerp(FLAME_YELLOW, (index % 2) * 0.45)
					part.Size = Vector3.new(0.32, tall, 0.32)
					part.CFrame = CFrame.new(math.cos(angle) * 1.25, tall / 2, math.sin(angle) * 1.05)
						* CFrame.Angles(0, angle, math.rad(8))
					part.Parent = clone
				end
			end
			if grade >= 3 then
				for index = 1, 12 do
					local angle = index / 12 * math.pi * 2
					local part = Instance.new("Part")
					part.Anchored = true
					part.CanCollide = false
					part.Material = Enum.Material.Neon
					part.Color = if index % 3 == 0 then FLAME_YELLOW else cosmetic.color
					part.Size = Vector3.one * (0.2 + (index % 2) * 0.1)
					part.CFrame = CFrame.new(
						math.cos(angle) * 0.9,
						size.Y + 0.35 + (index % 2) * 0.15,
						math.sin(angle) * 0.9
					) * CFrame.Angles(angle, angle, 0)
					part.Parent = clone
				end
			end
			local count = 14 + (grade - 1) * 6
			for index = 1, count do
				local angle = index / count * math.pi * 2
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = false
				part.Material = Enum.Material.Neon
				part.Color = cosmetic.color
				local cube = 0.25 + (index % 3) * 0.1
				part.Size = Vector3.one * cube
				part.CFrame = CFrame.new(
					math.cos(angle) * 1.9,
					0.6 + (index % 5) * size.Y * 0.18,
					math.sin(angle) * 1.6
				) * CFrame.Angles(angle, angle * 2, 0)
				part.Parent = clone
			end
		end
	end
	return clone
end

-- Mete el modelo en el ViewportFrame, con la cámara en 3/4 desde delante y algo desde arriba, a la
-- distancia justa para que quepa entero ("fill" > 1 lo acerca: la esfera que lo envuelve es más grande
-- que lo que se ve), y una luz cálida. Devuelve el modelo (para girarlo).
function RewardModels.frame(viewport: ViewportFrame, model: Model, fill: number?): Model
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	model.Parent = viewport
	local cframe, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) / (fill or 1.3)
	local direction = Vector3.new(0.55, 0.38, -1).Unit
	camera.CFrame = CFrame.lookAt(cframe.Position + direction * distance, cframe.Position)
	viewport.Ambient = Color3.fromRGB(205, 190, 180)
	viewport.LightColor = Color3.fromRGB(255, 240, 220)
	viewport.LightDirection = Vector3.new(-0.5, -1, 0.6)
	return model
end

return RewardModels
