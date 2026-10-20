--!strict
-- Provisiones de partida (bucle de retención, octubre de 2026): objetos de la Isla (bananos, vendas,
-- antídotos…) que el jugador gana fuera de una partida (calendario, misiones) y se guardan en su
-- perfil ("supplies") hasta que empieza la siguiente partida, donde le llegan a la mochila
-- (RoleService). El inventario de la Isla no se guarda entre partidas: por eso hace falta este almacén.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards)
local PlayerData = require(script.Parent.PlayerData)

local Supplies = {}

-- Suma provisiones al almacén del jugador.
function Supplies.add(player: Player, items: { [string]: number })
	local clean = Rewards.sanitizeItems(items)
	if next(clean) == nil then
		return
	end
	PlayerData.update(player, function(profile)
		local stored = Rewards.sanitizeItems(profile.supplies)
		for itemId, amount in clean do
			stored[itemId] = (stored[itemId] or 0) + amount
		end
		profile.supplies = stored
	end)
end

-- Vacía el almacén y devuelve lo que había (para entregarlo en la Isla). Se guarda en seguida: si el
-- servidor cayera antes, el jugador las volvería a recibir en vez de perderlas.
function Supplies.takeAll(player: Player): { [string]: number }
	local taken: { [string]: number } = {}
	PlayerData.update(player, function(profile)
		taken = Rewards.sanitizeItems(profile.supplies)
		profile.supplies = {}
	end)
	if next(taken) ~= nil then
		task.spawn(PlayerData.saveNow, player)
	end
	return taken
end

return Supplies
