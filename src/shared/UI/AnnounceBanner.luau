--!strict
-- Cartel de los anuncios de los administradores (Remotes.Announce, T4), en los tres places y para
-- todos los jugadores: arriba en el centro, más grande que un aviso (Shared/UI/Toast) y con borde
-- dorado, durante Config.AdminTools.AnnounceSeconds. Un anuncio nuevo sustituye al que se ve.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Parent.Config)
local Remotes = require(script.Parent.Parent.Remotes)
local Sounds = require(script.Parent.Parent.Data.Sounds)
local Widgets = require(script.Parent.Widgets)

local WOOD = Color3.fromRGB(25, 20, 15)
local GOLD = Color3.fromRGB(242, 178, 36)
local TITLE = Color3.fromRGB(255, 220, 150)

local AnnounceBanner = {}

local function build(): (Frame, TextLabel, TextLabel, UIScale)
	local gui = Widgets.screen("Announce", Players.LocalPlayer:WaitForChild("PlayerGui"))
	-- Encima de los avisos (10) y por debajo del panel de pruebas (20).
	gui.DisplayOrder = 11

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 6)
	banner.Size = UDim2.new(0.6, 0, 0, 92)
	banner.BackgroundColor3 = WOOD
	banner.BackgroundTransparency = 0.05
	banner.Active = false
	banner.Visible = false
	banner.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 0)
	limit.MaxSize = Vector2.new(720, math.huge)
	limit.Parent = banner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = banner
	local scale = Instance.new("UIScale")
	scale.Parent = banner

	local title = Widgets.label("", banner)
	title.Position = UDim2.fromOffset(14, 6)
	title.Size = UDim2.new(1, -28, 0, 24)
	title.TextColor3 = TITLE
	title.TextXAlignment = Enum.TextXAlignment.Left

	local text = Widgets.label("", banner)
	text.Position = UDim2.fromOffset(14, 32)
	text.Size = UDim2.new(1, -28, 1, -38)
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 12
	textLimit.MaxTextSize = 24
	textLimit.Parent = text
	return banner, title, text, scale
end

local function playSound()
	local sound = Instance.new("Sound")
	sound.SoundId = Sounds.Notify
	sound.Volume = Sounds.NotifyVolume
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

function AnnounceBanner.start()
	local banner, title, text, scale = build()
	local shown = 0
	Remotes.Announce.OnClientEvent:Connect(function(message: any, from: any)
		if typeof(message) ~= "string" then
			return
		end
		title.Text = `📢 Anuncio · {tostring(from)}`
		text.Text = message
		banner.Visible = true
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		playSound()
		shown += 1
		local thisShow = shown
		task.delay(Config.AdminTools.AnnounceSeconds, function()
			if shown == thisShow then
				banner.Visible = false
			end
		end)
	end)
end

return AnnounceBanner
