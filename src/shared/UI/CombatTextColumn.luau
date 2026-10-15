--!strict
-- Columna de números de combate (Config.CombatText): el número nuevo entra abajo con un "pop" y
-- empuja hacia arriba a los anteriores, que se van desvaneciendo; caben Slots (4) y cada uno dura
-- LifetimeSeconds. Los críticos entran más grandes y con un temblor.
-- También la usa la columna de lo que recoges (con sus propios huecos y duración): una línea con la
-- misma "key" que la más nueva la sustituye en su sitio ("+1 Madera" → "+3 Madera").
-- Va dentro de cualquier marco ("container"): un BillboardGui sobre una cabeza, una columna del alto
-- del personaje o un marco fijo en la pantalla. La usan CombatTextController y la vista previa del
-- panel de Ajustes (UI/SettingsPanel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local SETTINGS = Config.CombatText
-- Alto del número normal respecto al hueco (el crítico, ×CritTextScale, lo llena).
local BASE_HEIGHT = 0.8
-- Transparencia según la altura: abajo el más nuevo, arriba el más viejo.
local SLOT_TRANSPARENCY = { 0, 0.25, 0.5, 0.75 }
local MOVE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHAKE = TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.25)

export type Align = "Left" | "Right" | "Center"
export type Style = {
	color: Color3,
	crit: boolean?,
	scale: number?, -- tamaño (1 = el del jugador; la mascota y los aliados, menos)
	dim: number?, -- 0-1: más tenue (los aliados)
	key: string?, -- si la línea más nueva tiene la misma, se cambia su texto en vez de añadir otra
}
export type Options = {
	slots: number?, -- por defecto Config.CombatText.Slots
	lifetime: number?, -- por defecto Config.CombatText.LifetimeSeconds
}

-- "generation" sube cada vez que se reutiliza la etiqueta (pool): así el temporizador de un número
-- viejo no borra al nuevo.
type Entry = {
	label: TextLabel,
	scale: UIScale,
	dim: number,
	expired: boolean,
	generation: number,
	key: string?,
}

export type Column = {
	push: (self: Column, text: string, style: Style) -> (),
	isIdle: (self: Column) -> boolean,
	clear: (self: Column) -> (),
	destroy: (self: Column) -> (),
}

local CombatTextColumn = {}

local ALIGNMENT: { [string]: Enum.TextXAlignment } = {
	Left = Enum.TextXAlignment.Left,
	Right = Enum.TextXAlignment.Right,
	Center = Enum.TextXAlignment.Center,
}
local ANCHOR_X: { [string]: number } = { Left = 0, Right = 1, Center = 0.5 }

-- Una columna dentro de "container". "align": hacia dónde se pegan los números (la columna de la
-- izquierda de la cabeza se alinea a la derecha, para quedar junto a ella).
function CombatTextColumn.new(container: GuiObject, align: Align, options: Options?): Column
	local entries: { Entry } = {}
	local pool: { Entry } = {}
	local slots = options and options.slots or SETTINGS.Slots
	local lifetime = options and options.lifetime or SETTINGS.LifetimeSeconds
	local anchorX = ANCHOR_X[align]
	local destroyed = false

	local function transparencyAt(index: number, dim: number): number
		local base = SLOT_TRANSPARENCY[math.min(index, #SLOT_TRANSPARENCY)]
		return 1 - (1 - base) * (1 - dim)
	end

	local function newEntry(): Entry
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextScaled = true
		label.TextXAlignment = ALIGNMENT[align]
		label.AnchorPoint = Vector2.new(anchorX, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(25, 15, 10)
		stroke.Parent = label
		local scale = Instance.new("UIScale")
		scale.Parent = label
		return { label = label, scale = scale, dim = 0, expired = false, generation = 0 }
	end

	local function release(entry: Entry)
		if destroyed then
			entry.label:Destroy()
			return
		end
		entry.label.Parent = nil
		if #pool < slots + 2 then
			table.insert(pool, entry)
		else
			entry.label:Destroy()
		end
	end

	local function remove(entry: Entry)
		if entry.expired then
			return
		end
		entry.expired = true
		local index = table.find(entries, entry)
		if index then
			table.remove(entries, index)
		end
		-- Se va subiendo un poco más mientras se desvanece.
		local stroke = entry.label:FindFirstChildOfClass("UIStroke")
		local position = entry.label.Position
		TweenService:Create(entry.label, FADE, {
			TextTransparency = 1,
			Position = UDim2.fromScale(position.X.Scale, position.Y.Scale - 0.5 / slots),
		}):Play()
		if stroke then
			TweenService:Create(stroke, FADE, { Transparency = 1 }):Play()
		end
		task.delay(FADE.Time, release, entry)
	end

	-- Coloca cada número en su hueco (1 = abajo) con su transparencia.
	local function layout()
		for index, entry in entries do
			local y = 1 - (index - 1) / slots
			local transparency = transparencyAt(index, entry.dim)
			TweenService:Create(entry.label, MOVE, {
				Position = UDim2.fromScale(anchorX, y),
				TextTransparency = transparency,
			}):Play()
			local stroke = entry.label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, MOVE, { Transparency = math.min(1, transparency + 0.15) }):Play()
			end
		end
	end

	local column = {} :: Column

	-- Borra "entry" al acabar su tiempo, salvo que se haya reutilizado o renovado antes.
	local function expireLater(entry: Entry)
		local generation = entry.generation
		task.delay(lifetime, function()
			if entry.generation == generation then
				remove(entry)
			end
		end)
	end

	function column.push(_self: Column, text: string, style: Style)
		if destroyed then
			return
		end
		local newest = entries[1]
		if style.key and newest and newest.key == style.key and not newest.expired then
			-- La misma cosa otra vez: se cambia el texto en su sitio con un "pop" suave.
			newest.generation += 1
			newest.label.Text = text
			newest.scale.Scale = 1.2
			TweenService:Create(newest.scale, POP, { Scale = 1 }):Play()
			expireLater(newest)
			return
		end
		local entry = table.remove(pool) or newEntry()
		local crit = style.crit == true
		local size = (style.scale or 1) * (if crit then SETTINGS.CritTextScale else 1)
		entry.expired = false
		entry.generation += 1
		entry.key = style.key
		entry.dim = style.dim or 0
		local label = entry.label
		label.Text = if crit then `{text}!` else text
		label.TextColor3 = style.color
		label.Size = UDim2.fromScale(1, BASE_HEIGHT * size / slots)
		label.Position = UDim2.fromScale(anchorX, 1)
		label.TextTransparency = entry.dim
		label.Rotation = 0
		label.ZIndex = if crit then 3 else 2
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = if crit then 3 else 2
			stroke.Transparency = math.min(1, entry.dim + 0.15)
		end
		label.Parent = container

		-- Entra con un "pop"; el crítico, más fuerte y con un temblor.
		entry.scale.Scale = if crit then 1.7 else 1.35
		TweenService:Create(entry.scale, POP, { Scale = 1 }):Play()
		if crit then
			label.Rotation = if math.random() < 0.5 then -8 else 8
			TweenService:Create(label, SHAKE, { Rotation = 0 }):Play()
		end

		table.insert(entries, 1, entry)
		while #entries > slots do
			remove(entries[#entries])
		end
		layout()
		expireLater(entry)
	end

	function column.isIdle(_self: Column): boolean
		return #entries == 0
	end

	function column.clear(_self: Column)
		for index = #entries, 1, -1 do
			remove(entries[index])
		end
	end

	function column.destroy(_self: Column)
		destroyed = true
		for _, entry in entries do
			entry.expired = true
			entry.label:Destroy()
		end
		for _, entry in pool do
			entry.label:Destroy()
		end
		table.clear(entries)
		table.clear(pool)
	end

	return column
end

return CombatTextColumn
