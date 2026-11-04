--!strict
-- Depuración del campo de tiro (Fase 23e, solo Studio). Lo activan las órdenes del panel de pruebas
-- (DebugService), que ponen atributos en el jugador:
--   DebugRangeHitboxes: dibuja encima de los combatientes (monos, muñecos, dianas y otros jugadores) lo que
--     el servidor prueba al disparar: la esfera de la cabeza y la cápsula del cuerpo (Config.Combat.Headshot,
--     como Combat/Hitbox.bodyShape) y cada pieza con el color de su zona. Colores: cabeza rosa, torso azul,
--     miembro amarillo, punto débil blanco; sin verde (curación), morado (veneno) ni rojo (daño).
--   DebugRangeTraces: dibuja cada disparo al acabar (Remotes.RangeDebug): naranja = línea del servidor,
--     celeste = la puntería que mandó tu cliente, punto en el impacto y un cartel con el ping, los grados de
--     ayuda de puntería y los segundos rebobinados. Se borra solo.
--   DebugRangeFx: cada vez que sube, enseña el siguiente efecto en el muro de materiales: la marca de impacto
--     en cada panel, el impacto en un cuerpo y el estallido de crítico de cada estilo (BurstStyle).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ImpactFx = require(ReplicatedStorage.CombatClient.ImpactFx)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local FxQuality = require(ReplicatedStorage.Shared.FxQuality)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ComicBurst = require(ReplicatedStorage.Shared.UI.ComicBurst)

local HEADSHOT = Config.Combat.Headshot
local player = Players.LocalPlayer

-- Colores (ver arriba: nada de verde, morado ni rojo).
local ZONE_COLORS: { [string]: Color3 } = {
	Head = Color3.fromRGB(255, 120, 200),
	Torso = Color3.fromRGB(80, 160, 255),
	Limb = Color3.fromRGB(255, 215, 90),
	Weak = Color3.new(1, 1, 1),
}
local CAPSULE_COLOR = Color3.fromRGB(120, 230, 255)
local SERVER_LINE = Color3.fromRGB(255, 140, 40)
local CLIENT_LINE = Color3.fromRGB(120, 230, 255)
-- Hitbox: hasta dónde y a cuántos se dibujan, y cada cuántos segundos se rehacen sus medidas.
local HITBOX_RANGE = 160
local HITBOX_MAX = 40
local HITBOX_REFRESH = 0.1
local TRACE_SECONDS = 4
local LINE_THICKNESS = 0.08

local ZONE_BY_NAME: { [string]: string } = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	HumanoidRootPart = "Torso",
	Torso = "Torso",
	LeftUpperArm = "Limb",
	LeftLowerArm = "Limb",
	LeftHand = "Limb",
	RightUpperArm = "Limb",
	RightLowerArm = "Limb",
	RightHand = "Limb",
	LeftUpperLeg = "Limb",
	LeftLowerLeg = "Limb",
	LeftFoot = "Limb",
	RightUpperLeg = "Limb",
	RightLowerLeg = "Limb",
	RightFoot = "Limb",
	["Left Arm"] = "Limb",
	["Right Arm"] = "Limb",
	["Left Leg"] = "Limb",
	["Right Leg"] = "Limb",
}

local RangeDebugController = {}

local root: Folder
-- Lo dibujado de cada combatiente: su carpeta de adornos y la cápsula y la cabeza, que se rehacen.
type Drawn = { folder: Folder, capsule: CylinderHandleAdornment, head: SphereHandleAdornment? }
local drawn: { [Model]: Drawn } = {}

-- Misma regla que Combat/Hitbox.zoneOf (atributo Zone, WeakPoint, nombre de la pieza, si no el torso).
local function zoneOf(model: Model, part: Instance): string
	local current: Instance? = part
	while current and current ~= model do
		local tagged = current:GetAttribute("Zone")
		if typeof(tagged) == "string" and ZONE_COLORS[tagged] then
			return tagged
		end
		if current:GetAttribute("WeakPoint") == true then
			return "Weak"
		end
		current = current.Parent
	end
	return ZONE_BY_NAME[part.Name] or "Torso"
end

local function clearHitboxes()
	for model, entry in drawn do
		entry.folder:Destroy()
		drawn[model] = nil
	end
end

local function adorn(parent: Instance, adornment: GuiBase3d | HandleAdornment, color: Color3, transparency: number)
	adornment.Name = "Hitbox"
	adornment.Color3 = color
	adornment.Transparency = transparency
	adornment.Parent = parent
end

local function draw(model: Model): Drawn?
	local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not (rootPart and rootPart:IsA("BasePart")) then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = model.Name
	folder.Parent = root

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 and descendant.Name ~= "HumanoidRootPart" then
			local box = Instance.new("BoxHandleAdornment")
			box.Adornee = descendant
			box.Size = descendant.Size
			box.AlwaysOnTop = true
			box.ZIndex = 1
			adorn(folder, box, ZONE_COLORS[zoneOf(model, descendant)], 0.75)
		end
	end

	local capsule = Instance.new("CylinderHandleAdornment")
	capsule.Adornee = rootPart
	capsule.AlwaysOnTop = true
	capsule.ZIndex = 2
	capsule.Radius = HEADSHOT.BodyRadius
	adorn(folder, capsule, CAPSULE_COLOR, 0.8)

	local headPart = model:FindFirstChild("Head")
	local head: SphereHandleAdornment? = nil
	if headPart and headPart:IsA("BasePart") then
		head = Instance.new("SphereHandleAdornment")
		head.Adornee = headPart
		head.AlwaysOnTop = true
		head.ZIndex = 3
		head.Radius = math.max(headPart.Size.X, headPart.Size.Y, headPart.Size.Z) / 2 * HEADSHOT.HeadRadiusScale
		adorn(folder, head, ZONE_COLORS.Head, 0.55)
	end
	return { folder = folder, capsule = capsule, head = head }
end

-- Cápsula vertical de los pies al cuello (como Hitbox.bodyShape), en el sistema de la raíz.
local function refreshCapsule(model: Model, entry: Drawn)
	local rootPart = entry.capsule.Adornee
	if not (rootPart and rootPart:IsA("BasePart")) then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local feetY = rootPart.Position.Y - ((if humanoid then humanoid.HipHeight else 0) + rootPart.Size.Y / 2)
	local neckY = rootPart.Position.Y + rootPart.Size.Y / 2
	local head = entry.head
	local headPart = if head then head.Adornee else nil
	if head and headPart and headPart:IsA("BasePart") then
		neckY = headPart.Position.Y - head.Radius
	end
	neckY = math.max(neckY, feetY)
	local height = math.max(neckY - feetY, 0.1)
	local center = Vector3.new(rootPart.Position.X, (feetY + neckY) / 2, rootPart.Position.Z)
	-- El eje del cilindro de adorno es su Z; se tumba a la vertical del mundo.
	entry.capsule.Height = height
	entry.capsule.CFrame = rootPart.CFrame:ToObjectSpace(CFrame.new(center) * CFrame.Angles(math.pi / 2, 0, 0))
end

local function combatants(): { Model }
	local list: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, instance in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		if instance:IsA("Model") then
			seen[instance] = true
			table.insert(list, instance)
		end
	end
	-- Las dianas emergentes pierden la etiqueta al hundirse (RangeTargetService): se buscan también por su
	-- atributo para que sus hitbox no aparezcan y desaparezcan con ellas.
	local range = Workspace:FindFirstChild("CampoDeTiro")
	local targets = range and range:FindFirstChild("Dianas")
	if targets then
		for _, target in targets:GetChildren() do
			if target:IsA("Model") and not seen[target] and target:GetAttribute("RangeTarget") == true then
				table.insert(list, target)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	return list
end

local function updateHitboxes()
	local character = player.Character
	local origin = character and character:FindFirstChild("HumanoidRootPart")
	local origin3 = if origin and origin:IsA("BasePart") then origin.Position else Vector3.zero
	local wanted: { [Model]: boolean } = {}
	local count = 0
	for _, model in combatants() do
		local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if
			model ~= character
			and rootPart
			and rootPart:IsA("BasePart")
			and (rootPart.Position - origin3).Magnitude <= HITBOX_RANGE
			and count < HITBOX_MAX
		then
			count += 1
			wanted[model] = true
			local entry = drawn[model]
			if not entry then
				entry = draw(model)
				drawn[model] = entry
			end
			if entry then
				refreshCapsule(model, entry)
			end
		end
	end
	for model, entry in drawn do
		if not wanted[model] then
			entry.folder:Destroy()
			drawn[model] = nil
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Trazas

local function line(from: Vector3, to: Vector3, color: Color3, thickness: number): Part
	local part = Instance.new("Part")
	part.Name = "Traza"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(thickness, thickness, math.max((to - from).Magnitude, 0.05))
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = root
	return part
end

local function onTrace(data: any)
	if typeof(data) ~= "table" or typeof(data.origin) ~= "Vector3" or typeof(data.hit) ~= "Vector3" then
		return
	end
	local origin: Vector3 = data.origin
	local hit: Vector3 = data.hit
	local direction = data.direction :: Vector3
	local length = (hit - origin).Magnitude
	local made: { Instance } = {}
	table.insert(made, line(origin, hit, SERVER_LINE, LINE_THICKNESS))

	local degrees = 0
	local aim = data.aim
	if typeof(aim) == "Vector3" and aim.Magnitude > 0 then
		table.insert(made, line(origin, origin + aim.Unit * length, CLIENT_LINE, LINE_THICKNESS * 0.6))
		degrees = math.deg(math.acos(math.clamp(aim.Unit:Dot(direction.Unit), -1, 1)))
	end

	local marker = Instance.new("Part")
	marker.Name = "Impacto"
	marker.Shape = Enum.PartType.Ball
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.Neon
	marker.Color = SERVER_LINE
	marker.Size = Vector3.one * 0.5
	marker.Position = hit
	marker.Parent = root
	table.insert(made, marker)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 22)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = marker
	gui.Parent = marker
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 14
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.format(
		"%d ms · ayuda %.1f° · rebobina %.2f s · %.0f st",
		data.pingMs or 0,
		degrees,
		data.rewind or 0,
		length
	)
	label.Parent = gui

	task.delay(TRACE_SECONDS, function()
		for _, instance in made do
			instance:Destroy()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Estación de efectos

-- Los pasos: la marca de impacto en cada panel de materiales, el impacto en un cuerpo y un crítico con el
-- estilo de estallido de cada BurstStyle (el primero, sin estilo).
local fxIndex = 0

local function styleIds(): { string }
	local ids: { string } = {}
	for id, cosmetic in Cosmetics do
		if cosmetic.kind == "BurstStyle" and ComicBurst.hasStyle(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function panels(): { BasePart }
	local list: { BasePart } = {}
	local range = Workspace:FindFirstChild("CampoDeTiro")
	local folder = range and range:FindFirstChild("PanelesDeMateriales")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Panel" then
				table.insert(list, child)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Position.Z > b.Position.Z
	end)
	return list
end

local function burstAt(position: Vector3, kind: ComicBurst.Kind, styleId: string?)
	local anchor = Instance.new("Attachment")
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local gui = Instance.new("BillboardGui")
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(220, 220)
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local life = ComicBurst.play(frame, kind, ComicBurst.word(kind, "Ranged", styleId), 220, false, styleId)
	task.delay(life + 0.1, function()
		gui:Destroy()
		anchor:Destroy()
	end)
end

local function nextEffect()
	local list = panels()
	if #list == 0 then
		return
	end
	local styles = styleIds()
	local total = 2 + 1 + #styles
	fxIndex = fxIndex % total + 1
	local quality = FxQuality.get()
	-- Los paneles miran a -x (están en el muro de la derecha): el disparo viaja hacia +x.
	local direction = Vector3.xAxis
	local label: string
	if fxIndex == 1 then
		for _, panel in list do
			ImpactFx.play(panel.Position - Vector3.xAxis * (panel.Size.X / 2 + 0.05), direction, false, quality)
		end
		label = "impacto en los cuatro materiales"
	elseif fxIndex == 2 then
		for _, panel in list do
			ImpactFx.play(panel.Position - Vector3.xAxis * 6, direction, true, quality)
		end
		label = "impacto en un cuerpo"
	else
		local styleId = if fxIndex == 3 then nil else styles[fxIndex - 3]
		for _, panel in list do
			burstAt(panel.Position - Vector3.xAxis * 6 + Vector3.yAxis * 2, "Crit", styleId)
		end
		label = `crítico, estilo {styleId or "ninguno"}`
	end
	print(`[RangeDebug] Efecto {fxIndex}/{total}: {label}`)
end

---------------------------------------------------------------------------------------------------

function RangeDebugController:Start()
	root = Instance.new("Folder")
	root.Name = "RangeDebug"
	root.Parent = Workspace.CurrentCamera or Workspace

	Remotes.RangeDebug.OnClientEvent:Connect(function(kind: any, data: any)
		if kind == "Trace" and player:GetAttribute("DebugRangeTraces") == true then
			onTrace(data)
		end
	end)

	local lastFx = player:GetAttribute("DebugRangeFx")
	player:GetAttributeChangedSignal("DebugRangeFx"):Connect(function()
		local value = player:GetAttribute("DebugRangeFx")
		if value ~= lastFx then
			lastFx = value
			nextEffect()
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < HITBOX_REFRESH then
			return
		end
		elapsed = 0
		if player:GetAttribute("DebugRangeHitboxes") == true then
			updateHitboxes()
		elseif next(drawn) then
			clearHitboxes()
		end
	end)
end

return RangeDebugController
