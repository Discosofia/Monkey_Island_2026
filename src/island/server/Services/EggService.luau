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
-- Medidas del huevo: un óvalo alto con la base más ancha (dos esferas estiradas) y motas.
local EGG_SIZE = Vector3.new(2, 3, 2)
local EGG_HALF_HEIGHT = 1.5
local EGG_SHELL = Color3.fromRGB(240, 230, 200)
local EGG_SPOTS = Color3.fromRGB(80, 170, 170)
local EGG_GLOW = Color3.fromRGB(150, 240, 255)
local SPOT_COUNT = 9

type EggState = "Ground" | "Carried" | "Incubating"

local EggService = {}

local rng = Random.new()
local egg: BasePart? = nil
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
	if egg then
		egg:Destroy()
	end
	egg = nil
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

local pickUp: (player: Player) -> ()

local function shellPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Pega una pieza decorativa al huevo (la soldadura va dentro de la pieza, así no se confunde con la
-- que lo une a la cabeza del portador).
local function attach(shell: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = shell.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shell
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = shell
end

local function buildEgg(): BasePart
	local main = shellPart("HuevoMisterioso", EGG_SIZE, EGG_SHELL)
	main.Anchored = true
	attach(main, shellPart("Base", Vector3.new(2.3, 2.1, 2.3), EGG_SHELL), CFrame.new(0, -0.42, 0))
	-- Motas repartidas por la mitad de arriba (ángulo áureo), orientadas hacia fuera.
	for i = 1, SPOT_COUNT do
		local angle = i * 2.4
		local height = -0.3 + (i / SPOT_COUNT) * 1.3
		local radius = math.sqrt(1 - (height / EGG_HALF_HEIGHT) ^ 2) * EGG_SIZE.X / 2
		local position = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local normal = Vector3.new(position.X, height * 0.45, position.Z).Unit
		local size = 0.22 + (i % 3) * 0.08
		local spot = shellPart("Mota", Vector3.new(size * 1.3, size, 0.12), EGG_SPOTS)
		attach(main, spot, CFrame.lookAt(position, position + normal))
	end
	local light = Instance.new("PointLight")
	light.Color = EGG_GLOW
	light.Range = 14
	light.Brightness = 2
	light.Parent = main
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.75
	highlight.FillColor = EGG_GLOW
	highlight.OutlineColor = Color3.fromRGB(200, 250, 255)
	highlight.Parent = main
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

-- Pone el huevo en el suelo con su aviso "Recoger".
local function placeOnGround(position: Vector3)
	local part = egg
	if not part then
		part = buildEgg()
		egg = part
	end
	local eggPart = part :: BasePart
	unweld(eggPart)
	eggPart.Anchored = true
	eggPart.CFrame = CFrame.new(position + Vector3.new(0, EGG_HALF_HEIGHT - 0.1, 0))
	eggPart.Parent = Workspace
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
	part.Anchored = false
	part.CFrame = head.CFrame * CFrame.new(0, 0.5 + EGG_HALF_HEIGHT + 0.2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
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
	local position = part.Position - Vector3.new(0, 5, 0)
	local ground = groundAt(position) or position
	placeOnGround(ground)
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
	-- Lo deja en el centro del nido, apoyado (un poco hundido) en la paja.
	unweld(part)
	setPrompt(part, false)
	local bounds, size = target:GetBoundingBox()
	local strawTop = bounds.Position.Y - size.Y / 2 + 0.6
	part.Anchored = true
	part.CFrame = CFrame.new(bounds.Position.X, strawTop + EGG_HALF_HEIGHT - 0.35, bounds.Position.Z)
		* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	part.Parent = Workspace
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
