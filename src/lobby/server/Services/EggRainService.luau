--!strict
-- Lluvia de huevos (evento en vivo de T4b, Data/LiveEvents "EggRain"): al empezar caen huevos del
-- cielo en la plaza del Lobby, Config.LiveEvents.EggRainPerPlayer por jugador (al menos EggRainMin).
-- Cada jugador puede recoger uno (ProximityPrompt): va al nido o a la mochila como cualquier huevo
-- (ServerShared/Eggs.grant). La rareza se sortea como la de un huevo de la Isla, con "Suerte de
-- huevo" si está en marcha. Lo que nadie recoge desaparece al acabar el evento.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local EggModel = require(ReplicatedStorage.Shared.EggModel)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local LiveEventsServer = require(ServerScriptService.ServerShared.LiveEventsServer)
local LobbyBuilder = require(script.Parent.Parent.World.LobbyBuilder)

local FALL_HEIGHT = 45
local EGG_PLACES = {
	nest = Strings.later("en el nido"),
	bag = Strings.later("en la mochila"),
	pending = Strings.later("pendiente (mochila llena)"),
}

local EggRainService = {}

local rng = Random.new()

local function groundAt(x: number, z: number, top: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(Vector3.new(x, top + 60, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position else nil
end

local function rain(event: LiveEvents.Event)
	local _, plaza = LobbyBuilder.practiceSpots()
	local folder = Instance.new("Folder")
	folder.Name = "LluviaDeHuevos"
	folder.Parent = Workspace
	-- Quién ya ha recogido uno en esta lluvia.
	local collected: { [Player]: boolean } = {}
	local count = math.max(Config.LiveEvents.EggRainMin, #Players:GetPlayers() * Config.LiveEvents.EggRainPerPlayer)
	for index = 1, count do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = math.sqrt(rng:NextNumber()) * Config.LiveEvents.PlazaRadius
		local ground = groundAt(plaza.X + math.cos(angle) * distance, plaza.Z + math.sin(angle) * distance, plaza.Y)
		if not ground then
			continue
		end
		local rarity = PetRoll.rollRarity(rng, LiveEvents.eggWeights())
		local model, main = EggModel.build(rarity, `Huevo{index}`)
		local landed = CFrame.new(ground + Vector3.new(0, main.Size.Y / 2, 0))
		model:PivotTo(landed + Vector3.new(0, FALL_HEIGHT, 0))
		model.Parent = folder
		TweenService:Create(
			main,
			TweenInfo.new(rng:NextNumber(1.6, 3.2), Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{ CFrame = landed }
		):Play()

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Recoger"
		Strings.setText(prompt, "ObjectText", "🥚 Huevo {rarity}", { rarity = { Rarities[rarity].name } })
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = main
		prompt.Triggered:Connect(function(player)
			if collected[player] then
				Remotes.Notify:FireClient(
					player,
					"🥚 Ya recogiste un huevo de esta lluvia: deja los demás a los otros"
				)
				return
			end
			if model.Parent == nil then
				return
			end
			local where = Eggs.grant(player, rarity)
			if not where then
				return
			end
			collected[player] = true
			EggModel.burst(main.Position, rarity)
			model:Destroy()
			Remotes.Notify:FireClient(
				player,
				"🥚 ¡Huevo {rarity} recogido! Está {place}",
				{ rarity = { Rarities[rarity].name }, place = { EGG_PLACES[where] } }
			)
		end)
		task.wait(0.15)
	end
	task.delay(math.max(1, event.endsAt - LiveEvents.now()), function()
		folder:Destroy()
	end)
end

function EggRainService:Start()
	-- El centro de la plaza, para la fiesta (lobby/client/Controllers/PartyController).
	local _, plaza = LobbyBuilder.practiceSpots()
	ReplicatedStorage:SetAttribute("LobbyPlaza", plaza)
	LiveEventsServer.onStarted(function(event)
		if event.kind == "EggRain" then
			rain(event)
		end
	end)
end

return EggRainService
