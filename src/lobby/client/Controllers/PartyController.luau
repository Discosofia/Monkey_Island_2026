--!strict
-- Fiesta del Lobby (evento en vivo de T4b, Data/LiveEvents "Party"): mientras dura, confeti de
-- bloquecitos que cae sobre la plaza y fuegos artificiales que estallan encima, y al empezar todos hacen a la vez el emote
-- "¡Ánimo!" (gratis para todos). Lo dibuja cada cliente a partir de Shared/LiveEvents; el centro de
-- la plaza lo publica el servidor (atributo "LobbyPlaza", EggRainService). Sin verde, morado ni rojo
-- (curación, veneno y daño). Las piezas del confeti y los cohetes son de Shared/PartyFx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local PartyFx = require(ReplicatedStorage.Shared.PartyFx)
local EmoteWheel = require(ReplicatedStorage.Shared.UI.EmoteWheel)

-- Confeti de bloquecitos (estilo voxel): cuántos caen por segundo, desde qué altura y cuánto tardan.
local CONFETTI_PER_SECOND = 24
local CONFETTI_HEIGHT = 24
local CONFETTI_FALL = NumberRange.new(4, 6.5)
local ROCKET_HEIGHT = 38

local PartyController = {}

local rng = Random.new()

-- Un bloquecito de color que cae girando sobre la plaza y se queda un momento en el suelo.
local function confettiPiece(plaza: Vector3, folder: Folder)
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = math.sqrt(rng:NextNumber()) * Config.LiveEvents.PlazaRadius
	local x, z = plaza.X + math.cos(angle) * distance, plaza.Z + math.sin(angle) * distance
	local landed = Vector3.new(x + rng:NextNumber(-3, 3), plaza.Y + 0.1, z + rng:NextNumber(-3, 3))
	PartyFx.confettiPiece(
		folder,
		Vector3.new(x, plaza.Y + CONFETTI_HEIGHT, z),
		landed,
		PartyFx.PARTY_COLORS,
		rng:NextNumber(CONFETTI_FALL.Min, CONFETTI_FALL.Max)
	)
end

-- Un cohete que sube desde el borde de la plaza y estalla en un color.
local function firework(plaza: Vector3, folder: Folder)
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(0.4, 1) * Config.LiveEvents.PlazaRadius
	local from = plaza + Vector3.new(math.cos(angle) * distance, 1, math.sin(angle) * distance)
	PartyFx.firework(folder, from, PartyFx.PARTY_COLORS, ROCKET_HEIGHT)
end

local function party(event: LiveEvents.Event, plaza: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Fiesta"
	folder.Parent = Workspace
	EmoteWheel.play("EmoteCheer")
	task.spawn(function()
		while folder.Parent do
			confettiPiece(plaza, folder)
			task.wait(1 / CONFETTI_PER_SECOND)
		end
	end)
	-- Hasta que acaba o un administrador la para (sale de la lista).
	local function going(): boolean
		for _, listed in LiveEvents.list() do
			if listed.id == event.id then
				return LiveEvents.now() < event.endsAt
			end
		end
		return false
	end
	while going() do
		firework(plaza, folder)
		task.wait(rng:NextNumber(0.6, 1.6))
	end
	folder:Destroy()
end

function PartyController:Start()
	local seen: { [string]: boolean } = {}
	task.spawn(function()
		while true do
			task.wait(0.5)
			local plaza = ReplicatedStorage:GetAttribute("LobbyPlaza")
			if typeof(plaza) ~= "Vector3" then
				continue
			end
			local now = LiveEvents.now()
			for _, event in LiveEvents.list() do
				if event.kind == "Party" and LiveEvents.isRunning(event, now) and not seen[event.id] then
					seen[event.id] = true
					task.spawn(party, event, plaza)
				end
			end
		end
	end)
end

return PartyController
