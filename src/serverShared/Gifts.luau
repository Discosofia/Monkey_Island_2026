--!strict
-- Regalos (T3, 26-10-2026), en el Lobby, la Isla y Dunas: un jugador le compra a otro del servidor un
-- cosmético de Robux suelto (Data/Cosmetics con "source.productId") que aún no tiene. Solo cosméticos.
--
--   1. Remotes.RequestGift (cosmético, UserId): se comprueba que el otro está, que no lo tiene y que
--      hay producto de regalo de su precio (Config.Shop.GiftProducts). Se apunta el encargo en el
--      perfil del que paga ("purchases.giftIntents", uno por producto), se guarda y se abre la compra
--      por ServerShared/Purchases (recibo idempotente en el perfil del que paga).
--   2. Al cobrar, "grant" pasa el encargo a "purchases.giftOutbox" con el id del recibo.
--   3. "flush" entrega lo que haya en esa bandeja: si el otro está en este servidor, a su perfil; si
--      no, a su buzón (DataStore Config.Data.GiftStoreName, clave "g_<userId>") y le avisa por
--      MessagingService por si está en otro servidor. Lo entregado sale de la bandeja; lo que falla
--      se reintenta al volver a entrar el que paga.
--   4. "claim" vacía el buzón al entrar (y al llegar el aviso): da cada regalo una sola vez (los ids
--      recibidos van en "purchases.giftsReceived"), guarda y solo entonces lo borra del buzón.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticsServer = require(script.Parent.CosmeticsServer)
local PlayerData = require(script.Parent.PlayerData)
local Purchases = require(script.Parent.Purchases)
local RequestCooldown = require(script.Parent.RequestCooldown)

local TOPIC = "Gifts"

type Entry = { id: string, cosmetic: string, to: number, toName: string, from: string }

local Gifts = {}

local canRequest = RequestCooldown.new(2)
-- Jugadores con una entrega o un buzón en marcha (para no hacer dos a la vez).
local flushing: { [Player]: boolean } = {}
local claiming: { [Player]: boolean } = {}
local store: DataStore? = nil

local function getStore(): DataStore?
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.Data.GiftStoreName)
		end)
		store = if ok then result else nil
	end
	return store
end

local function listOf(purchases: { [string]: any }, field: string): { any }
	if typeof(purchases[field]) ~= "table" then
		purchases[field] = {}
	end
	return purchases[field]
end

-- Producto de regalo del precio del cosmético (nil si no es de Robux suelto o no hay de ese precio).
local function productFor(cosmeticId: string): string?
	local cosmetic = Cosmetics[cosmeticId]
	if not (cosmetic and cosmetic.source.productId) then
		return nil
	end
	for key, product in Config.Shop.GiftProducts do
		if product.price == cosmetic.source.price then
			return key
		end
	end
	return nil
end

local function label(cosmeticId: string): string
	local cosmetic = Cosmetics[cosmeticId]
	return `{cosmetic.icon} {cosmetic.name}`
end

-- Da el regalo "id" a quien está en este servidor (una sola vez). Devuelve true si ya es suyo.
local function giveTo(recipient: Player, id: string, cosmeticId: string, from: string): boolean
	local profile = PlayerData.get(recipient)
	if not profile then
		return false
	end
	local received = listOf(profile.purchases, "giftsReceived")
	if table.find(received, id) then
		return true
	end
	local isNew = CosmeticsServer.grant(recipient, cosmeticId)
	PlayerData.update(recipient, function(current)
		local list = listOf(current.purchases, "giftsReceived")
		table.insert(list, id)
		while #list > Config.Shop.ReceiptHistory do
			table.remove(list, 1)
		end
	end)
	Remotes.Notify:FireClient(
		recipient,
		if isNew
			then `🎁 ¡{from} te regaló {label(cosmeticId)}! Está en tu 👕 Armario`
			else `🎁 {from} te regaló {label(cosmeticId)} (ya lo tenías)`
	)
	return true
end

-- Deja el regalo en el buzón de quien no está en este servidor y le avisa si está en otro.
local function mail(entry: Entry): boolean
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local ok, err = pcall(function()
		dataStore:UpdateAsync(`g_{entry.to}`, function(current: any)
			local list = if typeof(current) == "table" then current else {}
			for _, stored in list do
				if typeof(stored) == "table" and stored.id == entry.id then
					return list
				end
			end
			table.insert(list, { id = entry.id, cosmetic = entry.cosmetic, from = entry.from })
			return list
		end)
	end)
	if not ok then
		warn(`[Gifts] No se pudo dejar el regalo {entry.id} para {entry.to}: {err}`)
		return false
	end
	pcall(function()
		MessagingService:PublishAsync(TOPIC, entry.to)
	end)
	return true
end

-- Entrega lo que el que paga tenga en su bandeja de salida. Puede tardar: desde un hilo.
function Gifts.flush(payer: Player)
	local profile = PlayerData.get(payer)
	if flushing[payer] or not profile then
		return
	end
	flushing[payer] = true
	local done = false
	for _, entry: Entry in table.clone(listOf(profile.purchases, "giftOutbox")) do
		if not (typeof(entry) == "table" and Cosmetics[entry.cosmetic]) then
			continue
		end
		local recipient = Players:GetPlayerByUserId(entry.to)
		local delivered = if recipient and PlayerData.get(recipient)
			then giveTo(recipient, entry.id, entry.cosmetic, entry.from)
			else mail(entry)
		if delivered then
			if recipient then
				task.spawn(PlayerData.saveNow, recipient)
			end
			PlayerData.update(payer, function(current)
				local outbox = listOf(current.purchases, "giftOutbox")
				for index, stored in outbox do
					if stored.id == entry.id then
						table.remove(outbox, index)
						break
					end
				end
			end)
			done = true
			Remotes.Notify:FireClient(
				payer,
				`🎁 Le regalaste {label(entry.cosmetic)} a {entry.toName}{if recipient
					then ""
					else ": lo recibirá al entrar"}`
			)
		end
	end
	if done then
		PlayerData.saveNow(payer)
	end
	flushing[payer] = nil
end

-- Vacía el buzón del jugador: da cada regalo, guarda y lo borra del buzón. Puede tardar: desde un hilo.
function Gifts.claim(player: Player)
	local dataStore = getStore()
	if claiming[player] or not (dataStore and PlayerData.get(player)) then
		return
	end
	claiming[player] = true
	local ok, list = pcall(function()
		return dataStore:GetAsync(`g_{player.UserId}`)
	end)
	local given: { string } = {}
	if ok and typeof(list) == "table" then
		for _, stored in list do
			if
				typeof(stored) == "table"
				and typeof(stored.id) == "string"
				and Cosmetics[stored.cosmetic]
				and giveTo(player, stored.id, stored.cosmetic, tostring(stored.from))
			then
				table.insert(given, stored.id)
			end
		end
	end
	-- Solo se borra del buzón lo que ya quedó guardado en el perfil.
	if #given > 0 and PlayerData.saveNow(player) then
		pcall(function()
			dataStore:UpdateAsync(`g_{player.UserId}`, function(current: any)
				if typeof(current) ~= "table" then
					return nil
				end
				local left = {}
				for _, stored in current do
					if not (typeof(stored) == "table" and table.find(given, stored.id)) then
						table.insert(left, stored)
					end
				end
				return left
			end)
		end)
	end
	claiming[player] = nil
end

-- ¿Puede "payer" regalar "cosmeticId" a "recipient" ahora? Si no, el motivo.
local function check(payer: Player, cosmeticId: string, recipient: Player?): (boolean, string?)
	if not recipient or recipient == payer or not PlayerData.get(recipient) then
		return false, "🎁 Ese jugador ya no está en el servidor"
	end
	if recipient:GetAttribute(`Cosmetic_{cosmeticId}`) == true then
		return false, `🎁 {recipient.DisplayName} ya tiene {label(cosmeticId)}`
	end
	return true, nil
end

local function onRequest(payer: Player, cosmeticId: any, userId: any)
	if typeof(cosmeticId) ~= "string" or typeof(userId) ~= "number" or not canRequest(payer) then
		return
	end
	local key = productFor(cosmeticId)
	local profile = PlayerData.get(payer)
	if not (key and profile) then
		return
	end
	local recipient = Players:GetPlayerByUserId(userId)
	local ok, reason = check(payer, cosmeticId, recipient)
	if not (ok and recipient) then
		Remotes.Notify:FireClient(payer, reason or "🎁 No se puede regalar ahora")
		return
	end
	PlayerData.update(payer, function(current)
		if typeof(current.purchases.giftIntents) ~= "table" then
			current.purchases.giftIntents = {}
		end
		current.purchases.giftIntents[key] =
			{ cosmetic = cosmeticId, to = recipient.UserId, toName = recipient.DisplayName, at = os.time() }
	end)
	-- El encargo queda guardado antes de cobrar: si el recibo llega en otro servidor, sabe qué dar.
	PlayerData.saveNow(payer)
	Purchases.prompt(payer, key)
end

local function registerProducts()
	for key, product in Config.Shop.GiftProducts do
		local function intentOf(profile: PlayerData.Profile): { [string]: any }?
			local intents = profile.purchases.giftIntents
			local intent = if typeof(intents) == "table" then intents[key] else nil
			return if typeof(intent) == "table" and Cosmetics[intent.cosmetic] then intent else nil
		end
		Purchases.register(key, product.productId, {
			name = `🎁 Regalo · {product.price} R$`,
			grant = function(profile, player, purchaseId)
				local intent = intentOf(profile)
				if not intent then
					warn(`[Gifts] Recibo {purchaseId} de {player.Name} sin encargo de regalo ({key})`)
					return
				end
				profile.purchases.giftIntents[key] = nil
				table.insert(listOf(profile.purchases, "giftOutbox"), {
					id = purchaseId,
					cosmetic = intent.cosmetic,
					to = intent.to,
					toName = intent.toName,
					from = player.DisplayName,
				})
			end,
			after = function(player)
				Gifts.flush(player)
			end,
			available = function(profile, player)
				local intent = intentOf(profile)
				if not intent then
					return false, "🎁 Elige a quién regalarlo"
				end
				return check(player, intent.cosmetic, Players:GetPlayerByUserId(intent.to))
			end,
		})
	end
end

function Gifts.start()
	registerProducts()
	Remotes.RequestGift.OnServerEvent:Connect(onRequest)
	local function onPlayer(player: Player)
		task.spawn(function()
			if PlayerData.waitFor(player) then
				Gifts.flush(player)
				Gifts.claim(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		flushing[player] = nil
		claiming[player] = nil
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local player = if typeof(message.Data) == "number" then Players:GetPlayerByUserId(message.Data) else nil
				if player then
					Gifts.claim(player)
				end
			end)
		end)
	end)
end

return Gifts
