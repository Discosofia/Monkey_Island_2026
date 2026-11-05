--!strict
-- Cámara al hombro al apuntar (Fase 19, W7). Mientras WeaponController dice que se apunta (clic derecho,
-- gatillo izquierdo o el botón "Mira"), en tercera persona:
--   - el ratón se bloquea en el centro y el personaje mira hacia donde mira la cámara (como el bloqueo de
--     cámara de Roblox), así la mira del centro de la pantalla es la línea de tiro;
--   - la cámara pasa al hombro derecho (Humanoid.CameraOffset = Config.Aim.ShoulderOffset), con una
--     transición de Config.Aim.TransitionSeconds.
-- Al soltar, al caer, al soltar el arma, con el menú de Roblox o un cuadro de texto abierto, en primera
-- persona o sentado, todo vuelve a lo que estaba (el modo de rotación, el ratón, AutoRotate y el
-- desplazamiento de la cámara). Con el bloqueo de cámara puesto (Ctrl, CameraLock) hace lo mismo sin apuntar, con
-- el desplazamiento de Config.Aim.LockOffset, y al apuntar pasa de ese al del hombro. El Laboratorio no lo carga: se juega en primera persona
-- (CombatClient/Controllers/FirstPersonController). Con ViewMode.get() == "First" (Fase 24: el campo de tiro en
-- modo shooter) queda inactivo y devuelve todo a su sitio. Aim.direction apunta al centro de la cámara
-- desde la cabeza, así que el tiro converge con la mira aunque la cámara esté al hombro.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Aim = require(script.Parent.Parent.Aim)
local WeaponController = require(script.Parent.WeaponController)
local CameraLock = require(script.Parent.Parent.CameraLock)
local ViewMode = require(script.Parent.Parent.ViewMode)

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
-- 0 (cámara normal) a 1 (al hombro del todo al apuntar) y 0 a 1 (con el bloqueo de cámara puesto).
local blend = 0
local lockBlend = 0

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

-- true si ahora toca el bloqueo de cámara (Ctrl, CombatClient/CameraLock) con este personaje: el ratón al centro,
-- de cara a la mira y la cámara al hombro, apunte o no. Se suelta con el menú de Roblox o un cuadro de texto.
local function lockWanted(humanoid: Humanoid, camera: Camera): boolean
	if not CameraLock.isLocked() or not LifeState.isAlive(player) or humanoid.Health <= 0 or humanoid.Sit then
		return false
	end
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	return (camera.CFrame.Position - camera.Focus.Position).Magnitude > FIRST_PERSON_STUDS
end

-- Cámara libre (clic derecho sin bloqueo de cámara): sin zoom ni cámara al hombro, el personaje solo se gira
-- hacia donde apunta el cursor mientras se mantiene el clic derecho. El ratón lo maneja la cámara de Roblox.
local freeSaved: Humanoid? = nil
local function stepFree(humanoid: Humanoid, root: BasePart, character: Model)
	local want = WeaponController.isFreeAiming()
		and LifeState.isAlive(player)
		and humanoid.Health > 0
		and not humanoid.Sit
		and not GuiService.MenuIsOpen
	if want then
		freeSaved = humanoid
		humanoid.AutoRotate = false
		local look = Aim.direction(character)
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	elseif freeSaved then
		if freeSaved.Parent then
			freeSaved.AutoRotate = true
		end
		freeSaved = nil
	end
end

local function restore(state: Saved)
	if state.humanoid.Parent then
		state.humanoid.AutoRotate = state.autoRotate
		state.humanoid.CameraOffset = state.offset
	end
end

local function step(deltaTime: number)
	-- Se vuelve a poner abajo si toca (ver CameraLock.setCentered).
	CameraLock.setCentered(false)
	-- Primera persona: nada de cámara al hombro; si estaba puesta, se devuelve todo.
	if ViewMode.get() == "First" then
		if saved then
			restore(saved)
			saved = nil
			blend = 0
			lockBlend = 0
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if freeSaved then
			if freeSaved.Parent then
				freeSaved.AutoRotate = true
			end
			freeSaved = nil
		end
		return
	end
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local state = saved
	if camera and humanoid and root and root:IsA("BasePart") and character and not state then
		stepFree(humanoid, root, character)
	end
	if state and (not humanoid or state.humanoid ~= humanoid) then
		-- Otro personaje (reapareció): lo de antes ya no existe, solo quedan los ajustes del jugador.
		restore(state)
		saved = nil
		state = nil
		blend = 0
		lockBlend = 0
	end
	if not (camera and humanoid and root and root:IsA("BasePart")) then
		return
	end
	local aimWant = wanted(humanoid, camera)
	local lockWant = lockWanted(humanoid, camera)
	local want = aimWant or lockWant
	CameraLock.setCentered(want)
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
	blend = math.clamp(blend + (if aimWant then deltaTime else -deltaTime) / seconds, 0, 1)
	lockBlend = math.clamp(lockBlend + (if lockWant then deltaTime else -deltaTime) / seconds, 0, 1)
	if not want and blend <= 0 and lockBlend <= 0 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		restore(state)
		saved = nil
		return
	end
	local eased = blend * blend * (3 - 2 * blend)
	local lockEased = lockBlend * lockBlend * (3 - 2 * lockBlend)
	-- Del desplazamiento de la cámara normal al del bloqueo y de ahí al del hombro al apuntar.
	humanoid.CameraOffset = state.offset:Lerp(Config.Aim.LockOffset, lockEased):Lerp(Config.Aim.ShoulderOffset, eased)
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
		-- Soltando: el ratón queda libre y el personaje vuelve a girar solo mientras la cámara vuelve.
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		humanoid.AutoRotate = state.autoRotate
	end
end

function ShoulderAimController:Start()
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

return ShoulderAimController
