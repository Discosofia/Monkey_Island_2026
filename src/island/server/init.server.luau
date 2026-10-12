--!strict
-- Punto de entrada del servidor de la Isla: carga todos los módulos de la carpeta Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load(script.Services)
