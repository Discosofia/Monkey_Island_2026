--!strict
-- Parcela permanente (Fase 12, Shared/Plot) en la Isla.
--   - Se desbloquea al ganar por primera vez: en el amanecer del rescate (resumen con phase "Rescue";
--     en Studio también con una victoria del panel de pruebas, para poder probarlo). Su hueco pasa a
--     ser permanente enseguida y el cliente enseña la ventana de bienvenida (UI/PlotWelcome).
--   - Levantar las estructuras en su hueco lo hace BuildingService.refreshPlot.
--   - Mejoras (P3, Data/PlotStructures; Remotes.UpgradePlot desde la ventana Parcela): cada nivel cuesta
--     Ámbar del perfil y materiales, primero de lo privado del cofre (si está en pie) y el resto de la
--     Bolsa. Se comprueba todo y se cobra todo sin esperas en medio, y el nivel queda en el perfil para
--     siempre.
--   - Efectos, solo mientras la estructura está en pie (BuildingService.plotLevel; rota no cuenta):
--     descuento en las recetas de la forja y del taller (atributos PlotDiscount_<estación>, que aplica
--     Shared/Crafting), vendas y fruta al amanecer (aquí), y la cama (LifeService y SurvivalService).
--   - Asedio: rota, cualquiera la repara con su aviso (Config.Plot.RepairCost); si no, al amanecer
--     vuelve con toda la vida (después de repartir lo del amanecer: la rota esa noche no da nada).
--   - Incubadora (P5): su efecto es en el nido del Lobby (ServerShared/Eggs, con el nivel del perfil). Al
--     mejorarla, los huevos que ya incuban se acortan con el nuevo factor; en la Isla enseña los huevos
--     del nido del Lobby del dueño con el color de su rareza.
--   - El nido no se mejora mientras se defiende un huevo en él (Plot.NEST_BUSY_ATTRIBUTE, EggService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Plot = require(ReplicatedStorage.Shared.Plot)
local PlotStructures = require(ReplicatedStorage.Shared.Data.PlotStructures)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local BuildingService = require(script.Parent.BuildingService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)

local REPAIR_PROMPT = "RepairPrompt"

local PlotService = {}

local canUpgrade = RequestCooldown.new(1)

-- Estaciones con descuento de alguna estructura (para quitarlo cuando deja de valer).
local discountStations: { string } = {}
for _, definition in PlotStructures do
	for _, level in definition.levels do
		for _, stationId in level.stations or {} do
			if not table.find(discountStations, stationId) then
				table.insert(discountStations, stationId)
			end
		end
	end
end

-- Datos del nivel con que funciona ahora la estructura (nil si no la tiene o está rota).
function PlotService.active(player: Player, structureId: string): PlotStructures.Level?
	local level = BuildingService.plotLevel(player, structureId)
	return if level > 0 then PlotStructures[structureId].levels[level] else nil
end

-- Descuentos de la forja y del taller en pie (atributos que lee Shared/Crafting en los dos lados), y el
-- nivel del cofre en pie (Plot.CHEST_ATTRIBUTE: ChestService y las dos ventanas).
local function applyDiscounts(player: Player)
	local chestLevel = BuildingService.plotLevel(player, "Chest")
	player:SetAttribute(Plot.CHEST_ATTRIBUTE, if chestLevel > 0 then chestLevel else nil)
	local discounts: { [string]: number } = {}
	for structureId in PlotStructures do
		local level = PlotService.active(player, structureId)
		if level and level.discount then
			for _, stationId in level.stations or {} do
				discounts[stationId] = math.max(discounts[stationId] or 0, level.discount)
			end
		end
	end
	for _, stationId in discountStations do
		player:SetAttribute(Plot.DISCOUNT_ATTRIBUTE .. stationId, discounts[stationId])
	end
end

local function ownerOf(model: Model): Player?
	local userId = model:GetAttribute("OwnerUserId")
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function costText(cost: { PlotStructures.Cost }): string
	local parts = {}
	for _, entry in cost do
		table.insert(parts, `{Items[entry.itemId].icon} {entry.amount}`)
	end
	return table.concat(parts, " ")
end

local function onRepair(model: Model, player: Player)
	if not (BuildingService.isBroken(model) and LifeState.isAlive(player)) then
		return
	end
	for _, entry in Config.Plot.RepairCost do
		if Inventory.count(player, entry.itemId) < entry.amount then
			Remotes.Notify:FireClient(player, `Para repararla hace falta {costText(Config.Plot.RepairCost)}`)
			return
		end
	end
	for _, entry in Config.Plot.RepairCost do
		InventoryService.remove(player, entry.itemId, entry.amount)
	end
	local maxHealth = model:GetAttribute("MaxHealth")
	BuildingService.repair(model, if typeof(maxHealth) == "number" then maxHealth else 0)
	Sfx.play("Craft", model:GetPivot().Position)
	Remotes.Notify:FireClient(player, `🔨 Reparada: {model.Name}`)
end

-- Aviso de reparar (solo encendido mientras está rota); al romperse o repararse cambian los efectos.
local function watchStructure(model: Model)
	local definition = PlotStructures[model:GetAttribute("PlotStructure") :: string]
	local anchor = model.PrimaryPart
	if not (definition and anchor) or anchor:FindFirstChild(REPAIR_PROMPT) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = REPAIR_PROMPT
	prompt.ActionText = `Reparar ({costText(Config.Plot.RepairCost)})`
	prompt.ObjectText = `{definition.icon} {model.Name} rota`
	prompt.HoldDuration = Config.Plot.RepairHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = BuildingService.isBroken(model)
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		onRepair(model, player)
	end)
	model:GetAttributeChangedSignal("Broken"):Connect(function()
		local broken = BuildingService.isBroken(model)
		prompt.Enabled = broken
		local owner = ownerOf(model)
		if owner then
			applyDiscounts(owner)
			if broken then
				Remotes.Notify:FireClient(
					owner,
					`💥 Han roto tu {model.Name}: no funciona hasta que la repares o amanezca`
				)
			end
		end
	end)
end

-- Huevos de bloques de la incubadora (Shared/PlotModels: "Egg" y, en el III, "Egg2"): cada uno con el color
-- de la rareza del huevo de ese hueco del nido del Lobby; el de un hueco vacío no se ve.
local function paintIncubator(player: Player)
	local model = BuildingService.plotStructure(player, "Incubator")
	local eggs = Eggs.get(player)
	if not (model and eggs) then
		return
	end
	for slot = 1, #EggIncubation.NEST_KEYS do
		local egg = EggIncubation.inSlot(eggs, slot)
		local suffix = if slot == 1 then "" else tostring(slot)
		for _, name in { `Egg{suffix}`, `Egg{suffix}Top` } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Transparency = if egg then 0 else 1
				if egg then
					part.Color = Rarities[egg.rarity].color
				end
			end
		end
	end
end

local function onPlotBuilt(player: Player)
	for structureId in PlotStructures do
		local model = BuildingService.plotStructure(player, structureId)
		if model then
			watchStructure(model)
		end
	end
	applyDiscounts(player)
	paintIncubator(player)
end

local function onUpgrade(player: Player, structureId: any)
	if typeof(structureId) ~= "string" or not canUpgrade(player) then
		return
	end
	local definition = PlotStructures[structureId]
	local profile = PlayerData.get(player)
	if not (definition and profile) or MatchService.isOver() then
		return
	end
	local state = Plot.normalize(profile.plot)
	if not state.unlocked then
		Remotes.Notify:FireClient(player, "🔒 La parcela se desbloquea al ganar una partida")
		return
	end
	local level = state.levels[structureId]
	local nextLevel = definition.levels[level + 1]
	if not nextLevel then
		Remotes.Notify:FireClient(player, `{definition.icon} {definition.name} ya está al máximo`)
		return
	end
	if structureId == "Nest" and player:GetAttribute(Plot.NEST_BUSY_ATTRIBUTE) then
		Remotes.Notify:FireClient(player, "🥚 Tu nido defiende un huevo: mejóralo cuando acabe")
		return
	end
	if not LifeState.isAlive(player) then
		return
	end
	if player:GetAttribute("InBasecamp") ~= true then
		Remotes.Notify:FireClient(player, "🏡 Las mejoras de la parcela se hacen en el Basecamp")
		return
	end
	if profile.amber < nextLevel.amber then
		Remotes.Notify:FireClient(player, `Te faltan {nextLevel.amber - profile.amber} de Ámbar`)
		return
	end
	-- Los materiales salen primero de lo privado del cofre (solo si está en pie) y el resto, de la Bolsa.
	local useChest = BuildingService.plotLevel(player, "Chest") > 0
	for _, entry in nextLevel.cost do
		local stored = if useChest then state.chest.private[entry.itemId] or 0 else 0
		if stored + Inventory.count(player, entry.itemId) < entry.amount then
			Remotes.Notify:FireClient(player, `Te faltan materiales: {costText(nextLevel.cost)}`)
			return
		end
	end
	-- Desde aquí no hay esperas: lo comprobado no puede cambiar antes de cobrarlo.
	local before = profile.amber
	local fromBag: { [string]: number } = {}
	PlayerData.update(player, function(current)
		current.amber -= nextLevel.amber
		local plot = Plot.normalize(current.plot)
		local _, factorBefore = Plot.incubator(plot)
		plot.levels[structureId] = level + 1
		local _, factorAfter = Plot.incubator(plot)
		if factorAfter < factorBefore then
			Eggs.speedUp(current, factorBefore, factorAfter)
		end
		for _, entry in nextLevel.cost do
			local stored = plot.chest.private[entry.itemId] or 0
			local fromChest = if useChest then math.min(stored, entry.amount) else 0
			plot.chest.private[entry.itemId] = if stored - fromChest > 0 then stored - fromChest else nil
			fromBag[entry.itemId] = entry.amount - fromChest
		end
		current.plot = plot :: any
	end)
	for itemId, amount in fromBag do
		if amount > 0 then
			InventoryService.remove(player, itemId, amount)
		end
	end
	Analytics.amber(player, "Sink", nextLevel.amber, before - nextLevel.amber, `Plot.{structureId}.{level + 1}`)
	BuildingService.refreshPlot(player)
	task.spawn(PlayerData.saveNow, player)
	local verb = if level == 0 then "Construido" else "Mejorado"
	Remotes.Notify:FireClient(
		player,
		`🏡 {verb}: {definition.icon} {definition.name} {Plot.ROMAN[level + 1]} · {nextLevel.effect}`
	)
end

-- Al amanecer: vendas del taller y fruta del huerto en pie; después vuelve todo lo roto o dañado de la
-- parcela con toda la vida.
local function onDawn()
	for _, player in Players:GetPlayers() do
		local gifts = {}
		local healer = PlotService.active(player, "Healer")
		if healer and healer.bandages then
			InventoryService.add(player, "Bandage", healer.bandages)
			table.insert(gifts, `{Items.Bandage.icon} {healer.bandages}`)
		end
		local garden = PlotService.active(player, "Garden")
		if garden and garden.food then
			for itemId, amount in garden.food do
				InventoryService.add(player, itemId, amount)
				table.insert(gifts, `{Items[itemId].icon} {amount}`)
			end
		end
		if #gifts > 0 then
			Remotes.Notify:FireClient(player, `🏡 Tu parcela al amanecer: {table.concat(gifts, " ")}`)
		end
		for structureId in PlotStructures do
			local model = BuildingService.plotStructure(player, structureId)
			local maxHealth = if model then model:GetAttribute("MaxHealth") else nil
			if model and typeof(maxHealth) == "number" then
				BuildingService.repair(model, maxHealth)
			end
		end
	end
end

local function onMatchEnded(player: Player, summary: MatchService.Summary)
	if summary.phase ~= "Rescue" or (summary.test and not RunService:IsStudio()) then
		return
	end
	local unlocked = false
	PlayerData.update(player, function(profile)
		local state = Plot.normalize(profile.plot)
		if not state.unlocked then
			state.unlocked = true
			profile.plot = state :: any
			unlocked = true
		end
	end)
	if unlocked then
		BuildingService.refreshPlot(player)
		Remotes.Notify:FireClient(player, "🏡 ¡Parcela desbloqueada! Ahora viaja contigo a cada partida")
		Analytics.event(player, "PlotUnlocked", 1)
	end
end

function PlotService:Init()
	MatchService.onMatchEnded(onMatchEnded)
	BuildingService.onPlotBuilt(onPlotBuilt)
	DayNightService.onPhaseStarted(function(day, phase)
		if phase == "Day" and day > 1 then
			onDawn()
		end
	end)
end

function PlotService:Start()
	Remotes.UpgradePlot.OnServerEvent:Connect(onUpgrade)
	-- Los huevos del nido del Lobby cambian (abrir, poner, tiempo ganado): se repinta la incubadora.
	local function watchEggs(player: Player)
		player:GetAttributeChangedSignal("Eggs"):Connect(function()
			paintIncubator(player)
		end)
	end
	Players.PlayerAdded:Connect(watchEggs)
	for _, player in Players:GetPlayers() do
		watchEggs(player)
	end
end

return PlotService
