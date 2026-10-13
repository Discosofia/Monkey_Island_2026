--!strict
-- Guardado de datos en la Isla (Fase 2.8): carga el perfil de cada jugador (Ámbar, récord…) y,
-- al terminar la partida, suma el Ámbar, el récord de días, la partida jugada y la XP del rol.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)

local DataService = {}

local function onMatchEnded(player: Player, summary: MatchService.Summary)
	local role = player:GetAttribute("Role")
	local xp = summary.days * Config.Data.RoleXpPerDay + summary.kills * Config.Data.RoleXpPerKill
	PlayerData.update(player, function(profile)
		profile.amber += summary.amber
		profile.bestDays = math.max(profile.bestDays, summary.days)
		profile.matches += 1
		if summary.result == "Victory" then
			profile.rescues += 1
		end
		if typeof(role) == "string" then
			profile.roleXp[role] = (profile.roleXp[role] or 0) + xp
		end
	end)
	PlayerData.saveNow(player)
	Remotes.Notify:FireClient(player, `✨ +{summary.amber} de Ámbar guardado`)
end

-- Diario de campo (Fase 4): cuenta los monos derrotados por especie. La primera vez, se anuncia.
local function onKilled(player: Player, speciesId: string)
	local first = false
	PlayerData.update(player, function(profile)
		first = (profile.bestiary[speciesId] or 0) == 0
		profile.bestiary[speciesId] = (profile.bestiary[speciesId] or 0) + 1
	end)
	if first then
		Remotes.Notify:FireClient(player, "📖 ¡Nueva especie en tu diario de campo! (J)")
	end
end

function DataService:Init()
	MatchService.onMatchEnded(onMatchEnded)
	MonkeyService.onKilled(onKilled)
end

function DataService:Start()
	PlayerData.start()
end

return DataService
