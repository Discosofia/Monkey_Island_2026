--!strict
-- Modelo provisional de una mascota (Fase 5): cuerpo y cabeza redondos con su color y su emoji
-- encima. Lo crean los clientes (Lobby e Isla) para que siga a su dueño con suavidad.

local Pets = require(script.Parent.Data.Pets)

local PetModels = {}

local function ball(name: string, diameter: number, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * diameter
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function PetModels.build(petId: string): Model?
	local pet = Pets[petId]
	if not pet then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `Mascota_{petId}`
	local body = ball("Body", 1.2 * pet.size, pet.color, model)
	local head = ball("Head", 0.8 * pet.size, pet.color:Lerp(Color3.new(1, 1, 1), 0.15), model)
	head.CFrame = body.CFrame * CFrame.new(0, 0.6 * pet.size, -0.35 * pet.size)
	model.PrimaryPart = body
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(34, 34)
	billboard.StudsOffset = Vector3.new(0, 1.4 * pet.size, 0)
	billboard.MaxDistance = 80
	billboard.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = pet.icon
	label.TextScaled = true
	label.Parent = billboard
	return model
end

return PetModels
