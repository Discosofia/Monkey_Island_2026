--!strict
-- Pantalla del jugador caído (GDD §6.2):
--   - Aviso en el centro con la cuenta atrás hasta reaparecer si nadie le reanima.
--   - "Rendirse": mantener pulsado F en PC, X en mando o el botón táctil "Rendirse"
--     (Config.Life.SurrenderHoldSeconds) para reaparecer ya, sin esperar la cuenta atrás.
--   - Oculta su propio aviso "Reanimar" (es para sus aliados).
--   - Desactiva "Reiniciar personaje" del menú de Roblox, que permitiría saltarse estos estados.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)

local SURRENDER_ACTION = "Surrender"

local LifeController = {}

-- Desde cuándo mantiene pulsado "Rendirse" (os.clock), o nil si no lo pulsa.
local holdingSince: number? = nil

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

local function setSurrender(enabled: boolean)
	holdingSince = nil
	if enabled then
		ActionButtons.bind(SURRENDER_ACTION, "Rendirse", function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				holdingSince = os.clock()
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				holdingSince = nil
			end
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	else
		ActionButtons.unbind(SURRENDER_ACTION)
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
	banner.TextColor3 = Color3.fromRGB(255, 120, 110)
	banner.Visible = false

	local function refresh()
		local downed = LifeState.get(player) == "Downed"
		setSurrender(downed)
		banner.Visible = downed
		-- Caído: tumbado, se arrastra (Data/PlayerAnimations "Crawl").
		if downed then
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

	-- Cuenta atrás mientras está caído y "Rendirse": al mantenerlo lo bastante, pide reaparecer.
	task.spawn(function()
		while gui.Parent do
			if LifeState.get(player) == "Downed" then
				local key = if UserInputService.TouchEnabled then "Rendirse" else "F"
				local since = holdingSince
				if since then
					local held = os.clock() - since
					if held >= Config.Life.SurrenderHoldSeconds then
						holdingSince = nil
						Remotes.Surrender:FireServer()
					end
					local left = math.max(0, Config.Life.SurrenderHoldSeconds - held)
					banner.Text =
						`🏳️ Rindiéndote… suelta para seguir esperando ({string.format("%.1f", left)} s)`
				else
					banner.Text =
						`🆘 Has caído: un aliado puede reanimarte ({secondsUntil("DownedEndsAt")} s) · mantén {key} para rendirte`
				end
			end
			task.wait(0.1)
		end
	end)
end

return LifeController
