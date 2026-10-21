--!strict
-- Baliza de rescate y victoria (GDD §5.3, Fase 6).
--   1. Se construye en el núcleo del Basecamp (pieza "Beacon" del martillo).
--   2. Con las 4 piezas de los jefes (Shared/Beacon) y desde el día Config.Match.BeaconUnlockDay, de
--      día, se puede encender (mantener pulsado su aviso).
--   3. Esa noche es la noche final, "La Gran Tropa" (SiegeService: más oleadas y más grandes).
--   4. Si al amanecer queda alguien en pie: ¡rescate! Victoria para todo el servidor.
-- Publica "BeaconStatus" (HUD), "BeaconLit" y "FinalNight" en ReplicatedStorage.

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
local Retention = require(ServerScriptService.ServerShared.Retention)
local DayNightService = require(script.Parent.DayNightService)
local MatchService = require(script.Parent.MatchService)

local BeaconService = {}

local lit = false
local finalNight = false

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text)
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

local function onLight(player: Player)
	if lit or not LifeState.isAlive(player) then
		return
	end
	local state = MatchState.read()
	local pieces = #Beacon.pieces()
	if pieces < Beacon.total() then
		Remotes.Notify:FireClient(player, `📡 Faltan piezas de los jefes: {pieces}/{Beacon.total()}`)
		return
	end
	-- En Studio, el panel de pruebas puede saltarse la espera del día 8 (DebugService).
	local debugUnlocked = ReplicatedStorage:GetAttribute("DebugBeaconUnlocked") == true
	if not debugUnlocked and (not state or state.day < Config.Match.BeaconUnlockDay) then
		Remotes.Notify:FireClient(
			player,
			`📡 La baliza solo se puede encender desde el día {Config.Match.BeaconUnlockDay}`
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
	local beacon = findBeacon()
	local lamp = if beacon then beacon:FindFirstChild("Lamp") else nil
	if lamp and lamp:IsA("BasePart") then
		lamp.Material = Enum.Material.Neon
		lamp.Color = Color3.fromRGB(255, 60, 50)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 60, 50)
		light.Range = 60
		light.Brightness = 4
		light.Parent = lamp
	end
	announce(
		`🚨 ¡{player.DisplayName} ha encendido la baliza! Esta noche llega La Gran Tropa: resistid hasta el amanecer`
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
	elseif phase == "Day" and finalNight then
		local anyoneStanding = false
		for _, player in Players:GetPlayers() do
			if LifeState.isAlive(player) then
				anyoneStanding = true
			end
		end
		if anyoneStanding then
			announce("🚁 ¡Amanece y llega el rescate! ¡Lo habéis conseguido!")
			MatchService.endMatch("Victory")
		end
	end
end

function BeaconService:Init()
	DayNightService.onPhaseStarted(onPhaseStarted)
end

function BeaconService:Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild(Building.STRUCTURES_FOLDER)
		folder.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Model") and child:GetAttribute("BuildableId") == "Beacon" then
				addPrompt(child)
			end
		end)
	end)
	while true do
		task.wait(1)
		local pieces = #Beacon.pieces()
		local status: string? = nil
		if finalNight then
			status = "🌕 La Gran Tropa: ¡resistid hasta el amanecer!"
		elseif lit then
			status = "🚨 Baliza encendida: esta noche llega La Gran Tropa"
		elseif pieces > 0 or findBeacon() then
			local built = if findBeacon() then "construida" else "sin construir"
			status = `📡 Baliza {built} · piezas {pieces}/{Beacon.total()}`
		end
		ReplicatedStorage:SetAttribute("BeaconStatus", status)
	end
end

return BeaconService
