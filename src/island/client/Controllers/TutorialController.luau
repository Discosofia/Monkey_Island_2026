--!strict
-- Tutorial de los primeros minutos (Fase 3). Solo aparece la primera vez ("TutorialPending").
-- Cada paso se completa solo al hacer lo que pide; se puede saltar. Al terminar se guarda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

type Step = { text: string, done: (player: Player, start: { [string]: number }) -> boolean }

local function gained(player: Player, start: { [string]: number }, itemId: string): boolean
	return Inventory.count(player, itemId) > (start[itemId] or 0)
end

local STEPS: { Step } = {
	{
		text = "🪓 Equipa el hacha de madera (3) y golpea un árbol hasta talarlo",
		done = function(player, start)
			return gained(player, start, "Wood")
		end,
	},
	{
		text = "🌿 Recoge fibra de un arbusto o helecho: mantén E (o toca) junto a él",
		done = function(player, start)
			return gained(player, start, "Fiber")
		end,
	},
	{
		text = "⛏️ Equipa el pico (4) y pica una roca",
		done = function(player, start)
			return gained(player, start, "Stone")
		end,
	},
	{
		text = "🔨 Vuelve al Basecamp y fabrica una antorcha en la mesa de trabajo",
		done = function(player)
			return Crafting.isOwned(player, "Torch")
		end,
	},
	{
		text = "🧱 Equipa el martillo y construye algo: de noche los monos asedian el Basecamp",
		done = function(player)
			local folder = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
			for _, model in if folder then folder:GetChildren() else {} do
				if model:GetAttribute("OwnerUserId") == player.UserId then
					return true
				end
			end
			return false
		end,
	},
}

local TutorialController = {}

function TutorialController:Start()
	local player = Players.LocalPlayer
	-- El servidor lo marca al cargar el perfil: se espera un poco por si llega tarde.
	local waited = 0
	while player:GetAttribute("TutorialPending") ~= true and waited < 30 do
		task.wait(1)
		waited += 1
	end
	if player:GetAttribute("TutorialPending") ~= true then
		return
	end

	local gui = Widgets.screen("Tutorial", player:WaitForChild("PlayerGui"))
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.18)
	panel.Size = UDim2.fromScale(0.5, 0.09)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local text = Widgets.label("", panel)
	text.Position = UDim2.fromScale(0.03, 0.08)
	text.Size = UDim2.fromScale(0.72, 0.84)
	text.TextXAlignment = Enum.TextXAlignment.Left
	local skip = Widgets.button("Saltar", panel)
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.fromScale(0.98, 0.5)
	skip.Size = UDim2.fromScale(0.2, 0.75)
	local limit = skip:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		Remotes.TutorialDone:FireServer()
		gui:Destroy()
	end
	skip.MouseButton1Click:Connect(finish)

	for index, step in STEPS do
		local start = {}
		for _, itemId in { "Wood", "Fiber", "Stone" } do
			start[itemId] = Inventory.count(player, itemId)
		end
		text.Text = `Tutorial {index}/{#STEPS}: {step.text}`
		while not finished and not step.done(player, start) do
			task.wait(0.5)
		end
		if finished then
			return
		end
	end
	text.Text = "✅ ¡Listo! Sobrevive, defiende el Basecamp y busca a los jefes de la isla"
	task.wait(6)
	finish()
end

return TutorialController
