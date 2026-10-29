--!strict
-- Cargador y dispersión del jugador local en el Laboratorio (Fase 15, V8). Predice lo que decide el
-- servidor (laboratorio/server/Services/LabAmmoService) para que el contador de balas, la recarga y la mira
-- dinámica respondan al momento, y se corrige con sus atributos del Player:
--   "LabAmmo"        balas que quedan en el cargador
--   "ReloadingUntil" Workspace:GetServerTimeNow() en que acaba la recarga (nil si no recarga)
-- Un valor de balas menor que el local se toma siempre; uno mayor solo si es el cargador lleno (recarga
-- acabada o cargador llenado al aparecer o al cambiar de arma): los intermedios son un eco retrasado.
-- Si el arma que lleva en la mano no tiene cargador (la Isla, Dunas, el Lobby), nada de esto actúa.
-- Lo usan WeaponController (disparar, recargar) y laboratorio/client/LabAmmoHUDController (contador, barra
-- y mira).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LabSpread = require(ReplicatedStorage.Shared.LabSpread)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local LabShooting = {}

local player = Players.LocalPlayer
-- nil hasta saber las balas: se asume el cargador lleno.
local ammoLeft: number? = nil
local reloadEnd: number? = nil
local spreadState = LabSpread.newState()
local listeners: { () -> () } = {}

local function notify()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

-- El arma del Laboratorio con cargador que lleva el jugador por el atributo "LabWeapon" (el servidor llena
-- y cuenta con esa), o nil.
local function chosenDefinition(): LabWeapons.LabWeaponDefinition?
	local weaponId = player:GetAttribute("LabWeapon")
	return if typeof(weaponId) == "string" then LabWeapons.weapons[weaponId] else nil
end

-- Arma con cargador que tiene en la mano ahora (su definición de Data/Weapons) y su id, o nil.
function LabShooting.weapon(): (Weapons.WeaponDefinition?, string?)
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	if weapon and weapon.lab and weapon.lab.magazine then
		return weapon, weaponId :: string
	end
	return nil, nil
end

-- Balas del cargador (con el arma de la mano; 0 si no tiene cargador).
function LabShooting.magazine(): number
	local weapon = LabShooting.weapon()
	return if weapon and weapon.lab then weapon.lab.magazine else 0
end

-- Si la recarga ya ha pasado, llena el cargador.
local function settle()
	local finish = reloadEnd
	if finish and Workspace:GetServerTimeNow() >= finish then
		reloadEnd = nil
		ammoLeft = nil
		notify()
	end
end

function LabShooting.ammo(): number
	settle()
	return ammoLeft or LabShooting.magazine()
end

-- Cuándo acaba la recarga (hora del servidor), o nil si no recarga.
function LabShooting.reloadingUntil(): number?
	settle()
	return reloadEnd
end

-- true si el arma de la mano tiene balas y no recarga.
function LabShooting.canShoot(): boolean
	return LabShooting.weapon() ~= nil and LabShooting.ammo() > 0 and LabShooting.reloadingUntil() == nil
end

local function beginReload(weapon: Weapons.WeaponDefinition)
	if weapon.lab then
		reloadEnd = Workspace:GetServerTimeNow() + weapon.lab.reloadSeconds
	end
end

-- Gasta una bala (el disparo ya sale) y suma su dispersión; con la última empieza la recarga.
function LabShooting.consume()
	local weapon = LabShooting.weapon()
	if not weapon then
		return
	end
	local left = LabShooting.ammo() - 1
	ammoLeft = math.max(0, left)
	LabSpread.fire(weapon, spreadState, os.clock())
	if left <= 0 then
		beginReload(weapon)
	end
	notify()
end

-- Recarga (la pide el jugador): se predice y se avisa al servidor. No hace nada con el cargador lleno o
-- si ya recarga.
function LabShooting.reload()
	local weapon = LabShooting.weapon()
	if not weapon or LabShooting.reloadingUntil() ~= nil or LabShooting.ammo() >= LabShooting.magazine() then
		return
	end
	beginReload(weapon)
	Remotes.LabReload:FireServer()
	notify()
end

local function isMoving(root: BasePart): boolean
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.Lab.SpreadMovingSpeed
end

-- Dispersión (grados) que tendría el siguiente tiro con el arma de la mano. "zoomed": la mira acercada.
function LabShooting.spreadDegrees(zoomed: boolean): number
	local weapon = LabShooting.weapon()
	if not weapon then
		return 0
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local moving = root ~= nil and root:IsA("BasePart") and isMoving(root)
	local airborne = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
	return LabSpread.angle(weapon, spreadState, os.clock(), moving, airborne, zoomed)
end

-- La misma dispersión en píxeles de la pantalla, con la cámara de ahora (el zoom la agranda).
function LabShooting.spreadPixels(zoomed: boolean): number
	local degrees = LabShooting.spreadDegrees(zoomed)
	local camera = Workspace.CurrentCamera
	if degrees <= 0 or not camera then
		return 0
	end
	local half = math.tan(math.rad(camera.FieldOfView) / 2)
	return math.tan(math.rad(degrees)) * (camera.ViewportSize.Y / 2) / math.max(half, 1e-3)
end

-- Llama a "callback" cuando cambian las balas o la recarga.
function LabShooting.onChanged(callback: () -> ())
	table.insert(listeners, callback)
end

local function reset()
	ammoLeft = nil
	reloadEnd = nil
	spreadState = LabSpread.newState()
	notify()
end

local function onAmmoAttribute()
	local value = player:GetAttribute("LabAmmo")
	if typeof(value) ~= "number" then
		return
	end
	local definition = chosenDefinition()
	local full = if definition then definition.lab.magazine else math.huge
	-- Sin predicción propia (nil) se toma el valor del servidor.
	if ammoLeft == nil or value < ammoLeft or value >= full then
		ammoLeft = value
		notify()
	end
end

local function onReloadAttribute()
	local value = player:GetAttribute("ReloadingUntil")
	local finish = if typeof(value) == "number" then value else nil
	if finish ~= nil then
		reloadEnd = finish
		notify()
	elseif reloadEnd ~= nil and Workspace:GetServerTimeNow() >= reloadEnd - Config.Net.JitterSeconds then
		-- La recarga acaba en el servidor a la vez que la predicha.
		reloadEnd = nil
		ammoLeft = nil
		notify()
	end
end

player:GetAttributeChangedSignal("LabAmmo"):Connect(onAmmoAttribute)
player:GetAttributeChangedSignal("ReloadingUntil"):Connect(onReloadAttribute)
-- El servidor llena el cargador al cambiar de arma y al aparecer; aquí se parte de cero.
player:GetAttributeChangedSignal("LabWeapon"):Connect(reset)
player.CharacterAdded:Connect(reset)
onAmmoAttribute()
onReloadAttribute()

return LabShooting
