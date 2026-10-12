--!strict
-- Construye las armas como Tools de Roblox (greybox): aparecen en la mochila nativa, que ya
-- funciona como barra rápida en PC (teclas 1-9), móvil (casillas táctiles) y mando.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local WOOD = Color3.fromRGB(110, 72, 40)
local LEATHER = Color3.fromRGB(60, 40, 25)
local STEEL = Color3.fromRGB(140, 146, 152)
local STEEL_DARK = Color3.fromRGB(85, 90, 96)
local STEEL_EDGE = Color3.fromRGB(215, 220, 226)
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
}

function WeaponTools.build(weaponId: string): Tool
	local weapon = Weapons[weaponId]
	local builder = BUILDERS[weaponId]
	assert(weapon and builder, `Arma desconocida: {weaponId}`)

	local tool = Instance.new("Tool")
	tool.Name = weapon.name
	tool.ToolTip = `{weapon.name}: {weapon.damage} de daño`
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

-- Sonido y animación de uso (visibles para todos los jugadores).
function WeaponTools.playUse(tool: Tool, weapon: Weapons.WeaponDefinition)
	local handle = tool:FindFirstChild("Handle")
	local sound = if handle then handle:FindFirstChild("UseSound") else nil
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
	if weapon.kind == "Melee" then
		-- El script de animación estándar de Roblox reproduce el tajo al ver este valor.
		local animation = Instance.new("StringValue")
		animation.Name = "toolanim"
		animation.Value = "Slash"
		animation.Parent = tool
		Debris:AddItem(animation, 1)
	end
end

return WeaponTools
