--!strict
-- Estallido de cómic de los efectos de combate ("BAM!", "POW!", "K.O.!", "OUCH!"): estrellas de picos
-- con trama de puntos, rayos, nubecitas, estrellitas y una palabra en letra de cómic (Bangers) con
-- borde de color, borde negro y sombra. Los dibujos están en blanco y negro en un atlas
-- (art/ui/comic/gen.py) y aquí se tiñen con ImageColor3: el blanco toma el color y el negro se queda.
-- Va dentro de cualquier marco cuadrado: un BillboardGui sobre un enemigo (ComicFxController) o la
-- vista previa de Ajustes (UI/SettingsPanel). Dura menos de un segundo y se borra solo.

local TweenService = game:GetService("TweenService")

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

export type Kind = "Hit" | "Crit" | "KO" | "Hurt"
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
}

local ComicBurst = {}

-- Último texto de cada lista, para no repetir la misma palabra dos veces seguidas.
local lastWord: { [string]: string } = {}

-- Palabra para un estallido ("Hit" y "Crit" dependen del arma).
function ComicBurst.word(kind: Kind, weapon: Weapon?): string
	local key = if kind == "Hit" or kind == "Crit" then `{kind}{weapon or "Melee"}` else kind
	local list = WORDS[key]
	local choice = list[math.random(#list)]
	if #list > 1 and choice == lastWord[key] then
		choice = list[(table.find(list, choice) :: number) % #list + 1]
	end
	lastWord[key] = choice
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

-- Dibuja un estallido dentro de "container" (cuadrado, de "pixels" de lado en pantalla) y lo borra al
-- acabar. Con "freeze" se queda quieto en su momento más grande (para revisarlo en Studio).
-- Devuelve los segundos que dura.
function ComicBurst.play(container: GuiObject, kind: Kind, text: string, pixels: number, freeze: boolean?): number
	local look = LOOKS[kind]
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
		local puff = image(root, "puff", Color3.fromRGB(255, 250, 235), 0.24, 4)
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
