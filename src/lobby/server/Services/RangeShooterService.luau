--!strict
-- Modo shooter del campo de tiro del Lobby (Fase 24b). En la zona de preparación hay un Armero
-- (World/RangeBuilder) con las cuatro armas del Laboratorio colgadas; cada una lleva un ProximityPrompt con el
-- atributo "ArmeroWeapon" (su id de Data/LabWeapons) y el del centro, "ArmeroDejarPrompt", suelta el arma.
--   - Equipar una pone en el jugador los atributos "ShooterWeapon" (lo leen LobbyCombatRules y el cliente,
--     ShooterViewController, que pasa a primera persona) y "LabWeapon" (el cargador de Combat/LabMagazine y el
--     HUD del Laboratorio), cambia sus armas de rol por esa sola (CombatService.refreshRoleWeapons) y se la
--     pone en la mano. Sin habilidades ni guardia (LobbyCombatRules); el Lobby sigue sin PvP.
--   - Dejarla, salir del campo (RangeService) o morir lo devuelve a tercera persona con las armas de su rol.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local LabMagazine = require(ServerScriptService.Combat.LabMagazine)

local DROP_PROMPT = "ArmeroDejarPrompt"
local WEAPON_ATTRIBUTE = "ArmeroWeapon"
-- Margen sobre el alcance del aviso por el retraso de la red.
local REACH_SLACK = 8
local COOLDOWN_SECONDS = 0.5

local RangeShooterService = {}

local lastUse: { [Player]: number } = {}

local function isLabWeapon(weaponId: any): boolean
	return typeof(weaponId) == "string" and table.find(LabWeapons.ORDER, weaponId) ~= nil
end

-- true si el jugador vive y está lo bastante cerca del aviso.
local function isNear(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local anchor = prompt.Parent
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return false
	end
	if not (anchor and anchor:IsA("BasePart")) then
		return false
	end
	return (root.Position - anchor.Position).Magnitude <= prompt.MaxActivationDistance + REACH_SLACK
end

-- Le pone en la mano el arma de rol que tenga en la mochila (si está vivo).
local function equip(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or humanoid.Health <= 0 or not backpack then
		return
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("RoleWeapon") == true then
			humanoid:EquipTool(tool)
			return
		end
	end
end

-- true si "player" lleva ahora un arma de rol en la mano.
local function holdsRoleWeapon(player: Player): boolean
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	return tool ~= nil and tool:GetAttribute("RoleWeapon") == true
end

local function equipWeapon(player: Player, weaponId: string)
	if player:GetAttribute("ShooterWeapon") == weaponId then
		return
	end
	player:SetAttribute("ShooterWeapon", weaponId)
	player:SetAttribute("LabWeapon", weaponId)
	CombatService.refreshRoleWeapons(player)
	equip(player)
end

-- Devuelve a "player" a sus armas de rol y a tercera persona. "reequip": ponerle en la mano el arma del rol si
-- llevaba la del Armero en la mano (no al morir).
function RangeShooterService.release(player: Player, reequip: boolean?)
	if player:GetAttribute("ShooterWeapon") == nil and player:GetAttribute("LabWeapon") == nil then
		return
	end
	local held = reequip == true and holdsRoleWeapon(player)
	player:SetAttribute("ShooterWeapon", nil)
	player:SetAttribute("LabWeapon", nil)
	CombatService.refreshRoleWeapons(player)
	if held then
		equip(player)
	end
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	local now = os.clock()
	if now - (lastUse[player] or -math.huge) < COOLDOWN_SECONDS or not isNear(player, prompt) then
		return
	end
	lastUse[player] = now
	if prompt.Name == DROP_PROMPT then
		RangeShooterService.release(player, true)
		return
	end
	local weaponId = prompt:GetAttribute(WEAPON_ATTRIBUTE)
	if isLabWeapon(weaponId) then
		equipWeapon(player, weaponId :: string)
	end
end

local function hook(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	if instance.Name == DROP_PROMPT or isLabWeapon(instance:GetAttribute(WEAPON_ATTRIBUTE)) then
		instance.Triggered:Connect(function(player: Player)
			onTriggered(instance, player)
		end)
	end
end

local function watch(player: Player)
	local function onCharacter(character: Model)
		-- Una vida nueva empieza sin el arma del Armero.
		RangeShooterService.release(player, false)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				RangeShooterService.release(player, false)
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function RangeShooterService:Start()
	LabMagazine.start()
	for _, instance in Workspace:GetDescendants() do
		hook(instance)
	end
	Workspace.DescendantAdded:Connect(hook)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
	end)
end

return RangeShooterService
