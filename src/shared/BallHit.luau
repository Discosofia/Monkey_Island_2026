--!strict
-- Matemática del golpe a la pelota del Juego de pelota (Fase 26d): zonas del cuerpo, calidad según el tiempo
-- hasta el contacto y velocidad final. Pura y sin estado: la usan igual el servidor (BallHitService, que decide)
-- y el cliente (BallHitController, que predice y dibuja el anillo). Coordenadas LOCALES de la cancha.
-- Zonas (altura de la pelota menos la del HumanoidRootPart): Foot (falta por pie), Knee, Hip, Elbow; por encima
-- de Elbow, fuera de alcance. Calidades: Perfect, Good, Weak (con pulsación) y Passive (roce sin pulsar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
-- "boost" (Golpe de yugo, BallHit.boostOf): multiplica la rapidez, sin pasar de Data.MaxSpeed.
function BallHit.velocity(zone: string, quality: string, lookDir: Vector3, rivalSign: number, boost: number?): Vector3
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
	speed = math.min(speed * (boost or 1), Data.MaxSpeed)
	return Vector3.new(direction.X * math.cos(radians), math.sin(radians), direction.Z * math.cos(radians)) * speed
end

-- true si el efecto de habilidad de "attribute" (hora del servidor en que caduca) sigue en marcha. "spent": el
-- valor del atributo que el cliente ya gastó en un golpe y el servidor aún no ha limpiado.
local function effectActive(player: Player, attribute: string, spent: number?): boolean
	local expiry = player:GetAttribute(attribute)
	return typeof(expiry) == "number" and expiry ~= spent and Workspace:GetServerTimeNow() < expiry
end

-- Multiplicador de rapidez del golpe de "player" (Golpe de yugo, Fase 26f): solo los golpes con pulsación y no la
-- falta de pie. 1 si no hay yugo. El servidor lo gasta al golpear (BallHitService).
function BallHit.boostOf(player: Player, zone: string, quality: string, spentYoke: number?): number
	if zone == "Foot" or quality == "Passive" then
		return 1
	end
	return if effectActive(player, Data.Attributes.Yoke, spentYoke) then Data.Yoke.SpeedMultiplier else 1
end

-- Segundos de curva que da el golpe de "player" a la pelota (Viento, Fase 26f): 0 si no hay viento, y tampoco en
-- el roce ni en la falta de pie.
function BallHit.curveOf(player: Player, zone: string, quality: string): number
	if zone == "Foot" or quality == "Passive" then
		return 0
	end
	return if effectActive(player, Data.Attributes.Wind, nil) then Data.Wind.CurveSeconds else 0
end

-- Equipo que ataca hacia +X (el que defiende X < 0) -> +1; el otro, -1.
function BallHit.rivalSign(teamId: string?): number
	return if teamId == "Quetzal" then -1 else 1
end

return BallHit
