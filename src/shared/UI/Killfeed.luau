--!strict
-- Registro de bajas (Fase 19, W9): filas apiladas arriba a la derecha, solo UI (Frames). Lo monta
-- CombatClient/KillfeedController con lo que manda Combat/Killfeed.
--   local feed = Killfeed.mount(parent); feed.add(entry); feed.destroy()
-- Fila: [asesino] [arma] [marca de cabeza] [víctima]. Un jefe: "[asesino] derrota a [jefe]". Sin asesino:
-- "[víctima] ha caído". Las filas del jugador local (asesino o víctima) llevan un borde cálido. Los nombres toman
-- el color de equipo si el jugador tiene Team. El icono del arma es un ViewportFrame con el modelo en caché
-- (uno por arma, clonado en cada fila). Nada de emojis: la marca de cabeza y el icono genérico se dibujan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local Strings = require(ReplicatedStorage.Shared.Strings)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)

local T = Strings.t

export type Entry = {
	killer: string?,
	killerId: number?,
	victim: string,
	victimId: number?,
	weaponId: string?,
	zone: string?,
	boss: boolean?,
}

export type Feed = { add: (entry: Entry) -> (), destroy: () -> () }

local HEAD_COLOR = Color3.fromRGB(255, 190, 50) -- como el hitmarker de cabeza (Config.HitFeedback)
local MINE_STROKE = Color3.fromRGB(255, 200, 80)
local MINE_FILL = Color3.fromRGB(70, 48, 12)
local ROW_FILL = Color3.fromRGB(20, 16, 12)
local ICON_FALLBACK = Color3.fromRGB(190, 190, 200)
local FADE_SECONDS = 0.5
-- En teléfono las filas son más pequeñas.
local PHONE_ICON_SCALE = 0.75

local Killfeed = {}

-- Un modelo por arma (false si no se pudo construir), compartido por todas las filas.
local modelCache: { [string]: Model | false } = {}

local function weaponModel(weaponId: string): Model?
	local cached = modelCache[weaponId]
	if cached == nil then
		local ok, model = pcall(WeaponTools.previewWeapon, weaponId, nil)
		cached = if ok then model else false
		modelCache[weaponId] = cached
	end
	return if cached then cached else nil
end

-- Color de equipo del jugador con ese UserId, o blanco.
local function nameColor(userId: number?): Color3
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	local team = if player then player.Team else nil
	return if team then team.TeamColor.Color else Color3.new(1, 1, 1)
end

function Killfeed.mount(parent: Instance): Feed
	local settings = Config.Killfeed
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local iconPx = if phone then math.round(settings.IconPx * PHONE_ICON_SCALE) else settings.IconPx
	local textSize = if phone then 13 else 16
	local localId = Players.LocalPlayer.UserId

	-- Debajo de los marcadores de arriba a la derecha de cada place (reloj de la Isla, bajas del Laboratorio,
	-- HUD de la arena), anclado a la derecha.
	local column = Instance.new("Frame")
	column.Name = "Killfeed"
	column.AnchorPoint = Vector2.new(1, 0)
	column.Position = UDim2.new(1, -16, 0, 170)
	column.Size = UDim2.fromOffset(0, 0)
	column.AutomaticSize = Enum.AutomaticSize.XY
	column.BackgroundTransparency = 1
	column.Parent = parent
	local columnLayout = Instance.new("UIListLayout")
	columnLayout.FillDirection = Enum.FillDirection.Vertical
	columnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Padding = UDim.new(0, 4)
	columnLayout.Parent = column

	local rows: { CanvasGroup } = {}
	local counter = 0
	local alive = true

	local function text(row: Instance, content: string, color: Color3?): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, iconPx)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = textSize
		label.TextColor3 = color or Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.5
		label.Text = content
		label.Parent = row
		return label
	end

	-- Icono genérico del arma: una barra en diagonal, para las que no tienen modelo.
	local function genericIcon(holder: Frame)
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(4, iconPx * 0.8)
		bar.Rotation = 45
		bar.BackgroundColor3 = ICON_FALLBACK
		bar.BorderSizePixel = 0
		bar.Parent = holder
	end

	local function weaponIcon(row: Instance, weaponId: string?)
		local model = if weaponId then weaponModel(weaponId) else nil
		if model then
			local viewport = Instance.new("ViewportFrame")
			viewport.Name = "Weapon"
			viewport.Size = UDim2.fromOffset(iconPx, iconPx)
			viewport.BackgroundTransparency = 1
			viewport.Parent = row
			RewardModels.frame(viewport, model:Clone(), 1)
		else
			local holder = Instance.new("Frame")
			holder.Name = "Weapon"
			holder.Size = UDim2.fromOffset(iconPx, iconPx)
			holder.BackgroundTransparency = 1
			holder.Parent = row
			genericIcon(holder)
		end
	end

	-- Marca de cabeza: un círculo con un punto en el centro, del amarillo-naranja del hitmarker de cabeza.
	local function headMark(row: Instance)
		local size = math.round(iconPx * 0.5)
		local holder = Instance.new("Frame")
		holder.Name = "HeadMark"
		holder.Size = UDim2.fromOffset(size + 4, iconPx)
		holder.BackgroundTransparency = 1
		holder.Parent = row
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromOffset(size, size)
		ring.BackgroundTransparency = 1
		ring.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = HEAD_COLOR
		stroke.Thickness = 2
		stroke.Parent = ring
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(4, 4)
		dot.BackgroundColor3 = HEAD_COLOR
		dot.BorderSizePixel = 0
		dot.Parent = ring
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot
	end

	local function remove(row: CanvasGroup)
		local index = table.find(rows, row)
		if index then
			table.remove(rows, index)
		end
		row:Destroy()
	end

	local function add(entry: Entry)
		if not alive then
			return
		end
		counter += 1
		local mine = entry.killerId == localId or entry.victimId == localId

		local row = Instance.new("CanvasGroup")
		row.Name = "Row"
		row.LayoutOrder = counter
		row.Size = UDim2.fromOffset(0, iconPx + 6)
		row.AutomaticSize = Enum.AutomaticSize.X
		row.BackgroundColor3 = if mine then MINE_FILL else ROW_FILL
		row.BackgroundTransparency = if mine then 0.25 else 0.5
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		if mine then
			local stroke = Instance.new("UIStroke")
			stroke.Color = MINE_STROKE
			stroke.Thickness = 2
			stroke.Parent = row
		end
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 5)
		layout.Parent = row
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = row

		local killerName = entry.killer
		if entry.boss then
			if killerName then
				text(row, killerName, nameColor(entry.killerId))
				text(row, T("derrota a"))
				text(row, T(entry.victim))
			else
				text(row, T("{victim} ha caído", { victim = T(entry.victim) }))
			end
		elseif killerName then
			text(row, killerName, nameColor(entry.killerId))
			weaponIcon(row, entry.weaponId)
			if entry.zone == "Head" then
				headMark(row)
			end
			text(row, entry.victim, nameColor(entry.victimId))
		else
			text(row, T("{victim} ha caído", { victim = entry.victim }), nameColor(entry.victimId))
		end

		-- UIListLayout hace que todo quede alineado a la derecha, y los hijos se ordenan por creación.
		for index, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				child.LayoutOrder = index
			end
		end

		row.Parent = column
		table.insert(rows, row)
		while #rows > settings.Rows do
			remove(rows[1])
		end

		-- Vive Seconds y se funde al final.
		task.delay(math.max(0, settings.Seconds - FADE_SECONDS), function()
			if row.Parent == nil then
				return
			end
			local tween = TweenService:Create(row, TweenInfo.new(FADE_SECONDS), { GroupTransparency = 1 })
			tween.Completed:Connect(function()
				if row.Parent then
					remove(row)
				end
			end)
			tween:Play()
		end)
	end

	local function destroy()
		alive = false
		column:Destroy()
		table.clear(rows)
	end

	return { add = add, destroy = destroy }
end

return Killfeed
