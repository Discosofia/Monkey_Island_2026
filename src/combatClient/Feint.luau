--!strict
-- Amagos en el cliente (Fase 10, C8): la preparación en curso del jugador local (un golpe de la cadena,
-- WeaponController, o una habilidad, RoleController) y su amago. GuardController lo prueba al pulsar la
-- guardia: si se puede, cancela aquí lo que se ve al momento (el tajo, el gesto, el movimiento que iba
-- a salir) y dibuja el humo; el servidor (Combat/Feint) decide lo demás con las mismas reglas
-- (Config.Feint): el del golpe, como mucho uno por segundo; el de una habilidad cuesta estamina (se
-- predice con CombatClient/Stamina) y su recarga corta llega en el atributo "AbilityReadyAt<hueco>".
-- Mientras dura la preparación de una habilidad no se pega ni se usa otra (casting), igual que en el
-- servidor ("Casting" de Shared/CombatState), sin esperar al atributo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local Stamina = require(script.Parent.Stamina)
local AbilityFxController = require(script.Parent.Controllers.AbilityFxController)

local SETTINGS = Config.Feint

export type Kind = "Attack" | "Ability"

type Pending = {
	kind: Kind,
	untilAt: number, -- os.clock en que sale
	cancel: () -> (),
}

local Feint = {}

local pending: Pending? = nil
local lastWeaponFeintAt = -math.huge

-- Empieza una preparación que sale a los "seconds" s; "cancel" deshace lo que se ve si se amaga.
-- Devuelve la marca para "finish".
function Feint.begin(kind: Kind, seconds: number, cancel: () -> ()): any
	local entry: Pending = { kind = kind, untilAt = os.clock() + seconds, cancel = cancel }
	pending = entry
	return entry
end

-- La preparación "mark" ha terminado (ha salido o se ha cortado).
function Feint.finish(mark: any)
	if pending == mark then
		pending = nil
	end
end

-- true mientras prepara una habilidad: no se pega ni se usa otra.
function Feint.casting(): boolean
	return pending ~= nil and pending.kind == "Ability" and os.clock() < pending.untilAt
end

-- Amaga lo que está preparando, si se puede. Solo hasta el retraso de red antes de que salga: después
-- la pulsación llegaría al servidor cuando ya ha salido.
function Feint.try(character: Model?): boolean
	local entry = pending
	if not entry then
		return false
	end
	local ok, ping = pcall(function()
		return Players.LocalPlayer:GetNetworkPing()
	end)
	local lag = if ok and typeof(ping) == "number" then math.clamp(ping, 0, Config.Net.MaxCompensationSeconds) else 0
	if os.clock() >= entry.untilAt - lag then
		return false
	end
	if entry.kind == "Attack" then
		if os.clock() - lastWeaponFeintAt < SETTINGS.WeaponCooldownSeconds then
			return false
		end
		lastWeaponFeintAt = os.clock()
	elseif not Stamina.tryConsume(SETTINGS.AbilityStaminaCost) then
		Toast.show("💨 Sin estamina para amagar")
		return false
	end
	pending = nil
	entry.cancel()
	if character then
		AbilityFxController.play("FeintFx", character)
	end
	return true
end

return Feint
