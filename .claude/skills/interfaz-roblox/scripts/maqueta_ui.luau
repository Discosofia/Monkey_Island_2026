-- Maqueta de interfaz en Roblox Studio, para mandarla con la herramienta execute_luau del MCP de
-- Studio (datamodel_type = "Edit"). No es un ModuleScript del juego: se pega entero y al final se
-- añade el código del encargo, por ejemplo:
--
--   local Widgets = UI.freshRequire("ReplicatedStorage.Shared.UI.Widgets")
--   UI.montar({ "telefono", "pc" })
--   UI.cada(function(pantalla)
--   	local boton = Widgets.button("Volver al Lobby", pantalla.normal)
--   	boton.AnchorPoint = Vector2.new(1, 1)
--   	boton.Position = UDim2.new(1, -12, 1, -12)
--   	boton.Size = UDim2.fromScale(0.22, 0.08)
--   end)
--   return UI.informe()
--
-- montar() crea StarterGui._VistaPreviaUI con una "pantalla" por dispositivo (teléfono, tablet, PC),
-- del tamaño en píxeles de ese dispositivo y reducida con UIScale para que quepan todas en el visor
-- de Studio. Cada pantalla tiene:
--   pantalla.normal    el área de un ScreenGui normal (debajo de la barra de Roblox, IgnoreGuiInset
--                      = false): ahí van casi todos los HUD del juego.
--   pantalla.completa  la pantalla entera (IgnoreGuiInset = true), como CombatText o Results.
--   pantalla.zonas     rectángulos rojos de lo que ya ocupa sitio: la barra de Roblox, el salto y
--                      los botones táctiles (ActionButtons), el joystick y la barra de objetos, más
--                      las que añadas con UI.zona (por ejemplo, los HUD del juego que no estás
--                      tocando, con los rectángulos de volcar_hud.luau). Se ven en la captura y
--                      cuentan en el informe.
-- Como la pantalla reducida usa UIScale, los tamaños en píxeles (fromOffset) y en escala (fromScale)
-- se ven en la misma proporción que en el dispositivo real.
--
-- informe() devuelve un JSON con el rectángulo de cada elemento (en píxeles del dispositivo), los que
-- se salen de la pantalla, los que se tapan entre sí o tapan una zona ocupada, y los textos que
-- quedan más pequeños de lo legible. UI.limpiar() lo borra todo.

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local CARPETA = "_VistaPreviaUI"
-- Alto de la barra de Roblox (GuiService:GetGuiInset() con la barra nueva).
local INSET = 58
-- Texto más pequeño que esto (en píxeles del dispositivo) no se lee en un móvil.
local TEXTO_MINIMO = 11
-- Tamaño mínimo cómodo para el dedo (el mismo que Widgets.button y ActionButtons).
local DEDO_MINIMO = 44

local DISPOSITIVOS = {
	telefono = { nombre = "Teléfono", tamano = Vector2.new(844, 390), tactil = true },
	tablet = { nombre = "Tablet", tamano = Vector2.new(1024, 768), tactil = true },
	pc = { nombre = "PC", tamano = Vector2.new(1366, 768), tactil = false },
	pcGrande = { nombre = "PC 1080p", tamano = Vector2.new(1920, 1080), tactil = false },
}

export type Pantalla = {
	id: string,
	nombre: string,
	tamano: Vector2,
	tactil: boolean,
	marco: Frame,
	normal: Frame,
	completa: Frame,
	zonas: Frame,
}

local UI = {}
UI.pantallas = {} :: { Pantalla }

-- Instancia a partir de una ruta con puntos ("ReplicatedStorage.Shared.UI.Widgets").
function UI.find(path: string): Instance
	local current: Instance = game
	for name in string.gmatch(path, "[^%.]+") do
		local child = if current == game then game:GetService(name) else current:FindFirstChild(name)
		assert(child, "No existe " .. name .. " en " .. current:GetFullName())
		current = child
	end
	return current
end

-- require sin la caché de Studio (execute_luau guarda el primer resultado de cada módulo toda la
-- sesión). Los require internos del módulo sí usan la caché.
function UI.freshRequire(path: string): any
	local module = UI.find(path)
	assert(module:IsA("ModuleScript"), path .. " no es un ModuleScript")
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

function UI.limpiar()
	local gui = StarterGui:FindFirstChild(CARPETA)
	if gui then
		gui:Destroy()
	end
	table.clear(UI.pantallas)
end

local function caja(name: string, parent: Instance, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- Rectángulo de una zona ocupada (en píxeles del dispositivo), rojo translúcido con su nombre.
function UI.zona(pantalla: Pantalla, nombre: string, posicion: Vector2, tamano: Vector2)
	local zona = caja(nombre, pantalla.zonas, Color3.fromRGB(230, 60, 60), 0.75)
	zona.Position = UDim2.fromOffset(posicion.X, posicion.Y)
	zona.Size = UDim2.fromOffset(tamano.X, tamano.Y)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(230, 60, 60)
	stroke.Thickness = 2
	stroke.Parent = zona
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = nombre
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 14
	label.TextWrapped = true
	label.Parent = zona
end

-- Zonas que ocupa Roblox (o el propio juego) en cada dispositivo. Las del salto y los botones de
-- acción repiten las cuentas de src/combatClient/ActionButtons.luau: si cambian allí, cambiarlas aquí.
local function zonasDeRoblox(pantalla: Pantalla)
	local w, h = pantalla.tamano.X, pantalla.tamano.Y
	UI.zona(pantalla, "Barra de Roblox", Vector2.new(0, 0), Vector2.new(260, INSET))
	if pantalla.tactil then
		local small = math.min(w, h) <= 500
		local jump = if small then 70 else 120
		local jumpPos = if small then Vector2.new(w - 95, h - 90) else Vector2.new(w - 170, h - 210)
		UI.zona(pantalla, "Salto", jumpPos, Vector2.new(jump, jump))
		-- Cuadrícula de ActionButtons: 6 columnas x 3 filas encima del salto, alineada a su borde derecho.
		local size = math.clamp(math.floor(jump * 0.75), 46, 72)
		local pitch = size + 6
		local right = jumpPos.X + jump
		local bottom = jumpPos.Y - 6
		UI.zona(
			pantalla,
			"Botones de acción",
			Vector2.new(right - 6 * pitch, bottom - 3 * pitch),
			Vector2.new(6 * pitch, 3 * pitch)
		)
		UI.zona(pantalla, "Joystick", Vector2.new(0, h * 0.5), Vector2.new(w * 0.4, h * 0.5))
	end
	-- Barra de objetos de Roblox (Backpack): abajo en el centro.
	local slots = if pantalla.tactil then 3 else 5
	local slot = if math.min(w, h) <= 500 then 48 else 60
	UI.zona(
		pantalla,
		"Barra de objetos",
		Vector2.new(w / 2 - slots * (slot + 5) / 2, h - slot - 8),
		Vector2.new(slots * (slot + 5), slot + 8)
	)
end

-- Crea las pantallas. dispositivos: ids de DISPOSITIVOS ("telefono", "tablet", "pc", "pcGrande").
-- opciones.zonas = false no dibuja las zonas de Roblox (pon las tuyas con UI.zona).
function UI.montar(dispositivos: { string }?, opciones: { zonas: boolean? }?)
	UI.limpiar()
	local ids = dispositivos or { "telefono", "pc" }
	local opts = opciones or {}

	local gui = Instance.new("ScreenGui")
	gui.Name = CARPETA
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false

	local fondo = caja("Fondo", gui, Color3.fromRGB(30, 30, 34), 0)
	fondo.Size = UDim2.fromScale(1, 1)

	-- Reparte el visor de Studio entre las pantallas, en fila o en columna (lo que las deje más
	-- grandes), con la misma escala para todas.
	local viewport = Workspace.CurrentCamera.ViewportSize
	local margin = 16
	local header = 30
	local sumWidth, sumHeight, maxWidth, maxHeight = 0, 0, 0, 0
	for _, id in ids do
		local device = DISPOSITIVOS[id]
		assert(device, "Dispositivo desconocido: " .. id)
		sumWidth += device.tamano.X
		sumHeight += device.tamano.Y
		maxWidth = math.max(maxWidth, device.tamano.X)
		maxHeight = math.max(maxHeight, device.tamano.Y)
	end
	local count = #ids
	local rowScale =
		math.min((viewport.X - margin * (count + 1)) / sumWidth, (viewport.Y - header - margin * 2) / maxHeight)
	local columnScale =
		math.min((viewport.X - margin * 2) / maxWidth, (viewport.Y - (header + margin) * count - margin) / sumHeight)
	local inRow = rowScale >= columnScale
	local scale = math.min(if inRow then rowScale else columnScale, 1)

	local x, y = margin, margin
	for _, id in ids do
		local device = DISPOSITIVOS[id]
		local marco = caja(id, fondo, Color3.new(0, 0, 0), 0)
		-- UIScale reduce el marco desde su esquina (AnchorPoint 0, 0): la posición no cambia.
		marco.Position = UDim2.fromOffset(x, y + header)
		marco.Size = UDim2.fromOffset(device.tamano.X, device.tamano.Y)
		marco.ClipsDescendants = true
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = scale
		uiScale.Parent = marco

		local titulo = Instance.new("TextLabel")
		titulo.BackgroundTransparency = 1
		titulo.Position = UDim2.fromOffset(x, y)
		titulo.Size = UDim2.fromOffset(device.tamano.X * scale, header - 4)
		titulo.Text = `{device.nombre} · {device.tamano.X}x{device.tamano.Y}`
		titulo.TextColor3 = Color3.new(1, 1, 1)
		titulo.Font = Enum.Font.BuilderSansBold
		titulo.TextSize = 18
		titulo.TextXAlignment = Enum.TextXAlignment.Left
		titulo.Parent = fondo
		if inRow then
			x += device.tamano.X * scale + margin
		else
			y += device.tamano.Y * scale + header + margin
		end

		-- "Escena": cielo arriba y arena abajo, para juzgar el contraste con fondo claro y oscuro.
		local escena = caja("Escena", marco, Color3.new(1, 1, 1), 0)
		escena.Size = UDim2.fromScale(1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 180, 225)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(150, 200, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 125, 95)),
		})
		gradient.Parent = escena

		local completa = caja("Completa", marco, Color3.new(), 1)
		completa.Size = UDim2.fromScale(1, 1)
		completa.ZIndex = 2
		local normal = caja("Normal", marco, Color3.new(), 1)
		normal.Position = UDim2.fromOffset(0, INSET)
		normal.Size = UDim2.new(1, 0, 1, -INSET)
		normal.ZIndex = 2
		local zonas = caja("Zonas", marco, Color3.new(), 1)
		zonas.Size = UDim2.fromScale(1, 1)
		zonas.ZIndex = 10

		local pantalla: Pantalla = {
			id = id,
			nombre = device.nombre,
			tamano = device.tamano,
			tactil = device.tactil,
			marco = marco,
			normal = normal,
			completa = completa,
			zonas = zonas,
		}
		if opts.zonas ~= false then
			zonasDeRoblox(pantalla)
		end
		table.insert(UI.pantallas, pantalla)
	end

	gui.Parent = StarterGui
	game.Selection:Set({})
end

-- Llama a construir(pantalla) en cada pantalla montada.
function UI.cada(construir: (Pantalla) -> ())
	for _, pantalla in UI.pantallas do
		construir(pantalla)
	end
end

local function rect(object: GuiObject, marco: Frame, scale: number): { number }
	local origin = marco.AbsolutePosition
	local position = (object.AbsolutePosition - origin) / scale
	local size = object.AbsoluteSize / scale
	return { math.round(position.X), math.round(position.Y), math.round(size.X), math.round(size.Y) }
end

local function cruzan(a: { number }, b: { number }): boolean
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

-- Elementos de primer nivel: los hijos directos de normal/completa (lo que en el juego sería un hijo
-- del ScreenGui). Lo de dentro se mide aparte para el tamaño del texto.
local function primerNivel(pantalla: Pantalla): { GuiObject }
	local list = {}
	for _, layer in { pantalla.normal, pantalla.completa } do
		for _, child in layer:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				table.insert(list, child)
			end
		end
	end
	return list
end

-- JSON con rectángulos y problemas de cada pantalla. Espera un momento a que se calcule el tamaño.
function UI.informe(): string
	task.wait(0.1)
	local report = {}
	for _, pantalla in UI.pantallas do
		local scale = (pantalla.marco:FindFirstChildOfClass("UIScale") :: UIScale).Scale
		local w, h = pantalla.tamano.X, pantalla.tamano.Y
		local elementos = {}
		local problemas = {}
		local items = primerNivel(pantalla)
		local rects = {}
		for _, item in items do
			local r = rect(item, pantalla.marco, scale)
			rects[item] = r
			table.insert(elementos, { nombre = item.Name, rect = r })
			if r[1] < 0 or r[2] < 0 or r[1] + r[3] > w or r[2] + r[4] > h then
				table.insert(problemas, `{item.Name} se sale de la pantalla`)
			end
			if item:IsA("GuiButton") and pantalla.tactil and math.min(r[3], r[4]) < DEDO_MINIMO then
				table.insert(problemas, `{item.Name} mide {math.min(r[3], r[4])} px: pequeño para el dedo`)
			end
			for _, zona in pantalla.zonas:GetChildren() do
				if zona:IsA("Frame") and cruzan(r, rect(zona, pantalla.marco, scale)) then
					table.insert(problemas, `{item.Name} pisa la zona "{zona.Name}"`)
				end
			end
			-- La propia pieza también, que muchas son un Widgets.label suelto.
			local texts = item:GetDescendants()
			table.insert(texts, item)
			for _, descendant in texts do
				if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
					local textBounds = descendant.TextBounds.Y / scale
					if
						descendant.Text ~= ""
						and descendant.Visible
						and textBounds > 0
						and textBounds < TEXTO_MINIMO
					then
						table.insert(problemas, `"{descendant.Text}" en {item.Name} sale a {math.round(textBounds)} px`)
					end
				end
			end
		end
		for i = 1, #items do
			for j = i + 1, #items do
				if cruzan(rects[items[i]], rects[items[j]]) then
					table.insert(problemas, `{items[i].Name} y {items[j].Name} se tapan`)
				end
			end
		end
		table.insert(
			report,
			{ pantalla = pantalla.nombre, tamano = { w, h }, elementos = elementos, problemas = problemas }
		)
	end
	return HttpService:JSONEncode(report)
end

-- ===== Código del encargo a partir de aquí =====
