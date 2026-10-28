--!strict
-- Alarma de las Rondas del Laboratorio (docs/LABORATORIO.md §3): con "LabAlarm" en ReplicatedStorage
-- (Rounds, a los AlarmAtSeconds de la ronda), los demás jugadores vivos se ven a través de las paredes: un
-- Highlight "AlarmaLab" (AlwaysOnTop, sin relleno) con el contorno del color de su bando. Se hace aquí, en el
-- cliente, para no dibujar el contorno del propio personaje en primera persona. Se quita al apagarse la
-- alarma, al morir o al ser eliminado de la ronda ("LabOut"). Sin bandos (Todos contra todos), un color neutro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = require(ReplicatedStorage.Shared.Arena)

local HIGHLIGHT_NAME = "AlarmaLab"
local NEUTRAL_COLOR = Color3.fromRGB(240, 235, 220)
-- Cada cuánto se revisa quién lo lleva (no hace falta cada fotograma).
local REFRESH_SECONDS = 0.2

local LabAlarmController = {}

local highlights: { [Player]: Highlight } = {}

local function remove(player: Player)
	local highlight = highlights[player]
	if highlight then
		highlight:Destroy()
		highlights[player] = nil
	end
end

local function isAlive(player: Player): (boolean, Model?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if player:GetAttribute("LabOut") == true or not character or not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	return true, character
end

local function update()
	local me = Players.LocalPlayer
	local alarm = ReplicatedStorage:GetAttribute("LabAlarm") == true
	for player in highlights do
		if not alarm or player.Parent == nil then
			remove(player)
		end
	end
	if not alarm then
		return
	end
	for _, player in Players:GetPlayers() do
		if player ~= me then
			local alive, character = isAlive(player)
			if not alive or not character then
				remove(player)
				continue
			end
			local existing = highlights[player]
			if existing and existing.Parent ~= character then
				remove(player)
				existing = nil
			end
			local highlight: Highlight
			if existing then
				highlight = existing
			else
				highlight = Instance.new("Highlight")
				highlight.Name = HIGHLIGHT_NAME
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.FillTransparency = 1
				highlight.OutlineTransparency = 0
				highlight.Parent = character
				highlights[player] = highlight
			end
			local teamId = Arena.teamOf(player)
			highlight.OutlineColor = if teamId then Arena.TEAMS[teamId].color else NEUTRAL_COLOR
		end
	end
end

function LabAlarmController:Start()
	Players.PlayerRemoving:Connect(remove)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= REFRESH_SECONDS then
			elapsed = 0
			update()
		end
	end)
end

return LabAlarmController
