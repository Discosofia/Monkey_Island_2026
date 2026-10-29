--!strict
-- Registro de rendimiento (Fase 4). Cada Config.Performance.LogSeconds escribe en la Salida cuántos
-- monos, piezas construidas, piezas totales y jugadores hay, y los fotogramas por segundo del servidor. Sirve para
-- las pruebas con 20 jugadores y en móvil (ver docs/RENDIMIENTO.md).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Config = require(ReplicatedStorage.Shared.Config)
local Performance = require(ServerScriptService.ServerShared.Performance)

local PerformanceService = {}

function PerformanceService:Start()
	local frames = 0
	RunService.Heartbeat:Connect(function()
		frames += 1
	end)
	while true do
		local started = os.clock()
		frames = 0
		task.wait(Config.Performance.LogSeconds)
		local fps = frames / (os.clock() - started)
		-- El conteo de piezas es el de la pestaña Rendimiento del panel de administradores.
		local totalParts = Performance.count()
		local structures = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
		print(
			string.format(
				"[Rendimiento] %d jugadores · %d enemigos · %d piezas · %d piezas totales · servidor a %.0f FPS · streaming %s",
				#Players:GetPlayers(),
				#CollectionService:GetTagged(Config.Combat.EnemyTag),
				if structures then #structures:GetChildren() else 0,
				totalParts,
				fps,
				if Workspace.StreamingEnabled then "activado" else "DESACTIVADO (ver docs/RENDIMIENTO.md)"
			)
		)
	end
end

return PerformanceService
