--!strict
-- Expositor del equipo (panel de pruebas del Lobby y de Dunas, solo Studio): delante del jugador, una fila
-- por rol con copias de su personaje. Primero una por grado de armadura (Data/Armor, en la versión de ese
-- rol: Shared/ArmorModels) con el arma de rol del mismo nivel de pie a su lado (Shared/WeaponTools) y,
-- tras un hueco, una por traje del rol (Data/Cosmetics "Outfit": el del pase, el mítico…) entero, como se
-- ve en el Lobby y en Dunas, con su aspecto de arma en el arma del último nivel. Encima, sus nombres (los
-- trajes, del color de su rareza). Miran al jugador; la espalda se ve rodeándolas. Pulsar otra vez las
-- quita.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArmorModels = require(ReplicatedStorage.Shared.ArmorModels)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)

local FOLDER_NAME = "DebugGearShowcase"
local FIRST_ROW = 10 -- de la primera fila (el primer rol) al jugador
local ROW_STEP = 10 -- entre una fila y la siguiente
local COLUMN_STEP = 8 -- entre las copias de una fila
local OUTFIT_GAP = 4 -- de más, entre las armaduras y los trajes
local WEAPON_SIDE = 2.8 -- de la copia a su arma
-- Lo que la copia no tiene que llevar: lo de la vida (scripts, sonidos, carteles), el arma de la mano,
-- la armadura o el traje que lleve y los efectos de sus cosméticos.
local STRIP = { "BaseScript", "Sound", "BillboardGui", "Tool", "ParticleEmitter", "Trail", "Beam", "Light" }
local STRIP_NAMES = { "ArmorPiece", "CosmeticAura", "CosmeticAttachment", "CosmeticTrail" }
local WHITE = Color3.new(1, 1, 1)

-- Lo que lleva una copia: armadura o traje, el arma de al lado (con su aspecto) y el cartel.
type Exhibit = {
	armorId: string?,
	outfitId: string?,
	weaponId: string?,
	skinId: string?,
	text: string,
	color: Color3,
	gap: number, -- hueco de más a su izquierda (visto desde el jugador) desde la primera copia
}

local GearShowcase = {}

local function rolesInOrder(): { string }
	local ids = {}
	for roleId in Roles do
		table.insert(ids, roleId)
	end
	table.sort(ids, function(a, b)
		return Roles[a].order < Roles[b].order
	end)
	return ids
end

local function withoutPrefix(name: string): string
	return (string.gsub(name, "^[^:]+: ", ""))
end

-- El aspecto de arma que acompaña al traje "outfitId": el del rol que le sigue en el orden de Data/Cosmetics
-- (cada traje va justo antes del suyo).
local function pairedSkin(outfitId: string): string?
	local outfit = Cosmetics[outfitId]
	local bestId, bestOrder = nil, math.huge
	for cosmeticId, cosmetic in Cosmetics do
		if
			cosmetic.kind == "WeaponSkin"
			and cosmetic.role == outfit.role
			and cosmetic.order > outfit.order
			and cosmetic.order < bestOrder
			and WeaponTools.hasSkin(cosmeticId)
		then
			bestId, bestOrder = cosmeticId, cosmetic.order
		end
	end
	return bestId
end

-- Lo que se expone de "roleId": sus armaduras por grado y sus trajes por orden.
local function exhibitsOf(roleId: string): { Exhibit }
	local role = Roles[roleId]
	local exhibits: { Exhibit } = {}
	for grade, armorId in ArmorModels.BY_GRADE do
		local weaponId = WeaponTools.roleWeapon(roleId, grade)
		local weaponName = if weaponId then Weapons[weaponId].name else "—"
		table.insert(exhibits, {
			armorId = armorId,
			weaponId = weaponId,
			text = `{role.icon} {Crafting.armorName(armorId, roleId)}\n{grade} · {weaponName}`,
			color = WHITE,
			gap = 0,
		})
	end
	local outfitIds = {}
	for cosmeticId, cosmetic in Cosmetics do
		if cosmetic.kind == "Outfit" and cosmetic.role == roleId and ArmorModels.hasOutfit(cosmeticId) then
			table.insert(outfitIds, cosmeticId)
		end
	end
	table.sort(outfitIds, function(a, b)
		return Cosmetics[a].order < Cosmetics[b].order
	end)
	for _, outfitId in outfitIds do
		local outfit = Cosmetics[outfitId]
		local skinId = pairedSkin(outfitId)
		local rarity = Rarities[outfit.rarity]
		local from = if outfit.source.season then ` · pase {outfit.source.season}` else ""
		local skinName = if skinId then withoutPrefix(Cosmetics[skinId].name) else "—"
		table.insert(exhibits, {
			outfitId = outfitId,
			weaponId = WeaponTools.roleWeapon(roleId, WeaponTools.MAX_LEVEL),
			skinId = skinId,
			text = `{outfit.icon} {withoutPrefix(outfit.name)}\n{rarity.name}{from} · {skinName}`,
			color = rarity.color,
			gap = OUTFIT_GAP,
		})
	end
	return exhibits
end

-- Quieto y que no estorbe: ni choca ni lo encuentran los golpes (Combat/Hitbox busca con consultas).
local function freeze(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

-- Copia del personaje sin nada puesto, o nil si no se puede copiar.
local function mannequin(character: Model): Model?
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil
	end
	for _, child in copy:GetDescendants() do
		local strip = table.find(STRIP_NAMES, child.Name) ~= nil
		for _, className in STRIP do
			strip = strip or child:IsA(className)
		end
		if strip and child.Parent then
			child:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return copy
end

local function label(parent: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	-- En studs: los de las filas de atrás se ven más pequeños y no tapan los de delante.
	billboard.Size = UDim2.fromScale(COLUMN_STEP, 1.6)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 120
	billboard.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Font = Enum.Font.BuilderSansBold
	textLabel.TextScaled = true
	-- Dos líneas siempre: las largas (los trajes) se hacen más pequeñas en vez de partirse.
	textLabel.TextWrapped = false
	textLabel.Text = text
	textLabel.Parent = billboard
end

-- Pone o quita el expositor delante de "player".
function GearShowcase.toggle(player: Player)
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, character }
	local function groundAt(position: Vector3): number?
		local hit = Workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
		return if hit then hit.Position.Y else nil
	end

	local pivot = character:GetPivot()
	local forward = (pivot.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = forward:Cross(Vector3.yAxis)
	-- Altura de la raíz sobre el suelo, la misma en todas las copias.
	local ownGround = groundAt(pivot.Position) or pivot.Position.Y - 3
	local rootHeight = pivot.Position.Y - ownGround

	for row, roleId in rolesInOrder() do
		local exhibits = exhibitsOf(roleId)
		-- Ancho de la fila, para centrarla delante del jugador.
		local width = (#exhibits - 1) * COLUMN_STEP
		for _, exhibit in exhibits do
			width += exhibit.gap
		end
		local offset = -width / 2
		for index, exhibit in exhibits do
			-- Si se ha quitado mientras se montaba, se deja de montar.
			if folder.Parent == nil then
				return
			end
			if index > 1 then
				offset += COLUMN_STEP
			end
			offset += exhibit.gap
			local copy = mannequin(character)
			if not copy then
				return
			end
			ArmorModels.wear(copy, exhibit.armorId, roleId, exhibit.outfitId, ArmorModels.MAX_GRADE)
			freeze(copy)
			local spot = pivot.Position + forward * (FIRST_ROW + (row - 1) * ROW_STEP) + right * offset
			local ground = groundAt(spot) or ownGround
			local place = CFrame.lookAt(Vector3.new(spot.X, ground + rootHeight, spot.Z), spot - forward * 10)
			copy:PivotTo(place)
			copy.Name = `{roleId} {index}`
			copy.Parent = folder

			if exhibit.weaponId then
				local weapon = WeaponTools.previewWeapon(exhibit.weaponId, exhibit.skinId)
				freeze(weapon)
				-- De pie, al lado izquierdo de la copia visto desde el jugador.
				weapon:PivotTo(CFrame.new(place.Position - right * WEAPON_SIDE) * place.Rotation)
				local box, size = weapon:GetBoundingBox()
				weapon:PivotTo(weapon:GetPivot() + Vector3.new(0, ground - (box.Position.Y - size.Y / 2), 0))
				weapon.Parent = folder
			end
			local head = copy:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				label(head, exhibit.text, exhibit.color, 3.2)
			end
		end
		task.wait()
	end
end

return GearShowcase
