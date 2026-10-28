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

	-- Duelo por equipos (L2): bandos, fases, HUD, selector de arma y avisos del servidor.
	["Piratas"] = "Pirates",
	["Guardianes"] = "Guardians",
	["Elige tu arma y pulsa «Listo» · {time}"] = "Pick your weapon and press “Ready” · {time}",
	["Elige tu arma y pulsa «Listo»"] = "Pick your weapon and press “Ready”",
	["⚔️ El duelo empieza en {seconds}"] = "⚔️ The duel starts in {seconds}",
	["⚡ ¡Muerte súbita! La siguiente baja gana"] = "⚡ Sudden death! The next takedown wins",
	["⚡ ¡Empate! Muerte súbita: la siguiente baja gana"] = "⚡ Tied! Sudden death: the next takedown wins",
	["🏆 ¡Gana el bando {icon} {name}!"] = "🏆 {icon} {name} win!",
	["Gana el primero a {kills} bajas"] = "First to {kills} takedowns wins",
	["Ctrl: soltar el ratón"] = "Ctrl: free the mouse",
	["Ctrl: volver a apuntar"] = "Ctrl: back to aiming",
	["Elige tu arma"] = "Pick your weapon",
	["Cambiar de arma"] = "Change weapon",
	["Daño {damage} · cada {seconds} s · {range} studs"] = "Damage {damage} · every {seconds} s · {range} studs",
	["Listos: {ready} de {total}"] = "Ready: {ready} of {total}",
	["Reapareces con ella en {seconds}"] = "You respawn with it in {seconds}",
	["↩️ No estoy listo"] = "↩️ Not ready",
	["⚔️ ¡Que empiece el duelo! Gana el primer bando en llegar a {kills} bajas"] = "⚔️ Let the duel begin! First side to {kills} takedowns wins",
	["No llegó el otro bando: vuelven al Lobby"] = "The other side didn't arrive: back to the Lobby",
	["Un bando se ha quedado vacío: se espera a más jugadores"] = "A side is empty: waiting for more players",
	["🧪 Falta el otro bando: usa el panel de pruebas para empezar solo"] = "🧪 The other side is missing: use the test panel to start alone",
	["👥 Formato {n}v{n}"] = "👥 Format {n}v{n}",
}
