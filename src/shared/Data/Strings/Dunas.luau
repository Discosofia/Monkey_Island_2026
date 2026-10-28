--!strict
-- Inglés de la arena de Dunas (src/dunas) y del combate compartido (src/combat: avisos de las habilidades,
-- munición y muñecos de práctica), revisado a mano (tanda I1d, GDD §18).
-- ["texto español"] = "English text". La clave es el texto exacto que se pasa a Strings.t (o que marca
-- Strings.later, o que manda el servidor por Notify), con los mismos argumentos {x}. tools/strings.py
-- avisa de lo que falta o sobra.

return {
	-- HUD: línea de la fase, bajo la barra de Roblox.
	["Elige tu equipo"] = "Pick your team",
	["Esperando a los equipos"] = "Waiting for the teams",
	["Esperando a los equipos · {time}"] = "Waiting for the teams · {time}",
	["⚔️ La batalla empieza en {seconds}"] = "⚔️ The battle starts in {seconds}",
	["⚡ ¡Muerte súbita! La siguiente captura gana"] = "⚡ Sudden death! Next capture wins",
	["🏆 ¡Gana el equipo {icon} {name}!"] = "🏆 Team {icon} {name} wins!",
	["🤝 Empate"] = "🤝 Draw",
	["🚩 ¡Llevas la bandera! Llévala a tu pedestal"] = "🚩 You have the flag! Take it to your pedestal",
	["⚠️ ¡Les robaron la bandera! Recupérala"] = "⚠️ Your flag was stolen! Get it back",
	["Reapareces en {seconds}"] = "Respawning in {seconds}",

	-- HUD: dónde está cada bandera, bajo el marcador.
	["🏠 En casa"] = "🏠 At base",
	["🏃 ¡Robada!"] = "🏃 Stolen!",
	["⏳ En el suelo {seconds}"] = "⏳ Dropped {seconds}",

	-- El altar de la pirámide: línea del HUD y cartel sobre el altar.
	["⛩️ Altar en {time}"] = "⛩️ Altar in {time}",
	["⛩️ ⚔️ Altar disputado"] = "⛩️ ⚔️ Altar contested",
	["⛩️ {icon} toma el altar {percent} %"] = "⛩️ {icon} taking the altar {percent}%",
	["⛩️ ¡Altar encendido!"] = "⛩️ Altar lit!",
	["⛩️ ⚔️ ¡Disputado!"] = "⛩️ ⚔️ Contested!",
	["⛩️ ¡Tómalo!"] = "⛩️ Take it!",

	-- Ventana "Antes de la batalla".
	["🛡️ Equipo y rol"] = "🛡️ Team and role",
	["✅ ¡Listo!"] = "✅ Ready!",
	["⏳ Esperando… (quitar Listo)"] = "⏳ Waiting… (cancel Ready)",
	["Aún puedes cambiar de rol y de equipo"] = "You can still change role and team",
	["Elige equipo para empezar"] = "Pick a team to start",
	["Listos: {ready}/{total}"] = "Ready: {ready}/{total}",

	-- Resultados de la partida.
	["🧪 Partida de prueba"] = "🧪 Test match",
	["🏆 ¡Victoria!"] = "🏆 Victory!",
	["💀 Derrota"] = "💀 Defeat",
	["No cuenta para el Ámbar ni el ranking"] = "Doesn't count for Amber or the leaderboard",
	["✨ +{amber} de Ámbar"] = "✨ +{amber} Amber",
	["✨ +{amber} de Ámbar (tope diario {today}/{cap}: {lost} sin cobrar)"] = "✨ +{amber} Amber (daily cap {today}/{cap}: {lost} not collected)",
	["⛩️ Altares: {jaguar} · {quetzal}"] = "⛩️ Altars: {jaguar} · {quetzal}",
	["La revancha empieza en {seconds} s con quienes se queden"] = "Rematch starts in {seconds}s with whoever stays",
	["🔁 Revancha"] = "🔁 Rematch",
	["🏝️ Volver al Lobby"] = "🏝️ Back to Lobby",
	["⏳ Viajando…"] = "⏳ Traveling…",

	-- Avisos de la partida.
	["⚔️ ¡Que empiece la batalla! Roba la bandera rival y tráela a tu base"] = "⚔️ Let the battle begin! Steal the enemy flag and bring it to your base",
	["⚡ ¡Empate! Muerte súbita: la siguiente captura gana"] = "⚡ Tied! Sudden death: next capture wins",
	["No llegó el otro equipo: vuelven al Lobby"] = "The other team didn't show up: back to the Lobby",
	["Un equipo se ha quedado vacío: se espera a más jugadores"] = "A team is empty: waiting for more players",
	["🧪 Falta el otro equipo: usa el panel de pruebas para empezar solo"] = "🧪 The other team is missing: use the test panel to start alone",
	['{icon} Estás en el equipo {name}: elige tu rol y presiona "Listo"'] = '{icon} You\'re on team {name}: pick your role and press "Ready"',
	["El equipo {name} ya está completo"] = "Team {name} is already full",
	["{icon} Tu rol ya está completo en el equipo: juegas como {role}"] = "{icon} Your role is already full on the team: you play as {role}",
	["Ya hay demasiados {role} en tu equipo"] = "Your team already has too many of this role: {role}",
	["⚔️ {attacker} derriba a {victim}"] = "⚔️ {attacker} knocks out {victim}",

	-- Avisos de las banderas.
	["🚩 ¡{name} se lleva la bandera {team}!"] = "🚩 {name} takes the {team} flag!",
	["💥 ¡{name} ha soltado la bandera {team}!"] = "💥 {name} dropped the {team} flag!",
	["🏆 ¡{name} captura la bandera {team}! {score}"] = "🏆 {name} captures the {team} flag! {score}",
	["↩️ La bandera {team} vuelve a su base"] = "↩️ The {team} flag returns to its base",
	["↩️ {name} devuelve la bandera {team}"] = "↩️ {name} returns the {team} flag",
	["🚩 Tu bandera no está en casa: recupérala para puntuar"] = "🚩 Your flag isn't at base: get it back to score",

	-- Avisos del altar.
	["⛩️ ¡El altar de la pirámide se encendió! Quédate en lo alto para tomarlo"] = "⛩️ The pyramid altar is lit! Stay on top to take it",
	["⛩️ ¡El equipo {team} toma el altar! Su definitiva se carga el doble de rápido {seconds} s"] = "⛩️ Team {team} takes the altar! Their ultimate charges twice as fast for {seconds}s",

	-- Combate: avisos de las habilidades.
	["⚔️ ¡Un mono va a por ti! Recibes un {reduction} % menos de daño"] = "⚔️ A monkey is coming for you! You take {reduction}% less damage",
	["⚔️ ¡{taunted} monos van a por ti! Recibes un {reduction} % menos de daño"] = "⚔️ {taunted} monkeys are coming for you! You take {reduction}% less damage",
	["🏹 Una presa marcada durante {seconds} s"] = "🏹 1 prey marked for {seconds}s",
	["🏹 {marked} presas marcadas durante {seconds} s"] = "🏹 {marked} prey marked for {seconds}s",
	["🔮 No hay ningún mono a tiro: apunta hacia uno"] = "🔮 No monkey in range: aim at one",
	["🔮 No hay ningún enemigo a tiro: apunta hacia uno"] = "🔮 No enemy in range: aim at one",
	["⛑️ Has curado a un jugador"] = "⛑️ You healed 1 player",
	["⛑️ Has curado a {healed} jugadores"] = "⛑️ You healed {healed} players",
	["⛑️ ¡Cura de urgencia! Has curado a {healed} jugadores, les has bajado la fiebre y has envenenado a {poisoned} monos"] = "⛑️ Emergency heal! You healed {healed} players, broke their fever and poisoned {poisoned} monkeys",
	["⛑️ Dardo curativo a {name}"] = "⛑️ Healing dart on {name}",
	["🍃 {name} te protege con un escudo de {amount}"] = "🍃 {name} shields you for {amount}",
	["🍃 Escudo de {amount} para {name}"] = "🍃 {amount} shield on {name}",
	["🍃 Te proteges con un escudo de {amount}"] = "🍃 You shield yourself for {amount}",
	["⛑️ Tótem sanador durante {seconds} s"] = "⛑️ Healing totem for {seconds}s",
	["⛑️ ¡Resurgir! Has curado y limpiado a un jugador"] = "⛑️ Resurgence! You healed and cleansed 1 player",
	["⛑️ ¡Resurgir! Has curado y limpiado a {healed} jugadores"] = "⛑️ Resurgence! You healed and cleansed {healed} players",

	-- Combate: munición y muñecos de práctica.
	["Necesitas {ammo} para usar: {weapon}"] = "You need {ammo} to use: {weapon}",
	["Muñeco de práctica"] = "Practice dummy",
	["Muñeco de sparring"] = "Sparring dummy",
}
