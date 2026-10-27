--!strict
-- Clima y eventos (GDD §7, Fase 5).
--   - Al empezar cada fase se sortea el clima (Config.Weather.Weights): despejado, lluvia o tormenta.
--     La lluvia quita sed a quien está fuera del Basecamp; la tormenta además lanza rayos.
--   - Erupción del volcán: a veces al azar, y siempre cuando el Gorila de Ceniza llega a su última
--     fase. Durante un minuto el cráter escupe bombas de lava en arco (con aviso en el suelo)
--     alrededor del volcán.
--   - Fase 9 (G7, MidEventService): la lluvia tóxica es un clima más ("ToxicRain", force) que no
--     quita la sed, y la erupción preliminar lanza piroclastos desde el cráter sobre las zonas altas
--     (pyroclasts).
-- El cliente lo dibuja (WeatherController) leyendo ReplicatedStorage: "Weather" y "Eruption".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local BossService = require(script.Parent.BossService)
local DayNightService = require(script.Parent.DayNightService)
local Hazards = require(script.Parent.Parent.Combat.Hazards)

local WeatherService = {}

local rng = Random.new()
local weatherToken = 0
local erupting = false

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text)
	end
end

local function pickWeather(): string
	local total = 0
	for _, weight in Config.Weather.Weights :: { [string]: number } do
		total += weight
	end
	local pick = rng:NextNumber(0, total)
	for name, weight in Config.Weather.Weights :: { [string]: number } do
		pick -= weight
		if pick <= 0 then
			return name
		end
	end
	return "Clear"
end

local function setWeather(name: string)
	ReplicatedStorage:SetAttribute("Weather", name)
	if name == "Rain" then
		announce("🌧️ Empieza a llover: fuera del Basecamp se te pasa la sed")
	elseif name == "Storm" then
		announce("⛈️ ¡Tormenta! Cuidado con los rayos")
	end
end

-- Centro de la zona volcánica (guarida del volcán), o nil si el mapa no la tiene.
local function volcanoCenter(): Vector3?
	local marker = Workspace:FindFirstChild("Guarida_Volcan", true)
	return if marker and marker:IsA("BasePart") then marker.Position else nil
end

-- Pone el clima "name" durante "seconds" (los eventos de mitad de partida): el sorteo de la fase no lo
-- quita antes. Después, despejado.
function WeatherService.force(name: string, seconds: number)
	weatherToken += 1
	local token = weatherToken
	setWeather(name)
	task.delay(seconds, function()
		if weatherToken == token then
			setWeather("Clear")
		end
	end)
end

-- Erupción preliminar (G7): durante "seconds" el cráter lanza piroclastos sobre "spots" (puntos de las
-- zonas altas) y, a veces (AimAtPlayerChance), sobre un jugador que esté en una de ellas.
function WeatherService.pyroclasts(spots: { Vector3 }, seconds: number)
	if #spots == 0 then
		return
	end
	local settings = Config.MidEvents.Eruption
	local center = volcanoCenter()
	local crater = if center then center + Vector3.new(0, 40, 0) else nil
	ReplicatedStorage:SetAttribute("Eruption", true)
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while os.clock() < endsAt do
			local target = spots[rng:NextInteger(1, #spots)]
			if rng:NextNumber() < settings.AimAtPlayerChance then
				local high = {}
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local position = if character then character:GetPivot().Position else nil
					if position and position.Y >= settings.HighGroundY and LifeState.isAlive(player) then
						table.insert(high, position)
					end
				end
				if #high > 0 then
					target = high[rng:NextInteger(1, #high)]
						+ Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
				end
			end
			Hazards.lavaBomb(target, settings.PyroclastDamage, settings.PyroclastRadius, 2, crater, "Piroclasto")
			task.wait(settings.PyroclastEverySeconds)
		end
		if not erupting then
			ReplicatedStorage:SetAttribute("Eruption", nil)
		end
	end)
end

function WeatherService.erupt()
	if erupting then
		return
	end
	local center = volcanoCenter()
	if not center then
		return
	end
	-- La guarida está en el fondo del cráter: las bombas salen por encima del borde.
	local crater = center + Vector3.new(0, 40, 0)
	erupting = true
	ReplicatedStorage:SetAttribute("Eruption", true)
	announce("🌋 ¡El volcán entra en erupción! Aléjate de sus laderas")
	task.spawn(function()
		local endsAt = os.clock() + Config.Weather.EruptionSeconds
		while os.clock() < endsAt do
			-- Bombas al azar por la zona, y alguna sobre los jugadores que estén cerca.
			local target = center
				+ Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * Config.Weather.EruptionRadius
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local position = if character then character:GetPivot().Position else nil
				local near = position and (position - center).Magnitude <= Config.Weather.EruptionRadius
				if near and position and rng:NextNumber() < 0.35 then
					target = position + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
					break
				end
			end
			Hazards.lavaBomb(target, Config.Weather.LavaBombDamage, 7, 1.6, crater)
			task.wait(Config.Weather.LavaBombEverySeconds)
		end
		erupting = false
		ReplicatedStorage:SetAttribute("Eruption", nil)
		announce("🌋 La erupción se calma")
	end)
end

local function onPhaseStarted(_day: number, _phase: MatchState.Phase)
	weatherToken += 1
	local token = weatherToken
	local weather = pickWeather()
	setWeather(weather)
	if weather ~= "Clear" then
		task.delay(rng:NextNumber(Config.Weather.MinSeconds, Config.Weather.MaxSeconds), function()
			if weatherToken == token then
				setWeather("Clear")
			end
		end)
	end
	if rng:NextNumber() < Config.Weather.EruptionChance then
		task.delay(rng:NextNumber(30, 200), WeatherService.erupt)
	end
end

local function tick(seconds: number)
	local weather = ReplicatedStorage:GetAttribute("Weather")
	if weather ~= "Rain" and weather ~= "Storm" then
		return
	end
	local amount = Config.Weather.RainThirstPerSecond * seconds * (if weather == "Storm" then 2 else 1)
	for _, player in Players:GetPlayers() do
		if LifeState.isAlive(player) and player:GetAttribute("InBasecamp") ~= true then
			local thirst = math.min(Survival.MAX, Survival.get(player, Survival.THIRST) + amount)
			player:SetAttribute(Survival.THIRST, thirst)
		end
	end
end

local function lightning()
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and LifeState.isAlive(player) and player:GetAttribute("InBasecamp") ~= true then
			table.insert(candidates, character:GetPivot().Position)
		end
	end
	if #candidates == 0 then
		return
	end
	local spot = candidates[rng:NextInteger(1, #candidates)]
		+ Vector3.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-15, 15))
	Hazards.lightning(spot, Config.Weather.LightningDamage, 5, 1.5)
	ReplicatedStorage:SetAttribute("LightningAt", Workspace:GetServerTimeNow() + 1.5)
end

function WeatherService:Init()
	DayNightService.onPhaseStarted(onPhaseStarted)
	BossService.onPhaseChanged(function(bossId: string, phase: number)
		if bossId == "GorilaDeCeniza" and phase == 3 then
			WeatherService.erupt()
		end
	end)
end

function WeatherService:Start()
	ReplicatedStorage:SetAttribute("Weather", "Clear")
	local sinceLightning = 0
	while true do
		task.wait(1)
		tick(1)
		if ReplicatedStorage:GetAttribute("Weather") == "Storm" then
			sinceLightning += 1
			if sinceLightning >= Config.Weather.LightningEverySeconds then
				sinceLightning = 0
				lightning()
			end
		end
	end
end

return WeatherService
