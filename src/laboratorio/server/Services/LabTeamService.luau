--!strict
-- Bandos del Laboratorio (docs/LABORATORIO.md §1 y §6): Piratas y Guardianes (Config.Lab.Teams, que
-- este servicio pone en Shared/Arena). Nadie elige: quien viene de la cola del Lobby llega al bando que
-- le tocó (TeleportData "team"; "party" es su grupo, atributo "LabParty"); los demás van al bando con
-- menos gente (al azar si están iguales), y en cada revancha se reparten otra vez al azar, equilibrados
-- y sin separar a los grupos (shuffle).
-- El bando va en el atributo "Team" (Shared/Arena), en el equipo de Roblox (la lista de jugadores sale por
-- colores) y en "LabFaction" (el aspecto de las armas, Shared/WeaponTools). Las piezas del personaje van
-- en el grupo de colisión de su bando: así las barreras de salida del rival no le dejan entrar
-- (LabWorldService).
-- En Todos contra todos (docs/LABORATORIO.md §3) no hay bando: "Team" queda en nil, la facción se elige al
-- azar (solo cambia el aspecto de las armas) y el personaje va en el grupo de colisión "Default", que
-- chocan con las barreras de las dos bases: nadie entra en ellas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local LabWorldService = require(script.Parent.LabWorldService)

local LabTeamService = {}

-- Los nombres de los bandos (Config.Lab.Teams) se traducen al dibujarlos (el marcador, los resultados).
local _TEAM_NAMES = { Strings.later("Piratas"), Strings.later("Guardianes") }

local robloxTeams: { [string]: Team } = {}

-- El grupo de colisión del personaje: el de su bando, o "Default" sin bando.
local function groupOf(player: Player): string
	local teamId = Arena.teamOf(player)
	return if teamId then LabWorldService.characterGroup(teamId) else "Default"
end

local function applyGroup(player: Player, character: Model?)
	if not character then
		return
	end
	local group = groupOf(player)
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
		if part:IsA("BasePart") then
			part.CollisionGroup = groupOf(player)
		end
	end)
end

-- Le da bando ("teamId") o, con nil, lo deja sin bando con una facción al azar.
local function setTeam(player: Player, teamId: string?)
	player:SetAttribute("Team", teamId)
	player:SetAttribute("LabFaction", teamId or Config.Lab.TeamOrder[math.random(1, #Config.Lab.TeamOrder)])
	player:SetAttribute("ArenaReady", false)
	player.Team = if teamId then robloxTeams[teamId] else nil
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
	if LabModes.isFreeForAll() then
		if player:GetAttribute("LabFaction") == nil or Arena.teamOf(player) then
			setTeam(player, nil)
		end
	elseif not Arena.teamOf(player) then
		setTeam(player, smallerTeam(player))
	end
end

-- El bando y el grupo que trae del Lobby (ArenaQueueService, TeleportData "team" y "party"), si cabe.
local function joinFromQueue(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data = if ok and typeof(joinData) == "table" then joinData.TeleportData else nil
	if typeof(data) ~= "table" then
		return
	end
	-- El grupo se guarda siempre: el reparto de las revanchas lo mantiene junto.
	player:SetAttribute("LabParty", if typeof(data.party) == "number" then data.party else nil)
	local teamId = data.team
	if
		not LabModes.isFreeForAll()
		and typeof(teamId) == "string"
		and table.find(Config.Lab.TeamOrder, teamId)
		and Arena.phase() == "Waiting"
		and Arena.teamOf(player) ~= teamId
		and #Arena.membersOf(teamId) < Arena.format()
	then
		setTeam(player, teamId)
	end
end

-- Reparte otra vez a todos al azar y equilibrados, sin separar a los grupos (atributo "LabParty"): cada
-- grupo entero es un bloque, y quien no tiene grupo, un bloque de uno (al volver a la espera tras unos
-- resultados).
function LabTeamService.shuffle()
	if LabModes.isFreeForAll() then
		for _, player in Players:GetPlayers() do
			setTeam(player, nil)
		end
		return
	end
	local blocks: { { Player } } = {}
	local byParty: { [number]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		local party = player:GetAttribute("LabParty")
		if typeof(party) == "number" then
			local block = byParty[party]
			if not block then
				block = {}
				byParty[party] = block
				table.insert(blocks, block)
			end
			table.insert(block, player)
		else
			table.insert(blocks, { player })
		end
	end
	for index = #blocks, 2, -1 do
		local other = math.random(1, index)
		blocks[index], blocks[other] = blocks[other], blocks[index]
	end
	-- De mayor a menor, estable tras el barajado (el orden barajado desempata).
	local order: { [{ Player }]: number } = {}
	for index, block in blocks do
		order[block] = index
	end
	table.sort(blocks, function(a, b)
		if #a ~= #b then
			return #a > #b
		end
		return order[a] < order[b]
	end)
	local sizes = { [Config.Lab.TeamOrder[1]] = 0, [Config.Lab.TeamOrder[2]] = 0 }
	for _, block in blocks do
		local first, second = Config.Lab.TeamOrder[1], Config.Lab.TeamOrder[2]
		local teamId = if sizes[first] == sizes[second]
			then Config.Lab.TeamOrder[math.random(1, 2)]
			elseif sizes[first] < sizes[second] then first
			else second
		sizes[teamId] += #block
		for _, player in block do
			setTeam(player, teamId)
		end
	end
end

-- Panel de pruebas: al otro bando.
function LabTeamService.switch(player: Player)
	if LabModes.isFreeForAll() then
		return
	end
	local teamId = Arena.teamOf(player)
	setTeam(player, if teamId then Arena.otherTeam(teamId) else smallerTeam(player))
end

-- Al cambiar de modo (LabMatchService.setMode): sin bando en Todos contra todos; en los demás, se reparten
-- todos de nuevo.
function LabTeamService.applyMode()
	if LabModes.isFreeForAll() then
		for _, player in Players:GetPlayers() do
			setTeam(player, nil)
		end
	else
		LabTeamService.shuffle()
	end
end

function LabTeamService:Start()
	-- Después de que LabMatchService lea el formato del primero en llegar.
	Players.PlayerAdded:Connect(function(player)
		task.defer(joinFromQueue, player)
	end)
	for _, player in Players:GetPlayers() do
		task.defer(joinFromQueue, player)
	end
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
