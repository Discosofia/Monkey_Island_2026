--!strict
-- Punto de entrada del cliente de la arena de Dunas: carga todos los módulos de la carpeta Controllers
-- y los del combate compartido con la Isla (ReplicatedStorage.CombatClient.Controllers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)

Remotes.Notify.OnClientEvent:Connect(Toast.show)

Loader.load({ script.Controllers, ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("Controllers") })
