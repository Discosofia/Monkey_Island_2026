--!strict
-- El golpe a la pelota del Juego de pelota (Fase 26d). El cliente manda Remotes.BallHit con hacia dónde mira; el
-- servidor decide: valida alcance, mitad de la cancha y enfriamientos, saca la zona del cuerpo y la calidad (tiempo
-- hasta el contacto) con Shared/BallHit, FIJA la velocidad de la pelota (BallService.applyImpulse) y avisa a todos
-- por BallEvent con { kind = "hit", userId, zone, quality, pos, vel }. Además hay un roce pasivo: la pelota que pasa
-- pegada a un jugador de su mitad rebota floja sin que pulse nada. Lo que no cuadra se ignora en silencio.
-- 26e se suscribe con onHit para las reglas (falta por pie: zona "Foot").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local BallHit = require(ReplicatedStorage.Shared.BallHit)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Latency = require(ServerScriptService.Combat.Latency)
local BallService = require(script.Parent.BallService)

local Hit = Data.Hit
local CENTER = CourtGeometry.CENTER
-- La dirección que manda el cliente tiene que ser unitaria con esta tolerancia.
local UNIT_TOLERANCE = 0.05
-- Tiempo máximo que se simula hacia delante para sacar la calidad (30 pasos).
local LOOKAHEAD_SECONDS = 0.5
-- Salir de PassiveContactDist por este factor rearma el roce pasivo de un jugador.
local PASSIVE_REARM_FACTOR = 1.5

export type HitInfo = {
	player: Player,
	team: string?,
	zone: string,
	quality: string,
	pos: Vector3,
	vel: Vector3,
}

local BallHitService = {}

local listeners: { (info: HitInfo) -> () } = {}
local lastHitAt: { [Player]: number } = {} -- último golpe de cada jugador (reloj del servidor)
local lastBallHitAt = -math.huge
local touching: { [Player]: boolean } = {} -- ya rozó y aún no se ha apartado

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- La raíz del personaje vivo del jugador, o nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Aplica el golpe: fija la velocidad (y la curva del Viento, en segundos), avisa a los clientes y a los oyentes.
local function apply(player: Player, team: string?, zone: string, quality: string, velocity: Vector3, curve: number)
	BallService.applyImpulse(velocity - BallService.state().vel)
	BallService.setCurve(curve)
	local after = BallService.state()
	lastHitAt[player] = now()
	lastBallHitAt = now()
	touching[player] = true
	Remotes.BallEvent:FireAllClients({
		kind = "hit",
		t = now(),
		userId = player.UserId,
		zone = zone,
		quality = quality,
		pos = after.pos,
		vel = after.vel,
		curve = curve,
	})
	local info: HitInfo = {
		player = player,
		team = team,
		zone = zone,
		quality = quality,
		pos = after.pos,
		vel = after.vel,
	}
	for _, listener in listeners do
		local ok, err = pcall(listener, info)
		if not ok then
			warn(`[BallHitService] Un oyente falló: {err}`)
		end
	end
end

-- Un golpe con pulsación de "player": suma lo que den sus habilidades (Golpe de yugo, Viento; Fase 26f), con la
-- misma cuenta que predice el cliente (Shared/BallHit). El yugo se gasta al golpear.
local function hitWithAbilities(player: Player, team: string?, zone: string, quality: string, lookDir: Vector3)
	local boost = BallHit.boostOf(player, zone, quality, nil)
	local velocity = BallHit.velocity(zone, quality, lookDir, BallHit.rivalSign(team), boost)
	apply(player, team, zone, quality, velocity, BallHit.curveOf(player, zone, quality))
	if boost > 1 then
		player:SetAttribute(Data.Attributes.Yoke, nil)
	end
end

local function onHitRequest(player: Player, lookDir: any)
	if typeof(lookDir) ~= "Vector3" or lookDir ~= lookDir or math.abs(lookDir.Magnitude - 1) > UNIT_TOLERANCE then
		return
	end
	if not BallService.isActive() then
		return
	end
	local root = rootOf(player)
	local team = Arena.teamOf(player)
	if not root or not team then
		return
	end
	local ball = BallService.state()
	if ball.dead then
		return
	end
	local side = CourtGeometry.teamOfSide(ball.pos.X)
	if side ~= nil and side ~= team then
		return
	end
	local slack = Config.Net.JitterSeconds + Latency.compensation(player)
	local time = now()
	if time - (lastHitAt[player] or -math.huge) < Hit.CooldownSeconds - slack then
		return
	end
	if time - lastBallHitAt < Hit.BallCooldownSeconds then
		return
	end
	local playerPos = root.Position - CENTER
	if (ball.pos - playerPos).Magnitude > Hit.Reach + slack * Hit.WalkSpeed then
		return
	end
	local zone = BallHit.zoneOf(ball.pos.Y - playerPos.Y)
	if zone == nil then
		return
	end
	local ttc = BallHit.timeToContact(ball, BallService.layout(), playerPos, Hit.ContactDist, LOOKAHEAD_SECONDS)
	local quality = BallHit.quality(ttc, slack)
	hitWithAbilities(player, team, zone, quality, lookDir)
end

-- Roce pasivo: rebote flojo, alejándose del jugador.
local function onHeartbeat()
	if not BallService.isActive() then
		return
	end
	local ball = BallService.state()
	if ball.dead then
		return
	end
	local side = CourtGeometry.teamOfSide(ball.pos.X)
	local time = now()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local team = Arena.teamOf(player)
		if not root or not team then
			continue
		end
		local playerPos = root.Position - CENTER
		local distance = (ball.pos - playerPos).Magnitude
		if touching[player] then
			if distance > Hit.PassiveContactDist * PASSIVE_REARM_FACTOR then
				touching[player] = nil
			end
			continue
		end
		if distance > Hit.PassiveContactDist then
			continue
		end
		if (side ~= nil and side ~= team) or time - lastBallHitAt < Hit.BallCooldownSeconds then
			continue
		end
		if time - (lastHitAt[player] or -math.huge) < Hit.BallCooldownSeconds then
			continue
		end
		local zone = BallHit.zoneOf(ball.pos.Y - playerPos.Y)
		if zone == nil then
			continue
		end
		local away = ball.pos - playerPos
		apply(player, team, zone, "Passive", BallHit.velocity(zone, "Passive", away, BallHit.rivalSign(team)), 0)
		break -- un solo roce por latido: el siguiente jugador espera al próximo
	end
end

-- Se suscribe a los golpes (26e: reglas). Devuelve la función que desconecta.
function BallHitService.onHit(listener: (info: HitInfo) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Depuración: golpea ya con la zona y la calidad dadas, sin mirar distancia, mitad ni enfriamientos.
function BallHitService.force(player: Player, zone: string, quality: string, lookDir: Vector3)
	if not BallService.isActive() or BallService.state().dead then
		return
	end
	hitWithAbilities(player, Arena.teamOf(player), zone, quality, lookDir)
end

function BallHitService:Init() end

function BallHitService:Start()
	Remotes.BallHit.OnServerEvent:Connect(onHitRequest)
	RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerRemoving:Connect(function(player)
		lastHitAt[player] = nil
		touching[player] = nil
	end)
end

return BallHitService
