--!strict
-- Vista del modo shooter del campo de tiro (Fase 24b). Con el atributo "ShooterWeapon" del jugador local (lo pone
-- RangeShooterService al equipar un arma del Armero) la cámara pasa a primera persona (CombatClient/ViewMode,
-- que ya apagan o encienden la mira del hombro, el bloqueo de cámara y las habilidades y la guardia); al
-- soltarla, al salir del campo o al morir vuelve a tercera persona.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewMode = require(ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("ViewMode"))

local ShooterViewController = {}

function ShooterViewController:Start()
	local player = Players.LocalPlayer
	local function apply()
		ViewMode.set(if typeof(player:GetAttribute("ShooterWeapon")) == "string" then "First" else "Third")
	end
	player:GetAttributeChangedSignal("ShooterWeapon"):Connect(apply)
	apply()
end

return ShooterViewController
