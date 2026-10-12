--!strict
-- Punto de entrada del servidor del Lobby: carga todos los módulos de la carpeta Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load(script.Services)
