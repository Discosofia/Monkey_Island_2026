--!strict
-- Entrada y salida del campo de tiro del Lobby (Fase 23, World/RangeBuilder). El arco del Lobby lleva el
-- aviso "CampoPrompt" (World/LobbyBuilder) y el arco trasero del recinto, "CampoSalidaPrompt". Al activarlos
-- el servidor comprueba que el jugador vive y está cerca del aviso, y mueve su personaje: dentro, a la zona
-- de preparación; fuera, delante del arco del Lobby.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LobbyBuilder = require(script.Parent.Parent.World.LobbyBuilder)
local RangeBuilder = require(script.Parent.Parent.World.RangeBuilder)
local RangeShooterService = require(script.Parent.RangeShooterService)

local ENTER_PROMPT = "CampoPrompt"
local EXIT_PROMPT = "CampoSalidaPrompt"
-- Margen sobre el alcance del aviso por el retraso de la red.
local REACH_SLACK = 8
local COOLDOWN_SECONDS = 1.5

local RangeService = {}

local lastUse: { [Player]: number } = {}
local arrivals = 0

-- El personaje vivo del jugador, si está lo bastante cerca del aviso.
local function characterNear(player: Player, prompt: ProximityPrompt): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local anchor = prompt.Parent
	if not (character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return nil
	end
	if not (anchor and anchor:IsA("BasePart")) then
		return nil
	end
	if (root.Position - anchor.Position).Magnitude > prompt.MaxActivationDistance + REACH_SLACK then
		return nil
	end
	return character
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	local now = os.clock()
	if now - (lastUse[player] or -math.huge) < COOLDOWN_SECONDS then
		return
	end
	local character = characterNear(player, prompt)
	if not character then
		return
	end
	lastUse[player] = now
	if prompt.Name == ENTER_PROMPT then
		arrivals += 1
		character:PivotTo(RangeBuilder.entrySpawn(arrivals))
	else
		-- Al salir se deja el arma del Armero (modo shooter, Fase 24b).
		RangeShooterService.release(player, true)
		character:PivotTo(LobbyBuilder.rangeExitSpawn())
	end
end

local function hook(instance: Instance)
	if instance:IsA("ProximityPrompt") and (instance.Name == ENTER_PROMPT or instance.Name == EXIT_PROMPT) then
		instance.Triggered:Connect(function(player: Player)
			onTriggered(instance, player)
		end)
	end
end

function RangeService:Start()
	for _, instance in Workspace:GetDescendants() do
		hook(instance)
	end
	Workspace.DescendantAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
	end)
end

return RangeService
