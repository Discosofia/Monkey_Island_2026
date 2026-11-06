--!strict
-- Rivales de prueba del Juego de pelota (Fase 27b, solo Studio): muñecos voxel que devuelven la pelota para poder
-- probar el partido sin otro jugador. Se crean desde el panel de pruebas (ArenaDebugService, «BotRivals»), viven en
-- Workspace.RivalesDePrueba y no cuentan como miembros del equipo (Arena.membersOf no los ve: por eso se prueba con
-- «Empezar ya»). Cada bot es un muñeco anclado sin colisión que se mueve a mano. Mientras la pelota esté en su
-- campo, el más cercano va a ella y, al tenerla al alcance y pasar el tiempo de reacción, la golpea con
-- BallHitService.botHit hacia el campo contrario. Se apagan al acabar la partida (fase Results) y al cambiar de modo.
-- Todo va en coordenadas LOCALES de la cancha (Shared/CourtGeometry); los números, en Data/Ballgame.Bot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local BallHit = require(ReplicatedStorage.Shared.BallHit)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)
local BallHitService = require(script.Parent.BallHitService)
local BallService = require(script.Parent.BallService)

local FOLDER_NAME = "RivalesDePrueba"
-- Altura del centro del muñeco sobre el suelo: la de un HumanoidRootPart (de ella sale la zona del golpe).
local ROOT_HEIGHT = 3
-- Los bots no se separan del eje del pasillo más que el pasillo menos este margen (studs).
local LANE_MARGIN = 3
-- El bot golpea cuando la pelota entra en esta fracción del alcance de un jugador.
local REACH_FACTOR = 0.8
-- Dispersión lateral (studs) del punto del campo rival al que apunta.
local AIM_SPREAD_Z = 8
-- Equipos: primario (cuerpo) y secundario (franja de la espalda, patas y orejas). Los de la cancha: el Jaguar,
-- rojo teja y amarillo; el Quetzal, jade y negro (nada de verde de curación ni rojo de daño puros).
local PALETTE: { [string]: { primary: Color3, secondary: Color3 } } = {
	Jaguar = { primary = Color3.fromRGB(172, 52, 40), secondary = Color3.fromRGB(232, 186, 52) },
	Quetzal = { primary = Color3.fromRGB(46, 125, 80), secondary = Color3.fromRGB(36, 32, 36) },
}
local SNOUT = Color3.fromRGB(226, 205, 168)

type Bot = {
	name: string,
	model: Model,
	home: Vector3, -- local (x, z); y no se usa
	pos: Vector3,
	reachSince: number?,
	restUntil: number,
}

local BallBotService = {}

local bots: { Bot } = {}
local botTeam: string? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Las piezas del muñeco (unas 14), con el HumanoidRootPart invisible en el centro y la cara hacia -Z.
local function buildFigure(name: string, teamId: string): Model
	local palette = PALETTE[teamId]
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Team", teamId)
	local function piece(partName: string, size: Vector3, offset: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = partName
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = size
		part.Position = offset
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = model
		return part
	end
	local root = piece("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, palette.primary)
	root.Transparency = 1
	model.PrimaryPart = root
	piece("Torso", Vector3.new(2, 2, 1), Vector3.zero, palette.primary)
	piece("LeftLeg", Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, -2, 0), palette.secondary)
	piece("RightLeg", Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, -2, 0), palette.secondary)
	piece("LeftArm", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 0, 0), palette.primary)
	piece("RightArm", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 0, 0), palette.primary)
	local head = piece("Head", Vector3.one * 1.6, Vector3.new(0, 1.8, 0), palette.primary)
	piece("Snout", Vector3.new(0.9, 0.6, 0.5), Vector3.new(0, 1.6, -1), SNOUT)
	piece("LeftEar", Vector3.new(0.5, 0.5, 0.3), Vector3.new(-0.7, 2.8, 0), palette.secondary)
	piece("RightEar", Vector3.new(0.5, 0.5, 0.3), Vector3.new(0.7, 2.8, 0), palette.secondary)
	piece("Belly", Vector3.new(1.2, 1.2, 0.2), Vector3.new(0, -0.1, -0.55), SNOUT)
	piece("BackStripe", Vector3.new(1.2, 1.8, 0.2), Vector3.new(0, 0, 0.6), palette.secondary)
	piece("TailBase", Vector3.new(0.4, 0.4, 0.8), Vector3.new(0, -0.9, 0.9), palette.primary)
	piece("TailTip", Vector3.new(0.4, 0.4, 0.8), Vector3.new(0, -0.5, 1.6), palette.secondary)
	-- El nombre sobre la cabeza.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(100, 24)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = billboard
	return model
end

-- Pone el muñeco en un punto local (x, z) mirando hacia el campo contrario a su equipo.
local function place(bot: Bot, localPos: Vector3, teamId: string)
	bot.pos = localPos
	local world = CourtGeometry.CENTER + Vector3.new(localPos.X, ROOT_HEIGHT, localPos.Z)
	local facing = world + Vector3.new(-CourtGeometry.sideSign(teamId), 0, 0)
	bot.model:PivotTo(CFrame.lookAt(world, facing))
end

function BallBotService.clear()
	for _, bot in bots do
		bot.model:Destroy()
	end
	bots = {}
	botTeam = nil
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

function BallBotService.isActive(): boolean
	return #bots > 0
end

-- Pone "count" rivales (1, 3 o 5; 0 apaga) en el campo de "teamId", repartidos a lo ancho del pasillo.
function BallBotService.setRivals(teamId: string, count: number)
	BallBotService.clear()
	if count <= 0 or not PALETTE[teamId] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	botTeam = teamId
	local halfLength = BallService.layout().halfLength
	local x = CourtGeometry.sideSign(teamId) * halfLength / 2
	local span = CourtGeometry.ALLEY_HALF_WIDTH - LANE_MARGIN
	for index = 1, count do
		local z = if count == 1 then 0 else -span + (index - 1) * (2 * span / (count - 1))
		local name = `Rival {index}`
		local model = buildFigure(name, teamId)
		model.Parent = folder
		local home = Vector3.new(x, 0, z)
		local bot: Bot = { name = name, model = model, home = home, pos = home, reachSince = nil, restUntil = 0 }
		table.insert(bots, bot)
		place(bot, home, teamId)
	end
end

-- Acerca "from" a "to" (solo en planta) como mucho "step" studs.
local function approach(from: Vector3, to: Vector3, step: number): Vector3
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if delta.Magnitude <= step then
		return Vector3.new(to.X, 0, to.Z)
	end
	return Vector3.new(from.X, 0, from.Z) + delta.Unit * step
end

-- Golpea hacia un punto del campo contrario (z al azar) con la zona y la calidad dadas.
local function strike(bot: Bot, teamId: string, ballPos: Vector3, zone: string)
	local layout = BallService.layout()
	local targetX = -CourtGeometry.sideSign(teamId) * layout.halfLength / 2
	local targetZ = (math.random() * 2 - 1) * AIM_SPREAD_Z
	local direction = Vector3.new(targetX - ballPos.X, 0, targetZ - ballPos.Z)
	local look = if direction.Magnitude > 0 then direction.Unit else Vector3.new(-CourtGeometry.sideSign(teamId), 0, 0)
	local quality = Data.Bot.Quality
	local velocity = BallHit.velocity(zone, quality, look, BallHit.rivalSign(teamId), nil)
	BallHitService.botHit(bot.name, teamId, zone, quality, velocity)
	bot.reachSince = nil
	bot.restUntil = now() + Data.Bot.ReturnSeconds
end

local function onHeartbeat(dt: number)
	local teamId = botTeam
	if teamId == nil or #bots == 0 then
		return
	end
	-- Al acabar la partida, los bots se van.
	if Arena.phase() == "Results" then
		BallBotService.clear()
		return
	end
	local time = now()
	local step = Data.Bot.Speed * dt
	local ball = BallService.state()
	local playing = BallService.isActive() and not ball.dead and CourtGeometry.teamOfSide(ball.pos.X) == teamId

	-- El que va a la pelota: el más cercano (en planta) de los que no descansan.
	local chaser: Bot? = nil
	if playing then
		local best = math.huge
		for _, bot in bots do
			local distance = (Vector3.new(ball.pos.X, 0, ball.pos.Z) - bot.pos).Magnitude
			if time >= bot.restUntil and distance < best then
				best = distance
				chaser = bot
			end
		end
	end

	local halfLength = BallService.layout().halfLength
	local laneHalf = CourtGeometry.ALLEY_HALF_WIDTH - LANE_MARGIN
	for _, bot in bots do
		if bot == chaser then
			-- Hacia la pelota sin salirse de su campo ni del pasillo.
			local target = Vector3.new(
				math.clamp(ball.pos.X, -halfLength, halfLength),
				0,
				math.clamp(ball.pos.Z, -laneHalf, laneHalf)
			)
			place(bot, approach(bot.pos, target, step), teamId)
			-- ¿Tiene la pelota al alcance?
			local botPos = Vector3.new(bot.pos.X, ROOT_HEIGHT, bot.pos.Z)
			local zone = BallHit.zoneOf(ball.pos.Y - ROOT_HEIGHT)
			if zone ~= nil and zone ~= "Foot" and (ball.pos - botPos).Magnitude <= Data.Hit.Reach * REACH_FACTOR then
				local since = bot.reachSince
				if since == nil then
					bot.reachSince = time
				elseif
					time - since >= Data.Bot.ReactionSeconds
					and BallHitService.secondsSinceHit() >= Data.Hit.BallCooldownSeconds
				then
					strike(bot, teamId, ball.pos, zone)
				end
			else
				bot.reachSince = nil
			end
		else
			bot.reachSince = nil
			if bot.pos ~= bot.home then
				place(bot, approach(bot.pos, bot.home, step), teamId)
			end
		end
	end
end

function BallBotService:Init() end

function BallBotService:Start()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return BallBotService
