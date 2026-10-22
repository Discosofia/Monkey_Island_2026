--!strict
-- Empujones que recibe el jugador local (Fase 10, C2): el servidor decide el golpe y manda el remoto
-- Knockback; aquí se mueve al personaje, que es de este cliente (Combat/Knockback).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Dash = require(script.Parent.Parent.Dash)

local KnockbackController = {}

function KnockbackController:Start()
	Remotes.Knockback.OnClientEvent:Connect(function(direction: any, speed: any, seconds: any)
		if typeof(direction) ~= "Vector3" or typeof(speed) ~= "number" or typeof(seconds) ~= "number" then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			Dash.push(root, direction, speed, seconds)
		end
	end)
end

return KnockbackController
