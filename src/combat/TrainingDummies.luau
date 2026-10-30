--!strict
-- Muñecos de práctica para probar las armas y las habilidades: en el Basecamp de la Isla
-- (TrainingDummyService) y en la plaza del Lobby (LobbyDummyService). Tienen la etiqueta de enemigo,
-- así que las armas y las habilidades les hacen daño, les ponen estados y sirven para enlazar
-- combos. Al romperse hacen "¡puf!" y reaparecen en el mismo sitio.
-- Fase 10, C6: el de sparring (placeSparring) además devuelve los golpes con un palo, avisando como un
-- mono (Combat/EnemyAttack), para practicar el bloqueo y el parry. No hace daño: gasta guardia, la
-- rompe y, si le paras, se queda tambaleado (Config.Combat.Sparring*).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local EnemyAttack = require(script.Parent.EnemyAttack)
local Guard = require(script.Parent.Guard)
local Poof = require(script.Parent.Poof)
local Status = require(script.Parent.Status)

-- El palo del sparring respecto a su raíz: en reposo, alzado a la derecha; al golpear, bajado delante.
-- (más a la derecha que el brazo derecho del muñeco, que está en x = 1,9, para que no lo tape).
local CLUB_REST = CFrame.new(3.1, 1.2, -0.4) * CFrame.Angles(math.rad(70), 0, math.rad(-20))
local CLUB_HIT = CFrame.new(0.6, 0, -1.8) * CFrame.Angles(math.rad(-10), 0, math.rad(-10))

local TrainingDummies = {}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = parent
	return part
end

-- El suelo bajo "position" (o "position" si no hay nada debajo). Se saltan las piezas invisibles (las
-- barreras del borde de un mapa): si no, el muñeco se queda encima de ellas, en el aire.
local INVISIBLE = 0.95
local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skipped: { Instance } = {}
	for _ = 1, 4 do
		params.FilterDescendantsInstances = skipped
		local result = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
		if not result then
			return position
		end
		if result.Instance.Transparency < INVISIBLE then
			return result.Position
		end
		table.insert(skipped, result.Instance)
	end
	return position
end

-- Destello rojo del golpe que entra (no quita vida).
local function flash(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Parent = character
	Debris:AddItem(highlight, 0.15)
end

-- Jugador vivo más cercano a "root" dentro de Config.Combat.SparringRange (en horizontal).
local function nearestPlayer(root: BasePart): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, Config.Combat.SparringRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local other = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if other and other:IsA("BasePart") and LifeState.isAlive(player) then
			local offset = (other.Position - root.Position) * Vector3.new(1, 0, 1)
			if offset.Magnitude <= bestDistance then
				best, bestRoot, bestDistance = player, other, offset.Magnitude
			end
		end
	end
	return best, bestRoot
end

-- Un golpe del sparring a "player": se gira, avisa y baja el palo. Si entra, destello rojo y "¡ay!".
local function spar(model: Model, root: BasePart, club: BasePart, player: Player, target: BasePart)
	local settings = Config.Combat
	EnemyAttack.face(model, target.Position)
	EnemyAttack.windup(model, settings.SparringWindupSeconds, "Strike", function()
		local rest = root.CFrame * CLUB_REST
		local swing = TweenService:Create(club, TweenInfo.new(0.1), { CFrame = root.CFrame * CLUB_HIT })
		swing.Completed:Once(function()
			TweenService:Create(club, TweenInfo.new(0.3), { CFrame = rest }):Play()
		end)
		swing:Play()
		Sfx.play("SwingHeavy", root)
		EnemyAttack.strike(model, player, settings.SparringRange, function(hit)
			hit.guardDamage = settings.SparringGuardDamage
			local character = player.Character
			if Guard.resolve(player, hit) == "Hit" and character then
				flash(character)
				Sfx.play("PlayerHurt", character.PrimaryPart or character)
			end
		end)
	end)
end

-- Mientras exista: cada Config.Combat.SparringAttackSeconds pega a quien tenga cerca (si no está
-- aturdido ni roto).
local function sparLoop(model: Model, humanoid: Humanoid, root: BasePart, club: BasePart)
	while model.Parent and humanoid.Health > 0 do
		task.wait(Config.Combat.SparringAttackSeconds)
		if model.Parent and humanoid.Health > 0 and not Status.isStunned(model) and not EnemyAttack.busy(model) then
			local player, target = nearestPlayer(root)
			if player and target then
				spar(model, root, club, player, target)
			end
		end
	end
end

local function spawnDummy(folder: Instance, ground: Vector3, lookAt: Vector3, sparring: boolean?)
	local model = Instance.new("Model")
	model.Name = if sparring then "Muñeco de sparring" else "Muñeco de práctica"
	-- Su daño no cuenta para las misiones del día (MissionService).
	model:SetAttribute("TrainingDummy", true)
	-- El de sparring lo busca la guía del Lobby (LobbyGuideController) para llevarte hasta él.
	if sparring then
		model:SetAttribute("Sparring", true)
	end
	local facing = CFrame.lookAt(ground, Vector3.new(lookAt.X, ground.Y, lookAt.Z))

	newPart("Post", Vector3.new(0.6, 3, 0.6), facing * CFrame.new(0, 1.5, 0), Color3.fromRGB(110, 72, 40), model)
	newPart("Torso", Vector3.new(2, 2, 1), facing * CFrame.new(0, 4, 0), Color3.fromRGB(190, 160, 110), model)
	local head =
		newPart("Head", Vector3.one * 1.6, facing * CFrame.new(0, 5.8, 0), Color3.fromRGB(205, 175, 125), model)
	head.Shape = Enum.PartType.Ball
	-- Brazos a los lados del torso: por su nombre cuentan como zona "Limb" (Hitbox.zoneOf), la cabeza como
	-- "Head" y el torso y el poste como "Torso", para probar las zonas de los proyectiles. Van separados del
	-- torso (más que el radio del proyectil, Config.Projectiles.WeaponRadius): si no, de frente se toca antes el torso.
	for _, side in { -1, 1 } do
		newPart(
			if side == 1 then "RightUpperArm" else "LeftUpperArm",
			Vector3.new(0.8, 1.6, 0.8),
			facing * CFrame.new(side * 1.9, 4.3, 0),
			Color3.fromRGB(210, 182, 132),
			model
		)
	end
	local root = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), facing * CFrame.new(0, 4, 0), Color3.new(), model)
	root.Transparency = 1
	model.PrimaryPart = root
	local club: Part? = nil
	if sparring then
		-- Ojos (brillan al avisar, EnemyWindupController), cinta azul en la frente y un palo en la mano.
		for _, side in { -1, 1 } do
			newPart(
				"Eye",
				Vector3.one * 0.28,
				facing * CFrame.new(side * 0.32, 5.95, -0.72),
				Color3.fromRGB(30, 25, 20),
				model
			)
		end
		newPart("Band", Vector3.new(1.7, 0.3, 1.7), facing * CFrame.new(0, 6.35, 0), Color3.fromRGB(40, 80, 170), model)
		club = newPart("Club", Vector3.new(0.45, 0.45, 3.4), root.CFrame * CLUB_REST, Color3.fromRGB(95, 60, 35), model)
		club.CanCollide = false
	end

	local humanoid = Instance.new("Humanoid")
	-- En español: UI/Localizer lo traduce en cada cliente.
	humanoid.DisplayName = if sparring
		then Strings.later("Muñeco de sparring")
		else Strings.later("Muñeco de práctica")
	humanoid.MaxHealth = Config.Combat.DummyHealth
	humanoid.Health = Config.Combat.DummyHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	CollectionService:AddTag(model, Config.Combat.EnemyTag)
	model.Parent = folder

	local respawning = false
	humanoid.HealthChanged:Connect(function(health)
		if health > 0 or respawning then
			return
		end
		respawning = true
		Poof.vanish(model)
		task.delay(Config.Combat.DummyRespawnSeconds, function()
			spawnDummy(folder, ground, lookAt, sparring)
		end)
	end)
	if club then
		task.spawn(sparLoop, model, humanoid, root, club)
	end
end

-- Pone un muñeco en el suelo bajo cada punto de "spots", mirando hacia "lookAt", dentro de una
-- carpeta nueva "MuñecosDePractica" del Workspace.
function TrainingDummies.place(spots: { Vector3 }, lookAt: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "MuñecosDePractica"
	folder.Parent = Workspace
	for _, spot in spots do
		spawnDummy(folder, groundAt(spot), lookAt)
	end
end

-- Pone el muñeco de sparring (el que devuelve los golpes) en el suelo bajo "spot", mirando hacia
-- "lookAt", en la carpeta de los muñecos de práctica.
function TrainingDummies.placeSparring(spot: Vector3, lookAt: Vector3)
	local folder = Workspace:FindFirstChild("MuñecosDePractica")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MuñecosDePractica"
		folder.Parent = Workspace
	end
	spawnDummy(folder :: Instance, groundAt(spot), lookAt, true)
end

return TrainingDummies
