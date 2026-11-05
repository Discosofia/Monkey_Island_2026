--!strict
-- Avisa al servidor de la vista con que apunta el jugador (Remotes.ReportAimView; Data/AimViews): táctil, mando,
-- primera persona, bloqueo de cámara (con o sin apuntar) o cámara libre. Solo la usa la calibración del campo de
-- tiro, para separar sus medidas por vista. Manda la vista inicial y cada cambio, con un mínimo entre envíos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Aim = require(script.Parent.Parent.Aim)
local ViewMode = require(script.Parent.Parent.ViewMode)
local WeaponController = require(script.Parent.WeaponController)

local MIN_INTERVAL = 0.1

local AimViewReporter = {}

local function currentView(): string
	local input = UserInputService:GetLastInputType()
	if input == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(input.Name, "Gamepad", 1, true) then
		return "Pad"
	elseif ViewMode.get() == "First" then
		return "First"
	elseif Aim.cameraLocked() then
		return if WeaponController.isAiming() then "LockAim" else "Lock"
	end
	return "Free"
end

function AimViewReporter:Start()
	local sent: string? = nil
	local sentAt = -math.huge
	RunService.Heartbeat:Connect(function()
		local view = currentView()
		if view == sent or os.clock() - sentAt < MIN_INTERVAL then
			return
		end
		sent = view
		sentAt = os.clock()
		Remotes.ReportAimView:FireServer(view)
	end)
end

return AimViewReporter
