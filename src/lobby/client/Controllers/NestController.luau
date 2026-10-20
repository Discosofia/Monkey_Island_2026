--!strict
-- Nido de huevos del Lobby (bucle de retención, octubre de 2026), en cada cliente:
--   - Dibuja sobre el nido de la playa (etiqueta Config.Lobby.NestTag, punto "EggSeat") el huevo que
--     el jugador tiene incubando, con el color de su rareza, y encima un cartel con lo que le falta.
--     Cada jugador ve el suyo: los demás no lo ven.
--   - Listo para abrir, el huevo se tambalea y brilla más, y el aviso del nido dice "Abrir el huevo".
--   - Al nacer la mascota (Remotes.EggHatched) hace la ceremonia: el huevo tiembla cada vez más
--     fuerte, estalla y sale la mascota girando con su nombre y su rareza.
-- Lo que se decide (poner, descartar, abrir) está en la pestaña Mascotas (LobbyUIController).

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
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

-- El huevo del Lobby, más grande que el de la Isla: el nido también lo es.
local EGG_SCALE = 1.5
local EGG_SINK = 0.5
local CEREMONY_SHAKE_SECONDS = 1.6
local REVEAL_SECONDS = 4
local SUBTEXT_COLOR = Color3.fromRGB(230, 220, 200)
local READY_COLOR = Color3.fromRGB(242, 178, 36)

local NestController = {}

local player = Players.LocalPlayer
-- Huevo dibujado ahora y de qué rareza (para no rehacerlo cada segundo).
local eggModel: Model? = nil
local eggRarity: string? = nil
local ceremony = false
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

local function eggRest(seat: BasePart): CFrame
	return CFrame.new(seat.Position + Vector3.new(0, EggModel.HALF_HEIGHT * EGG_SCALE - EGG_SINK, 0))
end

-- Cartel sobre el nido: título (rareza o "Nido vacío") y lo que falta. Se crea una vez.
type Sign = { gui: BillboardGui, title: TextLabel, detail: TextLabel }
local sign: Sign? = nil

local function getSign(seat: BasePart): Sign
	local current = sign
	if current and current.gui.Parent then
		return current
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NestSign"
	gui.Adornee = seat
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, EggModel.HALF_HEIGHT * 2 * EGG_SCALE + 1.6, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = player:WaitForChild("PlayerGui")
	local title = Widgets.label("", gui)
	title.Size = UDim2.fromScale(1, 0.5)
	local detail = Widgets.label("", gui)
	detail.Position = UDim2.fromScale(0, 0.5)
	detail.Size = UDim2.fromScale(1, 0.42)
	detail.TextColor3 = SUBTEXT_COLOR
	local created: Sign = { gui = gui, title = title, detail = detail }
	sign = created
	return created
end

local function setPrompt(nest: Model, text: string)
	local prompt = nest:FindFirstChild("NidoPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = text
	end
end

local function clearEgg()
	if eggModel then
		eggModel:Destroy()
	end
	eggModel = nil
	eggRarity = nil
end

local function placeEgg(seat: BasePart, rarity: string)
	if eggModel and eggRarity == rarity then
		return
	end
	clearEgg()
	local model, main = EggModel.build(rarity, "HuevoDelNido")
	model:ScaleTo(EGG_SCALE)
	model:PivotTo(eggRest(seat))
	main.Anchored = true
	model.Parent = Workspace
	eggModel = model
	eggRarity = rarity
end

-- Cada fotograma: el cartel, el aviso y el tambaleo del huevo.
local function refresh(time: number)
	local nest, seat = findNest()
	if not (nest and seat) or ceremony then
		return
	end
	local data = eggs
	local nestEgg = data.nest
	local board = getSign(seat)
	if not nestEgg then
		clearEgg()
		board.title.Text = "🥚 Nido vacío"
		board.title.TextColor3 = Color3.new(1, 1, 1)
		local stored = #data.bag + #data.pending
		board.detail.Text = if stored > 0
			then `Tienes {stored} huevo{if stored == 1 then "" else "s"}: ponlo a incubar`
			else "Consigue huevos en la Isla"
		setPrompt(nest, "Ver el nido")
		return
	end
	placeEgg(seat, nestEgg.rarity)
	local rarity = Rarities[nestEgg.rarity]
	local now = EggIncubation.now()
	local ready = EggIncubation.isReady(nestEgg, now)
	board.title.Text = `🥚 Huevo {rarity.name}`
	board.title.TextColor3 = rarity.color
	if ready then
		board.detail.Text = "🐣 ¡Listo para abrir!"
		board.detail.TextColor3 = READY_COLOR
		setPrompt(nest, "Abrir el huevo")
	else
		board.detail.Text = `⏳ {EggIncubation.formatTime(EggIncubation.remaining(nestEgg, now))}`
		board.detail.TextColor3 = SUBTEXT_COLOR
		setPrompt(nest, "Ver el nido")
	end
	local model = eggModel
	if model then
		-- Listo: se tambalea como si fuera a romperse. Incubando: casi quieto.
		local wobble = if ready then math.sin(time * 9) * 0.12 else math.sin(time * 1.5) * 0.025
		model:PivotTo(eggRest(seat) * CFrame.Angles(wobble, 0, wobble * 0.6))
	end
end

-- Letrero grande en pantalla con la mascota que ha nacido.
local function announce(petId: string, equipped: boolean)
	local pet = Pets[petId]
	local rarity = Rarities[pet.rarity]
	local gui = Widgets.screen("EggHatchedUI", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 9
	local label = Widgets.label(`🐣 ¡Ha nacido {pet.icon} {pet.name}!`, gui)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.6, 0.09)
	local detail = Widgets.label(
		`{rarity.name} · {if equipped then "ya te acompaña" else "en tu colección (llevas una más rara)"}`,
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

local function playCeremony(petId: string, rarity: string, equipped: boolean)
	local _, seat = findNest()
	if not seat then
		announce(petId, equipped)
		return
	end
	ceremony = true
	-- El cartel se esconde mientras dura: al acabar ya dirá cómo queda el nido.
	local board = getSign(seat)
	board.gui.Enabled = false
	placeEgg(seat, rarity)
	local model = eggModel
	-- El huevo tiembla cada vez más fuerte y estalla.
	local started = os.clock()
	while model and os.clock() - started < CEREMONY_SHAKE_SECONDS do
		local t = (os.clock() - started) / CEREMONY_SHAKE_SECONDS
		local shake = 0.05 + t * 0.3
		model:PivotTo(
			eggRest(seat)
				* CFrame.new(math.sin(os.clock() * 50) * shake * 0.3, 0, 0)
				* CFrame.Angles(math.sin(os.clock() * 37) * shake, 0, math.cos(os.clock() * 41) * shake)
		)
		RunService.RenderStepped:Wait()
	end
	local burstAt = eggRest(seat).Position
	clearEgg()
	EggModel.burst(burstAt, rarity)
	announce(petId, equipped)
	-- La mascota sube del nido girando y se va.
	local pet = PetModels.build(petId)
	if pet then
		local height = pet:GetAttribute("Height")
		local lift = if typeof(height) == "number" then height else 1.5
		pet.Parent = Workspace
		local revealStart = os.clock()
		while os.clock() - revealStart < REVEAL_SECONDS do
			local t = os.clock() - revealStart
			local rise = math.min(t / 0.6, 1)
			pet:PivotTo(
				CFrame.new(seat.Position + Vector3.new(0, 0.6 + lift * 0.5 + rise * 2.2, 0))
					* CFrame.Angles(0, t * 1.8, 0)
			)
			RunService.RenderStepped:Wait()
		end
		pet:Destroy()
	end
	board.gui.Enabled = true
	ceremony = false
end

function NestController:Start()
	Remotes.EggHatched.OnClientEvent:Connect(function(petId: any, rarity: any, equipped: any)
		if typeof(petId) == "string" and Pets[petId] and typeof(rarity) == "string" and Rarities[rarity] then
			task.spawn(playCeremony, petId, rarity, equipped == true)
		end
	end)
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
