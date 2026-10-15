-- Vista previa de un modelo en Roblox Studio, para mandarla con la herramienta execute_luau del MCP
-- de Studio (datamodel_type = "Edit"). No es un ModuleScript del juego: se pega entero y al final
-- se añade el código que construye el modelo, por ejemplo:
--
--   local model = Preview.freshRequire("ReplicatedStorage.Shared.PetModels").build("Mono")
--   return Preview.show(model)
--
-- o, con un modelo que ya está en el place:
--
--   return Preview.show(Preview.find("Workspace.Decoracion.Barca"):Clone())
--
-- show() pone el modelo en Workspace._VistaPrevia (lejos del mapa, sobre una base gris neutra y con
-- un maniquí de 5 studs, la altura de un personaje R15, para juzgar la escala) y devuelve un JSON
-- con su tamaño, el número de piezas y las cámaras sugeridas para screen_capture. Al terminar,
-- Preview.clear() lo borra todo.

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local FOLDER = "_VistaPrevia"
-- Lejos de la isla (radio 950) y del Lobby, para que nada del mapa salga en las capturas.
local ORIGIN = Vector3.new(0, 300, 4000)

local Preview = {}

-- Instancia a partir de una ruta con puntos ("ReplicatedStorage.Shared.PetModels").
function Preview.find(path: string): Instance
	local current: Instance = game
	for name in string.gmatch(path, "[^%.]+") do
		local child = if current == game then game:GetService(name) else current:FindFirstChild(name)
		assert(child, "No existe " .. name .. " en " .. current:GetFullName())
		current = child
	end
	return current
end

-- require sin la caché de Studio: la barra de comandos y execute_luau guardan el primer resultado
-- de cada módulo toda la sesión, así que tras un cambio sincronizado por Rojo se seguiría viendo
-- la versión vieja. Ojo: los require internos del módulo sí usan la caché; si el cambio está en
-- un módulo del que depende, recárgalo también con freshRequire o reinicia Studio.
function Preview.freshRequire(path: string): any
	local module = Preview.find(path)
	assert(module:IsA("ModuleScript"), path .. " no es un ModuleScript")
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

function Preview.clear()
	local folder = Workspace:FindFirstChild(FOLDER)
	if folder then
		folder:Destroy()
	end
end

local function plain(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function round(value: number): number
	return math.floor(value * 100 + 0.5) / 100
end

local function vector(value: Vector3): { number }
	return { round(value.X), round(value.Y), round(value.Z) }
end

-- Coloca "target" (Model, BasePart o Tool) en la zona de vista previa y devuelve el informe en JSON.
-- options.dummy = false quita el maniquí; options.keep = true conserva lo que ya hubiera en la zona
-- (para comparar dos versiones lado a lado, con options.offset).
function Preview.show(target: Instance, options: { dummy: boolean?, keep: boolean?, offset: Vector3? }?): string
	local opts = options or {}
	if not opts.keep then
		Preview.clear()
	end
	local folder = Workspace:FindFirstChild(FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = Workspace
	end

	-- Un Tool o una pieza suelta se envuelven en un Model para poder moverlos con PivotTo.
	local model: Model
	if target:IsA("Model") then
		model = target
	else
		model = Instance.new("Model")
		model.Name = target.Name
		target.Parent = model
	end
	model.Parent = folder
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Enabled = false
		end
	end

	-- Apoya el modelo sobre la base, centrado en ORIGIN (+ offset).
	local boxFrame, size = model:GetBoundingBox()
	local base = ORIGIN + (opts.offset or Vector3.zero)
	local lift = boxFrame.Position.Y - size.Y / 2
	local shift = Vector3.new(base.X - boxFrame.Position.X, base.Y - lift, base.Z - boxFrame.Position.Z)
	model:PivotTo(model:GetPivot() + shift)
	local center = base + Vector3.new(0, size.Y / 2, 0)

	if not folder:FindFirstChild("Base") then
		local floor = Instance.new("Part")
		floor.Name = "Base"
		floor.Size = Vector3.new(80, 1, 80)
		floor.Position = ORIGIN - Vector3.new(0, 0.5, 0)
		floor.Color = Color3.fromRGB(150, 150, 150)
		floor.Material = Enum.Material.SmoothPlastic
		plain(floor)
		floor.Parent = folder
	end
	if opts.dummy ~= false and not folder:FindFirstChild("Maniqui") then
		-- 2 x 5 x 1 studs, como un personaje R15 por defecto, a la derecha del modelo.
		local dummy = Instance.new("Part")
		dummy.Name = "Maniqui"
		dummy.Size = Vector3.new(2, 5, 1)
		dummy.Position = ORIGIN + Vector3.new(size.X / 2 + 3, 2.5, 0)
		dummy.Color = Color3.fromRGB(90, 140, 220)
		dummy.Transparency = 0.5
		plain(dummy)
		dummy.Parent = folder
	end

	local parts, meshParts, transparent = 0, 0, 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
			if descendant:IsA("MeshPart") then
				meshParts += 1
			end
			if descendant.Transparency >= 1 then
				transparent += 1
			end
		end
	end

	-- Cámaras: el frente de los modelos del proyecto mira hacia -Z.
	local distance = math.max(size.X, size.Y, size.Z) * 1.6 + 6
	local function camera(direction: Vector3, height: number)
		local position = center + direction.Unit * distance + Vector3.new(0, height, 0)
		return { position = vector(position), lookAt = vector(center) }
	end
	local cameras = {
		frente = camera(Vector3.new(0, 0, -1), size.Y * 0.15),
		lado = camera(Vector3.new(1, 0, 0), size.Y * 0.15),
		detras = camera(Vector3.new(0, 0, 1), size.Y * 0.15),
		tresCuartos = camera(Vector3.new(0.75, 0, -1), distance * 0.45),
		arriba = { position = vector(center + Vector3.new(0, distance * 1.2, -0.01)), lookAt = vector(center) },
	}

	return HttpService:JSONEncode({
		modelo = model:GetFullName(),
		tamanoStuds = vector(size),
		alturaEnPersonajes = round(size.Y / 5),
		piezas = parts,
		meshParts = meshParts,
		invisibles = transparent,
		centro = vector(center),
		camaras = cameras,
	})
end

-- Mueve la cámara de Studio (por si screen_capture no acepta posición o para dejarla al usuario).
function Preview.look(position: { number }, lookAt: { number })
	Workspace.CurrentCamera.CFrame =
		CFrame.lookAt(Vector3.new(position[1], position[2], position[3]), Vector3.new(lookAt[1], lookAt[2], lookAt[3]))
end

-- ===== Código del encargo a partir de aquí =====
