--!strict
-- Los modos de juego del Laboratorio en ruinas (Config.Lab.Modes): Duelo por equipos, Todos contra todos
-- y Rondas. El servidor del Laboratorio publica el modo en curso en Workspace "LabMode"
-- (LabMatchService); el cliente y el servidor lo leen de aquí. Fuera del Laboratorio (la cola del Lobby)
-- solo sirven formats() y formatLabel().

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Strings = require(script.Parent.Strings)

local T = Strings.t

local LabModes = {}

-- El modo en curso (el primero de la lista mientras no llega ninguno).
function LabModes.current(): string
	local mode = Workspace:GetAttribute("LabMode")
	return if typeof(mode) == "string" and Config.Lab.ModeFormats[mode] then mode else Config.Lab.Modes[1]
end

function LabModes.isFreeForAll(): boolean
	return LabModes.current() == "FreeForAll"
end

function LabModes.isRounds(): boolean
	return LabModes.current() == "Rounds"
end

-- Los formatos que se pueden buscar en la cola del modo.
function LabModes.formats(mode: string): { number }
	return Config.Lab.ModeFormats[mode] or Config.Lab.ModeFormats[Config.Lab.Modes[1]]
end

-- El texto de un formato: "3v3" por bando, o "10 jugadores" en Todos contra todos.
function LabModes.formatLabel(mode: string, format: number): string
	if mode == "FreeForAll" then
		return T("{n} jugadores", { n = format })
	end
	return `{format}v{format}`
end

return LabModes
