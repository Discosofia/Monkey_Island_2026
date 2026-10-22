--!strict
-- Evasivo (Fase 10, C7): la respuesta a un combo o a un control. Es la misma esquiva (Q / B /
-- "Esquivar") pulsada estando atrapado: aturdido, con la guardia rota, inmovilizado (el agarre del
-- orangután y de los jefes, el cepo, el hielo) o lanzado (Shared/CombatState.isTrapped).
--   - Quita el aturdido o el agarre, da Config.Evasive.InvulnerableSeconds de invulnerabilidad (estado
--     "Evading"), la inmunidad al control de siempre (Config.Combat.PlayerControlImmunitySeconds) y
--     termina el combo que recibía (Combat/ComboScaling). El salto que aparta lo hace su cliente
--     (DodgeController), como la esquiva.
--   - Recarga Config.Evasive.CooldownSeconds (atributo "EvasiveReadyAt" del Player, que leen el icono
--     del HUD y el botón táctil). No gasta estamina.
--   - Margen de red: vale si estaba atrapado hasta su ping antes (su cliente aún lo veía así), igual
--     para todos y con tope (Combat/Latency).
-- Lo que se ve: ráfaga blanca y azul ("EvasiveFx" en AbilityFxController) y el sonido "Evasive".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local AbilityFx = require(script.Parent.AbilityFx)
local CombatRules = require(script.Parent.CombatRules)
local ComboScaling = require(script.Parent.ComboScaling)
local Guard = require(script.Parent.Guard)
local Latency = require(script.Parent.Latency)
local StateMachine = require(script.Parent.StateMachine)

local SETTINGS = Config.Evasive

local Evasive = {}

local function onEvasive(player: Player)
	if not LifeState.isAlive(player) or not CombatState.canAct(player, "Evasive") then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (character and root and root:IsA("BasePart")) then
		return
	end
	local time = Workspace:GetServerTimeNow()
	local slack = Config.Net.JitterSeconds + 2 * Latency.compensation(player)
	if time > CombatState.trappedUntil(player) + slack or CombatState.evasiveWait(player) > slack then
		return
	end
	player:SetAttribute(CombatState.EVASIVE_ATTRIBUTE, time + SETTINGS.CooldownSeconds)
	-- Suelto: puede andar (los controladores de movimiento miran "StunnedUntil") y no se le puede volver
	-- a sujetar ni aturdir enseguida.
	player:SetAttribute("StunnedUntil", nil)
	player:SetAttribute("LaunchedUntil", nil)
	player:SetAttribute("ControlImmuneUntil", time + Config.Combat.PlayerControlImmunitySeconds)
	player:SetAttribute("InvulnerableUntil", time + SETTINGS.InvulnerableSeconds)
	Guard.drop(player)
	StateMachine.enter(player, "Evading", SETTINGS.InvulnerableSeconds)
	ComboScaling.reset(player)
	AbilityFx.others(player, "EvasiveFx", character)
	Sfx.play("Evasive", root)
	CombatRules.get().telemetry.mechanic(player, "Evasives")
end

-- Lo llama CombatService al empezar.
function Evasive.start()
	Remotes.Evasive.OnServerEvent:Connect(onEvasive)
end

return Evasive
