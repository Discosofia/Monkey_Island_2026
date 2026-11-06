--!strict
-- Matemática del golpe a la pelota del Juego de pelota (Fase 26d): zonas del cuerpo, calidad según el tiempo
-- hasta el contacto y velocidad final. Pura y sin estado: la usan igual el servidor (BallHitService, que decide)
-- y el cliente (BallHitController, que predice y dibuja el anillo). Coordenadas LOCALES de la cancha.
-- Zonas (altura de la pelota menos la del HumanoidRootPart): Foot (falta por pie), Knee, Hip, Elbow; por encima
-- de Elbow, fuera de alcance. Calidades: Perfect, Good, Weak (con pulsación) y Passive (roce sin pulsar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallSim = require(ReplicatedStorage.Shared.BallSim)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)

local Hit = Data.Hit

-- Con la mirada casi vertical no hay dirección horizontal fiable: se golpea hacia el lado rival.
local MIN_HORIZONTAL = 0.2

local BallHit = {}

-- Zona de golpe según "dy" (altura del centro de la pelota menos la del HumanoidRootPart); nil si está fuera de alcance.
function BallHit.zoneOf(dy: number): string?
	if dy > Hit.ZoneElbow then
		return nil
	elseif dy < Hit.ZoneFoot then
		return "Foot"
	elseif dy < Hit.ZoneKnee then
		return "Knee"
	elseif dy < Hit.ZoneHip then
		return "Hip"
	end
	return "Elbow"
end

-- Segundos hasta que el centro de la pelota esté a "contactDist" o menos de "playerPos" (0 si ya lo está), simulando
-- hasta "maxT"; nil si no llega. La copia no toca el estado de verdad.
function BallHit.timeToContact(
	ballState: BallSim.State,
	layout: CourtGeometry.Layout,
	playerPos: Vector3,
	contactDist: number,
	maxT: number
): number?
	if (ballState.pos - playerPos).Magnitude <= contactDist then
		return 0
	end
	if ballState.resting or ballState.dead then
		return nil
	end
	local sim = BallSim.clone(ballState)
	local steps = math.ceil(maxT / BallSim.STEP)
	for index = 1, steps do
		BallSim.step(sim, layout, BallSim.STEP)
		if (sim.pos - playerPos).Magnitude <= contactDist then
			return index * BallSim.STEP
		end
		if sim.dead or sim.resting then
			return nil
		end
	end
	return nil
end

-- Calidad del golpe según los segundos hasta el contacto ("slack": margen de lag que se suma a las ventanas).
function BallHit.quality(ttc: number?, slack: number): string
	if ttc ~= nil then
		if ttc <= Hit.PerfectSeconds + slack then
			return "Perfect"
		elseif ttc <= Hit.GoodSeconds + slack then
			return "Good"
		end
	end
	return "Weak"
end

-- Dirección horizontal unitaria de "lookDir" (mundo = local, la cancha no gira); sin ella, hacia "rivalSign" en X.
local function horizontal(lookDir: Vector3, rivalSign: number): Vector3
	local flat = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flat.Magnitude < MIN_HORIZONTAL then
		return Vector3.new(rivalSign, 0, 0)
	end
	return flat.Unit
end

-- La velocidad FINAL de la pelota tras el golpe. "rivalSign": +1 si el golpeador ataca hacia +X (el Jaguar), -1 si
-- hacia -X. Foot sale flojo con el ángulo de la rodilla; Passive, con el de la cadera y la rapidez del roce.
function BallHit.velocity(zone: string, quality: string, lookDir: Vector3, rivalSign: number): Vector3
	local pitch: number
	local speed: number
	if zone == "Foot" then
		pitch = Hit.Pitch.Knee
		speed = Hit.FootSpeed
	elseif quality == "Passive" then
		pitch = Hit.Pitch.Hip
		speed = Hit.PassiveSpeed
	else
		pitch = Hit.Pitch[zone]
		speed = Hit.Speed[zone][quality]
	end
	local direction = horizontal(lookDir, rivalSign)
	local radians = math.rad(pitch)
	return Vector3.new(direction.X * math.cos(radians), math.sin(radians), direction.Z * math.cos(radians)) * speed
end

-- Equipo que ataca hacia +X (el que defiende X < 0) -> +1; el otro, -1.
function BallHit.rivalSign(teamId: string?): number
	return if teamId == "Quetzal" then -1 else 1
end

return BallHit
