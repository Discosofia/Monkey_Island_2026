--!strict
-- Arma de cada uno en el Laboratorio (docs/LABORATORIO.md §2): lleva una sola de las cuatro de
-- Data/LabWeapons, la del atributo "LabWeapon" (CombatRules.roleWeapons, LabCombatRules; sin elegir,
-- Config.Lab.DefaultWeapon). Se cambia con Remotes.LabPickWeapon (LabLoadoutController) antes de la
-- partida, en los resultados o mientras espera para reaparecer; no en plena pelea. Al aparecer la lleva
-- ya en la mano: no hay otra que elegir en la mochila.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)

-- Cuánto se espera a que llegue el arma a la mochila al aparecer, para ponérsela en la mano.
local EQUIP_WAIT_SECONDS = 5

local LabLoadoutService = {}

local function isLabWeapon(weaponId: any): boolean
	return typeof(weaponId) == "string" and table.find(LabWeapons.ORDER, weaponId) ~= nil
end

-- true si "player" puede cambiar de arma ahora.
function LabLoadoutService.canPick(player: Player): boolean
	return not Arena.inBattle() or player:GetAttribute("RespawnAt") ~= nil
end

-- Le pone en la mano el arma del rol que tenga en la mochila (si está vivo).
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

local function onPick(player: Player, weaponId: any)
	if
		not isLabWeapon(weaponId)
		or player:GetAttribute("LabWeapon") == weaponId
		or not LabLoadoutService.canPick(player)
	then
		return
	end
	player:SetAttribute("LabWeapon", weaponId)
	CombatService.refreshRoleWeapons(player)
	equip(player)
end

local function onCharacter(player: Player, character: Model)
	local backpack = player:WaitForChild("Backpack", EQUIP_WAIT_SECONDS)
	local deadline = os.clock() + EQUIP_WAIT_SECONDS
	while backpack and player.Character == character and os.clock() < deadline do
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("RoleWeapon") == true then
				equip(player)
				return
			end
		end
		task.wait(0.1)
	end
end

function LabLoadoutService:Start()
	Remotes.LabPickWeapon.OnServerEvent:Connect(onPick)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return LabLoadoutService
