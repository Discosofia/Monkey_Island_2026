--!strict
-- Pose de apuntar de los demás jugadores (Fase 19, W2). Quien lleva un arma a distancia reproduce su pista
-- "Aim*" en su propio personaje y Roblox la replica; por si no llega, el servidor publica "AimPose" en el
-- Player (Combat/Services/WeaponPoseService: la pista que debe sonar, "" si ninguna) y aquí se reproduce en
-- bucle en su personaje. Si la replicada ya suena, no se duplica (BodyAnimations.playIdOn).

local Players = game:GetService("Players")

local BodyAnimations = require(script.Parent.Parent.BodyAnimations)
local WeaponAnimationIds = require(script.Parent.Parent.WeaponAnimationIds)

local RemoteWeaponPoseController = {}

-- Lo que suena ahora en cada jugador ajeno: la pista y cómo pararla.
local playing: { [Player]: { key: string, character: Model, stop: () -> () } } = {}

local function clear(other: Player)
	local current = playing[other]
	if current then
		playing[other] = nil
		current.stop()
	end
end

local function apply(other: Player)
	local key = other:GetAttribute("AimPose")
	local character = other.Character
	local current = playing[other]
	if current and current.key == key and current.character == character then
		return
	end
	clear(other)
	if typeof(key) ~= "string" or key == "" or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid:FindFirstChildOfClass("Animator")) then
		return
	end
	local stop = BodyAnimations.playIdOn(character, WeaponAnimationIds.get(key), Enum.AnimationPriority.Action, true)
	playing[other] = { key = key, character = character, stop = stop }
end

local function watch(other: Player)
	if other == Players.LocalPlayer then
		return
	end
	other:GetAttributeChangedSignal("AimPose"):Connect(function()
		apply(other)
	end)
	other.CharacterAdded:Connect(function(character)
		clear(other)
		-- El Animator tarda un momento en aparecer en el personaje replicado.
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid:WaitForChild("Animator", 5)
		end
		if other.Character == character then
			apply(other)
		end
	end)
	apply(other)
end

function RemoteWeaponPoseController:Start()
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
end

return RemoteWeaponPoseController
