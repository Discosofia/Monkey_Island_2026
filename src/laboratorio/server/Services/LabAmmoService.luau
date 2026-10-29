--!strict
-- Cargador, recarga y dispersión de las armas del Laboratorio (Fase 15, V8; números en Data/LabWeapons,
-- "lab.magazine", "lab.reloadSeconds" y "lab.spread", y Config.Lab.SpreadMovingSpeed).
--   - Cada jugador lleva las balas que le quedan y, si recarga, hasta cuándo. Se replican al Player como
--     atributos "LabAmmo" (balas) y "ReloadingUntil" (Workspace:GetServerTimeNow() en que acaba; nil si no
--     recarga) para el HUD (LabAmmoHUDController) y la predicción (CombatClient/LabShooting).
--   - Cada tiro gasta una bala (takeShot, la regla "takeShot" de LabCombatRules, que llama a
--     CombatService.onUseWeapon) y devuelve la dispersión del tiro (Shared/LabSpread). Al vaciarse el
--     cargador empieza la recarga sola; Remotes.LabReload la pide antes, con el cargador a medias.
--   - Al aparecer el personaje, o al cambiar de arma (atributo "LabWeapon"), el cargador se llena y se
--     cancela la recarga.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LabSpread = require(ReplicatedStorage.Shared.LabSpread)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)

type Entry = {
	weaponId: string?,
	ammo: number,
	reloadEnd: number?, -- Workspace:GetServerTimeNow() en que acaba la recarga
	token: number, -- sube con cada recarga o llenado, para anular el task.delay de la anterior
	spread: LabSpread.State,
}

local LabAmmoService = {}

local entries: { [Player]: Entry } = {}

-- El arma del Laboratorio que lleva "player" (atributo "LabWeapon"), o nil.
local function currentWeapon(player: Player): (string?, LabWeapons.LabWeaponDefinition?)
	local weaponId = player:GetAttribute("LabWeapon")
	if typeof(weaponId) ~= "string" then
		return nil, nil
	end
	return weaponId, LabWeapons.weapons[weaponId]
end

local function publish(player: Player, entry: Entry)
	player:SetAttribute("LabAmmo", entry.ammo)
	player:SetAttribute("ReloadingUntil", entry.reloadEnd)
end

-- Llena el cargador del arma que lleva ahora, cancela la recarga y borra la dispersión acumulada.
local function refill(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { weaponId = nil, ammo = 0, reloadEnd = nil, token = 0, spread = LabSpread.newState() }
		entries[player] = entry
	end
	local weaponId, weapon = currentWeapon(player)
	entry.token += 1
	entry.weaponId = weaponId
	entry.ammo = if weapon then weapon.lab.magazine else 0
	entry.reloadEnd = nil
	entry.spread = LabSpread.newState()
	publish(player, entry)
	return entry
end

local function entryOf(player: Player): Entry
	local entry = entries[player]
	if entry then
		return entry
	end
	return refill(player)
end

-- Empieza a recargar: al cabo de "reloadSeconds" el cargador está lleno, salvo que algo lo cancele antes.
local function startReload(player: Player, entry: Entry, weapon: LabWeapons.LabWeaponDefinition)
	entry.token += 1
	local token = entry.token
	entry.reloadEnd = Workspace:GetServerTimeNow() + weapon.lab.reloadSeconds
	publish(player, entry)
	task.delay(weapon.lab.reloadSeconds, function()
		if entry.token ~= token or entries[player] ~= entry then
			return
		end
		entry.ammo = weapon.lab.magazine
		entry.reloadEnd = nil
		publish(player, entry)
	end)
end

-- Gasta un disparo de "weapon" (el que lleva "player"): nil si no puede (sin balas o recargando); si puede,
-- la dispersión en grados de este tiro. Lo que no es del Laboratorio (sin cargador) dispara sin límite.
function LabAmmoService.takeShot(player: Player, weaponId: string, _weapon: any, zoomed: boolean): number?
	local lab = LabWeapons.weapons[weaponId]
	if not lab then
		return 0
	end
	local entry = entryOf(player)
	if entry.weaponId ~= weaponId then
		entry = refill(player)
		if entry.weaponId ~= weaponId then
			return nil
		end
	end
	if entry.ammo <= 0 or entry.reloadEnd ~= nil then
		return nil
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local moving = false
	if root and root:IsA("BasePart") then
		local velocity = root.AssemblyLinearVelocity
		moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.Lab.SpreadMovingSpeed
	end
	local airborne = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
	local now = os.clock()
	local degrees = LabSpread.angle(lab, entry.spread, now, moving, airborne, zoomed)
	LabSpread.fire(lab, entry.spread, now)
	entry.ammo -= 1
	if entry.ammo <= 0 then
		startReload(player, entry, lab)
	else
		publish(player, entry)
	end
	return degrees
end

-- Recarga a petición del jugador (Remotes.LabReload): vivo, con un arma con cargador, a medias y sin recargar ya.
function LabAmmoService.reload(player: Player)
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local weaponId, weapon = currentWeapon(player)
	if not weapon then
		return
	end
	local entry = entryOf(player)
	if entry.weaponId ~= weaponId or entry.reloadEnd ~= nil or entry.ammo >= weapon.lab.magazine then
		return
	end
	startReload(player, entry, weapon)
end

function LabAmmoService:Start()
	Remotes.LabReload.OnServerEvent:Connect(LabAmmoService.reload)
	local function watch(player: Player)
		refill(player)
		player.CharacterAdded:Connect(function()
			refill(player)
		end)
		player:GetAttributeChangedSignal("LabWeapon"):Connect(function()
			refill(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

return LabAmmoService
