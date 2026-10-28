--!strict
-- Nido de huevos del Lobby (bucle de retención, octubre de 2026), en cada cliente:
--   - Dibuja sobre el nido de la plaza (etiqueta Config.Lobby.NestTag, punto "EggSeat") el huevo que
--     el jugador tiene incubando, con el color de su rareza. Cada jugador ve el suyo: los demás no lo
--     ven. Con la incubadora III de la parcela (Fase 12) son dos, uno al lado del otro. Lo que les falta
--     lo enseña el cartel de las mascotas de detrás (PetBoardController).
--   - Listo para abrir, el huevo se tambalea y brilla más, y el aviso del nido dice "Abrir el huevo".
--   - Al nacer la mascota (Remotes.EggHatched) hace la ceremonia: el huevo tiembla cada vez más
--     fuerte, estalla y sale la mascota girando con su nombre y su rareza. Si ha salido una montura
--     (Fase 11), sale ella, a escala de nido, y el letrero dice cómo montarla.
--   - Alrededor del nido, la decoración que lleva el jugador (cosmético NestDecor, atributo
--     "NestDecor"; Shared/NestDecor), apoyada en el suelo. También la ve solo él.
-- Lo que se decide (poner, descartar, abrir) está en la ventana del nido (LobbyUIController).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local EggModel = require(ReplicatedStorage.Shared.EggModel)
local MountModels = require(ReplicatedStorage.Shared.MountModels)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local NestDecor = require(ReplicatedStorage.Shared.NestDecor)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t
local later = Strings.later

-- El huevo del Lobby, más grande que el de la Isla: el nido también lo es.
local EGG_SCALE = 1.5
local EGG_SINK = 0.5
-- Con dos huevos, cada uno se aparta esto del centro del nido.
local PAIR_OFFSET = 1.3
local CEREMONY_SHAKE_SECONDS = 1.6
local REVEAL_SECONDS = 4

local NestController = {}

local player = Players.LocalPlayer
-- Huevos dibujados ahora (por hueco del nido) y de qué rareza (para no rehacerlos cada segundo).
local eggModels: { [number]: Model } = {}
local eggRarities: { [number]: string } = {}
local ceremony = false
-- La decoración dibujada ahora y cuál es.
local decorModel: Model? = nil
local decorId: string? = nil
-- Huevos del jugador (atributo "Eggs"), leídos al cambiar.
local eggs: EggIncubation.EggData = EggIncubation.normalize(nil)

local function readEggs(): EggIncubation.EggData
	local raw = player:GetAttribute("Eggs")
	if typeof(raw) ~= "string" then
		return EggIncubation.normalize(nil)
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return EggIncubation.normalize(if ok then decoded else nil)
end

local function findNest(): (Model?, BasePart?)
	for _, tagged in CollectionService:GetTagged(Config.Lobby.NestTag) do
		if tagged:IsA("Model") and tagged:IsDescendantOf(Workspace) then
			local seat = tagged:FindFirstChild("EggSeat", true)
			if seat and seat:IsA("BasePart") then
				return tagged, seat
			end
		end
	end
	return nil, nil
end

-- Sitio del huevo del hueco "slot": en el centro si está solo, a un lado si hay dos.
local function eggRest(seat: BasePart, slot: number, pair: boolean): CFrame
	local side = if pair then (if slot == 1 then -PAIR_OFFSET else PAIR_OFFSET) else 0
	return CFrame.new(seat.Position + Vector3.new(side, EggModel.HALF_HEIGHT * EGG_SCALE - EGG_SINK, 0))
end

local function isPair(): boolean
	return eggs.nest ~= nil and eggs.nest2 ~= nil
end

-- "text": frase de Shared/Strings (se pone ya traducida; UI/Localizer la rehace si cambia el idioma).
local function setPrompt(nest: Model, text: string)
	local prompt = nest:FindFirstChild("NidoPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = T(text)
	end
end

local function clearEgg(slot: number)
	local model = eggModels[slot]
	if model then
		model:Destroy()
	end
	eggModels[slot] = nil
	eggRarities[slot] = nil
end

local function placeEgg(seat: BasePart, slot: number, rarity: string)
	if eggModels[slot] and eggRarities[slot] == rarity then
		return
	end
	clearEgg(slot)
	local model, main = EggModel.build(rarity, "HuevoDelNido")
	model:ScaleTo(EGG_SCALE)
	model:PivotTo(eggRest(seat, slot, isPair()))
	main.Anchored = true
	model.Parent = Workspace
	eggModels[slot] = model
	eggRarities[slot] = rarity
end

-- Pone (o cambia, o quita) la decoración del nido si ha cambiado la que lleva.
local function placeDecor(nest: Model)
	local wanted = player:GetAttribute("NestDecor")
	local cosmeticId = if typeof(wanted) == "string" and NestDecor.has(wanted) then wanted else nil
	if cosmeticId == decorId and (decorModel == nil or decorModel.Parent ~= nil) then
		return
	end
	if decorModel then
		decorModel:Destroy()
	end
	decorModel, decorId = nil, cosmeticId
	local inner = nest:FindFirstChild("Nido")
	local bounds = if inner then inner:FindFirstChild("Bounds") else nil
	if not (cosmeticId and inner and bounds and bounds:IsA("BasePart")) then
		return
	end
	local decor = NestDecor.build(cosmeticId, bounds.Size.X / 2) :: Model
	decor.Name = "DecoracionDelNido"
	-- El frente de la decoración (-Z) va hacia la llegada, al otro lado del cartel.
	decor:PivotTo(CFrame.new(bounds.Position - Vector3.new(0, bounds.Size.Y / 2, 0)) * CFrame.Angles(0, math.pi, 0))
	decor.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { decor, inner }
	NestDecor.settle(decor, function(point)
		local hit = Workspace:Raycast(point + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), params)
		return if hit then hit.Position.Y else nil
	end)
	decorModel = decor
end

-- Cada fotograma: la decoración, el aviso y el tambaleo del huevo.
local function refresh(time: number)
	local nest, seat = findNest()
	if nest then
		placeDecor(nest)
	end
	if not (nest and seat) or ceremony then
		return
	end
	local anyReady = false
	for slot = 1, #EggIncubation.NEST_KEYS do
		local nestEgg = EggIncubation.inSlot(eggs, slot)
		if not nestEgg then
			clearEgg(slot)
			continue
		end
		placeEgg(seat, slot, nestEgg.rarity)
		local ready = EggIncubation.isReady(nestEgg, EggIncubation.now())
		anyReady = anyReady or ready
		local model = eggModels[slot]
		if model then
			-- Listo: se tambalea como si fuera a romperse. Incubando: casi quieto.
			local wobble = if ready then math.sin(time * 9 + slot) * 0.12 else math.sin(time * 1.5 + slot) * 0.025
			model:PivotTo(eggRest(seat, slot, isPair()) * CFrame.Angles(wobble, 0, wobble * 0.6))
		end
	end
	setPrompt(nest, if anyReady then later("Abrir el huevo") else later("Ver el nido"))
end

-- Escala de la montura al salir del nido (de tamaño real no cabría: la llama mide 7,5 studs).
local MOUNT_REVEAL_SCALE = 0.45

-- Letrero grande en pantalla con la mascota (o la montura) que ha nacido. "amber" > 0: ya la tenía y
-- se cambia por Ámbar.
local function announce(petId: string, equipped: boolean, isMount: boolean, amber: number)
	local pet: { name: string, icon: string, rarity: string } = if isMount then Mounts[petId] else Pets[petId]
	local rarity = Rarities[pet.rarity]
	local gui = Widgets.screen("EggHatchedUI", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 9
	local args = { icon = pet.icon, name = { pet.name }, rarity = { rarity.name }, amber = amber }
	local label = Widgets.label(
		if amber > 0 then T("🐣 ¡Otra vez {icon} {name}!", args) else T("🐣 ¡Ha nacido {icon} {name}!", args),
		gui
	)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.6, 0.09)
	local detail = Widgets.label(
		if amber > 0
			then T("{rarity} · Ya la tenías: +{amber} ✨ Ámbar", args)
			elseif isMount and equipped then T(
				"{rarity} · ¡Una montura! Móntala con N (o el botón Montar)",
				args
			)
			elseif isMount then T("{rarity} · ¡Una montura! Llévala desde la ventana de Mascotas", args)
			elseif equipped then T("{rarity} · ya te acompaña", args)
			else T("{rarity} · en tu colección (llevas una más rara)", args),
		gui
	)
	detail.AnchorPoint = Vector2.new(0.5, 0)
	detail.Position = UDim2.fromScale(0.5, 0.35)
	detail.Size = UDim2.fromScale(0.5, 0.05)
	detail.TextColor3 = rarity.color
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(REVEAL_SECONDS, function()
		gui:Destroy()
	end)
end

local function playCeremony(
	petId: string,
	rarity: string,
	equipped: boolean,
	isMount: boolean,
	amber: number,
	slot: number
)
	local _, seat = findNest()
	if not seat then
		announce(petId, equipped, isMount, amber)
		return
	end
	ceremony = true
	-- El otro huevo (si lo hay) sigue donde estaba; el que nace, en su sitio de antes de abrirse.
	local pair = eggModels[1] ~= nil and eggModels[2] ~= nil
	placeEgg(seat, slot, rarity)
	local rest = eggRest(seat, slot, pair)
	local model = eggModels[slot]
	-- El huevo tiembla cada vez más fuerte y estalla.
	local started = os.clock()
	while model and os.clock() - started < CEREMONY_SHAKE_SECONDS do
		local t = (os.clock() - started) / CEREMONY_SHAKE_SECONDS
		local shake = 0.05 + t * 0.3
		model:PivotTo(
			rest
				* CFrame.new(math.sin(os.clock() * 50) * shake * 0.3, 0, 0)
				* CFrame.Angles(math.sin(os.clock() * 37) * shake, 0, math.cos(os.clock() * 41) * shake)
		)
		RunService.RenderStepped:Wait()
	end
	local burstAt = rest.Position
	clearEgg(slot)
	EggModel.burst(burstAt, rarity)
	announce(petId, equipped, isMount, amber)
	-- La mascota (o la montura, más pequeña) sube del nido girando y se va.
	local pet = if isMount then MountModels.build(petId) else PetModels.build(petId)
	if pet then
		if isMount then
			pet:ScaleTo(MOUNT_REVEAL_SCALE)
		end
		local height = pet:GetAttribute("Height")
		local lift = if typeof(height) == "number" then height else 1.5
		if isMount then
			-- El pivote de la montura está en el suelo, no en el centro.
			lift = 0
		end
		pet.Parent = Workspace
		local revealStart = os.clock()
		while os.clock() - revealStart < REVEAL_SECONDS do
			local t = os.clock() - revealStart
			local rise = math.min(t / 0.6, 1)
			pet:PivotTo(
				CFrame.new(
					Vector3.new(rest.X, seat.Position.Y, rest.Z) + Vector3.new(0, 0.6 + lift * 0.5 + rise * 2.2, 0)
				) * CFrame.Angles(0, t * 1.8, 0)
			)
			RunService.RenderStepped:Wait()
		end
		pet:Destroy()
	end
	ceremony = false
end

function NestController:Start()
	Remotes.EggHatched.OnClientEvent:Connect(
		function(petId: any, rarity: any, equipped: any, isMount: any, amber: any, slot: any)
			local known = if isMount == true then Mounts[petId] ~= nil else Pets[petId] ~= nil
			if typeof(petId) == "string" and known and typeof(rarity) == "string" and Rarities[rarity] then
				task.spawn(
					playCeremony,
					petId,
					rarity,
					equipped == true,
					isMount == true,
					if typeof(amber) == "number" then amber else 0,
					if slot == 2 then 2 else 1
				)
			end
		end
	)
	eggs = readEggs()
	player:GetAttributeChangedSignal("Eggs"):Connect(function()
		eggs = readEggs()
	end)
	-- El nido se busca en cada paso: con la carga por zonas puede no estar aún en Workspace.
	RunService.Heartbeat:Connect(function()
		refresh(os.clock())
	end)
end

return NestController
