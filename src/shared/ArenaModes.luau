--!strict
-- Los modos de juego de la Isla de Dunas (Config.Arena.Modes): hoy Captura la bandera; el Juego de pelota
-- llega en la Fase 26e. El servidor de Dunas publica el modo en curso en Workspace "ArenaMode"
-- (ArenaMatchService); el cliente y el servidor lo leen de aquí. Fuera de Dunas (la cola del Lobby) solo
-- sirven formats() y formatLabel(). Gemelo de Shared/LabModes.

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local ArenaModes = {}

-- El modo en curso (el primero de la lista mientras no llega ninguno).
function ArenaModes.current(): string
	local mode = Workspace:GetAttribute("ArenaMode")
	return if typeof(mode) == "string" and table.find(Config.Arena.Modes, mode) then mode else Config.Arena.Modes[1]
end

-- Los formatos que se pueden buscar en la cola del modo.
function ArenaModes.formats(mode: string): { number }
	return Config.Arena.ModeFormats[mode] or Config.Arena.ModeFormats[Config.Arena.Modes[1]]
end

-- El texto de un formato: "3v3" (jugadores por equipo).
function ArenaModes.formatLabel(_mode: string, format: number): string
	return `{format}v{format}`
end

return ArenaModes
