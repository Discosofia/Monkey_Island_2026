--!strict
-- Números flotantes de combate. El servidor dice a quién, cuánto, de qué tipo y si fue crítico; los
-- dibuja cada cliente (CombatTextController) según sus ajustes, así cada jugador ve sus números como
-- prefiera y no se crean piezas en el servidor.
--   - "Taken": daño que recibe un jugador (rojo, a la izquierda de su cabeza).
--   - "Heal": curación de un jugador (verde, a la derecha).
--   - "Dealt": daño a un enemigo (amarillo, sobre su cabeza).
--   - "Absorbed": un golpe que el Escudo de hojas paró entero (🛡️).
-- Se mandan en lotes cada Config.CombatText.MergeSeconds; los golpes iguales (mismo objetivo, tipo,
-- autor y crítico) de un lote se suman en un número: el abanico de flechas, la Lluvia…

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Kind = "Taken" | "Heal" | "Dealt" | "Absorbed"
type Entry = { target: Instance, amount: number, kind: Kind, crit: boolean, by: number?, pet: boolean? }

local CombatText = {}

local pending: { Entry } = {}
local lastFlush = 0
local connected = false

local function flush()
	if #pending == 0 then
		return
	end
	local batch: { Entry } = {}
	for _, entry in pending do
		entry.amount = math.round(entry.amount)
		-- Un goteo de menos de medio punto (hambre, fiebre) no se enseña.
		if entry.amount > 0 or entry.kind == "Absorbed" then
			table.insert(batch, entry)
		end
	end
	pending = {}
	if #batch > 0 then
		Remotes.CombatText:FireAllClients(batch)
	end
end

local function add(target: Instance?, amount: number, kind: Kind, crit: boolean?, by: Player?, pet: boolean?)
	if not target or (amount <= 0 and kind ~= "Absorbed") then
		return
	end
	local byId = if by then by.UserId else nil
	local isCrit = crit == true
	for _, entry in pending do
		if
			entry.target == target
			and entry.kind == kind
			and entry.by == byId
			and entry.crit == isCrit
			and entry.pet == pet
		then
			entry.amount += amount
			return
		end
	end
	table.insert(pending, { target = target, amount = amount, kind = kind, crit = isCrit, by = byId, pet = pet })
	if not connected then
		connected = true
		RunService.Heartbeat:Connect(function()
			if os.clock() - lastFlush >= Config.CombatText.MergeSeconds then
				lastFlush = os.clock()
				flush()
			end
		end)
	end
end

-- Daño que recibe "player". "by": quién le pegó (solo en PvP).
function CombatText.taken(player: Player, amount: number, crit: boolean?, by: Player?)
	add(player.Character, amount, "Taken", crit, by)
end

-- Curación de "player". "by": quién le curó (el médico, o el propio jugador con su mascota).
function CombatText.heal(player: Player, amount: number, crit: boolean?, by: Player?, pet: boolean?)
	add(player.Character, amount, "Heal", crit, by, pet)
end

-- Daño a un enemigo ("model"). "by": el jugador que lo hizo (o el dueño de la mascota).
function CombatText.dealt(model: Model, amount: number, crit: boolean?, by: Player?, pet: boolean?)
	add(model, amount, "Dealt", crit, by, pet)
end

-- Golpe parado entero por el escudo.
function CombatText.absorbed(player: Player, by: Player?)
	add(player.Character, 0, "Absorbed", false, by)
end

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if not character then
		return
	end
	for index = #pending, 1, -1 do
		if pending[index].target == (character :: Instance) then
			table.remove(pending, index)
		end
	end
end)

return CombatText
