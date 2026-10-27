--!strict
-- Monturas (Fase 11) en la Isla: dibuja las de todos (Shared/UI/MountRiders), enlaza Montar (N, R3 en
-- el mando y botón táctil) mientras lleves una montura y su gesto (Y y botón táctil: escupir, rugir)
-- mientras vas montado. La velocidad montado la pone SurvivalController (MountRiders.speedOf).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local MountRiders = require(ReplicatedStorage.Shared.UI.MountRiders)

local ACTION = "Mount"
local GESTURE_ACTION = "MountGesture"

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

-- El gesto de la montura (M3: escupir, rugir), solo montado: Y y botón táctil con su texto.
local function refreshGesture()
	local label = MountRiders.gestureLabel()
	if label then
		ActionButtons.bind(GESTURE_ACTION, label, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				MountRiders.gesture()
			end
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.Y)
	else
		ActionButtons.unbind(GESTURE_ACTION)
	end
end

function MountController:Start()
	MountRiders.start()
	Players.LocalPlayer:GetAttributeChangedSignal("ActiveMount"):Connect(refreshBinding)
	Players.LocalPlayer:GetAttributeChangedSignal("Mounted"):Connect(refreshGesture)
	refreshBinding()
	refreshGesture()
end

return MountController
