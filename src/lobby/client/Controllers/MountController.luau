--!strict
-- Monturas (Fase 11) en el Lobby: dibuja las de todos (Shared/UI/MountRiders), enlaza Montar (N, R3 en
-- el mando y botón táctil) mientras lleves una montura y pone la velocidad montado (en el Lobby nadie
-- más la cambia).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local MountRiders = require(ReplicatedStorage.Shared.UI.MountRiders)

local ACTION = "Mount"
-- Velocidad a pie en el Lobby (la de Roblox).
local WALK_SPEED = 16

local MountController = {}

-- El botón solo está si lleva una montura.
local function refreshBinding()
	if typeof(Players.LocalPlayer:GetAttribute("ActiveMount")) == "string" then
		ActionButtons.bind(ACTION, "Montar", function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				MountRiders.toggle()
			end
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.N, Enum.KeyCode.ButtonR3)
	else
		ActionButtons.unbind(ACTION)
	end
end

function MountController:Start()
	MountRiders.start()
	Players.LocalPlayer:GetAttributeChangedSignal("ActiveMount"):Connect(refreshBinding)
	refreshBinding()
	-- Solo se toca la velocidad montado y al bajar: a pie la deja como esté.
	local wasMounted = false
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid then
			return
		end
		local speed = MountRiders.speedOf(Players.LocalPlayer)
		if speed then
			wasMounted = true
		elseif wasMounted then
			wasMounted = false
			speed = WALK_SPEED
		end
		if speed and humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end)
end

return MountController
