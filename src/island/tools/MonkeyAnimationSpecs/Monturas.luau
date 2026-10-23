--!strict
-- Animaciones de las monturas (Shared/MountModels): de momento, la Llama Andina. Cada spec lleva
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

return {
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
