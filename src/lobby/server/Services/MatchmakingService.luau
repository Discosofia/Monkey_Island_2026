--!strict
-- Grupos y viaje a la Isla (Fase 3).
--   - Grupos: invitas a otro jugador del Lobby; si acepta, entra en tu grupo (hasta
--     Config.Party.MaxSize). El líder pulsa "Ir a la Isla" y viaja todo el grupo junto, al mismo
--     servidor. Quien no es líder no puede viajar solo mientras esté en un grupo.
--   - Sin grupo, cada uno viaja por su cuenta. Roblox elige un servidor de la Isla con hueco, así
--     que también se entra en partidas ya empezadas.
--   - Antes de viajar se guarda el perfil (rol elegido, compras) para que la Isla lo lea.
-- Para la interfaz se publican los atributos "PartyLeader" (UserId) y "PartyMembers" (nombres).
-- Fase 6, servidores privados: si este Lobby es un servidor privado, todos sus jugadores van a la misma
-- Isla reservada (nadie de fuera puede entrar en ella).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)

local MatchmakingService = {}

local reservedCode: string? = nil

-- Opciones de viaje: en un Lobby privado, la Isla reservada para él (se crea la primera vez).
local function travelOptions(): TeleportOptions?
	if game.PrivateServerId == "" or game.PrivateServerOwnerId == 0 then
		return nil
	end
	if not reservedCode then
		local ok, code = pcall(function()
			return (TeleportService:ReserveServer(Config.PlaceIds.Island))
		end)
		if not ok then
			warn(`[Matchmaking] No se pudo reservar la Isla privada: {code}`)
			return nil
		end
		reservedCode = code
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = reservedCode :: string
	return options
end

-- Grupos por líder; y el líder de cada miembro.
local parties: { [Player]: { Player } } = {}
local leaderOf: { [Player]: Player } = {}
-- Invitaciones pendientes: invitado -> { líder -> hora }.
local invites: { [Player]: { [Player]: number } } = {}

local function members(leader: Player): { Player }
	return parties[leader] or { leader }
end

-- El líder del grupo de "player" y todos sus miembros (sin grupo: él solo). Para la cola de la arena
-- (ArenaQueueService), que mete al grupo entero en el mismo equipo.
function MatchmakingService.partyOf(player: Player): (Player, { Player })
	local leader = leaderOf[player] or player
	return leader, table.clone(members(leader))
end

local function publish(leader: Player)
	local list = parties[leader]
	if not list then
		return
	end
	local names = {}
	for _, member in list do
		table.insert(names, member.DisplayName)
	end
	for _, member in list do
		member:SetAttribute("PartyLeader", leader.UserId)
		member:SetAttribute("PartyMembers", table.concat(names, ", "))
	end
end

local function clearAttributes(player: Player)
	player:SetAttribute("PartyLeader", nil)
	player:SetAttribute("PartyMembers", nil)
end

local function leave(player: Player)
	local leader = leaderOf[player]
	if not leader then
		return
	end
	leaderOf[player] = nil
	clearAttributes(player)
	local list = parties[leader]
	if not list then
		return
	end
	local index = table.find(list, player)
	if index then
		table.remove(list, index)
	end
	parties[leader] = nil
	if #list <= 1 then
		-- Grupo de uno: se deshace.
		for _, member in list do
			leaderOf[member] = nil
			clearAttributes(member)
			Remotes.Notify:FireClient(member, "El grupo se ha deshecho")
		end
		return
	end
	-- Si se fue el líder, lo es el siguiente.
	local newLeader = if player == leader then list[1] else leader
	parties[newLeader] = list
	for _, member in list do
		leaderOf[member] = newLeader
		Remotes.Notify:FireClient(member, `{player.DisplayName} ha salido del grupo`)
	end
	publish(newLeader)
end

local function onInvite(player: Player, targetUserId: any)
	local target = if typeof(targetUserId) == "number" then Players:GetPlayerByUserId(targetUserId) else nil
	if not target or target == player then
		return
	end
	local leader = leaderOf[player] or player
	if leader ~= player then
		Remotes.Notify:FireClient(player, "Solo el líder del grupo puede invitar")
		return
	end
	if leaderOf[target] then
		Remotes.Notify:FireClient(player, `{target.DisplayName} ya está en un grupo`)
		return
	end
	if #members(leader) >= Config.Party.MaxSize then
		Remotes.Notify:FireClient(player, `El grupo está lleno ({Config.Party.MaxSize})`)
		return
	end
	invites[target] = invites[target] or {}
	invites[target][leader] = os.clock()
	Remotes.PartyInvited:FireClient(target, leader.UserId, leader.DisplayName)
	Remotes.Notify:FireClient(player, `Invitación enviada a {target.DisplayName}`)
end

local function onRespond(player: Player, leaderUserId: any, accept: any)
	local leader = if typeof(leaderUserId) == "number" then Players:GetPlayerByUserId(leaderUserId) else nil
	local pending = invites[player]
	local sentAt = if pending and leader then pending[leader] else nil
	if pending and leader then
		pending[leader] = nil
	end
	if not (leader and sentAt) or accept ~= true then
		return
	end
	if os.clock() - sentAt > Config.Party.InviteSeconds then
		Remotes.Notify:FireClient(player, "La invitación ha caducado")
		return
	end
	if leaderOf[player] or (leaderOf[leader] and leaderOf[leader] ~= leader) then
		return
	end
	local list: { Player } = parties[leader] or { leader }
	if #list >= Config.Party.MaxSize then
		Remotes.Notify:FireClient(player, "El grupo está lleno")
		return
	end
	table.insert(list, player)
	parties[leader] = list
	for _, member in list do
		leaderOf[member] = leader
		Remotes.Notify:FireClient(member, `{player.DisplayName} se ha unido al grupo`)
	end
	publish(leader)
end

local canTravel = RequestCooldown.new(Config.Teleport.CooldownSeconds)

local function onJoinIsland(player: Player)
	if not canTravel(player) then
		return
	end
	local leader = leaderOf[player]
	if leader and leader ~= player then
		Remotes.Notify:FireClient(
			player,
			`Tu grupo viaja cuando {leader.DisplayName} (líder) presione "Ir a la {Config.PlaceNames.IslandShort}"`
		)
		return
	end
	local travellers = members(player)
	-- Guarda el perfil de todos antes de viajar: la Isla lee el rol elegido y las mejoras.
	local pending = #travellers
	for _, traveller in travellers do
		task.spawn(function()
			PlayerData.saveNow(traveller)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 8 do
		task.wait(0.1)
	end
	Teleporter.send(travellers, Config.PlaceIds.Island, `la {Config.PlaceNames.IslandShort}`, travelOptions())
end

function MatchmakingService:Start()
	Remotes.RequestJoinIsland.OnServerEvent:Connect(onJoinIsland)
	Remotes.PartyInvite.OnServerEvent:Connect(onInvite)
	Remotes.PartyRespond.OnServerEvent:Connect(onRespond)
	Remotes.PartyLeave.OnServerEvent:Connect(leave)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
	end)
end

return MatchmakingService
