--!strict
-- Animaciones de las armas (R15). Las genera en Studio el generador
-- ServerStorage.Tools.WeaponAnimationBuilder (en ReplicatedStorage.WeaponAnimations) y se publican
-- con clic derecho > "Save to Roblox"; su id se pega aquí ("rbxassetid://…"). Deben publicarse con
-- el mismo dueño que el juego (tu cuenta o el grupo) o no cargarán en el juego publicado.
-- Mientras un id esté vacío, en Studio se usa la secuencia generada (id temporal) y fuera de Studio
-- no se reproduce nada.
--   - Hold: con un arma a distancia en la mano, el brazo derecho cuelga junto al cuerpo (en bucle).
--   - Stone, Arrow, Spell, Dart: el disparo de cada tipo de arma ("projectile" en Data/Weapons).
--     "fxDelay": segundos hasta el marcador "Disparo", cuando salen la bocanada de la cerbatana o el
--     destello del bastón (AbilityFxController, efecto "WeaponShotFx").
--   - LabRifle, LabHarpoon, LabCannon, LabDart: el disparo del rifle, el lanzarredes, el cañón y el
--     lanzadardos del Laboratorio (Data/LabWeapons "pose"; Fase 15, V9). Mientras el id de LabDart esté
--     vacío fuera de Studio, el lanzadardos usa Dart (Data/WeaponAim.Fallback).
--   - AimStone, AimBow, AimSpell, AimBlowgun, AimDartGun, AimRifle, AimHarpoon, AimCannon: la pose de
--     apuntar de cada arma a distancia (en bucle, Fase 19, W2). Se mantiene mientras está equipada, salvo
--     corriendo (entonces vuelve a Hold). Qué pista es de cada disparo: Data/WeaponAim.AimOf. Mientras su
--     id esté vacío fuera de Studio, el brazo cuelga con Hold.
--   - Slash1–Slash4: los tajos de la cadena de golpes cuerpo a cuerpo (Shared/MeleeChain). Mientras su
--     id esté vacío, fuera de Studio se usa el tajo de Roblox.
--   - Guard: la pose de guardia (en bucle, Fase 10, C5; GuardController): los antebrazos delante de la
--     cara con el arma cruzada. Mientras su id esté vacío, fuera de Studio no hay pose (la guardia
--     funciona igual).

export type WeaponAnimation = { id: string, fxDelay: number? }

local WeaponAnimations: { [string]: WeaponAnimation } = {
	Hold = { id = "rbxassetid://138421282182628" },
	Stone = { id = "rbxassetid://92805362685076", fxDelay = 0.14 },
	Arrow = { id = "rbxassetid://103739018270171", fxDelay = 0.16 },
	Spell = { id = "rbxassetid://116426291827005", fxDelay = 0.12 },
	Dart = { id = "rbxassetid://104985681187504", fxDelay = 0.16 },
	LabRifle = { id = "rbxassetid://117986048889758", fxDelay = 0.1 },
	LabHarpoon = { id = "rbxassetid://99581314656449", fxDelay = 0.1 },
	LabCannon = { id = "rbxassetid://125505030931037", fxDelay = 0.12 },
	LabDart = { id = "", fxDelay = 0.05 },
	AimStone = { id = "" },
	AimBow = { id = "" },
	AimSpell = { id = "" },
	AimBlowgun = { id = "" },
	AimDartGun = { id = "" },
	AimRifle = { id = "" },
	AimHarpoon = { id = "" },
	AimCannon = { id = "" },
	Slash1 = { id = "rbxassetid://77898233432926" },
	Slash2 = { id = "rbxassetid://120859937990073" },
	Slash3 = { id = "rbxassetid://90979498051114" },
	Slash4 = { id = "rbxassetid://84709619605184" },
	Guard = { id = "rbxassetid://75420437779908" },
}

return WeaponAnimations
