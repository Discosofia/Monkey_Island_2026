--!strict
-- Sonidos de la pelota del Juego de pelota de Dunas (Fase 27f). Escucha Remotes.BallEvent y suena en 3D donde ocurre
-- (CourtGeometry.CENTER + la posición local del evento): golpe, roce, bote en suelo y en muro, choque en el borde del
-- aro y paso por el aro. Además suena una marca cuando sube el marcador por una raya. Cada tipo de sonido tiene su
-- cadencia mínima para que una racha de botes no sature. La fanfarria de la embocada es de BallReplayController.
-- Los efectos están en Shared/Data/Sounds.Effects (Ball*).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local CENTER = CourtGeometry.CENTER
local MIN_GAP = 0.08 -- segundos mínimos entre dos sonidos del mismo tipo

-- Superficies de BallSim que suenan como suelo; el resto (talud, contrahuella, muros, cabeceras) suena como muro.
-- "Ring" no suena aquí: el choque en el aro llega aparte como "ringRim".
local FLOOR_SURFACES = { Floor = true, Bench = true }

local BallSfxController = {}

local lastPlayed: { [string]: number } = {}

local function play(key: string, localPos: Vector3)
	local now = os.clock()
	if now - (lastPlayed[key] or -math.huge) < MIN_GAP then
		return
	end
	lastPlayed[key] = now
	Sfx.play(key, CENTER + localPos)
end

local function ringPosition(zSign: any): Vector3
	local ring = CourtGeometry.ring
	return Vector3.new(
		ring.centerX,
		ring.centerY,
		(if typeof(zSign) == "number" and zSign < 0 then -1 else 1) * ring.centerZ
	)
end

local function onEvent(event: any)
	if typeof(event) ~= "table" then
		return
	end
	local kind = event.kind
	local pos = event.pos
	if kind == "hit" and typeof(pos) == "Vector3" then
		local key = if event.quality == "Passive"
			then "BallTouch"
			elseif event.quality == "Perfect" then "BallHitPerfect"
			else "BallHit"
		play(key, pos)
	elseif kind == "bounce" and typeof(pos) == "Vector3" then
		local surface = event.surface
		if surface == "Ring" then
			return
		end
		play(if FLOOR_SURFACES[surface] then "BallBounceFloor" else "BallBounceWall", pos)
	elseif kind == "ringRim" then
		play("BallRim", ringPosition(event.zSign))
	elseif kind == "ringPass" then
		play("BallRingPass", ringPosition(event.zSign))
	end
end

function BallSfxController:Start()
	Remotes.BallEvent.OnClientEvent:Connect(onEvent)
	-- Una raya: el marcador de un equipo sube (con el modo Juego de pelota en curso).
	for _, teamId in Arena.TEAM_IDS do
		local last = Arena.score(teamId)
		ReplicatedStorage:GetAttributeChangedSignal(`ArenaScore_{teamId}`):Connect(function()
			local score = Arena.score(teamId)
			local rose = score > last
			last = score
			if rose and ArenaModes.current() == "Ballgame" then
				Sfx.playLocal("BallRay")
			end
		end)
	end
end

return BallSfxController
