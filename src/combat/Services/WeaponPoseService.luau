--!strict
-- Pose de apuntar de los demás jugadores (Fase 19, W2). El que lleva un arma a distancia reproduce su
-- pista Aim* en su propio personaje y Roblox la replica; por si no llega, el servidor publica el atributo
-- "AimPose" del Player (la pista que debe sonar, p. ej. "AimBow", o "" si ninguna) y
-- RemoteWeaponPoseController la reproduce en los demás clientes. Es "" si no lleva un arma a distancia,
-- si corre ("Sprinting", StaminaServer: el arma baja) o si está caído o muerto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponAim = require(ReplicatedStorage.Shared.Data.WeaponAim)

local WeaponPoseService = {}

-- La pista de apuntar del arma a distancia que lleva "player" en la mano, o "".
local function poseOf(player: Player): string
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return ""
	end
	if player:GetAttribute("Sprinting") == true or not LifeState.isAlive(player) then
		return ""
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	if not (weapon and weapon.kind == "Ranged") then
		return ""
	end
	local key = if weapon.lab then weapon.lab.pose else weapon.projectile or "Stone"
	return WeaponAim.AimOf[key] or ""
end

local function refresh(player: Player)
	player:SetAttribute("AimPose", poseOf(player))
end

local function watchCharacter(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			refresh(player)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			refresh(player)
		end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			refresh(player)
		end)
	end
	refresh(player)
end

local function add(player: Player)
	player:GetAttributeChangedSignal("Sprinting"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	else
		refresh(player)
	end
end

function WeaponPoseService:Start()
	Players.PlayerAdded:Connect(add)
	for _, player in Players:GetPlayers() do
		add(player)
	end
end

return WeaponPoseService
