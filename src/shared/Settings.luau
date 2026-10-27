--!strict
-- Ajustes del jugador (panel UI/SettingsPanel, en la Isla con el botón ⚙️ y en el Lobby en la pestaña
-- "Ajustes"). Se guardan en su perfil (serverShared/PlayerData, campo "settings") y se publican en el
-- atributo "Settings" (JSON). El cliente los aplica al momento, sin esperar al servidor.
--   - textLayout: dónde salen tus números de daño recibido y de curación:
--       "Head"   junto a la cabeza (columnas cortas a izquierda y derecha)
--       "Column" en una columna del alto del personaje, a cada lado
--       "Screen" fijos en la pantalla, a izquierda y derecha del centro
--   - numberFont: letra de los números de combate: "Comic" (Bangers, como POW!) o "Classic".
--   - showNumbers: números de combate sí/no.
--   - allyNumbers: el daño que hacen los aliados (tenue) sí/no.
--   - showLoot: lo que recoges ("+2 🌲 Madera") junto a tu personaje sí/no (sale donde textLayout).
--   - showCombo: el indicador de combos y racha sí/no.
--   - music: música sí/no (la tecla M también la silencia).
--   - comicFx: estallidos de cómic en combate ("POW!", ComicFxController) sí/no.
--   - comicLevel: "All" (también los golpes normales) o "Strong" (solo críticos, K.O. y golpes fuertes
--     que recibes).
--   - comicSize: "Small", "Normal" o "Large" (Config.ComicFx.SizeScale).
--   - cameraShake: temblor de la cámara en combate (remates, habilidades, rebotes, la guardia): "On",
--     "Soft" o "Off" (Config.CameraShake.Scale; CombatClient/CameraShake).
--   - language: idioma de los textos (Shared/Strings): "Auto" (el de la cuenta de Roblox), "es" o "en".
--   - missionsOpen: la lista de misiones de la Isla desplegada (en PC; se pliega tocando su cabecera,
--     MissionTrackerController). No sale en el panel.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)
local Strings = require(script.Parent.Strings)

export type Layout = "Head" | "Column" | "Screen"
export type ComicLevel = "All" | "Strong"
export type ComicSize = "Small" | "Normal" | "Large"
export type NumberFont = "Comic" | "Classic"
export type CameraShake = "On" | "Soft" | "Off"
export type Language = "Auto" | "es" | "en"
export type Values = {
	textLayout: Layout,
	numberFont: NumberFont,
	showNumbers: boolean,
	allyNumbers: boolean,
	showLoot: boolean,
	showCombo: boolean,
	music: boolean,
	comicFx: boolean,
	comicLevel: ComicLevel,
	comicSize: ComicSize,
	cameraShake: CameraShake,
	language: Language,
	missionsOpen: boolean,
}

local later = Strings.later

local Settings = {}

Settings.LAYOUTS = { "Head", "Column", "Screen" } :: { Layout }
-- Los nombres de las opciones, en español; el panel los traduce con Strings.
Settings.LAYOUT_NAMES = {
	Head = later("Junto a la cabeza"),
	Column = later("Columna del alto del jugador"),
	Screen = later("Fijos en la pantalla"),
} :: { [string]: string }
Settings.NUMBER_FONTS = { "Comic", "Classic" } :: { NumberFont }
Settings.NUMBER_FONT_NAMES = {
	Comic = later("¡Cómic!"),
	Classic = later("Clásica"),
} :: { [string]: string }
Settings.COMIC_LEVELS = { "All", "Strong" } :: { ComicLevel }
Settings.COMIC_LEVEL_NAMES = {
	All = later("Todo"),
	Strong = later("Solo lo fuerte"),
} :: { [string]: string }
Settings.COMIC_SIZES = { "Small", "Normal", "Large" } :: { ComicSize }
Settings.COMIC_SIZE_NAMES = {
	Small = later("Pequeños"),
	Normal = later("Normales"),
	Large = later("Grandes"),
} :: { [string]: string }
Settings.CAMERA_SHAKES = { "On", "Soft", "Off" } :: { CameraShake }
Settings.CAMERA_SHAKE_NAMES = {
	On = later("Encendido"),
	Soft = later("Suave"),
	Off = later("Apagado"),
} :: { [string]: string }
Settings.LANGUAGES = { "Auto", "es", "en" } :: { Language }
-- Cada idioma en su propio idioma (su inglés es el mismo texto); "Automático" sí se traduce.
Settings.LANGUAGE_NAMES = {
	Auto = later("Automático"),
	es = later("Español"),
	en = later("English"),
} :: { [string]: string }

function Settings.defaults(): Values
	return {
		textLayout = "Head",
		numberFont = "Comic",
		showNumbers = true,
		allyNumbers = true,
		showLoot = true,
		showCombo = true,
		music = true,
		comicFx = true,
		comicLevel = "All",
		comicSize = "Normal",
		cameraShake = "On",
		language = "Auto",
		missionsOpen = true,
	}
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
	if typeof(raw.numberFont) == "string" and table.find(Settings.NUMBER_FONTS, raw.numberFont) then
		values.numberFont = raw.numberFont :: NumberFont
	end
	if typeof(raw.comicLevel) == "string" and table.find(Settings.COMIC_LEVELS, raw.comicLevel) then
		values.comicLevel = raw.comicLevel :: ComicLevel
	end
	if typeof(raw.comicSize) == "string" and table.find(Settings.COMIC_SIZES, raw.comicSize) then
		values.comicSize = raw.comicSize :: ComicSize
	end
	if typeof(raw.cameraShake) == "string" and table.find(Settings.CAMERA_SHAKES, raw.cameraShake) then
		values.cameraShake = raw.cameraShake :: CameraShake
	end
	if typeof(raw.language) == "string" and table.find(Settings.LANGUAGES, raw.language) then
		values.language = raw.language :: Language
	end
	for _, key in { "showNumbers", "allyNumbers", "showLoot", "showCombo", "music", "comicFx", "missionsOpen" } do
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
	Strings.applySetting(clean.language)
	changed:Fire(clean)
	Remotes.SaveSettings:FireServer(clean)
end

-- Llama a "callback" con los ajustes nuevos cada vez que cambian.
function Settings.onChanged(callback: (values: Values) -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

return Settings
