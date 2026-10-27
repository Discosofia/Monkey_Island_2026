--!strict
-- Textos del juego en el idioma de cada jugador (GDD §18, tanda I1). El español es la clave:
--   local T = Strings.t
--   label.Text = T("Ámbar: {n}", { n = amber })
-- Los argumentos van con nombre entre llaves, como en una LocalizationTable de Roblox. Un argumento puede
-- ser otra frase que también se traduce, { "texto", args? }, o una lista de ellas, { list = { … }, sep? }
-- (así el servidor manda por un remoto, por ejemplo, "🎒 Tus provisiones: {items}" con cada objeto, y
-- el cliente lo pone todo en su idioma).
-- El texto tiene que ser un literal entre comillas dobles (nunca una interpolación con `), para que
-- tools/strings.py lo encuentre; un nombre de Data (T(def.name)) lo encuentra por los campos de Data.
-- Una frase que se guarda en una tabla y se traduce después (T(LINES[i])) se marca con
-- Strings.later("…").
--
-- El inglés está en Data/Strings/* (["texto español"] = "English text"), revisado a mano.
-- Idioma de cada jugador: el ajuste "language" (Shared/Settings, atributo "Settings" del Player):
--   - "es" o "en": ese.
--   - "Auto": el idioma de su cuenta de Roblox (LocalizationService.RobloxLocaleId): es-* → español,
--     en-* → inglés, y cualquier otro ("other") → la LocalizationTable de la nube (Creator Hub), que
--     tiene el inglés como origen y la traducción automática de Roblox a los demás idiomas. Las claves
--     de esa tabla son Strings.key(texto español); tools/strings.py --csv la genera.
--
-- En el servidor, T devuelve el español: el servidor no traduce lo que manda a un jugador, sino que
-- envía la plantilla en español y sus argumentos (Remotes.Notify:FireClient(player, texto, args)) y el
-- cliente la traduce con T.
-- No requiere Settings ni Remotes, para poder usarse también en modo edición.

local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Language = "es" | "en" | "other"
export type Args = { [string]: any }

local Strings = {}

-- El inglés de todas las tablas de Data/Strings, juntas.
local english: { [string]: string } = {}
for _, child in script.Parent.Data.Strings:GetChildren() do
	if child:IsA("ModuleScript") then
		for es, en in (require :: any)(child) :: { [string]: string } do
			english[es] = en
		end
	end
end

-- Clave corta y estable de un texto español para la tabla de la nube: FNV-1a de 32 bits sobre sus
-- bytes, en 8 cifras hexadecimales. tools/strings.py la calcula igual.
function Strings.key(es: string): string
	local hash = 2166136261
	for i = 1, #es do
		hash = bit32.bxor(hash, string.byte(es, i))
		-- Multiplicar por el primo 16777619 sin pasarse de los 53 bits exactos de un número de Luau.
		hash = (hash * 403 + bit32.lshift(hash % 256, 24)) % 4294967296
	end
	return string.format("%08x", hash)
end

local translate: (es: string, args: Args?) -> string

-- Un argumento en texto: las frases anidadas ({ "texto", args } y { list = … }) se traducen.
local function argument(value: any): string
	if typeof(value) ~= "table" then
		return tostring(value)
	elseif typeof(value[1]) == "string" then
		return translate(value[1], value[2])
	elseif typeof(value.list) == "table" then
		local parts = {}
		for _, entry in value.list do
			table.insert(parts, argument(entry))
		end
		return table.concat(parts, if typeof(value.sep) == "string" then value.sep else ", ")
	end
	return ""
end

local function format(text: string, args: Args?): string
	if not args then
		return text
	end
	return (
		string.gsub(text, "{([%w_]+)}", function(name: string): string?
			local value = args[name]
			return if value == nil then nil else argument(value)
		end)
	)
end

-- ===================================== Idioma =====================================

local isClient = RunService:IsClient()
local current: Language? = nil
local changed = Instance.new("BindableEvent")
local missingWarned: { [string]: boolean } = {}
local cloudTranslator: Translator? = nil
local cloudRequested = false

local function fromLocale(): Language
	local locale = string.lower(LocalizationService.RobloxLocaleId)
	if string.sub(locale, 1, 2) == "es" then
		return "es"
	elseif string.sub(locale, 1, 2) == "en" then
		return "en"
	end
	return "other"
end

local function readSetting(player: Player): string
	local raw = player:GetAttribute("Settings")
	if typeof(raw) ~= "string" then
		return "Auto"
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and typeof(decoded) == "table" and (decoded.language == "es" or decoded.language == "en") then
		return decoded.language
	end
	return "Auto"
end

local function resolve(setting: string): Language
	if setting == "es" or setting == "en" then
		return setting :: Language
	end
	return fromLocale()
end

local function requestCloud()
	if cloudRequested then
		return
	end
	cloudRequested = true
	task.spawn(function()
		local ok, translator =
			pcall(LocalizationService.GetTranslatorForPlayerAsync, LocalizationService, Players.LocalPlayer)
		if ok then
			cloudTranslator = translator
		end
	end)
end

-- Idioma en que se ven los textos de este jugador. En el servidor, siempre "es".
function Strings.language(): Language
	if not isClient then
		return "es"
	end
	if not current then
		local player = Players.LocalPlayer
		current = resolve(readSetting(player))
		player:GetAttributeChangedSignal("Settings"):Connect(function()
			local fresh = resolve(readSetting(player))
			if fresh ~= current then
				current = fresh
				changed:Fire(fresh)
			end
		end)
	end
	if current == "other" then
		requestCloud()
	end
	return current :: Language
end

-- Aplica en el cliente el ajuste nuevo sin esperar al servidor (lo llama Settings.set).
function Strings.applySetting(setting: string)
	if not isClient then
		return
	end
	Strings.language()
	local fresh = resolve(setting)
	if fresh ~= current then
		current = fresh
		changed:Fire(fresh)
	end
end

-- Llama a "callback" con el idioma nuevo cada vez que cambia.
function Strings.onChanged(callback: (language: Language) -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

-- ===================================== Traducir =====================================

local function toEnglish(es: string): string
	local en = english[es]
	if en then
		return en
	end
	if not missingWarned[es] then
		missingWarned[es] = true
		warn(`[Strings] sin inglés: {es}`)
	end
	return es
end

-- El texto en el idioma del jugador, con sus argumentos puestos.
function translate(es: string, args: Args?): string
	local language = Strings.language()
	if language == "es" then
		return format(es, args)
	end
	if language == "other" and cloudTranslator and english[es] then
		local ok, text = pcall(function()
			-- La nube no sabe de frases anidadas: van ya traducidas.
			local flat = {}
			for name, value in args or {} do
				flat[name] = argument(value)
			end
			return (cloudTranslator :: Translator):FormatByKey(Strings.key(es), flat)
		end)
		if ok then
			return text
		end
	end
	return format(toEnglish(es), args)
end
Strings.t = translate

-- Un argumento suelto en el idioma del jugador (una frase anidada o una lista, ver arriba).
function Strings.arg(value: any): string
	return argument(value)
end

-- Marca una frase para tools/strings.py sin traducirla todavía: devuelve el mismo texto, que se traduce
-- después con T.
function Strings.later(es: string): string
	return es
end

-- El texto español que corresponde a uno ya traducido al inglés (para volver a traducir los textos fijos
-- de la interfaz al cambiar de idioma, UI/Localizer). nil si no es de ninguna tabla.
local spanishOf: { [string]: string }? = nil
function Strings.source(text: string): string?
	if english[text] then
		return text
	end
	if not spanishOf then
		local reverse: { [string]: string } = {}
		for es, en in english do
			reverse[en] = es
		end
		spanishOf = reverse
	end
	return (spanishOf :: { [string]: string })[text]
end

return Strings
