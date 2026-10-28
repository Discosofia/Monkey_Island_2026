--!strict
-- Rol y ventajas de cada jugador en la Isla (Fase 3).
--   - Lee el perfil guardado (PlayerData): rol elegido en el Lobby, talentos y mejoras de la tienda.
--   - Publica "Role" y las ventajas como atributos "Perk_<nombre>" (Shared/Progression.perk).
--   - Aplica las que son de una vez: vida máxima extra, el kit de náufrago y los ítems del rol
--     (las flechas del cazador). Las armas del rol las da CombatService.
--   - Entrega las provisiones ganadas fuera de partida (calendario, misiones; ServerShared/Supplies).
--   - Rellena lo que el rol recupera solo ("refill" en Data/Roles: el carcaj del cazador).
--   - Marca "TutorialPending" si el jugador aún no ha hecho el tutorial (TutorialController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Supplies = require(ServerScriptService.ServerShared.Supplies)
local InventoryService = require(script.Parent.InventoryService)

local BASE_HEALTH = 100
local KIT_ITEMS = { "Wood", "Stone", "Fiber" }
local KIT_AMOUNT = 5
-- Cada cuánto se revisa lo que se rellena solo (el carcaj).
local REFILL_TICK_SECONDS = 0.5
local REFILL_AT = "RefillAt"

local RoleService = {}

-- Rol forzado a mitad de partida desde el panel de pruebas (no se guarda).
local debugRoles: { [Player]: string } = {}
-- Segundos acumulados hacia el siguiente ítem que se rellena solo, por jugador.
local refillProgress: { [Player]: number } = {}

-- Carcaj del cazador ("refill" en Data/Roles): mientras está vivo y le quedan menos de "cap", suma
-- 1 cada "seconds". Con el carcaj lleno (o caído) el tiempo no se acumula. Publica en "RefillAt"
-- (hora del servidor) cuándo llega la siguiente, para la barrita del contador (AmmoHUDController).
local function refillTick(elapsed: number)
	for _, player in Players:GetPlayers() do
		local roleId = player:GetAttribute("Role")
		local role = if typeof(roleId) == "string" then Roles[roleId] else nil
		local refill = if role then role.refill else nil
		if refill and LifeState.isAlive(player) and Inventory.count(player, refill.itemId) < refill.cap then
			local before = refillProgress[player]
			local progress = (before or 0) + elapsed
			local added = progress >= refill.seconds
			if added then
				progress -= refill.seconds
				InventoryService.add(player, refill.itemId, 1)
			end
			refillProgress[player] = progress
			if before == nil or added then
				player:SetAttribute(REFILL_AT, Workspace:GetServerTimeNow() + refill.seconds - progress)
			end
		elseif refillProgress[player] ~= nil then
			refillProgress[player] = nil
			player:SetAttribute(REFILL_AT, nil)
		end
	end
end

local function applyHealth(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = BASE_HEALTH + Progression.perk(player, "MaxHealth")
	humanoid.Health = humanoid.MaxHealth
end

-- Calcula y publica las ventajas (rol, talentos, mejoras y mascota activa) como atributos "Perk_*".
local function publishPerks(player: Player): { [string]: number }
	local profile = PlayerData.get(player)
	local roleId = Progression.validRole(debugRoles[player] or if profile then profile.selectedRole else nil)
	local petId = player:GetAttribute("ActivePet")
	local perks = Progression.computePerks(
		roleId,
		if profile then profile.talents else {},
		if profile then profile.upgrades else {},
		if typeof(petId) == "string" then petId else nil
	)
	for name, value in perks do
		player:SetAttribute(`Perk_{name}`, value)
	end
	player:SetAttribute("Role", roleId)
	return perks
end

-- Vuelve a calcular las ventajas a mitad de partida (p. ej. al nacer una mascota del huevo) y
-- ajusta la vida máxima sin rellenar la vida actual.
function RoleService.refreshPerks(player: Player)
	publishPerks(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	-- El administrador gigante (GiantAdminService) lleva su propia vida mientras lo es.
	if humanoid and player:GetAttribute("AdminBoss") ~= true then
		humanoid.MaxHealth = BASE_HEALTH + Progression.perk(player, "MaxHealth")
	end
end

local function giveRoleItems(player: Player, roleId: string)
	for itemId, amount in Roles[roleId].items or {} do
		InventoryService.add(player, itemId, amount)
	end
end

local function onPlayer(player: Player)
	local profile = PlayerData.waitFor(player)
	if not player.Parent then
		return
	end
	local perks = publishPerks(player)
	local roleId = Progression.validRole(if profile then profile.selectedRole else nil)

	local kit = math.floor(perks.StartKit)
	if kit > 0 then
		for _, itemId in KIT_ITEMS do
			InventoryService.add(player, itemId, kit * KIT_AMOUNT)
		end
	end
	giveRoleItems(player, roleId)
	local supplies = Supplies.takeAll(player)
	if next(supplies) ~= nil then
		for itemId, amount in supplies do
			InventoryService.add(player, itemId, amount)
		end
		Remotes.Notify:FireClient(player, "🎒 Tus provisiones: {items}", { items = Rewards.itemsArg(supplies) })
	end
	if profile and not profile.tutorialDone then
		player:SetAttribute("TutorialPending", true)
	end

	player.CharacterAdded:Connect(function(character)
		applyHealth(player, character)
	end)
	if player.Character then
		applyHealth(player, player.Character)
	end
	local role = Roles[roleId]
	Remotes.Notify:FireClient(
		player,
		"{icon} Juegas como {role}: {passive}",
		{ icon = role.icon, role = { role.name }, passive = { role.passive } }
	)
end

-- Panel de pruebas: pasa al siguiente rol sin volver al Lobby (armas, ventajas y habilidades).
function RoleService.debugNextRole(player: Player)
	local ids = {}
	for roleId in Roles do
		table.insert(ids, roleId)
	end
	table.sort(ids, function(a, b)
		return Roles[a].order < Roles[b].order
	end)
	local current = player:GetAttribute("Role")
	local index = table.find(ids, current) or 0
	local roleId = ids[index % #ids + 1]
	debugRoles[player] = roleId
	RoleService.refreshPerks(player)
	giveRoleItems(player, roleId)
	for slot = 1, 5 do -- los huecos de Data/Roles (4 activas y la definitiva)
		player:SetAttribute(`AbilityReadyAt{slot}`, nil)
	end
	local role = Roles[roleId]
	Remotes.Notify:FireClient(
		player,
		"{icon} Ahora juegas como {role}: {passive}",
		{ icon = role.icon, role = { role.name }, passive = { role.passive } }
	)
end

function RoleService:Start()
	Remotes.TutorialStep.OnServerEvent:Connect(function(player: Player, step: any)
		if typeof(step) == "number" and step >= 1 and step <= 10 then
			Analytics.tutorialStep(player, math.floor(step), `Paso {math.floor(step)}`)
		end
	end)
	Remotes.TutorialDone.OnServerEvent:Connect(function(player: Player)
		Analytics.tutorialStep(player, 99, "Completado")
		player:SetAttribute("TutorialPending", nil)
		PlayerData.update(player, function(profile)
			profile.tutorialDone = true
		end)
	end)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		debugRoles[player] = nil
		refillProgress[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(REFILL_TICK_SECONDS)
			local now = os.clock()
			refillTick(now - last)
			last = now
		end
	end)
end

return RoleService
