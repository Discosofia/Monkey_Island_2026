--!strict
-- Dibuja en este cliente los efectos de los jefes que avisa el servidor (Remotes.BossFx): pisotón, rocas,
-- bombas de lava, embestida, agarre y rugido. El servidor pone el daño y los tiempos; aquí solo se ve, con
-- la calidad de FxQuality (ajuste "Efectos") y las piezas de CombatClient/BossFx. Lo que está a más de
-- Config.BossFx.MaxDistanceStuds de la cámara no se dibuja.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossFx = require(ReplicatedStorage:WaitForChild("CombatClient"):WaitForChild("BossFx"))
local Config = require(ReplicatedStorage.Shared.Config)
local FxQuality = require(ReplicatedStorage.Shared.FxQuality)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local BossFxController = {}

local folder: Folder? = nil

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local fresh = Instance.new("Folder")
	fresh.Name = "BossFx"
	fresh.Parent = Workspace
	folder = fresh
	return fresh
end

local function onEvent(kind: unknown, style: unknown, position: unknown, params: unknown)
	if typeof(kind) ~= "string" or typeof(style) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > Config.BossFx.MaxDistanceStuds then
		return
	end
	local values = if typeof(params) == "table" then params :: any else {}
	local ok, message = pcall(function()
		BossFx.play(kind, style, container(), FxQuality.get(), {
			position = position,
			warn = values.warn,
			flight = values.flight,
			radius = values.radius,
			direction = values.direction,
			origin = values.origin,
			serverTime = values.serverTime,
			seed = values.seed,
		})
	end)
	if not ok then
		warn(`BossFx {kind}: {message}`)
	end
end

function BossFxController.Start()
	Remotes.BossFx.OnClientEvent:Connect(onEvent)
end

return BossFxController
