--!strict
-- Las vistas con que se apunta (calibración del tiro, Fase 24): el cliente avisa de la suya por Remotes.ReportAimView
-- (CombatClient/Controllers/AimViewReporter), el servidor la guarda como atributo "AimView" del jugador
-- (AimInputService) y el campo de tiro separa las medidas por vista (RangeCalibrationService).
--   Free     ratón con la cámara libre
--   Lock     bloqueo de cámara (Ctrl) sin apuntar
--   LockAim  bloqueo de cámara y apuntando (clic derecho)
--   First    primera persona (Laboratorio y modo shooter del campo)
--   Touch    táctil
--   Pad      mando
-- "names" es el texto corto de cada una (en español; se traduce al dibujarlo con T).

local Strings = require(script.Parent.Parent.Strings)

local later = Strings.later

local AimViews = {}

AimViews.order = { "Free", "Lock", "LockAim", "First", "Touch", "Pad" }

AimViews.names = {
	Free = later("Libre"),
	Lock = later("Bloqueo"),
	LockAim = later("Bloqueo + mira"),
	First = later("1ª persona"),
	Touch = later("Táctil"),
	Pad = later("Mando"),
}

return AimViews
