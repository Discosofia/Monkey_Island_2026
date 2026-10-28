--!strict
-- Guía de la primera vez en el Lobby: el menú ya no tiene los roles ni el nido, que están en la plaza,
-- así que a quien no la ha hecho ("LobbyGuideDone" falso, PlayerData) se le lleva hasta ellos:
--   1. Al cartel "ELIGE TU ROL" (hasta que usa su aviso, "RolesPrompt").
--   2. Al nido de huevos (hasta que usa su aviso, "NidoPrompt").
--   3. Al muñeco de sparring (Fase 10, C12), hasta que le para un golpe ("ParryAt" del Player, que
--      pone Combat/Guard): así aprende la guardia y el parry antes de la primera partida.
-- En cada paso: un aviso arriba (Toast), un rastro dorado desde los pies del personaje hasta la
-- estación (o el muñeco) y su icono flotante resaltado (StationMarkersController). Al acabar se guarda
-- (Remotes.LobbyGuideDone) y no vuelve a salir. El paso 3 se guarda aparte ("CombatGuideDone"): también
-- le sale una vez a quien ya tenía hecha la guía de antes. En Studio se repite con "🧭 Repetir la guía".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local StationMarkers = require(script.Parent.StationMarkersController)

local later = Strings.later

local TRAIL_COLOR = Color3.fromRGB(255, 205, 70)
-- El rastro acaba unos studs delante de la estación (donde se para el jugador), a ras de suelo.
local TRAIL_STOP = 5
local FEET = 2.8
-- Segundos entre un aviso y su recordatorio, por si no lo ha leído.
local REMINDER_SECONDS = 25
-- Lo que se deja leer el consejo de la guardia antes del aviso final.
local TIP_SECONDS = 4

-- "station": la estación de la plaza (o "Sparring", el muñeco); "prompt": el aviso que la completa.
-- "message": frase de Shared/Strings, con sus argumentos en "args".
type Step = { station: string, prompt: string?, message: string, args: { [string]: any }? }
local STEPS: { Step } = {
	{
		station = "Rol",
		prompt = "RolesPrompt",
		message = later("⚔️ Ve al cartel «Elige tu rol» y presiona E para elegir tu rol"),
	},
	{
		station = "Mascotas",
		prompt = "NidoPrompt",
		message = later("🥚 Ahora mira tu nido de huevos: de ahí nacen tus mascotas"),
	},
}

-- Cuánto delante del muñeco acaba el rastro: dentro de su alcance (Config.Combat.SparringRange).
local SPARRING_STOP = 4

-- Con qué se pone la guardia en el dispositivo que está usando (GuardController).
local function guardKey(): string
	local input = UserInputService:GetLastInputType()
	if input == Enum.UserInputType.Touch then
		return later("toca «Guardia»")
	elseif input.Name:find("Gamepad") then
		return later("presiona L2")
	end
	return later("presiona F")
end

local function sparringStep(): Step
	return {
		station = "Sparring",
		message = later("🛡️ Ve al muñeco de sparring: cuando enseñe «!», {key} justo antes del golpe"),
		args = { key = { guardKey() } },
	}
end

local LobbyGuideController = {}

-- La pieza de la estación "id" (atributo "StationId", World/LobbyBuilder), o la raíz del muñeco de
-- sparring (Combat/TrainingDummies, atributo "Sparring").
local function stationPart(id: string): BasePart?
	if id == "Sparring" then
		for _, model in CollectionService:GetTagged(Config.Combat.EnemyTag) do
			if model:GetAttribute("Sparring") == true and model:IsA("Model") and model.PrimaryPart then
				return model.PrimaryPart
			end
		end
		return nil
	end
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("BasePart") and instance:GetAttribute("StationId") == id then
			return instance
		end
	end
	return nil
end

-- Lleva al jugador por "steps", uno tras otro, hasta que hace cada uno.
local function guide(player: Player, steps: { Step })
	for _, step in steps do
		local target: BasePart? = nil
		while not target do
			target = stationPart(step.station)
			if not target then
				task.wait(1)
			end
		end
		local part = target :: BasePart
		StationMarkers.focus(if step.station == "Sparring" then nil else step.station)
		Toast.show(step.message, step.args)

		-- Rastro dorado del personaje a la estación, por el suelo.
		local stop = Instance.new("Attachment")
		stop.Name = "GuiaDestino"
		local front = if step.station == "Mascotas"
			then Vector3.zero
			elseif step.station == "Sparring" then part.CFrame.LookVector * SPARRING_STOP
			else part.CFrame.LookVector * TRAIL_STOP
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
		local connection = if step.prompt
			then ProximityPromptService.PromptTriggered:Connect(function(prompt)
				if prompt.Name == step.prompt then
					done = true
				end
			end)
			-- El muñeco: un parry de verdad (Combat/Guard pone "ParryAt" al parar).
			else player:GetAttributeChangedSignal("ParryAt"):Connect(function()
				done = true
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
				-- El del muñeco se rehace por si ha cambiado de teclado a mando o a la pantalla.
				local current = if step.station == "Sparring" then sparringStep() else step
				Toast.show(current.message, current.args)
			end
			task.wait(0.2)
		end
		connection:Disconnect()
		beam:Destroy()
		stop:Destroy()
	end
	StationMarkers.focus(nil)
end

function LobbyGuideController:Start()
	local player = Players.LocalPlayer
	local running = false

	local function run()
		if running then
			return
		end
		running = true
		local firstTime = player:GetAttribute("LobbyGuideDone") == false
		if firstTime then
			guide(player, STEPS)
			Remotes.LobbyGuideDone:FireServer()
		end
		if player:GetAttribute("CombatGuideDone") == false then
			guide(player, { sparringStep() })
			Remotes.LobbyGuideDone:FireServer("Combat")
			Toast.show("✨ ¡Bien parado! Mantén la guardia para bloquear; aturdido, esquiva para escapar (Evasivo)")
			-- Un aviso tapa al anterior: el último, cuando ya se ha leído este.
			task.wait(TIP_SECONDS)
		end
		if firstTime then
			Toast.show("✅ ¡Listo! Lo demás está en los iconos del menú")
		end
		running = false
	end

	local function check()
		if player:GetAttribute("LobbyGuideDone") == false or player:GetAttribute("CombatGuideDone") == false then
			task.spawn(run)
		end
	end
	player:GetAttributeChangedSignal("LobbyGuideDone"):Connect(check)
	player:GetAttributeChangedSignal("CombatGuideDone"):Connect(check)
	check()
end

return LobbyGuideController
