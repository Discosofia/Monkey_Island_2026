"""Fase 22 V1: un fotograma por corte, tal como queda en el tráiler (16:9) y con la guía del recorte 9:16.

Lee la lista de cortes de borrador.py (--json) y las tomas de O:/ (solo lectura). Escribe en build/videos/fotogramas/<nombre>/.
En cada imagen: el encuadre del corte en el tráiler, el rectángulo 9:16 centrado (verde) y su tercio central (amarillo).
Uso: python -I tools/video/fotogramas.py build/videos/cortes/trailer-esp.json [--hoja]
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ANCHO, ALTO = 960, 540  # tamaño de cada fotograma de salida (mitad de 1920x1080)


def buscar_ffmpeg() -> str:
	ruta = shutil.which("ffmpeg")
	if ruta:
		return ruta
	patron = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe")
	hallados = glob.glob(patron)
	if not hallados:
		raise SystemExit("No encuentro ffmpeg (winget install Gyan.FFmpeg).")
	return hallados[0]


def filtro(c: dict) -> str:
	"""Encuadre del corte en el lienzo 16:9 + guía 9:16. La escala y el desplazamiento son los de CapCut."""
	s = max(c["escala"], 1.0)
	w, h = ANCHO * s, ALTO * s
	# transform x/y: fracción de medio lienzo; y positivo sube la imagen
	x0 = (w - ANCHO) / 2 - c["x"] * ANCHO / 2
	y0 = (h - ALTO) / 2 + c["y"] * ALTO / 2
	ancho916 = ALTO * 9 / 16
	gx = (ANCHO - ancho916) / 2
	tercio = ALTO / 3
	return (
		f"scale={w + 0.5:.0f}:{h + 0.5:.0f},crop={ANCHO}:{ALTO}:{x0:.0f}:{y0:.0f},"
		f"drawbox=x={gx:.0f}:y=0:w={ancho916:.0f}:h={ALTO}:color=lime@0.9:t=3,"
		f"drawbox=x={gx:.0f}:y={tercio:.0f}:w={ancho916:.0f}:h={tercio:.0f}:color=yellow@0.9:t=2"
	)


def sacar(ffmpeg: str, c: dict, destino: Path) -> bool:
	es_imagen = c["toma"].lower().endswith((".png", ".jpg", ".jpeg"))
	momento = c["inicio"] + c["duracion"] / 2
	orden = [ffmpeg, "-v", "error", "-y"]
	if not es_imagen:
		orden += ["-ss", f"{momento:.3f}"]
	orden += ["-i", c["toma"], "-frames:v", "1", "-vf", filtro(c), "-q:v", "3", str(destino)]
	r = subprocess.run(orden, capture_output=True, text=True, encoding="utf-8", errors="replace")
	if r.returncode != 0 or not destino.exists():
		print(f"  FALLO {destino.name}: {r.stderr.strip()[:200]}")
		return False
	return True


def hoja(carpeta: Path, n: int) -> None:
	"""Hoja de contacto de 4 columnas con todos los fotogramas, a 480 px de ancho cada uno (necesita Pillow)."""
	from PIL import Image

	filas = (n + 3) // 4
	ancho, alto = 480, 270
	lienzo = Image.new("RGB", (4 * ancho + 20, filas * alto + (filas + 1) * 4), "black")
	for i in range(n):
		img = Image.open(carpeta / f"{i + 1:02d}.jpg").resize((ancho, alto))
		lienzo.paste(img, (4 + (i % 4) * (ancho + 4), 4 + (i // 4) * (alto + 4)))
	salida = carpeta / "hoja.jpg"
	lienzo.save(salida, quality=85)
	print("Hoja:", salida)


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("cortes", type=Path)
	ap.add_argument("--hoja", action="store_true")
	a = ap.parse_args()
	datos = json.loads(a.cortes.read_text(encoding="utf-8"))["cortes"]
	carpeta = RAIZ / "build" / "videos" / "fotogramas" / a.cortes.stem
	carpeta.mkdir(parents=True, exist_ok=True)
	ffmpeg = buscar_ffmpeg()
	ok = 0
	for i, c in enumerate(datos, 1):
		if sacar(ffmpeg, c, carpeta / f"{i:02d}.jpg"):
			ok += 1
	print(f"{ok}/{len(datos)} fotogramas en {carpeta}")
	if a.hoja and ok == len(datos):
		hoja(carpeta, len(datos))
	return 0 if ok == len(datos) else 1


if __name__ == "__main__":
	sys.exit(main())
