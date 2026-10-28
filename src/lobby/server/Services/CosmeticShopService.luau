--!strict
-- Tiendas de cosméticos del Lobby (Fase 9, G10; la rotación está en Shared/CosmeticShop):
--   - Fija la oferta de cada jugador la primera vez que la mira en el día (Ámbar) o en la semana
--     (Robux) y la guarda en el perfil ("cosmeticShop"), para que comprar uno no destape otro.
--   - La publica en el atributo "CosmeticShop" del jugador (JSON: day, amber, week, robux y "bought",
--     los de la oferta que ya tiene guardados en el perfil), que leen la ventana Tienda y el Armario.
--     Se mira cada minuto por si cambia el día con el jugador dentro.
--   - Vende con Ámbar lo de su oferta de hoy (Remotes.BuyCosmetic). Lo de Robux lo entrega
--     ServerShared/CosmeticsServer (Developer Product "Cosmetic.<id>"); aquí solo se vuelve a publicar
--     (CosmeticsServer.onGranted).
--   - En Studio, "DebugShopShift" (panel de pruebas, "📅 Tienda: día siguiente") adelanta su reloj.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticShop = require(ReplicatedStorage.Shared.CosmeticShop)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)

local CosmeticShopService = {}

local canRequest = RequestCooldown.new(0.5)
-- Jugadores con la publicación pendiente (se juntan las entregas de un mismo instante).
local queued: { [Player]: boolean } = {}

local function publish(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local state = CosmeticShop.normalize(profile.cosmeticShop, CosmeticShop.seasonAt(CosmeticShop.now()))
	local bought = {}
	for _, list in { state.amber, state.robux } do
		for _, cosmeticId in list do
			if profile.ownedCosmetics[cosmeticId] then
				table.insert(bought, cosmeticId)
			end
		end
	end
	player:SetAttribute(
		"CosmeticShop",
		HttpService:JSONEncode({
			day = state.day,
			amber = state.amber,
			week = state.week,
			robux = state.robux,
			bought = bought,
		})
	)
end

local function queuePublish(player: Player)
	if queued[player] then
		return
	end
	queued[player] = true
	task.defer(function()
		queued[player] = nil
		if player.Parent then
			publish(player)
		end
	end)
end

-- Rehace la oferta que haya caducado (otro día, otra semana) y la publica.
function CosmeticShopService.refresh(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local now = CosmeticShop.now()
	local seasonId = CosmeticShop.seasonAt(now)
	local day, week = CosmeticShop.period(now)
	local state = CosmeticShop.normalize(profile.cosmeticShop, seasonId)
	local function owns(cosmeticId: string): boolean
		return profile.ownedCosmetics[cosmeticId] == true
	end
	local changed = false
	if state.day ~= day then
		state.day = day
		state.amber = CosmeticShop.offer("Amber", day, owns, seasonId)
		changed = true
	end
	if state.week ~= week then
		state.week = week
		state.robux = CosmeticShop.offer("Robux", week, owns, seasonId)
		changed = true
	end
	if changed then
		PlayerData.update(player, function(current)
			current.cosmeticShop = state :: any
		end)
	end
	publish(player)
end

local function onBuy(player: Player, cosmeticId: any)
	if typeof(cosmeticId) ~= "string" or not Cosmetics[cosmeticId] or not canRequest(player) then
		return
	end
	CosmeticShopService.refresh(player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local cosmetic = Cosmetics[cosmeticId]
	local state = CosmeticShop.normalize(profile.cosmeticShop, CosmeticShop.seasonAt(CosmeticShop.now()))
	local price = CosmeticShop.price(cosmeticId, "Amber")
	if not (price and table.find(state.amber, cosmeticId)) then
		Remotes.Notify:FireClient(player, "Eso ya no está en la tienda de hoy")
		return
	end
	if profile.ownedCosmetics[cosmeticId] then
		Remotes.Notify:FireClient(player, "Ya tienes {icon} {name}", { icon = cosmetic.icon, name = { cosmetic.name } })
		return
	end
	if profile.amber < price then
		Remotes.Notify:FireClient(player, "Te faltan {n} de Ámbar", { n = price - profile.amber })
		return
	end
	PlayerData.update(player, function(current)
		current.amber -= price
		current.ownedCosmetics[cosmeticId] = true
	end)
	CosmeticsServer.refresh(player)
	task.spawn(PlayerData.saveNow, player)
	Analytics.amber(player, "Sink", price, profile.amber, `Cosmetic.{cosmeticId}`)
	Remotes.Notify:FireClient(
		player,
		"Comprado: {icon} {name}. Póntelo en el 👕 Armario",
		{ icon = cosmetic.icon, name = { cosmetic.name } }
	)
	publish(player)
end

function CosmeticShopService:Start()
	Remotes.BuyCosmetic.OnServerEvent:Connect(onBuy)
	-- Lo comprado con Robux (o ganado) llega por ServerShared/CosmeticsServer.
	CosmeticsServer.onGranted(queuePublish)
	local function onPlayer(player: Player)
		if PlayerData.waitFor(player) then
			CosmeticShopService.refresh(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		queued[player] = nil
	end)
	local function refreshAll()
		for _, player in Players:GetPlayers() do
			task.spawn(CosmeticShopService.refresh, player)
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("DebugShopShift"):Connect(refreshAll)
	task.spawn(function()
		while true do
			task.wait(60)
			refreshAll()
		end
	end)
end

return CosmeticShopService
