--!strict
-- Estamina de los jugadores con autoridad del servidor (Fase 10, C2). La gasta correr (el cliente avisa
-- con el remoto Sprint y aquí se mira que se mueva de verdad) y lo que tiene coste (la esquiva y,
-- desde C8, los amagos), y se recupera sola tras Config.Survival.StaminaRegenDelay sin gastar, al ritmo
-- que diga el place (CombatRules.staminaRegenFactor: en la Isla, a la mitad con hambre o sed bajas).
-- Correr no se cobra donde CombatRules.movement.staminaFree (el Lobby).
-- Se publica en el atributo "Stamina" del Player; el cliente la predice con los mismos números
-- (CombatClient/Stamina) y se corrige con ella si se separan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatRules = require(script.Parent.CombatRules)

local SETTINGS = Config.Survival
-- Velocidad horizontal (studs/s) a partir de la cual se cuenta que corre de verdad.
local MOVING_SPEED = 2
-- Cada cuánto se publica el atributo (s), para no mandar un cambio en cada fotograma.
local PUBLISH_SECONDS = 0.2

type State = { value: number, sprinting: boolean, lastSpentAt: number, publishedAt: number }

local StaminaServer = {}

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { value = SETTINGS.StaminaMax, sprinting = false, lastSpentAt = -math.huge, publishedAt = 0 }
		states[player] = state
	end
	return state
end

local function publish(player: Player, state: State)
	state.publishedAt = os.clock()
	player:SetAttribute("Stamina", math.round(state.value))
end

-- Estamina de "player" ahora.
function StaminaServer.get(player: Player): number
	return stateOf(player).value
end

-- Gasta "amount" si hay suficiente. "slack": cuánto le puede faltar (el cliente la predice y puede ir
-- un poco por delante). Devuelve false, sin gastar nada, si no alcanza.
function StaminaServer.tryConsume(player: Player, amount: number, slack: number?): boolean
	local state = stateOf(player)
	if state.value + (slack or 0) < amount then
		return false
	end
	state.value = math.max(0, state.value - amount)
	state.lastSpentAt = os.clock()
	publish(player, state)
	return true
end

local function isMoving(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
end

local function update(deltaTime: number)
	for player, state in states do
		local before = state.value
		-- Montado (Fase 11) no se gasta: corre la montura.
		local mounted = player:GetAttribute("Mounted") ~= nil
		-- Con la regla de movimiento staminaFree (el Lobby) correr no se cobra.
		local free = CombatRules.get().movement.staminaFree
		if state.sprinting and not mounted and not free and state.value > 0 and isMoving(player) then
			local cost = SETTINGS.SprintStaminaPerSecond * Progression.perk(player, "SprintCost")
			state.value = math.max(0, state.value - cost * deltaTime)
			state.lastSpentAt = os.clock()
		elseif os.clock() - state.lastSpentAt >= SETTINGS.StaminaRegenDelay then
			local rate = SETTINGS.StaminaRegenPerSecond * CombatRules.get().staminaRegenFactor(player)
			state.value = math.min(SETTINGS.StaminaMax, state.value + rate * deltaTime)
		end
		-- Como mucho cada PUBLISH_SECONDS, salvo al llenarse (que no se quede en 99).
		local changed = state.value ~= before and os.clock() - state.publishedAt >= PUBLISH_SECONDS
		local filled = state.value == SETTINGS.StaminaMax and player:GetAttribute("Stamina") ~= SETTINGS.StaminaMax
		if changed or filled then
			publish(player, state)
		end
	end
end

-- Lo llama CombatService al empezar.
function StaminaServer.start()
	local function add(player: Player)
		publish(player, stateOf(player))
		player.CharacterAdded:Connect(function()
			-- Reaparece descansado.
			local state = stateOf(player)
			state.value = SETTINGS.StaminaMax
			state.sprinting = false
			publish(player, state)
		end)
	end
	Players.PlayerAdded:Connect(add)
	for _, player in Players:GetPlayers() do
		add(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	Remotes.Sprint.OnServerEvent:Connect(function(player, sprinting: any)
		if typeof(sprinting) == "boolean" then
			stateOf(player).sprinting = sprinting
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return StaminaServer
