--!strict
-- Cartel del Laboratorio en ruinas en el borde de la plaza (etiqueta Config.Lobby.LabBoardTag, lo pone
-- World/LobbyBuilder). Cada cliente lo dibuja con lo suyo: el modo, cuántos jugadores esperan en la cola
-- de cada formato (todos los servidores, "LabQueueCounts" de ArenaQueueService) y, abajo, si estás
-- buscando partida o "Presiona E". Su aviso ("LabPrompt") abre la ventana del Laboratorio
-- (LobbyUIController). Las victorias, las bajas y el ranking llegan con las recompensas (L5).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)

local T = Strings.t

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local GOLD = Color3.fromRGB(255, 215, 90)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local DARK_TEXT = Color3.fromRGB(40, 25, 5)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local QUEUE_COLOR = Color3.fromRGB(120, 230, 255)

local LabBoardController = {}

type Board = {
	gui: SurfaceGui,
	mode: TextLabel,
	hint: TextLabel,
	queueTitle: TextLabel,
	formats: { [number]: TextLabel },
	badge: TextLabel,
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

local function readJson(raw: any): { [string]: any }?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(decoded) == "table" then decoded else nil
end

function LabBoardController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local boards: { [BasePart]: Board } = {}
	local settings = Config.Lab

	local function build(part: BasePart): Board
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TablaLab"
		gui.Adornee = part
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0 -- siempre legible, también de noche
		gui.ResetOnSpawn = false
		gui.Parent = playerGui

		local panel = Instance.new("Frame")
		panel.Position = UDim2.fromScale(0.03, 0.05)
		panel.Size = UDim2.fromScale(0.94, 0.9)
		panel.BackgroundColor3 = CARD_COLOR
		panel.BackgroundTransparency = 0.1
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.05, 0)
		corner.Parent = panel

		local mode = text("", panel, UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.15), Enum.Font.BuilderSansBold)
		mode.TextColor3 = GOLD
		local hint = text("", panel, UDim2.fromScale(0.05, 0.18), UDim2.fromScale(0.9, 0.11), Enum.Font.BuilderSans)
		hint.TextColor3 = SECONDARY
		local queueTitle =
			text("", panel, UDim2.fromScale(0.05, 0.31), UDim2.fromScale(0.9, 0.11), Enum.Font.BuilderSansBold)
		queueTitle.TextColor3 = GOLD
		local formats: { [number]: TextLabel } = {}
		local count = settings.MaxFormat - settings.MinFormat + 1
		for format = settings.MinFormat, settings.MaxFormat do
			local index = format - settings.MinFormat
			local label = text(
				"",
				panel,
				UDim2.fromScale(0.05 + index * (0.9 / count), 0.44),
				UDim2.fromScale(0.9 / count - 0.015, 0.25),
				Enum.Font.BuilderSansBold
			)
			label.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
			label.BackgroundTransparency = 0.2
			local labelCorner = Instance.new("UICorner")
			labelCorner.CornerRadius = UDim.new(0.2, 0)
			labelCorner.Parent = label
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0.1, 0)
			padding.PaddingBottom = UDim.new(0.1, 0)
			padding.Parent = label
			formats[format] = label
		end
		local badge =
			text("", panel, UDim2.fromScale(0.15, 0.75), UDim2.fromScale(0.7, 0.18), Enum.Font.BuilderSansExtraBold)
		badge.BackgroundTransparency = 0
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0.3, 0)
		badgeCorner.Parent = badge
		local badgePadding = Instance.new("UIPadding")
		badgePadding.PaddingTop = UDim.new(0.12, 0)
		badgePadding.PaddingBottom = UDim.new(0.12, 0)
		badgePadding.Parent = badge

		return { gui = gui, mode = mode, hint = hint, formats = formats, badge = badge, queueTitle = queueTitle }
	end

	local function draw(board: Board)
		local queue = readJson(player:GetAttribute("ArenaQueue"))
		-- Solo la cola del Laboratorio; la de Dunas se ve en su cartel.
		if queue and queue.game ~= "Lab" then
			queue = nil
		end
		local modeId = if queue and typeof(queue.mode) == "string" then queue.mode else settings.Modes[1]
		board.mode.Text = T(settings.ModeNames[modeId] or settings.ModeNames[settings.Modes[1]])
		board.hint.Text = T("Todos empiezan igual: 4 armas, solo cuenta la puntería")
		board.queueTitle.Text = T("⚔️ En cola ahora")

		-- Jugadores en la cola de cada formato (de todos los servidores); "—" si aún no se sabe.
		local counts = readJson(ReplicatedStorage:GetAttribute("LabQueueCounts"))
		local byFormat = if counts and typeof(counts[modeId]) == "table" then counts[modeId] else nil
		local myFormat = if queue then tonumber(queue.format) else nil
		for format, label in board.formats do
			local waiting = if byFormat then tonumber(byFormat[tostring(format)]) else nil
			label.Text = `{format}v{format}\n{if waiting then waiting else "—"} 👤`
			local mine = format == myFormat
			label.TextColor3 = if mine then DARK_TEXT elseif (waiting or 0) > 0 then QUEUE_COLOR else Color3.new(1, 1, 1)
			label.BackgroundColor3 = if mine then READY_COLOR else Color3.fromRGB(25, 20, 15)
		end

		if queue then
			local waited = math.max(0, Workspace:GetServerTimeNow() - (tonumber(queue.since) or 0))
			board.badge.Text = T("⏳ Buscando {n}v{n} · {time}", {
				n = queue.format,
				time = `{math.floor(waited // 60)}:{string.format("%02d", math.floor(waited % 60))}`,
			})
			board.badge.BackgroundColor3 = CARD_COLOR
			board.badge.TextColor3 = READY_COLOR
		else
			board.badge.Text = T("Presiona E para jugar")
			board.badge.BackgroundColor3 = READY_COLOR
			board.badge.TextColor3 = DARK_TEXT
		end
	end

	local function add(instance: Instance)
		if not instance:IsA("BasePart") or boards[instance] then
			return
		end
		local board = build(instance)
		boards[instance] = board
		draw(board)
	end

	CollectionService:GetInstanceAddedSignal(Config.Lobby.LabBoardTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Config.Lobby.LabBoardTag):Connect(function(instance)
		local board = boards[instance :: BasePart]
		if board then
			board.gui:Destroy()
			boards[instance :: BasePart] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(Config.Lobby.LabBoardTag) do
		add(instance)
	end

	local function redraw()
		for _, board in boards do
			draw(board)
		end
	end
	player:GetAttributeChangedSignal("ArenaQueue"):Connect(redraw)
	ReplicatedStorage:GetAttributeChangedSignal("LabQueueCounts"):Connect(redraw)
	Strings.onChanged(redraw)
	-- El tiempo en la cola corre solo: cada segundo.
	task.spawn(function()
		while true do
			task.wait(1)
			redraw()
		end
	end)
end

return LabBoardController
