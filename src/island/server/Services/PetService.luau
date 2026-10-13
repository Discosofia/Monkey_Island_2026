--!strict
-- Ayuda de las mascotas en la Isla (Fase 5). Cada Config.Pets.TickSeconds:
--   - Combate: ataca al mono más cercano a su dueño (dentro de Config.Pets.AttackRange). Avisa a los
--     clientes (Remotes.PetAttack) para que la mascota salte sobre él y el daño llega al golpe
--     (Config.Pets.StrikeDelaySeconds).
--   - Curación: cura a su dueño.
-- Las ventajas pasivas (apoyo, carga) las suma RoleService; el rastreo lo hace el cliente.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatService = require(script.Parent.CombatService)

local PetService = {}

local function nearestEnemy(position: Vector3): (Model?, Humanoid?)
	local best: Model? = nil
	local bestHumanoid: Humanoid? = nil
	local bestDistance = Config.Pets.AttackRange
	for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if enemy:IsA("Model") and humanoid and humanoid.Health > 0 then
			local distance = (enemy:GetPivot().Position - position).Magnitude
			if distance < bestDistance then
				best = enemy
				bestHumanoid = humanoid
				bestDistance = distance
			end
		end
	end
	return best, bestHumanoid
end

local function tick(player: Player)
	local petId = player:GetAttribute("ActivePet")
	local pet = if typeof(petId) == "string" then Pets[petId] else nil
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (pet and character and humanoid) or not LifeState.isAlive(player) then
		return
	end
	if pet.attackDamage then
		local enemy, enemyHumanoid = nearestEnemy(character:GetPivot().Position)
		local damage = pet.attackDamage
		if enemy and enemyHumanoid then
			Remotes.PetAttack:FireAllClients(player, enemy)
			task.delay(Config.Pets.StrikeDelaySeconds, function()
				if enemy.Parent and enemyHumanoid.Health > 0 then
					Sfx.play("PetAttack", enemy.PrimaryPart or enemy)
					CombatService.damage(enemy, enemyHumanoid, damage, player)
				end
			end)
		end
	end
	if pet.healPerTick and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + pet.healPerTick)
	end
end

function PetService:Start()
	while true do
		task.wait(Config.Pets.TickSeconds)
		for _, player in Players:GetPlayers() do
			tick(player)
		end
	end
end

return PetService
