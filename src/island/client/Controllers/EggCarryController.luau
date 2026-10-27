--!strict
-- Huevo misterioso a cuestas (Fase 5; soltarlo, Fase 12): mientras lo llevas aparece "Soltar huevo" (K,
-- R3 en el mando y botón táctil). El servidor lo deja en el suelo, donde cualquiera puede recogerlo
-- (EggService). Montar está bloqueado con el huevo, así que R3 no choca con la montura.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTION = "DropEgg"

local EggCarryController = {}

local function refreshBinding()
	if Players.LocalPlayer:GetAttribute("CarryingEgg") == true then
		ActionButtons.bind(ACTION, "Soltar huevo", function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				Remotes.DropEgg:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.K, Enum.KeyCode.ButtonR3)
	else
		ActionButtons.unbind(ACTION)
	end
end

function EggCarryController:Start()
	Players.LocalPlayer:GetAttributeChangedSignal("CarryingEgg"):Connect(refreshBinding)
	refreshBinding()
end

return EggCarryController
