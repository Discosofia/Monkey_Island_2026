--!strict
-- De dónde sale la bala propia (Fase 19, W4): CombatClient no puede requerir los controladores de un place,
-- así que el que dibuja el arma en la vista (el Laboratorio, FirstPersonController) registra aquí una
-- función que da la posición de su boca. Sin ella (o si da nil), WeaponController usa el arma de la mano.

local MuzzleSource = {}

local source: (() -> Vector3?)? = nil

function MuzzleSource.set(callback: () -> Vector3?)
	source = callback
end

-- La boca del arma de la vista, o nil si ningún place la registró o ahora no se ve.
function MuzzleSource.get(): Vector3?
	return if source then source() else nil
end

return MuzzleSource
