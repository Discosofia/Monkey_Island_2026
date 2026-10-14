--!strict
-- Rol del jugador local en la Isla (Fase 3):
--   - Habilidad activa: Z en PC, R1 en mando o el botón táctil "Habilidad". Un texto bajo las barras
--     de supervivencia dice cuál es y cuándo vuelve a estar lista.
--   - Avisos más rápidos según sus ventajas: "Reanimar" (médico) y recolectar (recolector).
--   - Médico: ve una barra de vida sobre la cabeza de cada aliado.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(script.Parent.Parent.ActionButtons)

local ACTION = "UseAbility"
-- Avisos cuyo tiempo de mantener depende de una ventaja del jugador.
local PROMPT_PERKS: { [string]: string } = {
	RevivePrompt = "ReviveSpeed",
	HarvestPrompt = "HarvestSpeed",
}

local RoleController = {}

local function adjustPrompt(player: Player, prompt: ProximityPrompt)
	local perk = PROMPT_PERKS[prompt.Name]
	if not perk then
		return
	end
	local base = prompt:GetAttribute("BaseHold")
	if typeof(base) ~= "number" then
		base = prompt.HoldDuration
		prompt:SetAttribute("BaseHold", base)
	end
	prompt.HoldDuration = (base :: number) * Progression.perk(player, perk)
end

-- Barras de vida de los aliados (solo el médico).
local function healthBars(player: Player)
	local bars: { [Player]: BillboardGui } = {}
	while true do
		local show = Progression.perk(player, "SeeHealth") > 0
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local head = if character then character:FindFirstChild("Head") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local bar = bars[other]
			if other == player or not show or not (head and humanoid) then
				if bar then
					bar:Destroy()
					bars[other] = nil
				end
			else
				if not bar or bar.Parent ~= head then
					if bar then
						bar:Destroy()
					end
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "AllyHealth"
					billboard.Size = UDim2.fromOffset(70, 8)
					billboard.StudsOffset = Vector3.new(0, 2.6, 0)
					billboard.AlwaysOnTop = true
					billboard.MaxDistance = 120
					local back = Instance.new("Frame")
					back.Size = UDim2.fromScale(1, 1)
					back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					back.Parent = billboard
					local fill = Instance.new("Frame")
					fill.Name = "Fill"
					fill.BackgroundColor3 = Color3.fromRGB(110, 230, 120)
					fill.BorderSizePixel = 0
					fill.Parent = back
					billboard.Parent = head
					bars[other] = billboard
					bar = billboard
				end
				local fill = (bar :: any).Frame.Fill :: Frame
				fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
			end
		end
		for other, bar in bars do
			if not other.Parent then
				bar:Destroy()
				bars[other] = nil
			end
		end
		task.wait(0.25)
	end
end

function RoleController:Start()
	local player = Players.LocalPlayer

	ProximityPromptService.PromptShown:Connect(function(prompt)
		adjustPrompt(player, prompt)
	end)

	local gui = Widgets.screen("RoleHUD", player:WaitForChild("PlayerGui"))
	local label = Widgets.label("", gui)
	label.Name = "Ability"
	label.Position = UDim2.fromOffset(12, 118)
	label.Size = UDim2.fromOffset(260, 22)
	label.TextXAlignment = Enum.TextXAlignment.Left

	ActionButtons.bind(ACTION, "Habilidad", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin and LifeState.isAlive(player) then
			Remotes.UseAbility:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.Z, Enum.KeyCode.ButtonR1)

	task.spawn(healthBars, player)
	while true do
		local roleId = player:GetAttribute("Role")
		local role = if typeof(roleId) == "string" then Roles[roleId] else nil
		if role then
			local readyAt = player:GetAttribute("AbilityReadyAt")
			local remaining = if typeof(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
			local status = if remaining > 0 then `{math.ceil(remaining)} s` else "lista"
			label.Text = `{role.icon} {role.ability.name} (Z): {status}`
			label.TextColor3 = if remaining > 0 then Color3.fromRGB(180, 180, 180) else Color3.fromRGB(255, 220, 120)
		end
		task.wait(0.25)
	end
end

return RoleController
