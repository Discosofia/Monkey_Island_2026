--!strict
-- Punto de entrada del cliente del Laboratorio en ruinas (Fase 13): carga todos los módulos de la carpeta
-- Controllers y los del combate compartido (ReplicatedStorage.CombatClient.Controllers), menos los de lo
-- que aquí no hay: habilidades y combos (RoleController, ComboController), guardia (GuardController), la
-- cadena de disparos (ChainPipsController) y el bloqueo de cámara (CameraLockController: se juega en
-- primera persona, Controllers/FirstPersonController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButtons = require(ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("ActionButtons"))
local Loader = require(ReplicatedStorage.Shared.Loader)
local Localizer = require(ReplicatedStorage.Shared.UI.Localizer)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)

local SKIP = {
	RoleController = true,
	ComboController = true,
	GuardController = true,
	ChainPipsController = true,
	CameraLockController = true,
	ShoulderAimController = true,
}

-- Sin guardia, "Mira" ocupa la casilla de la guardia, junto al pulgar.
ActionButtons.setSlot("Zoom", Vector2.new(0, 1))
Remotes.Notify.OnClientEvent:Connect(Toast.show)
task.spawn(Localizer.start)

-- La interfaz nace en el idioma del perfil, no en el de la cuenta (Shared/Strings).
Strings.awaitSetting(3)
Loader.load({ script.Controllers, ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("Controllers") }, SKIP)
