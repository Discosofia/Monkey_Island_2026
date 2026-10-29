--!strict
-- Deslizamiento de los demás jugadores (Fase 18, L2). El que se desliza reproduce "Slide" en su propio
-- personaje y Roblox la replica; por si no llega, el servidor publica "SlidingUntil" (CombatService.onSlide)
-- y aquí se reproduce la misma pista en su personaje mientras dure. Si la replicada ya suena, no se duplica
-- (BodyAnimations.playOn).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BodyAnimations = require(script.Parent.Parent.BodyAnimations)

local RemoteSlideController = {}

local function watch(other: Player)
	if other == Players.LocalPlayer then
		return
	end
	other:GetAttributeChangedSignal("SlidingUntil"):Connect(function()
		local untilTime = other:GetAttribute("SlidingUntil")
		local character = other.Character
		if typeof(untilTime) ~= "number" or not character then
			return
		end
		local left = untilTime - Workspace:GetServerTimeNow()
		if left > 0 then
			BodyAnimations.playOn(character, "Slide", left)
		end
	end)
end

function RemoteSlideController:Start()
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
end

return RemoteSlideController
