--!strict
-- Guardado de datos en la Isla (Fase 2.8): carga el perfil de cada jugador (Ámbar, récord…) y,
-- al terminar la partida, suma el Ámbar, el récord de días, la partida jugada y la XP del rol.
-- Una partida terminada con el panel de pruebas ("test" en el resumen) da el Ámbar y la XP, pero no
-- toca el récord de días, los rescates ni el ranking. Ganar con el equipo del nivel 4 de tu rol (su
-- arma de rol y la armadura volcánica) da su traje mítico (Data/Cosmetics, earned "MasterVictory").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Leaderboards = require(ServerScriptService.ServerShared.Leaderboards)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local BossService = require(script.Parent.BossService)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)

local DataService = {}

-- Si "player" lleva el equipo del nivel 4 de "roleId": la armadura volcánica y su arma de rol del
-- último nivel (en la mochila, en la mano o en StarterGear).
-- Fase 12: el final de "Seguir sobreviviendo" (phase "Endless") no vuelve a contar la partida; su
-- "days" es el total, así el récord y el ranking cuentan los días de más.
local function hasMasterKit(player: Player, roleId: string): boolean
	if player:GetAttribute("Armor") ~= "VolcanicArmor" then
		return false
	end
	local containers: { Instance? } =
		{ player:FindFirstChild("StarterGear"), player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		for _, tool in if container then container:GetChildren() else {} do
			local weaponId = tool:GetAttribute("WeaponId")
			if tool:IsA("Tool") and typeof(weaponId) == "string" then
				local weaponRole, level = WeaponTools.roleLevel(weaponId)
				if weaponRole == roleId and level >= WeaponTools.MAX_LEVEL then
					return true
				end
			end
		end
	end
	return false
end

-- Trajes míticos de "roleId" que se ganan venciendo con su equipo del nivel 4.
local function grantMasterOutfits(player: Player, roleId: string)
	if not hasMasterKit(player, roleId) then
		return
	end
	for cosmeticId, cosmetic in Cosmetics do
		if
			cosmetic.source.earned == "MasterVictory"
			and cosmetic.role == roleId
			and CosmeticsServer.grant(player, cosmeticId)
		then
			Remotes.Notify:FireClient(
				player,
				`{cosmetic.icon} ¡Cosmético MÍTICO ganado! {cosmetic.name}. Póntelo en el Armario (Lobby)`
			)
		end
	end
end

local function onMatchEnded(player: Player, summary: MatchService.Summary)
	local role = player:GetAttribute("Role")
	local xp = summary.days * Config.Data.RoleXpPerDay + summary.kills * Config.Data.RoleXpPerKill
	PlayerData.update(player, function(profile)
		profile.amber += summary.amber
		-- El final tras "Seguir sobreviviendo" es la misma partida: ya contó en el rescate.
		if summary.phase ~= "Endless" then
			profile.matches += 1
		end
		if not summary.test then
			profile.bestDays = math.max(profile.bestDays, summary.days)
			if summary.result == "Victory" then
				profile.rescues += 1
			end
		end
		if typeof(role) == "string" then
			profile.roleXp[role] = (profile.roleXp[role] or 0) + xp
		end
	end)
	-- En Studio también cuenta una victoria del panel de pruebas, para poder probarlo.
	if summary.result == "Victory" and (not summary.test or RunService:IsStudio()) and typeof(role) == "string" then
		grantMasterOutfits(player, role)
	end
	PlayerData.saveNow(player)
	Remotes.Notify:FireClient(
		player,
		`✨ +{summary.amber} de Ámbar guardado{if summary.test then " (prueba: no cuenta para el ranking)" else ""}`
	)
	local profile = PlayerData.get(player)
	if profile then
		Analytics.amber(player, "Source", summary.amber, profile.amber, "MatchReward")
		if not summary.test then
			Leaderboards.record(player.UserId, "BestDays", profile.bestDays)
			Leaderboards.record(player.UserId, "Rescues", profile.rescues)
		end
	end
	Analytics.event(
		player,
		if summary.result == "Victory"
			then "MatchVictory"
			elseif summary.phase == "Endless" then "MatchEndless"
			else "MatchDefeat",
		summary.days
	)
end

-- Diario de campo (Fase 4): cuenta los monos derrotados por especie y los jefes por id (los dos en
-- "bestiary"). La primera vez, se anuncia.
local function recordDefeat(player: Player, id: string, message: string)
	local first = false
	PlayerData.update(player, function(profile)
		first = (profile.bestiary[id] or 0) == 0
		profile.bestiary[id] = (profile.bestiary[id] or 0) + 1
	end)
	if first then
		Remotes.Notify:FireClient(player, message)
	end
end

local function onKilled(player: Player, speciesId: string)
	recordDefeat(player, speciesId, "📖 ¡Nueva especie en tu diario de campo! (J)")
end

local function onBossDefeated(player: Player, bossId: string)
	recordDefeat(player, bossId, "📖 ¡Nuevo jefe en tu diario de campo! (J)")
end

function DataService:Init()
	MatchService.onMatchEnded(onMatchEnded)
	MonkeyService.onKilled(onKilled)
	BossService.onDefeated(onBossDefeated)
end

function DataService:Start()
	PlayerData.start()
end

return DataService
