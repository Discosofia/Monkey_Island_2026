--!strict
-- Cámara al hombro al apuntar (Fase 19, W7). Mientras WeaponController dice que se apunta (clic derecho,
-- gatillo izquierdo o el botón "Mira"), en tercera persona:
--   - el ratón se bloquea en el centro y el personaje mira hacia donde mira la cámara (como el bloqueo de
--     cámara de Roblox), así la mira del centro de la pantalla es la línea de tiro;
--   - la cámara pasa al hombro derecho (Humanoid.CameraOffset = Config.Aim.ShoulderOffset), con una
--     transición de Config.Aim.TransitionSeconds.
-- Al soltar, al caer, al soltar el arma, con el menú de Roblox o un cuadro de texto abierto, en primera
-- persona o sentado, todo vuelve a lo que estaba (el modo de rotación, el ratón, AutoRotate y el
-- desplazamiento de la cámara). El Laboratorio no lo carga: se juega en primera persona
-- (laboratorio/client/Controllers/FirstPersonController). Aim.direction apunta al centro de la cámara
-- desde la cabeza, así que el tiro converge con la mira aunque la cámara esté al hombro.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local WeaponController = require(script.Parent.WeaponController)

local BIND_NAME = "ShoulderAim"
-- A esta distancia o menos del punto que sigue, la cámara cuenta como primera persona.
local FIRST_PERSON_STUDS = 1.5

local ShoulderAimController = {}

type Saved = {
	humanoid: Humanoid,
	autoRotate: boolean,
	offset: Vector3,
}

local player = Players.LocalPlayer
local saved: Saved? = nil
-- 0 (cámara normal) a 1 (al hombro del todo).
local blend = 0

-- true si ahora toca estar al hombro con este personaje.
local function wanted(humanoid: Humanoid, camera: Camera): boolean
	if not WeaponController.isAiming() or not LifeState.isAlive(player) or humanoid.Health <= 0 or humanoid.Sit then
		return false
	end
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	return (camera.CFrame.Position - camera.Focus.Position).Magnitude > FIRST_PERSON_STUDS
end

-- El modo del ratón y el de rotación no se guardan: el jugador puede cambiar el bloqueo de cámara (Ctrl)
-- mientras apunta, y restaurar un valor viejo dejaba el ratón fijo en el centro. La cámara de Roblox no
-- reajusta el ratón sola al soltar, así que se pregunta a su bloqueo si está encendido (si no se puede
-- saber, se deja libre).
local mouseLock: any = nil
local function naturalBehavior(): Enum.MouseBehavior
	if mouseLock == nil then
		local ok, controller = pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			assert(module, "sin PlayerModule")
			return (require(module) :: any):GetCameras():GetMouseLockController()
		end)
		mouseLock = if ok and controller then controller else false
	end
	if mouseLock and mouseLock:GetIsMouseLocked() then
		return Enum.MouseBehavior.LockCenter
	end
	return Enum.MouseBehavior.Default
end

local function restore(state: Saved)
	if state.humanoid.Parent then
		state.humanoid.AutoRotate = state.autoRotate
		state.humanoid.CameraOffset = state.offset
	end
end

local function step(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local state = saved
	if state and (not humanoid or state.humanoid ~= humanoid) then
		-- Otro personaje (reapareció): lo de antes ya no existe, solo quedan los ajustes del jugador.
		restore(state)
		saved = nil
		state = nil
		blend = 0
	end
	if not (camera and humanoid and root and root:IsA("BasePart")) then
		return
	end
	local want = wanted(humanoid, camera)
	if want and not state then
		state = {
			humanoid = humanoid,
			autoRotate = humanoid.AutoRotate,
			offset = humanoid.CameraOffset,
		}
		saved = state
	end
	if not state then
		return
	end
	local seconds = math.max(Config.Aim.TransitionSeconds, 1e-3)
	blend = math.clamp(blend + (if want then deltaTime else -deltaTime) / seconds, 0, 1)
	if not want and blend <= 0 then
		UserInputService.MouseBehavior = naturalBehavior()
		restore(state)
		saved = nil
		return
	end
	local eased = blend * blend * (3 - 2 * blend)
	humanoid.CameraOffset = state.offset:Lerp(Config.Aim.ShoulderOffset, eased)
	if want then
		-- La cámara de Roblox reajusta el ratón cada fotograma: este paso va justo después.
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		humanoid.AutoRotate = false
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	else
		-- Soltando: el ratón vuelve a lo que pide el bloqueo de cámara y el personaje vuelve a girar solo
		-- mientras la cámara vuelve.
		UserInputService.MouseBehavior = naturalBehavior()
		humanoid.AutoRotate = state.autoRotate
	end
end

function ShoulderAimController:Start()
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

return ShoulderAimController
