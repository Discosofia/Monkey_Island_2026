--!strict
-- Mira de Dunas (Fase 15, V6): la de UI/Crosshair, configurable en Ajustes (⚙️), solo con un arma a distancia
-- en la mano (Data/Weapons, kind "Ranged") y el jugador vivo.
--   - Con ratón, sigue al cursor (CombatClient/Aim apunta ahí) y esconde el icono del sistema mientras no esté
--     encima de un botón o una ventana; con el ratón bloqueado en el centro (bloqueo de cámara), va al centro.
--   - Sin ratón (móvil, mando), en el centro de la pantalla (Aim apunta al centro de la cámara).
--   - Al quitar el arma, o con el cursor sobre la interfaz, vuelve el icono del sistema.
-- Es un ScreenGui "Mira" sin botones (DisplayOrder 5, IgnoreGuiInset: sus coordenadas son las del cursor de
-- UserInputService:GetMouseLocation, que cuenta la barra de Roblox). La dispersión y la recarga de la mira
-- (Handle.setSpread / setCooldown) las pondrán las armas más adelante (V8).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Crosshair = require(ReplicatedStorage.Shared.UI.Crosshair)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ArenaCrosshairController = {}

-- true si el personaje está vivo y lleva en la mano un arma a distancia.
local function hasRangedWeapon(character: Model?): boolean
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	if typeof(weaponId) ~= "string" then
		return false
	end
	local weapon = Weapons[weaponId]
	return weapon ~= nil and weapon.kind == "Ranged"
end

-- true si en "position" (coordenadas de la pantalla entera) hay un botón o una ventana que se pulsa.
local function overInterface(playerGui: PlayerGui, position: Vector2, own: ScreenGui): boolean
	local inGui = position - GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(inGui.X, inGui.Y) do
		if (object.Active or object:IsA("GuiButton")) and not object:IsDescendantOf(own) then
			return true
		end
	end
	return false
end

function ArenaCrosshairController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Widgets.screen("Mira", playerGui)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local crosshair = Crosshair.mount(gui)
	crosshair.setVisible(false)
	-- El icono del sistema está escondido por esta mira (para devolverlo solo si lo escondimos nosotros).
	local iconHidden = false

	local function setSystemIcon(visible: boolean)
		if visible == not iconHidden then
			return
		end
		iconHidden = not visible
		UserInputService.MouseIconEnabled = visible
	end

	RunService.RenderStepped:Connect(function()
		if not hasRangedWeapon(player.Character) then
			crosshair.setVisible(false)
			setSystemIcon(true)
			return
		end
		local usesMouse = UserInputService.MouseEnabled
		if not usesMouse then
			crosshair.root.Position = UDim2.fromScale(0.5, 0.5)
			crosshair.setVisible(true)
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			mouse = gui.AbsoluteSize / 2
		end
		local covered = overInterface(playerGui, mouse, gui)
		crosshair.setVisible(not covered)
		setSystemIcon(covered)
		crosshair.root.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	end)
end

return ArenaCrosshairController
