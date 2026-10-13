--!strict
-- Curarse (Fases 1.6 y 2.3): H en PC, cruceta arriba en mando o el botón táctil "Curar".
-- El botón aparece si llevas algo para curarte (vendas, ungüentos o antídotos) y estás vivo.
-- El servidor elige qué usar: el antídoto si tienes fiebre; si no, la curación que mejor encaje.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTION = "UseHeal"
local ANTIDOTE_ID = "Antidote"

local HealController = {}

local function healingItems(): { string }
	local ids = { ANTIDOTE_ID }
	for itemId, item in Items do
		if item.heal then
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
			ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					Remotes.UseBandage:FireServer()
				end
				return Enum.ContextActionResult.Sink
			end, true, Enum.KeyCode.H, Enum.KeyCode.DPadUp)
			ContextActionService:SetTitle(ACTION, "Curar")
		else
			ContextActionService:UnbindAction(ACTION)
		end
	end

	for _, itemId in ids do
		player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refresh)
	end
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refresh)
	refresh()
end

return HealController
