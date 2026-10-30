--!strict
-- Mira de las armas a distancia (Fase 15, V6; Fase 19, W8: pasó de Dunas a CombatClient, así que también la
-- tienen la Isla y el Lobby; el Laboratorio lleva la suya en FirstPersonController): la de UI/Crosshair,
-- configurable en Ajustes (⚙️), solo con un arma a distancia en la mano (Data/Weapons, kind "Ranged") y el
-- jugador vivo. Al apuntar (WeaponController.aimAlpha) entra la mira del arma (UI/Sights: visor, punto rojo,
-- mira de hierro o trayectoria) y esconde la normal.
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
local Workspace = game:GetService("Workspace")

local Aim = require(script.Parent.Parent.Aim)
local Crosshair = require(ReplicatedStorage.Shared.UI.Crosshair)
local Sights = require(ReplicatedStorage.Shared.UI.Sights)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local WeaponController = require(script.Parent.WeaponController)

local RangedCrosshairController = {}

-- El arma a distancia de la mano si el personaje está vivo y la lleva; si no, nil.
local function rangedWeapon(character: Model?): Weapons.WeaponDefinition?
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	if typeof(weaponId) ~= "string" then
		return nil
	end
	local weapon = Weapons[weaponId]
	return if weapon ~= nil and weapon.kind == "Ranged" then weapon else nil
end

-- La boca del arma de la mano: su Attachment o pieza "Muzzle" o, si no, el Handle. nil si no hay ninguna.
local function muzzlePosition(character: Model): Vector3?
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end
	local muzzle = tool:FindFirstChild("Muzzle", true) or tool:FindFirstChild("Handle")
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	elseif muzzle and muzzle:IsA("BasePart") then
		return muzzle.Position
	end
	return nil
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

function RangedCrosshairController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Widgets.screen("Mira", playerGui)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local crosshair = Crosshair.mount(gui)
	crosshair.setVisible(false)
	local sights = Sights.mount(gui)
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
		local character = player.Character
		local weapon = rangedWeapon(character)
		sights.setWeapon(weapon)
		local camera = Workspace.CurrentCamera
		if not (weapon and character and camera) then
			crosshair.setVisible(false)
			setSystemIcon(true)
			return
		end
		-- Dónde está la mira: el cursor, o el centro (ratón bloqueado, táctil o mando).
		local usesMouse = UserInputService.MouseEnabled
		local position = gui.AbsoluteSize / 2
		local covered = false
		if usesMouse then
			local mouse = UserInputService:GetMouseLocation()
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
				position = mouse
			end
			covered = overInterface(playerGui, position, gui)
		end
		-- La mira del arma (solo cuando se apunta; con alpha 0 no se dibuja nada ni se calcula el blanco).
		local alpha = WeaponController.aimAlpha()
		sights.update({
			alpha = alpha,
			aimPoint = if alpha > 0 then Aim.point(character) else Vector3.zero,
			muzzle = muzzlePosition(character),
			camera = camera,
			center = position,
		})
		crosshair.setVisible(not covered and not sights.covers())
		gui:SetAttribute("SightCovers", sights.covers())
		crosshair.root.Position = UDim2.fromOffset(position.X, position.Y)
		if usesMouse then
			setSystemIcon(covered)
		end
	end)
end

return RangedCrosshairController
