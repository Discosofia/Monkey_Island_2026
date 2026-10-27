--!strict
-- Cosméticos en el servidor (Fase 6; ampliado en la Fase 9), en el Lobby, la Isla y Dunas:
--   - Decide qué tiene cada jugador ("Cosmetic_<id>" = true): su Game Pass, lo guardado en el perfil
--     ("ownedCosmetics": ganado jugando, del pase, comprado con Ámbar o con un Developer Product) o,
--     en Studio, lo de Robux aún sin id (Config.Cosmetics.FreeInStudio).
--   - Se entera de las compras de Game Pass hechas en la partida y entrega los Developer Products de
--     los cosméticos sueltos (ServerShared/Purchases, producto "Cosmetic.<id>").
--   - Equipar/quitar (Remotes.EquipCosmetic) se guarda en el perfil, en su hueco (Shared/CosmeticSlots).
--   - Dibuja lo equipado en el personaje: estela, título y aura. El traje y el aspecto del arma del rol
--     que se juega los publica en los atributos "Outfit" y "WeaponSkin" del jugador, y el del machete en
--     "MacheteSkin"; los pone Shared/ArmorModels (con la armadura) y Shared/WeaponTools (en las armas).
--   - Publica el marco ("Frame", lo dibujan las filas del ranking, del grupo y de los resultados con
--     Shared/UI/PlayerFrames), la skin de la mascota activa ("PetSkin", la ponen los clientes al
--     construirla con Shared/PetModels) y los tipos baratos: el estilo de los números ("NumberStyle",
--     CombatTextController), el de los estallidos ("BurstStyle", ComicFxController) y la decoración
--     del nido ("NestDecor", NestController del Lobby). Los emotes los hace el cliente (UI/EmoteWheel).
--   - De un cosmético por grados (I, II, III) se publica y se dibuja el grado más alto que se tiene.
--   - Guarda el mejor equipo fabricado en la Isla con cada rol (perfil "bestGear", recordGear) y, en el
--     Lobby y en Dunas (start con "showBestGear"), lo luce: la armadura en "ArmorLook" (Shared/ArmorModels)
--     y el nivel del arma de rol en "WeaponLook" (Shared/WeaponTools). Solo el aspecto: los números siguen
--     siendo los de la armadura ("Armor", que aquí no hay) y el arma que se lleva.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
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
-- Si este place luce el mejor equipo fabricado (Lobby y Dunas; en la Isla se lleva el de la partida).
local showBestGear = false

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

-- La mejor armadura y el mejor nivel del arma de rol fabricados con "roleId" (nil si ninguno o el 1).
local function bestGearOf(profile: PlayerData.Profile, roleId: string): (string?, number?)
	local best = profile.bestGear[roleId]
	if typeof(best) ~= "table" then
		return nil, nil
	end
	local armorId = if typeof(best.armor) == "string" and Armor[best.armor] then best.armor else nil
	local level = if typeof(best.weapon) == "number" and best.weapon > 1
		then math.min(best.weapon, WeaponTools.MAX_LEVEL)
		else nil
	return armorId, level
end

-- Publica el traje ("Outfit") y el aspecto del arma ("WeaponSkin") equipados del rol que juega, el del
-- machete ("MacheteSkin") y, si este place lo luce, su mejor equipo ("ArmorLook" y "WeaponLook"); si
-- cambian (o con "force", al aparecer), lo viste y cambia el aspecto de sus armas.
local function applyRoleCosmetics(player: Player, force: boolean?)
	local profile = PlayerData.get(player)
	local roleId = player:GetAttribute("Role")
	local outfitId, skinId, armorLook, weaponLook = nil, nil, nil, nil
	if profile and typeof(roleId) == "string" then
		outfitId = equippedOwned(player, profile, `Outfit.{roleId}`, ArmorModels.hasOutfit)
		skinId = equippedOwned(player, profile, `WeaponSkin.{roleId}`, WeaponTools.hasSkin)
		if showBestGear then
			armorLook, weaponLook = bestGearOf(profile, roleId)
		end
	end
	local macheteId = if profile then equippedOwned(player, profile, "WeaponSkin.Machete", WeaponTools.hasSkin) else nil
	if force or player:GetAttribute("Outfit") ~= outfitId or player:GetAttribute("ArmorLook") ~= armorLook then
		player:SetAttribute("Outfit", outfitId)
		player:SetAttribute("ArmorLook", armorLook)
		local character = player.Character
		if character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) then
			ArmorModels.dress(player, character)
		end
	end
	if
		player:GetAttribute("WeaponSkin") ~= skinId
		or player:GetAttribute("MacheteSkin") ~= macheteId
		or player:GetAttribute("WeaponLook") ~= weaponLook
	then
		player:SetAttribute("WeaponSkin", skinId)
		player:SetAttribute("MacheteSkin", macheteId)
		player:SetAttribute("WeaponLook", weaponLook)
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

-- Anillo invisible (soldado a la raíz) del que sale parte del aura: a los pies las llamas y la arena
-- (desde la raíz salían dentro del cuerpo y no se veían) y sobre la cabeza la nube y los pétalos.
-- "height" es su altura sobre la raíz (negativa: los pies).
local function ring(root: BasePart, height: number, width: number?): Part
	local part = Instance.new("Part")
	part.Name = "CosmeticAura"
	part.Size = Vector3.new(width or 4, 0.2, width or 4)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0, height, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = root
	return part
end

local function feetRing(root: BasePart): Part
	return ring(root, -root.Size.Y / 2 - 1.8)
end

-- Auras con otra forma ("look" en Data/Cosmetics) en vez de las chispas:
--   Sand    polvo de arena que gira a los pies y granos que brillan
--   Storm   una nube negra sobre la cabeza que suelta chispas eléctricas hacia abajo, y su luz
--   Petals  pétalos de su color y blancos que caen despacio desde encima de la cabeza
local LOOKS: { [string]: (root: BasePart, cosmetic: Cosmetics.Cosmetic) -> () } = {
	Sand = function(root, cosmetic)
		local dust = emitter(feetRing(root), "smoke_main.dds")
		dust.Shape = Enum.ParticleEmitterShape.Cylinder
		dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		dust.Color = ColorSequence.new(cosmetic.color, cosmetic.color:Lerp(Color3.fromRGB(150, 120, 80), 0.4))
		dust.Size = NumberSequence.new(0.8, 1.8)
		dust.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		dust.Rate = 14
		dust.Lifetime = NumberRange.new(1.2, 1.8)
		dust.Speed = NumberRange.new(0.4, 0.9)
		dust.Acceleration = Vector3.new(0, 1.2, 0)
		dust.Rotation = NumberRange.new(0, 360)
		dust.RotSpeed = NumberRange.new(120, 200)
		local grains = emitter(feetRing(root), "sparkles_main.dds")
		grains.Shape = Enum.ParticleEmitterShape.Cylinder
		grains.Color = ColorSequence.new(Color3.fromRGB(255, 235, 170), cosmetic.color)
		grains.Size = NumberSequence.new(0.18, 0)
		grains.Rate = 16
		grains.Lifetime = NumberRange.new(0.8, 1.4)
		grains.Speed = NumberRange.new(1, 2.5)
		grains.EmissionDirection = Enum.NormalId.Top
		grains.SpreadAngle = Vector2.new(30, 30)
		grains.Acceleration = Vector3.new(0, -2, 0)
		grains.LightEmission = 0.7
	end,
	Storm = function(root, cosmetic)
		local cloud = ring(root, 4.2, 3)
		local smoke = emitter(cloud, "smoke_main.dds")
		smoke.Shape = Enum.ParticleEmitterShape.Box
		smoke.Color = ColorSequence.new(Color3.fromRGB(55, 58, 70), Color3.fromRGB(35, 36, 45))
		smoke.Size = NumberSequence.new(1.4, 2.2)
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Rate = 14
		smoke.Lifetime = NumberRange.new(1.4, 2)
		smoke.Speed = NumberRange.new(0.1, 0.3)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Rotation = NumberRange.new(0, 360)
		smoke.RotSpeed = NumberRange.new(-20, 20)
		local bolts = emitter(cloud, "sparkles_main.dds")
		bolts.Shape = Enum.ParticleEmitterShape.Box
		bolts.Color = ColorSequence.new(Color3.new(1, 1, 1), cosmetic.color)
		bolts.Size = NumberSequence.new(0.5, 0.15)
		-- Positivo: altas y finas (rayos), no anchas.
		bolts.Squash = NumberSequence.new(2)
		bolts.Rate = 20
		bolts.Lifetime = NumberRange.new(0.15, 0.3)
		bolts.Speed = NumberRange.new(8, 12)
		bolts.EmissionDirection = Enum.NormalId.Bottom
		bolts.SpreadAngle = Vector2.new(15, 15)
		bolts.LightEmission = 1
		bolts.Brightness = 3
		local light = Instance.new("PointLight")
		light.Name = "CosmeticAura"
		light.Color = cosmetic.color
		light.Range = 9
		light.Brightness = 1.2
		light.Parent = cloud
	end,
	Petals = function(root, cosmetic)
		local petals = emitter(ring(root, 4, 5), "sparkles_main.dds")
		petals.Shape = Enum.ParticleEmitterShape.Box
		petals.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, cosmetic.color),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 245)),
			ColorSequenceKeypoint.new(1, cosmetic.color),
		})
		petals.Size = NumberSequence.new(0.35)
		petals.Squash = NumberSequence.new(0.6)
		petals.Rate = 10
		petals.Lifetime = NumberRange.new(2.5, 3.5)
		petals.Speed = NumberRange.new(0.2, 0.6)
		petals.SpreadAngle = Vector2.new(180, 180)
		petals.Acceleration = Vector3.new(0, -1.6, 0)
		petals.Drag = 1
		petals.Rotation = NumberRange.new(0, 360)
		petals.RotSpeed = NumberRange.new(-90, 90)
		petals.LightEmission = 0.3
	end,
}

-- Huellas de la estela ("footprints"): mientras el personaje anda por el suelo, cada FOOTPRINT_STEP
-- studs deja un pie de neón de ese color, alternando el izquierdo y el derecho, que se enfría hasta
-- un tono oscuro y se apaga. Se guardan en Workspace.CosmeticFootprints (sin colisión ni consultas).
-- Dura mientras esté su marca en la raíz: applyVisuals la borra con lo demás.
local FOOTPRINT_STEP = 2.4
local FOOTPRINT_COOL = 1.2
local FOOTPRINT_FADE = 1.6

local function footprints(root: BasePart, color: Color3)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid) then
		return
	end
	local mark = Instance.new("Configuration")
	mark.Name = "CosmeticTrail"
	mark.Parent = root
	local folder = workspace:FindFirstChild("CosmeticFootprints")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CosmeticFootprints"
		folder.Parent = workspace
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, folder }
	params.IgnoreWater = true
	local cooled = color:Lerp(Color3.fromRGB(40, 32, 30), 0.85)
	task.spawn(function()
		local last = root.Position
		local side = 1
		while mark.Parent and root.Parent do
			task.wait(0.1)
			local moved = Vector3.new(root.Position.X - last.X, 0, root.Position.Z - last.Z)
			if humanoid.FloorMaterial ~= Enum.Material.Air and moved.Magnitude >= FOOTPRINT_STEP then
				last = root.Position
				local facing = CFrame.lookAlong(Vector3.zero, moved.Unit)
				local from = root.Position + facing.RightVector * side * 0.45
				local hit = workspace:Raycast(from, Vector3.new(0, -root.Size.Y / 2 - 4, 0), params)
				if hit then
					local foot = Instance.new("Part")
					foot.Name = "Footprint"
					foot.Anchored = true
					foot.CanCollide = false
					foot.CanQuery = false
					foot.CanTouch = false
					foot.CastShadow = false
					foot.Material = Enum.Material.Neon
					foot.Color = color
					foot.Size = Vector3.new(0.55, 0.06, 0.9)
					foot.CFrame = CFrame.lookAlong(hit.Position + hit.Normal * 0.03, moved.Unit)
					foot.Parent = folder
					TweenService:Create(foot, TweenInfo.new(FOOTPRINT_COOL), { Color = cooled }):Play()
					TweenService:Create(
						foot,
						TweenInfo.new(
							FOOTPRINT_FADE,
							Enum.EasingStyle.Linear,
							Enum.EasingDirection.In,
							0,
							false,
							FOOTPRINT_COOL
						),
						{ Transparency = 1 }
					):Play()
					task.delay(FOOTPRINT_COOL + FOOTPRINT_FADE, function()
						foot:Destroy()
					end)
				end
				side = -side
			end
		end
	end)
end

-- La estela: una por cada franja de "colors" (de arriba abajo) o una de "color"; de Épico arriba,
-- más larga y más brillante; con "sparkle", chispas que caen y se quedan atrás al correr; con
-- "footprints", huellas en el suelo.
local function trail(root: BasePart, cosmetic: Cosmetics.Cosmetic)
	local colors = cosmetic.colors or { cosmetic.color }
	local rich = cosmetic.rarity == "Epic" or cosmetic.rarity == "Legendary" or cosmetic.rarity == "Mythic"
	local points = {}
	for index = 0, #colors do
		local point = Instance.new("Attachment")
		point.Name = "CosmeticAttachment"
		point.Position = Vector3.new(0, 1 - index * 2 / #colors, 0)
		point.Parent = root
		points[index] = point
	end
	for index, color in colors do
		local stripe = Instance.new("Trail")
		stripe.Name = "CosmeticTrail"
		stripe.Attachment0 = points[index - 1]
		stripe.Attachment1 = points[index]
		stripe.Color = ColorSequence.new(color)
		stripe.Transparency = NumberSequence.new(0.3, 1)
		stripe.Lifetime = if rich then 0.9 else 0.6
		stripe.LightEmission = cosmetic.emission or if rich then 1 else 0.5
		stripe.Parent = root
	end
	if cosmetic.sparkle then
		local sparks = emitter(root, "sparkles_main.dds")
		sparks.Name = "CosmeticTrail"
		sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), cosmetic.sparkle)
		sparks.Size = NumberSequence.new(0.3, 0)
		sparks.Rate = 14
		sparks.Lifetime = NumberRange.new(0.8, 1.2)
		sparks.Speed = NumberRange.new(0.3, 1)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, -3, 0)
		sparks.LightEmission = 1
	end
	if cosmetic.footprints then
		footprints(root, cosmetic.footprints)
	end
end

-- El aura: chispas de su color y, por grados, más cosas (II: más chispas y un anillo de llamas que
-- sube desde los pies; III: llamas más altas y brillantes, brasas rápidas, humo oscuro y una luz de su
-- color).
local function aura(root: BasePart, cosmetic: Cosmetics.Cosmetic)
	local look = if cosmetic.look then LOOKS[cosmetic.look] else nil
	if look then
		look(root, cosmetic)
		return
	end
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
				trail(root, cosmetic)
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

-- Le quita un cosmético guardado (panel de administración, T4d) y se lo quita de encima si lo llevaba.
-- Los de Game Pass no se pueden quitar (se tienen por el pase). Devuelve true si lo tenía.
function CosmeticsServer.revoke(player: Player, cosmeticId: string): boolean
	local profile = PlayerData.get(player)
	if not (profile and profile.ownedCosmetics[cosmeticId]) then
		return false
	end
	PlayerData.update(player, function(current)
		current.ownedCosmetics[cosmeticId] = nil
		for slot, equipped in table.clone(current.cosmetics) do
			if equipped == cosmeticId then
				current.cosmetics[slot] = nil
			end
		end
	end)
	refreshOwnership(player)
	applyVisuals(player)
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

-- Apunta en el perfil de "player" lo que acaba de fabricar con "roleId" en la Isla (la armadura
-- "armorId" o el arma de rol del nivel "weaponLevel") si es lo mejor que tiene de ese rol.
function CosmeticsServer.recordGear(player: Player, roleId: string, armorId: string?, weaponLevel: number?)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local armorBest, levelBest = bestGearOf(profile, roleId)
	local betterArmor = armorId ~= nil and ArmorModels.grade(armorId) > ArmorModels.grade(armorBest)
	local betterWeapon = weaponLevel ~= nil and weaponLevel > (levelBest or 1)
	if not (betterArmor or betterWeapon) then
		return
	end
	PlayerData.update(player, function(current)
		local best = { armor = armorBest, weapon = levelBest }
		if betterArmor then
			best.armor = armorId
		end
		if betterWeapon then
			best.weapon = weaponLevel
		end
		current.bestGear[roleId] = best
	end)
end

-- Prueba (panel de Studio, Lobby y Dunas): pasa el mejor equipo guardado del rol que juega al grado
-- siguiente (armadura de ese grado y arma de ese nivel), y tras el último a ninguno. Devuelve el grado.
function CosmeticsServer.debugNextBestGear(player: Player): number
	local roleId = player:GetAttribute("Role")
	local profile = PlayerData.get(player)
	if not (profile and typeof(roleId) == "string") then
		return 0
	end
	local grade = (ArmorModels.grade((bestGearOf(profile, roleId))) + 1) % (ArmorModels.MAX_GRADE + 1)
	PlayerData.update(player, function(current)
		current.bestGear[roleId] = if grade > 0 then { armor = ArmorModels.BY_GRADE[grade], weapon = grade } else nil
	end)
	applyRoleCosmetics(player)
	return grade
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
				available = function(_profile, player)
					if owns(player, cosmeticId) then
						return false, `✅ Ya tienes {cosmetic.icon} {cosmetic.name}`
					end
					return true, nil
				end,
			})
		end
	end
end

-- "showBestGear": este place luce el mejor equipo fabricado en la Isla (Lobby y Dunas).
function CosmeticsServer.start(options: { showBestGear: boolean? }?)
	showBestGear = options ~= nil and options.showBestGear == true
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
