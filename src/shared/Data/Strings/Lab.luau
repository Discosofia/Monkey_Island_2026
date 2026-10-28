--!strict
-- Inglés del Laboratorio en ruinas (Fase 13: src/laboratorio, Data/LabWeapons y lo suyo del combate
-- compartido), revisado a mano. Nace con T() (GDD §18): cada grupo de la fase añade aquí lo suyo.
-- ["texto español"] = "English text". La clave es el texto exacto que se pasa a Strings.t (o que marca
-- Strings.later, o que manda el servidor por Notify), con los mismos argumentos {x}. tools/strings.py
-- avisa de lo que falta o sobra.

return {
	-- Las cuatro armas (Data/LabWeapons): nombre y descripción.
	["Lanzadardos tranquilizante"] = "Tranquilizer Dart Gun",
	["Automática de media distancia. Cada dardo ralentiza un poco más."] = "Mid-range automatic. Each dart slows a little more.",
	["Rifle de bananas primales"] = "Primal Banana Rifle",
	["Precisión a larga distancia. Mantén apuntado para acercar la vista."] = "Long-range precision. Hold aim to zoom in.",
	["Lanzarredes de arpón"] = "Harpoon Net Launcher",
	["Corta distancia. El impacto enreda y frena al que se acerca."] = "Close range. The hit tangles and slows anyone who gets close.",
	["Cañón de suero ácido"] = "Acid Serum Cannon",
	["Dispara en arco por encima de las coberturas. Estalla y envenena en un área."] = "Lobs shots over cover. Bursts and poisons an area.",

	-- Botón táctil de la mira del rifle (CombatClient/WeaponController).
	["Mira"] = "Scope",
}
