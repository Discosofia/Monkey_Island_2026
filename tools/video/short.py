"""Fase 22 V2: crea el borrador 1080x1920 de un Short en CapCut (uno por idioma) desde su guion JSON.

Lee el guion (docs/videos/shorts/<id>.json) y las tomas de O:/ (solo lectura). Escribe en build/videos/borradores/<id>-<idioma>-vN/
(carpeta nueva en cada ejecución: nunca se sobrescribe) y lo copia a la lista de proyectos de CapCut
(%LOCALAPPDATA%/CapCut/User Data/Projects/com.lveditor.draft/), para que aparezca al abrir CapCut. Con CapCut abierto se niega.
`--no-instalar` lo deja solo en build/.

Cada corte del guion dice el centro (cx, cy: fracción 0..1 de la toma) y el zoom (1 = la ventana 9:16 de toda la altura) del recuadro.
`--vista` saca además un fotograma por corte con ese recuadro y la guía del tercio central, en build/videos/shorts/<id>/.
Uso: build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/jefes.json [--lang es|en] [--vista] [--solo-vista]
"""

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SALIDA = RAIZ / "build" / "videos" / "borradores"
VISTAS = RAIZ / "build" / "videos" / "shorts"
PORTADA = RAIZ / "art" / "portada" / "portada-principal-1920x1080.png"
VERSION_PROBADA = "9.7.0.4153"
ANCHO, ALTO = 1080, 1920
TOMA_W, TOMA_H = 1920, 1080
K0 = ANCHO / TOMA_W  # píxeles de lienzo por píxel de toma con la toma ajustada al ancho (escala 1 de CapCut)
UTIL_Y = (0.145, 0.925)  # zona útil de las tomas de O:/ (ventana entera de Studio): sin la barra de herramientas ni la franja de abajo
Y_MAX = 0.33  # el tercio central del lienzo: el centro del texto cae en transform_y de -0.33 a 0.33
TAM_TEXTO, TAM_CHICO = 16.0, 8.0


def buscar(nombre: str) -> str:
	ruta = shutil.which(nombre)
	if ruta:
		return ruta
	patron = os.path.expandvars(rf"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\{nombre}.exe")
	hallados = glob.glob(patron)
	if not hallados:
		raise SystemExit(f"No encuentro {nombre} (winget install Gyan.FFmpeg).")
	return hallados[0]


def capcut_abierto() -> bool:
	salida = subprocess.run(["tasklist", "/FI", "IMAGENAME eq CapCut.exe"], capture_output=True, text=True).stdout
	return "CapCut.exe" in salida


def version_capcut() -> str:
	try:
		ruta = Path(os.path.expandvars(r"%LOCALAPPDATA%\CapCut\ProductInfo.xml"))
		return ET.parse(ruta).getroot().find("full_appver").get("value")
	except Exception:  # noqa: BLE001 - solo es un aviso
		return "desconocida"


def instalar(carpeta: Path) -> Path:
	"""Copia el borrador a la lista de proyectos de CapCut (carpeta nueva; nunca sustituye otra). CapCut tiene que estar cerrado."""
	proyectos = Path(os.path.expandvars(r"%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft"))
	destino = proyectos / carpeta.name
	if destino.exists():
		raise SystemExit(f"Ya existe {destino}: no se sustituye.")
	shutil.copytree(carpeta, destino)
	return destino


def duracion_toma(ffprobe: str, ruta: str) -> float:
	r = subprocess.run(
		[ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", ruta],
		capture_output=True,
		text=True,
	)
	return float(r.stdout.strip())


def recuadro(c: dict) -> tuple[float, float, float, float]:
	"""(centro x, centro y, k, zoom) del recuadro 9:16, con el centro metido para que la toma siempre llene el lienzo.
	k = píxeles de lienzo por píxel de toma. La ventana mide (607,5/zoom) x (1080/zoom) píxeles de toma."""
	z = max(c.get("zoom", 1.0), 1.0 / (UTIL_Y[1] - UTIL_Y[0]))
	ventana_w = TOMA_H * 9 / 16 / z
	ventana_h = TOMA_H / z
	cx = min(max(c["cx"], ventana_w / 2 / TOMA_W), 1 - ventana_w / 2 / TOMA_W)
	cy = min(max(c["cy"], UTIL_Y[0] + ventana_h / 2 / TOMA_H), UTIL_Y[1] - ventana_h / 2 / TOMA_H)
	return cx, cy, ALTO / ventana_h, z


def validar(guion: dict) -> None:
	ffprobe = buscar("ffprobe")
	total = 0.0
	for i, c in enumerate(guion["cortes"], 1):
		if c["toma"] == "portada":
			if not PORTADA.exists():
				raise SystemExit(f"Falta la portada: {PORTADA}")
			total += c["dura"]
			continue
		if not Path(c["toma"]).exists():
			raise SystemExit(f"Corte {i}: no existe la toma {c['toma']}")
		largo = duracion_toma(ffprobe, c["toma"])
		if c["desde"] + c["dura"] > largo + 0.01:
			raise SystemExit(f"Corte {i}: se sale de la toma ({c['desde']}+{c['dura']} > {largo:.2f} s)")
		total += c["dura"] / c.get("velocidad", 1.0)
	for idioma, textos in guion["textos"].items():
		for t in textos:
			y = t.get("y", -0.2)
			if abs(y) > Y_MAX:
				raise SystemExit(f"[{idioma}] «{t['texto']}»: y={y} sale del tercio central (±{Y_MAX})")
			if t["en"] + t["dura"] > total + 0.01:
				raise SystemExit(f"[{idioma}] «{t['texto']}»: acaba después del vídeo ({total:.2f} s)")
	print(f"Guion válido: {len(guion['cortes'])} cortes, {total:.2f} s.")


def vista(guion: dict, destino: Path) -> None:
	"""Un fotograma por corte con el recuadro elegido (540x960) y la guía del tercio central."""
	ffmpeg = buscar("ffmpeg")
	destino.mkdir(parents=True, exist_ok=True)
	for i, c in enumerate(guion["cortes"], 1):
		salida = destino / f"corte-{i:02d}.jpg"
		guia = "drawbox=x=0:y=320:w=540:h=320:color=yellow@0.9:t=2"
		if c["toma"] == "portada":
			orden = [ffmpeg, "-v", "error", "-y", "-i", str(PORTADA), "-frames:v", "1", "-vf", f"scale=540:-2,pad=540:960:0:(960-ih)/2,{guia}"]
		else:
			cx, cy, _, z = recuadro(c)
			w, h = TOMA_H * 9 / 16 / z, TOMA_H / z
			x0, y0 = cx * TOMA_W - w / 2, cy * TOMA_H - h / 2
			momento = c["desde"] + c["dura"] / 2
			orden = [ffmpeg, "-v", "error", "-y", "-ss", f"{momento:.3f}", "-i", c["toma"], "-frames:v", "1", "-vf",
				f"crop={w:.0f}:{h:.0f}:{x0:.0f}:{y0:.0f},scale=540:960,{guia}"]
		r = subprocess.run(orden + ["-q:v", "3", str(salida)], capture_output=True, text=True, encoding="utf-8", errors="replace")
		if r.returncode != 0:
			print(f"  FALLO vista {salida.name}: {r.stderr.strip()[:200]}")
	try:
		from PIL import Image

		n = len(guion["cortes"])
		hoja = Image.new("RGB", (n * 544 + 4, 964), "black")
		for i in range(n):
			hoja.paste(Image.open(destino / f"corte-{i + 1:02d}.jpg"), (4 + i * 544, 2))
		hoja.save(destino / "hoja.jpg", quality=85)
	except Exception as e:  # noqa: BLE001 - la hoja es opcional
		print("Sin hoja de contacto:", e)
	print("Vistas en", destino)


def borrador(guion: dict, idioma: str) -> Path:
	import pycapcut as cc
	from pycapcut import ClipSettings, TextBorder, TextStyle, trange
	from pycapcut.metadata import FontType

	SALIDA.mkdir(parents=True, exist_ok=True)
	n = 1
	while (SALIDA / f"{guion['id']}-{idioma}-v{n}").exists():
		n += 1
	nombre = f"{guion['id']}-{idioma}-v{n}"
	guionista = cc.DraftFolder(str(SALIDA)).create_draft(nombre, ANCHO, ALTO, fps=30)
	guionista.add_track(cc.TrackType.video).add_track(cc.TrackType.text, "titulo").add_track(cc.TrackType.text, "pie")

	t = 0.0
	for c in guion["cortes"]:
		if c["toma"] == "portada":
			# la portada entera cabe a lo ancho (franjas negras arriba y abajo): recortarla a 9:16 cortaría el título
			seg = cc.VideoSegment(str(PORTADA), trange(f"{t:.4f}s", f"{c['dura']}s"))
			t += c["dura"]
		else:
			cx, cy, k, _ = recuadro(c)
			escala = k / K0
			ajuste = ClipSettings(
				scale_x=escala,
				scale_y=escala,
				transform_x=-(cx - 0.5) * TOMA_W * k / (ANCHO / 2),
				transform_y=(cy - 0.5) * TOMA_H * k / (ALTO / 2),
			)
			vel = c.get("velocidad", 1.0)
			salida = c["dura"] / vel
			seg = cc.VideoSegment(
				c["toma"],
				trange(f"{t:.4f}s", f"{salida:.4f}s"),
				source_timerange=trange(f"{c['desde']}s", f"{c['dura']}s"),
				volume=c.get("volumen", 1.0),
				clip_settings=ajuste,
			)
			t += salida
		guionista.add_segment(seg)

	fuente = FontType.Anton
	for x in guion["textos"][idioma]:
		chico = x.get("chico", False)
		guionista.add_segment(
			cc.TextSegment(
				x["texto"],
				trange(f"{x['en']}s", f"{x['dura']}s"),
				font=fuente,
				style=TextStyle(size=TAM_CHICO if chico else TAM_TEXTO, bold=False, color=(1.0, 1.0, 1.0), align=1, auto_wrapping=True),
				border=TextBorder(width=60.0),
				clip_settings=ClipSettings(transform_y=x.get("y", -0.2)),
			),
			"pie" if chico else "titulo",
		)
	guionista.save()
	return SALIDA / nombre


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("guion", type=Path)
	ap.add_argument("--lang", choices=["es", "en"])
	ap.add_argument("--vista", action="store_true", help="además del borrador, un fotograma por corte")
	ap.add_argument("--solo-vista", action="store_true", help="solo los fotogramas, sin borrador (CapCut puede estar abierto)")
	ap.add_argument("--no-instalar", action="store_true", help="no copiar el borrador a la lista de proyectos de CapCut")
	a = ap.parse_args()
	guion = json.loads(a.guion.read_text(encoding="utf-8"))
	if not re.fullmatch(r"[a-z0-9-]+", guion["id"]):
		raise SystemExit("El id del guion solo lleva minúsculas, números y guiones.")
	validar(guion)
	if a.vista or a.solo_vista:
		vista(guion, VISTAS / guion["id"])
	if a.solo_vista:
		return 0
	if capcut_abierto():
		print("CapCut está abierto: ciérralo antes de escribir el borrador.")
		return 1
	v = version_capcut()
	if v != VERSION_PROBADA:
		print(f"AVISO: CapCut {v}; la versión probada es {VERSION_PROBADA}. Revisa el borrador antes de fiarte de él.")
	for idioma in [a.lang] if a.lang else list(guion["textos"]):
		hecho = borrador(guion, idioma)
		print("Borrador creado:", hecho)
		if not a.no_instalar:
			print("Instalado en CapCut:", instalar(hecho))
	return 0


if __name__ == "__main__":
	sys.exit(main())
