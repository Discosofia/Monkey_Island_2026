--!strict
-- HUD del Juego de pelota de Dunas (Fase 26g), encima del de ArenaHUDController (que solo apaga banderas y altar
-- en este modo y deja vacío el número de las casillas):
--   - Rayas: palitos de talla en las casillas Jaguar y Quetzal del marcador (grupos de 4 palitos y el quinto
--     tachado en diagonal), con el color de cada equipo. El máximo sale de Config.Arena.Ballgame.RaysToWin.
--   - Botes: 3 puntos bajo la casilla de TU equipo; se apagan al botar la pelota en tu campo (a 3 es raya del
--     rival). Solo con la pelota en juego (BallActive) y si tienes equipo.
--   - Avisos: banner bajo el marcador con el color del equipo que puntúa (BallgameCall / BallgameCallTeam /
--     BallgameCallSeq, que publica Dunas/Modes/Ballgame). Sin equipo, color neutro. El del aro dura más.
-- El banner va por debajo de la barra de vida (arriba a la izquierda, hasta y 66) y no toca la cancha.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local Config = require(ReplicatedStorage.Shared.Config)
local BallgameData = require(ReplicatedStorage.Shared.Data.Ballgame)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t

local RAYS_PER_GROUP = 5 -- 4 palitos y el quinto tachado
local DARK_MIX = 0.7 -- cuánto se oscurece la casilla para que los palitos del color del equipo se vean
local DOT_SIZE = 10
local DOT_GAP = 4
local DOT_OFF_COLOR = Color3.fromRGB(60, 50, 45)
local BANNER_TOP = 70
local BANNER_HEIGHT = 44
local RING_BANNER_HEIGHT = 64
local BANNER_MAX_WIDTH = 520
local BANNER_SECONDS = 2
local RING_SECONDS = 3
local FADE_SECONDS = 0.3
local NEUTRAL_COLOR = Color3.fromRGB(245, 235, 210)
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)

local BallgameHUD = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function isBallgame(): boolean
	return ArenaModes.current() == "Ballgame"
end

-- Dibuja las rayas de un equipo en su contenedor: palitos en grupos, el quinto de cada grupo en diagonal.
local function drawTally(holder: Frame, color: Color3, score: number)
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local maxRays = Config.Arena.Ballgame.RaysToWin
	local shown = math.clamp(score, 0, maxRays)
	local groups = math.ceil(maxRays / RAYS_PER_GROUP)
	for g = 1, groups do
		local group = Instance.new("Frame")
		group.Name = `Group{g}`
		group.LayoutOrder = g
		group.BackgroundTransparency = 1
		group.Size = UDim2.fromScale(0.4, 0.62)
		group.Parent = holder
		for i = 0, RAYS_PER_GROUP - 1 do
			local n = (g - 1) * RAYS_PER_GROUP + i + 1
			if n > shown then
				break
			end
			local mark = Instance.new("Frame")
			mark.BackgroundColor3 = color
			mark.BorderSizePixel = 0
			if i < RAYS_PER_GROUP - 1 then
				mark.Name = `Stick{n}`
				mark.Position = UDim2.fromScale(i * 0.28, 0)
				mark.Size = UDim2.fromScale(0.14, 1)
			else
				mark.Name = `Slash{n}`
				mark.AnchorPoint = Vector2.new(0.5, 0.5)
				mark.Position = UDim2.fromScale(0.5, 0.5)
				mark.Size = UDim2.new(1.25, 0, 0, 3)
				mark.Rotation = -35
			end
			corner(mark, 2)
			mark.Parent = group
		end
	end
end

function BallgameHUD:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Widgets.screen("BallgameHUD", playerGui)
	gui.DisplayOrder = 2
	-- Las casillas las crea ArenaHUDController: se cuelga de ellas por su nombre.
	local score = playerGui:WaitForChild("ArenaScore"):WaitForChild("Score")

	local boxes: { [string]: TextLabel } = {}
	local tallies: { [string]: Frame } = {}
	local dotHolders: { [string]: Frame } = {}
	local dots: { [string]: { Frame } } = {}
	local drawnScore: { [string]: number } = {}
	local totalDots = Config.Arena.Ballgame.MaxBounces + 1

	for _, teamId in Arena.TEAM_IDS do
		local team = Config.Arena.Teams[teamId]
		local box = score:WaitForChild(teamId) :: TextLabel
		boxes[teamId] = box

		local tally = Instance.new("Frame")
		tally.Name = "Tally"
		tally.BackgroundTransparency = 1
		tally.Size = UDim2.fromScale(1, 1)
		tally.Parent = box
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = tally
		tallies[teamId] = tally

		-- Puntos de botes, centrados bajo la casilla (la de Jaguar ocupa 0–0,32 y la de Quetzal 0,68–1).
		local holder = Instance.new("Frame")
		holder.Name = `Bounces{teamId}`
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(if teamId == Arena.TEAM_IDS[1] then 0.16 else 0.84, 0, 1, 4)
		holder.Size = UDim2.fromOffset(totalDots * DOT_SIZE + (totalDots - 1) * DOT_GAP, DOT_SIZE)
		holder.Visible = false
		holder.Parent = score
		local dotLayout = Instance.new("UIListLayout")
		dotLayout.FillDirection = Enum.FillDirection.Horizontal
		dotLayout.Padding = UDim.new(0, DOT_GAP)
		dotLayout.SortOrder = Enum.SortOrder.LayoutOrder
		dotLayout.Parent = holder
		dotHolders[teamId] = holder
		local list = {}
		for i = 1, totalDots do
			local dot = Instance.new("Frame")
			dot.Name = `Dot{i}`
			dot.LayoutOrder = i
			dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
			dot.BackgroundColor3 = team.color
			dot.Parent = holder
			corner(dot, DOT_SIZE)
			list[i] = dot
		end
		dots[teamId] = list
	end

	-- Banner de avisos.
	local banner = Widgets.label("", gui)
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	banner.Size = UDim2.new(0.7, 0, 0, BANNER_HEIGHT)
	banner.BackgroundColor3 = PANEL_COLOR
	banner.BackgroundTransparency = 0.25
	banner.TextStrokeTransparency = 0.3
	banner.Visible = false
	corner(banner, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(BANNER_MAX_WIDTH, math.huge)
	sizeLimit.Parent = banner
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = banner
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 30
	textLimit.MinTextSize = 12
	textLimit.Parent = banner

	local showCount = 0
	local function showBanner(text: string, color: Color3, big: boolean)
		showCount += 1
		local thisShow = showCount
		local seconds = if big then RING_SECONDS else BANNER_SECONDS
		banner.Text = text
		banner.TextColor3 = color
		banner.Size = UDim2.new(0.7, 0, 0, if big then RING_BANNER_HEIGHT else BANNER_HEIGHT)
		banner.TextTransparency = 0
		banner.BackgroundTransparency = 0.25
		banner.Visible = true
		task.delay(math.max(0, seconds - FADE_SECONDS), function()
			if showCount ~= thisShow then
				return
			end
			TweenService
				:Create(banner, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		end)
		task.delay(seconds, function()
			if showCount == thisShow then
				banner.Visible = false
			end
		end)
	end

	local lastSeq = ReplicatedStorage:GetAttribute("BallgameCallSeq")
	local function onCall()
		local seq = ReplicatedStorage:GetAttribute("BallgameCallSeq")
		if seq == lastSeq then
			return
		end
		lastSeq = seq
		local call = ReplicatedStorage:GetAttribute("BallgameCall")
		local template = if typeof(call) == "string" then BallgameData.Calls[call] else nil
		if template == nil or not isBallgame() then
			return -- "Time" no lleva aviso
		end
		local teamId = ReplicatedStorage:GetAttribute("BallgameCallTeam")
		local team = if Arena.isTeam(teamId) then Config.Arena.Teams[teamId :: string] else nil
		local text = T(template, { icon = if team then team.icon else "", name = if team then team.name else "" })
		showBanner(text, if team then team.color else NEUTRAL_COLOR, call == "Ring")
	end
	ReplicatedStorage:GetAttributeChangedSignal("BallgameCallSeq"):Connect(onCall)

	local darkened = false
	RunService.RenderStepped:Connect(function()
		local ball = isBallgame()
		if ball ~= darkened then
			darkened = ball
			for teamId, box in boxes do
				local color = Config.Arena.Teams[teamId].color
				box.BackgroundColor3 = if ball then color:Lerp(Color3.new(0, 0, 0), DARK_MIX) else color
			end
		end
		for teamId, tally in tallies do
			tally.Visible = ball
			local rays = Arena.score(teamId)
			if ball and drawnScore[teamId] ~= rays then
				drawnScore[teamId] = rays
				drawTally(tally, Config.Arena.Teams[teamId].color, rays)
			end
		end
		if not ball then
			banner.Visible = false
		end

		-- Botes: solo los de mi lado y con la pelota en juego.
		local myTeam = Arena.teamOf(player)
		local live = ball and ReplicatedStorage:GetAttribute("BallActive") == true
		for teamId, holder in dotHolders do
			local mine = live and teamId == myTeam
			holder.Visible = mine
			if mine then
				local bounces = ReplicatedStorage:GetAttribute(`BallgameBounces_{teamId}`)
				local left = totalDots - (if typeof(bounces) == "number" then bounces else 0)
				local color = Config.Arena.Teams[teamId].color
				for i, dot in dots[teamId] do
					dot.BackgroundColor3 = if i <= left then color else DOT_OFF_COLOR
				end
			end
		end
	end)
end

return BallgameHUD
