--!strict
-- Coberturas que se rompen (Fase 10, C11): los modelos del mundo con la etiqueta
-- Config.Combat.DestructibleTag (hoy, las estelas y columnas de la arena de Dunas). El combate solo dice
-- qué las alcanza y con qué; cuánto les quita, cuándo caen y cuándo vuelven lo decide el place que las
-- tiene (Dunas: Services/CoverService, con Destructibles.onHit). Sin modelos con la etiqueta (Isla,
-- Lobby), todo esto no hace nada.
-- Lo que las alcanza (Kind):
--   "Ability"       una habilidad de daño: su área (blast) o el proyectil que se para en ella (hitPart)
--   "Ultimate"      lo mismo con una definitiva (V)
--   "Finisher"      el remate de la cadena de golpes: su caja (inBox)
--   "ShotFinisher"  el disparo de remate de un arma a distancia (y la explosión del del bastón)
-- Los golpes normales del arma no las rompen. Cada uso alcanza una vez a cada cobertura: quien llama
-- pasa la misma tabla "once" a todas las consultas de ese uso (las flechas del abanico, cada vuelta
-- del Torbellino).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Hitbox = require(script.Parent.Hitbox)

local TAG = Config.Combat.DestructibleTag

export type Kind = "Ability" | "Ultimate" | "Finisher" | "ShotFinisher"
export type Once = { [Model]: boolean }

local Destructibles = {}

local listeners: { (model: Model, kind: Kind, attacker: Player, at: Vector3) -> () } = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

-- Llama a "callback" cada vez que algo alcanza una cobertura (el place decide qué le hace).
function Destructibles.onHit(callback: (model: Model, kind: Kind, attacker: Player, at: Vector3) -> ())
	table.insert(listeners, callback)
end

-- La cobertura a la que pertenece "part", o nil.
function Destructibles.modelOf(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, TAG) then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function hit(model: Model, kind: Kind, attacker: Player, at: Vector3, once: Once?)
	if once then
		if once[model] then
			return
		end
		once[model] = true
	end
	for _, listener in listeners do
		task.spawn(listener, model, kind, attacker, at)
	end
end

-- Las coberturas con alguna pieza que choca (las rotas no chocan) entre las piezas de "parts".
local function coversIn(parts: { BasePart }): { Model }
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in parts do
		local model = if part.CanCollide then Destructibles.modelOf(part) else nil
		if model and not seen[model] then
			seen[model] = true
			table.insert(found, model)
		end
	end
	return found
end

local function prepared(): boolean
	if #listeners == 0 then
		return false
	end
	local tagged = CollectionService:GetTagged(TAG)
	if #tagged == 0 then
		return false
	end
	overlapParams.FilterDescendantsInstances = tagged
	return true
end

-- true si desde "from" no hay otra cosa antes que "model" de camino a su centro: lo de detrás de una
-- pared (u otra cobertura) no se rompe.
local function inSight(from: Vector3, model: Model): boolean
	local center = model:GetBoundingBox().Position
	local result = Hitbox.ray(from, center - from)
	return result == nil or result.Instance:IsDescendantOf(model)
end

-- Un proyectil que se ha parado en "part" (el mundo que ha tocado): si es una cobertura, la alcanza.
function Destructibles.hitPart(part: Instance, kind: Kind, attacker: Player, at: Vector3, once: Once?)
	if #listeners == 0 then
		return
	end
	local model = Destructibles.modelOf(part)
	if model then
		hit(model, kind, attacker, at, once)
	end
end

-- Un área: las coberturas con alguna pieza a menos de "radius" de "center", si se ven desde "from" (por
-- defecto, el centro).
function Destructibles.blast(center: Vector3, radius: number, kind: Kind, attacker: Player, once: Once?, from: Vector3?)
	if not prepared() then
		return
	end
	for _, model in coversIn(Workspace:GetPartBoundsInRadius(center, radius, overlapParams)) do
		if inSight(from or center, model) then
			hit(model, kind, attacker, center, once)
		end
	end
end

-- Una caja (el remate de la cadena): las coberturas con alguna pieza dentro que se ven desde "from".
function Destructibles.inBox(cframe: CFrame, size: Vector3, kind: Kind, attacker: Player, from: Vector3, once: Once?)
	if not prepared() then
		return
	end
	for _, model in coversIn(Workspace:GetPartBoundsInBox(cframe, size, overlapParams)) do
		if inSight(from, model) then
			hit(model, kind, attacker, cframe.Position, once)
		end
	end
end

return Destructibles
