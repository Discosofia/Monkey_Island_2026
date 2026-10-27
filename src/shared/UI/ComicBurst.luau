--!strict
-- Estallido de cómic de los efectos de combate ("BAM!", "POW!", "K.O.!", "OUCH!"): estrellas de picos
-- con trama de puntos, rayos, nubecitas, estrellitas y una palabra en letra de cómic (Bangers) con
-- borde de color, borde negro y sombra. Los dibujos están en blanco y negro en un atlas
-- (art/ui/comic/gen.py) y aquí se tiñen con ImageColor3: el blanco toma el color y el negro se queda.
-- Va dentro de cualquier marco cuadrado: un BillboardGui sobre un enemigo (ComicFxController) o la
-- vista previa de Ajustes (UI/SettingsPanel). Dura menos de un segundo y se borra solo.
-- Estilos de estallido (cosmético BurstStyle, STYLES): cambian los colores de tus golpes ("Hit",
-- "Crit", "KO"), el de las nubecitas y, si quieren, las palabras. El "Hurt" (lo que te pegan) es
-- siempre rojo: es el color del daño del juego.
-- La guardia (Fase 10, C12) tiene los suyos, iguales con cualquier estilo: "¡PARRY!" dorado (el color del
-- parry), "¡GUARDIA ROTA!" naranja con el centro oscuro de la rotura y "¡CONTRA!" (el golpe que castiga
-- al que acabas de parar) crema con el centro y la letra dorados.

local TweenService = game:GetService("TweenService")

local Strings = require(script.Parent.Parent.Strings)

local ATLAS = "rbxassetid://106987700658195"
-- Celdas del atlas en píxeles: { x, y, ancho, alto } (las mismas que en gen.py).
local CELLS: { [string]: { number } } = {
	burstA = { 0, 0, 512, 512 },
	burstB = { 512, 0, 512, 512 },
	rays = { 0, 512, 512, 512 },
	puff = { 512, 512, 256, 256 },
	star = { 768, 512, 256, 256 },
}
local BANGERS = Font.fromEnum(Enum.Font.Bangers)
local BLACK = Color3.new(0, 0, 0)
local POP = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_SECONDS = 0.14

export type Kind = "Hit" | "Crit" | "KO" | "Hurt" | "Parry" | "GuardBroken" | "Counter"
-- Con qué se golpea: cambia la palabra ("BAM!" / "PEW!" / "ZAP!").
export type Weapon = "Melee" | "Ranged" | "Spell"

type Look = {
	life: number, -- segundos en pantalla
	outer: Color3, -- estrella de fondo
	outerSize: number, -- parte del marco que ocupa
	inner: Color3?, -- segunda estrella encima, más pequeña (crítico, KO y recibir)
	rays: Color3?, -- rayos detrás de todo
	puffs: number, -- nubecitas que salen disparadas
	stars: number, -- estrellitas alrededor
	star: Color3,
	text: Color3,
	edge: Color3, -- borde de la letra (por fuera va otro negro)
	textHeight: number, -- alto de la palabra respecto al marco
}

-- Nubecitas de serie (crema).
local PUFF = Color3.fromRGB(255, 250, 235)

local LOOKS: { [Kind]: Look } = {
	-- Golpe normal: sale mucho, así que es pequeño, claro y sin adornos.
	Hit = {
		life = 0.32,
		outer = Color3.fromRGB(255, 235, 140),
		outerSize = 0.82,
		puffs = 0,
		stars = 0,
		star = Color3.fromRGB(255, 215, 40),
		text = Color3.fromRGB(255, 255, 255),
		edge = Color3.fromRGB(230, 90, 30),
		textHeight = 0.36,
	},
	-- Crítico: el "POW!" de la imagen de referencia.
	Crit = {
		life = 0.5,
		outer = Color3.fromRGB(255, 140, 30),
		outerSize = 0.84,
		inner = Color3.fromRGB(255, 215, 40),
		rays = Color3.fromRGB(255, 240, 170),
		puffs = 3,
		stars = 3,
		star = Color3.fromRGB(255, 215, 40),
		text = Color3.fromRGB(255, 230, 40),
		edge = Color3.fromRGB(220, 40, 30),
		textHeight = 0.3,
	},
	KO = {
		life = 0.65,
		outer = Color3.fromRGB(220, 40, 30),
		outerSize = 0.88,
		inner = Color3.fromRGB(255, 185, 30),
		rays = Color3.fromRGB(255, 220, 120),
		puffs = 4,
		stars = 4,
		star = Color3.fromRGB(255, 230, 40),
		text = Color3.fromRGB(255, 255, 255),
		edge = Color3.fromRGB(200, 30, 20),
		textHeight = 0.34,
	},
	-- Golpe fuerte que recibes: rojo, el color de "daño" del juego.
	Hurt = {
		life = 0.45,
		outer = Color3.fromRGB(235, 70, 60),
		outerSize = 0.84,
		inner = Color3.fromRGB(255, 215, 205),
		puffs = 2,
		stars = 0,
		star = Color3.fromRGB(255, 215, 40),
		text = Color3.fromRGB(255, 255, 255),
		edge = Color3.fromRGB(170, 20, 20),
		textHeight = 0.3,
	},
	-- La guardia: palabras largas, así que la letra es más baja.
	Parry = {
		life = 0.55,
		outer = Color3.fromRGB(255, 205, 60),
		outerSize = 0.86,
		inner = Color3.fromRGB(255, 245, 205),
		rays = Color3.fromRGB(255, 235, 150),
		puffs = 0,
		stars = 4,
		star = Color3.fromRGB(255, 250, 225),
		text = Color3.fromRGB(255, 255, 255),
		edge = Color3.fromRGB(165, 105, 10),
		textHeight = 0.26,
	},
	GuardBroken = {
		life = 0.6,
		outer = Color3.fromRGB(255, 130, 40),
		outerSize = 0.88,
		inner = Color3.fromRGB(90, 40, 15),
		puffs = 3,
		stars = 0,
		star = Color3.fromRGB(255, 130, 40),
		text = Color3.fromRGB(255, 225, 170),
		edge = Color3.fromRGB(150, 50, 5),
		textHeight = 0.22,
	},
	Counter = {
		life = 0.55,
		outer = Color3.fromRGB(255, 248, 230),
		outerSize = 0.86,
		inner = Color3.fromRGB(255, 205, 60),
		rays = Color3.fromRGB(255, 205, 60),
		puffs = 3,
		stars = 3,
		star = Color3.fromRGB(255, 205, 60),
		text = Color3.fromRGB(255, 215, 70),
		edge = Color3.fromRGB(110, 60, 5),
		textHeight = 0.26,
	},
}

-- Lo que cambia un estilo en cada tipo de golpe (solo los colores que pone; el resto, los de serie).
type Recolor = {
	outer: Color3?,
	inner: Color3?,
	rays: Color3?,
	star: Color3?,
	text: Color3?,
	edge: Color3?,
}
type BurstStyle = {
	Hit: Recolor?,
	Crit: Recolor?,
	KO: Recolor?,
	puff: Color3?,
	words: { [string]: { string } }?, -- por tipo ("Crit", "KO"…), para cualquier arma
}

local STYLES: { [string]: BurstStyle } = {
	-- Erupción: siempre una estrella de basalto con lava dentro (lo que no tiene ningún estallido de
	-- serie): el golpe, basalto y naranja; el crítico, con rayos de fuego; el K.O., basalto oscuro y lava
	-- roja. Nubes de ceniza y sus palabras ("FSSS!", "KABOOM!").
	VolcanicBurst = {
		-- El golpe normal también lleva la lava dentro de la estrella de basalto: si no, se confundía
		-- con el amarillo de serie.
		Hit = {
			outer = Color3.fromRGB(90, 72, 64),
			inner = Color3.fromRGB(255, 105, 25),
			star = Color3.fromRGB(255, 190, 60),
			text = Color3.fromRGB(255, 225, 80),
			edge = Color3.fromRGB(150, 25, 5),
		},
		Crit = {
			outer = Color3.fromRGB(105, 84, 75),
			inner = Color3.fromRGB(255, 130, 25),
			rays = Color3.fromRGB(255, 120, 30),
			star = Color3.fromRGB(255, 205, 80),
			text = Color3.fromRGB(255, 240, 150),
			edge = Color3.fromRGB(55, 25, 15),
		},
		KO = {
			outer = Color3.fromRGB(58, 46, 42),
			inner = Color3.fromRGB(240, 55, 15),
			rays = Color3.fromRGB(255, 140, 40),
			star = Color3.fromRGB(255, 190, 70),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(200, 40, 15),
		},
		puff = Color3.fromRGB(125, 115, 110),
		words = { Hit = { "FSSS!", "CRACK!", "FWOOSH!" }, Crit = { "KABOOM!", "BRRUM!" } },
	},
	-- Fuego azul (temporada 1): una llama azul con azufre amarillo dentro (el chapuzón lleva espuma
	-- blanca y el rayo, nube gris); el crítico, el azufre más vivo y rayos celestes (con el centro celeste
	-- se confundía con el chapuzón); el K.O., añil con el centro azul. Nubes de humo de azufre y sus
	-- palabras ("FSHHH!").
	BlueFireBurst = {
		Hit = {
			outer = Color3.fromRGB(40, 95, 240),
			inner = Color3.fromRGB(240, 205, 50),
			star = Color3.fromRGB(150, 210, 255),
			text = Color3.fromRGB(255, 235, 110),
			edge = Color3.fromRGB(15, 25, 110),
		},
		Crit = {
			outer = Color3.fromRGB(30, 70, 215),
			inner = Color3.fromRGB(255, 220, 70),
			rays = Color3.fromRGB(150, 210, 255),
			star = Color3.fromRGB(255, 240, 140),
			text = Color3.fromRGB(255, 240, 140),
			edge = Color3.fromRGB(15, 20, 90),
		},
		KO = {
			outer = Color3.fromRGB(22, 25, 95),
			inner = Color3.fromRGB(45, 120, 255),
			rays = Color3.fromRGB(240, 205, 50),
			star = Color3.fromRGB(255, 235, 110),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(10, 10, 55),
		},
		puff = Color3.fromRGB(215, 205, 140),
		words = { Hit = { "FSSH!", "FWUMP!", "PSSST!" }, Crit = { "FSHHH!", "WHOOOM!" } },
	},
	-- Chapuzón (tienda): una ola azul con espuma blanca dentro, gotas celestes y nubes de espuma.
	SplashBurst = {
		Hit = {
			outer = Color3.fromRGB(60, 150, 235),
			inner = Color3.fromRGB(235, 250, 255),
			star = Color3.fromRGB(150, 220, 255),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(20, 80, 170),
		},
		Crit = {
			outer = Color3.fromRGB(35, 120, 220),
			inner = Color3.fromRGB(120, 215, 255),
			rays = Color3.fromRGB(200, 240, 255),
			star = Color3.fromRGB(235, 250, 255),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(15, 60, 140),
		},
		KO = {
			outer = Color3.fromRGB(20, 70, 150),
			inner = Color3.fromRGB(60, 170, 240),
			rays = Color3.fromRGB(150, 220, 255),
			star = Color3.fromRGB(235, 250, 255),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(10, 40, 100),
		},
		puff = Color3.fromRGB(235, 248, 255),
		words = { Hit = { "SPLASH!", "SPLOSH!", "PLAF!" }, Crit = { "KA-SPLASH!", "GLUB-BOOM!" } },
	},
	-- Rayo (tienda, épico): una nube de tormenta gris oscura con el rayo amarillo dentro y rayos
	-- blancos detrás.
	LightningBurst = {
		Hit = {
			outer = Color3.fromRGB(70, 75, 95),
			inner = Color3.fromRGB(255, 230, 50),
			star = Color3.fromRGB(255, 245, 160),
			text = Color3.fromRGB(255, 240, 90),
			edge = Color3.fromRGB(25, 30, 60),
		},
		Crit = {
			outer = Color3.fromRGB(55, 60, 80),
			inner = Color3.fromRGB(255, 235, 60),
			rays = Color3.fromRGB(235, 245, 255),
			star = Color3.fromRGB(255, 250, 190),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(30, 40, 90),
		},
		KO = {
			outer = Color3.fromRGB(35, 38, 55),
			inner = Color3.fromRGB(150, 210, 255),
			rays = Color3.fromRGB(255, 235, 60),
			star = Color3.fromRGB(255, 245, 160),
			text = Color3.fromRGB(255, 240, 90),
			edge = Color3.fromRGB(15, 20, 50),
		},
		puff = Color3.fromRGB(95, 100, 120),
		words = { Hit = { "BZZT!", "ZAAP!", "KRZZ!" }, Crit = { "KRAKK!", "KA-BRAMM!" } },
	},
	-- Neón (Robux): estrella negra con el borde rosa y el centro celeste, como una máquina recreativa.
	NeonBurst = {
		Hit = {
			outer = Color3.fromRGB(30, 25, 40),
			inner = Color3.fromRGB(255, 70, 150),
			star = Color3.fromRGB(80, 235, 255),
			text = Color3.fromRGB(80, 235, 255),
			edge = Color3.fromRGB(255, 50, 140),
		},
		Crit = {
			outer = Color3.fromRGB(25, 20, 35),
			inner = Color3.fromRGB(80, 235, 255),
			rays = Color3.fromRGB(255, 70, 150),
			star = Color3.fromRGB(255, 240, 90),
			text = Color3.fromRGB(255, 255, 255),
			edge = Color3.fromRGB(255, 50, 140),
		},
		KO = {
			outer = Color3.fromRGB(20, 15, 30),
			inner = Color3.fromRGB(255, 70, 150),
			rays = Color3.fromRGB(80, 235, 255),
			star = Color3.fromRGB(255, 240, 90),
			text = Color3.fromRGB(255, 240, 90),
			edge = Color3.fromRGB(40, 20, 80),
		},
		puff = Color3.fromRGB(80, 235, 255),
		words = { Hit = { "BLIP!", "BOOP!", "PIU!" }, Crit = { "COMBO!", "MEGA!" }, KO = { "GAME OVER!" } },
	},
}

local WORDS: { [string]: { string } } = {
	HitMelee = { "BAM!", "WHACK!", "SMACK!", "BIFF!" },
	HitRanged = { "PEW!", "ZING!", "THWIP!" },
	HitSpell = { "ZAP!", "FZZT!", "ZOT!" },
	CritMelee = { "POW!", "KAPOW!", "WHAM!" },
	CritRanged = { "KA-PEW!", "THWACK!" },
	CritSpell = { "KA-ZAP!", "KRAKOOM!" },
	KO = { "K.O.!" },
	Hurt = { "OUCH!", "OOF!", "ARGH!" },
	Parry = { Strings.later("¡PARRY!") },
	GuardBroken = { Strings.later("¡GUARDIA ROTA!") },
	Counter = { Strings.later("¡CONTRA!") },
}

local ComicBurst = {}

-- Último texto de cada lista, para no repetir la misma palabra dos veces seguidas.
local lastWord: { [string]: string } = {}

-- ¿Existe el estilo de estallido "cosmeticId"?
function ComicBurst.hasStyle(cosmeticId: string): boolean
	return STYLES[cosmeticId] ~= nil
end

-- Palabra para un estallido ("Hit" y "Crit" dependen del arma; un estilo puede traer las suyas).
function ComicBurst.word(kind: Kind, weapon: Weapon?, styleId: string?): string
	local key = if kind == "Hit" or kind == "Crit" then `{kind}{weapon or "Melee"}` else kind
	local list = WORDS[key]
	local style = if styleId and kind ~= "Hurt" then STYLES[styleId] else nil
	if style and style.words and style.words[kind] then
		key = `{styleId}{kind}`
		list = style.words[kind]
	end
	local choice = list[math.random(#list)]
	if #list > 1 and choice == lastWord[key] then
		choice = list[(table.find(list, choice) :: number) % #list + 1]
	end
	lastWord[key] = choice
	-- Las onomatopeyas valen en los dos idiomas; solo se traducen las palabras de la guardia.
	if kind == "Parry" or kind == "GuardBroken" or kind == "Counter" then
		return Strings.t(choice)
	end
	return choice
end

-- Cuánto dura en pantalla un estallido de este tipo.
function ComicBurst.life(kind: Kind): number
	return LOOKS[kind].life
end

local function image(parent: Instance, cell: string, color: Color3, size: number, zIndex: number): ImageLabel
	local rect = CELLS[cell]
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = ATLAS
	label.ImageRectOffset = Vector2.new(rect[1], rect[2])
	label.ImageRectSize = Vector2.new(rect[3], rect[4])
	label.ImageColor3 = color
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(size, size)
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

-- La palabra en tres capas: sombra negra desplazada, borde negro grueso y la letra con su borde de
-- color (así sale el doble borde de los cómics).
local function lettering(parent: Instance, text: string, look: Look, pixels: number)
	local thickness = math.max(1, pixels * 0.016)
	local rotation = math.random(-10, 10)
	for layer = 1, 3 do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.FontFace = BANGERS
		label.TextScaled = true
		label.Text = text
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(0.84, look.textHeight)
		local shift = if layer == 1 then math.round(thickness * 1.8) else 0
		label.Position = UDim2.new(0.5, shift, 0.5, shift)
		label.Rotation = rotation
		label.TextColor3 = if layer == 3 then look.text else BLACK
		label.ZIndex = 5 + layer
		local stroke = Instance.new("UIStroke")
		stroke.Color = if layer == 3 then look.edge else BLACK
		stroke.Thickness = if layer == 3 then thickness else thickness * 2.2
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		label.Parent = parent
	end
end

-- Lo apaga todo a la vez (imágenes, letras y bordes).
local function fadeOut(root: Instance)
	local info = TweenInfo.new(FADE_SECONDS)
	for _, child in root:GetDescendants() do
		if child:IsA("ImageLabel") then
			TweenService:Create(child, info, { ImageTransparency = 1 }):Play()
		elseif child:IsA("TextLabel") then
			TweenService:Create(child, info, { TextTransparency = 1 }):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, info, { Transparency = 1 }):Play()
		end
	end
end

-- El aspecto de "kind" con los colores del estilo "styleId" (si tiene y no es "Hurt").
local function lookOf(kind: Kind, styleId: string?): (Look, Color3)
	local style = if styleId and kind ~= "Hurt" then STYLES[styleId] else nil
	local recolor = if style then (style :: any)[kind] :: Recolor? else nil
	if not (style and recolor) then
		return LOOKS[kind], PUFF
	end
	local look = table.clone(LOOKS[kind])
	for field, value in recolor :: any do
		(look :: any)[field] = value
	end
	return look, style.puff or PUFF
end

-- Los colores de un estallido "kind" con el estilo "styleId" (para su imagen, Shared/RewardModels):
-- estrella de fondo, la de encima, rayos, estrellitas, letra, borde de la letra y nubecitas.
function ComicBurst.palette(kind: Kind, styleId: string?): { [string]: Color3 }
	local look, puffColor = lookOf(kind, styleId)
	return {
		outer = look.outer,
		inner = look.inner or look.outer:Lerp(Color3.new(1, 1, 1), 0.4),
		rays = look.rays or look.outer:Lerp(Color3.new(1, 1, 1), 0.6),
		star = look.star,
		text = look.text,
		edge = look.edge,
		puff = puffColor,
	}
end

-- Dibuja un estallido dentro de "container" (cuadrado, de "pixels" de lado en pantalla) y lo borra al
-- acabar, con los colores del estilo "styleId" si lo hay. Con "freeze" se queda quieto en su momento
-- más grande (para revisarlo en Studio). Devuelve los segundos que dura.
function ComicBurst.play(
	container: GuiObject,
	kind: Kind,
	text: string,
	pixels: number,
	freeze: boolean?,
	styleId: string?
): number
	local look, puffColor = lookOf(kind, styleId)
	local root = Instance.new("Frame")
	root.Name = `Comic{kind}`
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local rays = if look.rays then image(root, "rays", look.rays, 1, 1) else nil
	if rays then
		rays.Rotation = math.random(0, 359)
	end
	local outer = image(root, "burstB", look.outer, look.outerSize, 2)
	outer.Rotation = math.random(0, 359)
	if look.inner then
		image(root, "burstA", look.inner, look.outerSize * 0.7, 3).Rotation = math.random(0, 359)
	end

	-- Nubecitas repartidas alrededor, con la nube hacia fuera y las rayas hacia el centro.
	local puffs: { { label: ImageLabel, direction: Vector2 } } = {}
	local start = math.random() * math.pi * 2
	for index = 1, look.puffs do
		local angle = start + (index - 1) * math.pi * 2 / look.puffs + (math.random() - 0.5) * 0.6
		local direction = Vector2.new(math.cos(angle), math.sin(angle))
		local puff = image(root, "puff", puffColor, 0.24, 4)
		puff.Rotation = math.deg(angle)
		puff.Position = UDim2.fromScale(0.5 + direction.X * 0.36, 0.5 + direction.Y * 0.36)
		table.insert(puffs, { label = puff, direction = direction })
	end
	local stars: { ImageLabel } = {}
	for index = 1, look.stars do
		local angle = start + (index - 0.5) * math.pi * 2 / look.stars
		local radius = 0.38 + math.random() * 0.08
		local star = image(root, "star", look.star, 0.08 + math.random() * 0.04, 5)
		star.Position = UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
		star.Rotation = math.random(-30, 30)
		table.insert(stars, star)
	end
	lettering(root, text, look, pixels)
	root.Parent = container

	if freeze then
		return look.life
	end

	-- Entra de golpe con un rebote, los adornos se alejan del centro y al final se apaga.
	scale.Scale = 0.3
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	local drift = TweenInfo.new(look.life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if rays then
		TweenService:Create(rays, drift, { Rotation = rays.Rotation + 14, Size = UDim2.fromScale(1.12, 1.12) }):Play()
	end
	for _, puff in puffs do
		local target = UDim2.fromScale(0.5 + puff.direction.X * 0.5, 0.5 + puff.direction.Y * 0.5)
		TweenService:Create(puff.label, drift, { Position = target }):Play()
	end
	for _, star in stars do
		TweenService:Create(star, drift, { Rotation = star.Rotation + 90 }):Play()
	end
	task.delay(look.life - FADE_SECONDS, function()
		fadeOut(root)
		TweenService:Create(scale, TweenInfo.new(FADE_SECONDS), { Scale = 1.08 }):Play()
	end)
	task.delay(look.life, function()
		root:Destroy()
	end)
	return look.life
end

return ComicBurst
