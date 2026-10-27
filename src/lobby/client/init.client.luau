--!strict
-- Punto de entrada del cliente del Lobby: carga todos los módulos de la carpeta Controllers y los del
-- combate compartido con la Isla y Dunas (ReplicatedStorage.CombatClient.Controllers), para probar
-- las habilidades y las armas del rol en la plaza.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)
local Localizer = require(ReplicatedStorage.Shared.UI.Localizer)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)

Remotes.Notify.OnClientEvent:Connect(Toast.show)
task.spawn(Localizer.start)

Loader.load({ script.Controllers, ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("Controllers") })
