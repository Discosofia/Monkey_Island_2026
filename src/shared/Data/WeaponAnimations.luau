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
--   - LabRifle, LabHarpoon, LabCannon: el disparo del rifle, el lanzarredes y el cañón del Laboratorio
--     (Data/LabWeapons "pose"; Fase 15, V9). El lanzadardos usa Dart.
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
	Slash1 = { id = "rbxassetid://77898233432926" },
	Slash2 = { id = "rbxassetid://120859937990073" },
	Slash3 = { id = "rbxassetid://90979498051114" },
	Slash4 = { id = "rbxassetid://84709619605184" },
	Guard = { id = "rbxassetid://75420437779908" },
}

return WeaponAnimations
