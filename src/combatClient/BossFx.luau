--!strict
-- Efectos de los jefes dibujados en el cliente (Fase 16, R6). Los lanza BossFxController cuando el servidor
-- avisa por Remotes.BossFx; el servidor solo se queda con el daño, los tiempos y los avisos. Todo en bloques
-- voxel (cubos con pocos tonos planos), con una firma para cada jefe:
--   OrangutanDelManglar  barro y raíces (y lianas oscuras que agarran)
--   ChimpanceCaudillo    rocas grises y polvo de piedra
--   GorilaAlbino         cristales y escarcha cian, y una ola de oscuridad en el rugido
--   GorilaDeCeniza       lava, grietas incandescentes y brasas
-- Las piezas salen de un pool (se reutilizan, nada de Debris) con un tope duro por calidad
-- (Config.Budgets.Vfx). El número de piezas de cada efecto por calidad está en Config.BossFx.Pieces.
--
-- El marcador de peligro (el disco rojo de un pisotón, una roca o una bomba) NO depende de la calidad: sale
-- siempre, con 1 pieza, y no cuenta para el tope. En Bajo solo se recorta la decoración.
--
-- BossFx.play(kind, style, parent, quality, params) crea las piezas ahora, en "parent", y las anima con
-- TweenService a partir de params.serverTime (así todos ven lo mismo que el daño del servidor). Devuelve
-- { pieces = n } con las que ha usado, para que la calculadora Rendimiento cuente el pico.
--   kind:   "stomp" | "rock" | "lavaBomb" | "charge" | "grab" | "roar"
--   params: position (el suelo), warn (segundos hasta el impacto; en "rock", hasta que empieza a caer),
--           flight (vuelo de la roca o la bomba), radius, direction (embestida), origin (de dónde sale la
--           bomba), serverTime, seed y uncapped (sin tope de piezas: solo para medir).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type Quality = "Low" | "Medium" | "High"
export type Params = {
	position: Vector3,
	warn: number?,
	flight: number?,
	radius: number?,
	direction: Vector3?,
	origin: Vector3?,
	serverTime: number?,
	seed: number?,
	uncapped: boolean?,
}

type Palette = {
	main: Color3,
	shade: Color3,
	accent: Color3,
	dust: Color3,
	wave: Color3,
	dark: Color3,
	glow: Color3,
	accentKind: string,
}

type Step = {
	seconds: number,
	goal: { [string]: any },
	wait: number?,
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
}

type Ctx = {
	parent: Instance,
	quality: Quality,
	cap: number,
	uncapped: boolean,
	count: number,
	random: Random,
	palette: Palette,
	elapsed: number,
}

local config: any = require(ReplicatedStorage.Shared.Config)

local BossFx = {}

-- ===================================== Paletas =====================================

local STYLES: { [string]: Palette } = {
	OrangutanDelManglar = {
		main = Color3.fromRGB(96, 64, 38),
		shade = Color3.fromRGB(66, 44, 26),
		accent = Color3.fromRGB(128, 88, 46),
		dust = Color3.fromRGB(118, 92, 62),
		wave = Color3.fromRGB(84, 58, 34),
		dark = Color3.fromRGB(28, 22, 16),
		-- Lianas apagadas: no es el verde de curar.
		glow = Color3.fromRGB(46, 66, 44),
		accentKind = "roots",
	},
	ChimpanceCaudillo = {
		main = Color3.fromRGB(128, 126, 122),
		shade = Color3.fromRGB(88, 86, 84),
		accent = Color3.fromRGB(150, 148, 142),
		dust = Color3.fromRGB(176, 166, 150),
		wave = Color3.fromRGB(140, 134, 124),
		dark = Color3.fromRGB(40, 38, 36),
		glow = Color3.fromRGB(110, 108, 104),
		accentKind = "rubble",
	},
	GorilaAlbino = {
		main = Color3.fromRGB(150, 226, 246),
		shade = Color3.fromRGB(96, 170, 206),
		accent = Color3.fromRGB(210, 244, 252),
		dust = Color3.fromRGB(200, 232, 242),
		wave = Color3.fromRGB(170, 230, 248),
		dark = Color3.fromRGB(18, 26, 52),
		glow = Color3.fromRGB(120, 220, 255),
		accentKind = "crystals",
	},
	GorilaDeCeniza = {
		main = Color3.fromRGB(255, 110, 30),
		shade = Color3.fromRGB(60, 54, 52),
		accent = Color3.fromRGB(255, 190, 60),
		dust = Color3.fromRGB(90, 80, 76),
		wave = Color3.fromRGB(255, 120, 40),
		dark = Color3.fromRGB(30, 26, 26),
		glow = Color3.fromRGB(255, 150, 40),
		accentKind = "cracks",
	},
}

local DEFAULT_RADIUS = { stomp = 20, rock = 6, lavaBomb = 6, grab = 4, charge = 9, roar = 45 }
local CHARGE_SPEED = 90 -- studs/s de la embestida (BossService)
local SMOOTH = Enum.Material.SmoothPlastic
local PLASTIC = Enum.Material.Plastic
local NEON = Enum.Material.Neon

-- ===================================== Pool =====================================

local free: { Part } = {}
local live = 0
local generation: { [Part]: number } = {}
local running: { [Part]: Tween } = {}
local queue: { { part: Part, at: number } } = {}
local cleaner: RBXScriptConnection? = nil

-- Cambia la configuración que lee el módulo (la calculadora le pasa la copia con su propuesta).
function BossFx.setConfig(newConfig: any)
	config = newConfig
end

-- Una pieza lista para usar (cubo anclado, sin colisión), reutilizada si hay alguna libre.
function BossFx.acquire(parent: Instance): Part
	local part = table.remove(free)
	if not part then
		part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
	end
	local piece = part :: Part
	live += 1
	piece.Name = "BossFxPiece"
	piece.Shape = Enum.PartType.Block
	piece.Material = PLASTIC
	piece.Transparency = 0
	piece.Parent = parent
	return piece
end

-- Devuelve la pieza al pool: corta sus animaciones y la saca del mundo.
function BossFx.release(part: Part)
	generation[part] = (generation[part] or 0) + 1
	local tween = running[part]
	if tween then
		running[part] = nil
		tween:Cancel()
	end
	live = math.max(0, live - 1)
	-- Si la carpeta se destruyó (la calculadora), la pieza ya no se puede reutilizar.
	local ok = pcall(function()
		part.Parent = nil
	end)
	if ok and #free < config.Budgets.Vfx.High then
		table.insert(free, part)
	elseif ok then
		part:Destroy()
	end
end

-- Piezas en uso ahora mismo (para depurar).
function BossFx.liveCount(): number
	return live
end

local function releaseLater(part: Part, seconds: number)
	table.insert(queue, { part = part, at = os.clock() + seconds })
	if cleaner then
		return
	end
	-- Un solo Heartbeat para todo el pool; se desconecta cuando no queda nada que devolver.
	cleaner = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local index = 1
		while index <= #queue do
			local entry = queue[index]
			if entry.at <= now then
				BossFx.release(entry.part)
				queue[index] = queue[#queue]
				queue[#queue] = nil
			else
				index += 1
			end
		end
		if #queue == 0 and cleaner then
			cleaner:Disconnect()
			cleaner = nil
		end
	end)
end

-- Anima una pieza en pasos seguidos. Cada tween se crea cuando acaba el anterior (así parte del valor en
-- que quedó el paso previo y no del que tenía al programarlo).
local function chain(part: Part, steps: { Step })
	local gen = generation[part] or 0
	local function run(index: number)
		local step = steps[index]
		if not step or (generation[part] or 0) ~= gen then
			return
		end
		local info = TweenInfo.new(
			step.seconds,
			step.style or Enum.EasingStyle.Quad,
			step.dir or Enum.EasingDirection.Out,
			0,
			false,
			step.wait or 0
		)
		local tween = TweenService:Create(part, info, step.goal)
		running[part] = tween
		tween.Completed:Once(function()
			run(index + 1)
		end)
		tween:Play()
	end
	run(1)
end

-- ===================================== Piezas =====================================

-- Una pieza oculta para el efecto, o nil si se llegó al tope de la calidad. "life" son los segundos hasta que
-- se devuelve al pool. Las esenciales (el marcador de peligro) no cuentan para el tope.
local function take(ctx: Ctx, life: number, essential: boolean?): Part?
	if not essential and not ctx.uncapped and live >= ctx.cap then
		return nil
	end
	local part = BossFx.acquire(ctx.parent)
	part.Transparency = 1
	ctx.count += 1
	releaseLater(part, life + 0.15)
	return part
end

local function put(part: Part, position: Vector3, size: Vector3, color: Color3, material: Enum.Material)
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
end

-- Paso que hace aparecer la pieza tras "wait" segundos.
local function appear(wait: number, transparency: number): Step
	return { wait = wait, seconds = 0.03, goal = { Transparency = transparency } }
end

local function randomSpin(ctx: Ctx): CFrame
	return CFrame.Angles(ctx.random:NextNumber(0, 6), ctx.random:NextNumber(0, 6), ctx.random:NextNumber(0, 6))
end

local function polar(angle: number, distance: number): Vector3
	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- El disco rojo de peligro, con el radio y la duración reales. Siempre sale, en cualquier calidad.
local function marker(ctx: Ctx, ground: Vector3, radius: number, seconds: number)
	local part = take(ctx, seconds + 0.3, true)
	if not part then
		return
	end
	part.Name = "BossMarker"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, radius * 2, radius * 2)
	part.CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = config.BossFx.MarkerColor
	part.Material = NEON
	part.Transparency = config.BossFx.MarkerTransparency
	-- Se va haciendo más fuerte según se acerca el impacto, y se apaga al caer.
	chain(part, {
		{ seconds = math.max(seconds, 0.05), goal = { Transparency = 0.3 }, style = Enum.EasingStyle.Linear },
		{ seconds = 0.25, goal = { Transparency = 1 } },
	})
end

-- Bloque que sale del suelo hasta "height" y se desvanece (raíces, cristales, piedras, lianas).
local function spike(
	ctx: Ctx,
	base: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	delay: number,
	hold: number,
	transparency: number
)
	local life = delay + 0.25 + hold + 0.5
	local part = take(ctx, life)
	if not part then
		return
	end
	put(part, base + Vector3.new(0, 0.1, 0), Vector3.new(width, 0.2, width), color, material)
	chain(part, {
		appear(delay, transparency),
		{
			seconds = 0.25,
			goal = {
				Size = Vector3.new(width, height, width),
				CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0))
					* CFrame.Angles(0, ctx.random:NextNumber(0, 3), 0),
			},
		},
		{ wait = hold, seconds = 0.5, goal = { Transparency = 1 } },
	})
end

-- Trozo que sale despedido en arco desde "from" hasta caer en "to".
local function lob(
	ctx: Ctx,
	from: Vector3,
	to: Vector3,
	peak: number,
	size: number,
	color: Color3,
	material: Enum.Material,
	delay: number
)
	local rise = 0.28
	local fall = 0.34
	local part = take(ctx, delay + rise + fall + 0.5)
	if not part then
		return
	end
	put(part, from, Vector3.one * size, color, material)
	local top = from:Lerp(to, 0.5) + Vector3.new(0, peak, 0)
	chain(part, {
		appear(delay, 0),
		{ seconds = rise, goal = { CFrame = CFrame.new(top) * randomSpin(ctx) } },
		{
			seconds = fall,
			goal = { CFrame = CFrame.new(to + Vector3.new(0, size / 2, 0)) * randomSpin(ctx) },
			style = Enum.EasingStyle.Quad,
			dir = Enum.EasingDirection.In,
		},
		{ seconds = 0.5, goal = { Transparency = 1 } },
	})
end

-- Chispa o brasa que sube y se apaga.
local function floatUp(
	ctx: Ctx,
	from: Vector3,
	height: number,
	size: number,
	color: Color3,
	material: Enum.Material,
	delay: number,
	seconds: number
)
	local part = take(ctx, delay + seconds + 0.4)
	if not part then
		return
	end
	put(part, from, Vector3.one * size, color, material)
	local drift = Vector3.new(ctx.random:NextNumber(-3, 3), height, ctx.random:NextNumber(-3, 3))
	chain(part, {
		appear(delay, 0),
		{
			seconds = seconds,
			goal = { CFrame = CFrame.new(from + drift) * randomSpin(ctx) },
			style = Enum.EasingStyle.Sine,
		},
		{ seconds = 0.4, goal = { Transparency = 1 } },
	})
end

-- Nube de polvo que se hincha mientras se va.
local function puff(ctx: Ctx, at: Vector3, from: number, to: number, color: Color3, delay: number, seconds: number)
	local part = take(ctx, delay + seconds + 0.1)
	if not part then
		return
	end
	put(part, at + Vector3.new(0, from / 2, 0), Vector3.one * from, color, SMOOTH)
	chain(part, {
		appear(delay, 0.35),
		{
			seconds = seconds,
			goal = {
				Size = Vector3.one * to,
				CFrame = CFrame.new(at + Vector3.new(0, to * 0.6, 0))
					* CFrame.Angles(0, ctx.random:NextNumber(0, 3), 0),
				Transparency = 1,
			},
		},
	})
end

-- Losas que se abren en anillo desde el centro hasta "to", subiendo y desvaneciéndose (la onda del pisotón y
-- la ola de oscuridad del rugido). Cada una mira hacia fuera.
local function wall(
	ctx: Ctx,
	center: Vector3,
	count: number,
	spec: {
		from: number,
		to: number,
		height: number,
		rise: number,
		thickness: number,
		maxWidth: number,
		delay: number,
		seconds: number,
		color: Color3,
		material: Enum.Material,
		transparency: number,
		turn: number,
	}
)
	for index = 1, count do
		local part = take(ctx, spec.delay + spec.seconds + 0.2)
		if not part then
			return
		end
		local angle = (index - 1) / count * math.pi * 2 + spec.turn
		local direction = polar(angle, 1)
		local width = math.min(math.pi * 2 * spec.to / count * 1.1, spec.maxWidth)
		local startPosition = center + direction * spec.from + Vector3.new(0, spec.height / 2, 0)
		put(part, startPosition, Vector3.new(width * 0.3, spec.height, spec.thickness), spec.color, spec.material)
		part.CFrame = CFrame.lookAt(startPosition, startPosition + direction)
		local endPosition = center + direction * spec.to + Vector3.new(0, spec.rise + spec.height / 2, 0)
		chain(part, {
			appear(spec.delay, spec.transparency),
			{
				seconds = spec.seconds,
				goal = {
					Size = Vector3.new(width, spec.height, spec.thickness),
					CFrame = CFrame.lookAt(endPosition, endPosition + direction),
					Transparency = 1,
				},
			},
		})
	end
end

-- Cuántas piezas de cada lado: se recorta el reparto, nunca el marcador.
local function share(total: number, fraction: number): number
	return math.floor(total * fraction)
end

-- ===================================== Efectos =====================================

-- Pisotón: marcador, onda que se abre, trozos despedidos y lo propio del jefe (raíces, cristales, grietas de
-- lava o piedras que brotan).
local function stomp(ctx: Ctx, center: Vector3, radius: number, impact: number, n: number)
	local p = ctx.palette
	local ring = math.max(1, n // 5)
	local lobs = share(n, 0.35)
	local extra = n - 1 - ring - lobs
	marker(ctx, center, radius, impact)

	wall(ctx, center, ring, {
		from = 2,
		to = radius * 0.95,
		height = 1.2,
		rise = 0.8,
		thickness = 1.4,
		maxWidth = 14,
		delay = impact,
		seconds = 0.38,
		color = p.wave,
		material = if p.accentKind == "crystals" then SMOOTH else PLASTIC,
		transparency = 0.3,
		turn = ctx.random:NextNumber(0, 3),
	})

	for index = 1, lobs do
		local angle = ctx.random:NextNumber(0, math.pi * 2)
		local spot = center + polar(angle, ctx.random:NextNumber(radius * 0.2, radius * 0.95))
		if p.accentKind == "cracks" then
			-- Brasas que suben desde las grietas.
			floatUp(ctx, spot + Vector3.new(0, 0.5, 0), ctx.random:NextNumber(8, 16), 0.7, p.accent, NEON, impact, 0.9)
		else
			local color = if index % 2 == 0 then p.main else p.shade
			lob(
				ctx,
				center + Vector3.new(0, 0.5, 0),
				spot,
				ctx.random:NextNumber(6, 11),
				ctx.random:NextNumber(0.9, 1.7),
				color,
				PLASTIC,
				impact
			)
		end
	end

	for index = 1, extra do
		local angle = if p.accentKind == "cracks"
			then (index / extra) * math.pi * 2
			else ctx.random:NextNumber(0, math.pi * 2)
		if p.accentKind == "cracks" then
			-- Grietas de lava que salen del centro y se van apagando.
			local length = radius * ctx.random:NextNumber(0.55, 0.9)
			local direction = polar(angle, 1)
			local middle = center + direction * (length / 2) + Vector3.new(0, 0.2, 0)
			local part = take(ctx, impact + 2.2)
			if part then
				put(part, middle, Vector3.new(0.8, 0.25, length), p.main, NEON)
				part.CFrame = CFrame.lookAt(middle, middle + direction)
				chain(part, { appear(impact, 0.05), { wait = 1.2, seconds = 1.0, goal = { Transparency = 1 } } })
			end
		else
			local base = center + polar(angle, ctx.random:NextNumber(radius * 0.35, radius * 0.95))
			if p.accentKind == "roots" then
				spike(
					ctx,
					base,
					1.0,
					ctx.random:NextNumber(5, 8),
					p.accent,
					PLASTIC,
					impact + ctx.random:NextNumber(0, 0.15),
					0.7,
					0
				)
			elseif p.accentKind == "crystals" then
				spike(
					ctx,
					base,
					1.4,
					ctx.random:NextNumber(6, 10),
					if index % 2 == 0 then p.main else p.accent,
					SMOOTH,
					impact + ctx.random:NextNumber(0, 0.15),
					0.9,
					0.15
				)
			else
				spike(
					ctx,
					base,
					2,
					ctx.random:NextNumber(2, 3.5),
					p.main,
					PLASTIC,
					impact + ctx.random:NextNumber(0, 0.15),
					0.6,
					0
				)
			end
		end
	end
end

-- Roca: marcador (su sombra de caída), la roca voxel que cae, polvo al impactar y esquirlas.
local function rock(ctx: Ctx, ground: Vector3, radius: number, startFall: number, flight: number, n: number)
	local p = ctx.palette
	local bodies = math.clamp(share(n - 1, 0.2), 1, 5)
	local rest = n - 1 - bodies
	local dust = math.ceil(rest / 2)
	local impact = startFall + flight
	marker(ctx, ground, radius, impact)

	for index = 1, bodies do
		local size = if index == 1 then radius * 0.9 else radius * ctx.random:NextNumber(0.3, 0.5)
		local offset = if index == 1 then Vector3.zero else polar(ctx.random:NextNumber(0, 6.28), radius * 0.45)
		local part = take(ctx, impact + 1.2)
		if part then
			local skyPosition = ground + offset + Vector3.new(0, 45, 0)
			put(part, skyPosition, Vector3.one * size, if index == 1 then p.main else p.shade, PLASTIC)
			chain(part, {
				appear(startFall, 0),
				{
					seconds = flight,
					goal = { CFrame = CFrame.new(ground + offset + Vector3.new(0, size / 2, 0)) * randomSpin(ctx) },
					style = Enum.EasingStyle.Quad,
					dir = Enum.EasingDirection.In,
				},
				{ wait = 0.5, seconds = 0.5, goal = { Transparency = 1 } },
			})
		end
	end
	for _ = 1, dust do
		local spot = ground + polar(ctx.random:NextNumber(0, 6.28), ctx.random:NextNumber(0, radius * 0.9))
		puff(ctx, spot, 1.5, radius * ctx.random:NextNumber(0.6, 1), p.dust, impact, 0.9)
	end
	for _ = 1, rest - dust do
		local spot = ground + polar(ctx.random:NextNumber(0, 6.28), ctx.random:NextNumber(radius, radius * 2))
		lob(
			ctx,
			ground + Vector3.new(0, 1, 0),
			spot,
			ctx.random:NextNumber(3, 7),
			ctx.random:NextNumber(0.4, 0.9),
			if ctx.random:NextInteger(0, 1) == 0 then p.main else p.shade,
			PLASTIC,
			impact
		)
	end
end

-- Bomba de lava (también la erupción del volcán): marcador, bola incandescente en arco, charco que arde unos
-- segundos y brasas.
local function lavaBomb(ctx: Ctx, ground: Vector3, radius: number, params: Params, n: number)
	local p = ctx.palette
	local warn = params.warn or 1.6
	local flight = math.min(params.flight or 1.1, warn)
	local launch = warn - flight - ctx.elapsed
	local impact = math.max(0, warn - ctx.elapsed)
	local flightLeft = math.max(0.05, flight + math.min(launch, 0))
	launch = math.max(0, launch)
	local bodies = if n >= 20 then 3 elseif n >= 10 then 2 else 1
	local pools = bodies
	local embers = n - 1 - bodies - pools
	marker(ctx, ground, radius, impact)

	local size = math.max(2.2, radius * 0.55)
	local start = params.origin or (ground + Vector3.new(0, 80, 0))
	local landing = ground + Vector3.new(0, size / 2, 0)
	local apex = (start + landing) / 2 + Vector3.new(0, 18, 0)
	for index = 1, bodies do
		local part = take(ctx, launch + flightLeft + 0.2)
		if part then
			local scale = if index == 1 then 1 elseif index == 2 then 0.55 else 1.25
			local color = if index == 1 then p.main elseif index == 2 then p.accent else p.shade
			put(part, start, Vector3.one * size * scale, color, if index == 3 then PLASTIC else NEON)
			chain(part, {
				appear(launch, if index == 3 then 0.2 else 0),
				{ seconds = flightLeft / 2, goal = { CFrame = CFrame.new(apex) * randomSpin(ctx) } },
				{
					seconds = flightLeft / 2,
					goal = { CFrame = CFrame.new(landing) * randomSpin(ctx) },
					style = Enum.EasingStyle.Quad,
					dir = Enum.EasingDirection.In,
				},
				{ seconds = 0.05, goal = { Transparency = 1 } },
			})
		end
	end

	local poolSeconds = config.BossFx.LavaPoolSeconds
	for index = 1, pools do
		local part = take(ctx, impact + poolSeconds + 0.4)
		if part then
			local width = radius * (if index == 1 then 1.4 elseif index == 2 then 1.9 else 0.8)
			local color = if index == 1 then p.main elseif index == 2 then p.shade else p.accent
			put(
				part,
				ground + Vector3.new(0, 0.1 + index * 0.04, 0),
				Vector3.new(width, 0.2, width),
				color,
				if index == 2 then PLASTIC else NEON
			)
			chain(
				part,
				{ appear(impact, 0.05), { wait = poolSeconds - 1.2, seconds = 1.2, goal = { Transparency = 1 } } }
			)
		end
	end

	for index = 1, embers do
		local spot = ground + polar(ctx.random:NextNumber(0, 6.28), ctx.random:NextNumber(radius * 0.5, radius * 1.8))
		if index % 2 == 0 then
			lob(
				ctx,
				ground + Vector3.new(0, 1, 0),
				spot,
				ctx.random:NextNumber(5, 10),
				ctx.random:NextNumber(0.5, 1.0),
				p.glow,
				NEON,
				impact
			)
		else
			floatUp(ctx, spot + Vector3.new(0, 0.5, 0), ctx.random:NextNumber(6, 12), 0.6, p.accent, NEON, impact, 1.0)
		end
	end
end

-- Embestida: estela de polvo y trocitos a lo largo del recorrido, saliendo a la velocidad del jefe.
local function charge(ctx: Ctx, from: Vector3, direction: Vector3, n: number)
	local p = ctx.palette
	local length = config.BossFx.ChargeLengthStuds
	local sideways = Vector3.new(-direction.Z, 0, direction.X)
	for index = 1, n do
		local distance = length * (index - 0.5) / n
		local delay = math.max(0, distance / CHARGE_SPEED - ctx.elapsed)
		local at = from + direction * distance + sideways * ctx.random:NextNumber(-2.5, 2.5)
		if index % 2 == 1 then
			puff(
				ctx,
				at,
				1.6,
				ctx.random:NextNumber(3.5, 5),
				if p.accentKind == "crystals" then p.wave else p.dust,
				delay,
				0.8
			)
		elseif p.accentKind == "cracks" then
			floatUp(ctx, at + Vector3.new(0, 0.5, 0), ctx.random:NextNumber(4, 8), 0.6, p.accent, NEON, delay, 0.7)
		else
			lob(
				ctx,
				at + Vector3.new(0, 0.5, 0),
				at + sideways * ctx.random:NextNumber(-3, 3),
				ctx.random:NextNumber(2, 4),
				ctx.random:NextNumber(0.5, 0.9),
				if p.accentKind == "crystals" then p.main else p.shade,
				if p.accentKind == "crystals" then SMOOTH else PLASTIC,
				delay
			)
		end
	end
end

-- Agarre: lianas oscuras que brotan alrededor de quien es agarrado y le dan vueltas en espiral.
local function grab(ctx: Ctx, center: Vector3, n: number)
	local p = ctx.palette
	local vines = math.ceil(n * 0.6)
	for index = 1, vines do
		local angle = index / vines * math.pi * 2
		spike(
			ctx,
			center + polar(angle, 2.2),
			0.7,
			ctx.random:NextNumber(6, 8.5),
			p.glow,
			PLASTIC,
			index * 0.03,
			2.4,
			0
		)
	end
	for index = 1, n - vines do
		local angle = index * 1.2
		local part = take(ctx, 0.3 + 2.6 + 0.5)
		if part then
			local at = center + polar(angle, 2.4) + Vector3.new(0, 1 + index * 1.1, 0)
			put(part, at, Vector3.new(2.8, 0.5, 0.7), p.shade, PLASTIC)
			-- Mira a lo largo de la tangente del círculo.
			part.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
			chain(part, { appear(0.1 + index * 0.05, 0), { wait = 2.4, seconds = 0.5, goal = { Transparency = 1 } } })
		end
	end
end

-- Rugido: olas de oscuridad que se abren por el suelo y suben.
local function roar(ctx: Ctx, center: Vector3, radius: number, n: number)
	local p = ctx.palette
	local rings = math.clamp(n // 10, 1, 3)
	local per = n // rings
	for ring = 1, rings do
		wall(ctx, center, per, {
			from = 3,
			to = radius,
			height = 6,
			rise = 10,
			thickness = 1.6,
			maxWidth = 26,
			delay = (ring - 1) * 0.22,
			seconds = 1.1,
			color = p.dark,
			material = SMOOTH,
			transparency = 0.25,
			turn = ring * 0.4,
		})
	end
end

-- ===================================== Interfaz =====================================

-- Dibuja un efecto. Ver la cabecera para los parámetros.
function BossFx.play(
	kind: string,
	style: string,
	parent: Instance,
	quality: Quality,
	params: Params
): { pieces: number }
	local pieceTable = config.BossFx.Pieces[kind]
	if not pieceTable then
		return { pieces = 0 }
	end
	local palette = STYLES[style] or STYLES.ChimpanceCaudillo
	-- La erupción y las bombas son siempre de lava, sea cual sea el jefe que las lance.
	if kind == "lavaBomb" then
		palette = STYLES.GorilaDeCeniza
	end
	local elapsed = if params.serverTime then math.max(0, Workspace:GetServerTimeNow() - params.serverTime) else 0
	local ctx: Ctx = {
		parent = parent,
		quality = quality,
		cap = config.Budgets.Vfx[quality],
		uncapped = params.uncapped == true,
		count = 0,
		random = Random.new(params.seed or 1),
		palette = palette,
		elapsed = elapsed,
	}
	local n: number = pieceTable[quality]
	local position = params.position
	local radius = params.radius or (DEFAULT_RADIUS :: any)[kind] or 6
	local untilImpact = math.max(0, (params.warn or 0) - elapsed)
	if kind == "stomp" then
		stomp(ctx, position, radius, untilImpact, n)
	elseif kind == "rock" then
		rock(ctx, position, radius, untilImpact, params.flight or 0.4, n)
	elseif kind == "lavaBomb" then
		lavaBomb(ctx, position, radius, params, n)
	elseif kind == "charge" then
		charge(ctx, position, params.direction or Vector3.zAxis, n)
	elseif kind == "grab" then
		grab(ctx, position, n)
	elseif kind == "roar" then
		roar(ctx, position, radius, n)
	end
	return { pieces = ctx.count }
end

return BossFx
