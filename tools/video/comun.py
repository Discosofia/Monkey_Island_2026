"""Piezas comunes de short.py y tomas.py: ffmpeg, formatos de vídeo, zonas útiles de las tomas y el recuadro del corte.

Las tomas de O:/ son 1920x1080. Hay dos clases: `juego` (el juego a pantalla completa) y `studio` (la ventana de Roblox Studio,
de la que solo vale el visor 3D). Un corte sin `clase` usa la zona de siempre (la ventana entera de Studio sin la barra y la franja
de abajo), para que los guiones viejos den el mismo encuadre.
"""

import glob
import os
import shutil
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
CARPETA_TOMAS = Path("O:/Videos Primal banana")  # solo se lee
TOMA_W, TOMA_H = 1920, 1080

# formato -> (ancho del lienzo, alto del lienzo, duración mínima, duración máxima en segundos)
FORMATOS = {
	"short": (1080, 1920, 15.0, 60.0),
	"reel": (1080, 1920, 15.0, 90.0),
	"youtube": (1920, 1080, 60.0, 180.0),
}

# clase -> (x0, x1, y0, y1) en fracción de la toma. None = la zona de siempre.
# Medidas sobre las tomas de «Upgrading Quetzaqatl»; si cambia la disposición de Studio, ajústalas.
#   studio: el juego corriendo dentro de Studio (Play): sin la cinta de arriba ni el Explorador de la derecha.
#   visor:  Studio en edición: solo el visor 3D, sin los paneles de los lados ni la salida de abajo.
ZONAS = {
	None: (0.0, 1.0, 0.145, 0.925),
	"juego": (0.0, 1.0, 0.04, 1.0),
	"studio": (0.012, 0.935, 0.13, 0.925),
	"visor": (0.245, 0.80, 0.15, 0.795),
}
CLASES = tuple(k for k in ZONAS if k)
VOLUMEN_CLASE = {"juego": 0.5, "studio": 0.0, "visor": 0.0}  # sin `volumen` en el corte: el juego a media voz y Studio en silencio


def buscar(nombre: str) -> str:
	ruta = shutil.which(nombre)
	if ruta:
		return ruta
	patron = os.path.expandvars(rf"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\{nombre}.exe")
	hallados = glob.glob(patron)
	if not hallados:
		raise SystemExit(f"No encuentro {nombre} (winget install Gyan.FFmpeg).")
	return hallados[0]


def duracion(ffprobe: str, ruta: str) -> float:
	r = subprocess.run(
		[ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", ruta],
		capture_output=True,
		text=True,
	)
	return float(r.stdout.strip())


def lienzo(guion: dict) -> tuple[int, int]:
	return FORMATOS[guion.get("formato", "short")][:2]


def ruta_toma(guion: dict, corte: dict) -> str:
	"""La toma del corte: una ruta absoluta, o relativa a `carpeta` del guion (que a su vez cuelga de O:/Videos Primal banana)."""
	toma = corte["toma"]
	if toma == "portada" or Path(toma).is_absolute() or "carpeta" not in guion:
		return toma
	base = Path(guion["carpeta"])
	if not base.is_absolute():
		base = CARPETA_TOMAS / base
	return str(base / toma)


def recuadro(corte: dict, formato: str = "short") -> tuple[float, float, float, float, float, float]:
	"""(centro x, centro y, k, zoom, ancho, alto) de la ventana del corte, metida en la zona útil de su clase.

	k = píxeles de lienzo por píxel de toma; ancho y alto, en píxeles de toma. En vertical la ventana es 9:16 y el zoom 1 es la toma
	entera de alto; en horizontal es 16:9 y el zoom 1 es la zona útil entera. El zoom mínimo es el que la deja dentro de la zona."""
	cw, ch = FORMATOS[formato][:2]
	x0, x1, y0, y1 = ZONAS[corte.get("clase")]
	zw, zh = x1 - x0, y1 - y0
	proporcion = cw / ch
	base_h = TOMA_H if cw < ch else TOMA_H * zh
	z = max(corte.get("zoom", 1.0), base_h / (zh * TOMA_H), base_h * proporcion / (zw * TOMA_W))
	h = base_h / z
	w = h * proporcion
	cx = min(max(corte["cx"], x0 + w / 2 / TOMA_W), x1 - w / 2 / TOMA_W)
	cy = min(max(corte["cy"], y0 + h / 2 / TOMA_H), y1 - h / 2 / TOMA_H)
	return cx, cy, ch / h, z, w, h
