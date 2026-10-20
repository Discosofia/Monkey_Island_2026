--!strict
-- Ayuda de las mascotas en la Isla (Fase 5). Cada Config.Pets.TickSeconds:
--   - Combate: ataca al mono más cercano a su dueño (dentro de Config.Pets.AttackRange). Avisa a los
--     clientes (Remotes.PetAttack) para que la mascota salte sobre él y el daño llega al golpe
--     (Config.Pets.StrikeDelaySeconds).
--   - Curación: cura a su dueño.
--   - Marca: marca al mono más cercano a su dueño (la misma marca que "Marcar presas" del cazador,
--     atributos "MarkedUntil"/"MarkBonus", con "MarkSource" = "Pet" para que los clientes dibujen una
--     huella en vez de la diana). Todo el que le pega hace más daño (CombatService.damage).
-- Sus golpes y curaciones pueden ser críticos (Config.Crit.PetChance) y sus números salen más pequeños
-- que los del jugador (CombatTextController).
-- Las ventajas pasivas (apoyo, carga) las suma RoleService; el rastreo lo hace el cliente.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Crit = require(ReplicatedStorage.Shared.Crit)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local Status = require(ServerScriptService.Combat.Status)

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

-- Marca de la mascota sobre "enemy": la renueva sin acortarla y no toca una marca mayor que dure aún
-- (la del cazador, que se escribe encima de esta al lanzarla).
local function petMark(enemy: Model)
	local bonus = Config.Pets.MarkBonus
	if Status.isBoss(enemy) then
		bonus *= Config.Pets.MarkBossMultiplier
	end
	local now = Workspace:GetServerTimeNow()
	local untilTime = enemy:GetAttribute("MarkedUntil")
	local current = enemy:GetAttribute("MarkBonus")
	local active = typeof(untilTime) == "number" and now < untilTime
	if active and typeof(current) == "number" and current > bonus then
		return
	end
	local newUntil = now + Config.Pets.MarkSeconds
	if active and enemy:GetAttribute("MarkSource") == "Pet" then
		newUntil = math.max(newUntil, untilTime :: number)
	end
	enemy:SetAttribute("MarkedUntil", newUntil)
	enemy:SetAttribute("MarkBonus", bonus)
	enemy:SetAttribute("MarkSource", "Pet")
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
					CombatService.damage(
						enemy,
						enemyHumanoid,
						damage,
						player,
						{ pet = true, crit = Crit.roll(Config.Crit.PetChance) }
					)
				end
			end)
		end
	end
	if pet.marks then
		local enemy = nearestEnemy(character:GetPivot().Position)
		if enemy then
			petMark(enemy)
		end
	end
	if pet.healPerTick and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		CombatService.heal(player, pet.healPerTick, player, { pet = true, canCrit = true })
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
