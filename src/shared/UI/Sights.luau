--!strict
-- Miras de las armas al apuntar (Fase 19, W8). Se dibujan con Frames, sin imágenes, y salen con la opacidad de
-- la transición de apuntar (WeaponController.aimAlpha): a 0 no se ve nada. Sights.mount(parent) crea un Frame
-- "Sights" a pantalla completa en "parent" (el ScreenGui "Mira", con IgnoreGuiInset) y devuelve un Handle:
--     setWeapon(weapon)  elige la mira del arma (nil: ninguna).
--     update(state)      una vez por fotograma: { alpha, aimPoint, muzzle, camera, center }. "center" es el
--                        punto de la pantalla donde está la mira (Dunas la mueve con el ratón); sin él, el centro.
--     covers()           true si hay una mira de arma visible (alpha > 0.35): quien llama esconde entonces la
--                        mira normal (UI/Crosshair).
--     scopeAlpha()       de 0 a 1, solo con el visor (para esconder el arma en primera persona).
--     destroy().
-- Qué mira lleva cada arma (Sights.kindOf): la de su campo "sight" (Data/Weapons y Data/LabWeapons) y, si no
-- lo trae, la de su proyectil:
--     sin proyectil o "Stone"  RedDot   punto rojo
--     "Arrow", "Dart"          Iron     mira de hierro (poste y muesca)
--     "Spell"                  Arc      recta de puntos hasta el blanco y anillo con el radio del remate
--     las del Laboratorio      las cuatro tienen "sight" (dardos RedDot, rifle Scope, arpón Iron, cañón Arc)
--     sin arma o cuerpo a cuerpo  nil
-- Scope: viñeta oscura con un hueco circular, cruz fina con hueco y marcas. Arc con AcidBurst (el cañón): la
-- parábola del disparo. Colores: nunca verde ni morado; el punto rojo es la excepción aceptada.

local Players = game:GetService("Players")

local Config = require(script.Parent.Parent.Config)
local Weapons = require(script.Parent.Parent.Data.Weapons)

export type SightKind = "Scope" | "RedDot" | "Iron" | "Arc"

export type State = {
	alpha: number,
	aimPoint: Vector3,
	muzzle: Vector3?,
	camera: Camera,
	center: Vector2?,
}

export type Handle = {
	root: Frame,
	setWeapon: (weapon: Weapons.WeaponDefinition?) -> (),
	update: (state: State) -> (),
	covers: () -> boolean,
	scopeAlpha: () -> number,
	destroy: () -> (),
}

type Entry = { obj: GuiObject, fill: number, stroke: UIStroke?, strokeFill: number }

type Options = {
	color: Color3?,
	fill: number?,
	round: boolean?,
	strokeColor: Color3?,
	strokeThickness: number?,
	strokeFill: number?,
}

local COVER_ALPHA = 0.35
-- Velocidad (por segundo) con que la opacidad sigue al alpha.
local SMOOTH = 30
local BLACK = Color3.fromRGB(10, 10, 10)
local DARK = Color3.fromRGB(30, 30, 30)
local LIGHT = Color3.fromRGB(235, 235, 235)
local RED = Color3.fromRGB(255, 60, 50)
local WARM = Color3.fromRGB(255, 230, 80)
-- Visor: el hueco ocupa esta fracción del lado corto de la pantalla; la viñeta cuadrada llega a SCOPE_SQUARE
-- veces el hueco y el anillo grueso (SCOPE_RING del hueco) tapa las esquinas del cuadrado.
local SCOPE_HOLE = 0.8
local SCOPE_SQUARE = 1.1
local SCOPE_RING = 0.3
local SCOPE_GAP = 8
local SCOPE_TICKS = { 0.35, 0.6, 0.85 }
local SCOPE_DIRS = { Vector2.new(-1, 0), Vector2.new(1, 0), Vector2.new(0, -1), Vector2.new(0, 1) }
-- Mira de hierro: alto de la muesca y del poste, en píxeles.
local IRON_BLOCK = Vector2.new(6, 12)
local IRON_POST = Vector2.new(4, 14)
local ARC_DOT = 5
local ARC_RING_MIN = 6
local DEFAULT_ACID_SPEED = 110

-- Lo que ve el visor (para esconder el arma en primera persona), compartido entre todos los Handle.
local currentScope = 0

local Sights = {}

-- Frame de la mira; se guarda en "list" para pintar su opacidad.
local function addFrame(list: { Entry }, parent: Instance, name: string, size: Vector2, options: Options): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BorderSizePixel = 0
	frame.Active = false
	local fill = options.fill or 0
	frame.BackgroundColor3 = options.color or BLACK
	frame.BackgroundTransparency = 1 - fill
	if options.round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	local stroke: UIStroke? = nil
	if options.strokeThickness then
		local made = Instance.new("UIStroke")
		made.Color = options.strokeColor or BLACK
		made.Thickness = options.strokeThickness
		made.Parent = frame
		stroke = made
	end
	frame.Parent = parent
	table.insert(list, { obj = frame, fill = fill, stroke = stroke, strokeFill = options.strokeFill or 0 })
	return frame
end

local function container(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Active = false
	frame.Visible = false
	frame.Parent = parent
	return frame
end

function Sights.kindOf(weapon: Weapons.WeaponDefinition?): SightKind?
	if not weapon or weapon.kind ~= "Ranged" then
		return nil
	end
	if weapon.sight then
		return weapon.sight
	end
	local projectile = weapon.projectile
	if projectile == nil or projectile == "Stone" then
		return "RedDot"
	elseif projectile == "Arrow" or projectile == "Dart" then
		return "Iron"
	elseif projectile == "Spell" then
		return "Arc"
	elseif projectile == "LabDart" then
		return "RedDot"
	elseif projectile == "LabBanana" then
		return "Scope"
	elseif projectile == "LabNet" then
		return "Iron"
	end
	return "Arc"
end

-- Lo que ve el visor ahora (de 0 a 1), de la última mira montada.
function Sights.scopeAlpha(): number
	return currentScope
end

-- Posición del punto de la pantalla (píxeles de la ventana) y su profundidad; nil si queda detrás de la cámara.
local function project(camera: Camera, world: Vector3): (Vector2?, number)
	local view = camera:WorldToViewportPoint(world)
	if view.Z <= 0 then
		return nil, view.Z
	end
	return Vector2.new(view.X, view.Y), view.Z
end

-- Radio en píxeles de una esfera de "studs" a la profundidad "depth".
local function studsToPixels(camera: Camera, studs: number, depth: number): number
	local tangent = math.tan(math.rad(camera.FieldOfView) / 2)
	return math.max(ARC_RING_MIN, studs * (camera.ViewportSize.Y / 2) / (math.max(depth, 0.1) * tangent))
end

function Sights.mount(parent: GuiObject): Handle
	local settings = Config.Sights
	local root = Instance.new("Frame")
	root.Name = "Sights"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 2
	root.Active = false
	root.Visible = false
	root.Parent = parent

	local entries: { [SightKind]: { Entry } } = { Scope = {}, RedDot = {}, Iron = {}, Arc = {} }
	local holders: { [SightKind]: Frame } = {}
	for kind in entries do
		holders[kind] = container(root, kind)
	end

	-- Visor: anillo grueso, borde fino, cuatro rectángulos, cruz con hueco y marcas.
	local scope = entries.Scope
	local scopeHolder = holders.Scope
	local vignette = settings.ScopeVignette
	local scopeRing = addFrame(scope, scopeHolder, "Ring", Vector2.zero, {
		round = true,
		strokeColor = BLACK,
		strokeThickness = 1,
		strokeFill = vignette,
	})
	local scopeRim = addFrame(scope, scopeHolder, "Rim", Vector2.zero, {
		round = true,
		strokeColor = DARK,
		strokeThickness = 2,
		strokeFill = 0.9,
	})
	local edges: { Frame } = {}
	for _, name in { "Top", "Bottom", "Left", "Right" } do
		local edge = addFrame(scope, scopeHolder, name, Vector2.zero, { color = BLACK, fill = vignette })
		edge.AnchorPoint = Vector2.zero
		table.insert(edges, edge)
	end
	local lines: { Frame } = {}
	for index in SCOPE_DIRS do
		table.insert(lines, addFrame(scope, scopeHolder, `Line{index}`, Vector2.zero, { color = BLACK, fill = 0.9 }))
	end
	local ticks: { Frame } = {}
	for index in SCOPE_DIRS do
		for fraction in SCOPE_TICKS do
			table.insert(
				ticks,
				addFrame(scope, scopeHolder, `Tick{index}_{fraction}`, Vector2.new(2, 8), {
					color = BLACK,
					fill = 0.9,
				})
			)
		end
	end

	-- Punto rojo.
	local dotSize = settings.RedDotPx
	local redDot = addFrame(entries.RedDot, holders.RedDot, "Dot", Vector2.new(dotSize, dotSize), {
		color = RED,
		fill = 1,
		round = true,
		strokeColor = BLACK,
		strokeThickness = 1,
		strokeFill = 0.8,
	})

	-- Mira de hierro: dos bloques a los lados y el poste en medio, que baja desde el centro.
	local ironBlocks: { Frame } = {}
	for index = 1, 2 do
		table.insert(
			ironBlocks,
			addFrame(entries.Iron, holders.Iron, `Block{index}`, IRON_BLOCK, {
				color = DARK,
				fill = 0.95,
				strokeColor = LIGHT,
				strokeThickness = 1,
				strokeFill = 0.9,
			})
		)
	end
	local ironPost = addFrame(entries.Iron, holders.Iron, "Post", IRON_POST, {
		color = DARK,
		fill = 0.95,
		strokeColor = LIGHT,
		strokeThickness = 1,
		strokeFill = 0.9,
	})
	ironPost.AnchorPoint = Vector2.new(0.5, 0)

	-- Trayectoria: puntos de un pool fijo y un anillo en el punto de impacto.
	local arcDots: { Frame } = {}
	for index = 1, settings.ArcPoints do
		table.insert(
			arcDots,
			addFrame(entries.Arc, holders.Arc, `Point{index}`, Vector2.new(ARC_DOT, ARC_DOT), {
				color = LIGHT,
				fill = 0.9,
				round = true,
				strokeColor = BLACK,
				strokeThickness = 1,
				strokeFill = 0.7,
			})
		)
	end
	local arcRing = addFrame(entries.Arc, holders.Arc, "Impact", Vector2.zero, {
		round = true,
		strokeColor = WARM,
		strokeThickness = 2,
		strokeFill = 0.95,
	})

	local weaponNow: Weapons.WeaponDefinition? = nil
	local kind: SightKind? = nil
	local shown = 0
	local rawAlpha = 0
	local lastPainted = -1
	local lastClock = os.clock()
	-- Para recolocar el visor y la mira de hierro solo cuando cambia el centro o la pantalla.
	local lastCenter = Vector2.new(-1, -1)
	local lastSize = Vector2.zero

	local function paint()
		if not kind then
			return
		end
		for _, entry in entries[kind] do
			if entry.fill > 0 then
				entry.obj.BackgroundTransparency = 1 - entry.fill * shown
			end
			if entry.stroke then
				entry.stroke.Transparency = 1 - entry.strokeFill * shown
			end
		end
		lastPainted = shown
	end

	local function hideAll()
		root.Visible = false
		currentScope = 0
	end

	local function layoutScope(center: Vector2, size: Vector2)
		local diameter = math.floor(math.min(size.X, size.Y) * SCOPE_HOLE)
		local half = diameter / 2
		local square = diameter * SCOPE_SQUARE / 2
		local at = UDim2.fromOffset(center.X, center.Y)
		scopeRing.Size = UDim2.fromOffset(diameter, diameter)
		scopeRing.Position = at
		scopeRim.Size = UDim2.fromOffset(diameter, diameter)
		scopeRim.Position = at
		local ringStroke = scopeRing:FindFirstChildOfClass("UIStroke")
		if ringStroke then
			ringStroke.Thickness = diameter * SCOPE_RING
		end
		local right = center.X + square
		local bottom = center.Y + square
		edges[1].Position = UDim2.fromOffset(0, 0)
		edges[1].Size = UDim2.fromOffset(size.X, math.max(0, center.Y - square))
		edges[2].Position = UDim2.fromOffset(0, bottom)
		edges[2].Size = UDim2.fromOffset(size.X, math.max(0, size.Y - bottom))
		edges[3].Position = UDim2.fromOffset(0, center.Y - square)
		edges[3].Size = UDim2.fromOffset(math.max(0, center.X - square), square * 2)
		edges[4].Position = UDim2.fromOffset(right, center.Y - square)
		edges[4].Size = UDim2.fromOffset(math.max(0, size.X - right), square * 2)
		-- Cruz con hueco central y marcas a lo largo de cada brazo.
		local length = math.max(2, half - SCOPE_GAP - 2)
		local tickIndex = 0
		for index, direction in SCOPE_DIRS do
			local line = lines[index]
			local horizontal = direction.X ~= 0
			line.Size = if horizontal then UDim2.fromOffset(length, 2) else UDim2.fromOffset(2, length)
			local middle = SCOPE_GAP + length / 2
			line.Position = UDim2.fromOffset(center.X + direction.X * middle, center.Y + direction.Y * middle)
			for _, fraction in SCOPE_TICKS do
				tickIndex += 1
				local tick = ticks[tickIndex]
				tick.Size = if horizontal then UDim2.fromOffset(2, 8) else UDim2.fromOffset(8, 2)
				local distance = half * fraction
				tick.Position = UDim2.fromOffset(center.X + direction.X * distance, center.Y + direction.Y * distance)
			end
		end
	end

	local function layoutFixed(center: Vector2)
		local at = UDim2.fromOffset(center.X, center.Y)
		redDot.Position = at
		local gap = settings.IronGapPx
		ironBlocks[1].Position = UDim2.fromOffset(center.X - gap / 2 - IRON_BLOCK.X / 2, center.Y - 4)
		ironBlocks[2].Position = UDim2.fromOffset(center.X + gap / 2 + IRON_BLOCK.X / 2, center.Y - 4)
		ironPost.Position = UDim2.fromOffset(center.X, center.Y - 3)
	end

	-- Posición de la cabeza del personaje propio (origen del disparo si no hay boca del arma).
	local function headPosition(camera: Camera): Vector3
		local character = Players.LocalPlayer.Character
		local head = if character then character:FindFirstChild("Head") else nil
		return if head and head:IsA("BasePart") then head.Position else camera.CFrame.Position
	end

	local function hideArc()
		for _, dot in arcDots do
			dot.Visible = false
		end
		arcRing.Visible = false
	end

	-- Pone los puntos de la trayectoria. "at" da el punto del mundo de cada paso (de 1 a ArcPoints).
	local function placeArc(
		camera: Camera,
		offset: Vector2,
		at: (step: number) -> Vector3,
		impact: Vector3,
		studs: number
	)
		for step, dot in arcDots do
			local screen = project(camera, at(step))
			dot.Visible = screen ~= nil
			if screen then
				dot.Position = UDim2.fromOffset(screen.X - offset.X, screen.Y - offset.Y)
			end
		end
		local screen, depth = project(camera, impact)
		arcRing.Visible = screen ~= nil
		if screen then
			local diameter = studsToPixels(camera, studs, depth) * 2
			arcRing.Size = UDim2.fromOffset(diameter, diameter)
			arcRing.Position = UDim2.fromOffset(screen.X - offset.X, screen.Y - offset.Y)
		end
	end

	local function updateArc(state: State, weapon: Weapons.WeaponDefinition)
		local camera = state.camera
		local origin = state.muzzle or headPosition(camera)
		local offset = root.AbsolutePosition
		local steps = #arcDots
		if weapon.lab and weapon.lab.effect == "AcidBurst" then
			-- Repite la fórmula de CombatService.acidLob (el servidor): el blanco recortado al alcance en
			-- horizontal, tiempo de vuelo por la velocidad en horizontal y una gravedad que da el arco
			-- Config.Lab.AcidArc × la distancia sobre la línea de tiro.
			local target = state.aimPoint
			local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
			if flat.Magnitude > weapon.range then
				flat = flat.Unit * weapon.range
				target = Vector3.new(origin.X + flat.X, target.Y, origin.Z + flat.Z)
			end
			local flatLook = camera.CFrame.LookVector
			local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(flatLook.X, 0, flatLook.Z).Unit
			local speed = weapon.projectileSpeed or DEFAULT_ACID_SPEED
			local distance = math.max(flat.Magnitude, 1)
			local seconds = distance / speed
			local gravity = 8 * Config.Lab.AcidArc * distance / (seconds * seconds)
			local rise = (target.Y - origin.Y) / seconds + gravity * seconds / 2
			local function pointAt(step: number): Vector3
				local t = seconds * (step - 1) / math.max(steps - 1, 1)
				return origin + direction * speed * t + Vector3.yAxis * (rise * t - gravity * t * t / 2)
			end
			placeArc(camera, offset, pointAt, pointAt(steps), Config.Lab.AcidRadius)
		else
			-- Bastón: recta hasta el punto apuntado, como mucho a su alcance, y el anillo del remate.
			local delta = state.aimPoint - origin
			local finish = if delta.Magnitude > weapon.range then origin + delta.Unit * weapon.range else state.aimPoint
			local function pointAt(step: number): Vector3
				return origin:Lerp(finish, (step - 1) / math.max(steps - 1, 1))
			end
			placeArc(camera, offset, pointAt, finish, Config.RangedChain.Finishers.Burst.radius)
		end
	end

	local handle = {} :: Handle
	handle.root = root
	handle.setWeapon = function(weapon)
		local newKind = Sights.kindOf(weapon)
		weaponNow = weapon
		if newKind == kind then
			return
		end
		kind = newKind
		for name, holder in holders do
			holder.Visible = name == newKind
		end
		lastPainted = -1
		lastCenter = Vector2.new(-1, -1)
		if not newKind then
			shown = 0
			hideAll()
		end
	end
	handle.update = function(state)
		local now = os.clock()
		local deltaTime = math.min(now - lastClock, 0.1)
		lastClock = now
		rawAlpha = if kind then state.alpha else 0
		if not kind then
			return
		end
		shown += (state.alpha - shown) * math.min(1, deltaTime * SMOOTH)
		if state.alpha <= 0 and shown < 0.01 then
			shown = 0
		end
		if shown <= 0 then
			hideAll()
			return
		end
		root.Visible = true
		if math.abs(shown - lastPainted) > 0.003 then
			paint()
		end
		currentScope = if kind == "Scope" then shown else 0
		local size = root.AbsoluteSize
		local center = state.center or size / 2
		if kind == "Scope" then
			if center ~= lastCenter or size ~= lastSize then
				layoutScope(center, size)
			end
		elseif kind == "Arc" then
			if weaponNow then
				updateArc(state, weaponNow)
			else
				hideArc()
			end
		elseif center ~= lastCenter then
			layoutFixed(center)
		end
		lastCenter = center
		lastSize = size
	end
	handle.covers = function()
		return kind ~= nil and rawAlpha > COVER_ALPHA
	end
	handle.scopeAlpha = function()
		return if kind == "Scope" then shown else 0
	end
	handle.destroy = function()
		currentScope = 0
		root:Destroy()
	end
	return handle
end

return Sights
