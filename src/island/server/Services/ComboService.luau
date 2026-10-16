--!strict
-- Combos de 3 habilidades, conexiones y racha (Data/Combos, Config.Combo). Cada rol tiene dos combos.
--   - Paso 1 (prepara): cuando la habilidad toca a alguien (el cepo atrapa, el hielo congela, la
--     embestida golpea, el dardo alcanza) lo marca y empieza su combo (ComboService.opener). Cada combo
--     del rol empieza con una habilidad distinta: la que usas primero decide cuál está en marcha.
--   - Pasos 2 y 3: usar la siguiente del combo en marcha antes de StepWindowSeconds la enlaza
--     (ComboService.onAbilityUsed, antes de aplicar la habilidad). Si la siguiente aún se está
--     recargando, el plazo cuenta desde que esté lista (stepDeadline). Durante PayoffSeconds sus golpes
--     contra los marcados son críticos seguros con el daño extra de su combo (isComboHit,
--     linkedDamageBonus) y el remate hace su efecto extra (isPayoff). Cada paso enlazado que no sea la
--     propia definitiva le quita UltRefundSeconds, como mucho UltRefundMaxSeconds por recarga.
--   - Conexión: al cerrar un combo, el otro queda abierto en su paso 1 (complete): lo marcado sigue
--     marcado, lo que golpea el remate se marca (touch) y se sigue directamente por su paso 2. Así se
--     encadenan A → B → A… y cada combo cerrado así sube la racha ConnectStreakBonus más.
--   - Racha: cada combo completo la sube (x1 → x5). Desde x2, las recargas son StreakCooldownBonus
--     más rápidas por nivel. Se pierde tras StreakSeconds sin hacer daño ni curar (onActivity).
-- El cliente lo ve en los atributos del jugador "ComboIndex" (qué combo de Data/Combos), "ComboStep"
-- (0-3), "ComboStepUntil", "ComboConnected" (lo abrió una conexión), "ComboChain" (combos cerrados
-- seguidos por conexiones), "ComboStreak" y "ComboStreakUntil" (hora del servidor); la marca, en
-- "ComboMarkBy"/"ComboMarkUntil" del modelo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combos = require(ReplicatedStorage.Shared.Data.Combos)
local Config = require(ReplicatedStorage.Shared.Config)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local AbilityFx = require(script.Parent.Parent.Combat.AbilityFx)
local TelemetryService = require(script.Parent.TelemetryService)

local SETTINGS = Config.Combo
-- Segundos que se ve "¡COMBO!" (ComboStep = 3) antes de volver a empezar.
local COMPLETE_DISPLAY_SECONDS = 1.5

type State = {
	combo: number, -- índice del combo en marcha en Data/Combos[rol] (0 = ninguno)
	step: number, -- último paso conseguido (0 = sin combo)
	stepUntil: number, -- hasta cuándo se puede enlazar el siguiente
	connected: boolean, -- el combo en marcha lo abrió el remate del anterior
	chain: number, -- combos seguidos cerrados por conexiones
	bridge: string?, -- remate que acaba de conectar: lo que golpea se marca para el combo siguiente
	displayUntil: number, -- hasta cuándo se ve "¡COMBO!" (ComboStep = 3) del combo que se acaba de cerrar
	payoffs: { [string]: number }, -- habilidad enlazada → hasta cuándo sus golpes cuentan como de combo
	streak: number,
	streakUntil: number,
	marked: { Instance },
	ultRefunded: number, -- segundos quitados ya a la recarga de la definitiva en curso
}

local ComboService = {}

local states: { [Player]: State } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = {
			combo = 0,
			step = 0,
			stepUntil = 0,
			connected = false,
			chain = 0,
			bridge = nil,
			displayUntil = 0,
			payoffs = {},
			streak = 0,
			streakUntil = 0,
			marked = {},
			ultRefunded = 0,
		}
		states[player] = state
	end
	return state
end

-- Los combos del rol del jugador (vacío si no tiene rol).
function ComboService.combosOf(player: Player): { Combos.Combo }
	local roleId = player:GetAttribute("Role")
	return if typeof(roleId) == "string" then Combos[roleId] or {} else {}
end

-- El combo en marcha del jugador, o nil.
local function activeCombo(player: Player, state: State): Combos.Combo?
	return ComboService.combosOf(player)[state.combo]
end

local function publishStep(player: Player, state: State, step: number, untilTime: number)
	player:SetAttribute("ComboIndex", state.combo)
	player:SetAttribute("ComboChain", state.chain)
	player:SetAttribute("ComboConnected", state.connected)
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

-- Hasta cuándo se puede enlazar el paso "nextIndex" del combo: StepWindowSeconds desde ahora o, si esa
-- habilidad aún se está recargando, desde que esté lista. Sin esto el guerrero perdía el combo si había
-- usado la Embestida (6 s) mientras el Grito (12 s) seguía recargándose.
local function stepDeadline(player: Player, combo: Combos.Combo, nextIndex: number, time: number): number
	local deadline = time + SETTINGS.StepWindowSeconds
	local roleId = player:GetAttribute("Role")
	local nextId = combo.steps[nextIndex]
	if typeof(roleId) ~= "string" or not (Roles[roleId] and nextId) then
		return deadline
	end
	for slot, ability in Roles[roleId].abilities do
		if ability.id == nextId then
			local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
			if typeof(readyAt) == "number" then
				deadline = math.max(deadline, readyAt + SETTINGS.StepWindowSeconds)
			end
		end
	end
	return deadline
end

-- true si "target" lleva la marca de combo de "player".
function ComboService.isMarkedBy(target: Instance, player: Player): boolean
	local untilTime = target:GetAttribute("ComboMarkUntil")
	return target:GetAttribute("ComboMarkBy") == player.UserId and typeof(untilTime) == "number" and now() < untilTime
end

-- La habilidad del primer paso de un combo tocó a "target": lo marca y empieza (o renueva) ese combo.
function ComboService.opener(player: Player, abilityId: string, target: Instance)
	local index = nil
	for candidate, combo in ComboService.combosOf(player) do
		if combo.steps[1] == abilityId then
			index = candidate
			break
		end
	end
	if not index then
		return
	end
	local state = stateOf(player)
	local time = now()
	-- A mitad de un combo (un cepo que salta, un Grito enlazado que también abre el otro) marca para el
	-- combo en marcha, pero no lo cambia ni lo vuelve a empezar.
	if state.step >= 2 and time <= state.stepUntil then
		mark(player, state, target, state.stepUntil)
		return
	end
	local combo = ComboService.combosOf(player)[index]
	-- Lo que toca el paso 1 sigue marcado mientras se pueda enlazar el 2.
	local deadline = stepDeadline(player, combo, 2, time)
	local renewing = state.combo == index and state.step == 1 and time <= state.stepUntil
	if renewing then
		deadline = math.max(deadline, state.stepUntil)
	else
		-- Un combo nuevo empezado a mano: se acaba la cadena de conexiones.
		state.connected = false
		state.chain = 0
	end
	mark(player, state, target, deadline)
	state.combo = index
	state.step = 1
	state.stepUntil = deadline
	-- El remate que conecta puede ser también el paso 1 del otro combo (la Bola de fuego del mago): no
	-- tapa el "¡COMBO!"; el paso 1 se publica al acabar el aviso (complete).
	if not (renewing and time < state.displayUntil) then
		publishStep(player, state, 1, deadline)
	end
end

-- Acerca la definitiva del rol, sin pasar de UltRefundMaxSeconds en cada recarga: así acelera lo
-- mismo a todos los roles, tengan los pasos del combo recargas cortas o largas.
local function refundUltimate(player: Player, state: State, roleId: string)
	for slot, ability in Roles[roleId].abilities do
		if ability.ultimate then
			local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
			if typeof(readyAt) == "number" and readyAt > now() then
				local refund = math.min(
					SETTINGS.UltRefundSeconds,
					SETTINGS.UltRefundMaxSeconds - state.ultRefunded,
					readyAt - now()
				)
				if refund > 0 then
					state.ultRefunded += refund
					player:SetAttribute(`AbilityReadyAt{slot}`, readyAt - refund)
				end
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

-- Sube la racha "levels" niveles (o la empieza en x1 si ya se había perdido).
local function bumpStreak(player: Player, state: State, levels: number)
	local time = now()
	state.streak = if time < state.streakUntil then math.min(SETTINGS.MaxStreak, state.streak + levels) else 1
	state.streakUntil = time + SETTINGS.StreakSeconds
	publishStreak(player, state)
end

-- Cierra el combo en marcha con "abilityId" y deja abierto el siguiente del rol (la conexión).
local function complete(player: Player, state: State, combo: Combos.Combo, abilityId: string)
	local time = now()
	if state.connected then
		state.chain += 1
	end
	bumpStreak(player, state, 1 + (if state.connected then SETTINGS.ConnectStreakBonus else 0))
	TelemetryService.comboCompleted(player, state.streak)
	-- Se ve "¡COMBO!" (o "¡CONEXIÓN!") con el combo que se ha cerrado…
	state.displayUntil = time + COMPLETE_DISPLAY_SECONDS
	publishStep(player, state, #combo.steps, state.displayUntil)
	local character = player.Character
	if character then
		AbilityFx.all("ComboComplete", character, state.streak)
	end
	local combos = ComboService.combosOf(player)
	if #combos < 2 then
		state.combo = 0
		state.step = 0
		return
	end
	-- …y el siguiente queda abierto en su paso 1 cuando acaba el aviso.
	local nextIndex = state.combo % #combos + 1
	local deadline = math.max(stepDeadline(player, combos[nextIndex], 2, time), time + COMPLETE_DISPLAY_SECONDS)
	state.combo = nextIndex
	state.step = 1
	state.stepUntil = deadline
	state.connected = true
	state.bridge = abilityId
	extendMarks(player, state, deadline)
	task.delay(COMPLETE_DISPLAY_SECONDS, function()
		if states[player] == state and state.combo == nextIndex and state.step == 1 then
			publishStep(player, state, 1, state.stepUntil)
		end
	end)
end

-- Llamar justo antes de aplicar una habilidad: si es el siguiente paso del combo en marcha, lo enlaza.
-- Devuelve el paso conseguido (2 o 3) o nil.
function ComboService.onAbilityUsed(player: Player, abilityId: string): number?
	local roleId = player:GetAttribute("Role")
	if not (typeof(roleId) == "string" and Roles[roleId]) then
		return nil
	end
	local state = stateOf(player)
	-- Empieza otra recarga de la definitiva: se puede volver a acercar.
	if isUltimate(roleId, abilityId) then
		state.ultRefunded = 0
	end
	local combo = activeCombo(player, state)
	local time = now()
	if not combo or state.step < 1 or time > state.stepUntil then
		return nil
	end
	local index = state.step + 1
	if combo.steps[index] ~= abilityId then
		return nil
	end
	local deadline = stepDeadline(player, combo, index + 1, time)
	state.step = index
	state.stepUntil = deadline
	state.bridge = nil
	state.payoffs[abilityId] = time + SETTINGS.PayoffSeconds
	extendMarks(player, state, math.max(deadline, time + SETTINGS.PayoffSeconds))
	if not isUltimate(roleId, abilityId) then
		refundUltimate(player, state, roleId)
	end
	if index >= #combo.steps then
		complete(player, state, combo, abilityId)
	else
		publishStep(player, state, index, deadline)
	end
	return index
end

-- Un golpe o una curación de "abilityId" alcanzó a "target". Si es el remate que acaba de conectar,
-- lo marca para el combo que ha quedado abierto (AbilityService.hurt y heal).
function ComboService.touch(player: Player, abilityId: string, target: Instance)
	local state = states[player]
	if not (state and state.bridge == abilityId and state.step == 1 and now() <= state.stepUntil) then
		return
	end
	mark(player, state, target, state.stepUntil)
end

-- true durante el efecto de "abilityId" enlazada en el combo (radio extra, curaciones críticas…).
function ComboService.isPayoff(player: Player, abilityId: string): boolean
	local state = states[player]
	local untilTime = if state then state.payoffs[abilityId] else nil
	return untilTime ~= nil and now() < untilTime
end

-- true si este golpe de "abilityId" contra "target" debe ser crítico por el combo.
function ComboService.isComboHit(player: Player, target: Instance, abilityId: string): boolean
	return ComboService.isPayoff(player, abilityId) and ComboService.isMarkedBy(target, player)
end

-- Daño extra (fracción) de los golpes de combo de "abilityId" ("damageBonus" del combo en el que se
-- enlazó en Data/Combos).
function ComboService.linkedDamageBonus(player: Player, abilityId: string): number
	local best = 0
	for _, combo in ComboService.combosOf(player) do
		local index = table.find(combo.steps, abilityId)
		if index and index > 1 then
			best = math.max(best, combo.damageBonus or 0)
		end
	end
	return best
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
	player:SetAttribute("ComboIndex", 0)
	player:SetAttribute("ComboChain", 0)
	player:SetAttribute("ComboConnected", false)
	player:SetAttribute("ComboStep", 0)
	player:SetAttribute("ComboStepUntil", 0)
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
