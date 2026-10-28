--!strict
-- Lo que se gana al terminar una partida del Laboratorio (Config.Lab.Amber), para cada jugador que
-- puntúa (LabMatchService llama a "give" justo antes de mandar los resultados):
--   - Ámbar por el resultado (victoria, empate, derrota; en Todos contra todos, por puesto) y por las
--     bajas (con tope por partida), por el evento "Doble Ámbar". Con un tope diario propio (perfil
--     "lab.daily", aparte del de Dunas): lo que pase del tope no se cobra, y los resultados lo dicen.
--   - Estadísticas guardadas (perfil "lab.stats"), bajas por arma (perfil "lab.weaponKills", para las
--     skins de la L5b) y rankings del Laboratorio (victorias y bajas).
--   - XP del pase de temporada (Config.Season.LabXp, ServerShared/SeasonPass).
--   - Misión semanal del Laboratorio (ganar; ServerShared/Retention).
--   - Títulos al llegar a Config.Lab.WinsForTitle victorias con un bando (ServerShared/CosmeticsServer).
-- Las partidas de prueba (panel de pruebas) no dan nada: LabMatchService no llama a "give".
-- Las bajas por arma de la partida salen solo de LabRespawnService.onKnockedOut (una vez por baja real);
-- "ArenaKills" no sirve para eso porque en Todos contra todos también lo suma el modo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Leaderboards = require(ServerScriptService.ServerShared.Leaderboards)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Retention = require(ServerScriptService.ServerShared.Retention)
local SeasonPass = require(ServerScriptService.ServerShared.SeasonPass)
local LabRespawnService = require(script.Parent.LabRespawnService)

type Result = "Win" | "Tie" | "Loss"

export type Reward = {
	earned: number,
	amber: number,
	today: number,
	dailyCap: number,
	pass: SeasonPass.Gain?,
}

local LabRewardService = {}

-- Bajas de la partida en curso por jugador y arma: [userId][weaponId] = n.
local matchWeaponKills: { [number]: { [string]: number } } = {}

local function stat(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Ámbar que ha ganado "player" en esta partida (antes del tope diario). Con "place" (Todos contra todos),
-- el resultado cuenta por puesto.
local function earned(player: Player, result: Result, place: number?): number
	local amber = Config.Lab.Amber
	local fromResult = if place then (amber.Places[place] or amber.Rest) else amber[result]
	local fromKills = math.min(stat(player, "ArenaKills") * amber.PerKill, amber.MaxFromKills)
	-- Evento en vivo "Doble Ámbar" (T4b): el tope diario sigue igual.
	return (fromResult + fromKills) * LiveEvents.amberMultiplier()
end

-- Cobra hasta el tope diario y guarda las estadísticas y las bajas por arma. Devuelve lo cobrado y lo que
-- lleva hoy.
local function grant(player: Player, amount: number, result: Result, teamId: string?): (number, number)
	local granted, todayTotal = 0, 0
	local today = Daily.today(os.time())
	local kills = stat(player, "ArenaKills")
	local weaponKills = matchWeaponKills[player.UserId]
	PlayerData.update(player, function(profile)
		local lab = profile.lab
		local daily = if typeof(lab.daily) == "table" and lab.daily.day == today
			then lab.daily
			else { day = today, amber = 0 }
		granted = math.clamp(Config.Lab.Amber.DailyCap - daily.amber, 0, amount)
		daily.amber += granted
		lab.daily = daily
		todayTotal = daily.amber
		profile.amber += granted

		local stats = if typeof(lab.stats) == "table" then lab.stats else {}
		stats.matches = (stats.matches or 0) + 1
		stats.wins = (stats.wins or 0) + (if result == "Win" then 1 else 0)
		stats.losses = (stats.losses or 0) + (if result == "Loss" then 1 else 0)
		stats.kills = (stats.kills or 0) + kills
		stats.winsPirates = (stats.winsPirates or 0) + (if result == "Win" and teamId == "Pirates" then 1 else 0)
		stats.winsGuardians = (stats.winsGuardians or 0) + (if result == "Win" and teamId == "Guardians" then 1 else 0)
		lab.stats = stats

		if weaponKills then
			local saved = if typeof(lab.weaponKills) == "table" then lab.weaponKills else {}
			for weaponId, count in weaponKills do
				saved[weaponId] = (saved[weaponId] or 0) + count
			end
			lab.weaponKills = saved
		end
	end)
	local profile = PlayerData.get(player)
	if profile then
		if granted > 0 then
			Analytics.amber(player, "Source", granted, profile.amber, "Lab")
		end
		local stats = profile.lab.stats
		task.spawn(function()
			Leaderboards.record(player.UserId, "LabWins", stats.wins or 0)
			Leaderboards.record(player.UserId, "LabKills", stats.kills or 0)
		end)
		-- Títulos por victorias con un bando (grant devuelve false si ya lo tiene).
		if (stats.winsPirates or 0) >= Config.Lab.WinsForTitle then
			CosmeticsServer.grant(player, Config.Lab.Titles.Pirates)
		end
		if (stats.winsGuardians or 0) >= Config.Lab.WinsForTitle then
			CosmeticsServer.grant(player, Config.Lab.Titles.Guardians)
		end
		task.spawn(PlayerData.saveNow, player)
	end
	return granted, todayTotal
end

-- Da a "player" lo de la partida y devuelve lo que enseñan los resultados. "place": su puesto en Todos
-- contra todos (nil en los modos por bandos); "teamId": su bando (nil en Todos contra todos).
function LabRewardService.give(player: Player, result: Result, place: number?, teamId: string?): Reward
	local amount = earned(player, result, place)
	local granted, todayTotal = grant(player, amount, result, teamId)

	-- Para la XP, en Todos contra todos el puesto hace de resultado: 1.º gana, 2.º y 3.º empatan.
	local xpKey: Result = result
	if place then
		xpKey = if place == 1 then "Win" elseif place <= 3 then "Tie" else "Loss"
	end
	local pass = SeasonPass.addXp(player, "Match", Config.Season.LabXp[xpKey])

	-- Misión semanal del Laboratorio (ServerShared/Retention), apuntada ya: luego vuelven al Lobby.
	if result == "Win" then
		Retention.progress(player, "LabWin")
	end
	Retention.flushNow(player)

	return {
		earned = amount,
		amber = granted,
		today = todayTotal,
		dailyCap = Config.Lab.Amber.DailyCap,
		pass = pass,
	}
end

-- Vacía las bajas por arma de la partida (al empezar cada una; LabMatchService).
function LabRewardService.reset()
	table.clear(matchWeaponKills)
end

-- Una baja real: se apunta con el arma que lleva quien la hace.
local function onKnockedOut(_victim: Player, attacker: Player)
	local weaponId = attacker:GetAttribute("LabWeapon")
	if typeof(weaponId) ~= "string" then
		weaponId = Config.Lab.DefaultWeapon
	end
	local byWeapon = matchWeaponKills[attacker.UserId]
	if not byWeapon then
		byWeapon = {}
		matchWeaponKills[attacker.UserId] = byWeapon
	end
	byWeapon[weaponId] = (byWeapon[weaponId] or 0) + 1
end

function LabRewardService:Init()
	LabRespawnService.onKnockedOut(onKnockedOut)
end

function LabRewardService:Start()
	-- La misión semanal del Laboratorio cuenta aquí (y las del día se ven al día en el perfil).
	Retention.start()
end

return LabRewardService
