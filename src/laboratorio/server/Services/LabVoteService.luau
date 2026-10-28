--!strict
-- Votación del mapa del Laboratorio (L4b). Al empezar cada espera (la llegada y cada revancha) LabMatchService
-- la arma (arm); en cuanto hay alguien en el servidor se abre y dura Config.Lab.VoteSeconds, o hasta que todos
-- han votado. Al cerrarse gana el mapa con más votos (el empate, también sin votos, al azar entre los
-- empatados) y, si no es el actual, se cambia (LabWorldService.setMap) y todos reaparecen en él.
-- Atributos: ReplicatedStorage "LabVoteEndsAt" (tiempo de servidor; nil si está cerrada) y, por jugador,
-- "LabMapVote" (el id elegido). No requiere LabMatchService (este la llama): la fase la lee de Shared/Arena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabRespawnService = require(script.Parent.LabRespawnService)
local LabWorldService = require(script.Parent.LabWorldService)

local LabVoteService = {}

-- Votación por abrir (armada, a la espera de que llegue alguien).
local pending = false

local function validMap(id: any): boolean
	return typeof(id) == "string" and table.find(Config.Lab.Maps, id) ~= nil
end

function LabVoteService.isOpen(): boolean
	return typeof(ReplicatedStorage:GetAttribute("LabVoteEndsAt")) == "number"
end

-- Borra los votos y deja la votación por abrir.
function LabVoteService.arm()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("LabMapVote", nil)
	end
	pending = true
	ReplicatedStorage:SetAttribute("LabVoteEndsAt", nil)
end

-- Cierra la votación y aplica el resultado. "_forced": cierre desde el panel de pruebas o al empezar ya (no
-- cambia nada: sin votación abierta solo cancela la que estaba por abrir).
function LabVoteService.close(_forced: boolean?)
	local wasOpen = LabVoteService.isOpen()
	pending = false
	ReplicatedStorage:SetAttribute("LabVoteEndsAt", nil)
	if not wasOpen then
		return
	end
	local counts: { [string]: number } = {}
	for _, id in Config.Lab.Maps do
		counts[id] = 0
	end
	for _, player in Players:GetPlayers() do
		local vote = player:GetAttribute("LabMapVote")
		if validMap(vote) then
			counts[vote] += 1
		end
	end
	local best = 0
	for _, id in Config.Lab.Maps do
		best = math.max(best, counts[id])
	end
	local tied = {}
	for _, id in Config.Lab.Maps do
		if counts[id] == best then
			table.insert(tied, id)
		end
	end
	local winner = tied[Random.new():NextInteger(1, #tied)]
	Remotes.Notify:FireAllClients("🗳️ Mapa: {name}", { name = { Config.Lab.MapNames[winner] } })
	if winner ~= LabWorldService.currentMap() then
		LabWorldService.setMap(winner)
		LabRespawnService.respawnAll()
	end
end

-- Cada 0,25 s en la espera (LabMatchService.tickWaiting).
function LabVoteService.tick()
	if pending then
		if #Players:GetPlayers() == 0 then
			return
		end
		pending = false
		ReplicatedStorage:SetAttribute("LabVoteEndsAt", Workspace:GetServerTimeNow() + Config.Lab.VoteSeconds)
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute("LabVoteEndsAt")
	if typeof(endsAt) ~= "number" then
		return
	end
	local players = Players:GetPlayers()
	local allVoted = #players > 0
	for _, player in players do
		if not validMap(player:GetAttribute("LabMapVote")) then
			allVoted = false
		end
	end
	if allVoted or Workspace:GetServerTimeNow() >= endsAt then
		LabVoteService.close()
	end
end

-- Panel de pruebas.
function LabVoteService.debugCloseNow()
	LabVoteService.close(true)
end

function LabVoteService:Start()
	Remotes.LabMapVote.OnServerEvent:Connect(function(player: Player, id: any)
		if validMap(id) and Arena.phase() == "Waiting" and LabVoteService.isOpen() then
			player:SetAttribute("LabMapVote", id)
		end
	end)
end

return LabVoteService
