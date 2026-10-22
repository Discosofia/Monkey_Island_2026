--!strict
-- Animaciones de los emotes propios (Fase 9, G11c), una por emote de Data/Cosmetics (la clave es el id
-- del cosmético). Mismo formato que ServerStorage.Tools.PlayerAnimationBuilder (R15): poses { x, y, z }
-- en grados en el espacio de la pieza de la que cuelga cada una, o { x, y, z, px, py, pz } con un
-- desplazamiento en studs; "reposo" pone a 0 lo que no nombra; "marcador" añade un KeyframeMarker, que
-- es cuando sale su efecto (Shared/UI/EmoteFx). En el R15: brazo o muslo hacia delante con X+, el codo
-- se dobla con X+ y la rodilla con X−, el torso se echa adelante con X− y la cabeza mira arriba con X+;
-- el brazo derecho se abre con Z+ y el izquierdo con Z−. El suelo queda 3,19 studs bajo la raíz.
-- "card": el instante de la pose que sale en la imagen del pase y del Armario (Shared/RewardModels).
-- PlayerAnimationBuilder.build() las deja en ReplicatedStorage.EmoteAnimations; en Studio se usan
-- mientras el "animationId" del emote esté vacío (Shared/EmoteTracks). Para el juego publicado: clic
-- derecho > Save to Roblox (mismo dueño que el juego) y el id va al "animationId" de Data/Cosmetics.

export type Spec = {
	name: string,
	loop: boolean?,
	easing: string?,
	direction: string?,
	card: number,
	keyframes: { { [string]: any } },
}

-- Piernas abiertas y dobladas (las dos a la vez): "open" las separa hacia fuera.
local function stance(frame: { [string]: any }, drop: number, thigh: number, knee: number, foot: number, open: number)
	frame.LowerTorso = frame.LowerTorso or { 0, 0, 0, 0, -drop, 0 }
	frame.RightUpperLeg = { thigh, 0, open }
	frame.RightLowerLeg = { knee, 0, -open }
	frame.RightFoot = { foot, 0, 0 }
	frame.LeftUpperLeg = { thigh, 0, -open }
	frame.LeftLowerLeg = { knee, 0, open }
	frame.LeftFoot = { foot, 0, 0 }
	return frame
end

-- Grito de gorila: puño derecho o izquierdo contra el pecho ("side" 1 o -1), el otro separado.
local function poundPose(t: number, side: number, marker: string?): { [string]: any }
	local hit, back = { 25, 70, 0 }, { 50, 30, 30 }
	local hitArm, backArm = { 125, 0, 0 }, { 95, 0, 0 }
	local right = side == 1
	return stance({
		t = t,
		marcador = marker,
		UpperTorso = { -6, 0, 0 },
		Head = { 8, 0, 0 },
		RightUpperArm = if right then hit else back,
		RightLowerArm = if right then hitArm else backArm,
		LeftUpperArm = if right then { back[1], -back[2], -back[3] } else { hit[1], -hit[2], -hit[3] },
		LeftLowerArm = if right then backArm else hitArm,
	}, 0.3, 30, -50, 20, 18)
end

-- Grito de gorila: brazos en alto y abiertos con la cabeza atrás, rugiendo. "tremble" -1/0/1 tiembla.
local function roarPose(t: number, tremble: number, marker: string?): { [string]: any }
	return stance({
		t = t,
		marcador = marker,
		UpperTorso = { 8 + 2 * tremble, 0, 0 },
		Head = { 25 + 3 * tremble, 0, 0 },
		RightUpperArm = { -20, 0, 118 + 4 * tremble },
		RightLowerArm = { 0, 0, 25 },
		LeftUpperArm = { -20, 0, -118 - 4 * tremble },
		LeftLowerArm = { 0, 0, -25 },
	}, 0.3, 30, -50, 20, 18)
end

local function gorillaRoar(): { { [string]: any } }
	local frames: { { [string]: any } } = { { t = 0, reposo = true } }
	table.insert(frames, poundPose(0.2, -1))
	-- Cuatro golpes en el pecho, alternando el puño.
	local side, t = 1, 0.35
	for _ = 1, 4 do
		table.insert(frames, poundPose(t, side, "Golpe"))
		table.insert(frames, poundPose(t + 0.1, -side))
		side, t = -side, t + 0.2
	end
	table.insert(frames, roarPose(1.25, 0, "Rugido"))
	local tremble = 1
	t = 1.32
	while t < 2.0 do
		table.insert(frames, roarPose(t, tremble))
		tremble, t = -tremble, t + 0.07
	end
	table.insert(frames, roarPose(2.05, 0))
	table.insert(frames, { t = 2.5, reposo = true })
	return frames
end

-- Danza del fuego: pisotón con una pierna ("side" 1 derecha, -1 izquierda), con la mano de ese lado en
-- alto y la otra abierta a la altura del hombro, como si llevaran el fuego; el torso gira hacia ella.
local function stompPose(t: number, side: number, marker: string?): { [string]: any }
	local high, highArm = { 172, 0, 12 }, { 10, 0, 0 }
	local low, lowArm = { 10, 0, 80 }, { 0, 0, 40 }
	local right = side == 1
	return stance({
		t = t,
		marcador = marker,
		UpperTorso = { -5, 15 * side, -8 * side },
		Head = { 15, 0, 6 * side },
		RightUpperArm = if right then high else low,
		RightLowerArm = if right then highArm else lowArm,
		LeftUpperArm = if right then { low[1], -low[2], -low[3] } else { high[1], -high[2], -high[3] },
		LeftLowerArm = if right then lowArm else highArm,
	}, 0.4, 35, -60, 25, 8)
end

-- Danza del fuego: la rodilla de "side" sube antes del pisotón.
local function kneePose(t: number, side: number): { [string]: any }
	local frame = stompPose(t, -side)
	frame.LowerTorso = { 0, 0, 0, 0, 0.05, 0 }
	local up, down = if side == 1 then "Right" else "Left", if side == 1 then "Left" else "Right"
	frame[`{up}UpperLeg`] = { 100, 0, 0 }
	frame[`{up}LowerLeg`] = { -100, 0, 0 }
	frame[`{up}Foot`] = { 0, 0, 0 }
	frame[`{down}UpperLeg`] = { 12, 0, 0 }
	frame[`{down}LowerLeg`] = { -22, 0, 0 }
	frame[`{down}Foot`] = { 10, 0, 0 }
	return frame
end

-- Erupción: agachado del todo, con las manos casi en el suelo. "tremble" -1/0/1 tiembla.
local function crouchPose(t: number, tremble: number, marker: string?): { [string]: any }
	return stance({
		t = t,
		marcador = marker,
		LowerTorso = { -15, 0, 2 * tremble, 0, -0.8 - 0.04 * math.abs(tremble), 0 },
		UpperTorso = { -20, 0, 3 * tremble },
		Head = { 10, 0, 0 },
		RightUpperArm = { 25, 0, 18 + 3 * tremble },
		RightLowerArm = { 25, 0, 0 },
		LeftUpperArm = { 25, 0, -18 + 3 * tremble },
		LeftLowerArm = { 25, 0, 0 },
	}, 0.8, 85, -115, 30, 12)
end

-- Erupción: brazos en V muy abiertos y cabeza atrás, en el aire ("lift" studs) o al caer.
local function burstPose(t: number, lift: number, marker: string?): { [string]: any }
	local airborne = lift > 0
	return stance({
		t = t,
		marcador = marker,
		LowerTorso = { 5, 0, 0, 0, lift, 0 },
		UpperTorso = { 8, 0, 0 },
		Head = { 22, 0, 0 },
		RightUpperArm = { -20, 0, 145 },
		RightLowerArm = { 0, 0, 10 },
		LeftUpperArm = { -20, 0, -145 },
		LeftLowerArm = { 0, 0, -10 },
	}, -lift, if airborne then -15 else 10, if airborne then -50 else -15, if airborne then 20 else 5, 14)
end

local function eruption(): { { [string]: any } }
	local frames: { { [string]: any } } = { { t = 0, reposo = true } }
	table.insert(frames, crouchPose(0.3, 0, "Temblor"))
	local tremble, t = 1, 0.36
	while t < 0.95 do
		table.insert(frames, crouchPose(t, tremble))
		tremble, t = -tremble, t + 0.06
	end
	local last = crouchPose(1.0, 0)
	last.direction = "In"
	table.insert(frames, last)
	table.insert(frames, burstPose(1.15, 1.3, "Erupcion"))
	table.insert(frames, burstPose(1.35, 1.5))
	-- Cae con las rodillas dobladas.
	local land = burstPose(1.6, 0)
	land.LowerTorso = { -5, 0, 0, 0, -0.3, 0 }
	table.insert(frames, stance(land, 0.3, 30, -50, 20, 14))
	table.insert(frames, burstPose(1.95, 0))
	table.insert(frames, { t = 2.4, reposo = true })
	return frames
end

-- Saludo simio: la mano izquierda rasca la cabeza por encima y la derecha, con el codo fuera, el sobaco
-- (el codo aletea), botando con las rodillas dobladas.
-- "up" alterna el bote (true arriba) y el rascado.
local function monkeyPose(t: number, up: boolean): { [string]: any }
	local scratch = if up then 12 else -12
	return stance({
		t = t,
		UpperTorso = { -8, 0, if up then 4 else -4 },
		Head = { if up then 12 else 0, 0, if up then -8 else 8 },
		LeftUpperArm = { -10, 0, -168 },
		LeftLowerArm = { 0, 0, 110 + scratch },
		RightUpperArm = { 0, 0, 90 + scratch },
		RightLowerArm = { 0, 0, -160 },
	}, if up then 0.25 else 0.45, if up then 22 else 35, if up then -40 else -62, if up then 18 else 27, 10)
end

local function monkeySalute(): { { [string]: any } }
	local frames: { { [string]: any } } = { { t = 0, reposo = true } }
	local up, t = false, 0.25
	while t < 1.9 do
		table.insert(frames, monkeyPose(t, up))
		up, t = not up, t + 0.18
	end
	table.insert(frames, { t = 2.3, reposo = true })
	return frames
end

local EmoteAnimations: { [string]: Spec } = {
	EmoteMonkeySalute = {
		name = "EmoteMonkeySalute",
		easing = "Cubic",
		direction = "InOut",
		card = 0.43,
		keyframes = monkeySalute(),
	},
	EmoteGorillaRoar = {
		name = "EmoteGorillaRoar",
		easing = "Cubic",
		direction = "Out",
		card = 1.25,
		keyframes = gorillaRoar(),
	},
	-- En bucle: dos pisotones por vuelta (la rueda la para al moverte).
	EmoteFireDance = {
		name = "EmoteFireDance",
		loop = true,
		easing = "Cubic",
		direction = "InOut",
		card = 0.5,
		keyframes = {
			stompPose(0, -1),
			kneePose(0.25, 1),
			stompPose(0.5, 1, "Pisada"),
			kneePose(0.75, -1),
			stompPose(1, -1, "Pisada"),
		},
	},
	EmoteEruption = {
		name = "EmoteEruption",
		easing = "Cubic",
		direction = "Out",
		card = 1.15,
		keyframes = eruption(),
	},
}

return EmoteAnimations
