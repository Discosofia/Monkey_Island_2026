--!strict
-- Órdenes del panel de pruebas en el Lobby (solo Studio; en el juego publicado se ignoran). Algunas
-- aceptan un segundo valor desde MCP (Remotes.DebugCommand:FireServer("GrantCosmetic", "GoldenTrail")).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Admin = require(ServerScriptService.ServerShared.Admin)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local GearShowcase = require(ServerScriptService.ServerShared.GearShowcase)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Purchases = require(ServerScriptService.ServerShared.Purchases)
local Retention = require(ServerScriptService.ServerShared.Retention)
local SeasonPass = require(ServerScriptService.ServerShared.SeasonPass)
local SeasonRules = require(ReplicatedStorage.Shared.SeasonPass)
local Supplies = require(ServerScriptService.ServerShared.Supplies)

local DebugService = {}

-- "SeasonShift": días que se adelanta el reloj del pase en cada pulsación y a partir de cuántos vuelve
-- a 0 (pasada la temporada y su descanso).
local SEASON_SHIFT_STEP = 7
local SEASON_SHIFT_MAX = 45

-- Rareza del próximo huevo de prueba ("GrantEgg").
local DEBUG_EGG_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local debugEggIndex = 0

-- Producto de ejemplo para la compra de prueba mientras no haya ninguno de verdad: da la estela de
-- la selva guardada en el perfil (como un cosmético suelto de la tienda).
local SAMPLE_PRODUCT = "Prueba.JungleTrail"
local debugProductIndex = 0
local debugCosmeticIndex = 0
local debugReceiptCount = 0
-- Último recibo de prueba de cada jugador ("RepeatReceipt" lo reenvía).
local lastReceipt: { [Player]: { key: string, id: string } } = {}

local function receiptCount(player: Player): number
	local profile = PlayerData.get(player)
	local receipts = if profile then profile.purchases.receipts else nil
	return if typeof(receipts) == "table" then #receipts else 0
end

local function sendReceipt(player: Player, key: string, purchaseId: string)
	lastReceipt[player] = { key = key, id = purchaseId }
	local before = receiptCount(player)
	local decision = Purchases.debugPurchase(player, key, purchaseId)
	local after = receiptCount(player)
	local verdict = if decision ~= Enum.ProductPurchaseDecision.PurchaseGranted
		then "sin entregar (NotProcessedYet)"
		elseif after > before then "entregado"
		else "ya estaba entregado (no se da dos veces)"
	Remotes.Notify:FireClient(player, `🧾 {key} ({purchaseId}): {verdict}. Recibos apuntados: {after}`)
end

local COMMANDS: { [string]: (player: Player, arg: any) -> () } = {
	Guide = function(player)
		PlayerData.update(player, function(profile)
			profile.lobbyGuideDone = false
			profile.combatGuideDone = false
		end)
	end,
	Amber = function(player)
		PlayerData.update(player, function(profile)
			profile.amber += 500
		end)
	end,
	RoleXp = function(player)
		PlayerData.update(player, function(profile)
			local role = Progression.validRole(profile.selectedRole)
			profile.roleXp[role] = (profile.roleXp[role] or 0) + 300
		end)
	end,
	-- Todo lo que se puede tener (solo Studio, panel de pruebas): todos los cosméticos, emotes
	-- incluidos, todas las mascotas y todas las monturas, guardados en el perfil del que lo pulsa
	-- (ServerShared/Admin.grantAll; en el juego publicado lo hace el panel de administradores).
	UnlockAll = function(player)
		Admin.grantAll(player)
		Remotes.Notify:FireClient(player, "🔓 Desbloqueado todo: cosméticos, emotes, mascotas y monturas")
	end,
	-- Da la montura de prueba (la primera de Data/Mounts) y la lleva puesta (Fase 11).
	Mount = function(player)
		local mountId = next(Mounts) :: string
		PlayerData.update(player, function(current)
			current.mounts[mountId] = math.max(current.mounts[mountId] or 0, 1)
			current.activeMount = mountId
		end)
		Remotes.Notify:FireClient(
			player,
			`Montura de prueba: {Mounts[mountId].icon} {Mounts[mountId].name} (presiona N)`
		)
	end,
	-- Pasa a la siguiente mascota y la lleva puesta (se la da si no la tenía).
	Pet = function(player)
		local profile = PlayerData.get(player)
		if not profile then
			return
		end
		local petId = PetRoll.after(if profile.activePet ~= "" then profile.activePet else nil)
		PlayerData.update(player, function(current)
			if (current.pets[petId] or 0) <= 0 then
				current.pets[petId] = 1
			end
			current.activePet = petId
		end)
		Remotes.Notify:FireClient(player, `🐾 Mascota de prueba: {Pets[petId].icon} {Pets[petId].name}`)
	end,
	-- Un huevo como los de la Isla, cada vez de la rareza siguiente (al nido, la mochila o pendiente).
	GrantEgg = function(player)
		debugEggIndex = debugEggIndex % #DEBUG_EGG_RARITIES + 1
		local rarity = DEBUG_EGG_RARITIES[debugEggIndex]
		Remotes.Notify:FireClient(player, `🥚 Huevo de prueba ({rarity}): {Eggs.grant(player, rarity) or "?"}`)
	end,
	EggReady = function(player)
		if not Eggs.makeReady(player) then
			Remotes.Notify:FireClient(player, "No hay huevo en el nido")
		end
	end,
	-- Provisiones como las del calendario: llegan al empezar la siguiente partida en la Isla.
	Supplies = function(player)
		Supplies.add(player, { Banana = 5, Bandage = 2, Antidote = 1 })
	end,
	-- Como si el último premio del calendario se hubiera cobrado ayer: hoy se puede cobrar otro.
	NextDay = function(player)
		Retention.debugNextDay(player)
		Remotes.Notify:FireClient(player, "📅 Día siguiente: ya puedes cobrar el premio del calendario")
	end,
	-- Cumple las misiones del día o las de la semana (se entregan ya, con su XP de pase).
	Missions = function(player)
		Retention.debugCompleteMissions(player)
	end,
	WeeklyMissions = function(player)
		Retention.debugCompleteMissions(player, true)
	end,
	-- Como si las semanales fueran de la semana pasada: tocan otras 5 y vuelve el cambio semanal.
	NextWeek = function(player)
		Retention.debugNextWeek(player)
		Remotes.Notify:FireClient(player, "📆 Semana siguiente: semanales nuevas")
	end,
	-- Da o quita el título que se gana al rescatarse, para ver cómo queda (no cuenta como victoria).
	-- Todas las armaduras de cada rol, con su arma del mismo nivel, en copias del personaje.
	GearShowcase = GearShowcase.toggle,
	-- Mejor equipo guardado del rol al grado siguiente (0–4), para ver cómo se luce.
	BestGear = function(player)
		local grade = CosmeticsServer.debugNextBestGear(player)
		Remotes.Notify:FireClient(
			player,
			if grade > 0 then `🛡️ Equipo lucido: nivel {grade}` else "🛡️ Equipo lucido: ninguno"
		)
	end,
	SurvivorTitle = function(player)
		local has = CosmeticsServer.debugToggle(player, "TitleSurvivor")
		Remotes.Notify:FireClient(
			player,
			if has then "🏝️ Título de prueba: lo tienes" else "🏝️ Título de prueba: quitado"
		)
	end,
	-- Da o quita el cosmético siguiente (por orden), o el que se pida, guardado en el perfil.
	GrantCosmetic = function(player, arg)
		local ids = {}
		for cosmeticId in Cosmetics do
			table.insert(ids, cosmeticId)
		end
		table.sort(ids, function(a, b)
			return Cosmetics[a].order < Cosmetics[b].order
		end)
		local cosmeticId = if typeof(arg) == "string" and Cosmetics[arg] then arg else nil
		if not cosmeticId then
			debugCosmeticIndex = debugCosmeticIndex % #ids + 1
			cosmeticId = ids[debugCosmeticIndex]
		end
		local has = CosmeticsServer.debugToggle(player, cosmeticId)
		local cosmetic = Cosmetics[cosmeticId]
		Remotes.Notify:FireClient(
			player,
			`🎁 {cosmetic.icon} {cosmetic.name}: {if has then "lo tienes" else "quitado"}`
		)
	end,
	-- Compra de prueba de un Developer Product (el siguiente registrado, o el que se pida) por la misma
	-- entrega que un recibo de verdad, con un recibo nuevo.
	FakePurchase = function(player, arg)
		local keys = Purchases.keys()
		local key = if typeof(arg) == "string" and table.find(keys, arg) then arg else nil
		if not key then
			debugProductIndex = debugProductIndex % #keys + 1
			key = keys[debugProductIndex]
		end
		debugReceiptCount += 1
		sendReceipt(player, key, `prueba-{player.UserId}-{os.time()}-{debugReceiptCount}`)
	end,
	-- Reenvía el último recibo de prueba: tiene que decir que ya estaba entregado.
	RepeatReceipt = function(player)
		local last = lastReceipt[player]
		if last then
			sendReceipt(player, last.key, last.id)
		else
			Remotes.Notify:FireClient(player, "🧾 Aún no hay ninguna compra de prueba")
		end
	end,
	-- Pase de temporada: XP (500 o la que se pida), hasta el siguiente nivel y premium sí/no.
	PassXp = function(player, arg)
		SeasonPass.debugAddXp(player, if typeof(arg) == "number" then arg else 500)
	end,
	PassLevel = function(player)
		SeasonPass.debugNextLevel(player)
	end,
	PassPremium = function(player)
		local premium = SeasonPass.debugTogglePremium(player)
		Remotes.Notify:FireClient(
			player,
			if premium then "🌋 Premium de prueba: la tienes" else "🌋 Premium quitada"
		)
	end,
	-- Adelanta el reloj del pase SEASON_SHIFT_STEP días (o los que se pidan) para ver la última semana,
	-- el descanso y el cierre de la temporada. Pasado SEASON_SHIFT_MAX vuelve a hoy.
	SeasonShift = function(player, arg)
		local shift = ReplicatedStorage:GetAttribute("DebugSeasonShift")
		local days = (if typeof(shift) == "number" then shift else 0) / 86400 + SEASON_SHIFT_STEP
		if typeof(arg) == "number" then
			days = arg
		elseif days > SEASON_SHIFT_MAX then
			days = 0
		end
		ReplicatedStorage:SetAttribute("DebugSeasonShift", days * 86400)
		for _, other in Players:GetPlayers() do
			task.spawn(SeasonPass.refresh, other)
		end
		local info = SeasonRules.info(SeasonRules.now())
		local phase = if info.phase == "Active"
			then `día {info.day}{if info.lastWeek then " (última semana)" else ""}`
			elseif info.phase == "Rest" then "descanso"
			else "sin temporada"
		Remotes.Notify:FireClient(player, `📆 Reloj del pase: +{days} días → {phase}`)
	end,
	-- Adelanta un día (o los que se pidan) el reloj de las tiendas de cosméticos (Shared/CosmeticShop):
	-- otra oferta en Ámbar y, cada 7, otra en Robux. Con 0 vuelve a hoy.
	ShopNextDay = function(player, arg)
		local shift = ReplicatedStorage:GetAttribute("DebugShopShift")
		local days = if typeof(arg) == "number"
			then arg
			else (if typeof(shift) == "number" then shift else 0) / 86400 + 1
		ReplicatedStorage:SetAttribute("DebugShopShift", days * 86400)
		Remotes.Notify:FireClient(player, `🛒 Reloj de las tiendas: +{days} días`)
	end,
	-- Adelanta una hora el reloj de los huevos de este servidor (Shared/EggIncubation.now).
	ClockHour = function(player)
		local shift = ReplicatedStorage:GetAttribute("DebugClockShift")
		local hours = (if typeof(shift) == "number" then shift else 0) / 3600 + 1
		ReplicatedStorage:SetAttribute("DebugClockShift", hours * 3600)
		Remotes.Notify:FireClient(player, `⏩ Reloj de los huevos: +{hours} h`)
	end,
}

function DebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Purchases.register(SAMPLE_PRODUCT, 0, {
		name = "🌿 Estela de la selva (compra de prueba)",
		grant = function(profile)
			profile.ownedCosmetics.JungleTrail = true
		end,
		after = function(player)
			player:SetAttribute("Cosmetic_JungleTrail", true)
		end,
	})
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any, arg: any)
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player, arg)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastReceipt[player] = nil
	end)
end

return DebugService
