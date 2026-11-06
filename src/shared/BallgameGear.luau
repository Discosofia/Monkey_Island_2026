--!strict
-- Equipo visual del Juego de pelota (Fase 27e): solo cosmético y solo mientras dura el partido. Todos los
-- jugadores llevan lo mismo (yugo de piedra, rodilleras, palma a la espalda y tocado); cambian el color y el
-- motivo del tocado según el equipo: Jaguar (orejas y manchas) o Quetzal (abanico de plumas y cola).
-- Son piezas voxel soldadas a las partes del R15, visibles también por detrás (cámara en tercera persona).
--
--   build(team, character)   crea el Model "BallgameGear" hijo del personaje (quita antes el que hubiera)
--   remove(character)        lo destruye
--
-- No toca los atributos de cosméticos ni la ArmorPiece. Presupuesto: Config.Budgets.Models.BallgameGear.
-- Los colores salen de World/CourtDecor (teamColors): Jaguar rojo y amarillo, Quetzal jade y negro.

local VoxelMerge = require(script.Parent.VoxelMerge)

local GEAR_NAME = "BallgameGear"

local BLACK = Color3.fromRGB(36, 32, 36)
local STONE = Color3.fromRGB(150, 146, 138)
local STONE_DARK = Color3.fromRGB(104, 100, 96)
local TURQUOISE = Color3.fromRGB(48, 190, 170)

-- Color principal y de acento de cada equipo.
local TEAM_COLORS: { [string]: { main: Color3, accent: Color3 } } = {
	Jaguar = { main = Color3.fromRGB(172, 52, 40), accent = Color3.fromRGB(232, 186, 52) },
	Quetzal = { main = Color3.fromRGB(46, 125, 80), accent = BLACK },
}

-- Grosor de la diadema y alto de la banda (studs).
local BAND_THICK = 0.15
local BAND_HEIGHT = 0.25

local BallgameGear = {}

function BallgameGear.remove(character: Model)
	local previous = character:FindFirstChild(GEAR_NAME)
	if previous then
		previous:Destroy()
	end
end

-- Una pieza soldada a "anchor", en su espacio local ("offset" es el centro de la pieza).
local function addPiece(
	model: Model,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material
)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.Massless = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CFrame = anchor.CFrame * CFrame.new(offset)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = model
end

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- Yugo de tlachtli: anillo grueso de piedra cerrado alrededor de la cadera (frente, lados y espalda). Un emblema de
-- acento en el frente y un panel tallado en la espalda lo hacen legible desde los dos lados. Son 6 piezas.
local function addYoke(model: Model, waist: BasePart, main: Color3, accent: Color3)
	local w, d = waist.Size.X, waist.Size.Z
	local material = Enum.Material.Slate
	local thick = 0.45
	local height = 0.8
	local y = -0.1
	addPiece(
		model,
		waist,
		"YokeBack",
		Vector3.new(w + thick * 2, height, thick),
		Vector3.new(0, y, d / 2 + thick / 2),
		main,
		material
	)
	addPiece(
		model,
		waist,
		"YokePanel",
		Vector3.new(w * 0.5, 0.5, 0.1),
		Vector3.new(0, y, d / 2 + thick + 0.05),
		accent,
		Enum.Material.SmoothPlastic
	)
	for sign = -1, 1, 2 do
		local x = sign * (w / 2 + thick / 2)
		addPiece(
			model,
			waist,
			sign < 0 and "YokeLeft" or "YokeRight",
			Vector3.new(thick, height, d),
			Vector3.new(x, y, 0),
			main,
			material
		)
	end
	-- Frente cerrado: placa del mismo grosor que la espalda con un emblema de acento.
	addPiece(
		model,
		waist,
		"YokeFront",
		Vector3.new(w + thick * 2, height, thick),
		Vector3.new(0, y, -(d / 2 + thick / 2)),
		main,
		material
	)
	addPiece(
		model,
		waist,
		"YokeEmblem",
		Vector3.new(w * 0.5, 0.5, 0.1),
		Vector3.new(0, y, -(d / 2 + thick + 0.05)),
		accent,
		Enum.Material.SmoothPlastic
	)
end

-- Rodilleras: una banda alrededor de la rodilla (arriba de la espinilla) y una almohadilla ancha delante.
local function addKneePads(model: Model, shin: BasePart, main: Color3, accent: Color3, spot: Color3?)
	local w, h, d = shin.Size.X, shin.Size.Y, shin.Size.Z
	local kneeY = h / 2 - 0.15
	addPiece(
		model,
		shin,
		"KneeBand",
		Vector3.new(w + 0.08, 0.25, d + 0.08),
		Vector3.new(0, kneeY, 0),
		accent,
		Enum.Material.SmoothPlastic
	)
	local padZ = -(d / 2 + 0.1 + 0.1)
	addPiece(
		model,
		shin,
		"KneePad",
		Vector3.new(w * 0.9, 0.6, 0.2),
		Vector3.new(0, kneeY, padZ),
		main,
		Enum.Material.Slate
	)
	if spot then
		addPiece(
			model,
			shin,
			"Spot",
			Vector3.new(0.3, 0.3, 0.08),
			Vector3.new(0, kneeY, padZ - 0.1 - 0.04),
			spot,
			Enum.Material.SmoothPlastic
		)
	end
end

-- Palma: hoja de piedra tallada de pie en la espalda, con base y un adorno del color del equipo.
local function addPalma(model: Model, chest: BasePart, main: Color3)
	local d = chest.Size.Z
	local z = d / 2 + 0.3
	addPiece(
		model,
		chest,
		"PalmaBase",
		Vector3.new(0.8, 0.3, 0.3),
		Vector3.new(0, -0.55, d / 2 + 0.15),
		STONE_DARK,
		Enum.Material.Slate
	)
	addPiece(
		model,
		chest,
		"PalmaBlade",
		Vector3.new(0.7, 1.7, 0.18),
		Vector3.new(0, 0.2, z),
		STONE,
		Enum.Material.Slate
	)
	addPiece(
		model,
		chest,
		"PalmaMark",
		Vector3.new(0.4, 0.4, 0.1),
		Vector3.new(0, 0.5, z + 0.14),
		main,
		Enum.Material.SmoothPlastic
	)
end

-- Altura (en el espacio de la cabeza) del centro de la diadema: a la altura de la frente.
local function bandY(head: BasePart): number
	return 0.36 * head.Size.Y
end

-- Diadema: un aro cerrado que abraza la cabeza (frente, espalda y dos lados), sin huecos ni salientes.
local function addHeadband(model: Model, head: BasePart, color: Color3)
	local hx, hz = head.Size.X, head.Size.Z
	local y = bandY(head)
	for sign = -1, 1, 2 do
		addPiece(
			model,
			head,
			sign < 0 and "BandFront" or "BandBack",
			Vector3.new(hx + BAND_THICK * 2, BAND_HEIGHT, BAND_THICK),
			Vector3.new(0, y, sign * (hz / 2 + BAND_THICK / 2)),
			color,
			Enum.Material.SmoothPlastic
		)
		addPiece(
			model,
			head,
			sign < 0 and "BandLeft" or "BandRight",
			Vector3.new(BAND_THICK, BAND_HEIGHT, hz),
			Vector3.new(sign * (hx / 2 + BAND_THICK / 2), y, 0),
			color,
			Enum.Material.SmoothPlastic
		)
	end
end

-- Jaguar: dos orejas ámbar apoyadas en las esquinas de arriba de la diadema y tres manchas negras en ella
-- (una delante y dos detrás).
local function addJaguarHead(model: Model, head: BasePart, accent: Color3)
	local hx, hz = head.Size.X, head.Size.Z
	local y = bandY(head)
	local earHeight = 0.4
	for sign = -1, 1, 2 do
		addPiece(
			model,
			head,
			"Ear",
			Vector3.new(0.4, earHeight, 0.4),
			Vector3.new(sign * (hx / 2 - 0.05), y + BAND_HEIGHT / 2 + earHeight / 2, 0),
			accent,
			Enum.Material.SmoothPlastic
		)
	end
	local spot = Vector3.new(0.32, 0.2, 0.08)
	local out = hz / 2 + BAND_THICK + 0.04
	addPiece(model, head, "Spot", spot, Vector3.new(0, y, -out), BLACK, Enum.Material.SmoothPlastic)
	addPiece(model, head, "Spot", spot, Vector3.new(-0.38, y, out), BLACK, Enum.Material.SmoothPlastic)
	addPiece(model, head, "Spot", spot, Vector3.new(0.38, y, out), BLACK, Enum.Material.SmoothPlastic)
end

-- Quetzal: abanico de cinco plumas anchas de distinta altura y, desde la nuca, dos colas largas
-- que caen por la espalda en S, a los lados de la palma.
local function addQuetzalHead(model: Model, head: BasePart, main: Color3)
	local hy, hz = head.Size.Y, head.Size.Z
	local heights = { 0.8, 1.1, 1.4, 1.1, 0.8 }
	for i, height in heights do
		addPiece(
			model,
			head,
			"Plume",
			Vector3.new(0.4, height, 0.12),
			-- Empotradas un poco en la cabeza; las pares, algo adelantadas para no coincidir en plano.
			Vector3.new((i - 3) * 0.3, hy / 2 - 0.1 + height / 2, if i % 2 == 0 then -0.08 else 0),
			if i % 2 == 1 then main else TURQUOISE,
			Enum.Material.SmoothPlastic
		)
	end
	-- Cola: dos plumas largas que salen de la nuca y barren la espalda en S suave. Cada una son tres segmentos
	-- escalonados (cada uno desplazado 0,15 en X del anterior, hacia fuera y hacia dentro), más largos y más finos
	-- hacia abajo, y una punta con ojo. El segmento del medio es turquesa (la vena); la cola llega a las rodillas.
	local top = bandY(head) - BAND_HEIGHT / 2 + 0.05
	local z = hz / 2 + BAND_THICK / 2
	local widths = { 0.45, 0.4, 0.3 }
	local lengths = { 0.9, 1.2, 1.4 }
	local shifts = { 0, 0.45, 0.15 }
	for sign = -1, 1, 2 do
		local y = top
		for i, length in lengths do
			local x = sign * (0.5 + shifts[i])
			addPiece(
				model,
				head,
				"Plume",
				Vector3.new(widths[i], length, BAND_THICK),
				Vector3.new(x, y - length / 2, z),
				if i == 2 then TURQUOISE else main,
				Enum.Material.SmoothPlastic
			)
			y -= length
		end
		-- Punta con ojo: un bloque turquesa que sobresale un poco hacia fuera, al final de la S.
		addPiece(
			model,
			head,
			"Plume",
			Vector3.new(0.3, 0.3, BAND_THICK),
			Vector3.new(sign * 0.65, y - 0.15, z),
			TURQUOISE,
			Enum.Material.SmoothPlastic
		)
	end
end

-- Viste a "character" (R15) con el equipo de "team" ("Jaguar" o "Quetzal"). Las partes que falten se saltan.
function BallgameGear.build(team: string, character: Model): Model
	BallgameGear.remove(character)
	local colors = TEAM_COLORS[team] or TEAM_COLORS.Jaguar
	local jaguar = team ~= "Quetzal"
	local model = Instance.new("Model")
	model.Name = GEAR_NAME
	local waist = part(character, "LowerTorso")
	if waist then
		addYoke(model, waist, colors.main, colors.accent)
	end
	for _, name in { "LeftLowerLeg", "RightLowerLeg" } do
		local shin = part(character, name)
		if shin then
			addKneePads(model, shin, colors.main, colors.accent, if jaguar then BLACK else nil)
		end
	end
	local chest = part(character, "UpperTorso")
	if chest then
		addPalma(model, chest, colors.main)
	end
	local head = part(character, "Head")
	if head then
		addHeadband(model, head, colors.main)
		if jaguar then
			addJaguarHead(model, head, colors.accent)
		else
			addQuetzalHead(model, head, colors.main)
		end
	end
	-- Por miembro (Part0 de las soldaduras), antes de ponerlo en el personaje.
	VoxelMerge.mergeWelded(model)
	model.Parent = character
	return model
end

return BallgameGear
