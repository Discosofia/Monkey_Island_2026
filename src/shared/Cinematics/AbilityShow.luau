--!strict
-- Habilidades de los roles sobre maniquíes y monos de una cinemática (Fase 25, G5: batallas montadas). Solo cliente.
-- AbilityShow.install(Sequencer) registra el evento
--
--   abilityFx { t, fx, from, to?, args? }
--     fx    el efecto (clave de FX, más abajo). OJO: no se llama «kind», que ya es el tipo del evento.
--     from  nombre del actor que lo lanza: un maniquí de scene.actors o un mono de CinematicMonkeyService.
--     to    el objetivo: nombre de un actor (maniquí o mono) o un Vector3 en el marco del anchor (cuentan X y Z; el
--           suelo se busca con un rayo contra el Terrain). Sin él, los efectos de área salen bajo «from».
--     args  ajustes del efecto (seconds, radius, count, range, degrees, delay…); lo que falta sale de Config.Abilities.
--   Con ctx.seeking (saltar en el tiempo) no se dibuja nada.
--
-- Es solo lo que se ve: llama a AbilityFxController.play, el mismo dibujo que el combate real (no toca la vida, ni
-- los cooldowns, ni CombatService). Se pide con FindFirstChild y pcall al módulo de ReplicatedStorage.CombatClient;
-- si no está o falla, el evento no hace nada y avisa una vez. Las firmas de AbilityFxController.EFFECTS que usa:
--
--   fx          AbilityFxController.play(…)                              viene de
--   Whirlwind   ("Whirlwind", personaje, segundos)                       from; seconds (2)
--   Charge      ("Charge", personaje, segundos)                          from; seconds (0,6). El rastro; la carrera es
--                                                                         un evento move del maniquí
--   WarCry      ("WarCry", personaje, segundos)                          from; seconds (1,8). La pose es la animación
--                                                                         WarCry (evento anim): si está publicada,
--                                                                         scream() no se usa
--   Quake       ("Quake", suelo, radio)                                  suelo de to o de from; radius (QuakeRadius)
--   Smash       ("Smash", suelo, hacia dónde mira, alcance, grados)      suelo de from, mirando a to; range
--                                                                         (SmashRange); degrees (SmashAngle)
--   MultiShot   ("Projectile", nil, "MultiShot", dueño, origen,          abanico de count (5) flechas desde la mano
--                dirección, velocidad, alcance, hora, false)              de from hacia to; sin id de servidor: se
--                                                                         paran a «alcance» (la distancia al
--                                                                         objetivo), no a un choque con el mono
--   Fireball    ("Projectile", nil, "Fireball", …, false, { radio })     bola de from a to; explota al llegar
--   FrostNova   ("FrostNova", centro, radio)                             suelo de to o de from; radius (NovaRadius)
--   Frozen      ("Frozen", modelo, segundos)                             to; seconds (2): el bloque de hielo
--   Meteor      ("Meteor", suelo, radio, segundos hasta el impacto)      suelo de to; radius, delay (MeteorDelay)
--   ArrowRain   ("ArrowRain", suelo, radio, segundos)                    suelo de to; radius (RainRadius), seconds
--                                                                         (2,5; en el juego, 4)
--   Lightning   ("Lightning", desde, hasta, modelo)                      de la mano de from al pecho de to
--   AreaHeal    ("AreaHeal", centro, radio)                              bajo from; radius (AreaHealRadius)
--
-- Lo que no se puede mostrar sobre un maniquí: la marca de las presas (MarkPrey, diana por atributos y etiqueta
-- Enemy), el escudo y el veneno (también por atributos), y el movimiento propio de la Embestida, el Torbellino y el
-- Parpadeo (los hace RoleController con el Player: aquí el maniquí se mueve con un evento move).
--
-- Tope de efectos: cada efecto declara un coste estimado (piezas y emisores vivos) y una duración; AbilityShow no deja
-- empezar uno si la suma pasa de Config.Budgets.Vfx de la calidad (FxQuality), si ya hay MAX_HEAVY grandes a la vez
-- o, para los grandes, retrasa el efecto hasta que pasen MIN_HEAVY_GAP segundos del anterior. En calidad baja los más
-- caros (ArrowRain, Meteor) se sustituyen por su «fallback» (más barato). Los costes son a ojo, sin medir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)

local AbilityShow = {}

local FOLDER_NAME = "CinematicActors" -- donde CinematicMonkeyService deja los monos
local MAX_HEAVY = 2 -- efectos grandes vivos a la vez
local MIN_HEAVY_GAP = 0.4 -- segundos mínimos entre el inicio de dos efectos grandes
local GROUND_RAY_UP = 60
local GROUND_RAY_DOWN = 200
local QUALITY_RANK = { Low = 1, Medium = 2, High = 3 }

type Quality = "Low" | "Medium" | "High"

-- Lo que se dibuja y lo que cuesta. cost = piezas y emisores que deja vivos a la vez (estimado a ojo, sin medir),
-- seconds = lo que dura viva, heavy = cuenta como efecto grande, minQuality = por debajo de esa calidad no sale (o
-- sale su fallback).
type Spec = {
	cost: number,
	seconds: (args: { [string]: any }) -> number,
	heavy: boolean,
	minQuality: Quality?,
	fallback: string?,
}

local function fixed(seconds: number): (args: { [string]: any }) -> number
	return function()
		return seconds
	end
end

local SPECS: { [string]: Spec } = {
	Whirlwind = {
		cost = 26,
		heavy = true,
		seconds = function(args)
			return (args.seconds or 2) + 0.5
		end,
	},
	Charge = { cost = 6, heavy = false, seconds = fixed(1.2) },
	WarCry = { cost = 12, heavy = false, seconds = fixed(2) },
	Quake = { cost = 34, heavy = true, seconds = fixed(1.6) },
	Smash = { cost = 30, heavy = true, seconds = fixed(1.4) },
	MultiShot = { cost = 14, heavy = false, seconds = fixed(1) },
	Fireball = { cost = 20, heavy = false, seconds = fixed(1.6) },
	FrostNova = { cost = 38, heavy = true, seconds = fixed(1.8) },
	Frozen = {
		cost = 14,
		heavy = false,
		seconds = function(args)
			return (args.seconds or 2) + 0.8
		end,
	},
	Meteor = {
		cost = 40,
		heavy = true,
		minQuality = "Medium",
		fallback = "Lightning",
		seconds = function(args)
			return (args.delay or Config.Abilities.MeteorDelay) + 1.2
		end,
	},
	ArrowRain = {
		cost = 60,
		heavy = true,
		minQuality = "Medium",
		fallback = "MultiShot",
		seconds = function(args)
			return (args.seconds or 2.5) + 1
		end,
	},
	Lightning = { cost = 12, heavy = false, seconds = fixed(1.2) },
	AreaHeal = { cost = 40, heavy = true, seconds = fixed(1.4) },
}

type Live = { endsAt: number, cost: number, heavy: boolean }

local live: { Live } = {}
local lastHeavyAt = -math.huge
local warnedNoFx = false

-- Módulos del combate del cliente, sin romper los places que no los tengan.
local function combatModule(...: string): any?
	local node: Instance? = ReplicatedStorage:FindFirstChild("CombatClient")
	for _, name in { ... } do
		node = if node then node:FindFirstChild(name) else nil
	end
	if not (node and node:IsA("ModuleScript")) then
		return nil
	end
	local ok, module = pcall(require, node)
	return if ok then module else nil
end

local function currentQuality(): Quality
	local ok, quality = pcall(function()
		return require(script.Parent.Parent.FxQuality).get()
	end)
	return if ok then quality else "Medium"
end

-- Actores ----------------------------------------------------------------------------------------------------

-- Un maniquí de scene.actors o un mono de CinematicMonkeyService (por su atributo CinematicActor y, si lo lleva, el
-- CinematicOwner de este jugador). Lo encontrado se guarda en ctx.actors para que los bocadillos del cómic apunten a él.
local function resolve(name: any, ctx: { [string]: any }): Model?
	if typeof(name) ~= "string" then
		return nil
	end
	local actors = ctx.actors
	local known = if typeof(actors) == "table" then actors[name] else nil
	if typeof(known) == "Instance" and known:IsA("Model") and known.Parent then
		return known
	end
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	local me = if Players.LocalPlayer then Players.LocalPlayer.UserId else nil
	if folder then
		for _, model in folder:GetChildren() do
			local owner = model:GetAttribute("CinematicOwner")
			if
				model:IsA("Model")
				and model:GetAttribute("CinematicActor") == name
				and (owner == nil or owner == me)
			then
				if typeof(actors) == "table" then
					actors[name] = model
				end
				return model
			end
		end
	end
	return nil
end

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Suelo bajo (X, Z) de "world", buscado solo contra el Terrain desde "from" hacia abajo.
local function groundColumn(world: Vector3, startY: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(world.X, startY, world.Z), Vector3.new(0, -GROUND_RAY_DOWN, 0), params)
	return if hit then hit.Position else world
end

type Target = { model: Model?, chest: Vector3, ground: Vector3 }

local function targetOf(raw: any, ctx: { [string]: any }): Target?
	if typeof(raw) == "Vector3" then
		local anchor: CFrame = ctx.anchor or CFrame.identity
		local world = anchor:PointToWorldSpace(Vector3.new(raw.X, 0, raw.Z))
		local ground = groundColumn(world, anchor.Position.Y + GROUND_RAY_UP)
		return { model = nil, chest = ground + Vector3.new(0, 2.5, 0), ground = ground }
	end
	local model = resolve(raw, ctx)
	local root = rootOf(model)
	if not (model and root) then
		return nil
	end
	return {
		model = model,
		chest = root.Position,
		ground = groundColumn(root.Position, root.Position.Y + 6),
	}
end

-- De dónde sale lo que lanza "model": su mano derecha (con el arma) o, si no, delante del pecho.
local function handOf(model: Model): Vector3
	local hand = model:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	local root = rootOf(model)
	return if root then root.Position + root.CFrame.LookVector * 1.2 + Vector3.new(0, 1, 0) else Vector3.zero
end

-- Lo que sabe hacer cada efecto ------------------------------------------------------------------------------

type Show = {
	fx: any, -- AbilityFxController
	from: Model,
	target: Target?,
	args: { [string]: any },
}

local function flatDirection(from: Vector3, to: Vector3): Vector3?
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if flat.Magnitude > 0.05 then flat.Unit else nil
end

local function ownGround(show: Show): Vector3?
	local root = rootOf(show.from)
	return if root then groundColumn(root.Position, root.Position.Y + 6) else nil
end

-- Las flechas y la bola de fuego: un proyectil sin id de servidor (nadie manda ProjectileEnd), que se detiene al
-- recorrer "range" y estalla donde cae.
local function shoot(show: Show, look: string, speed: number, angle: number, range: number, extra: { any }?)
	local target = show.target
	if not target then
		return
	end
	local origin = handOf(show.from)
	local aim = target.chest - origin
	if aim.Magnitude < 0.5 then
		return
	end
	local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim.Unit)
	show.fx.play(
		"Projectile",
		nil,
		look,
		show.from,
		origin,
		direction,
		speed,
		math.min(range, aim.Magnitude),
		Workspace:GetServerTimeNow(),
		false,
		extra
	)
end

local RUN: { [string]: (show: Show) -> () } = {
	Whirlwind = function(show)
		show.fx.play("Whirlwind", show.from, show.args.seconds or 2)
	end,
	Charge = function(show)
		show.fx.play("Charge", show.from, show.args.seconds or 0.6)
	end,
	WarCry = function(show)
		show.fx.play("WarCry", show.from, show.args.seconds or 1.8)
	end,
	Quake = function(show)
		local ground = if show.target then show.target.ground else ownGround(show)
		if ground then
			show.fx.play("Quake", ground, show.args.radius or Config.Abilities.QuakeRadius)
		end
	end,
	Smash = function(show)
		local ground = ownGround(show)
		local root = rootOf(show.from)
		if not (ground and root) then
			return
		end
		local facing = if show.target then flatDirection(root.Position, show.target.chest) else nil
		show.fx.play(
			"Smash",
			ground,
			facing or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit,
			show.args.range or Config.Abilities.SmashRange,
			show.args.degrees or Config.Abilities.SmashAngle
		)
	end,
	MultiShot = function(show)
		local count: number = show.args.count or 5
		local spread = math.rad(Config.Abilities.MultiShotSpreadDegrees)
		for index = 1, count do
			local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
			shoot(show, "MultiShot", Config.Abilities.MultiShotSpeed, angle, Config.Abilities.MultiShotRange, nil)
		end
	end,
	Fireball = function(show)
		shoot(
			show,
			"Fireball",
			Config.Abilities.FireballSpeed,
			0,
			Config.Abilities.FireballRange,
			{ show.args.radius or Config.Abilities.FireballSplashRadius }
		)
	end,
	FrostNova = function(show)
		local center = if show.target then show.target.ground else ownGround(show)
		if center then
			show.fx.play("FrostNova", center, show.args.radius or Config.Abilities.NovaRadius)
		end
	end,
	Frozen = function(show)
		if show.target and show.target.model then
			show.fx.play("Frozen", show.target.model, show.args.seconds or 2)
		end
	end,
	Meteor = function(show)
		if show.target then
			show.fx.play(
				"Meteor",
				show.target.ground,
				show.args.radius or Config.Abilities.MeteorRadius,
				show.args.delay or Config.Abilities.MeteorDelay
			)
		end
	end,
	ArrowRain = function(show)
		if show.target then
			show.fx.play(
				"ArrowRain",
				show.target.ground,
				show.args.radius or Config.Abilities.RainRadius,
				show.args.seconds or 2.5
			)
		end
	end,
	Lightning = function(show)
		if show.target then
			show.fx.play("Lightning", handOf(show.from), show.target.chest, show.target.model)
		end
	end,
	AreaHeal = function(show)
		local root = rootOf(show.from)
		if root then
			show.fx.play("AreaHeal", root.Position, show.args.radius or Config.Abilities.AreaHealRadius)
		end
	end,
}

-- Tope ----------------------------------------------------------------------------------------------------

local function pruneLive(now: number)
	for index = #live, 1, -1 do
		if live[index].endsAt <= now then
			table.remove(live, index)
		end
	end
end

local function warnSkip(message: string)
	if RunService:IsStudio() then
		warn(`AbilityShow: {message}`)
	end
end

-- Lanza "fx" si cabe en el tope; si no, su fallback (una vez) o nada. "delayed" marca el reintento de un efecto grande
-- que esperó a que pasara MIN_HEAVY_GAP.
local function launch(
	name: string,
	event: { [string]: any },
	ctx: { [string]: any },
	allowFallback: boolean,
	delayed: boolean
)
	local spec = SPECS[name]
	local run = RUN[name]
	if not (spec and run) then
		warn(`AbilityShow: efecto desconocido ({name})`)
		return
	end
	local function fallback(reason: string)
		warnSkip(`{name} no sale ({reason})`)
		if allowFallback and spec.fallback then
			launch(spec.fallback, event, ctx, false, false)
		end
	end
	local quality = currentQuality()
	if spec.minQuality and QUALITY_RANK[quality] < QUALITY_RANK[spec.minQuality] then
		fallback(`calidad {quality}`)
		return
	end
	local now = os.clock()
	pruneLive(now)
	local cost = 0
	local heavy = 0
	for _, item in live do
		cost += item.cost
		if item.heavy then
			heavy += 1
		end
	end
	if cost + spec.cost > Config.Budgets.Vfx[quality] or (spec.heavy and heavy >= MAX_HEAVY) then
		fallback(`tope de efectos, calidad {quality}: {cost + spec.cost} piezas, {heavy} grandes`)
		return
	end
	-- Entre dos efectos grandes, al menos MIN_HEAVY_GAP: si es demasiado pronto, espera lo que falte.
	if spec.heavy and not delayed and now - lastHeavyAt < MIN_HEAVY_GAP then
		local wait = MIN_HEAVY_GAP - (now - lastHeavyAt)
		lastHeavyAt = now + wait -- reserva el hueco para que otro grande no se cuele delante
		task.delay(wait, function()
			if not ctx._abilityShowStopped then
				launch(name, event, ctx, allowFallback, true)
			end
		end)
		return
	end

	local fx = combatModule("Controllers", "AbilityFxController")
	if not fx then
		if not warnedNoFx then
			warnedNoFx = true
			warn("AbilityShow: no hay AbilityFxController en CombatClient; los eventos abilityFx no hacen nada")
		end
		return
	end
	local from = resolve(event.from, ctx)
	if not from then
		warn(`AbilityShow: {name} pide un actor que no existe ({event.from})`)
		return
	end
	local args: { [string]: any } = event.args or {}
	if spec.heavy then
		lastHeavyAt = now
	end
	table.insert(live, { endsAt = now + spec.seconds(args), cost = spec.cost, heavy = spec.heavy })
	local ok, err = pcall(run, { fx = fx, from = from, target = targetOf(event.to, ctx), args = args })
	if not ok then
		warn(`AbilityShow: falla {name}: {err}`)
	end
end

function AbilityShow.install(sequencer: any)
	sequencer.registerHandler("abilityFx", function(event, ctx)
		if ctx.seeking then
			return
		end
		if typeof(event.fx) ~= "string" then
			warn("AbilityShow: el evento abilityFx necesita fx")
			return
		end
		launch(event.fx, event, ctx, true, false)
	end)
	sequencer.addHooks({
		start = function(_, ctx)
			table.clear(live)
			lastHeavyAt = -math.huge
			ctx._abilityShowStopped = false
			-- Para que los bocadillos del cómic encuentren a los monos del servidor (Comic.findActor).
			ctx.resolveActor = function(name: any): Model?
				return resolve(name, ctx)
			end
		end,
		finish = function(_, ctx)
			ctx._abilityShowStopped = true
			table.clear(live)
		end,
	})
end

return AbilityShow
