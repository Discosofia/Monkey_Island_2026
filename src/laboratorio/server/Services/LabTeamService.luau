--!strict
-- Bandos del Laboratorio (docs/LABORATORIO.md §1 y §6): Piratas y Guardianes (Config.Lab.Teams, que
-- este servicio pone en Shared/Arena). Nadie elige: al entrar, cada uno va al bando con menos gente (al
-- azar si están iguales), y en cada revancha se reparten otra vez al azar, equilibrados (shuffle).
-- El bando va en el atributo "Team" (Shared/Arena), en el equipo de Roblox (la lista de jugadores sale por
-- colores) y en "LabFaction" (el aspecto de las armas, Shared/WeaponTools). Las piezas del personaje van
-- en el grupo de colisión de su bando: así las barreras de salida del rival no le dejan entrar
-- (LabWorldService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local LabWorldService = require(script.Parent.LabWorldService)

local LabTeamService = {}

-- Los nombres de los bandos (Config.Lab.Teams) se traducen al dibujarlos (el marcador, los resultados).
local _TEAM_NAMES = { Strings.later("Piratas"), Strings.later("Guardianes") }

local robloxTeams: { [string]: Team } = {}

local function applyGroup(player: Player, character: Model?)
	local teamId = Arena.teamOf(player)
	if not character or not teamId then
		return
	end
	local group = LabWorldService.characterGroup(teamId)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- Al aparecer (LabRespawnService): el personaje, en el grupo de colisión de su bando, también lo que se
-- le añada después (accesorios, el arma en la mano).
function LabTeamService.prepareCharacter(player: Player, character: Model)
	applyGroup(player, character)
	character.DescendantAdded:Connect(function(part)
		local teamId = Arena.teamOf(player)
		if part:IsA("BasePart") and teamId then
			part.CollisionGroup = LabWorldService.characterGroup(teamId)
		end
	end)
end

local function setTeam(player: Player, teamId: string)
	player:SetAttribute("Team", teamId)
	player:SetAttribute("LabFaction", teamId)
	player:SetAttribute("ArenaReady", false)
	player.Team = robloxTeams[teamId]
	WeaponTools.reskin(player)
	applyGroup(player, player.Character)
end

-- El bando con menos jugadores (sin contar a "except"); con empate, al azar.
local function smallerTeam(except: Player?): string
	local first, second = Config.Lab.TeamOrder[1], Config.Lab.TeamOrder[2]
	local counts = { [first] = 0, [second] = 0 }
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if player ~= except and teamId then
			counts[teamId] += 1
		end
	end
	if counts[first] == counts[second] then
		return Config.Lab.TeamOrder[math.random(1, 2)]
	end
	return if counts[first] < counts[second] then first else second
end

-- Le da bando si aún no tiene (al entrar; LabRespawnService lo pide antes de que aparezca).
function LabTeamService.ensureTeam(player: Player)
	if not Arena.teamOf(player) then
		setTeam(player, smallerTeam(player))
	end
end

-- Reparte otra vez a todos al azar, equilibrados (al volver a la espera tras unos resultados).
function LabTeamService.shuffle()
	local players = Players:GetPlayers()
	for index = #players, 2, -1 do
		local other = math.random(1, index)
		players[index], players[other] = players[other], players[index]
	end
	-- El primero del orden ya mezclado va a un bando al azar y los demás se alternan.
	local start = math.random(0, 1)
	for index, player in players do
		setTeam(player, Config.Lab.TeamOrder[(index + start) % 2 + 1])
	end
end

-- Panel de pruebas: al otro bando.
function LabTeamService.switch(player: Player)
	local teamId = Arena.teamOf(player)
	setTeam(player, if teamId then Arena.otherTeam(teamId) else smallerTeam(player))
end

function LabTeamService:Init()
	Arena.configure(Config.Lab.Teams, Config.Lab.TeamOrder)
	for _, teamId in Config.Lab.TeamOrder do
		local settings = Config.Lab.Teams[teamId]
		local team = Instance.new("Team")
		team.Name = settings.name
		team.TeamColor = BrickColor.new(settings.color)
		team.AutoAssignable = false
		team.Parent = Teams
		robloxTeams[teamId] = team
	end
end

return LabTeamService
