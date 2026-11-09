--!strict
-- Qué pista de apuntar (Aim*, en Data/WeaponAnimations) sostiene cada tipo de arma a distancia mientras
-- está equipada, y qué disparo sustituye a otro mientras el suyo no esté publicado. La clave del disparo es
-- "lab.pose" en las armas del Laboratorio y "projectile" en las demás.

local WeaponAim = {}

-- Disparo → pista de apuntar.
WeaponAim.AimOf = {
	Stone = "AimStone",
	Arrow = "AimBow",
	Spell = "AimSpell",
	Dart = "AimBlowgun",
	LabDart = "AimDartGun",
	LabRifle = "AimRifle",
	LabHarpoon = "AimHarpoon",
	LabCannon = "AimCannon",
} :: { [string]: string }

-- Armas del Laboratorio (Fase 25, G11): disparo → pista que suena en vez de Hold al correr (arma a dos manos
-- bajada) y pista de recargar (se estira a "reloadSeconds"). Las demás armas siguen con Hold y sin recarga.
WeaponAim.RunOf = {
	LabDart = "RunDartGun",
	LabRifle = "RunRifle",
	LabHarpoon = "RunHarpoon",
	LabCannon = "RunCannon",
} :: { [string]: string }

WeaponAim.ReloadOf = {
	LabDart = "ReloadDartGun",
	LabRifle = "ReloadRifle",
	LabHarpoon = "ReloadHarpoon",
	LabCannon = "ReloadCannon",
} :: { [string]: string }

-- Disparo sin id (fuera de Studio) → el disparo que se usa en su lugar.
WeaponAim.Fallback = {
	LabDart = "Dart",
} :: { [string]: string }

return WeaponAim
