--!strict
-- Fiesta del Lobby (evento en vivo de T4b, Data/LiveEvents "Party"): mientras dura, confeti de
-- bloquecitos que cae sobre la plaza y fuegos artificiales que estallan encima, y al empezar todos hacen a la vez el emote
-- "¡Ánimo!" (gratis para todos). Lo dibuja cada cliente a partir de Shared/LiveEvents; el centro de
-- la plaza lo publica el servidor (atributo "LobbyPlaza", EggRainService). Sin verde, morado ni rojo
-- (curación, veneno y daño).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local EmoteWheel = require(ReplicatedStorage.Shared.UI.EmoteWheel)

local COLORS = {
	Color3.fromRGB(255, 205, 70), -- oro
	Color3.fromRGB(120, 230, 255), -- cian
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 50), -- naranja
	Color3.fromRGB(90, 160, 255), -- azul
}
-- Confeti de bloquecitos (estilo voxel): cuántos caen por segundo, desde qué altura y cuánto tardan.
local CONFETTI_PER_SECOND = 24
local CONFETTI_HEIGHT = 24
local CONFETTI_FALL = NumberRange.new(4, 6.5)
local ROCKET_HEIGHT = 38

local PartyController = {}

local rng = Random.new()

local function anchor(position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(6, 1, 6)
	part.Position = position
	part.Parent = parent
	return part
end

-- Un bloquecito de color que cae girando sobre la plaza y se queda un momento en el suelo.
local function confettiPiece(plaza: Vector3, folder: Folder)
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = math.sqrt(rng:NextNumber()) * Config.LiveEvents.PlazaRadius
	local x, z = plaza.X + math.cos(angle) * distance, plaza.Z + math.sin(angle) * distance
	local piece = anchor(Vector3.new(x, plaza.Y + CONFETTI_HEIGHT, z), folder)
	piece.Size = Vector3.new(0.35, 0.08, 0.35)
	piece.Transparency = 0
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = COLORS[rng:NextInteger(1, #COLORS)]
	piece.CFrame = CFrame.new(piece.Position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
	local landed = CFrame.new(x + rng:NextNumber(-3, 3), plaza.Y + 0.1, z + rng:NextNumber(-3, 3))
		* CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	TweenService:Create(
		piece,
		TweenInfo.new(rng:NextNumber(CONFETTI_FALL.Min, CONFETTI_FALL.Max), Enum.EasingStyle.Linear),
		{ CFrame = landed }
	):Play()
	task.delay(CONFETTI_FALL.Max + 3, function()
		piece:Destroy()
	end)
end

-- Un cohete que sube desde el borde de la plaza y estalla en un color.
local function firework(plaza: Vector3, folder: Folder)
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(0.4, 1) * Config.LiveEvents.PlazaRadius
	local from = plaza + Vector3.new(math.cos(angle) * distance, 1, math.sin(angle) * distance)
	local color = COLORS[rng:NextInteger(1, #COLORS)]
	local rocket = anchor(from, folder)
	rocket.Size = Vector3.new(0.5, 0.5, 0.5)
	rocket.Transparency = 0
	rocket.Material = Enum.Material.Neon
	rocket.Color = color
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(color)
	trail.Size = NumberSequence.new(0.3, 0)
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(0.4)
	trail.Speed = NumberRange.new(0)
	trail.LightEmission = 1
	trail.Parent = rocket
	local rise = TweenService:Create(
		rocket,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = from + Vector3.new(0, ROCKET_HEIGHT, 0) }
	)
	rise.Completed:Connect(function()
		trail.Enabled = false
		rocket.Transparency = 1
		local burst = Instance.new("ParticleEmitter")
		burst.Color = ColorSequence.new(color)
		burst.Size = NumberSequence.new(0.6, 0)
		burst.Lifetime = NumberRange.new(1, 1.6)
		burst.Speed = NumberRange.new(18, 26)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 2.5
		burst.Acceleration = Vector3.new(0, -8, 0)
		burst.LightEmission = 1
		burst.Rate = 0
		burst.Parent = rocket
		burst:Emit(70)
		Sfx.play("Firework", rocket.Position)
		task.delay(2, function()
			rocket:Destroy()
		end)
	end)
	rise:Play()
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
