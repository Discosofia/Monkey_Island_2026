--!strict
-- Punto de entrada del cliente del Lobby: carga todos los módulos de la carpeta Controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)

Remotes.Notify.OnClientEvent:Connect(Toast.show)

Loader.load(script.Controllers)
