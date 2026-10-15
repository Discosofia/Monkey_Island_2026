--!strict
-- Animaciones de las armas a distancia (R15). Las genera en Studio el generador
-- ServerStorage.Tools.WeaponAnimationBuilder (en ReplicatedStorage.WeaponAnimations) y se publican
-- con clic derecho > "Save to Roblox"; su id se pega aquí ("rbxassetid://…"). Deben publicarse con
-- el mismo dueño que el juego (tu cuenta o el grupo) o no cargarán en el juego publicado.
-- Mientras un id esté vacío, en Studio se usa la secuencia generada (id temporal) y fuera de Studio
-- no se reproduce nada.
--   - Hold: con un arma a distancia en la mano, el brazo derecho cuelga junto al cuerpo (en bucle).
--   - Stone, Arrow, Spell, Dart: el disparo de cada tipo de arma ("projectile" en Data/Weapons).
--     "fxDelay": segundos hasta el marcador "Disparo", cuando salen la bocanada de la cerbatana o el
--     destello del bastón (AbilityFxController, efecto "WeaponShotFx").

export type WeaponAnimation = { id: string, fxDelay: number? }

local WeaponAnimations: { [string]: WeaponAnimation } = {
	Hold = { id = "rbxassetid://138421282182628" },
	Stone = { id = "rbxassetid://92805362685076", fxDelay = 0.14 },
	Arrow = { id = "rbxassetid://103739018270171", fxDelay = 0.16 },
	Spell = { id = "rbxassetid://116426291827005", fxDelay = 0.12 },
	Dart = { id = "rbxassetid://104985681187504", fxDelay = 0.16 },
}

return WeaponAnimations
