--!strict
-- Empujones de los golpes (Fase 10, C2): la Embestida y, desde C4 y C10, el remate de la cadena y el
-- rebote contra muros.
--   - A un mono (lo simula el servidor) se le da la velocidad aquí mismo, con un pequeño salto.
--   - A un jugador lo simula su propio cliente: si el servidor le pusiera la velocidad, su cliente la
--     pisaría. Se le manda el remoto Knockback y lo aplica KnockbackController con Dash.push (fuerza
--     limitada y corte contra las paredes).
-- Los jefes no se empujan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Knockback = {}

-- Velocidad hacia arriba que se suma al empujar a un mono (sale un poco del suelo y no se arrastra).
local ENEMY_LIFT = 20

-- Empuja a "model" en "direction" (se aplana) a "speed" studs/s durante "seconds". Con "lift" lo lanza
-- además hacia arriba a esos studs/s (el remate de la cadena dado en el aire).
function Knockback.push(model: Model, direction: Vector3, speed: number, seconds: number, lift: number?)
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.01 or model:GetAttribute("Boss") ~= nil then
		return
	end
	horizontal = horizontal.Unit
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		Remotes.Knockback:FireClient(player, horizontal, speed, seconds, lift)
		return
	end
	local root = model.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = horizontal * speed + Vector3.new(0, lift or ENEMY_LIFT, 0)
	end
end

return Knockback
