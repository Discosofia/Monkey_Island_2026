--!strict
-- Barra de guardia del jugador (Fase 10, C5; atributo "Guard" que pone Combat/Guard): corta, con un
-- escudo, a la derecha de la de estamina en el HUD de cada place (SurvivalHUDController en la Isla,
-- ArenaHUDController en Dunas). Solo se ve mientras no está llena o se está en guardia. Plateada;
-- dorada un momento tras un parry ("ParryAt") y naranja con la guardia rota ("GuardBroken").
--   local update = GuardBar.attach(filaDeLaEstamina, anchoDeLaEstamina + 30, altoDeLaBarra)
--   update() -- en cada fotograma

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local WIDTH = 70
local ICON = 22
local GAP = 6
local GUARD_COLOR = Color3.fromRGB(200, 210, 225)
local PARRY_COLOR = Color3.fromRGB(255, 205, 60)
local BROKEN_COLOR = Color3.fromRGB(255, 130, 40)
local PARRY_FLASH_SECONDS = 0.4

local GuardBar = {}

local function corner(parent: Instance)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, 6)
	item.Parent = parent
end

-- Pone la barra en "row" a partir de "left" (px) y devuelve la función que la actualiza.
function GuardBar.attach(row: Frame, left: number, barHeight: number): () -> ()
	local player = Players.LocalPlayer
	local holder = Instance.new("Frame")
	holder.Name = "Guard"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(left + GAP, 0)
	holder.Size = UDim2.new(0, ICON + 4 + WIDTH, 1, 0)
	holder.Visible = false
	holder.Parent = row

	local icon = Widgets.label("🛡️", holder)
	icon.Size = UDim2.new(0, ICON, 1, 0)

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, ICON + 4, 0.5, 0)
	back.Size = UDim2.fromOffset(WIDTH, barHeight)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.35
	back.Parent = holder
	corner(back)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = GUARD_COLOR
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner(fill)

	return function()
		local value = player:GetAttribute("Guard")
		local fraction = if typeof(value) == "number" then math.clamp(value / Config.Guard.Max, 0, 1) else 1
		local state = CombatState.get(player)
		local broken = state == "GuardBroken"
		holder.Visible = fraction < 0.999 or broken or state == "Blocking" or state == "Parrying"
		if not holder.Visible then
			return
		end
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.Visible = fraction > 0
		local parryAt = player:GetAttribute("ParryAt")
		local parried = typeof(parryAt) == "number" and Workspace:GetServerTimeNow() - parryAt < PARRY_FLASH_SECONDS
		fill.BackgroundColor3 = if broken then BROKEN_COLOR elseif parried then PARRY_COLOR else GUARD_COLOR
		-- Rota y vacía: el hueco de la barra también se tiñe, para que se vea sin barra.
		back.BackgroundColor3 = if broken then Color3.fromRGB(90, 40, 15) else Color3.fromRGB(20, 20, 20)
	end
end

return GuardBar
