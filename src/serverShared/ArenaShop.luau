--!strict
-- Tienda del equipamiento de la arena (Data/ArenaGear), la misma en el Lobby (pestaña Arena) y en la
-- base de Dunas. Se guarda en el perfil, en "arena":
--   owned    { [id] = true }                   lo comprado (para siempre)
--   loadout  { [rol] = { Weapon, Armor, Amulet } }  lo puesto en cada ranura (sin nada, lo básico)
-- El cliente lo ve en el atributo "Arena" del jugador (PlayerData). Cada place conecta los remotos
-- (start) y decide cuándo se puede cambiar el equipo (en Dunas, solo antes de la partida).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaGear = require(ReplicatedStorage.Shared.Data.ArenaGear)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Analytics = require(script.Parent.Analytics)
local PlayerData = require(script.Parent.PlayerData)
local RequestCooldown = require(script.Parent.RequestCooldown)

local ArenaShop = {}

local canRequest = RequestCooldown.new(0.5)

local function loadoutOf(arena: { [string]: any }, roleId: string): { [string]: string }
	arena.loadout = if typeof(arena.loadout) == "table" then arena.loadout else {}
	local loadout = arena.loadout[roleId]
	if typeof(loadout) ~= "table" then
		loadout = {}
		arena.loadout[roleId] = loadout
	end
	return loadout
end

-- Lo puesto por "player" con "roleId" (ranura → id), para Data/ArenaGear.perksOf.
function ArenaShop.loadout(player: Player, roleId: string): { [string]: any }?
	local profile = PlayerData.get(player)
	local all = if profile then profile.arena.loadout else nil
	return if typeof(all) == "table" and typeof(all[roleId]) == "table" then all[roleId] else nil
end

-- Compra "gearId" y se lo pone. Devuelve true si lo compró.
function ArenaShop.buy(player: Player, gearId: string): boolean
	local item = ArenaGear.items[gearId]
	local profile = PlayerData.get(player)
	if not (item and profile) then
		return false
	end
	local owned = profile.arena.owned
	if typeof(owned) == "table" and owned[gearId] then
		return false
	end
	if profile.amber < item.cost then
		Remotes.Notify:FireClient(player, "Te faltan {n} de Ámbar", { n = item.cost - profile.amber })
		return false
	end
	PlayerData.update(player, function(current)
		current.amber -= item.cost
		local arena = current.arena
		arena.owned = if typeof(arena.owned) == "table" then arena.owned else {}
		arena.owned[gearId] = true
		loadoutOf(arena, item.role)[item.slot] = gearId
	end)
	task.spawn(PlayerData.saveNow, player)
	Analytics.amber(player, "Sink", item.cost, profile.amber, gearId)
	Remotes.Notify:FireClient(player, "Comprado y puesto: {icon} {name}", { icon = item.icon, name = { item.name } })
	return true
end

-- Pone "gearId" en su ranura, o quita lo de "slot" de "roleId" (vuelve a lo básico) si "gearId" es
-- nil. Devuelve true si cambió algo.
function ArenaShop.equip(player: Player, roleId: string, slot: string, gearId: string?): boolean
	local profile = PlayerData.get(player)
	if not (profile and Roles[roleId] and table.find(ArenaGear.SLOTS, slot :: any)) then
		return false
	end
	if gearId then
		local item = ArenaGear.items[gearId]
		local owned = profile.arena.owned
		if not (item and item.role == roleId and item.slot == slot) then
			return false
		end
		if not (typeof(owned) == "table" and owned[gearId]) then
			return false
		end
	end
	PlayerData.update(player, function(current)
		loadoutOf(current.arena, roleId)[slot] = gearId :: any
	end)
	return true
end

-- Conecta los remotos. "canChange(player)": si ahora se puede cambiar el equipo (en Dunas, solo antes
-- de la partida); "onChanged(player)": se ha comprado o cambiado algo (para recalcular sus ventajas).
function ArenaShop.start(canChange: (player: Player) -> boolean, onChanged: (player: Player) -> ())
	Remotes.ArenaBuyGear.OnServerEvent:Connect(function(player: Player, gearId: any)
		if typeof(gearId) ~= "string" or not canRequest(player) then
			return
		end
		if not canChange(player) then
			Remotes.Notify:FireClient(player, "El equipo se cambia antes de la partida")
			return
		end
		if ArenaShop.buy(player, gearId) then
			onChanged(player)
		end
	end)
	Remotes.ArenaEquipGear.OnServerEvent:Connect(function(player: Player, roleId: any, slot: any, gearId: any)
		if typeof(roleId) ~= "string" or typeof(slot) ~= "string" or not canRequest(player) then
			return
		end
		if not canChange(player) then
			Remotes.Notify:FireClient(player, "El equipo se cambia antes de la partida")
			return
		end
		local id = if typeof(gearId) == "string" and gearId ~= "" then gearId else nil
		if ArenaShop.equip(player, roleId, slot, id) then
			onChanged(player)
		end
	end)
end

return ArenaShop
