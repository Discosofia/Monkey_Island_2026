--!strict
-- Limita cada cuánto puede un jugador repetir una petición al servidor.
-- Protege contra clics repetidos y contra clientes modificados que envían spam.
--
-- Uso:
--   local canRequest = RequestCooldown.new(5)
--   if not canRequest(player) then return end

local Players = game:GetService("Players")

local RequestCooldown = {}

-- Devuelve una función que responde true (y registra el uso) si ya pasó el tiempo de espera.
function RequestCooldown.new(seconds: number): (player: Player) -> boolean
	local lastUse: { [Player]: number } = {}

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local last = lastUse[player]
		if last and now - last < seconds then
			return false
		end
		lastUse[player] = now
		return true
	end
end

return RequestCooldown
