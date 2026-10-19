--!strict
-- Zona segura del Basecamp (GDD §10).
-- Marca a cada jugador con el atributo "InBasecamp" (true/false) para el HUD.
-- Otros sistemas (monos, daño, construcción) usan BasecampService.isInside(posición).
-- Vida del campamento (Config.Basecamp.MaxHealth…, publicada con Shared/Basecamp): los monos del
-- asedio la bajan desde su hueco junto a la hoguera (MonkeyService). A 0 el campamento cae: deja de
-- ser zona segura (CombatService, MonkeyService) y las estaciones no funcionan (CraftingService).
-- De día se regenera y vuelve a estar en pie al pasar de Config.Basecamp.RecoverFraction. Una barra
-- sobre la hoguera la enseña mientras no esté entera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Basecamp = require(ReplicatedStorage.Shared.Basecamp)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

-- Nombre del modelo de la hoguera del mapa (MapBuilder; CraftingService crea una si falta).
local CAMPFIRE_NAME = "Hoguera"
-- Como mucho un sonido de golpe por segundo: muchos monos pegan a la vez.
local HIT_SOUND_SECONDS = 1
local HEALTHY_COLOR = Color3.fromRGB(90, 230, 110)
local WARNING_COLOR = Color3.fromRGB(255, 170, 60)
local DANGER_COLOR = Color3.fromRGB(235, 70, 60)

local BasecampService = {}

local zone: BasePart? = nil
local health = Config.Basecamp.MaxHealth
local fallen = false
local lastHitSoundAt = 0
local billboard: BillboardGui? = nil

local function findOrCreateZone(): BasePart
	local existing = Workspace:FindFirstChild(Config.Basecamp.ZonePartName, true)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	warn(
		`[BasecampService] No hay una pieza "{Config.Basecamp.ZonePartName}" en Workspace. `
			.. "Se crea una zona por defecto en el centro del mapa (ver Config.Basecamp)."
	)
	local part = Instance.new("Part")
	part.Name = Config.Basecamp.ZonePartName
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = Config.Basecamp.DefaultZoneSize
	part.Position = Config.Basecamp.DefaultZoneCenter
	-- Verde muy transparente: visible desde fuera para saber dónde está la zona segura.
	part.Color = Color3.fromRGB(80, 200, 120)
	part.Transparency = 0.9
	part.Parent = Workspace
	return part
end

-- true si la posición está dentro de la zona del Basecamp (respeta la rotación de la pieza).
function BasecampService.isInside(position: Vector3): boolean
	local zonePart = zone
	if not zonePart then
		return false
	end
	local localPosition = zonePart.CFrame:PointToObjectSpace(position)
	local halfSize = zonePart.Size / 2
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

-- Centro de la zona del Basecamp (a media altura de la pieza).
function BasecampService.getCenter(): Vector3
	return if zone then zone.Position else Config.Basecamp.DefaultZoneCenter
end

-- Barra de vida sobre la hoguera (se crea la primera vez que hace falta).
local function campfireBillboard(): BillboardGui?
	if billboard and billboard.Parent then
		return billboard
	end
	local campfire = Workspace:FindFirstChild(CAMPFIRE_NAME, true)
	local anchor = if campfire and campfire:IsA("Model")
		then campfire.PrimaryPart or campfire:FindFirstChildWhichIsA("BasePart")
		elseif campfire and campfire:IsA("BasePart") then campfire
		else nil
	if not anchor then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BasecampHealth"
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 12)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.35
	back.BorderSizePixel = 0
	back.Parent = gui
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 6)
	backCorner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	gui.Parent = anchor
	billboard = gui
	return gui
end

-- Publica la vida (Shared/Basecamp) y actualiza la barra de la hoguera.
local function publish()
	local maxHealth = Config.Basecamp.MaxHealth
	ReplicatedStorage:SetAttribute(Basecamp.HEALTH, math.floor(health))
	ReplicatedStorage:SetAttribute(Basecamp.MAX_HEALTH, maxHealth)
	ReplicatedStorage:SetAttribute(Basecamp.FALLEN, fallen)
	local gui = campfireBillboard()
	if not gui then
		return
	end
	local fraction = math.clamp(health / maxHealth, 0, 1)
	gui.Enabled = fallen or fraction < 1
	local label = gui:FindFirstChild("Label") :: TextLabel
	label.Text = if fallen then "🔥 Campamento caído" else `🏕️ Campamento {math.floor(health)}/{maxHealth}`
	local fill = (gui :: any).Back.Fill :: Frame
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = if fallen or fraction < 0.25
		then DANGER_COLOR
		elseif fraction < 0.5 then WARNING_COLOR
		else HEALTHY_COLOR
end

-- Daño al campamento (un mono del asedio desde su hueco junto a la hoguera).
function BasecampService.damage(amount: number)
	if fallen or amount <= 0 then
		return
	end
	health = math.max(0, health - amount)
	local now = os.clock()
	if now - lastHitSoundAt >= HIT_SOUND_SECONDS then
		lastHitSoundAt = now
		local gui = billboard
		local anchor = if gui then gui.Parent else nil
		if anchor and anchor:IsA("BasePart") then
			Sfx.play("StructureHit", anchor)
		end
	end
	if health <= 0 then
		fallen = true
		Remotes.Notify:FireAllClients(
			"🔥 ¡El campamento ha caído! Ya no es zona segura y las estaciones no funcionan hasta que se recupere de día"
		)
	end
	publish()
end

-- Panel de pruebas: deja el campamento a "fraction" de su vida (sin hacerlo caer).
function BasecampService.debugSetHealth(fraction: number)
	health = Config.Basecamp.MaxHealth * math.clamp(fraction, 0, 1)
	publish()
end

-- De día se recupera; al pasar de RecoverFraction vuelve a estar en pie.
local function regenerate(seconds: number)
	local settings = Config.Basecamp
	local state = MatchState.read()
	if not (state and state.phase == "Day") or health >= settings.MaxHealth then
		return
	end
	health = math.min(settings.MaxHealth, health + settings.RegenPerSecond * seconds)
	if fallen and health >= settings.MaxHealth * settings.RecoverFraction then
		fallen = false
		Remotes.Notify:FireAllClients("🏕️ El campamento vuelve a estar en pie: zona segura y estaciones de nuevo")
	end
	publish()
end

function BasecampService:Init()
	zone = findOrCreateZone()
	publish()
end

function BasecampService:Start()
	task.spawn(function()
		while true do
			task.wait(1)
			regenerate(1)
			-- Por si la hoguera aún no existía al empezar (CraftingService la crea si falta).
			if not billboard then
				publish()
			end
		end
	end)
	while true do
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local inside = false
			if root and root:IsA("BasePart") then
				inside = BasecampService.isInside(root.Position)
			end
			if player:GetAttribute("InBasecamp") ~= inside then
				player:SetAttribute("InBasecamp", inside)
			end
		end
		task.wait(Config.Basecamp.CheckIntervalSeconds)
	end
end

return BasecampService
