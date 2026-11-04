--!strict
-- Trazas de disparo del campo de tiro (Fase 23e, solo Studio). Con el atributo DebugRangeTraces del jugador
-- (lo cambia DebugService, orden «RangeTraces»), cada proyectil que lanza se manda a su cliente al acabar
-- (RangeDebugController lo dibuja): de dónde salió, la línea que mandó su cliente (la puntería), la que siguió
-- el servidor tras la ayuda de puntería y la dispersión, dónde acabó, su ping y los segundos de lag que se
-- le rebobinan. Los disparos y los finales se emparejan por orden (un jugador cuyo disparo atraviesa a
-- varios o cuyas habilidades lanzan varios a la vez puede ver la traza algo cruzada: es solo depuración).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Projectiles = require(ServerScriptService.Combat.Projectiles)

local ATTRIBUTE = "DebugRangeTraces"
-- Disparos sin terminar que se guardan por jugador (tope contra fugas).
local MAX_PENDING = 16

local RangeDebugService = {}

local pending: { [Player]: { Projectiles.Shot } } = {}

local function onShot(shooter: Player, _ownerSeq: number?, shot: Projectiles.Shot)
	if shooter:GetAttribute(ATTRIBUTE) ~= true then
		return
	end
	local list = pending[shooter]
	if not list then
		list = {}
		pending[shooter] = list
	end
	if #list >= MAX_PENDING then
		table.remove(list, 1)
	end
	table.insert(list, shot)
end

local function onImpact(shooter: Player, position: Vector3, _instance: Instance?, _model: Model?)
	local list = pending[shooter]
	local shot = if list then table.remove(list, 1) else nil
	if not shot or shooter:GetAttribute(ATTRIBUTE) ~= true then
		return
	end
	Remotes.RangeDebug:FireClient(shooter, "Trace", {
		origin = shot.origin,
		aim = shot.aimDirection,
		direction = shot.direction,
		hit = position,
		pingMs = math.round(shooter:GetNetworkPing() * 1000),
		rewind = shot.rewind or 0,
	})
end

function RangeDebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Projectiles.onShot(onShot)
	Projectiles.onImpact(onImpact)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return RangeDebugService
