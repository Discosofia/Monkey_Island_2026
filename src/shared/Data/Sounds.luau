--!strict
-- Música y sonidos (Fase 6). Pon aquí los IDs de audio ("rbxassetid://123…") que elijas en la
-- Caja de herramientas → Audio del Creator Store (usa pistas con licencia de Roblox, p. ej. de APM
-- Music, que son gratis para usar en tus juegos). Con "" esa música no suena.
-- Ver docs/LANZAMIENTO.md, sección Sonido.

local Sounds = {
	-- Música de fondo por situación (la Isla elige sola cuál toca).
	Music = {
		Lobby = "",
		Day = "",
		Night = "",
		Siege = "", -- cuando los monos atacan el Basecamp
		Boss = "", -- cerca de un jefe
		FinalNight = "", -- La Gran Tropa
	},
	MusicVolume = 0.35,
	-- Efectos. Estos ya vienen con Roblox y funcionan sin hacer nada.
	Notify = "rbxasset://sounds/electronicpingshort.wav",
	NotifyVolume = 0.25,
}

return Sounds
