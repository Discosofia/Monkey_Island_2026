--!strict
-- Evento del huevo (GDD §11, Fase 5).
--   1. De día puede aparecer un huevo en la selva, con aviso global, su dirección y su rareza (se sortea
--      al aparecer con Config.Pets.RarityWeights y se ve en su color, Shared/EggModel).
--   2. Quien lo recoge lo lleva encima: va más lento, los monos cercanos van a por él y tiene el PvP
--      activado (otros jugadores con PvP pueden derribarlo y quedarse el huevo).
--   3. Si el portador cae, el huevo se queda en el suelo para que otro lo recoja.
--   4. Al llevarlo al Nido del Basecamp empieza la incubación: llegan oleadas a por él.
--   5. Al terminar la incubación, cada participante (quien lo llevó o estuvo cerca durante el viaje, y
--      quien esté en el Basecamp al final) se lleva un huevo de esa rareza (ServerShared/Eggs): va a su
--      nido del Lobby, a su mochila o queda pendiente. La mascota nace después, en el nido del Lobby.
-- El estado se publica en ReplicatedStorage ("EggStatus") para el HUD y, mientras el huevo espera en el
-- suelo, su sitio ("EggPosition") para las mascotas que lo olfatean (el beagle, UI/PetFollowers).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Compass = require(ReplicatedStorage.Shared.Compass)
local Config = require(ReplicatedStorage.Shared.Config)
local EggModel = require(ReplicatedStorage.Shared.EggModel)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local Retention = require(ServerScriptService.ServerShared.Retention)
local BasecampService = require(script.Parent.BasecampService)
local MonkeyService = require(script.Parent.MonkeyService)
local PvPService = require(script.Parent.PvPService)

local TICK_SECONDS = 0.5
local DELIVERY_DISTANCE = 10
local EGG_HALF_HEIGHT = EggModel.HALF_HEIGHT
local EGG_RADIUS = EggModel.RADIUS
-- Cuánto se hunde el huevo en el forro del nido (punto EggSeat de BuildModels).
local NEST_SINK = 0.35

type EggState = "Ground" | "Carried" | "Incubating"

local EggService = {}

local rng = Random.new()
-- "egg" es la esfera central (lleva el aviso, la luz y la soldadura a la cabeza del portador);
-- "eggModel" agrupa todas las piezas, para moverlas de sitio y resaltarlas juntas.
local egg: BasePart? = nil
local eggModel: Model? = nil
local state: EggState = "Ground"
-- Rareza del huevo que hay en la isla (se sortea al aparecer).
local rarity = "Common"
local carrier: Player? = nil
local participants: { [Player]: boolean } = {}
local incubationEndsAt = 0
local nest: Model? = nil

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text)
	end
end

local function setStatus(text: string?)
	ReplicatedStorage:SetAttribute("EggStatus", text)
end

-- El cliente puede no tener cargado el huevo si está lejos (la Isla carga por zonas): por eso su
-- sitio va en un atributo, no se busca el modelo.
local function publishPosition()
	local part = egg
	ReplicatedStorage:SetAttribute("EggPosition", if part and state == "Ground" then part.Position else nil)
end

local function clearEgg()
	if eggModel then
		eggModel:Destroy()
	end
	egg = nil
	eggModel = nil
	if carrier then
		carrier:SetAttribute("CarryingEgg", nil)
	end
	carrier = nil
	nest = nil
	table.clear(participants)
	setStatus(nil)
end

local function groundAt(position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(position.X, 400, position.Z), Vector3.new(0, -800, 0), params)
	if not hit or hit.Material == Enum.Material.Water or BasecampService.isInside(hit.Position) then
		return nil
	end
	return hit.Position
end

-- Altura del suelo (terreno o piezas) bajo el huevo: la más alta entre el centro y cuatro puntos
-- de su contorno, para que en una ladera no quede medio enterrado. Ignora jugadores y el huevo.
local function restingY(position: Vector3): number?
	local ignore: { Instance } = {}
	if eggModel then
		table.insert(ignore, eggModel)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local highest: number? = nil
	for i = 0, 4 do
		local angle = i * math.pi / 2
		local offset = if i == 0
			then Vector3.zero
			else Vector3.new(math.cos(angle), 0, math.sin(angle)) * EGG_RADIUS * 0.8
		local origin = position + offset + Vector3.new(0, 6, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
		if hit and (highest == nil or hit.Position.Y > highest) then
			highest = hit.Position.Y
		end
	end
	return highest
end

-- Mueve el huevo entero. Hay que hacerlo así (y no cambiando el CFrame de la esfera central): fuera
-- del Workspace las soldaduras no arrastran a las demás piezas, que se quedaban en el origen del mapa.
local function moveEgg(cframe: CFrame)
	if eggModel then
		eggModel:PivotTo(cframe)
	end
end

local pickUp: (player: Player) -> ()

local function rarityName(): string
	return string.lower(Rarities[rarity].name)
end

local function buildEgg(): BasePart
	local model, main = EggModel.build(rarity, "HuevoMisterioso")
	eggModel = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggPrompt"
	prompt.ActionText = "Recoger (activa PvP)"
	prompt.ObjectText = `Huevo {rarityName()}`
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = main
	prompt.Triggered:Connect(function(player)
		pickUp(player)
	end)
	return main
end

-- Quita la soldadura que une el huevo a la cabeza del portador.
local function unweld(part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
end

local function setPrompt(part: BasePart, enabled: boolean)
	local prompt = part:FindFirstChild("EggPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

local function setEggParent(parent: Instance)
	if eggModel then
		eggModel.Parent = parent
	end
end

-- Deja el huevo anclado en "cframe". Mientras alguien lo lleva, su cliente controla la física del
-- huevo e ignora las posiciones que manda el servidor: si se ancla y se mueve a la vez, ese cliente
-- lo deja congelado donde lo veía (sobre su cabeza). Así que primero el servidor recupera el control
-- y lo ancla, y un momento después lo pone en su sitio definitivo, que ya llega a todos.
local function settleEgg(part: BasePart, cframe: CFrame)
	local wasCarried = not part.Anchored
	if wasCarried then
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
	end
	part.Anchored = true
	setEggParent(Workspace)
	if not wasCarried then
		moveEgg(cframe)
		return
	end
	-- Un poco por encima ya en el servidor (para las distancias), y el sitio exacto un instante
	-- después: como la posición cambia, se vuelve a enviar a los clientes.
	moveEgg(cframe * CFrame.new(0, 0.05, 0))
	task.wait(0.15)
	if egg == part then
		moveEgg(cframe)
	end
end

-- Pone el huevo de pie sobre el suelo que haya bajo "position", con su aviso "Recoger".
local function placeOnGround(position: Vector3)
	local part = egg
	if not part then
		part = buildEgg()
		egg = part
	end
	local eggPart = part :: BasePart
	unweld(eggPart)
	local floor = restingY(position) or position.Y
	settleEgg(eggPart, CFrame.new(position.X, floor + EGG_HALF_HEIGHT + 0.05, position.Z))
	setPrompt(eggPart, true)
	state = "Ground"
end

function pickUp(player: Player)
	local part = egg
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if state ~= "Ground" or not part or not LifeState.isAlive(player) or not (head and head:IsA("BasePart")) then
		return
	end
	state = "Carried"
	carrier = player
	participants[player] = true
	player:SetAttribute("CarryingEgg", true)
	setPrompt(part, false)
	moveEgg(head.CFrame * CFrame.new(0, 0.5 + EGG_HALF_HEIGHT + 0.2, 0))
	part.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	setEggParent(character)
	PvPService.forceOn(player, 60, "llevas el huevo")
	announce(`🥚 {player.DisplayName} lleva el huevo. ¡Escóltalo hasta el nido!`)
end

local function drop(reason: string)
	local holder = carrier
	local part = egg
	if not (holder and part) then
		return
	end
	holder:SetAttribute("CarryingEgg", nil)
	carrier = nil
	placeOnGround(part.Position)
	announce(`🥚 {reason}: el huevo ha caído al suelo`)
end

local function findNest(): Model?
	local folder = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("BuildableId") == "Nest" then
			return model
		end
	end
	return nil
end

-- Fin de la incubación: el huevo se salva y cada participante se lleva uno de su rareza.
local function complete()
	local rewarded = table.clone(participants)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InBasecamp") == true then
			rewarded[player] = true
		end
	end
	local part = egg
	if part then
		EggModel.burst(part.Position, rarity)
		Sfx.play("EggHatch", part.Position)
	end
	local label = `{Rarities[rarity].name}`
	for player in rewarded do
		if player.Parent then
			MatchStats.add(player, MatchStats.EGGS)
			Retention.progress(player, "Egg")
			local where = Eggs.grant(player, rarity)
			local text = if where == "nest"
				then `🥚 ¡Huevo {label} a salvo! Ya se incuba en tu nido del Lobby`
				elseif where == "bag" then `🥚 ¡Huevo {label} a salvo! Guardado en tu mochila de huevos`
				elseif
					where == "pending"
				then `🥚 ¡Huevo {label} a salvo! Tu mochila está llena: decide en el nido del Lobby`
				else nil
			if text then
				Remotes.Notify:FireClient(player, text)
			end
		end
	end
	announce(`🥚 ¡El huevo {rarityName()} está a salvo! Cada defensor se lleva uno a su nido del Lobby`)
	clearEgg()
end

local function startIncubation(target: Model)
	local holder = carrier
	local part = egg
	if not (holder and part) then
		return
	end
	holder:SetAttribute("CarryingEgg", nil)
	carrier = nil
	state = "Incubating"
	nest = target
	-- Lo deja en el hueco del nido (su punto "EggSeat"), un poco hundido en el forro de paja.
	unweld(part)
	setPrompt(part, false)
	local seat = target:FindFirstChild("EggSeat", true)
	local bottom: Vector3
	if seat and seat:IsA("BasePart") then
		bottom = seat.Position
	else
		-- Nido sin ese punto: el centro de la caja, a 0,6 del fondo.
		local bounds, size = target:GetBoundingBox()
		bottom = bounds.Position - Vector3.new(0, size.Y / 2 - 0.6, 0)
	end
	settleEgg(
		part,
		CFrame.new(bottom + Vector3.new(0, EGG_HALF_HEIGHT - NEST_SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	)
	incubationEndsAt = os.clock() + Config.Egg.IncubationSeconds
	announce(`🥚 ¡El huevo {rarityName()} está en el nido! Defiéndelo {Config.Egg.IncubationSeconds} s`)

	-- Oleadas a por el nido.
	local center = Building.center() or BasecampService.getCenter()
	local match = MatchState.read()
	local day = if match then match.day else 1
	for wave = 1, Config.Egg.DefenseWaves do
		task.delay((wave - 1) * Config.Egg.IncubationSeconds / Config.Egg.DefenseWaves + 5, function()
			if egg ~= part or nest ~= target then
				return
			end
			local angle = rng:NextInteger(0, 3) * math.pi / 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local gate = center + direction * (Config.Building.PerimeterRadius - 10)
			local spawn = center + direction * (Config.Building.PerimeterRadius + Config.Siege.SpawnDistance)
			MonkeyService.spawnSiegeGroup("AulladorRojo", spawn, gate, 3 + day)
			announce(`🐒 ¡Los monos vienen a por el huevo desde {Compass.direction(center, spawn)}!`)
		end)
	end
end

-- Prueba (panel de Studio): termina ya la defensa del huevo que esté en el nido.
function EggService.hatchNow(): boolean
	if state ~= "Incubating" then
		return false
	end
	incubationEndsAt = os.clock()
	return true
end

-- Hace aparecer un huevo (de la rareza dada o sorteada). Uno que espere en el suelo se cambia por el
-- nuevo; si alguien lo lleva o está en el nido, no hace nada y devuelve false.
function EggService.spawnEgg(forcedRarity: string?): boolean
	if egg and state ~= "Ground" then
		return false
	end
	clearEgg()
	rarity = if forcedRarity and Rarities[forcedRarity] then forcedRarity else PetRoll.rollRarity(rng)
	local center = BasecampService.getCenter()
	for _ = 1, 60 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(Config.Egg.MinDistance, Config.Egg.MaxDistance)
		local ground = groundAt(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
		if ground then
			placeOnGround(ground)
			announce(
				`🥚 ¡Ha aparecido un huevo {string.upper(Rarities[rarity].name)} hacia {Compass.direction(
					center,
					ground
				)}! Llévalo al nido`
			)
			return true
		end
	end
	return false
end

local function tick()
	local part = egg
	if not part then
		return
	end
	if state == "Carried" then
		local holder = carrier
		if not holder or not holder.Parent then
			carrier = nil
			placeOnGround(groundAt(part.Position) or part.Position)
			return
		end
		if not LifeState.isAlive(holder) then
			drop(`{holder.DisplayName} ha caído`)
			return
		end
		PvPService.forceOn(holder, 60, "llevas el huevo")
		local position = part.Position
		MonkeyService.alert(position, Config.Egg.AttractRadius, holder)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and (character:GetPivot().Position - position).Magnitude <= Config.Egg.ParticipantRadius then
				participants[player] = true
			end
		end
		local target = findNest()
		if target and (target:GetPivot().Position - position).Magnitude <= DELIVERY_DISTANCE + 4 then
			startIncubation(target)
		end
		setStatus(`🥚 {holder.DisplayName} lleva el huevo {rarityName()}`)
	elseif state == "Incubating" then
		local target = nest
		if not target or not target.Parent then
			announce("💔 Los monos han destrozado el nido: el huevo se ha perdido")
			clearEgg()
			return
		end
		local remaining = math.ceil(incubationEndsAt - os.clock())
		if remaining <= 0 then
			complete()
		else
			setStatus(`🥚 Defiende el huevo {rarityName()}: {remaining} s`)
		end
	else
		setStatus(`🥚 Hay un huevo {rarityName()} en la isla`)
	end
end

function EggService:Start()
	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Egg.CheckSeconds)
			local match = MatchState.read()
			if not egg and match and match.phase == "Day" and rng:NextNumber() < Config.Egg.Chance then
				EggService.spawnEgg()
			end
		end
	end)
	while true do
		task.wait(TICK_SECONDS)
		tick()
		publishPosition()
	end
end

return EggService
