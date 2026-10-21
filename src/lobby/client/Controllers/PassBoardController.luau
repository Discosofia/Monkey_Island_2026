--!strict
-- Cartel del pase de temporada en el borde de la plaza (etiqueta Config.Lobby.PassBoardTag, lo pone
-- World/LobbyBuilder). Cada cliente lo dibuja con lo suyo: la temporada y cuánto le queda (o el
-- descanso), tu nivel con su barra y, abajo, cuántos premios tienes por reclamar o "Pulsa E". Su
-- aviso ("PassPrompt") abre la ventana del pase (LobbyUIController, UI/SeasonPassPanel).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local DARK_TEXT = Color3.fromRGB(40, 25, 5)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local NEXT_COLOR = Color3.fromRGB(120, 230, 255)
local WARN_COLOR = Color3.fromRGB(255, 170, 60)
local BAR_BACK = Color3.fromRGB(20, 16, 12)
local DAY = 24 * 60 * 60

local PassBoardController = {}

type Board = {
	gui: SurfaceGui,
	season: TextLabel,
	time: TextLabel,
	level: TextLabel,
	fill: Frame,
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

local function corner(parent: Instance, scale: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(scale, 0)
	instance.Parent = parent
end

local function left(seconds: number): string
	if seconds >= DAY then
		return `{seconds // DAY} d {(seconds % DAY) // 3600} h`
	end
	return `{seconds // 3600} h {(seconds % 3600) // 60} min`
end

function PassBoardController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local boards: { [BasePart]: Board } = {}

	local function build(part: BasePart): Board
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TablaPase"
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
		corner(panel, 0.05)

		local season =
			text("", panel, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.17), Enum.Font.BuilderSansBold)
		local time = text("", panel, UDim2.fromScale(0.05, 0.22), UDim2.fromScale(0.9, 0.11), Enum.Font.BuilderSans)
		time.TextColor3 = SECONDARY
		local level =
			text("", panel, UDim2.fromScale(0.05, 0.37), UDim2.fromScale(0.9, 0.13), Enum.Font.BuilderSansBold)
		level.TextColor3 = READY_COLOR
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromScale(0.1, 0.53)
		bar.Size = UDim2.fromScale(0.8, 0.09)
		bar.BackgroundColor3 = BAR_BACK
		bar.Parent = panel
		corner(bar, 0.5)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = NEXT_COLOR
		fill.Parent = bar
		corner(fill, 0.5)
		local badge =
			text("", panel, UDim2.fromScale(0.15, 0.73), UDim2.fromScale(0.7, 0.2), Enum.Font.BuilderSansExtraBold)
		badge.BackgroundTransparency = 0
		corner(badge, 0.3)
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.12, 0)
		padding.PaddingBottom = UDim.new(0.12, 0)
		padding.Parent = badge

		return { gui = gui, season = season, time = time, level = level, fill = fill, badge = badge }
	end

	local function draw(board: Board)
		local info = SeasonPass.info(SeasonPass.now())
		local season = info.season
		if not season then
			board.season.Text = "🌋 Pronto, la primera temporada"
			board.time.Text = ""
			board.level.Text = ""
			board.fill.Size = UDim2.fromScale(0, 1)
			board.badge.Visible = false
			return
		end
		board.season.Text = `{season.icon} {season.name}`
		board.time.TextColor3 = if info.lastWeek then WARN_COLOR else SECONDARY
		if info.phase == "Active" then
			board.time.Text =
				`Día {info.day} de {Config.Season.Days} · termina en {left(info.secondsLeft)}{if info.lastWeek
					then ` · 🔥 ×{info.multiplier} XP`
					else ""}`
		elseif info.phase == "Rest" then
			board.time.Text = `Terminada · la siguiente en {left(info.secondsLeft)}`
		else
			board.time.Text = `Empieza en {left(info.secondsLeft)}`
		end
		local raw = player:GetAttribute("Season")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		local state = SeasonPass.normalize(if ok then decoded else nil, season.id)
		local progress, need = SeasonPass.progress(state)
		board.level.Text = `Tu nivel: {SeasonPass.level(state)}/{Config.Season.Levels}{if state.premium
			then " · 🌋 Premium"
			else ""}`
		board.fill.Size = UDim2.fromScale(math.clamp(progress / need, 0, 1), 1)
		board.badge.Visible = info.phase == "Active"
		local claims, loops = SeasonPass.claimable(season, state)
		local count = if state.closed then 0 else #claims + loops
		if count > 0 then
			board.badge.Text = `🎁 {count} {if count == 1 then "premio" else "premios"} por reclamar · E`
		else
			board.badge.Text = "Pulsa E para ver el pase"
		end
		board.badge.BackgroundColor3 = READY_COLOR
		board.badge.TextColor3 = DARK_TEXT
	end

	local function add(instance: Instance)
		if not instance:IsA("BasePart") or boards[instance] then
			return
		end
		local board = build(instance)
		boards[instance] = board
		draw(board)
	end

	CollectionService:GetInstanceAddedSignal(Config.Lobby.PassBoardTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Config.Lobby.PassBoardTag):Connect(function(instance)
		local board = boards[instance :: BasePart]
		if board then
			board.gui:Destroy()
			boards[instance :: BasePart] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(Config.Lobby.PassBoardTag) do
		add(instance)
	end

	local function redraw()
		for _, board in boards do
			draw(board)
		end
	end
	player:GetAttributeChangedSignal("Season"):Connect(redraw)
	-- El panel de pruebas de Studio mueve el reloj del pase.
	ReplicatedStorage:GetAttributeChangedSignal("DebugSeasonShift"):Connect(redraw)
	-- La cuenta atrás corre sola.
	task.spawn(function()
		while true do
			task.wait(30)
			redraw()
		end
	end)
end

return PassBoardController
