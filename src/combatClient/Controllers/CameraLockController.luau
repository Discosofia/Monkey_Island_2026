--!strict
-- Bloqueo de cámara (el "shift lock" de Roblox; Fase 10, C2) en Ctrl: Mayús ya es correr. Los tres
-- places lo activan con StarterPlayer.EnableMouseLockOption (*.project.json) y cada jugador lo enciende
-- o apaga en el menú de Roblox. Con la cámara bloqueada, el personaje mira hacia donde apunta: ayuda a
-- apuntar el tajo y a encarar la guardia (C5), que solo cubre de frente.
-- Las teclas son del PlayerModule de Roblox, que hoy se carga desde StarterPlayer.PlayerModule y las
-- lee del sistema de acciones de entrada (InputContexts.CameraContext.MouseLockSwitchAction, con un
-- InputBinding por tecla); las versiones antiguas, de PlayerScripts.PlayerModule y su valor
-- "BoundKeys". Aquí se cambian en el propio cliente, sin copiar el módulo.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

-- Mayús → Ctrl (del mismo lado).
local REPLACEMENTS: { [Enum.KeyCode]: Enum.KeyCode } = {
	[Enum.KeyCode.LeftShift] = Enum.KeyCode.LeftControl,
	[Enum.KeyCode.RightShift] = Enum.KeyCode.RightControl,
}
local OLD_KEYS = "LeftControl,RightControl"
local WAIT_SECONDS = 15

local CameraLockController = {}

-- El PlayerModule en uso: el de StarterPlayer (el de ahora) o el de PlayerScripts (antiguo).
local function findPlayerModule(): Instance?
	local deadline = os.clock() + WAIT_SECONDS
	while os.clock() < deadline do
		local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local found = StarterPlayer:FindFirstChild("PlayerModule")
			or (if scripts then scripts:FindFirstChild("PlayerModule") else nil)
		if found then
			return found
		end
		task.wait(0.2)
	end
	return nil
end

function CameraLockController:Start()
	local playerModule = findPlayerModule()
	if not playerModule then
		warn("[CameraLockController] No se encontró el PlayerModule de Roblox")
		return
	end
	local contexts = playerModule:WaitForChild("InputContexts", WAIT_SECONDS)
	local camera = if contexts then contexts:WaitForChild("CameraContext", WAIT_SECONDS) else nil
	local action = if camera then camera:WaitForChild("MouseLockSwitchAction", WAIT_SECONDS) else nil
	if action then
		for _, binding in action:GetDescendants() do
			if binding:IsA("InputBinding") then
				local replacement = REPLACEMENTS[binding.KeyCode]
				if replacement then
					binding.KeyCode = replacement
				end
			end
		end
		return
	end
	-- PlayerModule antiguo.
	local cameraModule = playerModule:FindFirstChild("CameraModule")
	local mouseLock = if cameraModule then cameraModule:FindFirstChild("MouseLockController") else nil
	local boundKeys = if mouseLock then mouseLock:WaitForChild("BoundKeys", WAIT_SECONDS) else nil
	if boundKeys and boundKeys:IsA("StringValue") then
		boundKeys.Value = OLD_KEYS
	else
		warn("[CameraLockController] No se encontraron las teclas del bloqueo de cámara de Roblox")
	end
end

return CameraLockController
