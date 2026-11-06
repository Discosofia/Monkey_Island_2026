--!strict
-- Decorado voxel de la cancha del Juego de pelota (Fase 27d): los dos templos en pirámide tras las cabeceras, los
-- estandartes y los ídolos de la plaza, los relieves de animales del paramento y de las cabeceras, la greca de la
-- cornisa y las gradas con público. Todo es decorado (sin colisión ni consulta de rayos) salvo las terrazas de
-- las pirámides, que son un sólido (la plaza se anda, la pirámide no).
--
-- Lo llama CourtBuilder, que le pasa sus ayudantes y colores en "kit" (así no hay un require circular ni colores
-- repetidos):
--   buildStatic(folder, kit)       lo que no depende del formato: Cancha.Decor (templos, estandartes, ídolos)
--   buildLayout(art, geo, kit)     lo que depende de geo.halfLength: Cancha.Court.Decor.Extras (relieves,
--                                  greca de la cornisa, gradas y público)
-- Las dos fusionan lo que crean con VoxelMerge.mergeStatic (cajas contiguas del mismo color pasan a una pieza;
-- los nombres que VoxelMerge nunca fusiona, como "Greca", "Feather" o "Border", no se usan aquí).
--
-- Estandartes y no tzompantli (decisión del usuario 06-11-2026).
--
-- Cómo medir las piezas: build() de CourtBuilder imprime «¡Cancha lista! (N piezas con el formato 5v5)» (todo,
-- ya fusionado) y, debajo, las piezas de este decorado antes y después de fusionar; CourtDecor.count(folder)
-- cuenta las de cualquier carpeta. El tope es Config.Budgets.Matches.CourtParts.
--
-- Medidas (coordenadas locales de la cancha; X negativa = Jaguar, X positiva = Quetzal; nivel de plaza y = 30):
--   Templo        5 terrazas de 7 de alto (y 30..65) entre |x| = 98 y 131 (la de abajo), z ±42; cada una se
--                 retranquea 3 por delante, 4 por los lados y 1 por detrás (la de arriba: |x| 110..127, z ±26).
--                 Escalinata central de 16 de ancho (35 peldaños de 1, desde |x| = 97,6, paso 0,34). Santuario
--                 |x| 110,5..126,5, z ±10, y 65..77, con puerta de 5 × 8; techo, crestería de 9 (y 78..87) y
--                 emblema de casillas de 1. 4 braseros. Alto total: 87 (57 sobre la plaza).
--   Estandartes   8 por equipo: fila A |x| = 94,2 en z ±24 y ±36; fila B |x| = 112 en z ±52 y ±66. Asta de 18,
--                 paño de 5 × 10.
--   Ídolos        6 (z) × 7 (y) × 5 (x) en |x| 92,5..97,5, z ±(9..15), uno a cada lado de la escalera.
--   Relieves      paneles de 16 × 8 casillas de 1 en el paramento (y 19,5..27,5), a |x| = 22 y 42 (los que caben,
--                 |x| + 8 <= halfLength - 1); en el fondo de cada cabecera, dos de 24 × 12 (casillas de 1,5) a
--                 z = ±26, y 8..20. Fondo marrón oscuro, silueta en dos colores y contorno de cal.
--   Gradas        3 gradas de 4 de fondo y 2,5 de alto, en z 52..64 a cada lado, |x| <= halfLength - 1. Cabezas de
--                 piel (un cubo, sin nada encima) cada 4 studs sobre un torso corrido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local VoxelMerge = require(ReplicatedStorage.Shared.VoxelMerge)

export type Maker = (parent: Instance, name: string, bounds: { number }, color: Color3, material: Enum.Material) -> Part

-- Lo que CourtBuilder presta: sus dos creadores de cajas, sus materiales y su paleta.
export type Kit = {
	deco: Maker,
	solid: Maker,
	Paint: Enum.Material,
	Limestone: Enum.Material,
	STUCCO: Color3,
	STONE: Color3,
	STONE_DARK: Color3,
	LIMESTONE_DARK: Color3,
	RED: Color3,
	BLUE: Color3,
	YELLOW: Color3,
	BLACK: Color3,
	JADE: Color3,
}

local CourtDecor = {}

-- Última fusión de cada parte (CourtBuilder la imprime al construir todo).
CourtDecor.lastStatic = nil :: VoxelMerge.Result?
CourtDecor.lastLayout = nil :: VoxelMerge.Result?

-- Sin la etiqueta "Detalle": no hay controlador de LOD de detalle en Dunas.
local MERGE_OPTIONS: VoxelMerge.Options = { tag = false }

-- Fuego de los braseros (Neon): naranja, ni rojo ni amarillo puros.
local FIRE = Color3.fromRGB(255, 150, 40)
-- Tonos de piel mate del público.
local SKINS = { Color3.fromRGB(198, 134, 92), Color3.fromRGB(156, 102, 70), Color3.fromRGB(224, 172, 126) }

-- Templo.
local TERRACES = 5
local TERRACE_HEIGHT = 7
local TEMPLE_FRONT_X = 98 -- |x| de la cara de delante de la terraza de abajo (mira a la cancha)
local TEMPLE_BACK_X = 131 -- la plaza llega a 132
local TEMPLE_HALF_Z = 42
local FRONT_SETBACK, BACK_SETBACK, SIDE_SETBACK = 3, 1, 4
local STAIR_HALF_Z = 8 -- escalinata de 16 de ancho
local STAIR_FRONT_X = 97.6 -- el primer peldaño sobresale 0,4 de la terraza de abajo
local STAIR_RUN = 0.34 -- 35 peldaños de 1 de alto repartidos en los 12 del retranqueo de delante
local STAIR_BACK_X = 110.5 -- hasta dónde llegan los peldaños (la pared del santuario)
local SANCT_FRONT_X, SANCT_BACK_X, SANCT_HALF_Z = 110.5, 126.5, 10
local SANCT_HEIGHT = 12
local COMB_X1, COMB_X2 = 112, 114.5 -- la crestería, en el techo y sobre la puerta

-- Estandartes e ídolos. Fila A entre el muro del fondo (92) y la pirámide (98); fila B a los lados de la pirámide.
local BANNER_ROWS = {
	{ x = 94.2, zs = { -36, -24, 24, 36 } },
	{ x = 112, zs = { -66, -52, 52, 66 } },
}
local IDOL_X1, IDOL_X2 = 92.5, 97.5
local IDOL_Z = 12 -- centro del ídolo (de 6 de ancho: z 9..15, junto a la escalinata de ±8)

-- Relieves del paramento: 16 columnas × 8 filas de 1 de lado, de y = 19,5 a 27,5 (el friso va de 27,5 a 29,5).
local RELIEF_TOP = 27.5
local RELIEF_CENTERS = { 22, 42 } -- |x| del centro de cada panel (de 16 de ancho)
local RELIEF_BACK = Color3.fromRGB(58, 42, 34) -- fondo marrón muy oscuro de los relieves

-- Gradas.
local STAND_Z1 = 52
local STAND_TIERS = 3
local STAND_DEPTH = 4
local STAND_RISE = 2.5
local HEAD_STEP = 4 -- una cabeza cada tanto (el presupuesto de piezas)
local GRECA_STEP = 5 -- una caja cada tanto en la cornisa

-- Imágenes de las casillas, de 16 columnas × 8 filas. «.» es hueco (el fondo oscuro); A y B, los colores del
-- panel; O, el contorno de una casilla (cal).
local ANIMALS = {
	-- Jaguar de frente: orejas, ojos grandes, nariz y hocico, con el fondo oscuro entre las manchas.
	{
		"..AAA......AAA..",
		".AAAAAAAAAAAAAA.",
		"AAABBAAAAAABBAAA",
		"A.ABBAAOOAABBA.A",
		"AAAAAAAOOAAAAAAA",
		".AA.AAAAAAAA.AA.",
		"..AAAOOOOOOAAA..",
		".....AAAAAA.....",
	},
	-- Serpiente emplumada en ouroboros: un anillo que se muerde la cola. La cabeza (arriba a la derecha, con ojo) abre
	-- las fauces sobre la punta de la cola, que sube por el lado derecho.
	{
		"....AAAAAABBBB..",
		"..AAAAAAAABBOBB.",
		".AAAA.....BBB...",
		"AAA..........AAA",
		"AAA..........AAA",
		".AAAA......AAAA.",
		"..AAAAAAAAAAAA..",
		"....AAAAAAAA....",
	},
	-- Quetzal de perfil: pico, cresta, cuerpo y cola larga.
	{
		"..BBB...........",
		".BBOBB..........",
		"OBBBBAAA........",
		"..BAAAAAAA......",
		"..AAAAAAAA......",
		"...AAAAAAAAA....",
		"....AAAAAA.AAA..",
		"......O.O....AAA",
	},
	-- Águila de frente: alas abiertas con las plumas de las puntas, cabeza clara y hueco oscuro entre ala y cuerpo.
	{
		".A............A.",
		"AAA...BBBB...AAA",
		"AAAA.BBOOBB.AAAA",
		"AAAAA.BBBB.AAAAA",
		".AAAAAABBAAAAAA.",
		"..AAAAABBAAAAA..",
		"...A.A.BB.A.A...",
		"....A..AA..A....",
	},
}
local RELIEF_COLS, RELIEF_ROWS = 16, 8
-- Sol del Jaguar (5 × 5) y serpiente de plumas del Quetzal (7 × 5): emblema sobre la puerta de cada templo.
local SUN = { "Y.R.Y", ".RYR.", "RYYYR", ".RYR.", "Y.R.Y" }
local SERPENT = { ".JKJ...", "J...J..", ".KJJ.JY", "J...JKY", ".JKJ..." }

-- Cuenta las piezas de una carpeta.
function CourtDecor.count(folder: Instance): number
	local total = VoxelMerge.count(folder)
	return total
end

-- Pinta una imagen de casillas: une las casillas iguales y seguidas de cada fila en una sola caja. "place"
-- devuelve los límites de la caja de las columnas [c1, c2) y las filas [r1, r2) (empiezan en 0, la fila 0 es la
-- de arriba).
type Placer = (c1: number, c2: number, r1: number, r2: number) -> { number }

local function paintGrid(
	parent: Instance,
	kit: Kit,
	name: string,
	rows: { string },
	palette: { [string]: Color3 },
	place: Placer
)
	for r, line in rows do
		local c = 1
		local n = #line
		while c <= n do
			local ch = string.sub(line, c, c)
			local e = c
			while e < n and string.sub(line, e + 1, e + 1) == ch do
				e += 1
			end
			local color = palette[ch]
			if color then
				kit.deco(parent, name, place(c - 1, e, r - 1, r), color, kit.Paint)
			end
			c = e + 1
		end
	end
end

-- Los dos colores de un equipo: Jaguar rojo y amarillo; Quetzal, jade y negro.
local function teamColors(kit: Kit, sign: number): (Color3, Color3)
	if sign < 0 then
		return kit.RED, kit.YELLOW
	end
	return kit.JADE, kit.BLACK
end

-- ============================================================================ Templos

-- Un templo en pirámide tras la cabecera de su equipo. "sign" es el signo de X del equipo.
local function buildTemple(parent: Folder, kit: Kit, sign: number)
	local colorA, colorB = teamColors(kit, sign)
	local model = Instance.new("Folder")
	model.Name = `Templo_{if sign < 0 then "Jaguar" else "Quetzal"}`
	-- Caja con X en valor absoluto (el signo del equipo se aplica aquí).
	local function bx(x1: number, x2: number, y1: number, y2: number, z1: number, z2: number): { number }
		return { sign * x1, sign * x2, y1, y2, z1, z2 }
	end

	-- Terrazas: STUCCO y el color del equipo alternados. Los lados de la escalinata son las propias terrazas (a modo
	-- de barandilla); la parte central empieza en la pared del santuario.
	for k = 0, TERRACES - 1 do
		local f = TEMPLE_FRONT_X + FRONT_SETBACK * k
		local b = TEMPLE_BACK_X - BACK_SETBACK * k
		local y1 = 30 + TERRACE_HEIGHT * k
		local y2 = y1 + TERRACE_HEIGHT
		local hz = TEMPLE_HALF_Z - SIDE_SETBACK * k
		local color = if k % 2 == 0 then colorA else kit.STUCCO
		local pieces = {
			bx(f, b, y1, y2, STAIR_HALF_Z, hz),
			bx(f, b, y1, y2, -hz, -STAIR_HALF_Z),
			bx(STAIR_BACK_X, b, y1, y2, -STAIR_HALF_Z, STAIR_HALF_Z),
		}
		for _, bounds in pieces do
			local part = kit.solid(model, "Terraza", bounds, color, kit.Limestone)
			part.CanQuery = false
			part.CanTouch = false
		end
		-- Banda fina de colorB en el borde de arriba de cada cara (la de delante, a los lados de la escalinata).
		local yb1, yb2 = y1 + TERRACE_HEIGHT - 1.4, y1 + TERRACE_HEIGHT - 0.4
		kit.deco(model, "Banda", bx(f - 0.3, f, yb1, yb2, STAIR_HALF_Z + 0.6, hz), colorB, kit.Paint)
		kit.deco(model, "Banda", bx(f - 0.3, f, yb1, yb2, -hz, -STAIR_HALF_Z - 0.6), colorB, kit.Paint)
		kit.deco(model, "Banda", bx(f, b, yb1, yb2, hz, hz + 0.3), colorB, kit.Paint)
		kit.deco(model, "Banda", bx(f, b, yb1, yb2, -hz - 0.3, -hz), colorB, kit.Paint)
		kit.deco(model, "Banda", bx(b, b + 0.3, yb1, yb2, -hz, hz), colorB, kit.Paint)
		-- Escalera de servicio por detrás: dos peldaños por terraza, de 5 de ancho.
		kit.deco(model, "Servicio", bx(b, b + 0.8, y1, y1 + 3.5, -2.5, 2.5), kit.STONE_DARK, kit.Limestone)
		kit.deco(model, "Servicio", bx(b, b + 0.4, y1 + 3.5, y2, -2.5, 2.5), kit.STONE_DARK, kit.Limestone)
	end

	-- Escalinata central: 35 peldaños de 1 de alto que se apoyan unos en otros (cada losa llega hasta la pared del
	-- santuario). Un peldaño de cada siete, de colorB.
	for i = 1, TERRACES * TERRACE_HEIGHT do
		local front = STAIR_FRONT_X + STAIR_RUN * (i - 1)
		local color = if i % TERRACE_HEIGHT == 0 then colorB else kit.STONE
		kit.deco(
			model,
			"Peldano",
			bx(front, STAIR_BACK_X, 29 + i, 30 + i, -STAIR_HALF_Z, STAIR_HALF_Z),
			color,
			kit.Limestone
		)
	end

	-- Santuario sobre la plataforma de arriba: puerta oscura de 5 × 8 hacia la cancha.
	local top = 30 + TERRACE_HEIGHT * TERRACES
	local roof = top + SANCT_HEIGHT
	kit.deco(
		model,
		"Santuario",
		bx(SANCT_FRONT_X, SANCT_BACK_X, top, roof, -SANCT_HALF_Z, SANCT_HALF_Z),
		kit.STUCCO,
		kit.Limestone
	)
	kit.deco(model, "Puerta", bx(SANCT_FRONT_X - 0.3, SANCT_FRONT_X, top, top + 8, -2.5, 2.5), kit.BLACK, kit.Paint)
	for _, zSign in { -1, 1 } do
		kit.deco(
			model,
			"Jamba",
			bx(SANCT_FRONT_X - 0.4, SANCT_FRONT_X, top, top + 8.8, zSign * 2.5, zSign * 3.6),
			colorA,
			kit.Paint
		)
	end
	kit.deco(model, "Dintel", bx(SANCT_FRONT_X - 0.4, SANCT_FRONT_X, top + 8, top + 8.8, -3.6, 3.6), colorB, kit.Paint)
	-- Banda de colorB alrededor del santuario (por detrás también) y un nicho oscuro en la pared de atrás.
	local by1, by2 = roof - 2.4, roof - 1.2
	kit.deco(
		model,
		"Banda",
		bx(SANCT_FRONT_X - 0.3, SANCT_FRONT_X, by1, by2, -SANCT_HALF_Z - 0.3, SANCT_HALF_Z + 0.3),
		colorB,
		kit.Paint
	)
	kit.deco(
		model,
		"Banda",
		bx(SANCT_BACK_X, SANCT_BACK_X + 0.3, by1, by2, -SANCT_HALF_Z - 0.3, SANCT_HALF_Z + 0.3),
		colorB,
		kit.Paint
	)
	for _, zSign in { -1, 1 } do
		kit.deco(
			model,
			"Banda",
			bx(SANCT_FRONT_X, SANCT_BACK_X, by1, by2, zSign * SANCT_HALF_Z, zSign * (SANCT_HALF_Z + 0.3)),
			colorB,
			kit.Paint
		)
	end
	kit.deco(model, "Nicho", bx(SANCT_BACK_X, SANCT_BACK_X + 0.3, top + 3, top + 8, -2.5, 2.5), kit.BLACK, kit.Paint)
	-- Techo y crestería de 9 con muescas (cuatro dientes) sobre la puerta.
	kit.deco(
		model,
		"Techo",
		bx(SANCT_FRONT_X - 0.6, SANCT_BACK_X + 0.6, roof, roof + 1, -SANCT_HALF_Z - 0.6, SANCT_HALF_Z + 0.6),
		colorA,
		kit.Paint
	)
	kit.deco(model, "Cresteria", bx(COMB_X1, COMB_X2, roof + 1, roof + 7, -8, 8), kit.STUCCO, kit.Limestone)
	for _, zc in { -6.6, -2.2, 2.2, 6.6 } do
		kit.deco(model, "Diente", bx(COMB_X1, COMB_X2, roof + 7, roof + 9, zc - 1.2, zc + 1.2), colorA, kit.Paint)
	end
	-- Emblema sobre la puerta: el sol (Jaguar) o la serpiente de plumas (Quetzal), de casillas de 1, en la cara de
	-- delante de la crestería, que ve quien mira al templo desde la cancha (a su derecha cae el +Z del lado Quetzal
	-- y el -Z del Jaguar).
	local emblem = if sign < 0 then SUN else SERPENT
	local cell = 1
	local cols = #emblem[1]
	local palette = if sign < 0
		then { Y = kit.YELLOW, R = kit.RED }
		else { J = kit.JADE, K = kit.BLACK, Y = kit.YELLOW }
	paintGrid(model, kit, "Emblema", emblem, palette, function(c1, c2, r1, r2)
		return {
			sign * (COMB_X1 - 0.3),
			sign * COMB_X1,
			roof + 6.5 - r2 * cell,
			roof + 6.5 - r1 * cell,
			sign * (c1 - cols / 2) * cell,
			sign * (c2 - cols / 2) * cell,
		}
	end)

	-- Cuatro braseros en las esquinas de la plataforma, con una llama de Neon.
	local fx1, fx2 = TEMPLE_FRONT_X + FRONT_SETBACK * (TERRACES - 1), TEMPLE_BACK_X - BACK_SETBACK * (TERRACES - 1)
	local fz = TEMPLE_HALF_Z - SIDE_SETBACK * (TERRACES - 1)
	for _, x in { fx1 + 1.4, fx2 - 1.4 } do
		for _, z in { -fz + 1.4, fz - 1.4 } do
			kit.deco(
				model,
				"Brasero",
				bx(x - 0.8, x + 0.8, top, top + 1.6, z - 0.8, z + 0.8),
				kit.STONE_DARK,
				kit.Limestone
			)
			kit.deco(
				model,
				"Llama",
				bx(x - 0.6, x + 0.6, top + 1.6, top + 2.8, z - 0.6, z + 0.6),
				FIRE,
				Enum.Material.Neon
			)
		end
	end
	model.Parent = parent
end

-- ============================================================================ Estandartes e ídolos

-- Un estandarte: asta de madera de 18, travesaño, paño de 5 × 10 de colorA con franja de colorB y tres plumas en lo alto.
local function buildBanner(parent: Folder, kit: Kit, sign: number, x: number, z: number)
	local colorA, colorB = teamColors(kit, sign)
	local wood = Color3.fromRGB(112, 80, 52)
	local cx = sign * x
	local function box(dx: number, y1: number, y2: number, dz: number, name: string, color: Color3, mat: Enum.Material)
		kit.deco(parent, name, { cx - dx, cx + dx, y1, y2, z - dz, z + dz }, color, mat)
	end
	box(0.4, 30, 48, 0.4, "Asta", wood, kit.Paint)
	box(0.4, 46.4, 47.2, 3, "Travesano", wood, kit.Paint)
	box(0.15, 36.4, 46.4, 2.5, "Estandarte", colorA, kit.Paint)
	box(0.2, 40, 41.6, 2.5, "Franja", colorB, kit.Paint)
	-- Remate de tres plumas: jade, amarillo y teja.
	local plumes = { { -1.1, kit.JADE, 2.2 }, { 0, kit.YELLOW, 3 }, { 1.1, kit.RED, 2.2 } }
	for _, plume in plumes do
		local dz, color, height = plume[1] :: number, plume[2] :: Color3, plume[3] :: number
		kit.deco(
			parent,
			"Penacho",
			{ cx - 0.25, cx + 0.25, 48, 48 + height, z + dz - 0.25, z + dz + 0.25 },
			color,
			kit.Paint
		)
	end
end

-- Ídolo/máscara de piedra de 6 × 7 × 5 a cada lado de la escalera, con ojos y boca oscuros y tocado de plumas.
local function buildIdol(parent: Folder, kit: Kit, sign: number, zSign: number)
	local colorA, colorB = teamColors(kit, sign)
	local zc = zSign * IDOL_Z
	local xf = sign * IDOL_X1 -- la cara, hacia la cancha
	local function onFace(depth: number, y1: number, y2: number, dz1: number, dz2: number): { number }
		return { xf, xf - sign * depth, y1, y2, zc + dz1, zc + dz2 }
	end
	kit.deco(parent, "Idolo", { sign * IDOL_X1, sign * IDOL_X2, 30, 37, zc - 3, zc + 3 }, kit.STONE_DARK, kit.Limestone)
	kit.deco(parent, "IdoloCeja", onFace(0.4, 34.4, 35.3, -3, 3), colorB, kit.Paint)
	kit.deco(parent, "IdoloOjo", onFace(0.4, 35.3, 36.4, -2.2, -1), kit.BLACK, kit.Paint)
	kit.deco(parent, "IdoloOjo", onFace(0.4, 35.3, 36.4, 1, 2.2), kit.BLACK, kit.Paint)
	kit.deco(parent, "IdoloNariz", onFace(0.7, 32.8, 35, -0.6, 0.6), kit.STONE, kit.Limestone)
	kit.deco(parent, "IdoloBoca", onFace(0.4, 31, 32.2, -1.8, 1.8), kit.BLACK, kit.Paint)
	-- Tocado: una cinta y tres plumas.
	kit.deco(parent, "IdoloTocado", { sign * IDOL_X1, sign * IDOL_X2, 37, 38, zc - 3, zc + 3 }, colorB, kit.Paint)
	local colors = { colorA, kit.YELLOW, colorA }
	for index, dz in { -2, 0, 2 } do
		local height = if index == 2 then 3.6 else 2.6
		kit.deco(
			parent,
			"IdoloPenacho",
			{ sign * (IDOL_X1 + 1), sign * (IDOL_X2 - 1), 38, 38 + height, zc + dz - 0.6, zc + dz + 0.6 },
			colors[index],
			kit.Paint
		)
	end
end

-- ============================================================================ Lo estático

-- Lo que no depende del formato: Cancha.Decor con los templos, los estandartes y los ídolos de los dos extremos.
function CourtDecor.buildStatic(folder: Folder, kit: Kit)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	for _, sign in { -1, 1 } do
		buildTemple(decor, kit, sign)
		for _, row in BANNER_ROWS do
			for _, z in row.zs do
				buildBanner(decor, kit, sign, row.x, z)
			end
		end
		for _, zSign in { -1, 1 } do
			buildIdol(decor, kit, sign, zSign)
		end
	end
	CourtDecor.lastStatic = VoxelMerge.mergeStatic(decor, MERGE_OPTIONS)
	decor.Parent = folder
end

-- ============================================================================ Lo que depende del formato

-- Paleta de un relieve: A y B son los colores principales del lado; z positivo los cambia entre sí; O es el contorno.
local function reliefPalette(kit: Kit, xSign: number, zSign: number): { [string]: Color3 }
	local a, b = if xSign < 0 then kit.RED else kit.JADE, kit.YELLOW
	if zSign > 0 then
		a, b = b, a
	end
	return { A = a, B = b, O = kit.STUCCO }
end

-- Paneles de animales en el paramento (cara hacia el pasillo), a ambos lados del aro y a lo largo de X.
local function buildWallReliefs(parent: Folder, kit: Kit, geo: CourtGeometry.Layout)
	local face = CourtGeometry.TALUD_OUTER_Z
	local hl = geo.halfLength
	for _, zSign in { -1, 1 } do
		-- Quien mira la pared desde el pasillo tiene a su derecha el +X (pared -Z) o el -X (pared +Z).
		local dir = if zSign < 0 then 1 else -1
		for _, xSign in { -1, 1 } do
			for slot, cx in RELIEF_CENTERS do
				if cx + RELIEF_COLS / 2 <= hl - 1 then
					local center = xSign * cx
					local kind = (slot - 1 + (if xSign > 0 then 1 else 0) + (if zSign > 0 then 2 else 0)) % #ANIMALS + 1
					kit.deco(parent, "ReliveFondo", {
						center - RELIEF_COLS / 2,
						center + RELIEF_COLS / 2,
						RELIEF_TOP - RELIEF_ROWS,
						RELIEF_TOP,
						zSign * (face - 0.15),
						zSign * face,
					}, RELIEF_BACK, kit.Paint)
					paintGrid(
						parent,
						kit,
						"Relieve",
						ANIMALS[kind],
						reliefPalette(kit, xSign, zSign),
						function(c1, c2, r1, r2)
							return {
								center + dir * (c1 - RELIEF_COLS / 2),
								center + dir * (c2 - RELIEF_COLS / 2),
								RELIEF_TOP - r2,
								RELIEF_TOP - r1,
								zSign * (face - 0.15),
								zSign * (face - 0.45),
							}
						end
					)
				end
			end
		end
	end
end

-- Relieve grande (casillas de 1,5: 24 × 12) a cada lado del emblema de la cara de dentro del muro del fondo de cada
-- cabecera.
local function buildHeaderReliefs(parent: Folder, kit: Kit, geo: CourtGeometry.Layout)
	local face = geo.halfLength + CourtGeometry.HEADER_DEPTH
	local cell = 1.5
	for _, sign in { -1, 1 } do
		local kinds = if sign < 0 then { 1, 4 } else { 3, 2 } -- Jaguar y águila; quetzal y serpiente
		local x1 = sign * face
		for index, zc in { -26, 26 } do
			local a, b = teamColors(kit, sign)
			if index == 2 then
				a, b = kit.YELLOW, a
			elseif sign > 0 then
				b = kit.YELLOW
			end
			local palette = { A = a, B = b, O = kit.STUCCO }
			kit.deco(parent, "ReliveFondo", { x1 - sign * 0.2, x1, 8, 20, zc - 12, zc + 12 }, RELIEF_BACK, kit.Paint)
			-- Mirando hacia el fondo de la cabecera, a la derecha cae el +Z (equipo Quetzal) o el -Z (Jaguar).
			paintGrid(parent, kit, "Relieve", ANIMALS[kinds[index]], palette, function(c1, c2, r1, r2)
				return {
					x1 - sign * 0.2,
					x1 - sign * 0.6,
					20 - r2 * cell,
					20 - r1 * cell,
					zc + sign * (c1 - RELIEF_COLS / 2) * cell,
					zc + sign * (c2 - RELIEF_COLS / 2) * cell,
				}
			end)
		end
	end
end

-- Greca de la cornisa: una caja pequeña cada GRECA_STEP studs sobre la moldura, del color del lado.
local function buildCorniceGreca(parent: Folder, kit: Kit, geo: CourtGeometry.Layout)
	local face = CourtGeometry.TALUD_OUTER_Z
	local top = CourtGeometry.WALL_TOP_Y + 0.6
	local hl = geo.halfLength
	for _, zSign in { -1, 1 } do
		local x = -(hl - 1.5)
		while x <= hl - 1.5 + 0.01 do
			local color = if x < 0 then kit.RED else kit.JADE
			kit.deco(
				parent,
				"Almenilla",
				{ x - 0.6, x + 0.6, top, top + 1, zSign * face, zSign * (face + 0.8) },
				color,
				kit.Paint
			)
			x += GRECA_STEP
		end
	end
end

-- Una media fila de torsos (de x = a a x = b): una caja larga por tramo de color y, a veces, un pañuelo.
local function torsoRun(
	parent: Folder,
	kit: Kit,
	rng: Random,
	a: number,
	b: number,
	y: number,
	z1: number,
	z2: number,
	colors: { Color3 }
)
	local lengths = { 6, 8, 9, 12 }
	local x = a
	local turn = rng:NextInteger(1, #colors)
	while x < b - 0.01 do
		local scarf = rng:NextNumber() < 0.14
		local length = if scarf then 3 else lengths[rng:NextInteger(1, #lengths)]
		local x2 = math.min(x + length, b)
		local color = if scarf then kit.BLUE else colors[turn]
		kit.deco(parent, "Torso", { x, x2, y, y + 1.6, z1, z2 }, color, kit.Paint)
		if not scarf then
			turn = turn % #colors + 1
		end
		x = x2
	end
end

-- Gradas con público: tres gradas escalonadas hacia atrás a cada lado, y en cada una una fila de espectadores
-- que mira a la cancha. El lado X < 0 viste rojo y amarillo; el X > 0, jade y negro. Determinista (semilla fija).
-- Cada cabeza es un solo cubo de piel, sobre el tramo de torso de su fila (los torsos cubren toda la fila).
local function buildStands(parent: Folder, kit: Kit, geo: CourtGeometry.Layout)
	local hl = geo.halfLength
	local rng = Random.new(2704)
	for _, zSign in { -1, 1 } do
		for tier = 1, STAND_TIERS do
			local near = STAND_Z1 + STAND_DEPTH * (tier - 1)
			local topY = 30 + STAND_RISE * tier
			kit.deco(
				parent,
				"Grada",
				{ -(hl - 1), hl - 1, 30, topY, zSign * near, zSign * (near + STAND_DEPTH) },
				if tier % 2 == 1 then kit.STONE else kit.STONE_DARK,
				kit.Limestone
			)
			-- La persona se sienta en el centro de la grada: torso de 1,4 de fondo y cabeza de 1.
			local tz1, tz2 = zSign * (near + 1.3), zSign * (near + 2.7)
			torsoRun(parent, kit, rng, -(hl - 2), 0, topY, tz1, tz2, { kit.RED, kit.YELLOW })
			torsoRun(parent, kit, rng, 0, hl - 2, topY, tz1, tz2, { kit.JADE, kit.BLACK })
			local x = -(hl - 3) + (tier % 2) * HEAD_STEP / 2
			while x <= hl - 3 do
				local skin = SKINS[rng:NextInteger(1, #SKINS)]
				local hz1, hz2 = zSign * (near + 1.5), zSign * (near + 2.5)
				kit.deco(parent, "Cabeza", { x - 0.5, x + 0.5, topY + 1.6, topY + 2.6, hz1, hz2 }, skin, kit.Paint)
				x += HEAD_STEP
			end
		end
	end
end

-- Lo que depende del formato: Cancha.Court.Decor.Extras con relieves, greca de la cornisa y gradas.
function CourtDecor.buildLayout(art: Folder, geo: CourtGeometry.Layout, kit: Kit)
	local extras = Instance.new("Folder")
	extras.Name = "Extras"
	buildWallReliefs(extras, kit, geo)
	buildHeaderReliefs(extras, kit, geo)
	buildCorniceGreca(extras, kit, geo)
	buildStands(extras, kit, geo)
	CourtDecor.lastLayout = VoxelMerge.mergeStatic(extras, MERGE_OPTIONS)
	extras.Parent = art
end

return CourtDecor
