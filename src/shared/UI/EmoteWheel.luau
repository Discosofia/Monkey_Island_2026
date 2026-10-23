--!strict
-- Rueda de emotes (Fase 9, G9c), en el Lobby y en la Isla: los 6 huecos de la rueda (Shared/CosmeticSlots;
-- vacía, los de serie de Config.Cosmetics.DefaultEmotes) en círculo alrededor del personaje. Está abierta
-- mientras se mantiene pulsada la tecla "." (la de los emotes de Roblox, cuyo menú se apaga para no abrir
-- los dos): al soltarla se hace el emote que está bajo el ratón, si hay uno. El botón 😀 la abre y la
-- cierra (EmoteWheel.button: junto al ⚙️ en la Isla y en la barra del menú del Lobby; en táctil no hay tecla).
--   - Elegir uno lo hace en tu personaje (lo ven todos: la animación del jugador se replica sola) y
--     cierra la rueda. Se para al moverte, saltar, sacar un arma o recibir daño.
--   - Solo fuera de combate: sin perder vida en Config.Cosmetics.EmoteCombatSeconds, sin estar caído
--     (Shared/LifeState) y con un avatar R15 (las animaciones de los emotes son de R15).
-- Los emotes se ponen en la rueda desde el Armario del Lobby (UI/WardrobePanel). Su animación sale de
-- Shared/EmoteTracks y los de la temporada llevan efectos (UI/EmoteFx, que arranca con la rueda).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticSlots = require(ReplicatedStorage.Shared.CosmeticSlots)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local EmoteFx = require(ReplicatedStorage.Shared.UI.EmoteFx)
local EmoteTracks = require(ReplicatedStorage.Shared.EmoteTracks)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local SQUARE_COLOR = Color3.fromRGB(40, 34, 28)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)
local EMPTY_TEXT = Color3.fromRGB(150, 140, 130)
-- Rueda: distancia del centro a cada hueco y lado de cada hueco (cabe en un teléfono de 390 de alto).
local RADIUS = 118
local SLOT_SIZE = 76
local CLOSE_SIZE = 52
-- Fundido al empezar y al parar el emote.
local FADE_SECONDS = 0.2
-- Por debajo de esto, el personaje no se está moviendo.
local MOVE_THRESHOLD = 0.1

local EmoteWheel = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local wheel: Frame? = nil
local lastHurt = -math.huge
local current: AnimationTrack? = nil
local started = false
-- El emote bajo el ratón (el que se hace al soltar la tecla).
local hovered: string? = nil

local function corner(parent: Instance, radius: UDim)
	local item = Instance.new("UICorner")
	item.CornerRadius = radius
	item.Parent = parent
end

local function textCap(object: GuiObject, max: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.Parent = object
end

local function stopEmote()
	if current then
		current:Stop(FADE_SECONDS)
		current = nil
	end
end

-- Por qué no se puede hacer un emote ahora (nil si se puede).
local function blockedReason(humanoid: Humanoid?): string?
	if not humanoid or humanoid.Health <= 0 or not LifeState.isAlive(player) then
		return "Ahora no puedes hacer emotes"
	elseif humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return "Los emotes son para avatares R15"
	elseif player:GetAttribute("Mounted") ~= nil then
		-- Montado (Fase 11) el gesto es de la montura (UI/MountRiders).
		return "🦙 Montado no: pulsa Y (o Escupir) para que tu montura escupa"
	elseif os.clock() - lastHurt < Config.Cosmetics.EmoteCombatSeconds then
		return "⚔️ En combate no: espera unos segundos"
	end
	return nil
end

-- Hace el emote "cosmeticId" en tu personaje (si lo tienes y estás fuera de combate).
function EmoteWheel.play(cosmeticId: string)
	local cosmetic = Cosmetics[cosmeticId]
	if not (cosmetic and cosmetic.kind == "Emote") then
		return
	end
	if player:GetAttribute(`Cosmetic_{cosmeticId}`) ~= true then
		return
	end
	local animationId = EmoteTracks.id(cosmeticId)
	if not animationId then
		Toast.show("Este emote aún no está listo")
		return
	end
	local character = player.Character
	local found = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local reason = blockedReason(found)
	if reason then
		Toast.show(reason)
		return
	end
	local humanoid = found :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	stopEmote()
	-- Con un arma en la mano, su pose taparía el emote.
	humanoid:UnequipTools()
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track:Play(FADE_SECONDS)
	current = track
	local health = humanoid.Health
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if current ~= track or not track.IsPlaying then
			connection:Disconnect()
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > MOVE_THRESHOLD or humanoid.Jump
		local armed = (character :: Model):FindFirstChildOfClass("Tool") ~= nil
		if moving or armed or humanoid.Health < health or humanoid.Parent == nil then
			connection:Disconnect()
			stopEmote()
		end
	end)
end

function EmoteWheel.close()
	hovered = nil
	if gui then
		gui.Enabled = false
	end
end

local function slotButton(parent: Instance, index: number, cosmeticId: string?)
	local angle = -math.pi / 2 + (index - 1) * (2 * math.pi / Config.Cosmetics.EmoteSlots)
	local cosmetic = if cosmeticId then Cosmetics[cosmeticId] else nil
	local owned = cosmeticId ~= nil and player:GetAttribute(`Cosmetic_{cosmeticId}`) == true
	local slot = Instance.new("TextButton")
	slot.Name = `Slot{index}`
	slot.Text = ""
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS)
	slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	slot.BackgroundColor3 = SQUARE_COLOR
	slot.BackgroundTransparency = 0.1
	slot.AutoButtonColor = owned
	slot.Parent = parent
	corner(slot, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = if owned and cosmetic then cosmetic.color else EMPTY_TEXT
	stroke.Thickness = 2
	stroke.Transparency = if owned then 0 else 0.5
	stroke.Parent = slot
	local icon = Widgets.label(if owned and cosmetic then cosmetic.icon else "·", slot)
	icon.Position = UDim2.fromScale(0.2, 0.1)
	icon.Size = UDim2.fromScale(0.6, 0.5)
	local name =
		Widgets.label(if owned and cosmetic then (string.gsub(cosmetic.name, "^[^:]+: ", "")) else "Vacío", slot)
	name.Position = UDim2.fromScale(0.1, 0.6)
	name.Size = UDim2.fromScale(0.8, 0.24)
	name.TextColor3 = if owned then Color3.new(1, 1, 1) else EMPTY_TEXT
	textCap(name, 14)
	if owned and cosmeticId then
		slot.MouseEnter:Connect(function()
			hovered = cosmeticId
			stroke.Color = READY_COLOR
			stroke.Thickness = 3
		end)
		slot.MouseLeave:Connect(function()
			if hovered == cosmeticId then
				hovered = nil
			end
			stroke.Color = (cosmetic :: Cosmetics.Cosmetic).color
			stroke.Thickness = 2
		end)
		slot.Activated:Connect(function()
			EmoteWheel.close()
			EmoteWheel.play(cosmeticId)
		end)
	end
end

-- Vuelve a dibujar los huecos con lo que hay puesto ahora.
local function refresh()
	if not wheel then
		return
	end
	for _, child in wheel:GetChildren() do
		if string.sub(child.Name, 1, 4) == "Slot" then
			child:Destroy()
		end
	end
	hovered = nil
	local slots = CosmeticSlots.wheel(Progression.read(player).cosmetics)
	for index = 1, Config.Cosmetics.EmoteSlots do
		slotButton(wheel, index, slots[index])
	end
end

function EmoteWheel.open()
	if not gui then
		return
	end
	refresh()
	gui.Enabled = true
end

function EmoteWheel.toggle()
	if gui and gui.Enabled then
		EmoteWheel.close()
	else
		EmoteWheel.open()
	end
end

-- Botón cuadrado 😀 que abre y cierra la rueda, del estilo del ⚙️ (lo coloca quien lo crea).
function EmoteWheel.button(parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = "EmoteButton"
	button.Size = UDim2.fromOffset(52, 52)
	button.BackgroundColor3 = SQUARE_COLOR
	button.BackgroundTransparency = 0.2
	button.Text = "😀"
	button.TextScaled = true
	button.Parent = parent
	corner(button, UDim.new(0, 12))
	button.Activated:Connect(EmoteWheel.toggle)
	return button
end

local function buildGui()
	local screen = Widgets.screen("EmoteWheel", player:WaitForChild("PlayerGui"))
	-- Por encima de los botones táctiles (5) y por debajo de los Ajustes (8) y los avisos (10).
	screen.DisplayOrder = 7
	screen.IgnoreGuiInset = true
	screen.Enabled = false
	gui = screen
	-- Tocar fuera de la rueda la cierra.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 8, 6)
	backdrop.BackgroundTransparency = 0.6
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = screen
	backdrop.Activated:Connect(EmoteWheel.close)
	local holder = Instance.new("Frame")
	holder.Name = "Wheel"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	local side = (RADIUS + SLOT_SIZE / 2) * 2
	holder.Size = UDim2.fromOffset(side, side)
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	wheel = holder
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.fromScale(0.5, 0.5)
	close.Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE)
	close.BackgroundColor3 = CLOSE_COLOR
	close.Text = "X"
	close.Font = Enum.Font.BuilderSansExtraBold
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = holder
	corner(close, UDim.new(0.5, 0))
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = close
	close.Activated:Connect(EmoteWheel.close)
	-- En táctil no hay tecla.
	local hint = Widgets.label(
		if UserInputService.KeyboardEnabled
			then "Mantén . y suelta sobre un emote · se para al moverte"
			else "Se para al moverte",
		screen
	)
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.5, side / 2 + 6)
	hint.Size = UDim2.fromOffset(360, 24)
	hint.TextColor3 = Color3.fromRGB(230, 220, 200)
	textCap(hint, 16)
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(value)
		if value < health then
			lastHurt = os.clock()
		end
		health = value
	end)
end

-- Arranca la rueda (una vez por place, desde un controlador del cliente).
function EmoteWheel.start()
	if started then
		return
	end
	started = true
	buildGui()
	EmoteFx.start()
	-- El menú de emotes de Roblox usa la misma tecla.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
	end)
	-- Abierta solo mientras se mantiene la tecla; al soltarla, el emote bajo el ratón.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Period and not (gui and gui.Enabled) then
			EmoteWheel.open()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Period or not (gui and gui.Enabled) then
			return
		end
		local pick = hovered
		EmoteWheel.close()
		if pick then
			EmoteWheel.play(pick)
		end
	end)
	-- Lo puesto en la rueda cambia desde el Armario (Progress) y lo que se tiene, con las compras.
	player:GetAttributeChangedSignal("Progress"):Connect(function()
		if gui and gui.Enabled then
			refresh()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		stopEmote()
		watchCharacter(character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

return EmoteWheel
