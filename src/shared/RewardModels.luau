--!strict
-- Imágenes 3D de los premios (Fase 9): modelos voxel pequeños que se ven en las tarjetas del pase de
-- temporada (UI/SeasonPassPanel, dentro de un ViewportFrame), nunca en el mundo. Cajas alineadas a una
-- rejilla de UNIT studs, con 3–5 tonos planos, como los monos y las mascotas voxel.
--
--   RewardModels.forReward(reward)       -- el modelo de un premio (Data/Seasons, Config.Reward)
--   RewardModels.avatar(character, id)   -- tu avatar en miniatura con un cosmético puesto
--   RewardModels.frame(viewport, model)  -- lo mete en el ViewportFrame con su cámara y su luz
--
-- Todos salen de pie en el origen, con el frente hacia -Z. Los ViewportFrame no dibujan partículas,
-- estelas (Trail) ni BillboardGui: el aura y la estela se hacen con bloques de neón, y el título lo
-- pone la tarjeta como texto.

local Cosmetics = require(script.Parent.Data.Cosmetics)
local EggModel = require(script.Parent.EggModel)

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
			for index = 1, 14 do
				local angle = index / 14 * math.pi * 2
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
