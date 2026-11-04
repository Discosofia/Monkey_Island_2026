--!strict
-- Dianas del campo de tiro del Lobby (Fase 23, World/RangeBuilder): las vuelve combatientes y mueve las
-- que no están quietas. Cada Workspace.CampoDeTiro.Dianas.Diana* recibe un Humanoid con una vida enorme
-- (Config.Range.TargetHealth) que se rellena tras cada golpe, y la etiqueta Config.Combat.EnemyTag: así
-- las armas la golpean con el combate normal y salen los números de daño. El anillo central («Bullseye»)
-- cuenta como cabeza (x1,5 de daño); los demás anillos y el poste, como torso. Las dianas con el atributo
-- RangeTarget no atraen la ayuda de puntería (CombatService.aimShot): se mide la puntería propia.
-- Movimiento (todo en el servidor, un solo Heartbeat y PivotTo, con la hora del servidor para que se
-- vea igual a todos): "rail" va y viene en x, "spin" gira sobre el eje vertical y "popup" sube y baja con el
-- ciclo de la maqueta; mientras está abajo pierde la etiqueta y no se la puede golpear.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)

local ENEMY_TAG = Config.Combat.EnemyTag
local SETTINGS = Config.Range

type Mover = (now: number, deltaTime: number) -> ()

local RangeTargetService = {}

local humanoids: { [Model]: Humanoid } = {}
local movers: { Mover } = {}

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

-- Humanoid sin barra de vida ni nombre, y zonas de daño de cada pieza.
local function makeCombatant(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("Zone", if descendant.Name == "Bullseye" then "Head" else "Torso")
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = SETTINGS.TargetHealth
	humanoid.Health = SETTINGS.TargetHealth
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	humanoids[model] = humanoid
	-- Su daño no cuenta para las misiones del día.
	model:SetAttribute("TrainingDummy", true)
	CollectionService:AddTag(model, ENEMY_TAG)
end

-- Rail: va y viene en x alrededor de donde está construida.
local function railMover(model: Model): Mover
	local base = model:GetPivot()
	local amplitude = numberAttribute(model, "RailAmplitude", 0)
	local speed = numberAttribute(model, "RailSpeed", 0)
	return function(now: number)
		model:PivotTo(base + Vector3.new(amplitude * math.sin(now * speed), 0, 0))
	end
end

-- Giratoria: el disco da vueltas sobre el eje vertical que pasa por su centro.
local function spinMover(model: Model): Mover
	local base = model:GetPivot()
	local speed = numberAttribute(model, "SpinSpeed", 0)
	return function(now: number)
		-- GetServerTimeNow vale ~1,8e9: el ángulo sin reducir pierde la precisión de un float32 y se queda quieto.
		model:PivotTo(base * CFrame.Angles(0, (now * speed) % (2 * math.pi), 0))
	end
end

-- Emergente: arriba la mitad del ciclo y abajo el resto, con un suavizado exponencial; abajo no se golpea.
local function popupMover(model: Model): Mover
	local base = model:GetPivot()
	local index = numberAttribute(model, "PopupIndex", 0)
	local radius = numberAttribute(model, "Radius", 3)
	local center = numberAttribute(model, "CenterHeight", 3)
	local hiddenY = -(center + radius + SETTINGS.PopupHideMargin)
	local y = hiddenY
	local lastY = math.huge
	local hittable = false
	CollectionService:RemoveTag(model, ENEMY_TAG)
	model:PivotTo(base + Vector3.new(0, y, 0))
	return function(now: number, deltaTime: number)
		local phase = (now * SETTINGS.PopupCycleRate + index * SETTINGS.PopupPhaseStep) % 1
		local goal = if phase < SETTINGS.PopupUpFraction then 0 else hiddenY
		y += (goal - y) * math.min(1, deltaTime * SETTINGS.PopupSmoothing)
		if math.abs(goal - y) < 0.005 then
			y = goal
		end
		if y ~= lastY then
			lastY = y
			model:PivotTo(base + Vector3.new(0, y, 0))
		end
		local visible = y > hiddenY * SETTINGS.PopupHiddenFraction
		if visible ~= hittable then
			hittable = visible
			if visible then
				CollectionService:AddTag(model, ENEMY_TAG)
			else
				CollectionService:RemoveTag(model, ENEMY_TAG)
			end
		end
	end
end

local function setUp(model: Model)
	if not (model:GetAttribute("RangeTarget") == true and model.PrimaryPart) or humanoids[model] then
		return
	end
	makeCombatant(model)
	local kind = model:GetAttribute("Kind")
	if kind == "rail" then
		table.insert(movers, railMover(model))
	elseif kind == "spin" then
		table.insert(movers, spinMover(model))
	elseif kind == "popup" then
		table.insert(movers, popupMover(model))
	end
end

function RangeTargetService:Start()
	-- Tras cada golpe, la diana recupera toda la vida: nunca cae.
	CombatService.onEnemyDamaged(function(model: Model)
		local humanoid = humanoids[model]
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end)

	local range = Workspace:WaitForChild("CampoDeTiro", 30)
	local targets = if range then range:WaitForChild("Dianas", 30) else nil
	if not targets then
		warn("[RangeTargetService] No hay Workspace.CampoDeTiro.Dianas: el Lobby no tiene el campo de tiro")
		return
	end
	for _, child in targets:GetChildren() do
		if child:IsA("Model") then
			setUp(child)
		end
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = Workspace:GetServerTimeNow()
		for _, mover in movers do
			mover(now, deltaTime)
		end
	end)
end

return RangeTargetService
