--!strict
-- Pase de temporada en el servidor (Fase 9), en el Lobby, la Isla y Dunas. Las cuentas están en
-- Shared/SeasonPass y las temporadas en Data/Seasons; el progreso se guarda en el perfil ("season").
--   - addXp: suma XP de pase. Las partidas ("Match": Isla y Dunas) cuentan para el tope de hoy
--     (Config.Season.DailyMatchXpCap) y dan un extra si hay un amigo de Roblox en el servidor
--     (trackFriends); las misiones ("Mission", ServerShared/Retention) no tienen tope. La última
--     semana de la temporada todo vale ×LastWeekMultiplier. En el descanso no se gana XP.
--   - Reclamar (Remotes.ClaimPass, desde la ventana del pase del Lobby): un premio o todos. Lo que no
--     es cosmético lo entrega ServerShared/Retention.grant; los cosméticos, CosmeticsServer.
--   - Al terminar una temporada se entrega solo lo que no se reclamó; al empezar otra, el progreso
--     empieza de cero (refresh, al entrar y cada minuto).
--   - Compras (ServerShared/Purchases, en los tres places): la premium (entrega ya lo premium alcanzado,
--     que es todo cosmético), el pack premium + niveles y un nivel suelto. Los niveles comprados nunca
--     desbloquean lo que no es cosmético (Shared/SeasonPass.unlocked).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Pass = require(ReplicatedStorage.Shared.SeasonPass)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seasons = require(ReplicatedStorage.Shared.Data.Seasons)
local Analytics = require(script.Parent.Analytics)
local CosmeticsServer = require(script.Parent.CosmeticsServer)
local PlayerData = require(script.Parent.PlayerData)
local Purchases = require(script.Parent.Purchases)
local RequestCooldown = require(script.Parent.RequestCooldown)
local Retention = require(script.Parent.Retention)

export type Source = "Match" | "Mission"

-- Lo que ha sumado una XP (va en los resultados de la Isla y de Dunas).
export type Gain = {
	xp: number, -- sumada de verdad (con el extra de amigos y el multiplicador)
	capped: number, -- la que se quedó fuera por el tope de hoy
	friends: number, -- la del extra por jugar con amigos
	multiplier: number,
	level: number,
	levelsUp: number,
	progress: number,
	need: number,
}

local S = Config.Season

local SeasonPass = {}

local canClaim = RequestCooldown.new(0.5)
-- Amigos de Roblox de cada jugador en este servidor (solo donde se gana XP de partida).
local friendsOf: { [Player]: { [Player]: boolean } } = {}
local started = false

local function hasFriendHere(player: Player): boolean
	local friends = friendsOf[player]
	return friends ~= nil and next(friends) ~= nil
end

local function withoutCosmetic(reward: Seasons.PassReward): Config.Reward
	return { amber = reward.amber, items = reward.items, eggSeconds = reward.eggSeconds, egg = reward.egg }
end

-- Entrega un premio del pase y devuelve lo recibido, línea a línea.
local function grantReward(player: Player, reward: Seasons.PassReward): { string }
	local lines = {}
	local cosmeticId = reward.cosmetic
	if cosmeticId and Cosmetics[cosmeticId] then
		CosmeticsServer.grant(player, cosmeticId)
		local cosmetic = Cosmetics[cosmeticId]
		table.insert(lines, `{cosmetic.icon} {cosmetic.name}`)
	end
	-- Lo del pase se gana jugando: el tiempo de huevo cuenta para su tope.
	for _, line in Retention.grant(player, withoutCosmetic(reward), true, "SeasonPass") do
		table.insert(lines, line)
	end
	return lines
end

local function grantAll(player: Player, rewards: { Seasons.PassReward }): { string }
	local lines = {}
	for _, reward in rewards do
		for _, line in grantReward(player, reward) do
			table.insert(lines, line)
		end
	end
	return lines
end

-- Marca como cobrados los premios que se pueden reclamar (todos, o solo "only") y los devuelve.
local function take(
	season: Seasons.Season,
	state: Pass.State,
	only: Pass.Claim?,
	loopsToo: boolean
): { Seasons.PassReward }
	local rewards = {}
	local claims, loops = Pass.claimable(season, state)
	for _, claim in claims do
		if not only or (only.level == claim.level and only.track == claim.track) then
			local reward = Pass.reward(season, claim.level, claim.track)
			if reward then
				table.insert(if claim.track == "Free" then state.claimedFree else state.claimedPremium, claim.level)
				table.insert(rewards, reward)
			end
		end
	end
	if loopsToo then
		for _ = 1, loops do
			state.loops += 1
			table.insert(rewards, Pass.loopReward(state.loops) :: any)
		end
	end
	return rewards
end

-- ¿Hay que cerrar la temporada del perfil o empezar la nueva?
local function needsSettle(raw: any, now: number): boolean
	local state = Pass.normalize(raw)
	if state.id ~= "" and not state.closed then
		local season = Pass.find(state.id)
		if not season or now >= Pass.endsAt(season) then
			return true
		end
	end
	local info = Pass.info(now)
	return info.phase == "Active" and info.season ~= nil and state.id ~= info.season.id
end

-- Cierra la temporada del perfil si ha terminado (devuelve lo no reclamado, para entregarlo fuera del
-- update, y su nombre) y empieza la nueva si ya está en marcha.
local function settle(profile: PlayerData.Profile, now: number): ({ Seasons.PassReward }, string?)
	local state = Pass.normalize(profile.season)
	local rewards: { Seasons.PassReward } = {}
	local closedName: string? = nil
	if state.id ~= "" and not state.closed then
		local season = Pass.find(state.id)
		if not season or now >= Pass.endsAt(season) then
			if season then
				rewards = take(season, state, nil, true)
				closedName = season.name
			end
			state.closed = true
		end
	end
	local info = Pass.info(now)
	if info.phase == "Active" and info.season and state.id ~= info.season.id then
		state = Pass.normalize(nil, info.season.id)
	end
	profile.season = state :: any
	return rewards, closedName
end

-- Pone al día la temporada del jugador (al entrar, cada minuto y antes de sumar o reclamar).
function SeasonPass.refresh(player: Player)
	local profile = PlayerData.get(player)
	local now = Pass.now()
	if not (profile and needsSettle(profile.season, now)) then
		return
	end
	local rewards: { Seasons.PassReward } = {}
	local closedName: string? = nil
	PlayerData.update(player, function(current)
		rewards, closedName = settle(current, now)
	end)
	if #rewards > 0 then
		local lines = grantAll(player, rewards)
		Remotes.Notify:FireClient(
			player,
			`🌋 Terminó la temporada «{closedName}». Te llevas lo que no reclamaste: {table.concat(lines, " · ")}`
		)
	end
end

-- Suma XP de pase. Devuelve lo sumado (nil si no hay temporada en marcha o el perfil no ha cargado).
function SeasonPass.addXp(player: Player, source: Source, amount: number): Gain?
	if amount <= 0 then
		return nil
	end
	SeasonPass.refresh(player)
	local now = Pass.now()
	local info = Pass.info(now)
	local season = info.season
	if info.phase ~= "Active" or not season then
		return nil
	end
	local gain: Gain? = nil
	PlayerData.update(player, function(profile)
		local state = Pass.normalize(profile.season, season.id)
		local today = Daily.today(now)
		if state.xpDay ~= today then
			state.xpDay = today
			state.xpToday = 0
		end
		local base, capped, friends = amount, 0, 0
		if source == "Match" then
			base = math.clamp(S.DailyMatchXpCap - state.xpToday, 0, amount)
			capped = amount - base
			state.xpToday += base
			if hasFriendHere(player) then
				friends = math.round(base * S.FriendsBonus)
			end
		end
		local total = (base + friends) * info.multiplier
		local before = Pass.level(state)
		state.xp += total
		local progress, need = Pass.progress(state)
		profile.season = state :: any
		gain = {
			xp = total,
			capped = capped,
			friends = friends * info.multiplier,
			multiplier = info.multiplier,
			level = Pass.level(state),
			levelsUp = Pass.level(state) - before,
			progress = progress,
			need = need,
		}
	end)
	local result = gain
	if result and result.levelsUp > 0 then
		Remotes.Notify:FireClient(
			player,
			`{season.icon} ¡Nivel {result.level} del pase de temporada! Reclama tus premios en el Lobby`
		)
		Analytics.event(player, "SeasonLevel", result.level, { season.id })
	end
	return result
end

-- Reclama un premio (nivel y pista) o, sin nivel, todos los que haya (también los del bucle).
function SeasonPass.claim(player: Player, level: number?, track: Pass.Track?)
	SeasonPass.refresh(player)
	local rewards: { Seasons.PassReward } = {}
	PlayerData.update(player, function(profile)
		local state = Pass.normalize(profile.season)
		local season = Pass.find(state.id)
		if not season or state.closed then
			return
		end
		local only: Pass.Claim? = if level and track then { level = level, track = track } else nil
		rewards = take(season, state, only, only == nil)
		profile.season = state :: any
	end)
	if #rewards > 0 then
		Remotes.Notify:FireClient(player, `🎁 Del pase: {table.concat(grantAll(player, rewards), " · ")}`)
	end
end

-- Compra de la premium y/o niveles (dentro de PlayerData.update: sin esperas). Con la premium, lo
-- premium ya alcanzado (solo cosméticos) se entrega en el momento.
local function grantPurchase(profile: PlayerData.Profile, premium: boolean, levels: number)
	local info = Pass.info(Pass.now())
	local state = Pass.normalize(profile.season)
	if info.phase == "Active" and info.season and state.id ~= info.season.id then
		state = Pass.normalize(nil, info.season.id)
	end
	if premium then
		state.premium = true
	end
	state.bought += levels
	local season = Pass.find(state.id)
	if season and state.premium and not state.closed then
		for level = 1, S.Levels do
			local reward = Pass.reward(season, level, "Premium")
			if
				reward
				and reward.cosmetic
				and Pass.unlocked(season, state, level, "Premium")
				and not Pass.isClaimed(state, level, "Premium")
			then
				profile.ownedCosmetics[reward.cosmetic] = true
				table.insert(state.claimedPremium, level)
			end
		end
	end
	profile.season = state :: any
end

local function registerProducts()
	local products = Config.Shop.Products
	local function register(key: string, name: string, premium: boolean, levels: number)
		Purchases.register(key, products[key].productId, {
			name = name,
			grant = function(profile)
				grantPurchase(profile, premium, levels)
			end,
			after = function(player)
				CosmeticsServer.refresh(player)
			end,
		})
	end
	register("SeasonPremium", "🌋 Pase de temporada premium", true, 0)
	register("SeasonPack", `🌋 Pase premium + {products.SeasonPack.levels} niveles`, true, products.SeasonPack.levels)
	register("SeasonLevel", "⭐ Un nivel del pase", false, products.SeasonLevel.levels)
end

-- Amigos de Roblox en el servidor, para el extra de XP (en la Isla y Dunas, donde se juega).
function SeasonPass.trackFriends()
	local function onPlayer(player: Player)
		friendsOf[player] = friendsOf[player] or {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, isFriend = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok and isFriend and player.Parent and other.Parent then
					friendsOf[player][other] = true
					friendsOf[other] = friendsOf[other] or {}
					friendsOf[other][player] = true
				end
			end
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		friendsOf[player] = nil
		for _, friends in friendsOf do
			friends[player] = nil
		end
	end)
end

-- Registra los productos (llamar en el Init del servicio de cada place, antes de las compras).
function SeasonPass.init()
	registerProducts()
end

function SeasonPass.start()
	if started then
		return
	end
	started = true
	Retention.setXpHandler(function(player, xp)
		local gain = SeasonPass.addXp(player, "Mission", xp)
		if not gain then
			return nil
		end
		return `⭐ +{gain.xp} XP de pase{if gain.multiplier > 1 then ` (×{gain.multiplier} última semana)` else ""}`
	end)
	Remotes.ClaimPass.OnServerEvent:Connect(function(player: Player, level: any, track: any)
		if not canClaim(player) then
			return
		end
		local validLevel = typeof(level) == "number" and level >= 1 and level <= S.Levels and level // 1 == level
		local validTrack = track == "Free" or track == "Premium"
		if validLevel and validTrack then
			SeasonPass.claim(player, level, track)
		elseif level == nil then
			SeasonPass.claim(player, nil, nil)
		end
	end)
	local function onPlayer(player: Player)
		if PlayerData.waitFor(player) then
			SeasonPass.refresh(player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	-- Por si empieza o termina una temporada con el jugador dentro.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				task.spawn(SeasonPass.refresh, player)
			end
		end
	end)
end

-- Prueba (panel de Studio): XP sin tope ni extras (la de una partida pasa por addXp).
function SeasonPass.debugAddXp(player: Player, amount: number)
	SeasonPass.refresh(player)
	local info = Pass.info(Pass.now())
	local season = info.season
	if info.phase ~= "Active" or not season then
		Remotes.Notify:FireClient(player, "🌋 No hay temporada en marcha (prueba «Temporada +7 días»)")
		return
	end
	PlayerData.update(player, function(profile)
		local state = Pass.normalize(profile.season, season.id)
		state.xp += amount
		profile.season = state :: any
	end)
end

-- Prueba: hasta el principio del siguiente nivel ganado.
function SeasonPass.debugNextLevel(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local state = Pass.normalize(profile.season)
	local _, need = Pass.progress(state)
	local into = Pass.progress(state)
	SeasonPass.debugAddXp(player, need - into)
end

-- Prueba: pone o quita la premium sin comprarla (la entrega de lo alcanzado, como al comprar).
function SeasonPass.debugTogglePremium(player: Player): boolean
	local premium = false
	PlayerData.update(player, function(profile)
		local state = Pass.normalize(profile.season)
		if state.premium then
			state.premium = false
			profile.season = state :: any
		else
			grantPurchase(profile, true, 0)
			premium = true
		end
	end)
	CosmeticsServer.refresh(player)
	return premium
end

return SeasonPass
