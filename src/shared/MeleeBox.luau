--!strict
-- Zona del golpe cuerpo a cuerpo, delante del personaje. La usan el servidor (CombatService.meleeAttack)
-- y el cliente (WeaponController, para el parón de impacto), así que las dos calculan lo mismo.
-- Crece con el tamaño del personaje (el gigante del administrador, a escala 2,5, tiene la raíz a unos
-- 7 studs del suelo: con la caja de tamaño normal solo le llegaba a la cabeza al rival). A escala 1 es la
-- caja de siempre: 7 de ancho, 6 de alto y "range" de largo.
local MeleeBox = {}

local WIDTH = 7
local HEIGHT = 6

-- La caja (CFrame y tamaño) del golpe de un arma de alcance "range". El alcance también crece con la
-- escala, porque empieza en el centro del cuerpo y el cuerpo ya ocupa parte de él.
function MeleeBox.compute(character: Model, root: BasePart, range: number): (CFrame, Vector3)
	local scale = math.max(1, character:GetScale())
	local length = range * scale
	return root.CFrame * CFrame.new(0, 0, -length / 2), Vector3.new(WIDTH * scale, HEIGHT * scale, length)
end

return MeleeBox
