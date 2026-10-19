--!strict
-- Curarse (Fases 1.6 y 2.3): H en PC, cruceta arriba en mando o el botón táctil "Curar".
-- El botón aparece si llevas algo para curarte (vendas, ungüentos, antídotos o la cataplasma de grupo
-- del médico) y estás vivo.
-- El servidor elige qué usar (CraftingService): con poca vida, la curación que mejor encaje aunque
-- tengas fiebre; con la vida bien y fiebre alta, el antídoto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)

local ACTION = "UseHeal"
local ANTIDOTE_ID = "Antidote"

local HealController = {}

local function healingItems(): { string }
	local ids = { ANTIDOTE_ID }
	for itemId, item in Items do
		if item.heal or item.groupHeal then
			table.insert(ids, itemId)
		end
	end
	return ids
end

function HealController:Start()
	local player = Players.LocalPlayer
	local ids = healingItems()
	local bound = false

	local function refresh()
		local hasAny = false
		for _, itemId in ids do
			if Inventory.count(player, itemId) > 0 then
				hasAny = true
				break
			end
		end
		local shouldBind = hasAny and LifeState.isAlive(player)
		if shouldBind == bound then
			return
		end
		bound = shouldBind
		if shouldBind then
			ActionButtons.bind(ACTION, "Curar", function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					BodyAnimations.play("Bandage")
					Remotes.UseBandage:FireServer()
				end
				return Enum.ContextActionResult.Sink
			end, Enum.KeyCode.H, Enum.KeyCode.DPadUp)
		else
			ActionButtons.unbind(ACTION)
		end
	end

	for _, itemId in ids do
		player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refresh)
	end
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refresh)
	refresh()
end

return HealController
