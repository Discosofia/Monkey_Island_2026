--!strict
-- Guardia (Fase 10, C5): F en PC, L2 en mando y el botón táctil "Guardia". Pulsar abre el parry y
-- mantenerla bloquea; lo decide el servidor (Combat/Guard), que pone el estado "Parrying"/"Blocking"
-- (Shared/CombatState) y la barra "Guard" (la dibujan los HUD de cada place).
--   - Al pulsar se manda la hora del servidor en este reloj: el servidor cuenta el parry desde ahí
--     (con tope), así el ping no se come la ventana.
--   - La pose ("Guard" de Shared/Data/WeaponAnimations) sale en cuanto se pulsa y se queda mientras el
--     servidor diga que está en guardia; si no la confirma enseguida (pegando, tambaleado, guardia
--     rota), se quita.
--   - Caído no hay guardia: F vuelve a ser "Rendirse" (LifeController) y el botón desaparece.
--   - Pulsar durante la preparación de un golpe o de una habilidad es un amago (C8, CombatClient/Feint):
--     aquí se cancela lo que se ve al momento y el servidor (Combat/Feint) decide.
-- En guardia se anda más despacio y no se corre (los controladores de movimiento de cada place miran
-- CombatState.isGuarding).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local Feint = require(script.Parent.Parent.Feint)
local WeaponController = require(script.Parent.WeaponController)

local ACTION = "Guard"
-- Lo que se espera a que el servidor confirme la guardia antes de quitar la pose (s).
local CONFIRM_SECONDS = 0.35
local POSE_FADE = 0.08

local GuardController = {}

local pressing = false
local pressedAt = -math.huge
local bound = false

local function setPressed(value: boolean)
	if value == pressing then
		return
	end
	pressing = value
	if value then
		pressedAt = os.clock()
		Feint.try(Players.LocalPlayer.Character)
		Remotes.Guard:FireServer(true, Workspace:GetServerTimeNow())
	else
		Remotes.Guard:FireServer(false)
	end
end

local function onAction(_, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		setPressed(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setPressed(false)
	end
	return Enum.ContextActionResult.Sink
end

-- La guardia solo está enlazada con el jugador vivo (caído, F es "Rendirse").
local function refreshBinding()
	local alive = LifeState.isAlive(Players.LocalPlayer)
	if alive == bound then
		return
	end
	bound = alive
	if alive then
		ActionButtons.bind(ACTION, "Guardia", onAction, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	else
		setPressed(false)
		ActionButtons.unbind(ACTION)
	end
end

-- true si se ve la pose: el servidor dice que está en guardia o se acaba de pulsar y aún puede ponerse.
local function wantsPose(player: Player): boolean
	if CombatState.isGuarding(player) then
		return true
	end
	if not pressing or os.clock() - pressedAt > CONFIRM_SECONDS then
		return false
	end
	local state = CombatState.get(player)
	return state == "Idle"
end

function GuardController:Start()
	local player = Players.LocalPlayer
	refreshBinding()
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refreshBinding)
	player.CharacterAdded:Connect(function()
		setPressed(false)
		refreshBinding()
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then
			return
		end
		local show = wantsPose(player)
		local track = if show then WeaponController.track(character, "Guard") else nil
		if show and track and not track.IsPlaying then
			track:Play(POSE_FADE)
		elseif not show then
			local playing = WeaponController.track(character, "Guard")
			if playing and playing.IsPlaying then
				playing:Stop(POSE_FADE)
			end
		end
	end)
end

return GuardController
