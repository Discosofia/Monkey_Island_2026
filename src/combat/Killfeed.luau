--!strict
-- Registro de bajas (Fase 19, W9): avisa a TODOS los clientes de que alguien ha caído, para que dibujen una
-- fila arriba a la derecha (Shared/UI/Killfeed, montada por CombatClient/KillfeedController).
--   Killfeed.send{ killer = Player | string | nil, victim = Player | string, weaponId = string?, zone = string?, boss = boolean? }
-- "victim" es un jugador o, en un jefe (boss = true), su nombre en español tal cual: el cliente lo traduce.
-- Tope global de Config.Killfeed.MaxPerSecond avisos por segundo (el resto se descarta).
--   Killfeed.fake(jugador, arg): bajas falsas para el panel de pruebas (solo Studio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Entry = {
	killer: (Player | string)?,
	victim: Player | string,
	weaponId: string?,
	zone: string?,
	boss: boolean?,
}

local Killfeed = {}

-- Cuándo (os.clock) salieron los avisos del último segundo.
local recent: { number } = {}

function Killfeed.send(entry: Entry)
	local now = os.clock()
	while recent[1] and now - recent[1] > 1 do
		table.remove(recent, 1)
	end
	if #recent >= Config.Killfeed.MaxPerSecond then
		return
	end
	table.insert(recent, now)

	local killer, victim = entry.killer, entry.victim
	Remotes.Killfeed:FireAllClients({
		killer = if typeof(killer) == "string" then killer elseif killer then killer.DisplayName else nil,
		killerId = if typeof(killer) == "Instance" then killer.UserId else nil,
		victim = if typeof(victim) == "string" then victim else victim.DisplayName,
		victimId = if typeof(victim) == "Instance" then victim.UserId else nil,
		weaponId = entry.weaponId,
		zone = entry.zone,
		boss = entry.boss,
	})
end

-- El arma que lleva el jugador en la mano (o la del Laboratorio, o nil).
local function heldWeapon(player: Player): string?
	local lab = player:GetAttribute("LabWeapon")
	if typeof(lab) == "string" then
		return lab
	end
	local tool = if player.Character then player.Character:FindFirstChildOfClass("Tool") else nil
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	return if typeof(weaponId) == "string" then weaponId else nil
end

-- Panel de pruebas. Sin "arg": una de cada (cabeza, te matan, jefe). "head" | "boss" | "spam" (6 seguidas).
function Killfeed.fake(player: Player, arg: any)
	local weaponId = heldWeapon(player)
	local function head()
		Killfeed.send({ killer = player, victim = "Rival", weaponId = weaponId, zone = "Head" })
	end
	local function killed()
		Killfeed.send({ killer = "Rival", victim = player })
	end
	local function boss()
		Killfeed.send({ killer = player, victim = "Gorila Plateado", boss = true })
	end
	if arg == "head" then
		head()
	elseif arg == "boss" then
		boss()
	elseif arg == "spam" then
		for index = 1, 6 do
			Killfeed.send({ killer = player, victim = `Rival {index}`, weaponId = weaponId })
		end
	else
		head()
		task.delay(0.4, killed)
		task.delay(0.8, boss)
	end
end

return Killfeed
