--!strict
-- Guardia de los jugadores (Fase 10, C5): bloqueo, parry y rotura. El cliente (GuardController) manda
-- el remoto Guard al pulsar (con la hora del servidor en su reloj) y al soltar; aquí se decide todo.
--   - Pulsar abre el parry (estado "Parrying", Config.Guard.ParryWindowSeconds, aunque se suelte
--     enseguida); no se vuelve a abrir hasta pasado ParryRearmSeconds (pulsar sin parar solo bloquea).
--     Mantenerla bloquea ("Blocking", sin fin hasta soltar). En guardia no se pega ni se usan
--     habilidades, se anda más despacio y no se corre (CombatState.isGuarding). Esquivar la suelta.
--   - Si se pulsa mientras pega o está tambaleado, la guardia se pone al acabar (si sigue pulsando).
--     Durante la preparación de un golpe o de una habilidad, pulsar es un amago (C8, Combat/Feint): la
--     cancela y la guardia se pone en ese momento.
--   - Barra "Guard" (atributo del Player, 0–Max): cada golpe bloqueado gasta su "guardDamage" y se
--     recupera sola tras RegenDelaySeconds sin recibir. Vacía: guardia rota (estado "GuardBroken",
--     Status.stunPlayer con su inmunidad) y hay que volver a pulsar.
--   - Solo cubre de frente (BlockAngle). Un golpe imbloqueable a quien está en guardia la rompe y entra
--     entero.
--   - Parry: el golpe no entra, devuelve ParryGuardRefund de guardia y, si el atacante pega de cerca
--     (ParryStaggerRange), le tambalea (un jugador, "Staggered"; un mono, aturdido; los jefes se
--     resisten). El atributo "ParryAt" del Player (hora del servidor) lo lee el HUD.
--   - Margen a favor del defensor (grace): CombatService espera hasta min(ping, ParryGraceMaxSeconds)
--     antes de resolver un golpe de arma en PvP, y la pulsación cuenta desde la hora de su cliente
--     (como mucho ese margen antes de llegar). Igual para todos y con tope.
-- Los monos y los jefes (C6, Combat/EnemyAttack) también esperan ese margen al acabar su preparación.
-- Orden en CombatService: invulnerable → parry → bloqueo → armadura → tótem → Grito → escudo.
-- Lo que se ve y se oye: destello dorado (parry), chispa (bloqueo) y estallido naranja con grietas
-- (rotura), en AbilityFxController ("GuardFx"), y los sonidos "Parry", "Block" y "GuardBreak". Cada
-- uno se cuenta en la telemetría (C7: Parries, Blocks y GuardBreaks).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local AbilityFx = require(script.Parent.AbilityFx)
local CombatRules = require(script.Parent.CombatRules)
local Feint = require(script.Parent.Feint)
local Latency = require(script.Parent.Latency)
local StateMachine = require(script.Parent.StateMachine)
local Status = require(script.Parent.Status)

local SETTINGS = Config.Guard
local ATTRIBUTE = "Guard"
-- Cada cuánto se recupera y se publica la barra (s).
local REGEN_STEP = 0.1
-- Un golpe defendido cuenta para "defended" durante esto (lo que tarda una habilidad en aplicar su
-- control después de su daño, en el mismo instante).
local DEFENDED_SECONDS = 0.1
-- Un margen más corto que un fotograma no merece esperar.
local MIN_GRACE = 1 / 60

export type Outcome = "Hit" | "Blocked" | "Parried" | "Broken"

-- Un golpe que se puede defender.
export type Hit = {
	guardDamage: number, -- guardia que gasta si se bloquea
	from: Vector3?, -- de dónde viene (para el cono de delante); sin él, de frente
	attacker: Model?, -- quién pega: a quien tambalea un parry, si está cerca
	unblockable: boolean?, -- rompe la guardia y entra entero
	enemy: boolean?, -- lo da un mono o un jefe (Config.Guard.BlockReductionEnemies)
	at: number?, -- hora del servidor del golpe, si se resuelve más tarde (el margen del defensor)
}

type State = {
	value: number,
	holding: boolean, -- mantiene pulsado
	lastHitAt: number, -- último golpe que gastó guardia (os.clock)
	lastParryAt: number, -- última vez que se abrió el parry (hora del servidor)
	parryFrom: number,
	parryUntil: number,
	guardFrom: number, -- desde cuándo está en guardia (hora del servidor, con el margen del cliente)
	defendedAt: number,
	ticket: number, -- para el paso de parry a bloqueo
}

local Guard = {}

local states: { [Player]: State } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = {
			value = SETTINGS.Max,
			holding = false,
			lastHitAt = -math.huge,
			lastParryAt = -math.huge,
			parryFrom = -math.huge,
			parryUntil = -math.huge,
			guardFrom = math.huge,
			defendedAt = -math.huge,
			ticket = 0,
		}
		states[player] = state
	end
	return state
end

local function publish(player: Player, state: State)
	local value = math.round(state.value)
	if player:GetAttribute(ATTRIBUTE) ~= value then
		player:SetAttribute(ATTRIBUTE, value)
	end
end

local function rootOf(model: Model?): BasePart?
	local root = if model then model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Guardia de "player" ahora (0–Max).
function Guard.value(player: Player): number
	return stateOf(player).value
end

-- Guardia que gasta el golpe básico de un mono o un jefe (Config.Guard: por categoría, ×alfa).
function Guard.enemyDamage(model: Model): number
	if Status.isBoss(model) then
		return SETTINGS.BossGuardDamage
	end
	local speciesId = model:GetAttribute("MonkeyType")
	local species = if typeof(speciesId) == "string" then Monkeys[speciesId] else nil
	local damage = SETTINGS.MonkeyGuardDamage[if species then species.tier else 1] or SETTINGS.MonkeyGuardDamage[1]
	if model:GetAttribute("Alpha") == true then
		damage *= SETTINGS.AlphaGuardMultiplier
	end
	return damage
end

-- El golpe básico de un mono o de un jefe, listo para CombatService.damagePlayer.
function Guard.enemyHit(model: Model): Hit
	local root = rootOf(model)
	return {
		guardDamage = Guard.enemyDamage(model),
		from = if root then root.Position else nil,
		attacker = model,
		enemy = true,
	}
end

-- Suelta la guardia (al soltar la tecla). "closeParry": también cierra la ventana del parry (al
-- esquivar o al romperse).
local function stop(player: Player, state: State, closeParry: boolean?)
	state.ticket += 1
	state.guardFrom = math.huge
	StateMachine.leave(player, "Blocking")
	if closeParry then
		state.parryUntil = -math.huge
		StateMachine.leave(player, "Parrying")
	end
end

-- Pone la guardia. "pressedAt": hora del servidor en el reloj del cliente al pulsar (con tope).
local function start(player: Player, pressedAt: number?)
	local state = stateOf(player)
	if not (state.holding and LifeState.isAlive(player)) or state.value <= 0 then
		return
	end
	local current = CombatState.get(player)
	if current == "Blocking" or current == "Parrying" or not CombatState.canAct(player, "Guard") then
		return
	end
	-- Pegando o tambaleado: se pone al acabar, si sigue pulsando (lo vigila Guard.start).
	if current ~= "Idle" then
		return
	end
	local time = now()
	local grace = math.min(Latency.compensation(player), Config.Net.ParryGraceMaxSeconds)
	local from = math.clamp(pressedAt or time, time - grace, time)
	state.ticket += 1
	local ticket = state.ticket
	state.guardFrom = from
	if time - state.lastParryAt < SETTINGS.ParryRearmSeconds then
		StateMachine.enter(player, "Blocking")
		return
	end
	state.lastParryAt = time
	state.parryFrom = from
	state.parryUntil = from + SETTINGS.ParryWindowSeconds
	StateMachine.enter(player, "Parrying", state.parryUntil - time)
	-- Al cerrarse la ventana: bloquea si sigue pulsando; si no, se acaba.
	task.delay(state.parryUntil - time, function()
		if state.ticket ~= ticket or not player.Parent then
			return
		end
		if state.holding and CombatState.get(player) == "Idle" and LifeState.isAlive(player) then
			StateMachine.enter(player, "Blocking")
		else
			state.guardFrom = math.huge
		end
	end)
end

local function onGuard(player: Player, pressed: any, clientTime: any)
	local state = stateOf(player)
	if pressed == true then
		state.holding = true
		-- Preparando un golpe o una habilidad: amaga si puede (y la guardia se pone ya).
		Feint.try(player)
		start(player, if typeof(clientTime) == "number" then clientTime else nil)
	else
		state.holding = false
		-- La ventana del parry sigue abierta aunque se suelte: pulsar es parry; mantener, bloqueo.
		if CombatState.get(player) == "Blocking" then
			stop(player, state)
		end
	end
end

-- Esquivar suelta la guardia (CombatService.onDodge); hay que volver a pulsar.
function Guard.drop(player: Player)
	local state = stateOf(player)
	state.holding = false
	stop(player, state, true)
end

-- Segundos que hay que esperar para resolver un golpe de arma a "player" (su margen para el parry): 0
-- si ya está en guardia o si no podría abrir el parry.
function Guard.grace(player: Player): number
	local state = stateOf(player)
	if CombatState.isGuarding(player) or now() - state.lastParryAt < SETTINGS.ParryRearmSeconds then
		return 0
	end
	local grace = math.min(Latency.compensation(player), Config.Net.ParryGraceMaxSeconds)
	return if grace >= MIN_GRACE then grace else 0
end

-- true si "player" acaba de bloquear o parar un golpe: las habilidades no le aplican su control.
function Guard.defended(player: Player): boolean
	return os.clock() - stateOf(player).defendedAt <= DEFENDED_SECONDS
end

-- true si el golpe que viene de "from" le llega a "player" por delante (Config.Guard.BlockAngle).
local function facing(player: Player, from: Vector3?): boolean
	local root = rootOf(player.Character)
	if not (root and from) then
		return true
	end
	local offset = (from - root.Position) * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.5 or look.Magnitude < 0.1 then
		return true
	end
	return offset.Unit:Dot(look.Unit) >= math.cos(math.rad(SETTINGS.BlockAngle / 2))
end

local function guardFx(player: Player, kind: string)
	local character = player.Character
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	AbilityFx.all("GuardFx", character, kind)
	Sfx.play(if kind == "Parry" then "Parry" elseif kind == "Break" then "GuardBreak" else "Block", root)
	CombatRules.get().telemetry
		.mechanic(player, if kind == "Parry" then "Parries" elseif kind == "Break" then "GuardBreaks" else "Blocks")
end

-- Rompe la guardia: aturdido "GuardBroken" (con la inmunidad de Status; si la rompe un jugador, ×el
-- control del place) y hay que volver a pulsar.
local function breakGuard(player: Player, state: State, hit: Hit)
	state.value = 0
	state.holding = false
	state.lastHitAt = os.clock()
	stop(player, state, true)
	publish(player, state)
	guardFx(player, "Break")
	local seconds = SETTINGS.BreakStunSeconds
	if not hit.enemy then
		seconds *= CombatRules.get().pvpControlMultiplier
	end
	Status.stunPlayer(player, seconds, "GuardBreak", "GuardBroken")
end

-- El parry tambalea al atacante si pega de cerca: a un jugador, "Staggered"; a un mono o un jefe,
-- aturdido (los jefes se resisten en Status.stun).
local function staggerAttacker(player: Player, attacker: Model?)
	local root = rootOf(player.Character)
	local attackerRoot = rootOf(attacker)
	if not (attacker and root and attackerRoot) then
		return
	end
	if (attackerRoot.Position - root.Position).Magnitude > SETTINGS.ParryStaggerRange then
		return
	end
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	if attackerPlayer then
		StateMachine.enter(attackerPlayer, "Staggered", SETTINGS.ParryStaggerPvP)
	else
		Status.stun(attacker, SETTINGS.ParryStaggerMonkey)
	end
end

-- Decide qué pasa con el golpe "hit" que le llega a "player" en el instante "at" (hora del servidor;
-- por defecto, ahora) y aplica la guardia que gasta, la rotura o el parry. Devuelve el resultado y la
-- fracción del daño que entra (0 en un parry).
function Guard.resolve(player: Player, hit: Hit, at: number?): (Outcome, number)
	local state = stateOf(player)
	local time = at or hit.at or now()
	local guarding = state.guardFrom <= time + 1e-3 and CombatState.isGuarding(player)
	local parrying = time >= state.parryFrom - 1e-3 and time <= state.parryUntil + 1e-3
	if not (guarding or parrying) or not facing(player, hit.from) then
		return "Hit", 1
	end
	if hit.unblockable then
		breakGuard(player, state, hit)
		return "Broken", 1
	end
	state.defendedAt = os.clock()
	if parrying then
		state.value = math.min(SETTINGS.Max, state.value + SETTINGS.ParryGuardRefund)
		publish(player, state)
		player:SetAttribute("ParryAt", now())
		guardFx(player, "Parry")
		staggerAttacker(player, hit.attacker)
		return "Parried", 0
	end
	local scale = 1 - (if hit.enemy then SETTINGS.BlockReductionEnemies else SETTINGS.BlockReduction)
	state.value -= hit.guardDamage
	state.lastHitAt = os.clock()
	if state.value <= 0 then
		breakGuard(player, state, hit)
		return "Broken", scale
	end
	publish(player, state)
	guardFx(player, "Block")
	return "Blocked", scale
end

-- Lo llama CombatService al empezar.
function Guard.start()
	Remotes.Guard.OnServerEvent:Connect(onGuard)

	local function watch(player: Player)
		local state = stateOf(player)
		publish(player, state)
		player.CharacterAdded:Connect(function()
			state.value = SETTINGS.Max
			state.holding = false
			state.ticket += 1
			state.guardFrom = math.huge
			state.parryUntil = -math.huge
			publish(player, state)
		end)
		-- Un tambaleo o un aturdido le quitó el bloqueo: si sigue pulsando, vuelve al acabar.
		player:GetAttributeChangedSignal(CombatState.ATTRIBUTE):Connect(function()
			if state.holding and player:GetAttribute(CombatState.ATTRIBUTE) == nil then
				task.defer(start, player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	-- Recuperación: tras RegenDelaySeconds sin recibir golpes, también bloqueando.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < REGEN_STEP then
			return
		end
		local step = elapsed
		elapsed = 0
		local clock = os.clock()
		for player, state in states do
			if state.value < SETTINGS.Max and clock - state.lastHitAt >= SETTINGS.RegenDelaySeconds then
				state.value = math.min(SETTINGS.Max, state.value + SETTINGS.RegenPerSecond * step)
				publish(player, state)
			end
		end
	end)
end

return Guard
