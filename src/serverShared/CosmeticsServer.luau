--!strict
-- Cosméticos en el servidor (Fase 6; ampliado en la Fase 9), en el Lobby, la Isla y Dunas:
--   - Decide qué tiene cada jugador ("Cosmetic_<id>" = true): su Game Pass, lo guardado en el perfil
--     ("ownedCosmetics": ganado jugando, del pase, comprado con Ámbar o con un Developer Product) o,
--     en Studio, lo de Robux aún sin id (Config.Cosmetics.FreeInStudio).
--   - Se entera de las compras de Game Pass hechas en la partida y entrega los Developer Products de
--     los cosméticos sueltos (ServerShared/Purchases, producto "Cosmetic.<id>").
--   - Equipar/quitar (Remotes.EquipCosmetic) se guarda en el perfil, en su hueco (Shared/CosmeticSlots).
--   - Dibuja lo equipado en el personaje: estela, título y aura.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticSlots = require(ReplicatedStorage.Shared.CosmeticSlots)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Purchases = require(script.Parent.Purchases)

local CosmeticsServer = {}

local VISUALS = { "CosmeticTrail", "CosmeticTitle", "CosmeticAura", "CosmeticAttachment" }

-- Game Passes que tiene cada jugador (se miran al entrar y al comprar en la partida).
local passes: { [Player]: { [string]: boolean } } = {}

local function owns(player: Player, cosmeticId: string): boolean
	return player:GetAttribute(`Cosmetic_{cosmeticId}`) == true
end

-- De Robux y aún sin id (sale como "Próximamente").
local function comingSoon(source: Cosmetics.Source): boolean
	return source.gamePassId == 0 or source.productId == 0
end

local function computeOwned(player: Player, cosmeticId: string, profile: PlayerData.Profile?): boolean
	if profile and profile.ownedCosmetics[cosmeticId] then
		return true
	end
	local source = Cosmetics[cosmeticId].source
	if source.earned then
		-- Ganado jugando: solo lo dice el perfil, también en Studio.
		return false
	end
	local owned = passes[player]
	if owned and owned[cosmeticId] then
		return true
	end
	return comingSoon(source) and RunService:IsStudio() and Config.Cosmetics.FreeInStudio
end

-- Pone los atributos "Cosmetic_<id>" según lo que tiene ahora.
local function refreshOwnership(player: Player)
	local profile = PlayerData.get(player)
	for cosmeticId in Cosmetics do
		player:SetAttribute(`Cosmetic_{cosmeticId}`, computeOwned(player, cosmeticId, profile))
	end
end

local function checkPasses(player: Player)
	local owned = {}
	for cosmeticId, cosmetic in Cosmetics do
		local gamePassId = cosmetic.source.gamePassId
		if gamePassId and gamePassId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
			end)
			owned[cosmeticId] = ok and result == true
		end
	end
	if player.Parent then
		passes[player] = owned
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
				-- Más ancho cuanto más largo el título, para que todos se lean del mismo tamaño.
				local text = cosmetic.title or cosmetic.name
				billboard.Size = UDim2.fromOffset(math.max(160, (utf8.len(text) or #text) * 9), 24)
				billboard.StudsOffset = Vector3.new(0, 4.4, 0)
				billboard.MaxDistance = 80
				billboard.Parent = head
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = text
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

-- Cosméticos de rescate para quien ya había ganado antes de que existieran.
local function checkEarned(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local missing = {}
	for cosmeticId, cosmetic in Cosmetics do
		if cosmetic.source.earned == "Rescue" and profile.rescues > 0 and not profile.ownedCosmetics[cosmeticId] then
			table.insert(missing, cosmeticId)
		end
	end
	if #missing > 0 then
		PlayerData.update(player, function(current)
			for _, cosmeticId in missing do
				current.ownedCosmetics[cosmeticId] = true
			end
		end)
	end
end

-- Da un cosmético para siempre (ganado jugando, premio del pase, tienda de Ámbar). Devuelve true si
-- es nuevo (no lo tenía guardado).
function CosmeticsServer.grant(player: Player, cosmeticId: string): boolean
	local profile = PlayerData.get(player)
	if not (Cosmetics[cosmeticId] and profile) or profile.ownedCosmetics[cosmeticId] then
		return false
	end
	PlayerData.update(player, function(current)
		current.ownedCosmetics[cosmeticId] = true
	end)
	player:SetAttribute(`Cosmetic_{cosmeticId}`, true)
	return true
end

-- Vuelve a mirar qué tiene (tras darle cosméticos en el perfil, como el pase al comprar la premium).
function CosmeticsServer.refresh(player: Player)
	refreshOwnership(player)
end

-- Prueba (panel de Studio): da o quita un cosmético guardado en el perfil, para ver cómo queda.
-- Devuelve si ahora lo tiene (un Game Pass comprado o uno gratis en Studio se sigue teniendo).
function CosmeticsServer.debugToggle(player: Player, cosmeticId: string): boolean
	if not Cosmetics[cosmeticId] then
		return false
	end
	PlayerData.update(player, function(profile)
		local has = not profile.ownedCosmetics[cosmeticId]
		profile.ownedCosmetics[cosmeticId] = if has then true else nil
		if not has and not computeOwned(player, cosmeticId, profile) then
			CosmeticSlots.unequip(profile.cosmetics, cosmeticId)
		end
	end)
	refreshOwnership(player)
	applyVisuals(player)
	return owns(player, cosmeticId)
end

local function onEquip(player: Player, cosmeticId: any)
	local cosmetic = if typeof(cosmeticId) == "string" then Cosmetics[cosmeticId] else nil
	if not cosmetic or not owns(player, cosmeticId) then
		return
	end
	local changed = false
	PlayerData.update(player, function(profile)
		changed = CosmeticSlots.toggle(profile.cosmetics, cosmeticId)
	end)
	if changed then
		applyVisuals(player)
	elseif cosmetic.kind == "Emote" then
		Remotes.Notify:FireClient(player, `Ya llevas {Config.Cosmetics.EmoteSlots} emotes: quita uno antes`)
	end
end

-- Cada cosmético que se vende suelto (source.productId) se entrega por ServerShared/Purchases. Se
-- registran también los que aún no tienen id (0), para la compra de prueba del panel de Studio.
local function registerProducts()
	for cosmeticId, cosmetic in Cosmetics do
		local productId = cosmetic.source.productId
		if productId then
			Purchases.register(`Cosmetic.{cosmeticId}`, productId, {
				name = `{cosmetic.icon} {cosmetic.name}`,
				grant = function(profile)
					profile.ownedCosmetics[cosmeticId] = true
				end,
				after = function(player)
					player:SetAttribute(`Cosmetic_{cosmeticId}`, true)
				end,
			})
		end
	end
end

function CosmeticsServer.start()
	registerProducts()
	Remotes.EquipCosmetic.OnServerEvent:Connect(onEquip)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		for cosmeticId, cosmetic in Cosmetics do
			if cosmetic.source.gamePassId == gamePassId then
				local owned = passes[player]
				if owned then
					owned[cosmeticId] = true
				end
				player:SetAttribute(`Cosmetic_{cosmeticId}`, true)
				Remotes.Notify:FireClient(player, `¡Gracias! Ya tienes: {cosmetic.icon} {cosmetic.name}`)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
	end)
	local function onPlayer(player: Player)
		task.spawn(function()
			checkPasses(player)
			if PlayerData.waitFor(player) then
				checkEarned(player)
			end
			refreshOwnership(player)
			-- El personaje pudo aparecer antes de saber qué tiene.
			applyVisuals(player)
		end)
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
