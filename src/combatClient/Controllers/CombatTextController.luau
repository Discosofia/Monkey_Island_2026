--!strict
-- Números flotantes de combate (lo que manda el servidor con Combat/CombatText):
--   - Lo que recibes tú: daño en rojo a la izquierda y curación en verde a la derecha. Dónde salen lo
--     elige el jugador en Ajustes (Shared/Settings):
--       "Head"   columnas cortas junto a la cabeza, del mismo tamaño en pantalla a cualquier distancia
--       "Column" columnas del alto del personaje, a cada lado del cuerpo
--       "Screen" columnas fijas en la pantalla, a izquierda y derecha del centro
--   - El daño que haces: amarillo, en una columna sobre la cabeza del enemigo; el de tu veneno, morado.
--   - Lo de tu mascota sale más pequeño (Config.CombatText.PetTextScale) y el daño de los aliados más
--     pequeño y tenue (si está activado y cerca). El médico ve, tenues, sus curaciones a los aliados.
--   - Los críticos salen un 25 % más grandes, con "!" y un temblor (UI/CombatTextColumn).
--   - La letra la elige el jugador (Settings.numberFont): de cómic (Bangers, como "POW!") o la clásica;
--     vale para los números y para lo recogido.
--   - El daño hecho (tuyo o de un aliado) sale con el estilo de número de quien lo hace (cosmético
--     NumberStyle, atributo "NumberStyle" del jugador): así los demás también ven el tuyo.
--   - Lo que recoges (Remotes.Loot): "+2 🌲 Madera" con el color de su rareza, en una columna a la
--     derecha justo debajo de la de curación (en las tres disposiciones). Lo mismo recogido seguido
--     suma en la misma línea (Config.CombatText.LootMergeSeconds). Lo que trae la mascota (el
--     labrador) va en su línea, con su icono al final: "+1 🦴 Hueso 🦮".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local CombatTextColumn = require(ReplicatedStorage.Shared.UI.CombatTextColumn)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local SETTINGS = Config.CombatText

local COLORS = {
	Taken = Color3.fromRGB(255, 70, 70),
	TakenCrit = Color3.fromRGB(255, 35, 35),
	Heal = Color3.fromRGB(90, 230, 110),
	HealCrit = Color3.fromRGB(50, 255, 110),
	Dealt = Color3.fromRGB(255, 220, 90),
	DealtCrit = Color3.fromRGB(255, 185, 30),
	Poison = Color3.fromRGB(190, 110, 255),
	Absorbed = Color3.fromRGB(200, 215, 230),
}
-- Tamaño en píxeles de una columna junto a una cabeza (antes de ajustarlo a la pantalla).
local HEAD_COLUMN = Vector2.new(110, 4 * 30)
-- Columna del alto del personaje (studs) y su separación del centro del cuerpo.
local BODY_COLUMN = Vector2.new(3, 5.4)
local BODY_SIDE_OFFSET = 2.6
-- Columna de lo recogido: ancho y alto de cada línea en píxeles (antes de ajustarlo a la pantalla).
local LOOT_WIDTH = 210
local LOOT_LINE = 26
-- Separación en píxeles entre la columna de curación y la de lo recogido, debajo.
local LOOT_GAP = 6
-- Las columnas de otros objetivos sin números se borran tras este tiempo.
local IDLE_SECONDS = 3
-- Como mucho tantas columnas sobre enemigos y aliados a la vez (se recicla la más vieja).
local MAX_COLUMNS = 24
-- Lo que tarda en desaparecer la columna de un enemigo derrotado (sus últimos números).
local DEFEATED_SECONDS = 1.2

-- Lados de las columnas propias: "Left" (daño recibido) y "Right" (curación).
local SIDES = { "Left", "Right" }
type WorldColumn = { gui: BillboardGui, column: CombatTextColumn.Column, lastUsed: number }

local CombatTextController = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui
-- Columnas propias (lo que recibes): una a cada lado, según la disposición elegida, y "Loot" (lo que
-- recoges) debajo de la de la derecha.
local ownColumns: { [string]: CombatTextColumn.Column } = {}
-- Lo último recogido, para sumar en la misma línea lo que llega seguido.
local lastLoot: { itemId: string, total: number, at: number }? = nil
local ownInstances: { Instance } = {}
-- Columnas sobre enemigos y aliados (siempre sobre su cabeza).
local worldColumns: { [Instance]: WorldColumn } = {}

-- Escala de la interfaz según el alto de la pantalla (móvil pequeño … monitor grande).
local function uiScale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	return math.clamp(height / 720, 0.85, 1.3)
end

local function headOf(model: Instance): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

local function billboard(name: string, adornee: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- La columna de la izquierda pega sus números a la derecha (junto al personaje) y al revés.
local function alignFor(side: string): CombatTextColumn.Align
	return if side == "Left" then "Right" else "Left"
end

local function frameIn(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = parent
	return frame
end

-- ===================================== Columnas propias =====================================

local function clearOwn()
	for _, column in ownColumns do
		column:destroy()
	end
	table.clear(ownColumns)
	for _, instance in ownInstances do
		instance:Destroy()
	end
	table.clear(ownInstances)
	lastLoot = nil
end

local function lootColumn(frame: GuiObject): CombatTextColumn.Column
	return CombatTextColumn.new(frame, "Left", {
		slots = SETTINGS.LootSlots,
		lifetime = SETTINGS.LootLifetimeSeconds,
	})
end

-- Tamaño en píxeles de la columna de lo recogido.
local function lootSize(scale: number): Vector2
	return Vector2.new(LOOT_WIDTH * scale, SETTINGS.LootSlots * LOOT_LINE * scale)
end

local function buildOwn()
	clearOwn()
	local character = player.Character
	local layout = Settings.get().textLayout
	if layout == "Screen" then
		local scale = uiScale()
		for _, side in SIDES do
			local frame = Instance.new("Frame")
			frame.Name = `CombatText{side}`
			frame.BackgroundTransparency = 1
			frame.AnchorPoint = Vector2.new(if side == "Left" then 1 else 0, 0.5)
			frame.Position = UDim2.fromScale(if side == "Left" then 0.44 else 0.56, 0.42)
			frame.Size = UDim2.fromOffset(150 * scale, 4 * 36 * scale)
			frame.Parent = screenGui
			table.insert(ownInstances, frame)
			ownColumns[side] = CombatTextColumn.new(frame, alignFor(side))
		end
		local size = lootSize(scale)
		local loot = Instance.new("Frame")
		loot.Name = "LootText"
		loot.BackgroundTransparency = 1
		loot.Position = UDim2.new(0.56, 0, 0.42, (4 * 36 / 2 + LOOT_GAP) * scale)
		loot.Size = UDim2.fromOffset(size.X, size.Y)
		loot.Parent = screenGui
		table.insert(ownInstances, loot)
		ownColumns.Loot = lootColumn(loot)
		return
	end
	if not character then
		return
	end
	if layout == "Column" then
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if not (root and root:IsA("BasePart")) then
			return
		end
		for _, side in SIDES do
			local gui = billboard(`CombatText{side}`, root)
			gui.Size = UDim2.fromScale(BODY_COLUMN.X, BODY_COLUMN.Y)
			gui.StudsOffset = Vector3.new(if side == "Left" then -BODY_SIDE_OFFSET else BODY_SIDE_OFFSET, -0.2, 0)
			table.insert(ownInstances, gui)
			ownColumns[side] = CombatTextColumn.new(frameIn(gui), alignFor(side))
		end
		-- Lo recogido, bajo el pie de la columna de curación, hacia fuera.
		local size = lootSize(uiScale())
		local loot = billboard("LootText", root)
		loot.Size = UDim2.fromOffset(size.X, size.Y)
		loot.StudsOffset = Vector3.new(BODY_SIDE_OFFSET - BODY_COLUMN.X / 2, -0.2 - BODY_COLUMN.Y / 2, 0)
		loot.SizeOffset = Vector2.new(0.5, -0.5 - LOOT_GAP / size.Y)
		table.insert(ownInstances, loot)
		ownColumns.Loot = lootColumn(frameIn(loot))
		return
	end
	-- "Head": columnas cortas con tamaño en píxeles, pegadas a cada lado de la cabeza.
	local head = character:WaitForChild("Head", 5)
	if not (head and head:IsA("BasePart")) then
		return
	end
	local scale = uiScale()
	for _, side in SIDES do
		local gui = billboard(`CombatText{side}`, head)
		gui.Size = UDim2.fromOffset(HEAD_COLUMN.X * scale, HEAD_COLUMN.Y * scale)
		gui.StudsOffset = Vector3.new(if side == "Left" then -1 else 1, 0, 0)
		-- Se desplaza medio tamaño hacia su lado y hacia arriba: el borde queda junto a la cabeza.
		gui.SizeOffset = Vector2.new(if side == "Left" then -0.5 else 0.5, 0.35)
		table.insert(ownInstances, gui)
		ownColumns[side] = CombatTextColumn.new(frameIn(gui), alignFor(side))
	end
	-- Lo recogido, justo debajo de la columna de curación (todo en píxeles: no se solapan a ninguna
	-- distancia). Esa columna baja 0.15 de su alto por debajo del centro de la cabeza.
	local size = lootSize(scale)
	local loot = billboard("LootText", head)
	loot.Size = UDim2.fromOffset(size.X, size.Y)
	loot.StudsOffset = Vector3.new(1, 0, 0)
	loot.SizeOffset = Vector2.new(0.5, (-0.15 * HEAD_COLUMN.Y * scale - LOOT_GAP * scale) / size.Y - 0.5)
	table.insert(ownInstances, loot)
	ownColumns.Loot = lootColumn(frameIn(loot))
end

-- ===================================== Columnas sobre otros =====================================

local function dropWorld(target: Instance)
	local entry = worldColumns[target]
	if entry then
		worldColumns[target] = nil
		entry.column:destroy()
		entry.gui:Destroy()
	end
end

local function worldColumn(target: Instance): CombatTextColumn.Column?
	local existing = worldColumns[target]
	if existing then
		existing.lastUsed = os.clock()
		return existing.column
	end
	local head = headOf(target)
	if not head then
		return nil
	end
	-- Demasiadas: se recicla la que lleva más tiempo sin usarse.
	local count, oldest, oldestTime = 0, nil :: Instance?, math.huge
	for other, entry in worldColumns do
		count += 1
		if entry.lastUsed < oldestTime then
			oldest, oldestTime = other, entry.lastUsed
		end
	end
	if count >= MAX_COLUMNS and oldest then
		dropWorld(oldest)
	end
	local scale = uiScale()
	local gui = billboard("CombatTextWorld", head)
	gui.Size = UDim2.fromOffset(HEAD_COLUMN.X * scale, HEAD_COLUMN.Y * scale)
	gui.StudsOffset = Vector3.new(0, head.Size.Y / 2 + 0.4, 0)
	gui.SizeOffset = Vector2.new(0, 0.5)
	local entry = { gui = gui, column = CombatTextColumn.new(frameIn(gui), "Center"), lastUsed = os.clock() }
	worldColumns[target] = entry
	-- Al desaparecer (¡puf!) se deja ver un momento el último número.
	target.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			task.delay(DEFEATED_SECONDS, dropWorld, target)
		end
	end)
	return entry.column
end

-- ===================================== Números =====================================

local function textOf(kind: string, amount: number): string
	if kind == "Absorbed" then
		return "🛡️"
	elseif kind == "Heal" then
		return `+{amount}`
	elseif kind == "Taken" then
		return `-{amount}`
	end
	return tostring(amount)
end

local function colorOf(kind: string, crit: boolean): Color3
	if kind == "Absorbed" then
		return COLORS.Absorbed
	end
	return (COLORS :: any)[if crit then `{kind}Crit` else kind]
end

-- El estilo de número de quien hace el daño (su UserId), si lleva uno.
local function skinOf(by: any): string?
	local attacker = if typeof(by) == "number" then Players:GetPlayerByUserId(by) else nil
	local skin = if attacker then attacker:GetAttribute("NumberStyle") else nil
	return if typeof(skin) == "string" and CombatTextColumn.hasStyle(skin) then skin else nil
end

local function nearMe(target: Instance): boolean
	local character = player.Character
	local head = headOf(target)
	if not (character and head) then
		return false
	end
	return (character:GetPivot().Position - head.Position).Magnitude <= SETTINGS.AllyMaxDistance
end

local function show(entry: any)
	if typeof(entry) ~= "table" then
		return
	end
	local target, amount, kind = entry.target, entry.amount, entry.kind
	if typeof(target) ~= "Instance" or typeof(amount) ~= "number" or typeof(kind) ~= "string" then
		return
	end
	local crit = entry.crit == true
	local pet = entry.pet == true
	local mine = entry.by == player.UserId
	local scale = if pet then SETTINGS.PetTextScale else 1
	local values = Settings.get()

	if target == player.Character then
		-- Lo que recibes tú: daño (y escudo) a la izquierda, curación a la derecha.
		local side = if kind == "Heal" then "Right" else "Left"
		local column = ownColumns[side]
		if column then
			column:push(textOf(kind, amount), { color = colorOf(kind, crit), crit = crit, scale = scale })
		end
		return
	end

	local victim = Players:GetPlayerFromCharacter(target)
	if victim then
		if mine and kind == "Taken" then
			-- PvP: tu golpe a otro jugador, como el daño a un enemigo.
			kind = "Dealt"
		elseif not (mine and kind == "Heal") then
			-- Lo que reciben los demás no se dibuja (no llenar la pantalla con 20 jugadores).
			return
		end
	elseif kind ~= "Dealt" and kind ~= "Poison" then
		return
	end

	local dim = 0
	if not mine then
		-- Daño de los aliados: más pequeño, tenue y solo cerca.
		if not values.allyNumbers or not nearMe(target) then
			return
		end
		scale *= SETTINGS.AllyTextScale
		dim = 0.5
	elseif kind == "Heal" then
		-- Tus curaciones a un aliado: tenues sobre su cabeza.
		scale *= SETTINGS.AllyTextScale
		dim = 0.35
	end
	local column = worldColumn(target)
	if column then
		column:push(textOf(kind, amount), {
			color = colorOf(kind, crit),
			skin = if kind == "Dealt" and not pet then skinOf(entry.by) else nil,
			crit = crit,
			scale = scale,
			dim = dim,
		})
	end
end

-- "+2 🌲 Madera" en la columna de lo recogido; lo mismo recogido seguido suma en la misma línea.
local function showLoot(itemId: any, amount: any, by: any)
	local item = if typeof(itemId) == "string" then Items[itemId] else nil
	local column = ownColumns.Loot
	if not (item and column and typeof(amount) == "number" and amount > 0) or not Settings.get().showLoot then
		return
	end
	local rarity = Rarities[item.rarity or "Common"] or Rarities.Common
	-- Lo que trae la mascota (el labrador), aparte y con su icono: así se ve que es suyo.
	if typeof(by) == "string" then
		lastLoot = nil
		column:push(`+{amount} {item.icon} {item.name} {by}`, { color = rarity.color })
		return
	end
	local now = os.clock()
	local total = amount
	if lastLoot and lastLoot.itemId == itemId and now - lastLoot.at <= SETTINGS.LootMergeSeconds then
		total += lastLoot.total
	end
	lastLoot = { itemId = itemId, total = total, at = now }
	column:push(`+{total} {item.icon} {item.name}`, { color = rarity.color, key = itemId })
end

function CombatTextController:Start()
	screenGui = Widgets.screen("CombatText", player:WaitForChild("PlayerGui"))
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = -1

	player.CharacterAdded:Connect(function()
		task.defer(buildOwn)
	end)
	local shownLayout = Settings.get().textLayout
	Settings.onChanged(function(values)
		if values.textLayout ~= shownLayout then
			shownLayout = values.textLayout
			buildOwn()
		end
	end)
	buildOwn()

	Remotes.CombatText.OnClientEvent:Connect(function(batch: any)
		if typeof(batch) ~= "table" or not Settings.get().showNumbers then
			return
		end
		for _, entry in batch do
			show(entry)
		end
	end)

	Remotes.Loot.OnClientEvent:Connect(showLoot)

	-- Limpieza de las columnas sobre otros que ya no se usan.
	while true do
		task.wait(1)
		local now = os.clock()
		for target, entry in worldColumns do
			if not target.Parent or (now - entry.lastUsed > IDLE_SECONDS and entry.column:isIdle()) then
				dropWorld(target)
			end
		end
	end
end

return CombatTextController
