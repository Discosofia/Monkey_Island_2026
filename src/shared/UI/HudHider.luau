--!strict
-- Esconde la interfaz para grabar vídeos y para las cinemáticas (Fase 25): los ScreenGui del jugador (salvo
-- los que se excluyan), la CoreGui y el cursor del ratón. Cuenta las llamadas: dos hide necesitan dos
-- restore, y la interfaz solo vuelve cuando se suelta la última. Sin dependencias del juego (no requiere
-- Remotes ni Settings). Solo cliente.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local HudHider = {}

local count = 0
local excluded: { [ScreenGui]: boolean } = {}
local savedGuis: { [ScreenGui]: boolean } = {}
local savedCore: { [Enum.CoreGuiType]: boolean } = {}
local savedMouseIcon = true
local connections: { RBXScriptConnection } = {}

local function hideGui(gui: ScreenGui)
	savedGuis[gui] = gui.Enabled
	gui.Enabled = false
	-- Si el juego vuelve a encender esa pantalla mientras está oculta, se apunta su estado y se vuelve a ocultar.
	table.insert(
		connections,
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if count > 0 and gui.Enabled then
				savedGuis[gui] = true
				gui.Enabled = false
			end
		end)
	)
end

-- Oculta la interfaz. "except": pantallas que se quedan visibles (el panel de pruebas, el ScreenGui de la
-- cinemática). Las exclusiones de las llamadas anidadas se suman.
function HudHider.hide(except: { ScreenGui }?)
	for _, gui in except or {} do
		excluded[gui] = true
	end
	count += 1
	if count > 1 then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and not excluded[child] then
			hideGui(child)
		end
	end
	table.insert(
		connections,
		playerGui.ChildAdded:Connect(function(child)
			if count > 0 and child:IsA("ScreenGui") and not excluded[child] then
				hideGui(child)
			end
		end)
	)
	for _, item in Enum.CoreGuiType:GetEnumItems() do
		if item ~= Enum.CoreGuiType.All then
			savedCore[item] = StarterGui:GetCoreGuiEnabled(item)
		end
	end
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	savedMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = false
end

-- Suelta una llamada a hide. Con la última, deja cada cosa como estaba.
function HudHider.restore()
	if count == 0 then
		return
	end
	count -= 1
	if count > 0 then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}
	for gui, enabled in savedGuis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	savedGuis = {}
	for item, enabled in savedCore do
		StarterGui:SetCoreGuiEnabled(item, enabled)
	end
	savedCore = {}
	excluded = {}
	UserInputService.MouseIconEnabled = savedMouseIcon
end

function HudHider.isHidden(): boolean
	return count > 0
end

return HudHider
