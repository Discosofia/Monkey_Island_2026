--!strict
-- Llegada a la isla (Fase 25, G4). Cada jugador ve una vez por visita al servidor la escena de la tripulación
-- llegando a la playa: «Arrival» entera la primera vez (hasta verla entera no se puede saltar; antes suena la travesía
-- en lancha, «Voyage», con su propio id) y «ArrivalShort» las siguientes. Es una escena local (solo la ve quien llega). CinematicService marca como vista la escena que se vio
-- entera por su id, así que «Arrival» solo cuenta cuando se vio la larga y la corta nunca la marca.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CinematicService = require(script.Parent.CinematicService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Cinematics = require(game:GetService("ReplicatedStorage").Shared.Data.Cinematics)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local MatchService = require(script.Parent.MatchService)
local PlayerData = require(game:GetService("ServerScriptService").ServerShared.PlayerData)

-- Playa de arena de la Isla: -Z local es tierra adentro y +Z el mar.
local ANCHOR = CFrame.new(0, 3.0, 946)
-- Espera tras tener personaje y perfil para que el cliente tenga listo el controlador de cinemáticas.
local START_DELAY_SECONDS = 2
-- Si la escena no se puede lanzar (por ejemplo, ya tiene una en marcha este mismo jugador), se reintenta cada tanto
-- hasta el límite. Los amigos que entran a la vez no se esperan unos a otros: cada uno tiene su ejecución.
local RETRY_SECONDS = 0.5
local MAX_WAIT_SECONDS = 40

-- Dónde espera el personaje real mientras suena la escena: en la playa, 45 studs al costado de la tripulación y fuera
-- de plano. El terreno se dibuja fino solo cerca de quien juega; con el jugador en el Basecamp, a 950 studs, la
-- arena salía en facetas y más alta que la real, y los maniquíes quedaban hundidos.
local WAIT_OFFSET = Vector3.new(-45, 0, 0)
local WAIT_LIFT = 3.4 -- altura de la raíz sobre el suelo
-- Cada jugador espera en su hueco, WAIT_SPACING studs más allá que el anterior (anclados e invisibles, para que no se
-- pisen). El hueco es el menor libre y se devuelve al volver.
local WAIT_SPACING = 6
-- Segundos que se espera, con el personaje ya en la playa, antes de empezar: el terreno de alrededor tarda en dibujarse
-- fino y, sin la espera, los primeros planos salían con la arena gruesa y los maniquíes hundidos.
local SETTLE_SECONDS = 2.5
-- Al volver al Basecamp (a 950 studs) se espera a que se cargue su terreno antes de soltar al personaje: sin ello
-- caía por el vacío y recibía daño.
local RETURN_STREAM_SECONDS = 6
-- Tiempo mínimo que se ve la tarjeta de regreso, aunque el terreno cargue al instante.
local RETURN_MIN_SECONDS = 1.6
-- Tope de la espera al aviso del cliente de que ya hay suelo bajo el personaje (si no llega, se suelta igual).
local RETURN_MAX_SECONDS = 15
-- Atributo del Player que el cliente lee (CinematicClient): mientras tenga valor, tarjeta de espera ("Arrive" antes de
-- la escena, "Return" al volver). Se pone al entrar,
-- antes de la escena, y se quita cuando el personaje ya está de vuelta con el terreno cargado.
local HOLD_ATTRIBUTE = "ArrivalHold"
-- Segundos antes del final de la travesía en que el atributo pasa a "Next" (sigue la llegada). El cliente lo lee al acabar
-- su escena (0,4 s después de su final) y, mientras suena, lo ignora.
local NEXT_HOLD_LEAD_SECONDS = 1
-- Escena que suena antes de la llegada larga, la primera vez.
local VOYAGE_ID = "Voyage"

local ArrivalService = {}

ArrivalService.ANCHOR = ANCHOR

local started: { [Player]: boolean } = {}
-- Jugadores cuyo cliente ya avisó (ArrivalGround) de que tiene suelo cargado en el Basecamp.
local groundReady: { [Player]: boolean } = {}
-- Hueco de espera en la playa de cada jugador que está en ella (0, 1, 2…).
local waitSlot: { [Player]: number } = {}

local function takeSlot(player: Player): number
	local used: { [number]: boolean } = {}
	for _, slot in waitSlot do
		used[slot] = true
	end
	local slot = 0
	while used[slot] do
		slot += 1
	end
	waitSlot[player] = slot
	return slot
end

-- Batallas con jefe (G5b): los monos reales de la isla que andan por el escenario salían en plano (con su nombre) y
-- mordían al personaje oculto. Dentro de CLEAR_RADIUS_STUDS del anchor se anclan, se esconden y se les apagan los
-- carteles; la función devuelta los deja como estaban. "keep" es lo que no se toca (el jefe de plató y los monos de
-- las escenas).
local CLEAR_RADIUS_STUDS = 130

local CLEAR_SWEEP_SECONDS = 0.4 -- cada cuánto se vuelve a barrer: los monos reales aparecen después de colocar al jugador

local function clearArea(center: Vector3, keep: Instance?, radius: number?): () -> ()
	local clearRadius = radius or CLEAR_RADIUS_STUDS
	local saved: { { instance: Instance, transparency: number?, enabled: boolean?, anchored: boolean? } } = {}
	local done: { [Instance]: boolean } = {}
	local active = true
	local function hide(tagged: Instance)
		for _, descendant in tagged:GetDescendants() do
			local item = descendant :: any
			if descendant:IsA("BasePart") then
				table.insert(
					saved,
					{ instance = descendant, transparency = item.Transparency, anchored = item.Anchored }
				)
				item.Transparency = 1
				item.Anchored = true
			elseif descendant:IsA("Decal") then
				table.insert(saved, { instance = descendant, transparency = item.Transparency })
				item.Transparency = 1
			elseif descendant:IsA("BillboardGui") and item.Enabled then
				table.insert(saved, { instance = descendant, enabled = true })
				item.Enabled = false
			end
		end
	end
	local function sweep()
		for _, tagged in CollectionService:GetTagged(Config.Combat.EnemyTag) do
			local root = if tagged:IsA("Model") then tagged.PrimaryPart else nil
			if
				root
				and not done[tagged]
				and not (keep and tagged:IsDescendantOf(keep))
				and not tagged:GetAttribute("CinematicActor")
				and (root.Position - center).Magnitude <= clearRadius
			then
				done[tagged] = true
				hide(tagged)
			end
		end
	end
	sweep()
	task.spawn(function()
		while active do
			task.wait(CLEAR_SWEEP_SECONDS)
			if active then
				sweep()
			end
		end
	end)
	return function()
		active = false
		for _, entry in saved do
			local item = entry.instance :: any
			if item.Parent then
				if entry.transparency ~= nil then
					item.Transparency = entry.transparency
				end
				if entry.anchored ~= nil then
					item.Anchored = entry.anchored
				end
				if entry.enabled ~= nil then
					item.Enabled = true
				end
			end
		end
	end
end

-- Lleva el personaje a la playa (invisible y quieto) y devuelve la función que lo deja como estaba.
-- "waitPoint" (mundo) es el sitio de espera de una batalla con jefe; sin él, el hueco de la playa.
local function moveToBeach(player: Player, slot: number, waitPoint: Vector3?): () -> ()
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (character and root and root:IsA("BasePart")) then
		return function() end
	end
	local home = character:GetPivot()
	local spot = waitPoint or ANCHOR:PointToWorldSpace(WAIT_OFFSET + Vector3.new(-WAIT_SPACING * slot, 0, 0))
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(spot.X, spot.Y + 80, spot.Z), Vector3.new(0, -160, 0), terrainOnly)
	local groundY = if hit then hit.Position.Y else spot.Y
	local wasAnchored = root.Anchored
	-- Lo que se ve de él se esconde y se apaga lo que lo delata: el título sobre la cabeza, estelas, auras y luces.
	local hidden: { [Instance]: number } = {}
	local switchedOff: { Instance } = {}
	for _, descendant in character:GetDescendants() do
		local item = descendant :: any
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			hidden[descendant] = item.Transparency
			item.Transparency = 1
		elseif
			(
				descendant:IsA("BillboardGui")
				or descendant:IsA("ParticleEmitter")
				or descendant:IsA("Trail")
				or descendant:IsA("Beam")
				or descendant:IsA("Light")
			) and item.Enabled
		then
			table.insert(switchedOff, descendant)
			item.Enabled = false
		end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.new(spot.X, groundY + WAIT_LIFT, spot.Z))
	root.Anchored = true
	return function()
		for instance, transparency in hidden do
			if instance.Parent then
				(instance :: any).Transparency = transparency
			end
		end
		for _, instance in switchedOff do
			if instance.Parent then
				(instance :: any).Enabled = true
			end
		end
		if character.Parent and root.Parent then
			character:PivotTo(home)
			root.AssemblyLinearVelocity = Vector3.zero
			-- Se queda quieto hasta que el terreno de casa esté cargado (si no, caería por el vacío).
			player:SetAttribute(HOLD_ATTRIBUTE, "Return")
			task.spawn(function()
				local startedAt = os.clock()
				groundReady[player] = nil
				pcall(player.RequestStreamAroundAsync, player, home.Position, RETURN_STREAM_SECONDS)
				-- Se espera el aviso del cliente (suelo ya cargado bajo el personaje) y el mínimo de la tarjeta.
				while
					player.Parent
					and (not groundReady[player] or os.clock() - startedAt < RETURN_MIN_SECONDS)
					and os.clock() - startedAt < RETURN_MAX_SECONDS
				do
					task.wait(0.1)
				end
				groundReady[player] = nil
				if root.Parent then
					root.Anchored = wasAnchored
				end
				if player.Parent then
					player:SetAttribute(HOLD_ATTRIBUTE, nil)
				end
			end)
		elseif player.Parent then
			player:SetAttribute(HOLD_ATTRIBUTE, nil)
		end
	end
end

-- Lanza la escena "sceneId" a "player": primero lo lleva a la playa, espera a que se dibuje el terreno y entonces empieza.
-- Con "beforeId" (la travesía) esa escena suena antes y, al acabar, sigue "sceneId" sin soltar al personaje ni dejar
-- entrar a otro. Varios jugadores pueden llegar a la vez (cada uno con su ejecución local y su hueco de espera).
-- false si este jugador ya tiene una en marcha.
-- Con "stage" (batalla contra un jefe, G5b) la escena no es la de la playa: "create" monta al jefe y devuelve el anchor
-- de la escena, el modelo del jefe y la función que lo borra; el personaje espera en "waitOffset" (marco del anchor) y
-- la escena sale con ese anchor, "bossId" y context = { bossModel }. El jefe se monta antes de la espera para que el
-- terreno y el modelo carguen, y se borra al acabar. Una escena sin jefe (la Supervivencia, G14b, en el Basecamp) pone
-- `bossId` a nil y devuelve nil como modelo: "create" solo da el anchor (y la función que limpia lo que monte, si algo).
export type Stage = {
	bossId: string?,
	waitOffset: Vector3,
	create: () -> (CFrame, Model?, () -> ()),
	clearRadius: number?, -- studs a limpiar de monos reales (130 por defecto); la Supervivencia ruedan fuera de la empalizada
}

function ArrivalService.play(player: Player, sceneId: string, beforeId: string?, stage: Stage?): boolean
	if
		CinematicService.isRunningFor(sceneId, player)
		or (beforeId ~= nil and CinematicService.isRunningFor(beforeId, player))
		or waitSlot[player] ~= nil
	then
		return false
	end
	-- Pantalla en negro en su cliente (CinematicClient) hasta que empiece la escena.
	player:SetAttribute(HOLD_ATTRIBUTE, "Arrive")
	local sceneAnchor = ANCHOR
	local bossModel: Model? = nil
	local removeStage: (() -> ())? = nil
	local waitPoint: Vector3? = nil
	local protectedUntil: number? = nil
	if stage then
		local removeBoss: () -> ()
		sceneAnchor, bossModel, removeBoss = stage.create()
		waitPoint = sceneAnchor:PointToWorldSpace(stage.waitOffset)
		-- Sin monos reales alrededor y con el personaje oculto protegido (si no, lo mordían: «-20» en pantalla).
		local restoreArea = clearArea(
			sceneAnchor.Position,
			if bossModel then bossModel.Parent or bossModel else nil,
			if stage then stage.clearRadius else nil
		)
		local scene = Cinematics[sceneId]
		protectedUntil = Workspace:GetServerTimeNow() + SETTLE_SECONDS + (if scene then scene.duration else 20) + 15
		player:SetAttribute("InvulnerableUntil", protectedUntil)
		removeStage = function()
			restoreArea()
			if player.Parent and player:GetAttribute("InvulnerableUntil") == protectedUntil then
				player:SetAttribute("InvulnerableUntil", nil)
			end
			removeBoss()
		end
	end
	local back = moveToBeach(player, takeSlot(player), waitPoint)
	task.wait(SETTLE_SECONDS)
	local function finish()
		waitSlot[player] = nil
		back()
		if removeStage then
			removeStage()
		end
	end
	local function launch(id: string, onEnd: () -> ()): boolean
		return player.Parent ~= nil
			and CinematicService.play(id, {
				audience = { player },
				anchor = sceneAnchor,
				bossId = if stage then stage.bossId else nil,
				context = if bossModel then { bossModel = bossModel } else nil,
				onFinished = onEnd,
			})
	end
	local ok: boolean
	if beforeId then
		ok = launch(beforeId, function()
			if player.Parent then
				player:SetAttribute(HOLD_ATTRIBUTE, "Arrive")
			end
			if launch(sceneId, finish) then
				return
			end
			finish()
		end)
		if ok then
			-- Un segundo antes de acabar la travesía el cliente sabe que sigue otra escena: al acabar enseña la tarjeta
			-- de espera de la llegada y no la de volver al Basecamp.
			local scene = Cinematics[beforeId]
			task.delay(if scene then scene.duration - NEXT_HOLD_LEAD_SECONDS else 0, function()
				if player.Parent and player:GetAttribute(HOLD_ATTRIBUTE) == "Arrive" then
					player:SetAttribute(HOLD_ATTRIBUTE, "Next")
				end
			end)
		end
	else
		ok = launch(sceneId, finish)
	end
	if not ok then
		finish()
	end
	return ok
end

local function run(player: Player)
	if started[player] then
		return
	end
	started[player] = true
	-- Tarjeta de espera desde que entra: antes de la escena se vería al personaje flotando mientras carga el Basecamp.
	player:SetAttribute(HOLD_ATTRIBUTE, "Arrive")
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	if not PlayerData.waitFor(player) then
		player:SetAttribute(HOLD_ATTRIBUTE, nil)
		return
	end
	task.wait(START_DELAY_SECONDS)
	local deadline = os.clock() + MAX_WAIT_SECONDS
	while player.Parent and not MatchService.isOver() do
		-- La primera vez (Arrival aún sin ver entera) la llegada va precedida de la travesía; después, la corta sola.
		local first = not CinematicService.hasSeen(player, "Arrival")
		local launched = if first
			then ArrivalService.play(player, "Arrival", VOYAGE_ID)
			else ArrivalService.play(player, "ArrivalShort")
		if launched then
			return
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(RETRY_SECONDS)
	end
	-- Sin escena (se acabó el plazo o la partida): se quita el negro.
	if player.Parent then
		player:SetAttribute(HOLD_ATTRIBUTE, nil)
	end
end

function ArrivalService:Start()
	Remotes.ArrivalGround.OnServerEvent:Connect(function(player: Player)
		groundReady[player] = true
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(run, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		started[player] = nil
		groundReady[player] = nil
		waitSlot[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(run, player)
	end
end

return ArrivalService
