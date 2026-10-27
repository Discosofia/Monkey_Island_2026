--!strict
-- Aviso de los ataques de los monos, los jefes y el muñeco de sparring (Fase 10, C6; Combat/EnemyAttack).
-- Sale de los atributos de cada enemigo, sin remotos:
--   - "WindupUntil" (hora del servidor en que golpea) y "WindupKind": mientras se prepara, un "!"
--     blanco sobre su cabeza que crece hasta el golpe y los ojos ("Eye") encendidos; si no se puede
--     bloquear ("Unblockable"), "‼" y ojos naranjas: hay que apartarse o esquivar. Se ve sin sonido.
--   - "ControlResistedAt": un control que no le ha hecho nada por los rendimientos decrecientes
--     (Combat/Status): "INMUNE" que sube y se desvanece.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)

local STRIKE_COLOR = Color3.fromRGB(255, 255, 255)
local STRIKE_EYES = Color3.fromRGB(255, 245, 190)
local UNBLOCKABLE_COLOR = Color3.fromRGB(255, 140, 40)
local RESISTED_COLOR = Color3.fromRGB(200, 215, 235)
-- A partir de esta distancia (studs) no se ven los avisos.
local MAX_DISTANCE = 150

type Warning = { gui: BillboardGui, eyes: { [BasePart]: { color: Color3, material: Enum.Material } }, ticket: number }

local EnemyWindupController = {}

local warnings: { [Model]: Warning } = {}
local tickets = 0

-- La cabeza (o la raíz) y cuánto sobresale por encima de su centro.
local function anchorOf(model: Model): (BasePart?, number)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head, head.Size.Y / 2
	end
	local root = model.PrimaryPart
	return root, if root then root.Size.Y / 2 else 0
end

local function billboard(model: Model, size: number): BillboardGui?
	local anchor, top = anchorOf(model)
	if not anchor then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyWindup"
	gui.Size = UDim2.fromOffset(size, size)
	gui.StudsOffset = Vector3.new(0, top + 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.Adornee = anchor
	gui.Parent = anchor
	return gui
end

local function hide(model: Model)
	local warning = warnings[model]
	if not warning then
		return
	end
	warnings[model] = nil
	warning.gui:Destroy()
	for eye, look in warning.eyes do
		eye.Color = look.color
		eye.Material = look.material
	end
end

local function show(model: Model)
	local untilTime = model:GetAttribute("WindupUntil")
	local seconds = if typeof(untilTime) == "number" then untilTime - Workspace:GetServerTimeNow() else 0
	hide(model)
	if seconds <= 0 then
		return
	end
	local unblockable = model:GetAttribute("WindupKind") == "Unblockable"
	local color = if unblockable then UNBLOCKABLE_COLOR else STRIKE_COLOR
	local gui = billboard(model, 64)
	if not gui then
		return
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.fromScale(0.6, 0.6)
	label.BackgroundTransparency = 1
	label.Text = if unblockable then "‼" else "!"
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.Parent = gui
	-- Crece hasta el golpe: el tamaño dice cuánto falta.
	TweenService:Create(label, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromScale(1, 1),
	}):Play()

	local eyes = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Eye" then
			eyes[child] = { color = child.Color, material = child.Material }
			child.Color = if unblockable then UNBLOCKABLE_COLOR else STRIKE_EYES
			child.Material = Enum.Material.Neon
		end
	end
	tickets += 1
	local ticket = tickets
	warnings[model] = { gui = gui, eyes = eyes, ticket = ticket }
	task.delay(seconds, function()
		local warning = warnings[model]
		if warning and warning.ticket == ticket then
			hide(model)
		end
	end)
end

local function resisted(model: Model)
	local gui = billboard(model, 110)
	if not gui then
		return
	end
	gui.Size = UDim2.fromOffset(110, 30)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = Strings.t("INMUNE")
	label.TextColor3 = RESISTED_COLOR
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.Parent = gui
	local info = TweenInfo.new(0.8)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, 1.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 0.8)
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	model:GetAttributeChangedSignal("WindupUntil"):Connect(function()
		show(model)
	end)
	model:GetAttributeChangedSignal("ControlResistedAt"):Connect(function()
		resisted(model)
	end)
	if model:GetAttribute("WindupUntil") ~= nil then
		show(model)
	end
end

function EnemyWindupController:Start()
	local tag = Config.Combat.EnemyTag
	CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		if instance:IsA("Model") then
			hide(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		watch(instance)
	end
end

return EnemyWindupController
