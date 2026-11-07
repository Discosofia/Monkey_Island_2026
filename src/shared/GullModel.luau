--!strict
-- Gaviota voxel (Fase 25, G6a): las seis que vuelan alrededor del barco en la escena «Shipwreck».
--   GullModel.build(options?)  devuelve (modelo, articulaciones). El modelo mira hacia -Z, con el pivote en el centro del
--                              cuerpo. PrimaryPart = "Cuerpo". Todo va soldado al cuerpo, sin anclar y sin colisión: quien
--                              lo use ancla el cuerpo y lo coloca con PivotTo.
--   GullModel.pose(joints, flap) aletea: flap en radianes (positivo = puntas de las alas arriba). Las alas son Weld cuyo C0
--                              se recalcula, así se ve igual en modo edición que en Play.
-- Diez piezas: cuerpo, cabeza, pico, dos ojos, cola, dos alas (gris claro) y sus dos puntas (negras).
-- Opción glow: de noche el cuerpo y la cabeza son Neon apagado (un blanco azulado) para que se distingan del cielo.

local WHITE = Color3.fromRGB(240, 240, 236)
local GLOW_WHITE = Color3.fromRGB(205, 212, 226)
local WING_GREY = Color3.fromRGB(184, 190, 198)
local WING_TIP = Color3.fromRGB(28, 28, 32)
local BEAK = Color3.fromRGB(245, 200, 50)
local BLACK = Color3.fromRGB(15, 15, 18)

local SHOULDER = Vector3.new(0.7, 0.35, -0.2) -- unión del ala con el cuerpo (el lado lo da el signo de x)
local INNER_LENGTH = 2.6
local TIP_LENGTH = 1.8
local TIP_BEND = 0.8 -- fracción del aleteo que dobla la punta respecto al ala

export type Joint = { weld: Weld, base: CFrame, side: number, bend: number }
export type Joints = { Joint }

local GullModel = {}

function GullModel.build(options: { glow: boolean? }?): (Model, Joints)
	local glow = options ~= nil and options.glow == true
	local model = Instance.new("Model")
	model.Name = "Gull"

	local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.Parent = model
		return part
	end

	local bodyMaterial = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local bodyColor = if glow then GLOW_WHITE else WHITE
	local body = newPart("Cuerpo", Vector3.new(1.5, 1.1, 3), CFrame.new(), bodyColor, bodyMaterial)
	body.Massless = false
	model.PrimaryPart = body

	local function weld(part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Weld
		local joint = Instance.new("Weld")
		joint.Part0 = part0
		joint.Part1 = part1
		joint.C0 = c0
		joint.C1 = c1
		joint.Parent = part1
		return joint
	end

	-- Piezas fijas: se sueldan donde están.
	local function fixed(part: Part)
		weld(body, part, body.CFrame:ToObjectSpace(part.CFrame), CFrame.identity)
	end
	fixed(newPart("Cabeza", Vector3.new(0.9, 0.9, 1), CFrame.new(0, 0.5, -1.9), bodyColor, bodyMaterial))
	fixed(newPart("Pico", Vector3.new(0.3, 0.25, 0.8), CFrame.new(0, 0.38, -2.8), BEAK, Enum.Material.SmoothPlastic))
	fixed(
		newPart("Ojo", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.46, 0.66, -2.2), BLACK, Enum.Material.SmoothPlastic)
	)
	fixed(
		newPart("Ojo", Vector3.new(0.12, 0.12, 0.12), CFrame.new(-0.46, 0.66, -2.2), BLACK, Enum.Material.SmoothPlastic)
	)
	fixed(newPart("Cola", Vector3.new(1.1, 0.15, 1.3), CFrame.new(0, 0.1, 2.1), WING_GREY, Enum.Material.SmoothPlastic))

	-- Alas: el ala interior cuelga del cuerpo y la punta del ala interior.
	local joints: Joints = {}
	for _, side in { -1, 1 } do
		local wing = newPart(
			"Ala",
			Vector3.new(INNER_LENGTH, 0.18, 1.7),
			CFrame.new(SHOULDER.X * side + side * INNER_LENGTH / 2, SHOULDER.Y, SHOULDER.Z),
			WING_GREY,
			Enum.Material.SmoothPlastic
		)
		local base = CFrame.new(side * SHOULDER.X, SHOULDER.Y, SHOULDER.Z)
		local shoulder = weld(body, wing, base, CFrame.new(-side * INNER_LENGTH / 2, 0, 0))
		table.insert(joints, { weld = shoulder, base = base, side = side, bend = 0 })

		local tip = newPart(
			"Punta",
			Vector3.new(TIP_LENGTH, 0.15, 1.2),
			wing.CFrame * CFrame.new(side * (INNER_LENGTH + TIP_LENGTH) / 2, 0, 0.2),
			WING_TIP,
			Enum.Material.SmoothPlastic
		)
		local tipBase = CFrame.new(side * INNER_LENGTH / 2, 0, 0.2)
		local elbow = weld(wing, tip, tipBase, CFrame.new(-side * TIP_LENGTH / 2, 0, 0))
		table.insert(joints, { weld = elbow, base = tipBase, side = side, bend = TIP_BEND })
	end

	return model, joints
end

-- Aleteo: cada articulación gira alrededor del eje Z (el del avance). El ala interior sigue "flap" y la punta, ya
-- sobre el ala, dobla TIP_BEND de él.
function GullModel.pose(joints: Joints, flap: number)
	for _, joint in joints do
		if joint.weld.Parent then
			local factor = if joint.bend > 0 then joint.bend else 1
			joint.weld.C0 = joint.base * CFrame.Angles(0, 0, joint.side * flap * factor)
		end
	end
end

return GullModel
