--!strict
-- Órdenes del panel de pruebas (solo Studio): nombre interno y texto del botón, en el orden en que
-- salen. El servidor de cada place (DebugService) decide qué hace cada una.

export type Command = { id: string, label: string }

local DebugCommands: { Island: { Command }, Lobby: { Command } } = {
	Island = {
		{ id = "Materials", label = "🎒 +50 de todo" },
		{ id = "NextRole", label = "🎭 Siguiente rol" },
		{ id = "Abilities", label = "⚡ Habilidades listas" },
		{ id = "Heal", label = "❤️ Curar y llenar" },
		{ id = "Revive", label = "💚 Revivir (Caído)" },
		{ id = "Hungry", label = "🍖 Hambre y sed al 10" },
		{ id = "Fever", label = "🤒 Fiebre a 90" },
		{ id = "Boss", label = "👑 Siguiente jefe" },
		{ id = "BossHurt", label = "💔 Jefe al 30 %" },
		{ id = "Mandrill", label = "🐒 Mandril aquí" },
		{ id = "AlwaysCrit", label = "🎯 Críticos al 100 % (sí/no)" },
		{ id = "Egg", label = "🥚 Huevo (rareza siguiente)" },
		{ id = "HatchNow", label = "🐣 Terminar la defensa del huevo (en el nido)" },
		{ id = "GrantEgg", label = "🥚 Huevo guardado (al nido del Lobby o la mochila)" },
		{ id = "Missions", label = "🎯 Cumplir las misiones del día" },
		{ id = "Crate", label = "📦 Caja de suministro" },
		{ id = "Pet", label = "🐾 Siguiente mascota" },
		{ id = "Rain", label = "🌧️ Lluvia" },
		{ id = "Storm", label = "⛈️ Tormenta" },
		{ id = "Clear", label = "☀️ Despejado" },
		{ id = "Eruption", label = "🌋 Erupción" },
		{ id = "Lightning", label = "⚡ Rayo cerca de mí" },
		{ id = "LavaBomb", label = "☄️ Bombas de lava cerca de mí" },
		{ id = "Sounds", label = "🔊 Probar todos los sonidos" },
		{ id = "WeaponShowcase", label = "🗡️ Expositor de armas (sí/no)" },
		{ id = "MonkeyShowcase", label = "🦍 Expositor de monos y jefes con sus fases (sí/no)" },
		{ id = "PetShowcase", label = "🐾 Expositor de mascotas (sí/no)" },
		{ id = "NextArmor", label = "🛡️ Siguiente armadura" },
		{ id = "Beacon", label = "📡 4 piezas + baliza sin espera" },
		{ id = "GreatTroop", label = "🌕 La Gran Tropa ya" },
		{ id = "BasecampHurt", label = "🏕️ Campamento al 10 %" },
		{ id = "Defeat", label = "💀 Terminar: derrota" },
		{ id = "Victory", label = "🚁 Terminar: victoria (rescate)" },
	},
	Lobby = {
		{ id = "Amber", label = "✨ +500 Ámbar" },
		{ id = "RoleXp", label = "⭐ +300 XP del rol" },
		{ id = "Pet", label = "🐾 Siguiente mascota" },
		{ id = "GrantEgg", label = "🥚 Huevo (rareza siguiente)" },
		{ id = "EggReady", label = "🐣 Huevo del nido listo" },
		{ id = "ClockHour", label = "⏩ Reloj +1 h" },
		{ id = "Supplies", label = "🎒 Provisiones de prueba" },
		{ id = "NextDay", label = "📅 Día siguiente (calendario)" },
	},
}

return DebugCommands
