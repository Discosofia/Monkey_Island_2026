--!strict
-- Cartel del pase de temporada en el borde de la plaza (etiqueta Config.Lobby.PassBoardTag, lo pone
-- World/LobbyBuilder con su aspecto de volcán). Cada cliente lo dibuja con lo suyo, en un panel de
-- obsidiana con borde de lava: el medallón con tu nivel, la temporada y lo que le queda (o el
-- descanso), la barra de XP de lava, "Siguiente premio" con su imagen 3D girando (el primero que
-- tienes por reclamar o el del nivel siguiente; Shared/RewardModels) y, abajo, cuántos premios
-- tienes por reclamar. Su aviso ("PassPrompt", a los pies del cartel) abre la ventana del pase
-- (LobbyUIController, UI/SeasonPassPanel).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Strings = require(ReplicatedStorage.Shared.Strings)

local T = Strings.t

local OBSIDIAN = Color3.fromRGB(24, 17, 16)
local OBSIDIAN_LIGHT = Color3.fromRGB(52, 30, 24)
local LAVA = Color3.fromRGB(255, 110, 30)
local LAVA_LIGHT = Color3.fromRGB(255, 195, 80)
local LAVA_DARK = Color3.fromRGB(150, 40, 15)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local DARK_TEXT = Color3.fromRGB(40, 25, 5)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local BAR_BACK = Color3.fromRGB(20, 12, 10)
local DAY = 24 * 60 * 60

local PassBoardController = {}

type Board = {
	gui: SurfaceGui,
	medal: TextLabel,
	medalLabel: TextLabel,
	season: TextLabel,
	time: TextLabel,
	fill: Frame,
	barText: TextLabel,
	nextTitle: TextLabel,
	view: ViewportFrame,
	nextName: TextLabel,
	badge: TextLabel,
	shownKey: string?,
	model: Model?,
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

local function stroke(parent: Instance, color: Color3, thickness: number)
	local instance = Instance.new("UIStroke")
	instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	instance.Color = color
	instance.Thickness = thickness
	instance.Parent = parent
end

local function gradient(parent: Instance, from: Color3, to: Color3, rotation: number)
	local instance = Instance.new("UIGradient")
	instance.Color = ColorSequence.new(from, to)
	instance.Rotation = rotation
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
		panel.Position = UDim2.fromScale(0.025, 0.04)
		panel.Size = UDim2.fromScale(0.95, 0.92)
		panel.BackgroundColor3 = Color3.new(1, 1, 1)
		panel.Parent = gui
		corner(panel, 0.05)
		gradient(panel, OBSIDIAN_LIGHT, OBSIDIAN, 90)
		stroke(panel, LAVA, 3)

		-- Medallón con tu nivel.
		local medalFrame = Instance.new("Frame")
		medalFrame.Position = UDim2.fromScale(0.03, 0.07)
		medalFrame.Size = UDim2.fromScale(0.24, 0.62)
		medalFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		medalFrame.Parent = panel
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = medalFrame
		corner(medalFrame, 0.5)
		gradient(medalFrame, OBSIDIAN_LIGHT, OBSIDIAN, 90)
		stroke(medalFrame, LAVA, 4)
		local medal =
			text("", medalFrame, UDim2.fromScale(0, 0.1), UDim2.fromScale(1, 0.58), Enum.Font.BuilderSansExtraBold)
		medal.TextColor3 = LAVA_LIGHT
		local medalLabel =
			text("NIVEL", medalFrame, UDim2.fromScale(0, 0.66), UDim2.fromScale(1, 0.2), Enum.Font.BuilderSansBold)
		medalLabel.TextColor3 = SECONDARY

		-- La temporada, lo que le queda y la barra de lava.
		local season =
			text("", panel, UDim2.fromScale(0.29, 0.06), UDim2.fromScale(0.4, 0.17), Enum.Font.BuilderSansBold)
		season.TextColor3 = LAVA_LIGHT
		season.TextXAlignment = Enum.TextXAlignment.Left
		local time = text("", panel, UDim2.fromScale(0.29, 0.25), UDim2.fromScale(0.4, 0.12), Enum.Font.BuilderSans)
		time.TextColor3 = SECONDARY
		time.TextXAlignment = Enum.TextXAlignment.Left
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromScale(0.29, 0.45)
		bar.Size = UDim2.fromScale(0.4, 0.15)
		bar.BackgroundColor3 = BAR_BACK
		bar.Parent = panel
		corner(bar, 0.5)
		stroke(bar, LAVA_DARK, 2)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.Parent = bar
		corner(fill, 0.5)
		gradient(fill, LAVA, LAVA_LIGHT, 0)
		local barText = text("", bar, UDim2.fromScale(0, 0.1), UDim2.fromScale(1, 0.8), Enum.Font.BuilderSansBold)

		-- Siguiente premio, con su imagen 3D.
		local nextTitle =
			text("", panel, UDim2.fromScale(0.71, 0.05), UDim2.fromScale(0.27, 0.1), Enum.Font.BuilderSansBold)
		nextTitle.TextColor3 = LAVA_LIGHT
		local viewBack = Instance.new("Frame")
		viewBack.Position = UDim2.fromScale(0.72, 0.16)
		viewBack.Size = UDim2.fromScale(0.25, 0.46)
		viewBack.BackgroundColor3 = Color3.new(1, 1, 1)
		viewBack.Parent = panel
		corner(viewBack, 0.1)
		gradient(viewBack, Color3.fromRGB(70, 35, 22), OBSIDIAN, 90)
		stroke(viewBack, LAVA_DARK, 2)
		local view = Instance.new("ViewportFrame")
		view.Size = UDim2.fromScale(1, 1)
		view.BackgroundTransparency = 1
		view.Parent = viewBack
		local nextName =
			text("", panel, UDim2.fromScale(0.7, 0.63), UDim2.fromScale(0.29, 0.1), Enum.Font.BuilderSansBold)

		-- Abajo: premios por reclamar o cómo abrir el pase.
		local badge =
			text("", panel, UDim2.fromScale(0.12, 0.78), UDim2.fromScale(0.76, 0.17), Enum.Font.BuilderSansExtraBold)
		badge.BackgroundTransparency = 0
		corner(badge, 0.3)
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.14, 0)
		padding.PaddingBottom = UDim.new(0.14, 0)
		padding.Parent = badge
		local pulse = Instance.new("UIScale")
		pulse.Parent = badge
		TweenService:Create(
			pulse,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.05 }
		):Play()

		return {
			gui = gui,
			medal = medal,
			medalLabel = medalLabel,
			season = season,
			time = time,
			fill = fill,
			barText = barText,
			nextTitle = nextTitle,
			view = view,
			nextName = nextName,
			badge = badge,
			shownKey = nil,
			model = nil,
		}
	end

	-- Pone en el visor el premio "reward" (solo si ha cambiado: rehacer el avatar cuesta).
	local function show(board: Board, key: string, reward: { [string]: any }?)
		if board.shownKey == key then
			return
		end
		board.shownKey = key
		board.model = nil
		for _, child in board.view:GetChildren() do
			child:Destroy()
		end
		if not reward then
			return
		end
		local model = if reward.cosmetic
			then RewardModels.cosmetic(player.Character, reward.cosmetic)
			else RewardModels.forReward(reward)
		if model then
			board.model = RewardModels.frame(board.view, model, if reward.cosmetic then 1.2 else 1.35)
		end
	end

	local function draw(board: Board)
		local info = SeasonPass.info(SeasonPass.now())
		local season = info.season
		if not season then
			board.season.Text = T("Pronto, la primera temporada")
			board.time.Text = ""
			board.medal.Text = "–"
			board.barText.Text = ""
			board.fill.Size = UDim2.fromScale(0, 1)
			board.nextTitle.Text = ""
			board.nextName.Text = ""
			board.badge.Visible = false
			show(board, "", nil)
			return
		end
		board.season.Text = `{season.icon} {T(season.name)}`
		board.time.TextColor3 = if info.lastWeek then LAVA_LIGHT else SECONDARY
		if info.phase == "Active" then
			local args = { left = left(info.secondsLeft), multiplier = info.multiplier }
			board.time.Text = if info.lastWeek
				then T("Termina en {left} · 🔥 ×{multiplier} XP", args)
				else T("Termina en {left}", args)
		elseif info.phase == "Rest" then
			board.time.Text = T("Terminada · la siguiente en {left}", { left = left(info.secondsLeft) })
		else
			board.time.Text = T("Empieza en {left}", { left = left(info.secondsLeft) })
		end
		local raw = player:GetAttribute("Season")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		local state = SeasonPass.normalize(if ok then decoded else nil, season.id)
		local level = SeasonPass.level(state)
		local progress, need = SeasonPass.progress(state)
		board.medal.Text = tostring(level)
		board.fill.Size = UDim2.fromScale(math.clamp(progress / need, 0.03, 1), 1)
		board.barText.Text = `{progress}/{need} XP`
		board.medalLabel.Text = if state.premium then T("PREMIUM") else T("NIVEL")
		board.medalLabel.TextColor3 = if state.premium then READY_COLOR else SECONDARY

		-- Siguiente premio: el primero por reclamar o el del nivel que viene (lo premium si la tiene).
		local claims, loops = SeasonPass.claimable(season, state)
		local count = if state.closed then 0 else #claims + loops
		local key, reward, title = "", nil :: { [string]: any }?, ""
		if #claims > 0 and not state.closed then
			local first = claims[1]
			key = `{first.level}{first.track}`
			reward = SeasonPass.reward(season, first.level, first.track) :: any
			title = T("¡LISTO PARA TI!")
		elseif level < Config.Season.Levels then
			local nextLevel = level + 1
			local premium = if state.premium then SeasonPass.reward(season, nextLevel, "Premium") else nil
			reward = (premium or SeasonPass.reward(season, nextLevel, "Free")) :: any
			key = `{nextLevel}{if premium then "Premium" else "Free"}`
			title = T("NIVEL {level}", { level = nextLevel })
		else
			key = "Loop"
			reward = SeasonPass.loopReward(state.loops + 1) :: any
			title = T("PREMIO EXTRA")
		end
		board.nextTitle.Text = title
		local cosmetic = if reward and reward.cosmetic then Cosmetics[reward.cosmetic] else nil
		board.nextName.Text = if cosmetic
			then T(cosmetic.name)
			elseif reward then Rewards.describe(reward :: any)
			else ""
		board.nextName.TextColor3 = if cosmetic then cosmetic.color else Color3.new(1, 1, 1)
		show(board, key, reward)

		board.badge.Visible = info.phase == "Active"
		if count > 0 then
			board.badge.Text = if count == 1
				then T("🎁 {count} premio por reclamar", { count = count })
				else T("🎁 {count} premios por reclamar", { count = count })
			board.badge.BackgroundColor3 = READY_COLOR
			board.badge.TextColor3 = DARK_TEXT
		else
			board.badge.Text = T("Juega en las islas para subir de nivel")
			board.badge.BackgroundColor3 = OBSIDIAN_LIGHT
			board.badge.TextColor3 = LAVA_LIGHT
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
	Strings.onChanged(redraw)
	-- El panel de pruebas de Studio mueve el reloj del pase.
	ReplicatedStorage:GetAttributeChangedSignal("DebugSeasonShift"):Connect(redraw)
	-- El avatar del premio cosmético sale con tu personaje: se rehace cuando aparece.
	player.CharacterAppearanceLoaded:Connect(function()
		for _, board in boards do
			board.shownKey = nil
			draw(board)
		end
	end)
	-- El premio gira despacio; la cuenta atrás corre sola.
	RunService.RenderStepped:Connect(function(delta)
		for _, board in boards do
			local model = board.model
			if model and model.Parent then
				local center = model:GetBoundingBox().Position
				model:PivotTo(
					CFrame.new(center) * CFrame.Angles(0, delta * 0.8, 0) * CFrame.new(-center) * model:GetPivot()
				)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			redraw()
		end
	end)
end

return PassBoardController
