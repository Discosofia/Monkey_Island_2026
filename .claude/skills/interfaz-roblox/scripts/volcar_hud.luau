-- Vuelca la interfaz real de una partida de prueba, para mandarlo con execute_luau del MCP de Studio
-- con datamodel_type = "Client" (Studio en Play). No cambia nada: solo lee el PlayerGui del jugador.
-- Se pega entero y al final se añade la llamada, por ejemplo:
--
--   return Hud.volcar()                    -- todas las pantallas (ScreenGui) del jugador
--   return Hud.volcar({ "IslandHUD" })     -- solo esas
--   return Hud.arbol("IslandHUD.Clock")    -- propiedades de un elemento y de lo que lleva dentro
--
-- volcar() devuelve un JSON con el tamaño del visor, la barra de Roblox, cada ScreenGui (DisplayOrder,
-- IgnoreGuiInset) con el rectángulo en píxeles de sus elementos visibles de primer nivel ({x, y, ancho,
-- alto}, todos medidos desde la esquina de la pantalla entera, con la barra de Roblox incluida), y la
-- lista de elementos de distintas pantallas que se tapan. Los rectángulos sirven luego como zonas ocupadas
-- en maqueta_ui.luau (UI.zona), para diseñar algo nuevo sin pisar lo que ya hay.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Pantallas de Roblox o de herramientas que no son del juego.
local IGNORADAS = { Freecam = true, BubbleChat = true, _VistaPreviaUI = true }

local Hud = {}

local function playerGui(): PlayerGui
	local player = Players.LocalPlayer
	assert(player, 'No hay jugador local: usa datamodel_type = "Client" con Studio en Play')
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

-- Rectángulo en píxeles de la pantalla entera. AbsolutePosition empieza debajo de la barra de Roblox
-- en los ScreenGui con IgnoreGuiInset = false: se le suma para que todos usen el mismo origen.
local function rect(object: GuiObject): { number }
	local screen = object:FindFirstAncestorWhichIsA("ScreenGui")
	local offset = if screen and not screen.IgnoreGuiInset then GuiService:GetGuiInset().Y else 0
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	return { math.round(position.X), math.round(position.Y + offset), math.round(size.X), math.round(size.Y) }
end

local function cruzan(a: { number }, b: { number }): boolean
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

-- Un elemento se ve si él y todos sus antepasados son visibles y su pantalla está activada.
local function seVe(object: GuiObject): boolean
	local current: Instance? = object
	while current and not current:IsA("ScreenGui") do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current ~= nil and (current :: ScreenGui).Enabled
end

local function textoDe(object: GuiObject): string?
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		return object.Text
	end
	return nil
end

-- Un texto sin texto, sin fondo y sin nada dentro (las líneas de estado de IslandHUD cuando no hay
-- aviso) ocupa sitio pero no se ve: no cuenta para los solapes.
local function vacio(object: GuiObject): boolean
	return textoDe(object) == "" and object.BackgroundTransparency >= 1 and #object:GetChildren() == 0
end

function Hud.volcar(nombres: { string }?): string
	local gui = playerGui()
	local inset = GuiService:GetGuiInset()
	local report = {
		visor = {
			math.round(Workspace.CurrentCamera.ViewportSize.X),
			math.round(Workspace.CurrentCamera.ViewportSize.Y),
		},
		barraRoblox = math.round(inset.Y),
		tactil = game:GetService("UserInputService").TouchEnabled,
		pantallas = {},
		solapes = {},
	}
	local todos: { { pantalla: string, nombre: string, rect: { number } } } = {}
	for _, screen in gui:GetChildren() do
		if
			not screen:IsA("ScreenGui")
			or IGNORADAS[screen.Name]
			or (nombres and not table.find(nombres, screen.Name))
		then
			continue
		end
		local elementos = {}
		for _, child in screen:GetChildren() do
			if child:IsA("GuiObject") and seVe(child) then
				local r = rect(child)
				local empty = vacio(child)
				table.insert(elementos, { nombre = child.Name, rect = r, texto = textoDe(child), vacio = empty })
				if not empty then
					table.insert(todos, { pantalla = screen.Name, nombre = child.Name, rect = r })
				end
			end
		end
		table.insert(report.pantallas, {
			nombre = screen.Name,
			activada = screen.Enabled,
			displayOrder = screen.DisplayOrder,
			ignoreGuiInset = screen.IgnoreGuiInset,
			elementos = elementos,
		})
	end
	-- Solo entre pantallas distintas: dentro de una misma, que dos piezas se tapen suele ser a propósito.
	for i = 1, #todos do
		for j = i + 1, #todos do
			local a, b = todos[i], todos[j]
			if a.pantalla ~= b.pantalla and cruzan(a.rect, b.rect) then
				table.insert(report.solapes, `{a.pantalla}.{a.nombre} y {b.pantalla}.{b.nombre}`)
			end
		end
	end
	return HttpService:JSONEncode(report)
end

-- Propiedades de diseño de un elemento ("IslandHUD.Clock") y de sus descendientes.
function Hud.arbol(ruta: string): string
	local current: Instance = playerGui()
	for name in string.gmatch(ruta, "[^%.]+") do
		local child = current:FindFirstChild(name)
		assert(child, "No existe " .. name .. " en " .. current:GetFullName())
		current = child
	end
	local lines = {}
	local function visit(object: Instance, depth: number)
		local line = string.rep("  ", depth) .. object.ClassName .. " " .. object.Name
		if object:IsA("GuiObject") then
			line ..= string.format(
				" pos=%s size=%s anchor=%s abs=%s visible=%s z=%d",
				tostring(object.Position),
				tostring(object.Size),
				tostring(object.AnchorPoint),
				table.concat(rect(object), ","),
				tostring(object.Visible),
				object.ZIndex
			)
			local text = textoDe(object)
			if text then
				line ..= ` texto="{text}"`
			end
		end
		table.insert(lines, line)
		for _, child in object:GetChildren() do
			visit(child, depth + 1)
		end
	end
	visit(current, 0)
	return table.concat(lines, "\n")
end

-- ===== Código del encargo a partir de aquí =====
