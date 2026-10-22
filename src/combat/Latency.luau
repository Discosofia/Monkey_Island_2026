--!strict
-- Compensación del lag (Fase 10, C2): cuánto margen se le da a un jugador por su ping al comprobar
-- lo que manda (recargas, esquiva y, desde C3 y C5, golpes rebobinados y parry). Igual para todos y
-- con tope (Config.Net.MaxCompensationSeconds): nadie gana por tener más ping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Latency = {}

-- Segundos de margen para "player": su ping de ida (Player:GetNetworkPing), sin pasar del tope.
function Latency.compensation(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	if not ok or typeof(ping) ~= "number" then
		return 0
	end
	return math.clamp(ping, 0, Config.Net.MaxCompensationSeconds)
end

return Latency
