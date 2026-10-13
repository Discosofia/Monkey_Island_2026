--!strict
-- Cosméticos de pago en el servidor (Fase 6), en el Lobby y en la Isla:
--   - Comprueba qué Game Passes tiene cada jugador ("Cosmetic_<id>" = true).
--   - Se entera de las compras hechas en la partida.
--   - Equipar/quitar (Remotes.EquipCosmetic) se guarda en el perfil (uno por tipo).
--   - Dibuja lo equipado en el personaje: estela, título y aura.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local CosmeticsServer = {}

local VISUALS = { "CosmeticTrail", "CosmeticTitle", "CosmeticAura", "CosmeticAttachment" }

local function owns(player: Player, cosmeticId: string): boolean
	return player:GetAttribute(`Cosmetic_{cosmeticId}`) == true
end

local function checkOwnership(player: Player)
	for cosmeticId, cosmetic in Cosmetics do
		local owned = false
		if cosmetic.gamePassId == 0 then
			owned = RunService:IsStudio() and Config.Cosmetics.FreeInStudio
		else
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, cosmetic.gamePassId)
			end)
			owned = ok and result == true
		end
		player:SetAttribute(`Cosmetic_{cosmeticId}`, owned)
	end
end

local function applyVisuals(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if not (character and root and root:IsA("BasePart")) then
		return
	end
	for _, name in VISUALS do
		for _, descendant in character:GetDescendants() do
			if descendant.Name == name then
				descendant:Destroy()
			end
		end
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	for _, cosmeticId in profile.cosmetics do
		local cosmetic = Cosmetics[cosmeticId]
		if cosmetic and owns(player, cosmeticId) then
			if cosmetic.kind == "Trail" then
				local top = Instance.new("Attachment")
				top.Name = "CosmeticAttachment"
				top.Position = Vector3.new(0, 1, 0)
				top.Parent = root
				local bottom = Instance.new("Attachment")
				bottom.Name = "CosmeticAttachment"
				bottom.Position = Vector3.new(0, -1, 0)
				bottom.Parent = root
				local trail = Instance.new("Trail")
				trail.Name = "CosmeticTrail"
				trail.Attachment0 = top
				trail.Attachment1 = bottom
				trail.Color = ColorSequence.new(cosmetic.color)
				trail.Transparency = NumberSequence.new(0.3, 1)
				trail.Lifetime = 0.6
				trail.LightEmission = 0.5
				trail.Parent = root
			elseif cosmetic.kind == "Title" and head and head:IsA("BasePart") then
				local billboard = Instance.new("BillboardGui")
				billboard.Name = "CosmeticTitle"
				billboard.Size = UDim2.fromOffset(160, 24)
				billboard.StudsOffset = Vector3.new(0, 4.4, 0)
				billboard.MaxDistance = 80
				billboard.Parent = head
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = cosmetic.title or cosmetic.name
				label.TextColor3 = cosmetic.color
				label.TextStrokeTransparency = 0.3
				label.Font = Enum.Font.BuilderSansBold
				label.TextScaled = true
				label.Parent = billboard
			elseif cosmetic.kind == "Aura" then
				local aura = Instance.new("ParticleEmitter")
				aura.Name = "CosmeticAura"
				aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				aura.Color = ColorSequence.new(cosmetic.color)
				aura.Size = NumberSequence.new(0.3)
				aura.Rate = 8
				aura.Lifetime = NumberRange.new(1, 1.5)
				aura.Speed = NumberRange.new(1, 2)
				aura.SpreadAngle = Vector2.new(180, 180)
				aura.LightEmission = 0.6
				aura.Parent = root
			end
		end
	end
end

local function onEquip(player: Player, cosmeticId: any)
	local cosmetic = if typeof(cosmeticId) == "string" then Cosmetics[cosmeticId] else nil
	if not cosmetic or not owns(player, cosmeticId) then
		return
	end
	PlayerData.update(player, function(profile)
		-- Pulsar en el equipado lo quita; si no, sustituye al de su tipo.
		if profile.cosmetics[cosmetic.kind] == cosmeticId then
			profile.cosmetics[cosmetic.kind] = nil
		else
			profile.cosmetics[cosmetic.kind] = cosmeticId
		end
	end)
	applyVisuals(player)
end

function CosmeticsServer.start()
	Remotes.EquipCosmetic.OnServerEvent:Connect(onEquip)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		for cosmeticId, cosmetic in Cosmetics do
			if cosmetic.gamePassId == gamePassId then
				player:SetAttribute(`Cosmetic_{cosmeticId}`, true)
				Remotes.Notify:FireClient(player, `¡Gracias! Ya tienes: {cosmetic.icon} {cosmetic.name}`)
			end
		end
	end)
	local function onPlayer(player: Player)
		checkOwnership(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			PlayerData.waitFor(player)
			applyVisuals(player)
		end)
		if player.Character then
			PlayerData.waitFor(player)
			applyVisuals(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return CosmeticsServer
