--!strict
-- Piezas de la baliza de rescate (Fases 5 y 6). Pertenecen al servidor, no a un jugador.
-- BossService añade una al derrotar a cada jefe; la baliza (BeaconService) las necesita todas.
-- Se publican en ReplicatedStorage ("BeaconPieces": ids de jefe separados por comas).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(script.Parent.Data.Bosses)

local ATTRIBUTE = "BeaconPieces"

local Beacon = {}

function Beacon.pieces(): { string }
	local value = ReplicatedStorage:GetAttribute(ATTRIBUTE)
	if typeof(value) ~= "string" or value == "" then
		return {}
	end
	return string.split(value, ",")
end

function Beacon.has(bossId: string): boolean
	return table.find(Beacon.pieces(), bossId) ~= nil
end

function Beacon.total(): number
	local count = 0
	for _ in Bosses do
		count += 1
	end
	return count
end

-- Solo el servidor debe llamarla.
function Beacon.add(bossId: string)
	if Beacon.has(bossId) then
		return
	end
	local pieces = Beacon.pieces()
	table.insert(pieces, bossId)
	ReplicatedStorage:SetAttribute(ATTRIBUTE, table.concat(pieces, ","))
end

return Beacon
