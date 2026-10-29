--!strict
-- Espectador del Laboratorio (docs/LABORATORIO.md §3); la cámara, la ficha y la barra ◀ ▶ son de
-- CombatClient/SpectateCamera. Aquí solo se dice cuándo y a quién:
--   - Rondas: quien cae en plena ronda queda con "LabOut" y no reaparece hasta la pausa.
--   - Batalla en cualquier modo: quien cae y espera su "RespawnAt" (Fase 15, V10: killcam de
--     Config.Lab.KillcamSeconds sobre quien lo derribó y después sus compañeros).
--   - Candidatos: los compañeros en pie; en Todos contra todos (sin bando), cualquiera en pie.
--   - Sin nadie en pie, vista fija desde arriba del centro del mapa (cámara Scriptable) a la altura
--     OverheadHeight de su modelo; si el mapa tiene techo (carpeta Techo), se oculta en local mientras dura.
--   - El ratón va suelto mientras dura (FirstPersonController.freeCursor "Spectate") para poder pulsar ◀ ▶.
-- Al reaparecer (o al acabar la ronda) se restaura la primera persona del place (CameraMode, zoom y cámara).
-- Sitio en pantalla: la barra y la ficha van abajo en el centro; el selector de armas (LabLoadoutController)
-- está arriba y "Reapareces en" (LabHUDController) al 20 % de la altura, así que no se pisan salvo en un
-- teléfono muy bajo, donde la ficha (1,5 s) puede rozar el borde inferior del selector.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local SpectateCamera = require(ReplicatedStorage.CombatClient.SpectateCamera)
local FirstPersonController = require(script.Parent.FirstPersonController)

-- Vista fija sin compañeros: altura sobre el centro del mapa (si su modelo no trae OverheadHeight) y cuánto
-- se desplaza hacia atrás.
local DEFAULT_OVERHEAD_HEIGHT = 150
local OVERHEAD_BACK = 40

local LabSpectateController = {}

-- El modelo del mapa que se juega (LabMap/<Map>), o nil si aún no está.
local function activeMap(): Model?
	local folder = Workspace:FindFirstChild("LabMap")
	local id = if folder then folder:GetAttribute("Map") else nil
	local model = if folder and typeof(id) == "string" then folder:FindFirstChild(id) else nil
	return if model and model:IsA("Model") then model else nil
end

-- El centro del mapa (el pivote de su modelo), la altura de la vista cenital y cuánto se desplaza hacia atrás
-- (el atributo OverheadBack de su modelo, si lo trae); cero si aún no está.
local function mapCenter(): (Vector3, number, number)
	local map = activeMap()
	if not map then
		return Vector3.zero, DEFAULT_OVERHEAD_HEIGHT, OVERHEAD_BACK
	end
	local height = map:GetAttribute("OverheadHeight")
	local back = map:GetAttribute("OverheadBack")
	return map:GetPivot().Position,
		if typeof(height) == "number" then height else DEFAULT_OVERHEAD_HEIGHT,
		if typeof(back) == "number" then back else OVERHEAD_BACK
end

-- Oculta (o devuelve) el techo del mapa, solo para este jugador: LocalTransparencyModifier no cambia la
-- pieza en el servidor.
local function setCeilingHidden(hidden: boolean)
	local map = activeMap()
	local ceiling = if map then map:FindFirstChild("Techo") else nil
	if not ceiling then
		return
	end
	for _, part in ceiling:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function LabSpectateController:Start()
	local player = Players.LocalPlayer
	SpectateCamera.new({
		guiName = "LabSpectate",
		distance = Config.Lab.SpectateDistance,
		killcamSeconds = Config.Lab.KillcamSeconds,
		candidates = function()
			return if Arena.teamOf(player) then SpectateCamera.allies(player) else SpectateCamera.everyone(player)
		end,
		overhead = mapCenter,
		hideCeiling = setCeilingHidden,
		freeCursor = function(on: boolean)
			FirstPersonController.freeCursor("Spectate", on)
		end,
		wantsSpectate = function()
			if not Arena.inBattle() then
				return false
			end
			if LabModes.isRounds() and player:GetAttribute("LabOut") == true then
				return true
			end
			local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
			return typeof(player:GetAttribute("RespawnAt")) == "number" and humanoid ~= nil and humanoid.Health <= 0
		end,
	}):Start()
end

return LabSpectateController
