--!strict
-- Textos del juego en el idioma de cada jugador (GDD §18, tanda I1). El español es la clave:
--   local T = Strings.t
--   label.Text = T("Ámbar: {n}", { n = amber })
-- Los argumentos van con nombre entre llaves, como en una LocalizationTable de Roblox. Un argumento puede
-- ser otra frase que también se traduce, { "texto", args? }, una lista de ellas, { list = { … }, sep? }
-- (sep, un texto o una frase: { Strings.later(" y ") }), u otro argumento en minúsculas o mayúsculas,
-- { lower = … } o { upper = … } ("un huevo raro", "¡RARO!"). Solo arrays o solo diccionarios: una tabla
-- mixta pierde sus claves al pasar por un RemoteEvent o por JSONEncode.
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
	elseif value.lower ~= nil then
		return string.lower(argument(value.lower))
	elseif value.upper ~= nil then
		return string.upper(argument(value.upper))
	elseif typeof(value.list) == "table" then
		local parts = {}
		for _, entry in value.list do
			table.insert(parts, argument(entry))
		end
		-- El separador puede ser también una frase ({ " y " }).
		local sep = if typeof(value.sep) == "string"
			then value.sep
			elseif typeof(value.sep) == "table" then argument(value.sep)
			else ", "
		return table.concat(parts, sep)
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

-- Espera (como mucho "timeout" segundos) a que el servidor copie los ajustes del perfil al atributo
-- "Settings", para que la interfaz nazca ya en el idioma elegido y no en el de la cuenta. Lo llama el
-- init.client de cada place antes de cargar los controladores.
function Strings.awaitSetting(timeout: number)
	if not isClient then
		return
	end
	local player = Players.LocalPlayer
	local deadline = os.clock() + timeout
	while player:GetAttribute("Settings") == nil and os.clock() < deadline do
		task.wait(0.1)
	end
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

-- En el servidor, el texto en el idioma de "player", para lo que Roblox enseña sin pasar por su cliente
-- (el mensaje de player:Kick). Su ajuste, o con "Auto" el idioma de su cuenta (Player.LocaleId): es-* →
-- español; cualquier otro → inglés (aquí no hay traducción de la nube).
function Strings.forPlayer(player: Player, es: string, args: Args?): string
	local setting = readSetting(player)
	local spanish = if setting == "Auto"
		then string.sub(string.lower(player.LocaleId), 1, 2) == "es"
		else setting == "es"
	if spanish then
		return format(es, args)
	end
	return format(english[es] or es, args)
end

-- Un argumento suelto en el idioma del jugador (una frase anidada o una lista, ver arriba).
function Strings.arg(value: any): string
	return argument(value)
end

-- Marca una frase para tools/strings.py sin traducirla todavía: devuelve el mismo texto, que se traduce
-- después con T.
function Strings.later(es: string): string
	return es
end

-- Una frase y sus argumentos juntos en un texto, para un atributo que el servidor publica y el cliente
-- enseña (las líneas de estado del HUD de la Isla): ReplicatedStorage:SetAttribute("SiegeStatus",
-- Strings.pack("⚔️ Asedio: {alive} monos…", { alive = n })).
function Strings.pack(es: string, args: Args?): string
	return HttpService:JSONEncode({ es, args })
end

-- La frase y los argumentos de Strings.pack. Un texto que no viene de ahí sale tal cual y sin argumentos.
function Strings.unpacked(raw: string): (string, Args?)
	if string.sub(raw, 1, 2) == '["' then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(decoded) == "table" and typeof(decoded[1]) == "string" then
			return decoded[1], decoded[2]
		end
	end
	return raw, nil
end

-- El texto de Strings.pack en el idioma del jugador.
function Strings.unpack(raw: string): string
	if raw == "" then
		return ""
	end
	local es, args = Strings.unpacked(raw)
	return translate(es, args)
end

-- Un texto del mundo (BillboardGui, SurfaceGui) que el servidor forma con argumentos y cambia en la
-- partida ("🏕️ Campamento {health}/{max}"). Guarda la plantilla y sus argumentos en los atributos
-- "TextKey" y "TextArgs" del texto, y UI/Localizer lo traduce en cada cliente cada vez que cambian.
function Strings.setWorldText(label: TextLabel, es: string, args: Args?)
	label:SetAttribute("TextKey", es)
	label:SetAttribute("TextArgs", if args then HttpService:JSONEncode(args) else nil)
	label.Text = translate(es, args)
end

-- Lo mismo para otra propiedad con texto: el ActionText u ObjectText de un ProximityPrompt ("📦 Cofre
-- de {player}") o el DisplayName de un Humanoid ("{name} alfa"). La plantilla queda en los atributos
-- "<property>Key" y "<property>Args".
function Strings.setText(
	instance: Instance,
	property: "ActionText" | "ObjectText" | "DisplayName",
	es: string,
	args: Args?
)
	instance:SetAttribute(property .. "Key", es)
	instance:SetAttribute(property .. "Args", if args then HttpService:JSONEncode(args) else nil);
	(instance :: any)[property] = translate(es, args)
end

-- La plantilla y los argumentos que dejó Strings.setWorldText en un texto, o Strings.setText con
-- prefix = la propiedad (nil si no tiene).
function Strings.worldText(label: Instance, prefix: string?): (string?, Args?)
	local es = label:GetAttribute((prefix or "Text") .. "Key")
	if typeof(es) ~= "string" then
		return nil, nil
	end
	local raw = label:GetAttribute((prefix or "Text") .. "Args")
	local args = nil
	if typeof(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		args = if ok then decoded else nil
	end
	return es, args
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
