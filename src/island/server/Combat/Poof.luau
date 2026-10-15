--!strict
-- "¡Puf!" de caricatura al derrotar un mono, un jefe o un muñeco de práctica: una nube de humo claro con
-- estrellas que tapa el cuerpo mientras desaparece. Sustituye a la animación de muerte para que el
-- combate se vea irreal y apto para todas las edades (cuestionario de madurez: violencia leve).
-- El servidor manda dónde y de qué tamaño; las partículas las dibuja cada cliente (PoofController).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

-- Segundos que tarda el cuerpo en volverse invisible detrás del humo.
local HIDE_SECONDS = 0.25
-- Tamaño mínimo de la nube (studs), para que se vea bien también con los monos pequeños.
local MIN_SIZE = 4

local Poof = {}

-- Nube de humo con estrellas en "position". "size" es el tamaño aproximado de lo que desaparece (studs).
function Poof.burst(position: Vector3, size: number)
	Remotes.Poof:FireAllClients(position, math.max(size, MIN_SIZE))
	Sfx.play("Poof", position)
end

-- "¡Puf!" sobre un modelo: lo deja quieto, lo vuelve invisible tras el humo y lo borra.
function Poof.vanish(model: Model)
	local cframe, extents = model:GetBoundingBox()
	Poof.burst(cframe.Position, math.max(extents.X, extents.Y, extents.Z))
	local hide = TweenInfo.new(HIDE_SECONDS)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			if part.Transparency < 1 then
				TweenService:Create(part, hide, { Transparency = 1 }):Play()
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			TweenService:Create(part, hide, { Transparency = 1 }):Play()
		elseif part:IsA("ParticleEmitter") or part:IsA("Light") or part:IsA("BillboardGui") then
			part.Enabled = false
		end
	end
	Debris:AddItem(model, HIDE_SECONDS + 0.1)
end

return Poof
