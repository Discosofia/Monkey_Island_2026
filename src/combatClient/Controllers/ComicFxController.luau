--!strict
-- Efectos de cómic del combate (UI/ComicBurst): un estallido corto con una palabra sobre el enemigo al
-- que golpeas y junto a ti cuando te pegan fuerte. Se entera de los golpes por el mismo aviso que los
-- números (Remotes.CombatText), así que no necesita nada propio del servidor.
--   - "Hit": tus golpes normales ("BAM!", "PEW!" con armas a distancia, "ZAP!" con hechizos), como
--     mucho uno por enemigo cada Config.ComicFx.HitCooldownSeconds.
--   - "Crit": tus críticos ("POW!").
--   - "KO": el golpe tuyo que derriba al enemigo ("K.O.!"; el servidor lo marca con "ko"), también el
--     de tu veneno (sus golpes de cada segundo no hacen nada más).
--   - "Hurt": lo que te quita al menos HurtFraction de tu vida máxima o es crítico ("OUCH!").
--   - La guardia (Fase 10, C12), por el aviso "GuardFx" de Remotes.AbilityFx: "¡PARRY!" y "¡GUARDIA
--     ROTA!" sobre ti o sobre un jugador a menos de GuardNearbyStuds (en la arena, el rival que te para
--     el golpe), y "¡CONTRA!" con tu primer golpe, hasta CounterSeconds tras tu parry, a un enemigo
--     aturdido o a un rival tambaleado (el castigo del parry).
-- Tus golpes salen con tu estilo de estallido (cosmético BurstStyle, atributo "BurstStyle").
-- Solo lo tuyo: ni lo de tu mascota ni lo de los aliados. Se ajusta en Ajustes (Shared/Settings):
-- comicFx (sí/no), comicLevel ("All" o "Strong": sin los golpes normales; los de la guardia salen
-- siempre) y comicSize.
-- El estallido va sobre el pecho del enemigo (por debajo de la cabeza) para no tapar la columna de
-- números, que sale encima de ella.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ComicBurst = require(ReplicatedStorage.Shared.UI.ComicBurst)
local Config = require(ReplicatedStorage.Shared.Config)
local Crit = require(ReplicatedStorage.Shared.Crit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local SETTINGS = Config.ComicFx
-- Cuánto se desplaza el estallido respecto a su tamaño (positivo = arriba / derecha): el de un golpe
-- baja al pecho del enemigo; el que recibes va abajo a la derecha de tu cabeza, lejos de la columna de
-- daño recibido (a la izquierda).
local DEALT_OFFSET = Vector2.new(0, -0.35)
local HURT_OFFSET = Vector2.new(0.35, -0.45)
local RANK: { [string]: number } = { Hit = 1, Crit = 2, Counter = 3, KO = 4 }
-- La guardia de alguien va sobre su cabeza, más arriba que el "OUCH!".
local GUARD_OFFSET = Vector2.new(0, 0.2)

local ComicFxController = {}

local player = Players.LocalPlayer
local active = 0
-- Último estallido sobre cada enemigo (cualquiera) y último crítico o KO, para no amontonarlos.
local lastAny: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastStrong: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastHurt = -math.huge
-- Tu último parry (os.clock) y si ya se ha usado para una "¡CONTRA!".
local parriedAt = -math.huge
local counterUsed = true

-- Escala según el alto de la pantalla: en un teléfono más pequeños que los números, para no tapar
-- media pantalla.
local function screenScale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	return math.clamp(height / 720, SETTINGS.MinScreenScale, 1.3)
end

local function headOf(model: Instance): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

-- Con qué pega el jugador, para la palabra: el arma que cuenta para sus golpes (Shared/Crit).
local function weaponKind(): ComicBurst.Weapon
	local weaponId = Crit.playerWeapon(player)
	local weapon = if weaponId then Weapons[weaponId] else nil
	if weapon and weapon.kind == "Ranged" then
		return if weapon.spell then "Spell" else "Ranged"
	end
	return "Melee"
end

-- Tu estilo de estallido, si llevas uno.
local function burstStyle(): string?
	local styleId = player:GetAttribute("BurstStyle")
	return if typeof(styleId) == "string" and ComicBurst.hasStyle(styleId) then styleId else nil
end

-- Un estallido fijo en "position" (no sigue al enemigo: dura menos de un segundo y así se ve aunque
-- el enemigo desaparezca al caer).
local function spawnAt(position: Vector3, kind: ComicBurst.Kind, word: string, offset: Vector2)
	if active >= SETTINGS.MaxActive then
		return
	end
	local values = Settings.get()
	local pixels = math.round(SETTINGS.Pixels[kind] * screenScale() * (SETTINGS.SizeScale[values.comicSize] or 1))
	local anchor = Instance.new("Attachment")
	anchor.Name = "ComicFx"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position

	local gui = Instance.new("BillboardGui")
	gui.Name = "ComicFx"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	gui.MaxDistance = SETTINGS.MaxDistance
	gui.Size = UDim2.fromOffset(pixels, pixels)
	gui.SizeOffset = Vector2.new(offset.X + (math.random() - 0.5) * 0.3, offset.Y)
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	active += 1
	local life = ComicBurst.play(frame, kind, word, pixels, false, burstStyle())
	task.delay(life + 0.05, function()
		active -= 1
		gui:Destroy()
		anchor:Destroy()
	end)
end

-- Te han pegado: solo si el golpe es fuerte o crítico.
local function onHurt(character: Model, amount: number, crit: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local maxHealth = if humanoid then humanoid.MaxHealth else 100
	local now = os.clock()
	if not crit and amount < maxHealth * SETTINGS.HurtFraction or now - lastHurt < SETTINGS.HurtCooldownSeconds then
		return
	end
	local head = headOf(character)
	if head then
		lastHurt = now
		spawnAt(head.Position, "Hurt", ComicBurst.word("Hurt"), HURT_OFFSET)
	end
end

-- true si "target" está aturdido (un mono, un jefe) o tambaleado (un rival): lo que deja tu parry.
local function punishable(target: Instance): boolean
	local rival = Players:GetPlayerFromCharacter(target)
	if rival then
		return rival:GetAttribute("CombatState") == "Staggered"
	end
	local stunnedUntil = target:GetAttribute("StunnedUntil")
	return typeof(stunnedUntil) == "number" and stunnedUntil > Workspace:GetServerTimeNow()
end

-- La guardia de "character" ("Parry" o "Break"; el bloqueo no lleva estallido): sobre ti o sobre un
-- jugador cerca.
local function onGuard(character: any, kind: any)
	if typeof(character) ~= "Instance" or not character:IsA("Model") or not Settings.get().comicFx then
		return
	end
	local burst: ComicBurst.Kind? = if kind == "Parry" then "Parry" elseif kind == "Break" then "GuardBroken" else nil
	local head = headOf(character)
	if not (burst and head) then
		return
	end
	local own = character == player.Character
	if not own then
		local mine = player.Character and headOf(player.Character)
		if not mine or (mine.Position - head.Position).Magnitude > SETTINGS.GuardNearbyStuds then
			return
		end
	end
	if own and burst == "Parry" then
		parriedAt = os.clock()
		counterUsed = false
	end
	spawnAt(head.Position, burst, ComicBurst.word(burst), GUARD_OFFSET)
end

-- Tu golpe más fuerte sobre "target" en este lote.
local function onDealt(target: Instance, kind: ComicBurst.Kind, level: Settings.ComicLevel)
	if kind == "Hit" and level == "Strong" then
		return
	end
	local now = os.clock()
	if kind == "Counter" then
		local head = headOf(target)
		if head then
			lastAny[target] = now
			lastStrong[target] = now
			spawnAt(head.Position, kind, ComicBurst.word(kind), DEALT_OFFSET)
		end
		return
	end
	if kind == "Hit" and now - (lastAny[target] or -math.huge) < SETTINGS.HitCooldownSeconds then
		return
	elseif kind == "Crit" and now - (lastStrong[target] or -math.huge) < SETTINGS.CritCooldownSeconds then
		return
	end
	local head = headOf(target)
	if not head then
		return
	end
	lastAny[target] = now
	if kind ~= "Hit" then
		lastStrong[target] = now
	end
	spawnAt(head.Position, kind, ComicBurst.word(kind, weaponKind(), burstStyle()), DEALT_OFFSET)
end

local function onBatch(batch: any)
	local values = Settings.get()
	if typeof(batch) ~= "table" or not values.comicFx then
		return
	end
	local character = player.Character
	-- Un lote puede traer a la vez el golpe normal y el crítico al mismo enemigo: se queda el mayor.
	local strongest: { [Instance]: ComicBurst.Kind } = {}
	for _, entry in batch do
		if typeof(entry) ~= "table" or typeof(entry.target) ~= "Instance" or typeof(entry.amount) ~= "number" then
			continue
		end
		local target: Instance = entry.target
		local crit = entry.crit == true
		if target == character then
			if entry.kind == "Taken" then
				onHurt(character :: Model, entry.amount, crit)
			end
			continue
		end
		-- Lo tuyo (no lo de tu mascota) a un enemigo o, en PvP, a otro jugador.
		local pvp = entry.kind == "Taken" and Players:GetPlayerFromCharacter(target) ~= nil
		-- Del veneno (cada segundo) solo el golpe que lo derriba.
		local poisonKo = entry.kind == "Poison" and entry.ko == true
		if entry.by ~= player.UserId or entry.pet == true or not (entry.kind == "Dealt" or pvp or poisonKo) then
			continue
		end
		local kind: ComicBurst.Kind = if entry.ko == true then "KO" elseif crit then "Crit" else "Hit"
		if
			kind ~= "KO"
			and not counterUsed
			and os.clock() - parriedAt <= SETTINGS.CounterSeconds
			and punishable(target)
		then
			counterUsed = true
			kind = "Counter"
		end
		local current = strongest[target]
		if not current or RANK[kind] > RANK[current] then
			strongest[target] = kind
		end
	end
	for target, kind in strongest do
		onDealt(target, kind, values.comicLevel)
	end
end

function ComicFxController:Start()
	Remotes.CombatText.OnClientEvent:Connect(onBatch)
	Remotes.AbilityFx.OnClientEvent:Connect(function(kind, ...)
		if kind == "GuardFx" then
			onGuard(...)
		end
	end)
end

return ComicFxController
