--!strict
-- Construye las armas como Tools de Roblox (greybox): aparecen en la mochila nativa, que ya
-- funciona como barra rápida en PC (teclas 1-9), móvil (casillas táctiles) y mando.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local WOOD = Color3.fromRGB(110, 72, 40)
local METAL = Color3.fromRGB(170, 175, 180)
local USE_SOUNDS = {
	Melee = "rbxasset://sounds/swordslash.wav",
	Ranged = "rbxasset://sounds/swordlunge.wav",
}

local WeaponTools = {}

local function newPiece(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.Massless = true
	return piece
end

-- Suelda una pieza decorativa al mango, colocada respecto a él.
local function attach(handle: Part, piece: Part, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = handle.Parent
end

-- La pieza "Handle" apunta hacia delante (eje Y) al sujetarla; Grip marca dónde va la mano.
local BUILDERS: { [string]: (tool: Tool) -> Part } = {
	Machete = function(tool)
		local blade = newPiece("Handle", Vector3.new(0.35, 3.2, 0.7), METAL, Enum.Material.Metal)
		blade.Parent = tool
		attach(blade, newPiece("Hilt", Vector3.new(0.5, 1.2, 0.5), WOOD, Enum.Material.Wood), CFrame.new(0, -2.1, 0))
		tool.Grip = CFrame.new(0, -2.1, 0)
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
