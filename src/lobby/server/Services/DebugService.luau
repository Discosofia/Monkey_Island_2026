--!strict
-- Órdenes del panel de pruebas en el Lobby (solo Studio; en el juego publicado se ignoran). Algunas
-- aceptan un segundo valor desde MCP (Remotes.DebugCommand:FireServer("GrantCosmetic", "GoldenTrail")).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Purchases = require(ServerScriptService.ServerShared.Purchases)
local Retention = require(ServerScriptService.ServerShared.Retention)
local Supplies = require(ServerScriptService.ServerShared.Supplies)

local DebugService = {}

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
	-- Da o quita el título que se gana al rescatarse, para ver cómo queda (no cuenta como victoria).
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
