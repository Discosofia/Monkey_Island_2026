--!strict
-- Ajustes del jugador (panel UI/SettingsPanel, en la Isla con el botón ⚙️ y en el Lobby en la pestaña
-- "Ajustes"). Se guardan en su perfil (serverShared/PlayerData, campo "settings") y se publican en el
-- atributo "Settings" (JSON). El cliente los aplica al momento, sin esperar al servidor.
--   - textLayout: dónde salen tus números de daño recibido y de curación:
--       "Head"   junto a la cabeza (columnas cortas a izquierda y derecha)
--       "Column" en una columna del alto del personaje, a cada lado
--       "Screen" fijos en la pantalla, a izquierda y derecha del centro
--   - showNumbers: números de combate sí/no.
--   - allyNumbers: el daño que hacen los aliados (tenue) sí/no.
--   - showCombo: el indicador de combos y racha sí/no.
--   - music: música sí/no (la tecla M también la silencia).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)

export type Layout = "Head" | "Column" | "Screen"
export type Values = {
	textLayout: Layout,
	showNumbers: boolean,
	allyNumbers: boolean,
	showCombo: boolean,
	music: boolean,
}

local Settings = {}

Settings.LAYOUTS = { "Head", "Column", "Screen" } :: { Layout }
Settings.LAYOUT_NAMES = {
	Head = "Junto a la cabeza",
	Column = "Columna del alto del jugador",
	Screen = "Fijos en la pantalla",
} :: { [string]: string }

function Settings.defaults(): Values
	return { textLayout = "Head", showNumbers = true, allyNumbers = true, showCombo = true, music = true }
end

-- Valida lo que llega del cliente o del DataStore: lo que no sea válido queda por defecto.
function Settings.sanitize(raw: any): Values
	local values = Settings.defaults()
	if typeof(raw) ~= "table" then
		return values
	end
	if typeof(raw.textLayout) == "string" and table.find(Settings.LAYOUTS, raw.textLayout) then
		values.textLayout = raw.textLayout :: Layout
	end
	for _, key in { "showNumbers", "allyNumbers", "showCombo", "music" } do
		if typeof(raw[key]) == "boolean" then
			(values :: any)[key] = raw[key]
		end
	end
	return values
end

-- ===================================== Cliente =====================================

local current: Values? = nil
local changed = Instance.new("BindableEvent")

local function fromAttribute(player: Player): Values
	local raw = player:GetAttribute("Settings")
	local ok, decoded = pcall(function()
		return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else nil
	end)
	return Settings.sanitize(if ok then decoded else nil)
end

-- Ajustes del jugador local.
function Settings.get(): Values
	if not current then
		local player = Players.LocalPlayer
		current = fromAttribute(player)
		-- Llegan del servidor al cargar el perfil (o tras guardar en otro place).
		player:GetAttributeChangedSignal("Settings"):Connect(function()
			local fresh = fromAttribute(player)
			current = fresh
			changed:Fire(fresh)
		end)
	end
	return current :: Values
end

-- Cambia un ajuste del jugador local: se aplica ya y se guarda en su perfil.
function Settings.set(key: string, value: any)
	assert(RunService:IsClient(), "Settings.set es del cliente")
	local values = table.clone(Settings.get());
	(values :: any)[key] = value
	local clean = Settings.sanitize(values)
	current = clean
	changed:Fire(clean)
	Remotes.SaveSettings:FireServer(clean)
end

-- Llama a "callback" con los ajustes nuevos cada vez que cambian.
function Settings.onChanged(callback: (values: Values) -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

return Settings
