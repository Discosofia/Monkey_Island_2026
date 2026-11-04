--!strict
-- Avisa al servidor del control que usa el jugador (Remotes.ReportInput): solo el táctil recibe la ayuda
-- de puntería (Config.AimAssist, Combat/AimInputService). Manda el tipo inicial al arrancar y después cada
-- cambio de UserInputService.LastInputTypeChanged, con un mínimo entre envíos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Tras un toque se ignoran el ratón simulado de algunos emuladores durante esto (segundos).
local TOUCH_MOUSE_GRACE = 0.5

local InputReporter = {}

local sentKind: string? = nil
local sentAt = -math.huge
local lastTouchAt = -math.huge
-- Un cambio que llegó antes del mínimo entre envíos: se manda al cumplirse.
local pending: string? = nil

local function initialKind(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "Mouse"
end

local function classify(inputType: Enum.UserInputType): string?
	local name = inputType.Name
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.match(name, "^Gamepad%d$") then
		return "Gamepad"
	elseif
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
		or inputType == Enum.UserInputType.MouseWheel
		or inputType == Enum.UserInputType.MouseMovement
	then
		return "Mouse"
	end
	return nil
end

local function report(kind: string)
	if kind == sentKind then
		pending = nil
		return
	end
	local wait = sentAt + Config.AimAssist.ReportMinInterval - os.clock()
	if wait > 0 then
		-- Se queda el último pedido; el hilo que ya espera lo manda.
		local waiting = pending ~= nil
		pending = kind
		if not waiting then
			task.delay(wait, function()
				local latest = pending
				pending = nil
				if latest and latest ~= sentKind then
					sentKind = latest
					sentAt = os.clock()
					Remotes.ReportInput:FireServer(latest)
				end
			end)
		end
		return
	end
	pending = nil
	sentKind = kind
	sentAt = os.clock()
	Remotes.ReportInput:FireServer(kind)
end

function InputReporter:Start()
	report(initialKind())
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local kind = classify(inputType)
		if not kind then
			return
		end
		local now = os.clock()
		if kind == "Touch" then
			lastTouchAt = now
		elseif kind == "Mouse" and (inputType.Name:find("^Mouse") ~= nil) and now - lastTouchAt < TOUCH_MOUSE_GRACE then
			-- Ratón simulado por el toque (emuladores): no es un cambio de control.
			return
		end
		report(kind)
	end)
end

return InputReporter
