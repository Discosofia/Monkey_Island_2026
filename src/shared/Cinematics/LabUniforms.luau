--!strict
-- Los trajes de los dos bandos del Laboratorio en las cinemáticas (Fase 25, G13). LabUniforms.wear(rig, faction) viste a un
-- rig R15 (un maniquí o la copia del avatar) con el traje de su bando, para que se distingan de lejos y de espaldas:
--   Guardians  bata blanca con solapa y cruz azul (también a la espalda), pantalón azul oscuro y gafas de laboratorio.
--   Pirates    chaleco y mangas oscuras con la banda dorada cruzada, hombreras doradas, pañuelo dorado en la cabeza, parche
--              en el ojo y calavera blanca a la espalda.
-- Los colores salen de Config.Lab.Teams (azul de los Guardianes, dorado de los Piratas). Nada verde ni morado ni rojo
-- (están reservados a la curación, el veneno y el daño recibido). Se pintan las piezas del cuerpo (se quitan la camiseta,
-- el pantalón y las texturas del cuerpo, que taparían el color) y se sueldan piezas pequeñas, sin colisión, que siguen las
-- animaciones. Las manos y la cara se quedan con el color de piel.

local Config = require(script.Parent.Parent.Config)

local LabUniforms = {}

type Palette = { torso: Color3, arms: Color3, legs: Color3, boots: Color3 }

local PALETTES: { [string]: Palette } = {
	Guardians = {
		torso = Color3.fromRGB(240, 243, 248),
		arms = Color3.fromRGB(240, 243, 248),
		legs = Color3.fromRGB(40, 58, 96),
		boots = Color3.fromRGB(30, 38, 58),
	},
	Pirates = {
		torso = Color3.fromRGB(44, 36, 30),
		arms = Color3.fromRGB(52, 42, 34),
		legs = Color3.fromRGB(32, 28, 26),
		boots = Color3.fromRGB(22, 18, 16),
	},
}

local TORSO_PARTS = { "UpperTorso", "LowerTorso" }
local ARM_PARTS = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local LEG_PARTS = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local FOOT_PARTS = { "LeftFoot", "RightFoot" }

local WHITE = Color3.fromRGB(240, 243, 248)
local DARK = Color3.fromRGB(28, 24, 22)
local GOGGLE_LENS = Color3.fromRGB(120, 215, 255)

local function paint(rig: Model, names: { string }, color: Color3)
	for _, name in names do
		local part = rig:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
		end
	end
end

local function factionColor(faction: string): Color3
	local teams = (Config.Lab :: any).Teams
	local info = if teams then teams[faction] else nil
	return if info then info.color else Color3.fromRGB(200, 200, 200)
end

-- Una pieza pequeña soldada a `parent`, en `offset` (relativo a él).
local function piece(
	rig: Model,
	name: string,
	size: Vector3,
	color: Color3,
	parent: BasePart,
	offset: CFrame,
	material: Enum.Material?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
	part.Parent = rig
end

local function part(rig: Model, name: string): BasePart?
	local found = rig:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function wearGuardian(rig: Model, blue: Color3)
	local torso, lower, head = part(rig, "UpperTorso"), part(rig, "LowerTorso"), part(rig, "Head")
	if torso and lower then
		-- Faldones de la bata: dos delante y uno a la espalda, y la solapa y el cuello azules.
		piece(rig, "CoatBack", Vector3.new(1.9, 2.3, 0.2), WHITE, lower, CFrame.new(0, -0.9, 0.62), nil)
		piece(rig, "CoatFrontL", Vector3.new(0.75, 2.1, 0.2), WHITE, lower, CFrame.new(0.62, -0.85, -0.62), nil)
		piece(rig, "CoatFrontR", Vector3.new(0.75, 2.1, 0.2), WHITE, lower, CFrame.new(-0.62, -0.85, -0.62), nil)
		piece(rig, "CoatStripe", Vector3.new(0.22, 1.9, 0.12), blue, torso, CFrame.new(0, -0.2, -0.6), nil)
		piece(rig, "CoatCollar", Vector3.new(2.0, 0.3, 1.25), blue, torso, CFrame.new(0, 0.95, 0), nil)
		piece(rig, "Badge", Vector3.new(0.5, 0.5, 0.1), blue, torso, CFrame.new(0.55, 0.45, -0.6), nil)
		-- La cruz azul de la espalda.
		piece(rig, "CrossH", Vector3.new(1.0, 0.28, 0.08), blue, torso, CFrame.new(0, -0.1, 0.62), nil)
		piece(rig, "CrossV", Vector3.new(0.28, 1.0, 0.08), blue, torso, CFrame.new(0, -0.1, 0.62), nil)
	end
	if head then
		-- Gafas de laboratorio: goma oscura alrededor de la cabeza y dos cristales celestes.
		piece(rig, "GoggleBand", Vector3.new(1.3, 0.3, 1.3), DARK, head, CFrame.new(0, 0.2, 0), nil)
		piece(
			rig,
			"LensL",
			Vector3.new(0.38, 0.3, 0.1),
			GOGGLE_LENS,
			head,
			CFrame.new(0.3, 0.2, -0.63),
			Enum.Material.Neon
		)
		piece(
			rig,
			"LensR",
			Vector3.new(0.38, 0.3, 0.1),
			GOGGLE_LENS,
			head,
			CFrame.new(-0.3, 0.2, -0.63),
			Enum.Material.Neon
		)
	end
end

local function wearPirate(rig: Model, gold: Color3)
	local torso, lower, head = part(rig, "UpperTorso"), part(rig, "LowerTorso"), part(rig, "Head")
	if torso and lower then
		-- Banda dorada cruzada al pecho, cinturón y capa corta a la espalda con la calavera blanca.
		piece(
			rig,
			"Sash",
			Vector3.new(0.4, 2.5, 0.14),
			gold,
			torso,
			CFrame.new(0, -0.05, -0.6) * CFrame.Angles(0, 0, math.rad(35)),
			nil
		)
		piece(rig, "Belt", Vector3.new(2.0, 0.3, 1.25), gold, lower, CFrame.new(0, 0.1, 0), nil)
		piece(rig, "Cape", Vector3.new(1.9, 2.1, 0.18), DARK, torso, CFrame.new(0, -0.55, 0.62), nil)
		piece(rig, "CapeTrim", Vector3.new(1.9, 0.2, 0.2), gold, torso, CFrame.new(0, -1.55, 0.62), nil)
		piece(rig, "Skull", Vector3.new(0.9, 0.75, 0.08), WHITE, torso, CFrame.new(0, -0.15, 0.74), nil)
		piece(rig, "Jaw", Vector3.new(0.5, 0.25, 0.08), WHITE, torso, CFrame.new(0, -0.68, 0.74), nil)
		piece(rig, "EyeL", Vector3.new(0.2, 0.2, 0.1), DARK, torso, CFrame.new(0.2, -0.1, 0.77), nil)
		piece(rig, "EyeR", Vector3.new(0.2, 0.2, 0.1), DARK, torso, CFrame.new(-0.2, -0.1, 0.77), nil)
	end
	-- Hombreras doradas.
	for _, name in { "LeftUpperArm", "RightUpperArm" } do
		local arm = part(rig, name)
		if arm then
			piece(rig, "Pauldron", Vector3.new(1.3, 0.35, 1.3), gold, arm, CFrame.new(0, 0.5, 0), nil)
		end
	end
	if head then
		-- Pañuelo dorado con su nudo y las puntas a la espalda, y el parche en el ojo.
		piece(rig, "Bandana", Vector3.new(1.3, 0.4, 1.3), gold, head, CFrame.new(0, 0.42, 0), nil)
		piece(rig, "BandanaKnot", Vector3.new(0.4, 0.45, 0.35), gold, head, CFrame.new(0, 0.4, 0.68), nil)
		piece(rig, "BandanaTailL", Vector3.new(0.15, 0.7, 0.1), gold, head, CFrame.new(0.15, 0.0, 0.75), nil)
		piece(rig, "BandanaTailR", Vector3.new(0.15, 0.6, 0.1), gold, head, CFrame.new(-0.15, 0.05, 0.75), nil)
		piece(rig, "EyePatch", Vector3.new(0.38, 0.34, 0.08), DARK, head, CFrame.new(0.3, 0.1, -0.63), nil)
	end
end

-- Viste a `rig` con el traje de `faction` ("Guardians" | "Pirates"); otro valor no hace nada.
function LabUniforms.wear(rig: Model, faction: string?)
	local palette = if faction then PALETTES[faction] else nil
	if not (faction and palette) then
		return
	end
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Shirt") or descendant:IsA("Pants") or descendant:IsA("ShirtGraphic") then
			descendant:Destroy()
		end
	end
	paint(rig, TORSO_PARTS, palette.torso)
	paint(rig, ARM_PARTS, palette.arms)
	paint(rig, LEG_PARTS, palette.legs)
	paint(rig, FOOT_PARTS, palette.boots)
	local color = factionColor(faction)
	if faction == "Guardians" then
		wearGuardian(rig, color)
	else
		wearPirate(rig, color)
	end
end

return LabUniforms
