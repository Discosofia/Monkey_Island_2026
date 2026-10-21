--!strict
-- Cosméticos en el servidor (Fase 6; ampliado en la Fase 9), en el Lobby, la Isla y Dunas:
--   - Decide qué tiene cada jugador ("Cosmetic_<id>" = true): su Game Pass, lo guardado en el perfil
--     ("ownedCosmetics": ganado jugando, del pase, comprado con Ámbar o con un Developer Product) o,
--     en Studio, lo de Robux aún sin id (Config.Cosmetics.FreeInStudio).
--   - Se entera de las compras de Game Pass hechas en la partida y entrega los Developer Products de
--     los cosméticos sueltos (ServerShared/Purchases, producto "Cosmetic.<id>").
--   - Equipar/quitar (Remotes.EquipCosmetic) se guarda en el perfil, en su hueco (Shared/CosmeticSlots).
--   - Dibuja lo equipado en el personaje: estela, título y aura. El traje y el aspecto del arma del rol
--     que se juega los publica en los atributos "Outfit" y "WeaponSkin" del jugador y los pone
--     Shared/ArmorModels (con la armadura) y Shared/WeaponTools (en las armas de rol).
--   - Publica el marco ("Frame", lo dibujan las filas del ranking, del grupo y de los resultados con
--     Shared/UI/PlayerFrames), la skin de la mascota activa ("PetSkin", la ponen los clientes al
--     construirla con Shared/PetModels) y los tipos baratos: el estilo de los números ("NumberStyle",
--     CombatTextController), el de los estallidos ("BurstStyle", ComicFxController) y la decoración
--     del nido ("NestDecor", NestController del Lobby). Los emotes los hace el cliente (UI/EmoteWheel).
--   - De un cosmético por grados (I, II, III) se publica y se dibuja el grado más alto que se tiene.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArmorModels = require(ReplicatedStorage.Shared.ArmorModels)
local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticSlots = require(ReplicatedStorage.Shared.CosmeticSlots)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local PlayerData = require(script.Parent.PlayerData)
local Purchases = require(script.Parent.Purchases)

local CosmeticsServer = {}

local VISUALS = { "CosmeticTrail", "CosmeticTitle", "CosmeticAura", "CosmeticAttachment" }
-- Huecos de un tipo que se publican tal cual en un atributo del jugador con el mismo nombre.
local PUBLISHED = { "Frame", "NumberStyle", "BurstStyle", "NestDecor" }

-- Game Passes que tiene cada jugador (se miran al entrar y al comprar en la partida).
local passes: { [Player]: { [string]: boolean } } = {}
-- Quienes quieren enterarse de un cosmético nuevo guardado en el perfil (CosmeticsServer.onGranted).
local grantedListeners: { (player: Player, cosmeticId: string) -> () } = {}

local function notifyGranted(player: Player, cosmeticId: string)
	for _, listener in grantedListeners do
		task.spawn(listener, player, cosmeticId)
	end
end

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
	if source.free then
		return true
	elseif source.earned then
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

-- El grado más alto que tiene de la línea de "cosmeticId" (él mismo si no va por grados), o nil.
local function bestOwned(player: Player, cosmeticId: string): string?
	if not Cosmetics[cosmeticId] then
		return nil
	end
	return CosmeticSlots.best(cosmeticId, function(id)
		return owns(player, id)
	end)
end

-- Lo equipado en el hueco "slot" si lo tiene y existe "isBuilt" (su modelo), o nil.
local function equippedOwned(
	player: Player,
	profile: PlayerData.Profile,
	slot: string,
	isBuilt: (string) -> boolean
): string?
	local equipped = profile.cosmetics[slot]
	local cosmeticId = if equipped then bestOwned(player, equipped) else nil
	return if cosmeticId and isBuilt(cosmeticId) then cosmeticId else nil
end

-- Publica el traje ("Outfit") y el aspecto del arma ("WeaponSkin") equipados del rol que juega y, si
-- cambian (o con "force", al aparecer), lo viste y cambia el aspecto de sus armas de rol.
local function applyRoleCosmetics(player: Player, force: boolean?)
	local profile = PlayerData.get(player)
	local roleId = player:GetAttribute("Role")
	local outfitId, skinId = nil, nil
	if profile and typeof(roleId) == "string" then
		outfitId = equippedOwned(player, profile, `Outfit.{roleId}`, ArmorModels.hasOutfit)
		skinId = equippedOwned(player, profile, `WeaponSkin.{roleId}`, WeaponTools.hasSkin)
	end
	if force or player:GetAttribute("Outfit") ~= outfitId then
		player:SetAttribute("Outfit", outfitId)
		local character = player.Character
		if character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) then
			ArmorModels.dress(player, character)
		end
	end
	if player:GetAttribute("WeaponSkin") ~= skinId then
		player:SetAttribute("WeaponSkin", skinId)
		WeaponTools.reskin(player)
	end
end

local function always(): boolean
	return true
end

-- Publica el marco y los tipos baratos (PUBLISHED) y la skin de la mascota activa ("PetSkin"), si los
-- tiene.
local function applyPublished(player: Player)
	local profile = PlayerData.get(player)
	for _, slot in PUBLISHED do
		local cosmeticId = if profile then equippedOwned(player, profile, slot, always) else nil
		if player:GetAttribute(slot) ~= cosmeticId then
			player:SetAttribute(slot, cosmeticId)
		end
	end
	local skinId = nil
	if profile then
		local petId = player:GetAttribute("ActivePet")
		if typeof(petId) == "string" then
			skinId = equippedOwned(player, profile, CosmeticSlots.petSkinSlot(petId), function(cosmeticId)
				return CosmeticSlots.fitsPet(Cosmetics[cosmeticId], petId)
			end)
		end
	end
	if player:GetAttribute("PetSkin") ~= skinId then
		player:SetAttribute("PetSkin", skinId)
	end
end

local function emitter(root: BasePart, texture: string): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "CosmeticAura"
	particles.Texture = `rbxasset://textures/particles/{texture}`
	particles.Parent = root
	return particles
end

-- Anillo invisible a los pies (soldado a la raíz) del que salen las llamas del aura: desde la raíz
-- salían dentro del cuerpo y no se veían.
local function feetRing(root: BasePart): Part
	local ring = Instance.new("Part")
	ring.Name = "CosmeticAura"
	ring.Size = Vector3.new(4, 0.2, 4)
	ring.Transparency = 1
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.CFrame = root.CFrame * CFrame.new(0, -root.Size.Y / 2 - 1.8, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring
	ring.Parent = root
	return ring
end

-- El aura: chispas de su color y, por grados, más cosas (II: más chispas y un anillo de llamas que
-- sube desde los pies; III: llamas más altas y brillantes, brasas rápidas, humo oscuro y una luz de su
-- color).
local function aura(root: BasePart, cosmetic: Cosmetics.Cosmetic)
	local grade = cosmetic.grade or 1
	local sparks = emitter(root, "sparkles_main.dds")
	sparks.Color = ColorSequence.new(cosmetic.color)
	sparks.Size = NumberSequence.new(0.3 + (grade - 1) * 0.1)
	sparks.Rate = 8 + (grade - 1) * 6
	sparks.Lifetime = NumberRange.new(1, 1.5)
	sparks.Speed = NumberRange.new(1, 2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 0.6
	if grade >= 2 then
		local flames = emitter(feetRing(root), "fire_main.dds")
		flames.Shape = Enum.ParticleEmitterShape.Cylinder
		flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		flames.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		flames.Color = ColorSequence.new(cosmetic.color:Lerp(Color3.new(1, 1, 0.6), 0.5), cosmetic.color)
		flames.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2 + (grade - 2) * 0.7),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		flames.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		flames.Brightness = 3 + (grade - 2) * 2
		flames.Rate = 40 + (grade - 2) * 25
		flames.Lifetime = NumberRange.new(0.6, 1 + (grade - 2) * 0.3)
		flames.Speed = NumberRange.new(0.3, 0.6)
		flames.Acceleration = Vector3.new(0, 7, 0)
		flames.LightEmission = 0.9
	end
	if grade >= 3 then
		local embers = emitter(root, "sparkles_main.dds")
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), cosmetic.color)
		embers.Size = NumberSequence.new(0.18)
		embers.Rate = 12
		embers.Lifetime = NumberRange.new(1.2, 2)
		embers.Speed = NumberRange.new(4, 7)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.SpreadAngle = Vector2.new(35, 35)
		embers.LightEmission = 1
		local smoke = emitter(root, "smoke_main.dds")
		smoke.Color = ColorSequence.new(Color3.fromRGB(60, 50, 45))
		smoke.Size = NumberSequence.new(1.2, 3)
		smoke.Transparency = NumberSequence.new(0.7, 1)
		smoke.Rate = 3
		smoke.Lifetime = NumberRange.new(1.5, 2.2)
		smoke.Speed = NumberRange.new(1, 2)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Rotation = NumberRange.new(0, 360)
		local light = Instance.new("PointLight")
		light.Name = "CosmeticAura"
		light.Color = cosmetic.color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = root
	end
end

local function applyVisuals(player: Player)
	applyRoleCosmetics(player)
	applyPublished(player)
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
	for _, equippedId in profile.cosmetics do
		local cosmeticId = bestOwned(player, equippedId)
		local cosmetic = if cosmeticId then Cosmetics[cosmeticId] else nil
		if cosmetic then
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
				aura(root, cosmetic)
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
	notifyGranted(player, cosmeticId)
	return true
end

-- "callback" se llama cada vez que se guarda un cosmético en el perfil de un jugador (ganado, del pase,
-- comprado con un Developer Product; la tienda en Ámbar lo hace ella misma).
function CosmeticsServer.onGranted(callback: (player: Player, cosmeticId: string) -> ())
	table.insert(grantedListeners, callback)
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
					notifyGranted(player, cosmeticId)
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
			character:WaitForChild("UpperTorso", 2)
			PlayerData.waitFor(player)
			applyRoleCosmetics(player, true)
			applyVisuals(player)
		end)
		-- Cada rol tiene su traje y su aspecto de arma; cada mascota, su skin.
		player:GetAttributeChangedSignal("Role"):Connect(function()
			applyRoleCosmetics(player)
		end)
		player:GetAttributeChangedSignal("ActivePet"):Connect(function()
			applyPublished(player)
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
