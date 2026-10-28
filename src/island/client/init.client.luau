--!strict
-- Punto de entrada del cliente de la Isla: carga todos los módulos de la carpeta Controllers y los del
-- combate compartido con la arena (ReplicatedStorage.CombatClient.Controllers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)
local Localizer = require(ReplicatedStorage.Shared.UI.Localizer)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)

Remotes.Notify.OnClientEvent:Connect(Toast.show)
task.spawn(Localizer.start)

-- La interfaz nace en el idioma del perfil, no en el de la cuenta (Shared/Strings).
Strings.awaitSetting(3)
Loader.load({ script.Controllers, ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("Controllers") })
