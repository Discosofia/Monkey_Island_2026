--!strict
-- Dibuja el "¡puf!" de caricatura que pide el servidor (Combat/Poof): una nube de humo claro con
-- estrellas. Se hace en el cliente porque las partículas que suelta el servidor en una pieza recién
-- creada no siempre llegan a verse (sobre todo con StreamingEnabled).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local STAR_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_COLOR = Color3.fromRGB(255, 248, 230)
local STAR_COLOR = Color3.fromRGB(255, 225, 80)
local LIFETIME = 0.9

local PoofController = {}

local function emitter(texture: string, color: Color3, size: NumberSequence, speed: number): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = texture
	particles.Color = ColorSequence.new(color)
	particles.Size = size
	particles.Transparency = NumberSequence.new(0, 1)
	particles.Lifetime = NumberRange.new(LIFETIME * 0.6, LIFETIME)
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Drag = 4
	particles.Rate = 0
	return particles
end

local function burst(position: Vector3, size: number)
	local anchor = Instance.new("Attachment")
	anchor.Name = "Poof"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position

	local smoke = emitter(SMOKE_TEXTURE, SMOKE_COLOR, NumberSequence.new(size * 0.5, size * 1.1), size * 2)
	smoke.Parent = anchor
	smoke:Emit(math.clamp(math.round(size * 3), 10, 40))

	local stars = emitter(STAR_TEXTURE, STAR_COLOR, NumberSequence.new(size * 0.25, 0), size * 4)
	stars.LightEmission = 1
	stars.Parent = anchor
	stars:Emit(math.clamp(math.round(size * 2), 6, 24))

	Debris:AddItem(anchor, LIFETIME + 0.5)
end

function PoofController:Start()
	Remotes.Poof.OnClientEvent:Connect(function(position: any, size: any)
		if typeof(position) == "Vector3" and typeof(size) == "number" then
			burst(position, size)
		end
	end)
end

return PoofController
