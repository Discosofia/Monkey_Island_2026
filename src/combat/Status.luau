--!strict
-- Estados que las habilidades de los roles ponen a los enemigos (monos, jefes, muñecos). Se guardan
-- como atributos del modelo con la hora del servidor en que terminan; la IA de los monos
-- (MonkeyService) y la de los jefes (BossService) los consultan en cada vuelta.
--   - Aturdido ("StunnedUntil"): no se mueve ni ataca. Lo usan aturdir, congelar e inmovilizar.
--     Los jefes se resisten (Config.Abilities.BossControlMultiplier). Rendimientos decrecientes
--     (Fase 10, C6; Config.ControlDR), por modelo: cada control seguido dura menos y después es
--     inmune un rato; "ControlResistedAt" (hora del servidor) avisa a los clientes de que lo ha resistido.
--   - Ralentizado ("SlowedUntil" y "SlowFactor"): anda más despacio.
--   - Provocado ("TauntedBy" y "TauntedUntil"): va a por el jugador que le provocó.
--   - Envenenado ("PoisonedUntil"): pierde vida cada Config.Abilities.PoisonTickSeconds (poison).
--   - Expuesto ("ExposedUntil" y "ExposedBonus"): recibe más daño (CombatService.damage).
-- También deja quietos (holdPlayer) o aturde (stunPlayer) a los jugadores, con su propia regla para
-- no encadenarlo (y, los de otros jugadores, con rendimientos decrecientes: C7).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CombatRules = require(script.Parent.CombatRules)
local StateMachine = require(script.Parent.StateMachine)

local Status = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function active(model: Model, attribute: string): boolean
	local untilTime = model:GetAttribute(attribute)
	return typeof(untilTime) == "number" and now() < untilTime
end

-- Contorno de color mientras dura un estado.
local function outline(model: Model, name: string, color: Color3, seconds: number)
	local old = model:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = name
	highlight.FillColor = color
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, seconds)
end

function Status.isBoss(model: Model): boolean
	return model:GetAttribute("Boss") ~= nil
end

-- Rendimientos decrecientes del control (Config.ControlDR), por modelo: cuántos controles seguidos
-- lleva y cuándo empezó el último que le entró. Se reinicia tras ResetSeconds sin ninguno.
-- Desde C7 también por jugador, para los controles de otros jugadores (holdPlayer con "PvP").
type Diminishing = { index: number, lastAt: number }
local diminishing: { [Instance]: Diminishing } = setmetatable({} :: any, { __mode = "k" })

-- Fracción que le dura el siguiente control a "model" (0 = inmune) y lo apunta.
local function diminish(model: Instance): number
	local settings = Config.ControlDR
	local time = now()
	local entry = diminishing[model]
	if not entry or time - entry.lastAt >= settings.ResetSeconds then
		entry = { index = 1, lastAt = time }
		diminishing[model] = entry
	end
	local factor = settings.Steps[entry.index] or 0
	if factor > 0 then
		entry.index += 1
		entry.lastAt = time
	end
	return factor
end

-- Aturde (o congela, o inmoviliza, o duerme). Aturdido lleva un contorno amarillo; el bloque de hielo
-- del congelado, el brillo verde del inmovilizado y los "Zzz" del dormido los dibuja cada cliente
-- (AbilityFxController). Todo control a un enemigo pasa por aquí: habilidades, el parry y el remate de
-- la cadena. Devuelve los segundos que dura de verdad (los jefes se resisten y cada control seguido
-- dura menos); 0 si es inmune.
function Status.stun(model: Model, seconds: number, look: ("Stun" | "Freeze" | "Root" | "Sleep")?): number
	if Status.isBoss(model) then
		seconds *= Config.Abilities.BossControlMultiplier
	end
	seconds *= diminish(model)
	if seconds <= 0 then
		model:SetAttribute("ControlResistedAt", now())
		return 0
	end
	local untilTime = now() + seconds
	local current = model:GetAttribute("StunnedUntil")
	if typeof(current) ~= "number" or current < untilTime then
		model:SetAttribute("StunnedUntil", untilTime)
	end
	if look ~= "Freeze" and look ~= "Root" and look ~= "Sleep" then
		outline(model, "StatusOutline", Color3.fromRGB(255, 230, 90), seconds)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
	return seconds
end

-- Inmoviliza a un jugador (agarre del orangután y de los jefes, cepo, hielo): no anda ("StunnedUntil",
-- que leen los controladores de movimiento), pero puede pegar, usar habilidades y esquivar. Para que
-- nadie le tenga sujeto siempre (un orangután que pega más a menudo de lo que dura su agarre, dos
-- gorilas turnándose…), mientras está quieto otro control (este o stunPlayer) no lo alarga y, al
-- soltarse, tiene Config.Combat.PlayerControlImmunitySeconds en los que no se le puede volver a
-- sujetar ni aturdir. "cause" es para la telemetría (CombatRules.telemetry.causeOf). Los de otros
-- jugadores (cause "PvP", C7) llevan además los rendimientos decrecientes de Config.ControlDR, por
-- jugador: cada uno seguido dura menos y luego no entra hasta ResetSeconds sin ninguno. Se sale con el
-- Evasivo (Combat/Evasive). Devuelve true si le ha sujetado.
function Status.holdPlayer(player: Player, seconds: number, cause: string): boolean
	local time = now()
	local immuneUntil = player:GetAttribute("ControlImmuneUntil")
	if seconds <= 0 or (typeof(immuneUntil) == "number" and time < immuneUntil) then
		return false
	end
	if cause == "PvP" then
		seconds *= diminish(player)
		if seconds <= 0 then
			return false
		end
	end
	player:SetAttribute("StunnedUntil", time + seconds)
	player:SetAttribute("ControlImmuneUntil", time + seconds + Config.Combat.PlayerControlImmunitySeconds)
	CombatRules.get().telemetry.held(player, seconds, cause)
	return true
end

-- Aturde a un jugador (Fase 10, C2; pisotones, embestidas de jefe, golpes fuertes, control de
-- habilidades en PvP): como holdPlayer, y además no pega, ni usa habilidades, ni esquiva ni se
-- defiende (estado "Stunned" de Shared/CombatState); sale con el Evasivo (C7). Misma regla de
-- inmunidad (y de rendimientos decrecientes en PvP) que holdPlayer. Devuelve true si le ha aturdido. "state": "GuardBroken" para la guardia
-- rota (Combat/Guard), que es un aturdido con su propio aspecto.
function Status.stunPlayer(player: Player, seconds: number, cause: string, state: ("Stunned" | "GuardBroken")?): boolean
	if not Status.holdPlayer(player, seconds, cause) then
		return false
	end
	-- Lo que dura de verdad (holdPlayer lo acorta en PvP).
	local stunnedUntil = player:GetAttribute("StunnedUntil")
	StateMachine.enter(
		player,
		state or "Stunned",
		if typeof(stunnedUntil) == "number" then stunnedUntil - now() else seconds
	)
	return true
end

-- Ralentiza a "model" a "factor" de su velocidad. No recorta una lentitud igual o más fuerte que dure
-- más (C10: las zonas la renuevan cada poco).
function Status.slow(model: Model, seconds: number, factor: number)
	local untilTime = now() + seconds
	local current = model:GetAttribute("SlowedUntil")
	local currentFactor = model:GetAttribute("SlowFactor")
	if
		typeof(current) == "number"
		and current > untilTime
		and typeof(currentFactor) == "number"
		and currentFactor <= factor
	then
		return
	end
	model:SetAttribute("SlowedUntil", untilTime)
	model:SetAttribute("SlowFactor", factor)
end

function Status.taunt(model: Model, player: Player, seconds: number)
	model:SetAttribute("TauntedBy", player.UserId)
	model:SetAttribute("TauntedUntil", now() + seconds)
end

-- Los dormidos del remate de "Nana de la selva": reciben "bonus" (fracción) más de daño. El "+30 %"
-- sobre el "💤" lo dibuja cada cliente (AbilityFxController).
function Status.expose(model: Model, bonus: number, seconds: number)
	model:SetAttribute("ExposedUntil", now() + seconds)
	model:SetAttribute("ExposedBonus", bonus)
end

type PoisonDamage = (model: Model, humanoid: Humanoid, amount: number, attacker: Player?, source: string) -> ()
type Poison = { dps: number, attacker: Player?, source: string }

-- Quién aplica cada golpe del veneno: CombatService lo registra al empezar (así este módulo no
-- depende de CombatService, que sí depende de él para los dardos).
local poisonDamage: PoisonDamage? = nil
local poisoned: { [Model]: Poison } = {}

function Status.setPoisonDamage(callback: PoisonDamage)
	poisonDamage = callback
end

-- Envenena a un enemigo: "dps" de daño por segundo durante "seconds", en golpes cada
-- Config.Abilities.PoisonTickSeconds a nombre de "attacker" (botín, racha, telemetría con "source").
-- No se acumula: uno igual o más fuerte lo renueva (y pasa a ser de quien lo puso); uno más flojo no
-- hace nada mientras dure el otro. Lo usan las cerbatanas del médico y el remate de "Cura de
-- urgencia"; las burbujas moradas salen del atributo "PoisonedUntil" en cada cliente.
function Status.poison(model: Model, dps: number, seconds: number, attacker: Player?, source: string)
	if dps <= 0 or seconds <= 0 then
		return
	end
	local current = poisoned[model]
	if current and current.dps > dps and active(model, "PoisonedUntil") then
		return
	end
	model:SetAttribute("PoisonedUntil", now() + seconds)
	poisoned[model] = { dps = dps, attacker = attacker, source = source }
	if current then
		-- Ya hay un goteo en marcha: sigue con el veneno nuevo.
		return
	end
	task.spawn(function()
		local tick = Config.Abilities.PoisonTickSeconds
		while true do
			task.wait(tick)
			local poison = poisoned[model]
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local untilTime = model:GetAttribute("PoisonedUntil")
			-- Con un poco de margen: el último golpe cae justo cuando se acaba.
			local still = typeof(untilTime) == "number" and now() <= untilTime + 0.1
			if not (poison and still and model.Parent and humanoid and humanoid.Health > 0) then
				break
			end
			if poisonDamage then
				poisonDamage(model, humanoid, poison.dps * tick, poison.attacker, poison.source)
			end
		end
		poisoned[model] = nil
		-- Si ha caído antes de que se acabe, que no siga burbujeando.
		model:SetAttribute("PoisonedUntil", nil)
	end)
end

function Status.isStunned(model: Model): boolean
	return active(model, "StunnedUntil")
end

-- Fracción de su velocidad normal con la que anda (1 = normal).
function Status.speedFactor(model: Model): number
	local factor = model:GetAttribute("SlowFactor")
	if active(model, "SlowedUntil") and typeof(factor) == "number" then
		return factor
	end
	return 1
end

-- Jugador vivo que le está provocando, o nil.
function Status.tauntTarget(model: Model): Player?
	local userId = model:GetAttribute("TauntedBy")
	if not active(model, "TauntedUntil") or typeof(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

return Status
