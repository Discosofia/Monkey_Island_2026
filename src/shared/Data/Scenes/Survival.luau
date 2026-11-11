--!strict
-- Escena Survival de las cinemáticas (ver la cabecera de Data/Cinematics). Archivo propio por el límite de locales del módulo grande.

local Kit = require(script.Parent.Parent.CinematicKit)
local Config = require(script.Parent.Parent.Parent.Config)
local Strings = require(script.Parent.Parent.Parent.Strings)

type Scene = Kit.Scene
type EventList = Kit.EventList
local cameraKey = Kit.cameraKey
local cutShots = Kit.cutShots
local yawBetween = Kit.yawBetween

-- ============================================================================ Supervivencia (Fase 25, G14b)
-- «Survival» (28 s, solo la versión normal): recolectar, hambre y sed, fabricar y construir en el Basecamp real. La lanza
-- «🎬 Supervivencia» del panel de la Isla con ArrivalService.play y un stage cuyo anchor es el suelo bajo el centro del Basecamp
-- (la hoguera, en (0, 0); la mesa de trabajo, en Config.Crafting.DefaultWorkbenchOffset = (-35, 0, 0), de cara a la hoguera).
-- El avatar (copia del jugador, con el hacha de piedra) y dos amigos: un Cazador (pico de piedra) y un Médico. El árbol, la roca y
-- la mata de plátanos son props de Shared/NodeModels; los muros y la antorcha, de Shared/BuildModels (eventos de SurvivalActor).
--    0 a  2,5  la tripulación llega corriendo a la hoguera (grúa que baja); caption «Sobrevive en la isla»
--  2,5 a  9    el avatar tala (3 tajos, el árbol cae: +4 Madera); el Cazador pica la roca (+3 Piedra); el Médico coge un racimo (+2 Banano)
--    9 a 14,5  las barras 🍖 y 💧 bajan y parpadean; el avatar come un plátano y el Cazador bebe un coco
-- 14,5 a 20    el avatar martillea en la mesa, sube y gira un Hacha de hueso (+1) y pasa a su mano
--   20 a 26    tres muros (fantasma verde, golpe, suben del suelo) y una antorcha que se enciende; la hora avanza hasta 18,8
--   26 a 28    los tres en la hoguera, ya de noche; título, logo y fundido (plano que se aleja)
-- Efectos pesados (caída del árbol, roca, polvo de cada pieza) separados al menos 0,4 s. Los textos llevan Strings.later; el nombre de
-- los objetos sale de Data/Items y Data/Weapons. Va dentro de una función por el límite de 200 locales del módulo.
local survivalScenes: { [string]: Scene? } = (function(): { [string]: Scene? }
	local out: { [string]: Scene? } = {}
	local function build(): Scene
		local Actors = require(script.Parent.Parent.Parent.Cinematics.Actors)
		local NodeModels = require(script.Parent.Parent.Parent.NodeModels)

		local SURVIVAL_SECONDS = 28
		local FIRE = Vector3.zero
		local TABLE_AT = Config.Crafting.DefaultWorkbenchOffset
		-- La recolección se rueda FUERA de la empalizada (dentro del Basecamp no hay árboles ni rocas): en el claro llano al norte
		-- de la puerta N (empalizada en z = -81; suelo a Y ≈ 12 con menos de 1 stud de variación, medido). Lo de abajo está
		-- escrito alrededor de (0, 0) y GATHER lo traslada allí. Los recursos reales más cercanos están a casi 70 studs, así que
		-- son props de NodeModels.
		local GATHER = Vector3.new(0, 0, -120)
		local function g(x: number, y: number, z: number): Vector3
			return Vector3.new(x + GATHER.X, y + GATHER.Y, z + GATHER.Z)
		end
		local TREE_AT = g(22, 0, -14)
		local ROCK_AT = g(22, 0, 11)
		local PLANT_AT = g(22, 0, 25)
		-- Dónde trabaja cada uno: a 3,8 studs de su prop y mirándolo (a 5,5 el hacha daba al aire, al lado del tronco).
		local AVATAR_TREE = g(18.2, 0, -13.7)
		local HUNTER_ROCK = g(18.2, 0, 11)
		local MEDIC_PLANT = g(18.2, 0, 25)
		local AVATAR_TABLE = Vector3.new(-30, 0, 0)
		-- Alrededor de la hoguera (llegada y cierre) y dónde esperan el Cazador y el Médico mientras se construye.
		local CAMP_AVATAR = Vector3.new(3.5, 0, 5)
		local CAMP_HUNTER = Vector3.new(-3.5, 0, 5)
		local CAMP_MEDIC = Vector3.new(6.5, 0, -1)
		local WAIT_HUNTER = Vector3.new(7, 0, 7)
		local WAIT_MEDIC = Vector3.new(10, 0, 2)
		-- Cierre: los tres en fila perpendicular al eje de la cámara de salida (que mira desde (15, -4)), para que no se solapen
		-- en pantalla, y de cara a la cámara.
		local END_CAMERA = Vector3.new(15, 0, -4)
		local END_AVATAR = Vector3.new(-2, 0, 2)
		local END_HUNTER = Vector3.new(-3.7, 0, -2.2)
		local END_MEDIC = Vector3.new(-0.3, 0, 6.2)
		-- Los muros, en un arco a 17 studs de la hoguera (grados desde +X hacia +Z), y la antorcha junto al último. El avatar trabaja
		-- por fuera, a 21 studs: así el muro que sube no lo tapa a la cámara de fuera.
		local WALL_RADIUS = 17 -- los bancos de la hoguera están a radio 11 (medido en el Basecamp), así que el arco queda fuera
		local WORK_RADIUS = 21
		local WALL_ANGLES = { 100, 140, 180 }
		local TORCH_ANGLE = 205
		local function arc(degrees: number, radius: number): Vector3
			local a = math.rad(degrees)
			return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		end
		local TORCH_AT = arc(TORCH_ANGLE, WALL_RADIUS)

		local events: EventList = {}
		local function add(event: { t: number, kind: string, [string]: any })
			table.insert(events, event)
		end
		local function put(t: number, actor: string, pos: Vector3, yaw: number)
			add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
		end
		-- Corre de un punto a otro con el giro de la marcha; la velocidad de la animación sale de lo que recorre.
		local function run(t: number, actor: string, from: Vector3, to: Vector3, seconds: number)
			add({
				t = t,
				kind = "anim",
				actor = actor,
				action = "Run",
				seconds = seconds + 0.1,
				speed = math.clamp((to - from).Magnitude / seconds / 16, 0.4, 1.2),
			})
			add({
				t = t,
				kind = "move",
				actor = actor,
				pos = to,
				yaw = yawBetween(from, to),
				seconds = seconds,
				easing = Enum.EasingStyle.Linear,
			})
		end
		local function face(t: number, actor: string, pos: Vector3, target: Vector3)
			put(t, actor, pos, yawBetween(pos, target))
		end
		local function anim(t: number, actor: string, action: string, seconds: number)
			add({ t = t, kind = "anim", actor = actor, action = action, seconds = seconds })
		end
		local function loot(t: number, actor: string, item: string, n: number)
			add({ t = t, kind = "loot", actor = actor, item = item, n = n })
		end
		local function hit(t: number, actor: string, node: string, material: string)
			add({ t = t, kind = "nodeHit", actor = actor, node = node, material = material })
		end

		-- ===== Apertura (0 a 2,5): llegan corriendo desde el sur
		add({ t = 0, kind = "letterbox" })
		-- Un Yarumo real a unos 14 studs de la tala (tronco blanco, y su pieza gris) salía en plano: se esconde en este cliente.
		add({ t = 0, kind = "hideReal", at = TREE_AT, radius = 36 })
		add({ t = 0.3, kind = "caption", text = Strings.later("Sobrevive en la isla"), seconds = 1.8 })
		run(0, "avatar", Vector3.new(5, 0, 38), CAMP_AVATAR, 2.2)
		run(0, "hunter", Vector3.new(-5, 0, 41), CAMP_HUNTER, 2.3)
		run(0, "medic", Vector3.new(9, 0, 34), CAMP_MEDIC, 2.3)
		face(2.25, "avatar", CAMP_AVATAR, FIRE)
		face(2.35, "hunter", CAMP_HUNTER, FIRE)
		face(2.4, "medic", CAMP_MEDIC, FIRE)

		-- ===== Recolectar (2,5 a 9): al cortar, el Cazador y el Médico ya están en su sitio (fuera de plano)
		local treeStart = g(10, 0, -12.5)
		put(2.5, "avatar", treeStart, yawBetween(treeStart, AVATAR_TREE))
		run(2.5, "avatar", treeStart, AVATAR_TREE, 0.7)
		face(3.2, "avatar", AVATAR_TREE, TREE_AT)
		face(2.5, "hunter", HUNTER_ROCK, ROCK_AT)
		face(2.5, "medic", MEDIC_PLANT, PLANT_AT)
		-- Tres tajos al árbol (el golpe llega a ~0,25 s del inicio del tajo) y la caída hacia el este: 1,2 s después toca el suelo.
		for _, swing in
			{ { t = 3.4, action = "Slash1" }, { t = 4.2, action = "Slash2" }, { t = 5.0, action = "Slash1" } }
		do
			anim(swing.t, "avatar", swing.action, 0.7)
			hit(swing.t + 0.25, "avatar", "tree", "wood")
		end
		add({ t = 5.7, kind = "nodeFall", node = "tree", dir = Vector3.xAxis })
		add({ t = 6.9, kind = "shake", amp = 0.15, seconds = 0.4 })
		-- El botín sale sobre la cabeza del avatar: tiene que ser mientras la cámara lo ve (la lateral acaba en 5,6).
		loot(5.3, "avatar", "Wood", 4)
		-- El Cazador pica la roca (2 golpes y se rompe) y el Médico coge un racimo. Todo con tiempo de verse: la roca cae a 8,3
		-- y el botín sale a 8,4, antes de que el plano acabe (9,0).
		anim(7.3, "hunter", "Slash1", 0.7)
		hit(7.55, "hunter", "rock", "stone")
		anim(7.4, "medic", "Craft", 1.2)
		add({ t = 7.85, kind = "nodeFall", node = "plant" })
		loot(7.95, "medic", "Banana", 2)
		anim(7.85, "hunter", "Slash2", 0.7)
		hit(8.1, "hunter", "rock", "stone")
		add({ t = 8.3, kind = "nodeFall", node = "rock" })
		loot(8.4, "hunter", "Stone", 3)

		-- ===== Hambre y sed (9 a 14,5): las barras bajan al umbral bajo y parpadean; comer y beber las sube
		add({ t = 9.0, kind = "survivalBars", hunger = 1, thirst = 1, seconds = 0 })
		add({ t = 9.3, kind = "caption", text = Strings.later("El hambre y la sed no esperan"), seconds = 2.2 })
		add({ t = 9.4, kind = "survivalBars", hunger = 0.16, thirst = 0.2, seconds = 1.6 })
		-- Comer y beber de cara a la cámara (en la grabación el avatar comía de espaldas) y con la mano derecha, la de Consume:
		-- sueltan el arma antes y la recogen al acabar.
		face(10.3, "avatar", AVATAR_TREE, g(13, 0, -5))
		add({ t = 10.3, kind = "equip", actor = "avatar", weapon = false })
		add({
			t = 10.6,
			kind = "holdProp",
			actor = "avatar",
			item = "Banana",
			hand = "Right",
			sound = "Eat",
			delay = 0.7,
		})
		anim(10.7, "avatar", "Consume", 1.5)
		add({ t = 11.4, kind = "survivalBars", hunger = 0.8, seconds = 0.7 })
		face(11.8, "hunter", HUNTER_ROCK, g(5, 0, 4))
		add({ t = 11.8, kind = "equip", actor = "hunter", weapon = false })
		add({
			t = 11.9,
			kind = "holdProp",
			actor = "hunter",
			item = "Coconut",
			hand = "Right",
			sound = "Drink",
			delay = 0.7,
		})
		add({ t = 12.3, kind = "holdProp", actor = "avatar", item = false })
		add({ t = 12.4, kind = "equip", actor = "avatar", weapon = "StoneAxe" })
		anim(12.0, "hunter", "Consume", 1.5)
		add({ t = 12.7, kind = "survivalBars", thirst = 0.85, seconds = 0.7 })
		add({ t = 13.7, kind = "holdProp", actor = "hunter", item = false })
		add({ t = 13.8, kind = "equip", actor = "hunter", weapon = "StonePick" })
		add({ t = 14.2, kind = "survivalBars", show = false })

		-- ===== Fabricar (14,5 a 20): dos golpes en la mesa, chispas, el hacha de hueso sube y gira y pasa a la mano
		put(14.5, "avatar", AVATAR_TABLE, yawBetween(AVATAR_TABLE, TABLE_AT))
		put(14.5, "hunter", WAIT_HUNTER, yawBetween(WAIT_HUNTER, FIRE))
		put(14.5, "medic", WAIT_MEDIC, yawBetween(WAIT_MEDIC, FIRE))
		add({ t = 14.8, kind = "caption", text = Strings.later("Fabrica tu propio equipo"), seconds = 2.2 })
		anim(14.7, "avatar", "Hammer", 1.4)
		add({ t = 16.2, kind = "craftFx", at = TABLE_AT + Vector3.new(0, 4.4, 0), weapon = "BoneAxe" })
		loot(16.5, "avatar", "BoneAxe", 1)
		add({ t = 18.4, kind = "equip", actor = "avatar", weapon = "BoneAxe" })
		anim(18.5, "avatar", "Cheer", 1.4)

		-- ===== Construir (20 a 26): fantasma verde, golpe y la pieza sube del suelo. La hora avanza hasta el anochecer.
		add({ t = 20.2, kind = "caption", text = Strings.later("Levanta tus defensas"), seconds = 2.4 })
		-- El anochecer se reparte en toda la escena: pasado 17,5 el mapa ya parece noche cerrada (se vio en la grabación),
		-- así que acaba en 18 y la antorcha encendida es lo que marca el final.
		add({ t = 9, kind = "clock", hour = 16.5, seconds = 5 })
		add({ t = 14.5, kind = "clock", hour = 17, seconds = 5 })
		add({ t = 19.5, kind = "clock", hour = 17.5, seconds = 4 })
		add({ t = 23.5, kind = "clock", hour = 18, seconds = 3 })
		local ghostAt = { 20.0, 21.2, 22.6 }
		local hammerAt = { 20.1, 21.5, 22.9 }
		local riseAt = { 20.6, 22.0, 23.4 }
		local previousSpot: Vector3? = nil
		for index, degrees in WALL_ANGLES do
			local wall = arc(degrees, WALL_RADIUS)
			local standAt = arc(degrees, WORK_RADIUS)
			local toFire = yawBetween(wall, FIRE)
			if previousSpot then
				run(hammerAt[index] - 0.6, "avatar", previousSpot, standAt, 0.6)
				face(hammerAt[index], "avatar", standAt, wall)
			else
				put(ghostAt[index], "avatar", standAt, yawBetween(standAt, wall))
			end
			previousSpot = standAt
			add({ t = ghostAt[index], kind = "buildGhost", id = "WoodWall", at = wall, yaw = toFire })
			anim(hammerAt[index], "avatar", "Hammer", 0.8)
			add({ t = riseAt[index], kind = "buildRise", id = "WoodWall", at = wall, yaw = toFire, seconds = 0.6 })
		end
		local torchSpot = arc(TORCH_ANGLE, WORK_RADIUS)
		run(23.7, "avatar", previousSpot :: Vector3, torchSpot, 0.5)
		face(24.2, "avatar", torchSpot, TORCH_AT)
		add({ t = 23.8, kind = "buildGhost", id = "StandingTorch", at = TORCH_AT })
		anim(24.2, "avatar", "Hammer", 0.8)
		add({ t = 24.4, kind = "buildRise", id = "StandingTorch", at = TORCH_AT, seconds = 0.6 }) -- antes de 24,7: más tiempo con llama

		-- ===== Cierre (26 a 28): los tres en la hoguera, ya de noche
		put(26.0, "avatar", END_AVATAR, yawBetween(END_AVATAR, END_CAMERA))
		put(26.0, "hunter", END_HUNTER, yawBetween(END_HUNTER, END_CAMERA))
		put(26.0, "medic", END_MEDIC, yawBetween(END_MEDIC, END_CAMERA))
		anim(26.2, "avatar", "Cheer", 1.4)
		anim(26.3, "hunter", "Cheer", 1.4)
		anim(26.4, "medic", "Cheer", 1.4)
		-- El título se va antes de que entre el logo (en la grabación se pisaban).
		add({ t = 25.7, kind = "title", text = Strings.later("Recolecta, fabrica, construye"), seconds = 0.55 })
		add({
			t = 27.35,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 0.5,
		})
		-- Negro hasta el final: tras acabar la escena, y antes de la pantalla de «Heading back», salía medio segundo de día.
		add({ t = 27.5, kind = "fade", seconds = 0.6, toBlack = true })

		-- ===== Cámara. Ninguna a menos de 8 studs de un actor ni de un muro; la grúa de entrada y la de salida van muy por
		-- encima. Las alturas son sobre el suelo del anchor (el centro del Basecamp).
		local function ring(degrees: number, y: number): Vector3
			local at = arc(degrees, 38) -- a 30 un muro llenaba el plano
			return Vector3.new(at.X, y, at.Z)
		end
		local function ringLook(degrees: number): Vector3
			local at = arc(degrees, WALL_RADIUS + 1)
			return Vector3.new(at.X, 3.2, at.Z)
		end
		local shots: { CameraShot } = {
			-- Grúa sobre el Basecamp que baja hacia la hoguera.
			{
				t0 = 0,
				t1 = 2.5,
				a = cameraKey(Vector3.new(-22, 28, 32), Vector3.new(0, 2, 2), 60), -- más baja: arriba, los actores salían diminutos
				b = cameraKey(Vector3.new(-16, 13, 24), Vector3.new(0, 2, 2), 60),
			},
			-- Lateral del hacha: el avatar a la izquierda y el árbol a la derecha.
			{
				t0 = 2.5,
				t1 = 5.6,
				-- (a 18 studs del avatar: a 10 el tronco ocupaba media pantalla)
				a = cameraKey(g(14, 3.5, 0), g(20, 3.3, -13.5), 55), -- z = 0, no 4: a 5,8 de la armadura del Cazador
				b = cameraKey(g(15, 3.4, -1), g(20, 3.3, -13.5), 52),
			},
			-- Contrapicado de la caída del árbol (hacia el este, de izquierda a derecha).
			{
				t0 = 5.6,
				t1 = 7.3,
				-- Desde x = 30 (a 22 el avatar quedaba cortado en el borde derecho).
				a = cameraKey(g(30, 1.4, -29), g(26, 7, -14), 62),
				b = cameraKey(g(30, 1.2, -28), g(32, 5, -14), 62),
			},
			-- Medio cruzado: el Cazador con la roca (izquierda) y el Médico con la mata (derecha).
			{
				t0 = 7.3,
				t1 = 9.0,
				-- En diagonal (a 12-24 studs): de lado se ve el pico contra la roca y las dos parejas quedan a distinta profundidad.
				a = cameraKey(g(8, 3.6, 2), g(19.5, 2.8, 18), 58),
				b = cameraKey(g(10, 3.4, 3), g(19.5, 2.8, 18), 55),
			},
			-- El avatar come.
			{
				t0 = 9.0,
				t1 = 11.8,
				a = cameraKey(g(13, 3, -5), g(18.2, 3.6, -13.7), 55),
				b = cameraKey(g(12.5, 3.1, -5.6), g(18.2, 3.6, -13.7), 50),
			},
			-- El Cazador bebe.
			{
				t0 = 11.8,
				t1 = 14.5,
				-- Empuje lento: la escena dura 2,7 s y beber, 1,5 (antes el plano casi no se movía y parecía congelado).
				a = cameraKey(g(2, 3.4, 2), g(18.2, 3.6, 11), 55),
				b = cameraKey(g(8, 3.1, 6), g(18.2, 3.6, 11), 48),
			},
			-- Picado sobre la mesa.
			{
				t0 = 14.5,
				t1 = 17.0,
				a = cameraKey(Vector3.new(-22, 11, 7), Vector3.new(-33, 3, 0), 52),
				b = cameraKey(Vector3.new(-24, 9.5, 6), Vector3.new(-34, 3.5, 0), 48),
			},
			-- Primer plano del arma que sube y gira.
			{
				t0 = 17.0,
				t1 = 20.0,
				-- Rodea la mesa mientras el arma sube y pasa a la mano: así no hay plano vacío cuando el arma ya no está.
				-- Desde el lado del avatar, no por detrás: su cabeza tapaba la mesa. El arma sube a ~6,4 de altura y entra en cuadro.
				a = cameraKey(Vector3.new(-28, 6.5, 12), Vector3.new(-34, 5.2, 0), 42),
				b = cameraKey(Vector3.new(-18, 5.5, -9), Vector3.new(-31, 3.5, 0), 46), -- a 15 del avatar (a 5 le pegaba en la cara)
			},
			-- Travelling lateral por fuera del arco de muros (tres tramos seguidos, sin corte entre ellos).
			{
				t0 = 20.0,
				t1 = 21.17,
				a = cameraKey(ring(70, 4.5), ringLook(85), 58),
				b = cameraKey(ring(100, 4.6), ringLook(115), 58),
			},
			{
				t0 = 21.17,
				t1 = 22.33,
				a = cameraKey(ring(100, 4.6), ringLook(115), 58),
				b = cameraKey(ring(130, 4.8), ringLook(145), 58),
			},
			{
				t0 = 22.33,
				t1 = 23.5,
				a = cameraKey(ring(130, 4.8), ringLook(145), 58),
				b = cameraKey(ring(160, 5), ringLook(175), 58),
			},
			-- Contraplano desde dentro del arco: la antorcha que se enciende, con el avatar al otro lado.
			{
				t0 = 23.5,
				t1 = 26.0,
				a = cameraKey(Vector3.new(-1, 3.6, -10), TORCH_AT + Vector3.new(0, 3, 0), 55),
				b = cameraKey(Vector3.new(-3, 3.8, -11), TORCH_AT + Vector3.new(0, 3, 0), 55),
			},
			-- Cierre: plano abierto que se aleja de la hoguera.
			{
				t0 = 26.0,
				t1 = SURVIVAL_SECONDS,
				a = cameraKey(Vector3.new(15, 6.5, -4), Vector3.new(0, 2.5, 2), 55),
				b = cameraKey(Vector3.new(36, 24, -16), Vector3.new(0, 2.5, 2), 60),
			},
		}

		-- ===== Actores. Los tres con snap (el suelo del Basecamp no es llano). Los props nacen en el mundo, sobre el terreno.
		local function nodeProp(at: Vector3, make: (base: Vector3) -> Model)
			return {
				kind = "prop",
				build = function(anchor: CFrame): Model
					local node = make(anchor:PointToWorldSpace(Actors.snapToTerrain(anchor, at)))
					node:SetAttribute("CinematicKeep", true)
					return node
				end,
			}
		end
		local actors: { [string]: { [string]: any } } = {
			avatar = {
				kind = "localPlayer",
				copy = true,
				role = "Guerrero",
				weapon = "StoneAxe",
				snap = true,
				pos = Vector3.new(5, 0, 38),
				yaw = 0,
			},
			hunter = {
				kind = "dummy",
				role = "Cazador",
				armor = "VolcanicArmor",
				weapon = "StonePick",
				snap = true,
				pos = Vector3.new(-5, 0, 41),
				yaw = 0,
			},
			medic = {
				kind = "dummy",
				role = "Medico",
				outfit = "CeibaOfLifeOutfit",
				weapon = false,
				snap = true,
				pos = Vector3.new(9, 0, 34),
				yaw = 0,
			},
			tree = nodeProp(TREE_AT, function(base)
				return NodeModels.buildTree(base, Random.new(14), 0.9, "Frondoso")
			end),
			rock = nodeProp(ROCK_AT, function(base)
				return NodeModels.buildRock(base, Random.new(14), 1.2)
			end),
			plant = nodeProp(PLANT_AT, function(base)
				return NodeModels.buildMusa("BananaPlant", base, Random.new(14))
			end),
		}

		return {
			duration = SURVIVAL_SECONDS + 0.6, -- el negro final se sostiene hasta que acaba la escena
			audience = "Self",
			freeze = false,
			skippable = true,
			hour = 16,
			-- El suelo del Basecamp cargado donde se pisa: la hoguera, los tres props, la mesa y el arco de muros.
			waitTerrain = { FIRE, TREE_AT, ROCK_AT, PLANT_AT, AVATAR_TABLE, arc(100, WALL_RADIUS), TORCH_AT },
			actors = actors,
			camera = cutShots(shots),
			events = events,
		}
	end

	local ok, built = pcall(build)
	if ok then
		out.Survival = built :: Scene
	else
		warn(`Cinematics: no se pudo construir la escena Survival: {built}`)
	end
	return out
end)()

return { Survival = survivalScenes.Survival }
