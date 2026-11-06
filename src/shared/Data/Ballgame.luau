--!strict
-- Números de la pelota del Juego de pelota de Dunas (Fase 26c). Los lee Shared/BallSim (la simulación, igual
-- en el servidor y en el cliente), el servicio de la pelota (Dunas/Services/BallService) y su controlador.
-- Unidades: studs y segundos. La escala de la cancha es 1 stud ≈ 0,28 m (ver Shared/CourtGeometry).

local Ballgame = {}

-- Gravedad (studs/s²). Más que la de Roblox (196) no: la pelota tiene que flotar lo bastante para que una
-- jugada de cadera dure un segundo y medio y se vea venir. Con 70, un bote desde 10 studs tarda ~0,53 s.
Ballgame.Gravity = 70
-- Arrastre del aire, lineal: la velocidad pierde este porcentaje por segundo (5 %). Casi nada, pero frena
-- los tiros largos de 140 studs/s para que no crucen la cancha sin pasar por ninguna mano.
Ballgame.AirDrag = 0.05

-- Restitución por superficie: la parte de la velocidad normal que vuelve tras el bote. El hule bota mucho:
-- el suelo y los taludes (que son de cal) devuelven 0,72; los muros 0,8 (rebote vivo para jugar con las
-- paredes); los aros de piedra 0,85, para que un roce con el anillo se note y la pelota salga lejos.
Ballgame.Restitution = {
	Floor = 0.72,
	Bench = 0.72,
	Riser = 0.72,
	Talud = 0.72,
	Wall = 0.8,
	EndWall = 0.8,
	HeaderWall = 0.8,
	AlleyEnd = 0.8,
	Ring = 0.85,
} :: { [string]: number }

-- Lo que se conserva de la velocidad tangencial en cada bote (rozamiento al botar, sin giro).
Ballgame.TangentialKeep = 0.92
-- Por debajo de esta velocidad normal (studs/s) la pelota no rebota: se queda en contacto y rueda.
Ballgame.RestSpeed = 2.5
-- Deceleración al rodar por el suelo o la banqueta (studs/s²) hasta pararse.
Ballgame.RollingDecel = 14
-- Velocidad máxima (studs/s): el tope de un remate perfecto; también evita que atraviese nada.
Ballgame.MaxSpeed = 140
-- Los botes con velocidad normal menor que esto no emiten el evento "bounce" (no cuentan para las reglas).
Ballgame.MinBounceSpeed = 3

-- Saque (BallService.serve): la pelota sale del centro del pasillo, a esta altura, con un lob suave hacia el
-- campo del equipo que recibe. Horizontal y Vertical en studs/s; SideSpeed, el desvío máximo a los lados.
Ballgame.Serve = {
	Height = 10,
	Horizontal = 12,
	Vertical = 16,
	SideSpeed = 3,
}

-- Red. El servidor manda el estado a StateHz; el cliente lo avanza con la misma simulación. Si lo dibujado
-- se aparta más de SnapDistance (studs) de lo predicho salta de golpe; si no, el desvío se disuelve en
-- SmoothSeconds. Parada, el servidor repite el estado cada RestResendSeconds (para quien llega tarde).
-- MaxCatchUp: lo máximo (s) que el cliente compensa por la latencia de un paquete.
Ballgame.Net = {
	StateHz = 20,
	SnapDistance = 8,
	SmoothSeconds = 0.15,
	RestResendSeconds = 1,
	MaxCatchUp = 0.3,
}

-- El golpe (Fase 26d). Alturas relativas, zonas y calidades en Shared/BallHit. Valores de partida: se afinan jugando.
-- Pitch: ángulo de salida (grados sobre la horizontal). Speed: rapidez final (studs/s) por zona y calidad; el golpe
-- FIJA la velocidad de la pelota, no la suma.
Ballgame.Hit = {
	Reach = 5.5, -- distancia máxima jugador-pelota para poder golpear (studs)
	ContactDist = 2.6, -- distancia a la que se considera contacto (para medir el tiempo hasta él)
	PerfectSeconds = 0.15,
	GoodSeconds = 0.35,
	CooldownSeconds = 0.45, -- por jugador
	BallCooldownSeconds = 0.15, -- entre cualquier par de golpes sobre la pelota
	PassiveContactDist = 2.2, -- roce sin pulsar
	PassiveSpeed = 12,
	Pitch = { Knee = 22, Hip = 35, Elbow = 55 } :: { [string]: number },
	Speed = {
		Knee = { Perfect = 58, Good = 44, Weak = 16 },
		Hip = { Perfect = 78, Good = 56, Weak = 16 },
		Elbow = { Perfect = 52, Good = 40, Weak = 16 },
	} :: { [string]: { [string]: number } },
	FootSpeed = 10, -- la falta por pie solo patea flojo
	RingLeadSeconds = 0.5, -- el anillo de aviso aparece cuando falta esto o menos para el contacto
	-- Límites de la altura de la pelota respecto al HumanoidRootPart (studs) que separan las zonas.
	ZoneFoot = -2.2,
	ZoneKnee = -0.6,
	ZoneHip = 1.4,
	ZoneElbow = 3.5,
	WalkSpeed = 16, -- velocidad con la que se amplía el alcance por el lag del servidor
}

-- Apariencia: hule casi negro con un tono marrón; la sombra se aclara con la altura hasta ShadowMaxHeight.
Ballgame.BallColor = Color3.fromRGB(34, 28, 30)
Ballgame.BallMaterial = Enum.Material.SmoothPlastic
Ballgame.ShadowMaxHeight = 30

return Ballgame
