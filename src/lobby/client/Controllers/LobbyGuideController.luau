--!strict
-- Guía de la primera vez en el Lobby: el menú ya no tiene los roles ni el nido, que están en la plaza,
-- así que a quien no la ha hecho ("LobbyGuideDone" falso, PlayerData) se le lleva hasta ellos:
--   1. Al cartel "ELIGE TU ROL" (hasta que usa su aviso, "RolesPrompt").
--   2. Al nido de huevos (hasta que usa su aviso, "NidoPrompt").
-- En cada paso: un aviso arriba (Toast), un rastro dorado desde los pies del personaje hasta la
-- estación y su icono flotante resaltado (StationMarkersController). Al acabar se guarda
-- (Remotes.LobbyGuideDone) y no vuelve a salir. En Studio se repite con "🧭 Repetir la guía".

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local StationMarkers = require(script.Parent.StationMarkersController)

local TRAIL_COLOR = Color3.fromRGB(255, 205, 70)
-- El rastro acaba unos studs delante de la estación (donde se para el jugador), a ras de suelo.
local TRAIL_STOP = 5
local FEET = 2.8
-- Segundos entre un aviso y su recordatorio, por si no lo ha leído.
local REMINDER_SECONDS = 25

type Step = { station: string, prompt: string, message: string }
local STEPS: { Step } = {
	{
		station = "Rol",
		prompt = "RolesPrompt",
		message = "⚔️ Ve al cartel «Elige tu rol» y pulsa E para elegir tu rol",
	},
	{
		station = "Mascotas",
		prompt = "NidoPrompt",
		message = "🥚 Ahora mira tu nido de huevos: de ahí nacen tus mascotas",
	},
}

local LobbyGuideController = {}

-- La pieza de la estación "id" (atributo "StationId", World/LobbyBuilder).
local function stationPart(id: string): BasePart?
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("BasePart") and instance:GetAttribute("StationId") == id then
			return instance
		end
	end
	return nil
end

function LobbyGuideController:Start()
	local player = Players.LocalPlayer
	local running = false

	local function run()
		if running then
			return
		end
		running = true
		for _, step in STEPS do
			local target: BasePart? = nil
			while not target do
				target = stationPart(step.station)
				if not target then
					task.wait(1)
				end
			end
			local part = target :: BasePart
			StationMarkers.focus(step.station)
			Toast.show(step.message)

			-- Rastro dorado del personaje a la estación, por el suelo.
			local stop = Instance.new("Attachment")
			stop.Name = "GuiaDestino"
			local front = if step.station == "Mascotas" then Vector3.zero else part.CFrame.LookVector * TRAIL_STOP
			stop.WorldPosition = Vector3.new(part.Position.X + front.X, 0, part.Position.Z + front.Z)
			stop.Parent = Workspace.Terrain
			local beam = Instance.new("Beam")
			beam.Name = "GuiaRastro"
			beam.Color = ColorSequence.new(TRAIL_COLOR)
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Transparency = NumberSequence.new(0.25)
			beam.Width0 = 0.7
			beam.Width1 = 0.7
			beam.FaceCamera = true
			beam.Segments = 20
			beam.Attachment1 = stop
			beam.Parent = Workspace.Terrain

			local done = false
			local connection = ProximityPromptService.PromptTriggered:Connect(function(prompt)
				if prompt.Name == step.prompt then
					done = true
				end
			end)
			local lastReminder = os.clock()
			while not done do
				-- El origen sigue a los pies del personaje (también tras reaparecer).
				local character = player.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if root and root:IsA("BasePart") then
					local start = root:FindFirstChild("GuiaOrigen")
					if not start then
						local attachment = Instance.new("Attachment")
						attachment.Name = "GuiaOrigen"
						attachment.Position = Vector3.new(0, -FEET, 0)
						attachment.Parent = root
						start = attachment
					end
					beam.Attachment0 = start :: Attachment
					-- A la altura del suelo bajo el personaje.
					stop.WorldPosition = Vector3.new(stop.WorldPosition.X, root.Position.Y - FEET, stop.WorldPosition.Z)
				end
				if os.clock() - lastReminder > REMINDER_SECONDS then
					lastReminder = os.clock()
					Toast.show(step.message)
				end
				task.wait(0.2)
			end
			connection:Disconnect()
			beam:Destroy()
			stop:Destroy()
		end
		StationMarkers.focus(nil)
		Toast.show("✅ ¡Listo! Lo demás está en los iconos del menú")
		Remotes.LobbyGuideDone:FireServer()
		running = false
	end

	local function check()
		if player:GetAttribute("LobbyGuideDone") == false then
			task.spawn(run)
		end
	end
	player:GetAttributeChangedSignal("LobbyGuideDone"):Connect(check)
	check()
end

return LobbyGuideController
