--!strict
-- Cartel de las mascotas en el borde de la plaza (etiqueta Config.Lobby.PetsBoardTag, lo pone
-- World/LobbyBuilder a la izquierda de la bitácora). Cada cliente lo dibuja con lo suyo: a la
-- izquierda el huevo de su nido (rareza, lo que le falta, la barra de incubación y qué puede salir);
-- a la derecha la mochila de huevos, los pendientes y la mascota que le acompaña. No tiene aviso: se
-- interactúa con el nido que tiene delante ("NidoPrompt", LobbyUIController abre la ventana). Todo va
-- en la parte de arriba (CONTENT_HEIGHT): el huevo del nido tapa la franja de abajo vista desde la
-- plaza.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local TRACK_COLOR = Color3.fromRGB(25, 20, 15)
-- Cian = huevo (como su línea de estado en la Isla y la barra de la ventana del nido).
local EGG_BAR_COLOR = Color3.fromRGB(150, 240, 255)
local GOLD = Color3.fromRGB(255, 215, 90)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local WARNING = Color3.fromRGB(255, 170, 60)
local EMPTY_SLOT = Color3.fromRGB(90, 80, 70)
-- Parte del alto del cartel que ocupa el contenido, desde arriba.
local CONTENT_HEIGHT = 0.72

local PetBoardController = {}

type Board = {
	gui: SurfaceGui,
	eggTitle: TextLabel,
	eggTime: TextLabel,
	fill: Frame,
	track: Frame,
	options: TextLabel,
	slots: { TextLabel },
	pending: TextLabel,
	companion: TextLabel,
}

local function text(value: string, parent: Instance, position: UDim2, size: UDim2, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = value
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = parent
	return label
end

local function card(parent: Instance, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = CARD_COLOR
	frame.BackgroundTransparency = 0.1
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.06, 0)
	corner.Parent = frame
	return frame
end

function PetBoardController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local boards: { [BasePart]: Board } = {}

	local function readEggs(): EggIncubation.EggData
		local raw = player:GetAttribute("Eggs")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		return EggIncubation.normalize(if ok then decoded else nil)
	end

	local function build(part: BasePart): Board
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TablaMascotas"
		gui.Adornee = part
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0 -- siempre legible, también de noche
		gui.ResetOnSpawn = false
		gui.Parent = playerGui

		-- Izquierda: el huevo del nido.
		local egg = card(gui, UDim2.fromScale(0.025, 0.04), UDim2.fromScale(0.58, CONTENT_HEIGHT))
		local eggTitle =
			text("", egg, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.2), Enum.Font.BuilderSansBold)
		local eggTime =
			text("", egg, UDim2.fromScale(0.05, 0.26), UDim2.fromScale(0.9, 0.22), Enum.Font.BuilderSansExtraBold)
		local track = Instance.new("Frame")
		track.Position = UDim2.fromScale(0.06, 0.52)
		track.Size = UDim2.fromScale(0.88, 0.07)
		track.BackgroundColor3 = TRACK_COLOR
		track.Parent = egg
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0.5, 0)
		trackCorner.Parent = track
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = EGG_BAR_COLOR
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
		local options = text("", egg, UDim2.fromScale(0.05, 0.64), UDim2.fromScale(0.9, 0.32), Enum.Font.BuilderSans)
		options.TextWrapped = true
		options.TextColor3 = SECONDARY

		-- Derecha: la mochila, los pendientes y la mascota que te acompaña.
		local side = card(gui, UDim2.fromScale(0.625, 0.04), UDim2.fromScale(0.35, CONTENT_HEIGHT))
		local bagTitle = text(
			"🎒 Mochila",
			side,
			UDim2.fromScale(0.06, 0.04),
			UDim2.fromScale(0.88, 0.17),
			Enum.Font.BuilderSansBold
		)
		bagTitle.TextColor3 = GOLD
		local slots = {}
		for index = 1, Config.Egg.BagSize do
			local slot = text(
				"",
				side,
				UDim2.fromScale(0.06 + (index - 1) * (0.88 / Config.Egg.BagSize), 0.23),
				UDim2.fromScale(0.88 / Config.Egg.BagSize - 0.03, 0.22),
				Enum.Font.BuilderSansBold
			)
			slot.BackgroundTransparency = 0.2
			local slotCorner = Instance.new("UICorner")
			slotCorner.CornerRadius = UDim.new(0.25, 0)
			slotCorner.Parent = slot
			slots[index] = slot
		end
		local pending =
			text("", side, UDim2.fromScale(0.06, 0.48), UDim2.fromScale(0.88, 0.14), Enum.Font.BuilderSansBold)
		pending.TextColor3 = WARNING
		local companion =
			text("", side, UDim2.fromScale(0.06, 0.64), UDim2.fromScale(0.88, 0.32), Enum.Font.BuilderSans)
		companion.TextWrapped = true
		companion.TextColor3 = SECONDARY

		return {
			gui = gui,
			eggTitle = eggTitle,
			eggTime = eggTime,
			fill = fill,
			track = track,
			options = options,
			slots = slots,
			pending = pending,
			companion = companion,
		}
	end

	local function draw(board: Board)
		local eggs = readEggs()
		-- Con dos huecos (incubadora III de la parcela), el cartel enseña el primero y resume el otro.
		local nestEgg = eggs.nest or eggs.nest2
		local other = if eggs.nest then eggs.nest2 else nil
		local now = EggIncubation.now()
		if nestEgg then
			local rarity = Rarities[nestEgg.rarity]
			local ready = EggIncubation.isReady(nestEgg, now)
			board.eggTitle.Text = if other
				then `🥚 Huevo {rarity.name} · 2.º: {Rarities[other.rarity].name}, {if EggIncubation.isReady(
						other,
						now
					)
					then "listo"
					else EggIncubation.formatTime(EggIncubation.remaining(other, now))}`
				else `🥚 Huevo {rarity.name}`
			board.eggTitle.TextColor3 = rarity.color
			board.eggTime.Text = if ready
				then "🐣 ¡Listo para abrir!"
				else `⏳ {EggIncubation.formatTime(EggIncubation.remaining(nestEgg, now))}`
			board.eggTime.TextColor3 = if ready then READY_COLOR else Color3.new(1, 1, 1)
			board.track.Visible = true
			board.fill.Size = UDim2.fromScale(math.clamp(EggIncubation.progress(nestEgg, now), 0, 1), 1)
			-- Qué puede salir (con ✅ las que ya tienes).
			local data = Progression.read(player)
			local names = {}
			for _, petId in PetRoll.petsOfRarity(nestEgg.rarity) do
				local pet = Pets[petId]
				local owned = (data.pets[petId] or 0) > 0
				table.insert(names, `{pet.icon} {pet.name}{if owned then " ✅" else ""}`)
			end
			-- Y sus monturas (Fase 11), mientras no las tengas.
			for _, mountId in PetRoll.mountsOfRarity(nestEgg.rarity) do
				local mount = Mounts[mountId]
				local owned = (data.mounts[mountId] or 0) > 0
				table.insert(names, `{mount.icon} {mount.name} (montura){if owned then " ✅" else ""}`)
			end
			board.options.Text = `Puede salir: {table.concat(names, " · ")}`
		else
			local stored = #eggs.bag + #eggs.pending
			board.eggTitle.Text = "🥚 Nido vacío"
			board.eggTitle.TextColor3 = Color3.new(1, 1, 1)
			board.eggTime.Text = if stored > 0 then "Pon un huevo a incubar" else "Sin huevos"
			board.eggTime.TextColor3 = if stored > 0 then READY_COLOR else SECONDARY
			board.track.Visible = false
			board.options.Text = if stored > 0
				then "Acércate al nido y presiona E"
				else `Defiende huevos en la {Config.PlaceNames.IslandShort} para conseguirlos`
		end

		for index, slot in board.slots do
			local stored = eggs.bag[index]
			if stored then
				local rarity = Rarities[stored.rarity]
				slot.Text = "🥚"
				slot.BackgroundColor3 = rarity.color
			else
				slot.Text = ""
				slot.BackgroundColor3 = EMPTY_SLOT
			end
		end
		board.pending.Text = if #eggs.pending > 0 then `⚠️ {#eggs.pending} esperando sitio` else ""

		local active = player:GetAttribute("ActivePet")
		local pet = if typeof(active) == "string" then Pets[active] else nil
		board.companion.Text = if pet
			then `🐾 Te acompaña:\n{pet.icon} {pet.name}`
			else "🐾 Ninguna mascota te acompaña"
	end

	local function add(instance: Instance)
		if not instance:IsA("BasePart") or boards[instance] then
			return
		end
		local board = build(instance)
		boards[instance] = board
		draw(board)
	end

	CollectionService:GetInstanceAddedSignal(Config.Lobby.PetsBoardTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Config.Lobby.PetsBoardTag):Connect(function(instance)
		local board = boards[instance :: BasePart]
		if board then
			board.gui:Destroy()
			boards[instance :: BasePart] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(Config.Lobby.PetsBoardTag) do
		add(instance)
	end

	local function redraw()
		for _, board in boards do
			draw(board)
		end
	end
	player.AttributeChanged:Connect(function(attribute)
		if attribute == "Eggs" or attribute == "ActivePet" or attribute == "Progress" then
			redraw()
		end
	end)
	-- El tiempo del huevo corre solo: cada segundo.
	task.spawn(function()
		while true do
			task.wait(1)
			redraw()
		end
	end)
end

return PetBoardController
