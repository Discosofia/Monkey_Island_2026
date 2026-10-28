--!strict
-- Compras con Developer Products (Fase 9), en el Lobby, la Isla y Dunas: Roblox solo cobra, el juego
-- entrega. Hay un único MarketplaceService.ProcessReceipt por place (Purchases.start, desde el
-- PurchaseService de cada uno) que busca quién entrega cada producto. Cada sistema registra los suyos
-- con Purchases.register (los cosméticos sueltos, CosmeticsServer; el pase, ServerShared/SeasonPass).
--
-- Orden seguro para no perder ni duplicar compras (docs de Roblox):
--   1. Sin jugador en el servidor o sin perfil cargado → NotProcessedYet (Roblox lo reintenta).
--   2. Recibo ya apuntado en el perfil → PurchaseGranted (ya se entregó).
--   3. Entregar dentro de PlayerData.update y apuntar el recibo (los últimos Config.Shop.ReceiptHistory).
--   4. Guardar ya (PlayerData.saveNow) y solo entonces devolver PurchaseGranted. Si no se pudo
--      guardar, NotProcessedYet: el reintento encuentra el recibo y vuelve a intentar guardar.
-- En Studio sin acceso a DataStore (datos temporales) se entrega igual, para probar.
--
-- No volver a pagar lo que ya tienes (26-10-2026): Roblox no deja rechazar un recibo ya cobrado, así
-- que la defensa es no pedir el pago. El cliente no abre la ventana de compra: pide la compra con
-- Remotes.RequestPurchase y el servidor la abre (Purchases.prompt) solo si "available" dice que se
-- puede entregar y no hay otra abierta. Si aun así llega un recibo de algo que ya tiene, el recibo se
-- apunta y no se da nada (nunca Ámbar a cambio: reglas de pago).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Analytics = require(script.Parent.Analytics)
local PlayerData = require(script.Parent.PlayerData)
local RequestCooldown = require(script.Parent.RequestCooldown)

export type Handler = {
	-- Nombre para el aviso al jugador: una frase de Shared/Strings como argumento, { "texto", args? }
	-- ({ Strings.later("⭐ Un nivel del pase") }), que el cliente traduce.
	name: any,
	-- Entrega en el perfil. Corre dentro de PlayerData.update: sin esperas y sin fallar (si no hay
	-- nada que dar, que no dé nada; el recibo se apunta igual). "purchaseId" es el del recibo.
	grant: (profile: PlayerData.Profile, player: Player, purchaseId: string) -> (),
	-- Después de guardar: atributos, avisos o efectos (opcional).
	after: ((player: Player) -> ())?,
	-- ¿Se puede comprar ahora? Si no, el motivo para el aviso: un texto ya marcado con Strings.later o
	-- { "texto", args } ("Ya lo tienes"). Sin él, siempre.
	available: ((profile: PlayerData.Profile, player: Player) -> (boolean, any?))?,
}

local Purchases = {}

local handlers: { [string]: Handler } = {}
local keyByProduct: { [number]: string } = {}
local productByKey: { [string]: number } = {}
-- Cuándo abrió cada jugador la ventana de compra de Roblox (hasta PromptProductPurchaseFinished o
-- Config.Shop.PromptTimeoutSeconds).
local prompting: { [Player]: number } = {}
local canRequest = RequestCooldown.new(1)
local order: { string } = {}
-- Recibos que se están entregando ahora (Roblox puede volver a llamar mientras se guarda).
local inFlight: { [string]: boolean } = {}
-- Recibos ya entregados pero sin guardar: el reintento solo vuelve a guardar.
local unsaved: { [string]: boolean } = {}

local function receiptsOf(profile: PlayerData.Profile): { string }
	local purchases = profile.purchases
	if typeof(purchases.receipts) ~= "table" then
		purchases.receipts = {}
	end
	return purchases.receipts
end

local function canGrant(player: Player): boolean
	return PlayerData.isSaveable(player) or RunService:IsStudio()
end

local function persist(player: Player): boolean
	if not PlayerData.isSaveable(player) then
		return RunService:IsStudio()
	end
	return PlayerData.saveNow(player)
end

-- Entrega "key" a "player" con el recibo "purchaseId". Lo usan ProcessReceipt y las compras de prueba.
local function grantReceipt(player: Player, key: string, purchaseId: string): Enum.ProductPurchaseDecision
	local handler = handlers[key]
	local profile = PlayerData.get(player)
	if not (handler and profile) or inFlight[purchaseId] or not canGrant(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(receiptsOf(profile), purchaseId) then
		if not unsaved[purchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		inFlight[purchaseId] = true
		local saved = persist(player)
		inFlight[purchaseId] = nil
		if saved then
			unsaved[purchaseId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	inFlight[purchaseId] = true
	local ok, err = pcall(function()
		PlayerData.update(player, function(current)
			handler.grant(current, player, purchaseId)
			local receipts = receiptsOf(current)
			table.insert(receipts, purchaseId)
			while #receipts > Config.Shop.ReceiptHistory do
				table.remove(receipts, 1)
			end
		end)
	end)
	if not ok then
		inFlight[purchaseId] = nil
		warn(`[Purchases] No se pudo entregar {key} a {player.Name}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	unsaved[purchaseId] = true
	local saved = persist(player)
	inFlight[purchaseId] = nil
	if not saved then
		warn(`[Purchases] {key} entregado a {player.Name} pero sin guardar; se reintentará`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	unsaved[purchaseId] = nil
	Analytics.event(player, "Purchase", 1, { key })
	Remotes.Notify:FireClient(player, "¡Gracias! Ya tienes: {name}", { name = handler.name })
	local after = handler.after
	if after then
		task.spawn(after, player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local key = keyByProduct[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not (key and player) then
		if not key then
			warn(`[Purchases] Nadie entrega el producto {receipt.ProductId}`)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Espera a que cargue el perfil (la compra puede llegar justo al entrar al servidor).
	if not PlayerData.waitFor(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return grantReceipt(player, key, tostring(receipt.PurchaseId))
end

-- Registra quién entrega "key". "productId" es el del Creator Hub (0 = aún sin crear: solo se puede
-- comprar con la compra de prueba del panel de Studio).
function Purchases.register(key: string, productId: number, handler: Handler)
	assert(handlers[key] == nil, `Purchases: "{key}" ya está registrado`)
	handlers[key] = handler
	productByKey[key] = productId
	table.insert(order, key)
	if productId ~= 0 then
		assert(keyByProduct[productId] == nil, `Purchases: el producto {productId} ya está registrado`)
		keyByProduct[productId] = key
	end
end

-- Productos registrados, en el orden en que se registraron (para el panel de pruebas).
function Purchases.keys(): { string }
	return table.clone(order)
end

-- Compra de prueba (panel de Studio): pasa por la misma entrega que un recibo de verdad. Con el
-- mismo "purchaseId" sirve para comprobar que repetir un recibo no da dos veces.
function Purchases.debugPurchase(player: Player, key: string, purchaseId: string): Enum.ProductPurchaseDecision
	return grantReceipt(player, key, purchaseId)
end

-- ¿Puede comprar "key" ahora? Si no, el motivo (un texto o { texto, args }, como Handler.available).
function Purchases.available(player: Player, key: string): (boolean, any?)
	local handler = handlers[key]
	local profile = PlayerData.get(player)
	if not (handler and profile) then
		return false, Strings.later("La tienda aún no está lista: prueba en un momento")
	end
	local check = handler.available
	if check then
		return check(profile, player)
	end
	return true, nil
end

-- Abre la ventana de compra de "key" (o, en Studio sin id, hace una compra de prueba) si se puede
-- entregar; si no, avisa del motivo. Devuelve true si la abrió.
function Purchases.prompt(player: Player, key: string): boolean
	local ok, reason = Purchases.available(player, key)
	if not ok then
		if typeof(reason) == "table" then
			Remotes.Notify:FireClient(player, reason[1], reason[2])
		elseif reason then
			Remotes.Notify:FireClient(player, reason)
		end
		return false
	end
	local openedAt = prompting[player]
	if openedAt and os.clock() - openedAt < Config.Shop.PromptTimeoutSeconds then
		return false
	end
	local productId = productByKey[key]
	if productId == 0 then
		if RunService:IsStudio() then
			task.spawn(grantReceipt, player, key, `prueba-{player.UserId}-{os.time()}-{os.clock()}`)
			return true
		end
		Remotes.Notify:FireClient(player, "Próximamente")
		return false
	end
	prompting[player] = os.clock()
	MarketplaceService:PromptProductPurchase(player, productId)
	return true
end

function Purchases.start()
	MarketplaceService.ProcessReceipt = processReceipt
	Remotes.RequestPurchase.OnServerEvent:Connect(function(player, key)
		if typeof(key) == "string" and handlers[key] and canRequest(player) then
			Purchases.prompt(player, key)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			prompting[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		prompting[player] = nil
	end)
end

return Purchases
