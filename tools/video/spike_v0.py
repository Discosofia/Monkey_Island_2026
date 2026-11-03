"""Spike V0 de la Fase 22: borrador 9:16 de prueba con pyCapCut.

Solo lee la toma de O:/ y crea una carpeta NUEVA en build/videos/borradores/. No toca ningún borrador de CapCut.
Uso: build/videos/.venv/Scripts/python -I tools/video/spike_v0.py
"""

import subprocess
import sys
import time
from pathlib import Path

import pycapcut as cc
from pycapcut import ClipSettings, TextStyle, trange
from pycapcut.metadata import FontType

RAIZ = Path(__file__).resolve().parents[2]
TOMA = "O:/2026-10-30 10-42-16.mkv"
MUSICA = RAIZ / "build" / "videos" / "tono_prueba.mp3"
SALIDA = RAIZ / "build" / "videos" / "borradores"
CORTES = [(5, 4), (15, 4), (28, 4)]  # (inicio en la toma, duración) en segundos


def capcut_abierto() -> bool:
	salida = subprocess.run(["tasklist", "/FI", "IMAGENAME eq CapCut.exe"], capture_output=True, text=True).stdout
	return "CapCut.exe" in salida


def main() -> int:
	if capcut_abierto():
		print("CapCut está abierto: ciérralo antes de escribir el borrador.")
		return 1
	SALIDA.mkdir(parents=True, exist_ok=True)
	nombre = "V0-spike-" + time.strftime("%Y%m%d-%H%M%S")
	carpeta = cc.DraftFolder(str(SALIDA))
	guion = carpeta.create_draft(nombre, 1080, 1920, fps=30)  # sin allow_replace: falla si existe

	guion.add_track(cc.TrackType.video).add_track(cc.TrackType.audio).add_track(cc.TrackType.text)
	llenar_alto = 1920 / (1080 * 1080 / 1920)  # el ancho encaja en 1080 (alto 607,5): 1920 / 607,5 llena el alto
	t = 0.0
	for inicio, dur in CORTES:
		seg = cc.VideoSegment(
			TOMA,
			trange(f"{t}s", f"{dur}s"),
			source_timerange=trange(f"{inicio}s", f"{dur}s"),
			clip_settings=ClipSettings(scale_x=llenar_alto, scale_y=llenar_alto),
		)
		guion.add_segment(seg)
		t += dur
	guion.add_segment(cc.AudioSegment(str(MUSICA), trange("0s", f"{t}s"), volume=0.6))

	libre = next(f for f in FontType if not f.value.is_vip)
	texto = cc.TextSegment(
		"PRIMAL BANANA ISLANDS",
		trange("0s", f"{t}s"),
		font=libre,
		style=TextStyle(size=14.0, bold=True, color=(1.0, 1.0, 1.0), align=1),
		clip_settings=ClipSettings(transform_y=-0.1),
	)
	guion.add_segment(texto)
	guion.save()
	print("Borrador creado:", SALIDA / nombre)
	print("Fuente usada (no Pro):", libre.name)
	return 0


if __name__ == "__main__":
	sys.exit(main())
