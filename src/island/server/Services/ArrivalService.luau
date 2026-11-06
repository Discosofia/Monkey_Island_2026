--!strict
-- Llegada a la isla (Fase 25, G4). Cada jugador ve una vez por visita al servidor la escena de la tripulación
-- llegando a la playa: «Arrival» entera la primera vez (hasta verla entera no se puede saltar) y «ArrivalShort» las
-- siguientes. Es una escena local (solo la ve quien llega). CinematicService marca como vista la escena que se vio
-- entera por su id, así que «Arrival» solo cuenta cuando se vio la larga y la corta nunca la marca.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CinematicService = require(script.Parent.CinematicService)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local MatchService = require(script.Parent.MatchService)
local PlayerData = require(game:GetService("ServerScriptService").ServerShared.PlayerData)

-- Playa de arena de la Isla: -Z local es tierra adentro y +Z el mar.
local ANCHOR = CFrame.new(0, 3.0, 946)
-- Espera tras tener personaje y perfil para que el cliente tenga listo el controlador de cinemáticas.
local START_DELAY_SECONDS = 2
-- Si otra escena igual está en marcha (otro amigo viendo la suya), se reintenta cada tanto hasta el límite.
local RETRY_SECONDS = 0.5
local MAX_WAIT_SECONDS = 40

-- Dónde espera el personaje real mientras suena la escena: en la playa, 45 studs al costado de la tripulación y fuera
-- de plano. El terreno se dibuja fino solo cerca de quien juega; con el jugador en el Basecamp, a 950 studs, la
-- arena salía en facetas y más alta que la real, y los maniquíes quedaban hundidos.
local WAIT_OFFSET = Vector3.new(-45, 0, 0)
local WAIT_LIFT = 3.4 -- altura de la raíz sobre el suelo
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

local ArrivalService = {}

ArrivalService.ANCHOR = ANCHOR

local started: { [Player]: boolean } = {}
-- Jugadores cuyo cliente ya avisó (ArrivalGround) de que tiene suelo cargado en el Basecamp.
local groundReady: { [Player]: boolean } = {}

-- Lleva el personaje a la playa (invisible y quieto) y devuelve la función que lo deja como estaba.
local function moveToBeach(player: Player): () -> ()
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (character and root and root:IsA("BasePart")) then
		return function() end
	end
	local home = character:GetPivot()
	local spot = ANCHOR:PointToWorldSpace(WAIT_OFFSET)
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

-- Solo una llegada a la vez (la escena es única por id y mientras alguien espera en la playa no entra otro).
local busy = false

-- Lanza la escena "sceneId" a "player": primero lo lleva a la playa, espera a que se dibuje el terreno y entonces empieza.
-- false si ya hay una en marcha.
function ArrivalService.play(player: Player, sceneId: string): boolean
	if busy or CinematicService.isRunning(sceneId) then
		return false
	end
	busy = true
	-- Pantalla en negro en su cliente (CinematicClient) hasta que empiece la escena.
	player:SetAttribute(HOLD_ATTRIBUTE, "Arrive")
	local back = moveToBeach(player)
	task.wait(SETTLE_SECONDS)
	local ok = player.Parent ~= nil
		and CinematicService.play(sceneId, {
			audience = { player },
			anchor = ANCHOR,
			onFinished = function()
				busy = false
				back()
			end,
		})
	if not ok then
		busy = false
		back()
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
		local sceneId = if CinematicService.hasSeen(player, "Arrival") then "ArrivalShort" else "Arrival"
		if ArrivalService.play(player, sceneId) then
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
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(run, player)
	end
end

return ArrivalService
