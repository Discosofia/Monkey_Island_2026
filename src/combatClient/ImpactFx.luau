--!strict
-- Impactos de las balas de las armas (Fase 19, W5). Lo llama AbilityFxController cuando una bala acaba:
--   ImpactFx.play(position, direction, hitBody, quality)
-- Contra una pared o el suelo deja una marca oscura (la losa voxel de Config.ImpactFx.MarkSize, del tono de la
-- pieza), unas chispas cálidas y una bocanada de polvo del color de la pieza. Contra un cuerpo (hitBody) salta
-- pulpa de plátano: cubitos amarillos que se desvanecen sin física.
-- Todo sale de pools con tope duro (Config.Budgets.ImpactMarks para las marcas; el doble de
-- Config.ImpactFx.Pulp.High para los cubitos): cuando están llenos no se crea nada, se recicla la marca más
-- vieja y la pulpa que no cabe no sale. Sin Debris. Las piezas cuelgan de la carpeta de efectos del cliente
-- (ImpactFx.setFolder). La calidad la resuelve quien llama (FxQuality.get()).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type Quality = "Low" | "Medium" | "High"

type Mark = {
	part: Part,
	token: number, -- sube cada vez que se recicla: anula lo que quedaba pendiente de su uso anterior
	tween: Tween?,
}

type Cube = {
	part: Part,
	busy: boolean,
}

local ImpactFx = {}

local SPARK_COLOR = Color3.fromRGB(255, 220, 120)
local PULP_COLOR = Color3.fromRGB(255, 225, 90) -- amarillo plátano
local PULP_SIZE = 0.12
local PULP_SECONDS = 0.45
local DARKEN = 0.55 -- cuánto se mezcla con negro el color de la marca
local MARK_GAP = 0.02 -- separación de la marca a la superficie
local FLOOR_NORMAL_Y = 0.7 -- a partir de aquí la superficie es suelo
local PROBE_BEHIND = 0.6 -- el raycast empieza esto detrás del punto de impacto
local PROBE_AHEAD = 1.6 -- y llega esto por delante

local rng = Random.new()
local folder: Instance? = nil
local marks: { Mark } = {}
local nextMark = 0
local cubes: { Cube } = {}
local anchor: Part? = nil
local sparks: ParticleEmitter? = nil
local dust: ParticleEmitter? = nil
local attachment: Attachment? = nil

-- La carpeta de efectos del cliente (AbilityFx) de la que cuelga todo.
function ImpactFx.setFolder(newFolder: Instance)
	folder = newFolder
	-- Si había piezas en la carpeta anterior, se vuelven a colgar de la nueva al usarlas.
	if anchor then
		anchor.Parent = newFolder
	end
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material
	return part
end

-- Un emisor de cuadraditos voxel (sin textura: la partícula sale como un cuadrado plano).
local function newEmitter(parent: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = ""
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.LightEmission = 0
	emitter.Drag = 4
	emitter.Parent = parent
	return emitter
end

-- El ancla invisible con los dos emisores (chispas y polvo): una sola para todos los impactos.
local function ensureEmitters(): Attachment?
	local parent = folder
	if not parent then
		return nil
	end
	if attachment and anchor and anchor.Parent == parent then
		return attachment
	end
	if anchor then
		anchor:Destroy()
	end
	local base = newPart("ImpactEmitters", Vector3.one * 0.1, Color3.new(), Enum.Material.SmoothPlastic)
	base.Transparency = 1
	local point = Instance.new("Attachment")
	point.Parent = base

	local spark = newEmitter(point)
	spark.Color = ColorSequence.new(SPARK_COLOR)
	spark.Size = NumberSequence.new(0.14, 0.04)
	spark.Lifetime = NumberRange.new(0.15, 0.3)
	spark.Speed = NumberRange.new(7, 14)
	spark.SpreadAngle = Vector2.new(55, 55)
	spark.LightEmission = 0.6
	spark.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})

	local puff = newEmitter(point)
	puff.Size = NumberSequence.new(0.2, 0.55)
	puff.Lifetime = NumberRange.new(0.4, 0.7)
	puff.Speed = NumberRange.new(1.5, 4)
	puff.SpreadAngle = Vector2.new(70, 70)
	puff.Transparency = NumberSequence.new(0.35, 1)

	base.Parent = parent
	anchor = base
	attachment = point
	sparks = spark
	dust = puff
	return point
end

-- Dónde y cómo está la superficie que ha tocado la bala: punto, normal, color y material de la pieza.
type Surface = { point: Vector3, normal: Vector3, color: Color3, material: Enum.Material, floor: boolean, real: boolean }

-- Un raycast corto alrededor del impacto, sin los efectos ni los personajes. Sin acierto, la superficie
-- es la del propio punto con la normal opuesta a la bala.
local function probe(position: Vector3, direction: Vector3): Surface
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignored: { Instance } = {}
	if folder then
		table.insert(ignored, folder)
	end
	params.FilterDescendantsInstances = ignored
	local origin = position - direction * PROBE_BEHIND
	local ray = direction * PROBE_AHEAD
	for _ = 1, 3 do
		local result = Workspace:Raycast(origin, ray, params)
		if not result then
			break
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			-- Un personaje (o un mono) por delante: se salta y se vuelve a tirar.
			table.insert(ignored, model)
			params.FilterDescendantsInstances = ignored
		else
			local color = if result.Instance:IsA("Terrain")
				then Workspace.Terrain:GetMaterialColor(result.Material)
				else (result.Instance :: BasePart).Color
			return {
				point = result.Position,
				normal = result.Normal,
				color = color,
				material = result.Material,
				floor = result.Normal.Y > FLOOR_NORMAL_Y,
				real = true,
			}
		end
	end
	return {
		point = position,
		normal = -direction,
		color = Color3.fromRGB(150, 140, 130),
		material = Enum.Material.Plastic,
		floor = false,
		real = false,
	}
end

-- La marca de la pared o el suelo: una losa que se recicla de un pool circular.
local function placeMark(surface: Surface, quality: Quality)
	local cap = Config.Budgets.ImpactMarks[quality]
	nextMark = nextMark % cap + 1
	local mark = marks[nextMark]
	if not mark then
		mark = {
			part = newPart("ImpactMark", Config.ImpactFx.MarkSize, Color3.new(), Enum.Material.SmoothPlastic),
			token = 0,
		}
		marks[nextMark] = mark
	end
	local slot: Mark = mark
	slot.token += 1
	local token = slot.token
	if slot.tween then
		slot.tween:Cancel()
		slot.tween = nil
	end
	local part = slot.part
	part.Color = surface.color:Lerp(Color3.new(), DARKEN)
	part.Transparency = 0
	local spin = rng:NextNumber(0, math.pi * 2)
	part.CFrame = CFrame.lookAt(
		surface.point + surface.normal * (MARK_GAP + Config.ImpactFx.MarkSize.Z / 2),
		surface.point + surface.normal
	) * CFrame.Angles(0, 0, spin)
	part.Parent = folder
	task.delay(Config.ImpactFx.MarkSeconds, function()
		if slot.token ~= token then
			return
		end
		local fade = TweenService:Create(
			part,
			TweenInfo.new(Config.ImpactFx.MarkFadeSeconds, Enum.EasingStyle.Linear),
			{ Transparency = 1 }
		)
		slot.tween = fade
		fade.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and slot.token == token then
				part.Parent = nil
				slot.tween = nil
			end
		end)
		fade:Play()
	end)
end

-- Chispas y polvo: los emisores se colocan en la superficie, con su arriba por la normal, y emiten de golpe.
local function emitSurface(surface: Surface, quality: Quality)
	local point = ensureEmitters()
	local spark, puff = sparks, dust
	local base = anchor
	if not (point and spark and puff and base) then
		return
	end
	local frame = CFrame.lookAt(surface.point, surface.point + surface.normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	base.CFrame = frame
	spark:Emit(Config.ImpactFx.Sparks[quality])
	puff.Color = ColorSequence.new(surface.color:Lerp(Color3.new(1, 1, 1), 0.2))
	puff:Emit(Config.ImpactFx.Dust[quality])
end

-- La pulpa de plátano contra un cuerpo: cubitos del pool que salen hacia fuera y se desvanecen sin física.
local function emitPulp(position: Vector3, direction: Vector3, quality: Quality)
	local cap = Config.ImpactFx.Pulp.High * 2
	for _ = 1, Config.ImpactFx.Pulp[quality] do
		local cube: Cube? = nil
		for _, candidate in cubes do
			if not candidate.busy then
				cube = candidate
				break
			end
		end
		if not cube and #cubes < cap then
			local fresh: Cube = {
				part = newPart("ImpactPulp", Vector3.one * PULP_SIZE, PULP_COLOR, Enum.Material.SmoothPlastic),
				busy = false,
			}
			table.insert(cubes, fresh)
			cube = fresh
		end
		if not cube then
			return
		end
		local used: Cube = cube
		used.busy = true
		local part = used.part
		local spread = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1))
		local outward = (-direction * rng:NextNumber(0.4, 1) + spread).Unit * rng:NextNumber(1.2, 2.6)
		part.Transparency = 0
		part.CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		part.Parent = folder
		local tween = TweenService:Create(
			part,
			TweenInfo.new(PULP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = position + outward, Transparency = 1 }
		)
		tween.Completed:Once(function()
			part.Parent = nil
			used.busy = false
		end)
		tween:Play()
	end
end

-- Un impacto: "position" es donde acabó la bala, "direction" hacia dónde iba y "hitBody" si paró en un cuerpo.
function ImpactFx.play(position: Vector3, direction: Vector3, hitBody: boolean, quality: Quality)
	if not folder then
		return
	end
	local heading = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis
	if hitBody then
		emitPulp(position, heading, quality)
		return
	end
	local surface = probe(position, heading)
	-- Sin pieza real donde pegarla (el raycast no acertó), no hay marca.
	if surface.real then
		placeMark(surface, quality)
	end
	emitSurface(surface, quality)
end

-- Para la calculadora Rendimiento: las piezas más que puede haber a la vez, por calidad.
function ImpactFx.peakPieces(quality: Quality): { marks: number, pulp: number, emitters: number }
	return {
		marks = Config.Budgets.ImpactMarks[quality],
		pulp = Config.ImpactFx.Pulp.High * 2,
		emitters = 1,
	}
end

return ImpactFx
