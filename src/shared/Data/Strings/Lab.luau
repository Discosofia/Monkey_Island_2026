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

	-- Modos Todos contra todos y Rondas (L4a): formato, avisos del servidor y panel de pruebas.
	["{n} jugadores"] = "{n} players",
	["👥 Formato {n} jugadores"] = "👥 Format {n} players",
	["⚔️ ¡Todos contra todos! Gana el primero en llegar a {kills} bajas"] = "⚔️ Free for all! First to {kills} takedowns wins",
	["🏆 ¡Gana {name}!"] = "🏆 {name} wins!",
	["No llegaron jugadores suficientes: vuelven al Lobby"] = "Not enough players arrived: back to the Lobby",
	["Faltan jugadores: se espera a más"] = "Players missing: waiting for more",
	["🧪 Faltan jugadores: usa el panel de pruebas para empezar solo"] = "🧪 Players missing: use the test panel to start alone",
	["⚔️ ¡Que empiecen las rondas! Gana el primer bando en llegar a {rounds} rondas"] = "⚔️ Let the rounds begin! First side to {rounds} rounds wins",
	["⚔️ ¡Ronda {round}!"] = "⚔️ Round {round}!",
	["⚡ ¡Ronda decisiva! La gana quien la gane"] = "⚡ Deciding round! Whoever wins it wins the match",
	["⚡ ¡Empate a rondas! La siguiente ronda decide"] = "⚡ Tied on rounds! The next round decides",
	["Ronda {round} para {icon} {name}"] = "Round {round} goes to {icon} {name}",
	["Ronda {round} nula: nadie la gana"] = "Round {round} is void: nobody wins it",
	["🔔 ¡Alarma! Todos quedan a la vista"] = "🔔 Alarm! Everyone is in plain sight",
	["🔀 ¡Cambio de lado! Cada bando pasa a la base contraria"] = "🔀 Switch sides! Each side moves to the opposite base",
	["🎮 Modo: {name}"] = "🎮 Mode: {name}",
	["🎮 El modo solo se cambia en la espera o en los resultados"] = "🎮 The mode can only change while waiting or on the results",

	-- Cliente de los modos nuevos (L4a): marcador, línea de la fase, espectador y resultados.
	["Tú {n}"] = "You {n}",
	["🥇 {n}"] = "🥇 {n}",
	["Gana el primero a {kills} bajas · vas {place}.º"] = "First to {kills} takedowns wins · you are #{place}",
	["Ronda {round} · gana el primero a {rounds}"] = "Round {round} · first to {rounds} wins",
	["🧍 En pie: {a} · {b}"] = "🧍 Standing: {a} · {b}",
	["🔔 Alarma en {seconds}"] = "🔔 Alarm in {seconds}",
	["🔔 ¡Alarma! Todos se ven a través de las paredes"] = "🔔 Alarm! Everyone shows through the walls",
	["Ronda {round} en {seconds} · puedes cambiar de arma"] = "Round {round} in {seconds} · you can change weapon",
	["Ronda {round} en {seconds}"] = "Round {round} in {seconds}",
	["💀 Eliminado: vuelves en la siguiente ronda"] = "💀 Knocked out: you return next round",
	["Viendo a {name}"] = "Watching {name}",
	["Ningún compañero en pie"] = "No teammate standing",
	["Puesto {place} de {total}"] = "Place {place} of {total}",
	["🥇 {name} · {kills} bajas"] = "🥇 {name} · {kills} takedowns",

	-- Mapas (L4b): nombres y alcance (Config.Lab.MapNames y MapRanges) y la caída al vacío.
	["Laboratorio central"] = "Central Lab",
	["Azotea de la torre"] = "Tower Rooftop",
	["Alcantarillas"] = "Sewers",
	["Media distancia"] = "Mid range",
	["Larga distancia"] = "Long range",
	["Corta distancia"] = "Short range",
	["🪂 {attacker} tira a {victim} al vacío"] = "🪂 {attacker} knocks {victim} off the edge",
	["🏙️ El mapa solo se cambia en la espera o en los resultados"] = "🏙️ The map can only change while waiting or on the results screen",
	["🏙️ Solo hay un mapa"] = "🏙️ There is only one map",
	["🏙️ Mapa: {name}"] = "🏙️ Map: {name}",
	-- Votación del mapa (LabVoteService y LabMapVoteController).
	["🗳️ Vota el mapa"] = "🗳️ Vote for the map",
	["Se cierra en {seconds}"] = "Closes in {seconds}",
	["Votos: {n}"] = "Votes: {n}",
	["✅ Tu voto"] = "✅ Your vote",
	["🗳️ Mapa: {name}"] = "🗳️ Map: {name}",
	-- Recompensas (L5a): misión semanal y títulos de Data/Cosmetics.
	["Gana {target} partidas en el Laboratorio en ruinas"] = "Win {target} matches in the Ruined Laboratory",
	["Gana 50 partidas en el Laboratorio"] = "Win 50 matches in the Laboratory",
	["Título: Saqueador del PRIMAL"] = "Title: PRIMAL Plunderer",
	["Solo para quien ha ganado 50 partidas con los Piratas en el Laboratorio en ruinas."] = "Only for those who have won 50 matches with the Pirates in the Ruined Laboratory.",
	["⚓ Saqueador del PRIMAL"] = "⚓ PRIMAL Plunderer",
	["Título: Guardián del Suero"] = "Title: Serum Guardian",
	["Solo para quien ha ganado 50 partidas con los Guardianes en el Laboratorio en ruinas."] = "Only for those who have won 50 matches with the Guardians in the Ruined Laboratory.",
	["🧬 Guardián del Suero"] = "🧬 Serum Guardian",
}
