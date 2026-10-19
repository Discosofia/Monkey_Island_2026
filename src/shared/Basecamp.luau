--!strict
-- Vida del campamento (Basecamp): la escribe el servidor (BasecampService) como atributos de
-- ReplicatedStorage y cualquiera la lee (el HUD, los monos, el daño a los jugadores, la fabricación).
--   BasecampHealth / BasecampMaxHealth: vida actual y máxima.
--   BasecampFallen: true si ha caído (llegó a 0 y aún no se ha recuperado de día). Mientras tanto
--   no es zona segura y las estaciones no funcionan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Basecamp = {}

Basecamp.HEALTH = "BasecampHealth"
Basecamp.MAX_HEALTH = "BasecampMaxHealth"
Basecamp.FALLEN = "BasecampFallen"

function Basecamp.isFallen(): boolean
	return ReplicatedStorage:GetAttribute(Basecamp.FALLEN) == true
end

-- Vida actual y máxima (nil si el servidor aún no la ha publicado).
function Basecamp.health(): (number?, number?)
	local health = ReplicatedStorage:GetAttribute(Basecamp.HEALTH)
	local maxHealth = ReplicatedStorage:GetAttribute(Basecamp.MAX_HEALTH)
	if typeof(health) ~= "number" or typeof(maxHealth) ~= "number" then
		return nil, nil
	end
	return health, maxHealth
end

return Basecamp
