--!strict
-- Números de la pelota del Juego de pelota de Dunas (Fase 26c). Los lee Shared/BallSim (la simulación, igual
-- en el servidor y en el cliente), el servicio de la pelota (Dunas/Services/BallService) y su controlador.
-- Unidades: studs y segundos. La escala de la cancha es 1 stud ≈ 0,28 m (ver Shared/CourtGeometry).

local Strings = require(script.Parent.Parent.Strings)
local Roles = require(script.Parent.Roles)

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
	-- Pruebas (saque lento y BallPlace «mine»/«rival»): la pelota se deja quieta a esta holgura sobre el suelo.
	RestClearance = 0.01,
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

-- Habilidades de rol del Juego de pelota (Fase 26f). En este modo cada rol solo tiene UNA, en el hueco 1 (Z, el
-- botón 1 del móvil, R1 + A): Shared/RoleAbilities.of las da en lugar de las cinco de Data/Roles. No hacen daño.
-- Los números de cada una (recarga arriba; efecto en Yoke, JaguarLeap, Wind y LightStep) son de partida.
Ballgame.Abilities = {
	Guerrero = {
		id = "Yoke",
		name = "Golpe de yugo",
		short = "Yugo",
		description = "Tu siguiente golpe a la pelota sale mucho más fuerte.",
		cooldownSeconds = 8,
		castSeconds = 0,
	},
	Cazador = {
		id = "JaguarLeap",
		name = "Salto de jaguar",
		short = "Salto",
		description = "Das un gran salto para llegar a las pelotas altas.",
		cooldownSeconds = 6,
		castSeconds = 0,
	},
	Mago = {
		id = "Wind",
		name = "Viento",
		short = "Viento",
		description = "Durante un momento, tus golpes dan una curva leve a la pelota.",
		cooldownSeconds = 10,
		castSeconds = 0,
	},
	Medico = {
		id = "LightStep",
		name = "Paso ligero",
		short = "Paso",
		description = "Corres más rápido durante un momento.",
		cooldownSeconds = 8,
		castSeconds = 0,
	},
} :: { [string]: Roles.Ability }

-- Atributos del Player (hora del servidor en que caduca cada efecto) que publica AbilityService y leen el
-- servidor (BallHitService) y el cliente (Shared/BallHit, BallHitController, LocomotionController).
Ballgame.Attributes = {
	Yoke = "BallYoke",
	Wind = "BallWind",
	LightStep = "BallLightStep",
}

-- Golpe de yugo: el siguiente golpe de pelota sale con la velocidad multiplicada (sin pasar de MaxSpeed). Se
-- gasta al golpear (no el roce) o caduca a los ExpireSeconds.
Ballgame.Yoke = {
	SpeedMultiplier = 1.4,
	ExpireSeconds = 5,
}

-- Salto de jaguar: velocidad vertical (studs/s) que se da al personaje; con la gravedad de Roblox (196) sube
-- unos 14 studs, el triple de un salto normal.
Ballgame.JaguarLeap = {
	VerticalSpeed = 75,
}

-- Viento: Seconds, lo que dura el efecto tras lanzarlo; en ese tiempo, cada golpe propio deja la pelota curvando
-- CurveSeconds, con una aceleración lateral de CurveAccel (studs/s²) hacia la DERECHA del sentido en que viaja
-- (BallSim.step; regla fija para que servidor y cliente simulen igual).
Ballgame.Wind = {
	Seconds = 1,
	CurveSeconds = 1.2,
	CurveAccel = 14,
}

-- Paso ligero: la velocidad al andar y correr sube SpeedBonus (fracción) durante Seconds.
Ballgame.LightStep = {
	SpeedBonus = 0.35,
	Seconds = 2,
}

-- Avisos de raya (Fase 26g): la plantilla de cada clave de ReplicatedStorage "BallgameCall" (el equipo que
-- anota va en {icon} {name}). El servidor la manda por Notify y el cliente (BallgameHUD) la dibuja con T().
-- "Time" (fin por tiempo o por abandono) no lleva aviso propio.
Ballgame.Calls = {
	ThreeBounces = Strings.later("¡Tres botes! Raya para {icon} {name}"),
	Out = Strings.later("¡Fuera! Raya para {icon} {name}"),
	Foot = Strings.later("¡Falta de pie! Raya para {icon} {name}"),
	RingMiss = Strings.later("¡Falló el aro! Raya para {icon} {name}"),
	EndWall = Strings.later("¡Muro del fondo! Raya para {icon} {name}"),
	OwnEndWall = Strings.later("¡Contra su propio muro! Raya para {icon} {name}"),
	Stalled = Strings.later("¡Pelota parada! Raya para {icon} {name}"),
	Ring = Strings.later("¡Aro! Gana {icon} {name}"),
} :: { [string]: string }

-- Celebración del aro (Fase 27f; Dunas/Client/BallReplayController): confeti y plumas con la paleta del equipo que
-- anota (Jaguar, rojo y amarillo; Quetzal, jade y negro). PerSecond: piezas por segundo (el tope de vivas es
-- Config.Budgets.BallgameConfetti); Fall: segundos que tardan en caer; Height: altura sobre el suelo de la que salen.
Ballgame.Celebration = {
	PerSecond = 30,
	Fall = NumberRange.new(1.6, 2.4),
	Height = 26,
	Palettes = {
		Jaguar = { Color3.fromRGB(215, 55, 40), Color3.fromRGB(250, 205, 60) },
		Quetzal = { Color3.fromRGB(40, 175, 120), Color3.fromRGB(25, 25, 28) },
	} :: { [string]: { Color3 } },
}

-- Apariencia: hule casi negro con un tono marrón; la sombra se aclara con la altura hasta ShadowMaxHeight.
Ballgame.BallColor = Color3.fromRGB(34, 28, 30)
Ballgame.BallMaterial = Enum.Material.SmoothPlastic
Ballgame.ShadowMaxHeight = 30

-- Deslizamiento del talud (Fase 27a; Dunas/Client/Controllers/TaludSlideController). El talud es de ~25° y el jugador
-- que pisa (o salta sobre) él resbala hacia el pasillo. SlideSpeed: studs/s A LO LARGO de la pendiente (unos 18
-- en horizontal): andando a 18 no se avanza, corriendo a 26 se sube despacio. MaxForceFactor: fuerza máxima del
-- empuje = masa del personaje x este número (la misma que usan la esquiva y el hielo).
Ballgame.Talud = {
	SlideSpeed = 20,
	MaxForceFactor = 3000,
}

-- Rivales de prueba (Fase 27b; Dunas/Services/BallBotService, solo Studio): muñecos que devuelven la pelota para poder
-- probar el partido en solitario. Speed: studs/s con que van a la pelota. ReactionSeconds: lo que tardan en golpear desde
-- que la pelota entra en su alcance. Quality: calidad del golpe (Perfect, Good, Weak). ReturnSeconds: tras golpear,
-- segundos en que el bot descansa (vuelve a su sitio) antes de poder ir otra vez a la pelota.
Ballgame.Bot = {
	Speed = 14,
	ReactionSeconds = 0.06, -- poco: una pelota rápida cruza su alcance en ~0,2 s
	Quality = "Good",
	ReturnSeconds = 1,
}

return Ballgame
