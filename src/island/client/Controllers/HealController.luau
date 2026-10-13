--!strict
-- Usar una venda (Fase 1.6): H en PC, cruceta arriba en mando o el botón táctil "Curar".
-- El botón solo aparece si tienes vendas y estás vivo. El servidor cura y gasta la venda.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTION = "UseBandage"
local ITEM_ID = "Bandage"

local HealController = {}

function HealController:Start()
	local player = Players.LocalPlayer
	local bound = false

	local function refresh()
		local shouldBind = Inventory.count(player, ITEM_ID) > 0 and LifeState.isAlive(player)
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

	player:GetAttributeChangedSignal(Inventory.attributeName(ITEM_ID)):Connect(refresh)
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refresh)
	refresh()
end

return HealController
