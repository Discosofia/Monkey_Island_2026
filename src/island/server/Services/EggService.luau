--!strict
-- Evento del huevo (GDD §11, Fase 5).
--   1. De día puede aparecer un huevo misterioso en la selva, con aviso global y su dirección.
--   2. Quien lo recoge lo lleva encima: va más lento, los monos cercanos van a por él y tiene el PvP
--      activado (otros jugadores con PvP pueden derribarlo y quedarse el huevo).
--   3. Si el portador cae, el huevo se queda en el suelo para que otro lo recoja.
--   4. Al llevarlo al Nido del Basecamp empieza la incubación: llegan oleadas a por él.
--   5. Al eclosionar, cada participante (quien lo llevó o estuvo cerca durante el viaje, y quien esté
--      en el Basecamp al nacer) recibe una mascota persistente (Shared/PetRoll), que le acompaña ya en
--      esta partida salvo que lleve otra más rara.
-- El estado se publica en ReplicatedStorage ("EggStatus") para el HUD.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Compass = require(ReplicatedStorage.Shared.Compass)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local BasecampService = require(script.Parent.BasecampService)
local MonkeyService = require(script.Parent.MonkeyService)
local PvPService = require(script.Parent.PvPService)
local RoleService = require(script.Parent.RoleService)

local TICK_SECONDS = 0.5
local DELIVERY_DISTANCE = 10
-- Forma del huevo: perfil de revolución más ancho abajo que arriba (radio según la altura).
-- Se construye con una fila de esferas a lo largo del eje, cada una la más grande que cabe dentro
-- del perfil: juntas dan un contorno liso, sin las aristas que dejan dos óvalos cruzados.
local EGG_HALF_HEIGHT = 1.65
local EGG_RADIUS = 1.2
local EGG_TAPER = 0.16 -- cuánto más estrecha es la punta de arriba que la base
local EGG_SPHERES = 12
local EGG_SHELL = Color3.fromRGB(240, 230, 200)
local EGG_SPOTS = Color3.fromRGB(80, 170, 170)
local EGG_SPOTS_DARK = Color3.fromRGB(45, 110, 120)
local EGG_GLOW = Color3.fromRGB(150, 240, 255)
local SPOT_COUNT = 16
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

-- Radio del huevo a una altura (0 en el centro, ±EGG_HALF_HEIGHT en las puntas).
local function eggRadius(height: number): number
	local t = height / EGG_HALF_HEIGHT
	if math.abs(t) >= 1 then
		return 0
	end
	return EGG_RADIUS * math.sqrt(1 - t * t) * (1 - EGG_TAPER * t)
end

-- Esferas que rellenan el perfil: X = altura del centro, Y = radio. Se calculan una vez.
local eggSpheres: { Vector2 }? = nil
local function spheresOfEgg(): { Vector2 }
	local cached = eggSpheres
	if cached then
		return cached
	end
	local spheres = {}
	local first = -EGG_HALF_HEIGHT + 0.5
	local step = 2 * (EGG_HALF_HEIGHT - 0.5) / (EGG_SPHERES - 1)
	for i = 0, EGG_SPHERES - 1 do
		local center = first + i * step
		-- La esfera más grande con ese centro que no se sale del perfil.
		local radius = math.huge
		for sample = 0, 400 do
			local height = -EGG_HALF_HEIGHT + sample * 2 * EGG_HALF_HEIGHT / 400
			radius = math.min(radius, Vector2.new(height - center, eggRadius(height)).Magnitude)
		end
		table.insert(spheres, Vector2.new(center, radius))
	end
	eggSpheres = spheres
	return spheres
end

-- Pieza del huevo: esfera (Ball) o, con "oval", un óvalo aplastado (para las motas).
local function shellPart(name: string, size: Vector3, color: Color3, oval: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	if oval then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	else
		part.Shape = Enum.PartType.Ball
	end
	part.Size = size
	return part
end

-- Pega una pieza al huevo (la soldadura va dentro de la pieza, así no se confunde con la que lo
-- une a la cabeza del portador).
local function attach(core: BasePart, model: Model, piece: BasePart, offset: CFrame)
	piece.CFrame = core.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = model
end

local function buildEgg(): BasePart
	local model = Instance.new("Model")
	model.Name = "HuevoMisterioso"
	eggModel = model

	-- La esfera más cercana al centro es la pieza principal; las demás se le sueldan.
	local spheres = spheresOfEgg()
	local coreIndex = 1
	for i, sphere in spheres do
		if math.abs(sphere.X) < math.abs(spheres[coreIndex].X) then
			coreIndex = i
		end
	end
	local core = spheres[coreIndex]
	local main = shellPart("Cascara", Vector3.one * core.Y * 2, EGG_SHELL, false)
	main.Anchored = true
	main.Parent = model
	model.PrimaryPart = main
	for i, sphere in spheres do
		if i ~= coreIndex then
			local shell = shellPart("Cascara", Vector3.one * sphere.Y * 2, EGG_SHELL, false)
			attach(main, model, shell, CFrame.new(0, sphere.X - core.X, 0))
		end
	end

	-- Motas por toda la cáscara (espiral con el ángulo áureo), pegadas a la superficie y con su
	-- inclinación. Algo más grandes hacia la base.
	for i = 1, SPOT_COUNT do
		local height = EGG_HALF_HEIGHT * (0.85 - 1.65 * (i - 0.5) / SPOT_COUNT)
		local angle = i * 2.39996
		local slope = (eggRadius(height + 0.01) - eggRadius(height - 0.01)) / 0.02
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = outward * (eggRadius(height) - 0.02) + Vector3.new(0, height - core.X, 0)
		local normal = (outward - Vector3.new(0, slope, 0)).Unit
		local size = 0.22 + (i % 4) * 0.07 + (1 - height / EGG_HALF_HEIGHT) * 0.06
		local color = if i % 3 == 0 then EGG_SPOTS_DARK else EGG_SPOTS
		local spot = shellPart("Mota", Vector3.new(size * 1.35, size, 0.08), color, true)
		attach(main, model, spot, CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, angle))
	end

	local light = Instance.new("PointLight")
	light.Color = EGG_GLOW
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = main
	-- En el modelo, no en una pieza: así resalta el huevo entero con un solo contorno.
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.88
	highlight.FillColor = EGG_GLOW
	highlight.OutlineColor = Color3.fromRGB(200, 250, 255)
	highlight.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggPrompt"
	prompt.ActionText = "Recoger (activa PvP)"
	prompt.ObjectText = "Huevo misterioso"
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
	announce(`🥚 {player.DisplayName} lleva el huevo. ¡Escoltadlo hasta el nido!`)
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

-- Trozos de cáscara que salen volando al eclosionar.
local function burstShell(position: Vector3)
	for i = 1, 10 do
		local shard = Instance.new("Part")
		shard.Name = "Cascara"
		shard.Size = Vector3.new(0.6, 0.15, 0.5)
		shard.Color = if i % 3 == 0 then EGG_SPOTS else EGG_SHELL
		shard.Material = Enum.Material.SmoothPlastic
		shard.CanCollide = true
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = CFrame.new(position)
			* CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3))
		shard.Parent = Workspace
		local angle = i * math.pi / 5
		shard.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * 12, rng:NextNumber(14, 22), math.sin(angle) * 12)
		Debris:AddItem(shard, 4)
	end
	local flash = Instance.new("Part")
	flash.Name = "Eclosion"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 2
	flash.Color = EGG_GLOW
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CFrame = CFrame.new(position)
	flash.Parent = Workspace
	TweenService:Create(flash, TweenInfo.new(0.6), { Size = Vector3.one * 9, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.7)
end

-- La mascota nueva pasa a acompañar al jugador ya en esta partida, salvo que lleve una más rara.
local function equipHatched(player: Player, petId: string): boolean
	local current = player:GetAttribute("ActivePet")
	local currentPet = if typeof(current) == "string" then Pets[current] else nil
	if currentPet and Rarities[currentPet.rarity].order > Rarities[Pets[petId].rarity].order then
		return false
	end
	player:SetAttribute("ActivePet", petId)
	PlayerData.update(player, function(profile)
		profile.activePet = petId
	end)
	RoleService.refreshPerks(player)
	return true
end

local function hatch()
	local hatchedFor = table.clone(participants)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InBasecamp") == true then
			hatchedFor[player] = true
		end
	end
	local part = egg
	if part then
		burstShell(part.Position)
		Sfx.play("EggHatch", part.Position)
	end
	for player in hatchedFor do
		if player.Parent then
			local petId = PetRoll.roll(rng)
			local pet = Pets[petId]
			PlayerData.update(player, function(profile)
				profile.pets[petId] = (profile.pets[petId] or 0) + 1
			end)
			MatchStats.add(player, MatchStats.EGGS)
			local equipped = equipHatched(player, petId)
			Remotes.Notify:FireClient(
				player,
				`🐣 ¡Ha nacido tu mascota: {pet.icon} {pet.name} ({Rarities[pet.rarity].name})! `
					.. if equipped then "Ya te acompaña" else "Te espera en el Lobby (llevas una más rara)"
			)
		end
	end
	announce("🐣 ¡El huevo ha eclosionado!")
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
	announce(`🥚 ¡El huevo está en el nido! Defendedlo {Config.Egg.IncubationSeconds} s hasta que eclosione`)

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

-- Prueba (panel de Studio): termina ya la incubación del huevo que esté en el nido.
function EggService.hatchNow(): boolean
	if state ~= "Incubating" then
		return false
	end
	incubationEndsAt = os.clock()
	return true
end

function EggService.spawnEgg()
	local center = BasecampService.getCenter()
	for _ = 1, 60 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(Config.Egg.MinDistance, Config.Egg.MaxDistance)
		local ground = groundAt(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
		if ground then
			placeOnGround(ground)
			announce(
				`🥚 ¡Ha aparecido un huevo misterioso hacia {Compass.direction(center, ground)}! Llevadlo al nido`
			)
			return
		end
	end
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
		setStatus(`🥚 {holder.DisplayName} lleva el huevo`)
	elseif state == "Incubating" then
		local target = nest
		if not target or not target.Parent then
			announce("💔 Los monos han destrozado el nido: el huevo se ha perdido")
			clearEgg()
			return
		end
		local remaining = math.ceil(incubationEndsAt - os.clock())
		if remaining <= 0 then
			hatch()
		else
			setStatus(`🥚 Incubando: {remaining} s`)
		end
	else
		setStatus("🥚 Hay un huevo misterioso en la isla")
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
	end
end

return EggService
