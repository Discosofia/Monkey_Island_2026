--!strict
-- Equipos de la arena: cada jugador elige el suyo al llegar (Remotes.ArenaPickTeam), como mucho
-- Arena.format() por equipo, y aparece en su base. Publica el atributo "Team" (Shared/Arena) y lo
-- pone también en el equipo de Roblox (la lista de jugadores sale por colores).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArenaRoleService = require(script.Parent.ArenaRoleService)
local RespawnService = require(script.Parent.RespawnService)

local TeamService = {}

local robloxTeams: { [string]: Team } = {}

local function join(player: Player, teamId: string)
	player:SetAttribute("Team", teamId)
	player:SetAttribute("ArenaReady", false)
	player.Team = robloxTeams[teamId]
	ArenaRoleService.ensureAllowed(player)
	RespawnService.respawnNow(player)
	local team = Config.Arena.Teams[teamId]
	Remotes.Notify:FireClient(player, `{team.icon} Estás en el equipo {team.name}: elige tu rol y pulsa "Listo"`)
end

-- Mete en un equipo a quien aún no lo tenga (al acabarse la espera): al que tenga menos jugadores.
function TeamService.assignMissing()
	for _, player in Players:GetPlayers() do
		if not Arena.teamOf(player) then
			local jaguar = #Arena.membersOf("Jaguar")
			local quetzal = #Arena.membersOf("Quetzal")
			local teamId = if jaguar == quetzal
				then Arena.TEAM_IDS[math.random(1, 2)]
				elseif jaguar < quetzal then "Jaguar"
				else "Quetzal"
			if #Arena.membersOf(teamId) < Arena.format() then
				join(player, teamId)
			end
		end
	end
end

local function onPickTeam(player: Player, teamId: any)
	if Arena.phase() ~= "Waiting" or not Arena.isTeam(teamId) or Arena.teamOf(player) == teamId then
		return
	end
	if #Arena.membersOf(teamId) >= Arena.format() then
		Remotes.Notify:FireClient(player, `El equipo {Config.Arena.Teams[teamId].name} ya está completo`)
		return
	end
	join(player, teamId)
end

function TeamService:Init()
	for _, teamId in Arena.TEAM_IDS do
		local settings = Config.Arena.Teams[teamId]
		local team = Instance.new("Team")
		team.Name = settings.name
		team.TeamColor = BrickColor.new(settings.color)
		team.AutoAssignable = false
		team.Parent = Teams
		robloxTeams[teamId] = team
	end
end

function TeamService:Start()
	Remotes.ArenaPickTeam.OnServerEvent:Connect(onPickTeam)
	Remotes.ArenaReady.OnServerEvent:Connect(function(player: Player, ready: any)
		if Arena.phase() == "Waiting" and Arena.teamOf(player) and typeof(ready) == "boolean" then
			player:SetAttribute("ArenaReady", ready)
		end
	end)
end

return TeamService
