--!strict
-- Altar de la cima de la pirámide del centro (Fase 10, C11), con los números de Config.Arena.Altar:
--   - Se enciende Altar.FirstSeconds después de empezar la partida.
--   - Encendido, lo toma el equipo que se queda cerca (CaptureRadius en horizontal, hasta CaptureHeight
--     por encima de la cima) CaptureSeconds sin rivales. Con gente de los dos equipos, la barra se para
--     (disputado); si entra el otro equipo solo, primero la vacía y luego la llena para él; sin nadie, se
--     vacía sola en DecaySeconds.
--   - Al tomarlo: BuffSeconds en los que la definitiva (V) de todo ese equipo se recarga UltChargeRate
--     veces más rápido (también a los que esperan para reaparecer). Se apaga y vuelve RespawnSeconds
--     después.
--   - Fuera de la partida, apagado y sin ventaja. Cuenta los que toma cada equipo para los resultados.
-- El estado va en atributos de ReplicatedStorage para el HUD y el altar del mundo (AltarController):
--   "AltarState"        "Off" (fuera de la partida) | "Dormant" (apagado hasta AltarReadyAt) | "Active"
--   "AltarReadyAt"      hora del servidor en que se enciende (apagado)
--   "AltarProgress"     0–1, de "AltarTeam" (el equipo que lo está tomando; nil si nadie)
--   "AltarContested"    true si hay gente de los dos equipos
--   "AltarBuffTeam", "AltarBuffUntil"  equipo con la ventaja y hasta cuándo
--   "ArenaAltars_<equipo>"  altares tomados en esta partida

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local ArenaTelemetryService = require(script.Parent.ArenaTelemetryService)

local TICK_SECONDS = 0.1

local AltarService = {}

local center: Vector3 = Vector3.zero

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function settings()
	return Config.Arena.Altar
end

local function teamText(teamId: string): string
	local team = Config.Arena.Teams[teamId]
	return `{team.icon} {team.name}`
end

local function set(name: string, value: any)
	if ReplicatedStorage:GetAttribute(name) ~= value then
		ReplicatedStorage:SetAttribute(name, value)
	end
end

local function progress(): number
	local value = ReplicatedStorage:GetAttribute("AltarProgress")
	return if typeof(value) == "number" then value else 0
end

local function sleep(seconds: number)
	set("AltarState", "Dormant")
	set("AltarReadyAt", now() + seconds)
	set("AltarProgress", 0)
	set("AltarTeam", nil)
	set("AltarContested", nil)
end

local function reset(phase: Arena.Phase)
	if phase == "Battle" then
		for _, teamId in Arena.TEAM_IDS do
			set(`ArenaAltars_{teamId}`, 0)
		end
		set("AltarBuffTeam", nil)
		set("AltarBuffUntil", nil)
		sleep(settings().FirstSeconds)
	elseif phase ~= "SuddenDeath" then
		set("AltarState", "Off")
		set("AltarReadyAt", nil)
		set("AltarProgress", 0)
		set("AltarTeam", nil)
		set("AltarContested", nil)
		set("AltarBuffTeam", nil)
		set("AltarBuffUntil", nil)
	end
end

-- Los equipos con alguien vivo en el altar (y quiénes son).
local function presence(): ({ [string]: { Player } }, number)
	local teams: { [string]: { Player } } = {}
	local count = 0
	local radius, height = settings().CaptureRadius, settings().CaptureHeight
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if teamId and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and offset.Y >= -1 and offset.Y <= height then
				if not teams[teamId] then
					teams[teamId] = {}
					count += 1
				end
				table.insert(teams[teamId], player)
			end
		end
	end
	return teams, count
end

local function capture(teamId: string, takers: { Player })
	local altar = settings()
	set(`ArenaAltars_{teamId}`, (ReplicatedStorage:GetAttribute(`ArenaAltars_{teamId}`) or 0) + 1)
	set("AltarBuffTeam", teamId)
	set("AltarBuffUntil", now() + altar.BuffSeconds)
	sleep(altar.RespawnSeconds)
	for _, player in takers do
		ArenaTelemetryService.mechanic(player, "AltarCaptures")
	end
	Sfx.play("Revive", center)
	Remotes.Notify:FireAllClients(
		`⛩️ ¡El equipo {teamText(teamId)} toma el altar! Su definitiva se carga el doble de rápido {altar.BuffSeconds} s`
	)
end

-- La ventaja: la recarga de la definitiva de cada uno del equipo avanza (rate − 1) × "elapsed" de más.
local function charge(teamId: string, elapsed: number)
	local extra = (settings().UltChargeRate - 1) * elapsed
	for _, player in Arena.membersOf(teamId) do
		local roleId = player:GetAttribute("Role")
		local role = if typeof(roleId) == "string" then Roles[roleId] else nil
		for slot, ability in if role then role.abilities else {} do
			local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
			if ability.ultimate and typeof(readyAt) == "number" and readyAt > now() then
				player:SetAttribute(`AbilityReadyAt{slot}`, math.max(now(), readyAt - extra))
			end
		end
	end
end

local function tick(elapsed: number)
	if not Arena.inBattle() then
		return
	end
	local altar = settings()
	local buffTeam = ReplicatedStorage:GetAttribute("AltarBuffTeam")
	local buffUntil = ReplicatedStorage:GetAttribute("AltarBuffUntil")
	if Arena.isTeam(buffTeam) and typeof(buffUntil) == "number" then
		if now() < buffUntil then
			charge(buffTeam :: string, math.min(elapsed, buffUntil - now()))
		else
			set("AltarBuffTeam", nil)
			set("AltarBuffUntil", nil)
		end
	end

	local state = ReplicatedStorage:GetAttribute("AltarState")
	if state == "Dormant" then
		local readyAt = ReplicatedStorage:GetAttribute("AltarReadyAt")
		if typeof(readyAt) == "number" and now() >= readyAt then
			set("AltarState", "Active")
			set("AltarReadyAt", nil)
			Remotes.Notify:FireAllClients(
				"⛩️ ¡El altar de la pirámide se ha encendido! Quedaos en lo alto para tomarlo"
			)
		end
		return
	elseif state ~= "Active" then
		return
	end

	local teams, count = presence()
	local owner = ReplicatedStorage:GetAttribute("AltarTeam")
	local value = progress()
	local rate = elapsed / altar.CaptureSeconds
	set("AltarContested", if count >= 2 then true else nil)
	if count == 1 then
		local teamId = next(teams) :: string
		if owner == teamId or value <= 0 then
			value = math.min(1, value + rate)
			set("AltarTeam", teamId)
			if value >= 1 then
				capture(teamId, teams[teamId])
				return
			end
		else
			-- Primero vacía lo que había tomado el otro equipo.
			value = math.max(0, value - rate)
			if value <= 0 then
				set("AltarTeam", nil)
			end
		end
	elseif count == 0 then
		value = math.max(0, value - elapsed / altar.DecaySeconds)
		if value <= 0 then
			set("AltarTeam", nil)
		end
	end
	set("AltarProgress", value)
end

function AltarService:Start()
	-- El altar lo pone World/ArenaBuilder en lo alto de la pirámide (Arena.Altar, con su centro en la
	-- pieza "Captura").
	local model = Workspace:WaitForChild("Arena"):WaitForChild("Altar")
	local zone = model:WaitForChild("Captura") :: BasePart
	center = zone.Position
	reset(Arena.phase())
	ReplicatedStorage:GetAttributeChangedSignal("ArenaPhase"):Connect(function()
		reset(Arena.phase())
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_SECONDS)
			local current = os.clock()
			tick(current - last)
			last = current
		end
	end)
end

return AltarService
