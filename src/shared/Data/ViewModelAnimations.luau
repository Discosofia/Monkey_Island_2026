--!strict
-- Animaciones de los brazos en primera persona del Laboratorio (Fase 19, W10; Shared/LabViewModelRig,
-- laboratorio/client/Controllers/FirstPersonController). Una por arma y clave, sobre el reposo «de cadera» del rig.
-- Las genera island/tools/ViewModelAnimationBuilder (ReplicatedStorage.ViewModelAnimations, secuencias
-- "<arma>_<clave>"); las publica el usuario (clic derecho > Save to Roblox) y el id se pega aquí.
-- Mientras un id esté vacío (nil): en Studio se usa la secuencia generada (CombatClient/ViewModelAnimationIds) y,
-- fuera de Studio o sin secuencia, FirstPersonController mantiene el movimiento por código de siempre.
--   Aim: bucle de apuntar (su peso es WeaponController.aimAlpha()) · Fire: un disparo · Reload: la recarga (se
--   estira a lo que dura la real) · Sprint: bucle al correr · Equip: sacar el arma.

local KEYS = { "Aim", "Fire", "Reload", "Sprint", "Equip" }

-- Lo que dura la secuencia Reload (s); FirstPersonController la estira a Data/LabWeapons "reloadSeconds".
local RELOAD_LENGTH = 1

local ids: { [string]: { [string]: string? } } = {
	LabDartGun = {
		Aim = "rbxassetid://112779066511655",
		Fire = "rbxassetid://135222799594303",
		Reload = "rbxassetid://114777574890379",
		Sprint = "rbxassetid://103620379482717",
		Equip = "rbxassetid://123848286864775",
	},
	LabBananaRifle = {
		Aim = "rbxassetid://139063756727909",
		Fire = "rbxassetid://71108009898737",
		Reload = "rbxassetid://83711503307926",
		Sprint = "rbxassetid://73485805248202",
		Equip = "rbxassetid://108721417112473",
	},
	LabNetHarpoon = {
		Aim = "rbxassetid://87586149680383",
		Fire = "rbxassetid://121826246853896",
		Reload = "rbxassetid://131471456251297",
		Sprint = "rbxassetid://122798235115772",
		Equip = "rbxassetid://107665350431114",
	},
	LabAcidCannon = {
		Aim = "rbxassetid://134656855233839",
		Fire = "rbxassetid://128222821413650",
		Reload = "rbxassetid://84422912919265",
		Sprint = "rbxassetid://114717454736112",
		Equip = "rbxassetid://78242403248535",
	},
}

return {
	KEYS = KEYS,
	RELOAD_LENGTH = RELOAD_LENGTH,
	ids = ids,
}
