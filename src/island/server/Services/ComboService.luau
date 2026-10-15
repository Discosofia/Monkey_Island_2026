--!strict
-- Combos de 3 habilidades y racha (Data/Combos, Config.Combo).
--   - Paso 1 (prepara): cuando la habilidad toca a alguien (el cepo atrapa, el hielo congela, la
--     embestida golpea, el dardo alcanza) lo marca y empieza el combo (ComboService.opener).
--   - Pasos 2 y 3: usar la siguiente del combo antes de StepWindowSeconds la enlaza
--     (ComboService.onAbilityUsed, antes de aplicar la habilidad). Durante PayoffSeconds sus golpes
--     contra los marcados son críticos seguros (isComboHit) y el remate hace su efecto extra
--     (isPayoff). Cada paso enlazado que no sea la propia definitiva le quita UltRefundSeconds.
--   - Racha: cada combo completo la sube (x1 → x5). Desde x2, las recargas son StreakCooldownBonus
--     más rápidas por nivel. Se pierde tras StreakSeconds sin hacer daño ni curar (onActivity).
-- El cliente lo ve en los atributos del jugador "ComboStep" (0-3), "ComboStepUntil", "ComboStreak" y
-- "ComboStreakUntil" (hora del servidor); la marca, en "ComboMarkBy"/"ComboMarkUntil" del modelo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combos = require(ReplicatedStorage.Shared.Data.Combos)
local Config = require(ReplicatedStorage.Shared.Config)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local AbilityFx = require(script.Parent.Parent.Combat.AbilityFx)

local SETTINGS = Config.Combo
-- Segundos que se ve "¡COMBO!" (ComboStep = 3) antes de volver a empezar.
local COMPLETE_DISPLAY_SECONDS = 1.5

type State = {
	step: number, -- último paso conseguido (0 = sin combo)
	stepAt: number,
	payoff: string?, -- habilidad enlazada cuyos golpes son críticos contra los marcados
	payoffUntil: number,
	streak: number,
	streakUntil: number,
	marked: { Instance },
}

local ComboService = {}

local states: { [Player]: State } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { step = 0, stepAt = 0, payoff = nil, payoffUntil = 0, streak = 0, streakUntil = 0, marked = {} }
		states[player] = state
	end
	return state
end

-- El combo del rol del jugador.
function ComboService.comboOf(player: Player): Combos.Combo?
	local roleId = player:GetAttribute("Role")
	return if typeof(roleId) == "string" then Combos[roleId] else nil
end

local function publishStep(player: Player, step: number, untilTime: number)
	player:SetAttribute("ComboStep", step)
	player:SetAttribute("ComboStepUntil", untilTime)
end

local function publishStreak(player: Player, state: State)
	player:SetAttribute("ComboStreak", state.streak)
	player:SetAttribute("ComboStreakUntil", state.streakUntil)
end

local function mark(player: Player, state: State, target: Instance, untilTime: number)
	target:SetAttribute("ComboMarkBy", player.UserId)
	target:SetAttribute("ComboMarkUntil", untilTime)
	if not table.find(state.marked, target) then
		table.insert(state.marked, target)
	end
end

-- Alarga las marcas que siguen siendo de este jugador y olvida las demás.
local function extendMarks(player: Player, state: State, untilTime: number)
	local kept = {}
	for _, target in state.marked do
		if target.Parent and target:GetAttribute("ComboMarkBy") == player.UserId then
			local current = target:GetAttribute("ComboMarkUntil")
			if typeof(current) == "number" and current >= now() then
				target:SetAttribute("ComboMarkUntil", math.max(current, untilTime))
				table.insert(kept, target)
			end
		end
	end
	state.marked = kept
end

-- true si "target" lleva la marca de combo de "player".
function ComboService.isMarkedBy(target: Instance, player: Player): boolean
	local untilTime = target:GetAttribute("ComboMarkUntil")
	return target:GetAttribute("ComboMarkBy") == player.UserId and typeof(untilTime) == "number" and now() < untilTime
end

-- La habilidad del primer paso tocó a "target": lo marca y empieza (o renueva) el combo.
function ComboService.opener(player: Player, abilityId: string, target: Instance)
	local combo = ComboService.comboOf(player)
	if not (combo and combo.steps[1] == abilityId) then
		return
	end
	local state = stateOf(player)
	local time = now()
	mark(player, state, target, time + SETTINGS.StepWindowSeconds)
	-- Un cepo que salta a mitad de combo marca, pero no lo vuelve a empezar.
	if state.step >= 2 and time - state.stepAt <= SETTINGS.StepWindowSeconds then
		return
	end
	state.step = 1
	state.stepAt = time
	publishStep(player, 1, time + SETTINGS.StepWindowSeconds)
end

-- Acerca la definitiva del rol.
local function refundUltimate(player: Player, roleId: string)
	for slot, ability in Roles[roleId].abilities do
		if ability.ultimate then
			local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
			if typeof(readyAt) == "number" and readyAt > now() then
				player:SetAttribute(`AbilityReadyAt{slot}`, math.max(now(), readyAt - SETTINGS.UltRefundSeconds))
			end
		end
	end
end

local function isUltimate(roleId: string, abilityId: string): boolean
	for _, ability in Roles[roleId].abilities do
		if ability.id == abilityId then
			return ability.ultimate == true
		end
	end
	return false
end

-- Sube la racha (o la empieza en x1 si ya se había perdido).
local function bumpStreak(player: Player, state: State)
	local time = now()
	state.streak = if time < state.streakUntil then math.min(SETTINGS.MaxStreak, state.streak + 1) else 1
	state.streakUntil = time + SETTINGS.StreakSeconds
	publishStreak(player, state)
end

local function complete(player: Player, state: State, combo: Combos.Combo)
	local time = now()
	bumpStreak(player, state)
	state.step = 0
	publishStep(player, #combo.steps, time + COMPLETE_DISPLAY_SECONDS)
	local character = player.Character
	if character then
		AbilityFx.all("ComboComplete", character, state.streak)
	end
end

-- Llamar justo antes de aplicar una habilidad: si es el siguiente paso del combo, lo enlaza.
-- Devuelve el paso conseguido (2 o 3) o nil.
function ComboService.onAbilityUsed(player: Player, abilityId: string): number?
	local combo = ComboService.comboOf(player)
	local roleId = player:GetAttribute("Role")
	if not (combo and typeof(roleId) == "string" and Roles[roleId]) then
		return nil
	end
	local index = table.find(combo.steps, abilityId)
	if not index or index == 1 then
		return nil
	end
	local state = stateOf(player)
	local time = now()
	if state.step ~= index - 1 or time - state.stepAt > SETTINGS.StepWindowSeconds then
		return nil
	end
	state.step = index
	state.stepAt = time
	state.payoff = abilityId
	state.payoffUntil = time + SETTINGS.PayoffSeconds
	extendMarks(player, state, time + math.max(SETTINGS.StepWindowSeconds, SETTINGS.PayoffSeconds))
	if not isUltimate(roleId, abilityId) then
		refundUltimate(player, roleId)
	end
	if index >= #combo.steps then
		complete(player, state, combo)
	else
		publishStep(player, index, time + SETTINGS.StepWindowSeconds)
	end
	return index
end

-- true durante el efecto de "abilityId" enlazada en el combo (radio extra, curaciones críticas…).
function ComboService.isPayoff(player: Player, abilityId: string): boolean
	local state = states[player]
	return state ~= nil and state.payoff == abilityId and now() < state.payoffUntil
end

-- true si este golpe de "abilityId" contra "target" debe ser crítico por el combo.
function ComboService.isComboHit(player: Player, target: Instance, abilityId: string): boolean
	return ComboService.isPayoff(player, abilityId) and ComboService.isMarkedBy(target, player)
end

-- El jugador ha hecho daño o ha curado: la racha sigue viva.
function ComboService.onActivity(player: Player)
	local state = states[player]
	if not state or state.streak <= 0 then
		return
	end
	local time = now()
	if time >= state.streakUntil then
		state.streak = 0
		publishStreak(player, state)
		return
	end
	local renewed = time + SETTINGS.StreakSeconds
	-- Solo se publica si cambia de forma apreciable (no en cada golpe del Torbellino).
	if renewed - state.streakUntil >= 0.5 then
		state.streakUntil = renewed
		publishStreak(player, state)
	end
end

-- Multiplicador del tiempo de espera de las habilidades por la racha (1 sin racha).
function ComboService.cooldownFactor(player: Player): number
	local state = states[player]
	if not state or state.streak < 2 or now() >= state.streakUntil then
		return 1
	end
	return 1 - SETTINGS.StreakCooldownBonus * (state.streak - 1)
end

local function reset(player: Player)
	states[player] = nil
	publishStep(player, 0, 0)
	player:SetAttribute("ComboStreak", 0)
	player:SetAttribute("ComboStreakUntil", 0)
end

function ComboService:Start()
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("Role"):Connect(function()
			reset(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("Role"):Connect(function()
			reset(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return ComboService
