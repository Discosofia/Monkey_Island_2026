--!strict
-- Construye las armas y herramientas como Tools de Roblox (greybox): aparecen en la mochila nativa, que ya
-- funciona como barra rápida en PC (teclas 1-9), móvil (casillas táctiles) y mando.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local WOOD = Color3.fromRGB(110, 72, 40)
local LEATHER = Color3.fromRGB(60, 40, 25)
local STEEL = Color3.fromRGB(140, 146, 152)
local STEEL_DARK = Color3.fromRGB(85, 90, 96)
local STEEL_EDGE = Color3.fromRGB(215, 220, 226)
local STONE = Color3.fromRGB(120, 120, 125)
local STONE_DARK = Color3.fromRGB(85, 85, 90)
local FIBER = Color3.fromRGB(150, 135, 85)
local FANG = Color3.fromRGB(235, 225, 195)
local FUR = Color3.fromRGB(150, 70, 45)
local DARK_BARK = Color3.fromRGB(75, 48, 28)
local LIGHT_WOOD = Color3.fromRGB(175, 130, 80)
local USE_SOUNDS = {
	Melee = "rbxasset://sounds/swordslash.wav",
	Ranged = "rbxasset://sounds/swordlunge.wav",
}

local WeaponTools = {}

local function newPiece(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	className: string?
): BasePart
	local piece = Instance.new(className or "Part") :: BasePart
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.Massless = true
	return piece
end

-- Suelda una pieza decorativa al mango, colocada respecto a él.
local function attach(handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = handle.Parent
end

-- Hacha: cabeza afilada atada a un mango; el filo mira hacia delante (-Z).
local function buildAxe(tool: Tool, headColor: Color3, edgeColor: Color3, material: Enum.Material): BasePart
	local shaft = newPiece("Handle", Vector3.new(0.3, 3, 0.3), WOOD, Enum.Material.Wood)
	shaft.Parent = tool
	attach(shaft, newPiece("Head", Vector3.new(0.35, 0.9, 0.9), headColor, material), CFrame.new(0, 1.15, -0.45))
	attach(shaft, newPiece("Edge", Vector3.new(0.25, 1.1, 0.3), edgeColor, material), CFrame.new(0, 1.15, -0.95))
	for _, y in { 0.95, 1.35 } do
		attach(
			shaft,
			newPiece("Lashing", Vector3.new(0.4, 0.12, 0.4), FIBER, Enum.Material.Fabric),
			CFrame.new(0, y, 0)
		)
	end
	tool.Grip = CFrame.new(0, -1, 0)
	return shaft
end

-- Pico: una pieza larga atravesada, con las dos puntas en cuña.
local function buildPick(tool: Tool, headColor: Color3, pointColor: Color3, material: Enum.Material): BasePart
	local shaft = newPiece("Handle", Vector3.new(0.3, 3, 0.3), WOOD, Enum.Material.Wood)
	shaft.Parent = tool
	attach(shaft, newPiece("Head", Vector3.new(0.35, 0.4, 1.6), headColor, material), CFrame.new(0, 1.3, 0))
	for side = -1, 1, 2 do
		-- La cuña se estrecha hacia su -Z local: se gira para que cada punta mire hacia fuera.
		attach(
			shaft,
			newPiece("Point", Vector3.new(0.35, 0.4, 0.7), pointColor, material, "WedgePart"),
			CFrame.new(0, 1.3, side * 1.15) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
		)
	end
	attach(shaft, newPiece("Lashing", Vector3.new(0.4, 0.5, 0.4), FIBER, Enum.Material.Fabric), CFrame.new(0, 1.3, 0))
	tool.Grip = CFrame.new(0, -1, 0)
	return shaft
end

-- La pieza "Handle" apunta hacia delante (eje Y) al sujetarla; Grip marca dónde va la mano.
-- Machete: la hoja es fina en X y ancha en Z; los detalles se ven desde los lados planos.
local BUILDERS: { [string]: (tool: Tool) -> BasePart } = {
	Machete = function(tool)
		local blade = newPiece("Handle", Vector3.new(0.12, 2.6, 0.75), STEEL, Enum.Material.Metal)
		blade.Reflectance = 0.15
		blade.Parent = tool

		-- Punta en ángulo: una cuña al final de la hoja.
		attach(
			blade,
			newPiece("Tip", Vector3.new(0.12, 0.8, 0.75), STEEL, Enum.Material.Metal, "WedgePart"),
			CFrame.new(0, 1.7, 0)
		)
		-- Filo brillante en un borde, lomo oscuro en el otro y acanaladura a lo largo.
		local edge = newPiece("Edge", Vector3.new(0.13, 2.6, 0.1), STEEL_EDGE, Enum.Material.SmoothPlastic)
		edge.Reflectance = 0.35
		attach(blade, edge, CFrame.new(0, 0, -0.33))
		attach(
			blade,
			newPiece("Spine", Vector3.new(0.16, 2.6, 0.09), STEEL_DARK, Enum.Material.Metal),
			CFrame.new(0, 0, 0.33)
		)
		attach(
			blade,
			newPiece("Fuller", Vector3.new(0.14, 1.9, 0.07), STEEL_DARK, Enum.Material.Metal),
			CFrame.new(0, -0.25, 0.14)
		)

		-- Guarda, empuñadura de madera con dos vueltas de cuero, remaches y pomo.
		attach(
			blade,
			newPiece("Guard", Vector3.new(0.3, 0.15, 0.9), STEEL_DARK, Enum.Material.Metal),
			CFrame.new(0, -1.38, 0)
		)
		attach(blade, newPiece("Grip", Vector3.new(0.34, 1.2, 0.42), WOOD, Enum.Material.Wood), CFrame.new(0, -2.05, 0))
		for _, y in { -1.65, -2.45 } do
			attach(
				blade,
				newPiece("Wrap", Vector3.new(0.38, 0.12, 0.46), LEATHER, Enum.Material.Fabric),
				CFrame.new(0, y, 0)
			)
		end
		for _, y in { -1.9, -2.2 } do
			local rivet = newPiece("Rivet", Vector3.new(0.4, 0.12, 0.12), STEEL_EDGE, Enum.Material.Metal) :: Part
			rivet.Shape = Enum.PartType.Cylinder
			attach(blade, rivet, CFrame.new(0, y, 0))
		end
		attach(
			blade,
			newPiece("Pommel", Vector3.new(0.38, 0.2, 0.48), STEEL_DARK, Enum.Material.Metal),
			CFrame.new(0, -2.75, 0)
		)

		tool.Grip = CFrame.new(0, -2.05, 0)
		return blade
	end,
	Honda = function(tool)
		local stem = newPiece("Handle", Vector3.new(0.4, 1.6, 0.4), WOOD, Enum.Material.Wood)
		stem.Parent = tool
		for side = -1, 1, 2 do
			attach(
				stem,
				newPiece("Prong", Vector3.new(0.3, 1.2, 0.3), WOOD, Enum.Material.Wood),
				CFrame.new(side * 0.35, 1.2, 0) * CFrame.Angles(0, 0, -side * math.rad(20))
			)
		end
		attach(
			stem,
			newPiece("Band", Vector3.new(0.95, 0.12, 0.12), Color3.fromRGB(40, 30, 25), Enum.Material.Fabric),
			CFrame.new(0, 1.75, 0)
		)
		tool.Grip = CFrame.new(0, -0.4, 0)
		return stem
	end,
	Torch = function(tool)
		local stick = newPiece("Handle", Vector3.new(0.35, 2.6, 0.35), WOOD, Enum.Material.Wood)
		stick.Parent = tool
		local head = newPiece("Head", Vector3.new(0.6, 0.8, 0.6), LEATHER, Enum.Material.Fabric)
		attach(stick, head, CFrame.new(0, 1.5, 0))
		attach(stick, newPiece("Wrap", Vector3.new(0.45, 0.15, 0.45), FIBER, Enum.Material.Fabric), CFrame.new(0, 1, 0))
		-- El fuego y la luz solo existen en el mundo mientras la llevas en la mano.
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = head
		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Shadows = true
		light.Parent = head
		tool.Grip = CFrame.new(0, -0.6, 0)
		return stick
	end,
	WoodenAxe = function(tool)
		return buildAxe(tool, LIGHT_WOOD, DARK_BARK, Enum.Material.Wood)
	end,
	StoneAxe = function(tool)
		return buildAxe(tool, STONE, STONE_DARK, Enum.Material.Slate)
	end,
	WoodenPick = function(tool)
		return buildPick(tool, LIGHT_WOOD, DARK_BARK, Enum.Material.Wood)
	end,
	StonePick = function(tool)
		return buildPick(tool, STONE, STONE_DARK, Enum.Material.Slate)
	end,
	-- Lanza: asta larga con un colmillo atado en la punta.
	Spear = function(tool)
		local shaft = newPiece("Handle", Vector3.new(0.25, 6, 0.25), WOOD, Enum.Material.Wood)
		shaft.Parent = tool
		attach(
			shaft,
			newPiece("Tip", Vector3.new(0.2, 0.45, 1), FANG, Enum.Material.SmoothPlastic, "WedgePart"),
			-- Girada para que la parte fina de la cuña (su -Z) apunte hacia arriba.
			CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(90), 0, 0)
		)
		attach(
			shaft,
			newPiece("Lashing", Vector3.new(0.35, 0.4, 0.35), FIBER, Enum.Material.Fabric),
			CFrame.new(0, 2.85, 0)
		)
		attach(shaft, newPiece("Fur", Vector3.new(0.4, 0.3, 0.4), FUR, Enum.Material.Fabric), CFrame.new(0, 2.5, 0))
		tool.Grip = CFrame.new(0, -1.2, 0)
		return shaft
	end,
	-- Garrote: mango fino y cabeza gruesa con colmillos clavados.
	Club = function(tool)
		local grip = newPiece("Handle", Vector3.new(0.35, 2.4, 0.35), WOOD, Enum.Material.Wood)
		grip.Parent = tool
		local head = newPiece("Head", Vector3.new(0.9, 2.8, 0.9), WOOD, Enum.Material.Wood)
		attach(grip, head, CFrame.new(0, 2.4, 0))
		attach(grip, newPiece("Cap", Vector3.new(1, 0.3, 1), DARK_BARK, Enum.Material.Wood), CFrame.new(0, 3.85, 0))
		attach(grip, newPiece("Wrap", Vector3.new(0.4, 0.9, 0.4), FUR, Enum.Material.Fabric), CFrame.new(0, -0.6, 0))
		-- Tres anillos de colmillos, cada uno girado respecto al anterior.
		for ring, y in { 1.6, 2.4, 3.2 } do
			for i = 0, 5 do
				local angle = i * math.pi / 3 + ring * math.pi / 6
				attach(
					grip,
					newPiece("Fang", Vector3.new(0.18, 0.18, 0.5), FANG, Enum.Material.SmoothPlastic, "WedgePart"),
					CFrame.new(0, y, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.65)
				)
			end
		end
		tool.Grip = CFrame.new(0, -0.6, 0)
		return grip
	end,
}

-- El machete afilado usa el mismo modelo que el machete; la honda de liana, el de la honda.
BUILDERS.SharpMachete = BUILDERS.Machete
BUILDERS.LianaSling = BUILDERS.Honda
BUILDERS.BigFangClub = BUILDERS.Club
-- Fase 4: hacha y pico de hueso.
local BONE = Color3.fromRGB(230, 220, 195)
local BONE_DARK = Color3.fromRGB(190, 175, 145)
BUILDERS.BoneAxe = function(tool)
	return buildAxe(tool, BONE, BONE_DARK, Enum.Material.SmoothPlastic)
end
BUILDERS.BonePick = function(tool)
	return buildPick(tool, BONE, BONE_DARK, Enum.Material.SmoothPlastic)
end

function WeaponTools.build(weaponId: string): Tool
	local weapon = Weapons[weaponId]
	local builder = BUILDERS[weaponId]
	assert(weapon and builder, `Arma desconocida: {weaponId}`)

	local tool = Instance.new("Tool")
	tool.Name = weapon.name
	tool.ToolTip = `{weapon.name}: {weapon.damage} de daño`
	if weapon.tool then
		tool.ToolTip ..= if weapon.tool.kind == "Axe" then " · golpea árboles" else " · golpea rocas"
	end
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weaponId)

	local handle = builder(tool)
	local sound = Instance.new("Sound")
	sound.Name = "UseSound"
	sound.SoundId = USE_SOUNDS[weapon.kind]
	sound.Volume = 0.6
	sound.Parent = handle
	return tool
end

-- Sonido de uso, audible para todos. La animación del tajo la reproduce el cliente
-- (WeaponController) para que responda al instante.
function WeaponTools.playUse(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	local sound = if handle then handle:FindFirstChild("UseSound") else nil
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

return WeaponTools
