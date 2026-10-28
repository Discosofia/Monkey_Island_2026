--!strict
-- Baliza de rescate y victoria (GDD §5.3, Fase 6).
--   1. Se construye en el núcleo del Basecamp (pieza "Beacon" del martillo).
--   2. Con las 4 piezas de los jefes (Shared/Beacon) y desde el día Config.Match.BeaconUnlockDay, de
--      día, se puede encender (mantener pulsado su aviso).
--   3. Esa noche es la noche final, "La Gran Tropa" (SiegeService: más oleadas y más grandes).
--   4. Si al amanecer queda alguien en pie: ¡rescate! Victoria para todo el servidor.
-- Fase 9 (G8): parte de la Gran Tropa va a por la baliza (Config.Siege.BeaconRaid). Si la derriban
-- (Buildables "breaksInPlace": no desaparece), la señal se corta: no hay rescate al amanecer. Al
-- amanecer se repara entera y se puede volver a encender (otra Gran Tropa esa noche). Una barra sobre
-- la baliza enseña su vida mientras está encendida o dañada.
-- Publica "BeaconStatus" (HUD), "BeaconLit" y "FinalNight" en ReplicatedStorage.
-- Fase 12: tras el rescate la partida puede seguir ("Seguir sobreviviendo"); la baliza se apaga y ya
-- no se puede encender.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Beacon = require(ReplicatedStorage.Shared.Beacon)
local Building = require(ReplicatedStorage.Shared.Building)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Retention = require(ServerScriptService.ServerShared.Retention)
local DayNightService = require(script.Parent.DayNightService)
local BuildingService = require(script.Parent.BuildingService)
local MatchService = require(script.Parent.MatchService)

local LIT_COLOR = Color3.fromRGB(255, 60, 50)
local HEALTHY_COLOR = Color3.fromRGB(90, 230, 110)
local WARNING_COLOR = Color3.fromRGB(255, 170, 60)
local DANGER_COLOR = Color3.fromRGB(235, 70, 60)

local BeaconService = {}

local lit = false
local finalNight = false
-- La Gran Tropa derribó la baliza esta noche: al amanecer no hay rescate.
local signalCut = false

-- Aviso a todos: plantilla en español y sus argumentos, que traduce cada cliente.
local function announce(text: string, args: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text, args)
	end
end

local function findBeacon(): Model?
	local folder = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("BuildableId") == "Beacon" then
			return model
		end
	end
	return nil
end

-- Luz roja de la baliza encendida, o apagada (como recién construida).
local function setLamp(beacon: Model?, on: boolean)
	local lamp = if beacon then beacon:FindFirstChild("Lamp") else nil
	if not (lamp and lamp:IsA("BasePart")) then
		return
	end
	local light = lamp:FindFirstChildOfClass("PointLight")
	if on then
		lamp:SetAttribute("OffColor", lamp:GetAttribute("OffColor") or lamp.Color)
		lamp.Material = Enum.Material.Neon
		lamp.Color = LIT_COLOR
		if not light then
			light = Instance.new("PointLight")
			light.Color = LIT_COLOR
			light.Range = 60
			light.Brightness = 4
			light.Parent = lamp
		end
	else
		local offColor = lamp:GetAttribute("OffColor")
		lamp.Material = Enum.Material.Glass
		lamp.Color = if typeof(offColor) == "Color3" then offColor else lamp.Color
		if light then
			light:Destroy()
		end
	end
end

-- Humo sobre la torre mientras está derribada.
local function setSmoke(beacon: Model, on: boolean)
	local tower = beacon:FindFirstChild("Tower")
	if not (tower and tower:IsA("BasePart")) then
		return
	end
	local smoke = tower:FindFirstChild("BrokenSmoke")
	if on and not smoke then
		local newSmoke = Instance.new("Smoke")
		newSmoke.Name = "BrokenSmoke"
		newSmoke.Color = Color3.fromRGB(60, 60, 60)
		newSmoke.Size = 4
		newSmoke.RiseVelocity = 4
		newSmoke.Opacity = 0.4
		newSmoke.Parent = tower
	elseif not on and smoke then
		smoke:Destroy()
	end
end

-- Barra de vida sobre la baliza (se crea la primera vez que hace falta), como la de la hoguera.
local function healthBar(beacon: Model): BillboardGui?
	local tower = beacon:FindFirstChild("Tower")
	if not (tower and tower:IsA("BasePart")) then
		return nil
	end
	local existing = tower:FindFirstChild("BeaconHealth")
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BeaconHealth"
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
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
	gui.Parent = tower
	return gui
end

local function healthOf(beacon: Model): (number, number)
	local health = beacon:GetAttribute("Health")
	local maxHealth = beacon:GetAttribute("MaxHealth")
	local max = if typeof(maxHealth) == "number" then maxHealth else 1
	return if typeof(health) == "number" then health else max, max
end

local function updateBar(beacon: Model)
	local gui = healthBar(beacon)
	if not gui then
		return
	end
	local health, maxHealth = healthOf(beacon)
	local fraction = math.clamp(health / maxHealth, 0, 1)
	local broken = BuildingService.isBroken(beacon)
	gui.Enabled = lit or broken or fraction < 1
	local label = gui:FindFirstChild("Label") :: TextLabel
	if broken then
		Strings.setWorldText(label, "📡 Baliza derribada")
	else
		Strings.setWorldText(label, "📡 Baliza {health}/{max}", { health = math.floor(health), max = maxHealth })
	end
	local fill = (gui :: any).Back.Fill :: Frame
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = if broken or fraction < 0.25
		then DANGER_COLOR
		elseif fraction < 0.5 then WARNING_COLOR
		else HEALTHY_COLOR
end

-- La Gran Tropa (u otro mono) la ha derribado: si estaba encendida, la señal se corta.
local function onBroken(model: Model)
	if model:GetAttribute("BuildableId") ~= "Beacon" then
		return
	end
	setSmoke(model, true)
	updateBar(model)
	if lit then
		lit = false
		signalCut = true
		ReplicatedStorage:SetAttribute("BeaconLit", nil)
		setLamp(model, false)
		announce("📡 ¡Los monos han derribado la baliza! Se ha cortado la señal: esta noche no habrá rescate")
	else
		announce("📡 ¡Los monos han derribado la baliza! Se reparará al amanecer")
	end
end

local function onLight(player: Player)
	if lit or not LifeState.isAlive(player) then
		return
	end
	if MatchService.isRescued() then
		Remotes.Notify:FireClient(player, "📡 Ya los rescataron: ahora toca sobrevivir todo lo que puedan")
		return
	end
	local beacon = findBeacon()
	if beacon and BuildingService.isBroken(beacon) then
		Remotes.Notify:FireClient(player, "📡 La baliza está derribada: se repara al amanecer")
		return
	end
	local state = MatchState.read()
	local pieces = #Beacon.pieces()
	if pieces < Beacon.total() then
		Remotes.Notify:FireClient(
			player,
			"📡 Faltan piezas de los jefes: {pieces}/{total}",
			{ pieces = pieces, total = Beacon.total() }
		)
		return
	end
	-- En Studio, el panel de pruebas puede saltarse la espera del día 8 (DebugService).
	local debugUnlocked = ReplicatedStorage:GetAttribute("DebugBeaconUnlocked") == true
	if not debugUnlocked and (not state or state.day < Config.Match.BeaconUnlockDay) then
		Remotes.Notify:FireClient(
			player,
			"📡 La baliza solo se puede encender desde el día {day}",
			{ day = Config.Match.BeaconUnlockDay }
		)
		return
	end
	if not state or state.phase ~= "Day" then
		Remotes.Notify:FireClient(player, "📡 Enciéndela de día: esa misma noche llegará La Gran Tropa")
		return
	end
	lit = true
	ReplicatedStorage:SetAttribute("BeaconLit", true)
	Retention.progress(player, "Beacon")
	setLamp(beacon, true)
	if beacon then
		updateBar(beacon)
	end
	announce(
		"🚨 ¡{player} ha encendido la baliza! Esta noche llega La Gran Tropa: defiende la baliza hasta el amanecer",
		{ player = player.DisplayName }
	)
end

local function addPrompt(model: Model)
	local anchor = model:FindFirstChild("Tower") or model.PrimaryPart
	if not (anchor and anchor:IsA("BasePart")) or anchor:FindFirstChild("BeaconPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BeaconPrompt"
	prompt.ActionText = "Encender baliza"
	prompt.ObjectText = "Baliza de rescate"
	prompt.HoldDuration = 3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(onLight)
end

local function onPhaseStarted(_day: number, phase: MatchState.Phase)
	if phase == "Night" and lit and not finalNight then
		finalNight = true
		ReplicatedStorage:SetAttribute("FinalNight", true)
		announce("🌕 ¡LA GRAN TROPA! Toda la isla viene a por el Basecamp")
	elseif phase == "Day" then
		-- Al amanecer se repara (también si los monos solo la dañaron).
		local beacon = findBeacon()
		if beacon then
			local _, maxHealth = healthOf(beacon)
			BuildingService.repair(beacon, maxHealth)
			setSmoke(beacon, false)
			updateBar(beacon)
		end
		if finalNight and signalCut then
			finalNight = false
			signalCut = false
			ReplicatedStorage:SetAttribute("FinalNight", nil)
			announce(
				"🌅 Amanece sin rescate. La baliza está reparada: enciéndela de nuevo y defiéndela esta noche"
			)
		elseif finalNight then
			local anyoneStanding = false
			for _, player in Players:GetPlayers() do
				if LifeState.isAlive(player) then
					anyoneStanding = true
				end
			end
			if anyoneStanding then
				announce("🚁 ¡Amanece y llega el rescate! ¡Lo lograron!")
				-- La partida puede seguir (Fase 12): la baliza ya cumplió y se queda apagada.
				finalNight = false
				lit = false
				ReplicatedStorage:SetAttribute("FinalNight", nil)
				ReplicatedStorage:SetAttribute("BeaconLit", nil)
				setLamp(beacon, false)
				MatchService.endMatch("Victory")
			end
		end
	end
end

function BeaconService:Init()
	DayNightService.onPhaseStarted(onPhaseStarted)
	BuildingService.onBroken(onBroken)
end

function BeaconService:Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild(Building.STRUCTURES_FOLDER)
		folder.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Model") and child:GetAttribute("BuildableId") == "Beacon" then
				addPrompt(child)
				child:GetAttributeChangedSignal("Health"):Connect(function()
					updateBar(child)
				end)
			end
		end)
	end)
	while true do
		task.wait(1)
		local pieces = #Beacon.pieces()
		local status: string? = nil
		local beacon = findBeacon()
		if MatchService.isRescued() then
			status = Strings.pack("♾️ Seguir sobreviviendo: cada día de más cuenta para tu récord")
		elseif finalNight and signalCut then
			status = Strings.pack("📡 Baliza derribada: esta noche no habrá rescate. ¡Resiste hasta el amanecer!")
		elseif finalNight then
			local health, maxHealth = 0, 1
			if beacon then
				health, maxHealth = healthOf(beacon)
			end
			status = Strings.pack(
				"🌕 La Gran Tropa: ¡defiende la baliza ({percent} %) hasta el amanecer!",
				{ percent = math.floor(health / maxHealth * 100) }
			)
		elseif lit then
			status = Strings.pack("🚨 Baliza encendida: esta noche llega La Gran Tropa. ¡Defiéndela!")
		elseif pieces > 0 or beacon then
			status = Strings.pack(
				if beacon
					then Strings.later("📡 Baliza construida · piezas {pieces}/{total}")
					else Strings.later("📡 Baliza sin construir · piezas {pieces}/{total}"),
				{ pieces = pieces, total = Beacon.total() }
			)
		end
		ReplicatedStorage:SetAttribute("BeaconStatus", status)
	end
end

return BeaconService
