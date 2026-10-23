--!strict
-- Nido de huevos del Lobby (bucle de retención, octubre de 2026): lo que el jugador decide en el panel
-- del nido (NestController). Todo se valida y se cambia en ServerShared/Eggs.
--   - PlaceEgg: pone en el nido vacío un huevo de la mochila o de los pendientes.
--   - DiscardEgg: lo descarta a cambio de Ámbar.
--   - HatchEgg: abre el huevo del nido si está listo; el cliente hace la ceremonia (EggHatched).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)

local NestService = {}

local canRequest = RequestCooldown.new(0.3)

local function readTarget(source: any, index: any): (Eggs.Source?, number?)
	if (source ~= "bag" and source ~= "pending") or typeof(index) ~= "number" or index ~= index // 1 then
		return nil, nil
	end
	return source, index
end

local function onPlace(player: Player, rawSource: any, rawIndex: any)
	local source, index = readTarget(rawSource, rawIndex)
	if not (source and index and canRequest(player)) then
		return
	end
	if Eggs.placeInNest(player, source, index) then
		Remotes.Notify:FireClient(player, "🥚 Huevo en el nido: ya se está incubando")
	else
		Remotes.Notify:FireClient(player, "El nido ya tiene un huevo: ábrelo cuando esté listo")
	end
end

local function onDiscard(player: Player, rawSource: any, rawIndex: any)
	local source, index = readTarget(rawSource, rawIndex)
	if not (source and index and canRequest(player)) then
		return
	end
	local amber = Eggs.discard(player, source, index)
	if amber > 0 then
		Remotes.Notify:FireClient(player, `Huevo descartado: +{amber} ✨ Ámbar`)
	end
end

local function onHatch(player: Player)
	if not canRequest(player) then
		return
	end
	local egg = Eggs.get(player)
	local rarity = if egg and egg.nest then egg.nest.rarity else nil
	local petId, equipped, isMount = Eggs.hatch(player)
	if not (petId and rarity) then
		return
	end
	Remotes.EggHatched:FireClient(player, petId, rarity, equipped, isMount)
end

function NestService:Start()
	Remotes.PlaceEgg.OnServerEvent:Connect(onPlace)
	Remotes.DiscardEgg.OnServerEvent:Connect(onDiscard)
	Remotes.HatchEgg.OnServerEvent:Connect(onHatch)
end

return NestService
