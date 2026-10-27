--!strict
-- Animaciones de las monturas (Shared/MountModels): la Llama Andina y el Jaguar. Cada spec lleva
-- "parents", la jerarquía de huesos de la montura, porque no es la de los monos. Ver
-- MonkeyAnimationBuilder para el formato. Los ángulos son los de CFrame.Angles en el espacio del
-- hueso padre: en las patas (cuelgan hacia abajo), X positivo lleva la pezuña adelante; en el
-- cuello, la cabeza, las orejas y la cola (apuntan hacia arriba), X positivo los echa atrás; en la
-- mandíbula (delante de su articulación), X negativo abre la boca.
--   - Llama_Run: galope de 0,6 s en bucle (prioridad Movement). Las patas van con seno y las cañas se
--     doblan mientras la pata vuelve adelante (las de delante con la pezuña atrás, las de atrás por
--     el corvejón, con la pezuña adelante).
--   - Llama_Idle: parada rumiando (3,2 s en bucle): seis masticadas de lado, una sacudida de oreja,
--     un coletazo y el cuello que se mece despacio.
--   - Llama_Spit: escupitajo (1 s). Pega las orejas atrás, coge aire echando la cabeza atrás y lanza
--     el cuello adelante con la boca abierta en el marcador "Escupir" (0,45 s): ahí quien la
--     reproduce llama a MountModels.spit, que suelta las partículas.
--   - Llama_Jump: salto en el sitio (0,9 s; la altura la da la física): se agacha, se impulsa con las
--     patas de atrás, recoge las de delante en el aire y amortigua al caer.

local PARENTS: { [string]: string } = {
	Body = "Root",
	Neck = "Body",
	Head = "Neck",
	Jaw = "Head",
	EarL = "Head",
	EarR = "Head",
	Tail = "Body",
	LegFL = "Body",
	LegFR = "Body",
	LegBL = "Body",
	LegBR = "Body",
	ShinFL = "LegFL",
	ShinFR = "LegFR",
	ShinBL = "LegBL",
	ShinBR = "LegBR",
}

local function round(value: number): number
	return math.round(value * 100) / 100
end

-- Galope: "steps" fotogramas por zancada de "length" s. Cada pata tiene su desfase (las de atrás
-- empujan primero, las de delante caen después) y la caña se dobla en la fase en que la pata avanza.
local function gallop(length: number, steps: number): { { [string]: any } }
	local legs = {
		{ name = "BL", phase = 0, fold = 45 },
		{ name = "BR", phase = 0.08, fold = 45 },
		{ name = "FL", phase = 0.45, fold = -60 },
		{ name = "FR", phase = 0.53, fold = -60 },
	}
	local keyframes = {}
	for i = 0, steps do
		local u = i / steps
		local frame: { [string]: any } = { t = round(length * u) }
		for _, leg in legs do
			local angle = 2 * math.pi * (u - leg.phase)
			frame[`Leg{leg.name}`] = { round(36 * math.sin(angle)), 0, 0 }
			frame[`Shin{leg.name}`] = { round(leg.fold * math.max(0, math.cos(angle))), 0, 0 }
		end
		local wave = math.sin(2 * math.pi * u)
		-- El lomo cabecea y sube tras el empujón de atrás; cuello y cabeza compensan para que la cabeza
		-- vaya casi quieta, adelantada como al correr.
		frame.Body = { round(4 * wave), 0, 0, 0, round(0.12 * math.cos(2 * math.pi * (u - 0.3))), 0 }
		frame.Neck = { round(-14 - 5 * wave), 0, 0 }
		frame.Head = { round(10 + 3 * wave), 0, 0 }
		frame.EarL = { 28, 0, 0 }
		frame.EarR = { 28, 0, 0 }
		frame.Tail = { round(-12 + 10 * math.sin(2 * math.pi * (u - 0.2))), 0, 0 }
		table.insert(keyframes, frame)
	end
	return keyframes
end

-- Masticar rumiando: la mandíbula va de un lado a otro abriéndose un poco al cruzar, como las
-- llamas, y la cabeza acompaña con un cabeceo pequeño.
local function chew(keyframes: { { [string]: any } }, start: number, count: number, period: number)
	for i = 0, count - 1 do
		local t = start + i * period
		table.insert(keyframes, { t = round(t), Jaw = { -2, 12, 3 }, Head = { 1, 0, 0 } })
		table.insert(keyframes, { t = round(t + period / 2), Jaw = { -6, -12, -3 }, Head = { -1, 0, 0 } })
	end
end

local idle: { { [string]: any } } = {}
chew(idle, 0, 6, 0.4)
-- Los fotogramas de masticar solo mueven mandíbula y cabeza; el resto va en sus propios fotogramas.
local extras = {
	{ t = 0, Neck = { 0, 0, 0 }, EarL = { 0, 0, 0 }, EarR = { 0, 0, 0 }, Tail = { 0, 0, 0 } },
	{ t = 1.1, EarR = { 0, 0, 0 } },
	{ t = 1.22, EarR = { 10, 0, -22 } },
	{ t = 1.36, EarR = { 0, 0, 0 } },
	{ t = 1.6, Neck = { -3, 4, 0 } },
	{ t = 1.9, Tail = { 0, 0, 0 } },
	{ t = 2.05, Tail = { 0, 0, 14 } },
	{ t = 2.2, Tail = { 0, 0, -10 } },
	{ t = 2.35, Tail = { 0, 0, 0 } },
	-- Pausa para tragar: la mandíbula se cierra y las orejas giran a escuchar.
	{ t = 2.4, Jaw = { 0, 0, 0 }, Head = { 0, 0, 0 }, EarL = { 0, 0, 0 } },
	{ t = 2.7, EarL = { 0, 18, 0 }, EarR = { 0, -18, 0 }, Head = { 3, 0, 0 } },
	{ t = 3, EarL = { 0, 18, 0 }, EarR = { 0, -18, 0 } },
	{
		t = 3.2,
		Jaw = { -2, 12, 3 },
		Head = { 1, 0, 0 },
		Neck = { 0, 0, 0 },
		EarL = { 0, 0, 0 },
		EarR = { 0, 0, 0 },
		Tail = { 0, 0, 0 },
	},
}
-- Junta los fotogramas que caen en el mismo instante.
local byTime: { [number]: { [string]: any } } = {}
for _, frame in idle do
	byTime[frame.t] = frame
end
for _, frame in extras do
	local existing = byTime[frame.t]
	if existing then
		for key, value in frame do
			existing[key] = value
		end
	else
		byTime[frame.t] = frame
		table.insert(idle, frame)
	end
end
table.sort(idle, function(a, b)
	return a.t < b.t
end)

-- ===== Jaguar Albino Esmeralda (T5a) =====
-- La cola tiene tres tramos (Tail → Tail2 → Tail3) y sale hacia atrás: X negativo la sube. La cabeza
-- y la mandíbula están delante de su articulación: X positivo levanta la cabeza y X negativo abre la
-- boca. El hueso "Aura" no se anima: lo gira MountModels.animateAura.
--   - Jaguar_Run: galope de 0,55 s en bucle, zancada larga de felino: el lomo cabecea, la cabeza va
--     casi quieta y la cola, tendida atrás, ondula con un retraso de tramo a tramo.
--   - Jaguar_Idle: de pie (3,6 s en bucle): respira, la cola ondula en S de lado a lado, gira la
--     cabeza a un lado y vuelve, y sacude una oreja.
--   - Jaguar_Roar: rugido (1,25 s): se agacha, se alza con el pecho arriba y las manos adelante y abre
--     las fauces en el marcador "Rugido" (0,45 s), donde quien la reproduce llama a
--     MountModels.gesture (la onda del aura y los ojos).
--   - Jaguar_Jump: salto (0,9 s; la altura la da la física): se agacha, empuja con las patas de atrás,
--     se estira en el aire con las manos delante y amortigua.

local JAGUAR_PARENTS: { [string]: string } = table.clone(PARENTS)
JAGUAR_PARENTS.Tail2 = "Tail"
JAGUAR_PARENTS.Tail3 = "Tail2"

-- Ola de la cola: cada tramo repite el giro del anterior con retraso, así se dobla en S.
local function tailWave(
	frame: { [string]: any },
	u: number,
	axis: number,
	amplitude: number,
	base: { number },
	lag: number
)
	for i, bone in { "Tail", "Tail2", "Tail3" } do
		local angle = { base[i], 0, 0 }
		angle[axis] += round(amplitude * math.sin(2 * math.pi * (u - (i - 1) * lag)))
		frame[bone] = angle
	end
end

local function jaguarGallop(length: number, steps: number): { { [string]: any } }
	local legs = {
		-- Al recoger la pata, el pie queda detrás de la rodilla (corvejón doblado): las cuatro doblan en
		-- negativo, no como la llama.
		{ name = "BL", phase = 0, fold = -50 },
		{ name = "BR", phase = 0.1, fold = -50 },
		{ name = "FL", phase = 0.5, fold = -70 },
		{ name = "FR", phase = 0.6, fold = -70 },
	}
	local keyframes = {}
	for i = 0, steps do
		local u = i / steps
		local frame: { [string]: any } = { t = round(length * u) }
		for _, leg in legs do
			local angle = 2 * math.pi * (u - leg.phase)
			frame[`Leg{leg.name}`] = { round(40 * math.sin(angle)), 0, 0 }
			frame[`Shin{leg.name}`] = { round(leg.fold * math.max(0, math.cos(angle))), 0, 0 }
		end
		local wave = math.sin(2 * math.pi * u)
		-- Cabeceo y bote pequeños y el lomo algo alzado: con 5° y 0,14 studs, las manos se clavaban
		-- 0,26 studs en el suelo (medido con Anim.measure).
		frame.Body = { round(3 * wave), 0, 0, 0, round(0.08 + 0.06 * math.cos(2 * math.pi * (u - 0.25))), 0 }
		frame.Neck = { round(-4 - 4 * wave), 0, 0 }
		frame.Head = { round(-1 * wave), 0, 0 }
		frame.EarL = { 30, 0, 0 }
		frame.EarR = { 30, 0, 0 }
		-- Cola tendida atrás (sube a la línea del lomo) y ondulando arriba y abajo.
		tailWave(frame, u, 1, 8, { -10, 8, 12 }, 0.15)
		table.insert(keyframes, frame)
	end
	return keyframes
end

local function jaguarIdle(length: number, steps: number): { { [string]: any } }
	local keyframes = {}
	for i = 0, steps do
		local u = i / steps
		local t = round(length * u)
		local frame: { [string]: any } = { t = t }
		-- Respira: el lomo sube y baja dos veces por ciclo.
		frame.Body = { round(0.8 * math.sin(4 * math.pi * u)), 0, 0 }
		frame.Neck = { round(1.5 * math.sin(4 * math.pi * u - 0.6)), 0, 0 }
		-- Mira a un lado entre el 30 % y el 70 % del ciclo y vuelve.
		local look = math.clamp(math.sin(math.pi * math.clamp((u - 0.3) / 0.4, 0, 1)) * 1.4, 0, 1)
		frame.Head = { 0, round(24 * look), round(-4 * look) }
		-- La oreja izquierda se sacude una vez.
		local flick = if math.abs(u - 0.85) < 0.04 then 1 else 0
		frame.EarL = { round(25 * flick), 0, round(-20 * flick) }
		frame.EarR = { 0, 0, 0 }
		-- Cola en S de lado a lado (sobre el eje vertical), despacio.
		tailWave(frame, u, 2, 14, { 0, 0, 0 }, 0.12)
		table.insert(keyframes, frame)
	end
	return keyframes
end

return {
	Jaguar_Run = {
		name = "Jaguar_Run",
		loop = true,
		priority = "Movement",
		easing = "Linear",
		parents = JAGUAR_PARENTS,
		keyframes = jaguarGallop(0.55, 12),
	},
	Jaguar_Idle = {
		name = "Jaguar_Idle",
		loop = true,
		priority = "Idle",
		easing = "Cubic",
		direction = "InOut",
		parents = JAGUAR_PARENTS,
		keyframes = jaguarIdle(3.6, 24),
	},
	Jaguar_Roar = {
		name = "Jaguar_Roar",
		loop = false,
		priority = "Action",
		easing = "Cubic",
		direction = "Out",
		parents = JAGUAR_PARENTS,
		keyframes = {
			{ t = 0, reposo = true },
			-- Se prepara: agacha el pecho y la cabeza, orejas atrás.
			{
				t = 0.2,
				Body = { -3, 0, 0 },
				Neck = { -8, 0, 0 },
				Head = { -6, 0, 0 },
				Jaw = { -4, 0, 0 },
				EarL = { 55, 0, 0 },
				EarR = { 55, 0, 0 },
				LegFL = { -8, 0, 0 },
				LegFR = { -8, 0, 0 },
				ShinFL = { 16, 0, 0 },
				ShinFR = { 16, 0, 0 },
			},
			-- Ruge: se alza con el pecho arriba, las manos adelante y las fauces abiertas.
			{
				t = 0.45,
				marcador = "Rugido",
				Body = { 9, 0, 0, 0, 0.35, 0 },
				Neck = { 12, 0, 0 },
				Head = { 14, 0, 0 },
				Jaw = { -38, 0, 0 },
				EarL = { 65, 0, 0 },
				EarR = { 65, 0, 0 },
				LegFL = { 22, 0, 0 },
				LegFR = { 22, 0, 0 },
				ShinFL = { -18, 0, 0 },
				ShinFR = { -18, 0, 0 },
				LegBL = { -8, 0, 0 },
				LegBR = { -8, 0, 0 },
				Tail = { -18, 0, 0 },
				Tail2 = { 12, 0, 0 },
				Tail3 = { 10, 0, 0 },
			},
			-- Aguanta el rugido sacudiendo un poco la cabeza.
			{
				t = 0.75,
				Body = { 8, 0, 0, 0, 0.32, 0 },
				Neck = { 10, 0, 0 },
				Head = { 12, 6, 0 },
				Jaw = { -34, 0, 0 },
				EarL = { 65, 0, 0 },
				EarR = { 65, 0, 0 },
				LegFL = { 20, 0, 0 },
				LegFR = { 20, 0, 0 },
				ShinFL = { -16, 0, 0 },
				ShinFR = { -16, 0, 0 },
				LegBL = { -8, 0, 0 },
				LegBR = { -8, 0, 0 },
				Tail = { -16, 0, 0 },
				Tail2 = { 10, 0, 0 },
				Tail3 = { 8, 0, 0 },
			},
			-- Baja y cierra la boca.
			{
				t = 1,
				Body = { 1, 0, 0, 0, 0.04, 0 },
				Neck = { 2, 0, 0 },
				Head = { 2, 0, 0 },
				Jaw = { -6, 0, 0 },
				EarL = { 20, 0, 0 },
				EarR = { 20, 0, 0 },
			},
			{ t = 1.25, reposo = true },
		},
	},
	Jaguar_Jump = {
		name = "Jaguar_Jump",
		loop = false,
		priority = "Action",
		easing = "Cubic",
		direction = "InOut",
		parents = JAGUAR_PARENTS,
		keyframes = {
			{ t = 0, reposo = true },
			-- Se agacha: el lomo baja y las patas se doblan con los pies en su sitio.
			{
				t = 0.15,
				Body = { -2, 0, 0, 0, -0.05, 0 },
				Neck = { -6, 0, 0 },
				Head = { 4, 0, 0 },
				EarL = { 30, 0, 0 },
				EarR = { 30, 0, 0 },
				LegFL = { -25, 0, 0 },
				LegFR = { -25, 0, 0 },
				ShinFL = { 50, 0, 0 },
				ShinFR = { 50, 0, 0 },
				LegBL = { 30, 0, 0 },
				LegBR = { 30, 0, 0 },
				ShinBL = { -50, 0, 0 },
				ShinBR = { -50, 0, 0 },
				Tail = { 10, 0, 0 },
			},
			-- Impulso: el pecho sube, las de atrás empujan estiradas y las manos se recogen.
			{
				t = 0.3,
				Body = { 12, 0, 0, 0, 0.15, 0 },
				Neck = { -6, 0, 0 },
				Head = { 2, 0, 0 },
				EarL = { 35, 0, 0 },
				EarR = { 35, 0, 0 },
				LegFL = { 40, 0, 0 },
				LegFR = { 40, 0, 0 },
				ShinFL = { -80, 0, 0 },
				ShinFR = { -80, 0, 0 },
				LegBL = { -40, 0, 0 },
				LegBR = { -40, 0, 0 },
				ShinBL = { 10, 0, 0 },
				ShinBR = { 10, 0, 0 },
				Tail = { -10, 0, 0 },
				Tail2 = { 10, 0, 0 },
			},
			-- En el aire: estirado, manos delante y patas atrás, la cola de timón.
			{
				t = 0.5,
				Body = { 0, 0, 0, 0, 0.12, 0 },
				Neck = { -4, 0, 0 },
				Head = { 2, 0, 0 },
				EarL = { 35, 0, 0 },
				EarR = { 35, 0, 0 },
				LegFL = { 55, 0, 0 },
				LegFR = { 55, 0, 0 },
				ShinFL = { -25, 0, 0 },
				ShinFR = { -25, 0, 0 },
				LegBL = { -45, 0, 0 },
				LegBR = { -45, 0, 0 },
				ShinBL = { 25, 0, 0 },
				ShinBR = { 25, 0, 0 },
				Tail = { -18, 0, 0 },
				Tail2 = { 6, 0, 0 },
				Tail3 = { 6, 0, 0 },
			},
			-- Cae de manos: las de delante reciben el peso y las de atrás vuelven bajo el cuerpo.
			{
				t = 0.65,
				Body = { -3, 0, 0 },
				Neck = { 3, 0, 0 },
				Head = { 0, 0, 0 },
				EarL = { 20, 0, 0 },
				EarR = { 20, 0, 0 },
				LegFL = { 20, 0, 0 },
				LegFR = { 20, 0, 0 },
				ShinFL = { -8, 0, 0 },
				ShinFR = { -8, 0, 0 },
				LegBL = { 15, 0, 0 },
				LegBR = { 15, 0, 0 },
				ShinBL = { -20, 0, 0 },
				ShinBR = { -20, 0, 0 },
				Tail = { -8, 0, 0 },
			},
			-- Amortigua.
			{
				t = 0.75,
				Body = { -1, 0, 0 },
				Neck = { 5, 0, 0 },
				LegFL = { -18, 0, 0 },
				LegFR = { -18, 0, 0 },
				ShinFL = { 36, 0, 0 },
				ShinFR = { 36, 0, 0 },
				LegBL = { 20, 0, 0 },
				LegBR = { 20, 0, 0 },
				ShinBL = { -36, 0, 0 },
				ShinBR = { -36, 0, 0 },
			},
			{ t = 0.9, reposo = true },
		},
	},
	Llama_Run = {
		name = "Llama_Run",
		loop = true,
		priority = "Movement",
		easing = "Linear",
		parents = PARENTS,
		keyframes = gallop(0.6, 12),
	},
	Llama_Idle = {
		name = "Llama_Idle",
		loop = true,
		priority = "Idle",
		easing = "Cubic",
		direction = "InOut",
		parents = PARENTS,
		keyframes = idle,
	},
	Llama_Spit = {
		name = "Llama_Spit",
		loop = false,
		priority = "Action",
		easing = "Cubic",
		direction = "Out",
		parents = PARENTS,
		keyframes = {
			{ t = 0, reposo = true },
			{ t = 0.15, EarL = { 60, 0, 0 }, EarR = { 60, 0, 0 } },
			-- Coge aire: cuello y hocico atrás y arriba.
			{
				t = 0.32,
				Body = { 3, 0, 0 },
				Neck = { 14, 0, 0 },
				Head = { 16, 0, 0 },
				Jaw = { 0, 0, 0 },
				EarL = { 60, 0, 0 },
				EarR = { 60, 0, 0 },
			},
			-- Escupe: cuello lanzado adelante y boca abierta.
			{
				t = 0.45,
				marcador = "Escupir",
				Body = { -2, 0, 0 },
				Neck = { -20, 0, 0 },
				Head = { 6, 0, 0 },
				Jaw = { -26, 0, 0 },
				EarL = { 60, 0, 0 },
				EarR = { 60, 0, 0 },
			},
			{
				t = 0.62,
				Body = { -1, 0, 0 },
				Neck = { -15, 0, 0 },
				Head = { -2, 0, 0 },
				Jaw = { -12, 0, 0 },
				EarL = { 55, 0, 0 },
				EarR = { 55, 0, 0 },
			},
			{ t = 1, reposo = true },
		},
	},
	Llama_Jump = {
		name = "Llama_Jump",
		loop = false,
		priority = "Action",
		easing = "Cubic",
		direction = "InOut",
		parents = PARENTS,
		keyframes = {
			{ t = 0, reposo = true },
			-- Se agacha: el lomo baja y las patas se doblan con las pezuñas en su sitio.
			{
				t = 0.15,
				Body = { -3, 0, 0, 0, -0.18, 0 },
				Neck = { 6, 0, 0 },
				LegFL = { 30, 0, 0 },
				LegFR = { 30, 0, 0 },
				ShinFL = { -60, 0, 0 },
				ShinFR = { -60, 0, 0 },
				LegBL = { -30, 0, 0 },
				LegBR = { -30, 0, 0 },
				ShinBL = { 60, 0, 0 },
				ShinBR = { 60, 0, 0 },
			},
			-- Impulso: el pecho se levanta, las de atrás empujan estiradas y las de delante se recogen.
			{
				t = 0.3,
				Body = { 10, 0, 0, 0, 0.1, 0 },
				Neck = { -10, 0, 0 },
				Head = { 5, 0, 0 },
				EarL = { 25, 0, 0 },
				EarR = { 25, 0, 0 },
				Tail = { -20, 0, 0 },
				LegFL = { 45, 0, 0 },
				LegFR = { 45, 0, 0 },
				ShinFL = { -90, 0, 0 },
				ShinFR = { -90, 0, 0 },
				LegBL = { -35, 0, 0 },
				LegBR = { -35, 0, 0 },
				ShinBL = { 0, 0, 0 },
				ShinBR = { 0, 0, 0 },
			},
			-- En el aire: todo recogido.
			{
				t = 0.5,
				Body = { 0, 0, 0, 0, 0.1, 0 },
				Neck = { -6, 0, 0 },
				Head = { 3, 0, 0 },
				EarL = { 25, 0, 0 },
				EarR = { 25, 0, 0 },
				Tail = { -15, 0, 0 },
				LegFL = { 40, 0, 0 },
				LegFR = { 40, 0, 0 },
				ShinFL = { -80, 0, 0 },
				ShinFR = { -80, 0, 0 },
				LegBL = { -10, 0, 0 },
				LegBR = { -10, 0, 0 },
				ShinBL = { 60, 0, 0 },
				ShinBR = { 60, 0, 0 },
			},
			-- Cae de manos: las de delante se estiran adelante para recibir el peso.
			{
				t = 0.65,
				Body = { -6, 0, 0 },
				Neck = { 4, 0, 0 },
				Head = { 0, 0, 0 },
				EarL = { 15, 0, 0 },
				EarR = { 15, 0, 0 },
				Tail = { -8, 0, 0 },
				LegFL = { 22, 0, 0 },
				LegFR = { 22, 0, 0 },
				ShinFL = { -10, 0, 0 },
				ShinFR = { -10, 0, 0 },
				LegBL = { 12, 0, 0 },
				LegBR = { 12, 0, 0 },
				ShinBL = { 20, 0, 0 },
				ShinBR = { 20, 0, 0 },
			},
			-- Amortigua.
			{
				t = 0.75,
				Body = { -2, 0, 0, 0, -0.1, 0 },
				Neck = { 7, 0, 0 },
				LegFL = { 25, 0, 0 },
				LegFR = { 25, 0, 0 },
				ShinFL = { -50, 0, 0 },
				ShinFR = { -50, 0, 0 },
				LegBL = { -25, 0, 0 },
				LegBR = { -25, 0, 0 },
				ShinBL = { 50, 0, 0 },
				ShinBR = { 50, 0, 0 },
			},
			{ t = 0.9, reposo = true },
		},
	},
}
