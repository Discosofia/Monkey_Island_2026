--!strict
-- Pantalla del jugador caído o Espíritu (GDD §6.2):
--   - Aviso en el centro con la cuenta atrás o las instrucciones.
--   - Oculta su propio aviso "Reanimar" (es para sus aliados).
--   - Como Espíritu, marca enemigos: F en PC, X en mando o el botón táctil "Marcar".
--   - Desactiva "Reiniciar personaje" del menú de Roblox, que permitiría saltarse estos estados.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local Aim = require(script.Parent.Parent.Aim)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)

local MARK_ACTION = "SpiritMark"

local LifeController = {}

local function disableResetButton()
	-- SetCore puede fallar si el menú aún no ha cargado: se reintenta unos segundos.
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

local function hideOwnRevivePrompt(character: Model)
	local function check(descendant: Instance)
		if descendant:IsA("ProximityPrompt") and descendant.Name == "RevivePrompt" then
			descendant.Enabled = false
		end
	end
	for _, descendant in character:GetDescendants() do
		check(descendant)
	end
	character.DescendantAdded:Connect(check)
end

local function setMarking(enabled: boolean)
	if enabled then
		ActionButtons.bind(MARK_ACTION, "Marcar", function(_, state: Enum.UserInputState)
			local character = Players.LocalPlayer.Character
			if state == Enum.UserInputState.Begin and character then
				Remotes.SpiritMark:FireServer(Aim.direction(character))
			end
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	else
		ActionButtons.unbind(MARK_ACTION)
	end
end

function LifeController:Start()
	local player = Players.LocalPlayer
	task.spawn(disableResetButton)

	player.CharacterAdded:Connect(hideOwnRevivePrompt)
	if player.Character then
		hideOwnRevivePrompt(player.Character)
	end

	local gui = Widgets.screen("LifeHUD", player:WaitForChild("PlayerGui"))
	local banner = Widgets.label("", gui)
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.32)
	banner.Size = UDim2.fromScale(0.7, 0.06)
	banner.Visible = false

	local function refresh()
		local state = LifeState.get(player)
		setMarking(state == "Spirit")
		banner.Visible = state ~= "Alive"
		-- Caído: tumbado, se arrastra (Data/PlayerAnimations "Crawl").
		if state == "Downed" then
			if not BodyAnimations.isPlaying("Crawl") then
				BodyAnimations.play("Crawl", 0)
			end
		else
			BodyAnimations.stop("Crawl")
		end
	end
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refresh)
	refresh()

	-- Arrastrándose, brazos y piernas van al ritmo al que se mueve; quieto, se queda tumbado.
	RunService.Heartbeat:Connect(function()
		if not BodyAnimations.isPlaying("Crawl") then
			return
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			BodyAnimations.setSpeed("Crawl", math.clamp(speed / Config.Life.CrawlSpeed, 0, 1.5))
		end
	end)

	-- Reanimar a un aliado: de rodillas mientras se mantiene pulsado su aviso.
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt.Name == "RevivePrompt" then
			BodyAnimations.play("Revive")
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt.Name == "RevivePrompt" then
			BodyAnimations.stop("Revive")
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "RevivePrompt" then
			BodyAnimations.stop("Revive")
		end
	end)

	local function secondsUntil(attribute: string): number
		local endsAt = player:GetAttribute(attribute)
		return if typeof(endsAt) == "number" then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else 0
	end

	-- Cuenta atrás mientras está caído o es Espíritu.
	task.spawn(function()
		while gui.Parent do
			local state = LifeState.get(player)
			if state == "Downed" then
				banner.Text = `🆘 Has caído: un aliado puede reanimarte ({secondsUntil("DownedEndsAt")} s)`
				banner.TextColor3 = Color3.fromRGB(255, 120, 110)
			elseif state == "Spirit" then
				banner.Text =
					`👻 Eres un Espíritu: reapareces en {secondsUntil("SpiritEndsAt")} s · F / Marcar para señalar enemigos`
				banner.TextColor3 = Color3.fromRGB(170, 225, 255)
			end
			task.wait(0.25)
		end
	end)
end

return LifeController
