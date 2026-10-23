--!strict
-- Temblor de la cámara del jugador local (Fase 10, C12). Todos los temblores del combate pasan por aquí
-- para que el ajuste "cameraShake" (Shared/Settings: encendido, suave o apagado; Config.CameraShake.Scale)
-- los cambie todos a la vez: el remate de la cadena (WeaponController), las habilidades y el rebote
-- contra muros (AbilityFxController) y la guardia (parry y guardia rota).
--   CameraShake.play(fuerza, segundos)   tiembla y se va apagando ("fuerza" 1 ≈ 0,4 studs)
--   CameraShake.scale()                  lo que multiplica el ajuste (0 = apagado)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(ReplicatedStorage.Shared.Settings)

local CameraShake = {}

local rng = Random.new()
local count = 0

function CameraShake.scale(): number
	return Config.CameraShake.Scale[Settings.get().cameraShake] or 1
end

function CameraShake.play(strength: number, seconds: number)
	local camera = Workspace.CurrentCamera
	local power = strength * CameraShake.scale()
	if not camera or power <= 0 or seconds <= 0 then
		return
	end
	count += 1
	local name = `CombatShake{count}`
	local elapsed = 0
	-- Justo después de la cámara de Roblox: se suma a donde la deja en cada fotograma.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		elapsed += deltaTime
		if elapsed >= seconds then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local amount = power * (1 - elapsed / seconds) * 0.4
		camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * amount, rng:NextNumber(-1, 1) * amount, 0)
	end)
end

return CameraShake
