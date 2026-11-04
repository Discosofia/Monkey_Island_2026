"""Fase 22 V2: crea el borrador de CapCut de un vídeo (uno por idioma) desde su guion JSON: Short y Reel 1080x1920, YouTube 1920x1080.

Lee el guion (docs/videos/shorts/<id>.json) y las tomas de O:/ (solo lectura). Escribe en build/videos/borradores/<id>-<idioma>-vN/
(carpeta nueva en cada ejecución: nunca se sobrescribe) y lo copia a la lista de proyectos de CapCut
(%LOCALAPPDATA%/CapCut/User Data/Projects/com.lveditor.draft/), para que aparezca al abrir CapCut. Con CapCut abierto se niega.
`--no-instalar` lo deja solo en build/.

Cada corte del guion dice el centro (cx, cy: fracción 0..1 de la toma) y el zoom del recuadro (1 = la ventana de toda la altura en
vertical; la zona útil entera en horizontal), y su `clase` (juego o studio: la zona útil y el volumen). Campos del guion: ver docs/videos/shorts.md.
`--vista` saca además un fotograma por corte con ese recuadro y la guía, en build/videos/shorts/<id>/.
Uso: build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/jefes.json [--lang es|en] [--vista] [--solo-vista]
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # con `python -I` la carpeta del script no entra sola

import comun  # noqa: E402
from comun import CLASES, FORMATOS, TOMA_H, TOMA_W, VOLUMEN_CLASE, buscar, lienzo, recuadro, ruta_toma  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
SALIDA = RAIZ / "build" / "videos" / "borradores"
VISTAS = RAIZ / "build" / "videos" / "shorts"
PORTADA = RAIZ / "art" / "portada" / "portada-principal-1920x1080.png"
VERSION_PROBADA = "9.7.0.4153"
Y_MAX = 0.33  # el tercio central del lienzo vertical: el centro del texto cae en transform_y de -0.33 a 0.33
Y_MAX_HORIZONTAL = 0.45  # en 16:9 no hay tercio central, solo márgenes
TAM_TEXTO, TAM_CHICO, TAM_VOZ = 16.0, 8.0, 7.0
REGISTRO_MUSICA = RAIZ / "docs" / "videos" / "musica" / "README.md"


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


def pistas_con_licencia() -> set[str]:
	"""Nombres de archivo que tienen fila en el registro de licencias de docs/videos/musica/README.md."""
	if not REGISTRO_MUSICA.exists():
		return set()
	filas = [f for f in REGISTRO_MUSICA.read_text(encoding="utf-8").split("## Registro de licencias")[-1].splitlines() if f.startswith("|")]
	return {f.split("|")[1].strip().strip("`") for f in filas[2:] if f.count("|") >= 3}


def validar(guion: dict) -> float:
	"""Comprueba tomas, tiempos, textos, voz y música. Devuelve la duración total en segundos."""
	formato = guion.get("formato", "short")
	if formato not in FORMATOS:
		raise SystemExit(f"Formato desconocido «{formato}» (short, reel o youtube).")
	ffprobe = buscar("ffprobe")
	total = 0.0
	for i, c in enumerate(guion["cortes"], 1):
		if c["toma"] == "portada":
			if not PORTADA.exists():
				raise SystemExit(f"Falta la portada: {PORTADA}")
			total += c["dura"]
			continue
		if c.get("clase") not in (None, *CLASES):
			raise SystemExit(f"Corte {i}: clase «{c['clase']}» desconocida ({', '.join(CLASES)}).")
		toma = ruta_toma(guion, c)
		if not Path(toma).exists():
			raise SystemExit(f"Corte {i}: no existe la toma {toma}")
		largo = comun.duracion(ffprobe, toma)
		if c["desde"] + c["dura"] > largo + 0.01:
			raise SystemExit(f"Corte {i}: se sale de la toma ({c['desde']}+{c['dura']} > {largo:.2f} s)")
		total += c["dura"] / c.get("velocidad", 1.0)
	y_max = Y_MAX if formato != "youtube" else Y_MAX_HORIZONTAL
	for clave in ("textos", "voz"):
		for idioma, textos in guion.get(clave, {}).items():
			for t in textos:
				y = t.get("y", -0.2)
				if abs(y) > y_max:
					raise SystemExit(f"[{clave} {idioma}] «{t['texto']}»: y={y} sale de la zona segura (±{y_max})")
				if t["en"] + t["dura"] > total + 0.01:
					raise SystemExit(f"[{clave} {idioma}] «{t['texto']}»: acaba después del vídeo ({total:.2f} s)")
	musica = guion.get("musica")
	if musica:
		pista = RAIZ / musica["pista"]
		if not pista.exists():
			raise SystemExit(f"No existe la pista de música {pista}")
		if pista.name not in pistas_con_licencia():
			raise SystemExit(f"La pista {pista.name} no tiene fila en el registro de licencias ({REGISTRO_MUSICA.name}): sin fila no se usa.")
	_, _, minimo, maximo = FORMATOS[formato]
	if not minimo <= total <= maximo:
		print(f"AVISO: {total:.1f} s; un {formato} dura entre {minimo:.0f} y {maximo:.0f} s.")
	print(f"Guion válido: {len(guion['cortes'])} cortes, {total:.2f} s, formato {formato}.")
	return total


def vista(guion: dict, destino: Path) -> None:
	"""Un fotograma por corte con el recuadro elegido (mitad de tamaño) y la guía (el tercio central en vertical)."""
	formato = guion.get("formato", "short")
	ffmpeg = buscar("ffmpeg")
	cw, ch = lienzo(guion)
	sw, sh = cw // 2, ch // 2
	destino.mkdir(parents=True, exist_ok=True)
	guia = f"drawbox=x=0:y={sh // 3}:w={sw}:h={sh // 3}:color=yellow@0.9:t=2" if cw < ch else f"drawbox=x=0:y=0:w={sw}:h={sh}:color=yellow@0.9:t=2"
	for i, c in enumerate(guion["cortes"], 1):
		salida = destino / f"corte-{i:02d}.jpg"
		if c["toma"] == "portada":
			orden = [ffmpeg, "-v", "error", "-y", "-i", str(PORTADA), "-frames:v", "1", "-vf", f"scale={sw}:-2,pad={sw}:{sh}:0:({sh}-ih)/2,{guia}"]
		else:
			cx, cy, _, _, w, h = recuadro(c, formato)
			x0, y0 = cx * TOMA_W - w / 2, cy * TOMA_H - h / 2
			momento = c["desde"] + c["dura"] / 2
			orden = [ffmpeg, "-v", "error", "-y", "-ss", f"{momento:.3f}", "-i", ruta_toma(guion, c), "-frames:v", "1", "-vf",
				f"crop={w:.0f}:{h:.0f}:{x0:.0f}:{y0:.0f},scale={sw}:{sh},{guia}"]
		r = subprocess.run(orden + ["-q:v", "3", str(salida)], capture_output=True, text=True, encoding="utf-8", errors="replace")
		if r.returncode != 0:
			print(f"  FALLO vista {salida.name}: {r.stderr.strip()[:200]}")
	try:
		from PIL import Image

		n = len(guion["cortes"])
		# vertical: los cortes en fila; horizontal: de dos en dos
		columnas = n if cw < ch else min(n, 2)
		filas = (n + columnas - 1) // columnas
		hoja = Image.new("RGB", (columnas * (sw + 4) + 4, filas * (sh + 4) + 4), "black")
		for i in range(n):
			hoja.paste(Image.open(destino / f"corte-{i + 1:02d}.jpg"), (4 + (i % columnas) * (sw + 4), 4 + (i // columnas) * (sh + 4)))
		hoja.save(destino / "hoja.jpg", quality=85)
	except Exception as e:  # noqa: BLE001 - la hoja es opcional
		print("Sin hoja de contacto:", e)
	print("Vistas en", destino)


def borrador(guion: dict, idioma: str, total: float) -> Path:
	import pycapcut as cc
	from pycapcut import ClipSettings, TextBorder, TextStyle, trange
	from pycapcut.metadata import FontType

	formato = guion.get("formato", "short")
	ancho, alto = lienzo(guion)
	k0 = ancho / TOMA_W  # píxeles de lienzo por píxel de toma con la toma ajustada al ancho (escala 1 de CapCut)
	SALIDA.mkdir(parents=True, exist_ok=True)
	n = 1
	while (SALIDA / f"{guion['id']}-{idioma}-v{n}").exists():
		n += 1
	nombre = f"{guion['id']}-{idioma}-v{n}"
	guionista = cc.DraftFolder(str(SALIDA)).create_draft(nombre, ancho, alto, fps=30)
	guionista.add_track(cc.TrackType.video)
	musica = guion.get("musica")
	if musica:
		guionista.add_track(cc.TrackType.audio, "musica")
	guionista.add_track(cc.TrackType.text, "titulo").add_track(cc.TrackType.text, "pie")
	if guion.get("voz", {}).get(idioma):
		guionista.add_track(cc.TrackType.text, "voz")

	t = 0.0
	for c in guion["cortes"]:
		if c["toma"] == "portada":
			# la portada entera cabe a lo ancho (en vertical, franjas negras arriba y abajo): recortarla a 9:16 cortaría el título
			seg = cc.VideoSegment(str(PORTADA), trange(f"{t:.4f}s", f"{c['dura']}s"))
			t += c["dura"]
		else:
			cx, cy, k, _, _, _ = recuadro(c, formato)
			escala = k / k0
			ajuste = ClipSettings(
				scale_x=escala,
				scale_y=escala,
				transform_x=-(cx - 0.5) * TOMA_W * k / (ancho / 2),
				transform_y=(cy - 0.5) * TOMA_H * k / (alto / 2),
			)
			vel = c.get("velocidad", 1.0)
			salida = c["dura"] / vel
			seg = cc.VideoSegment(
				ruta_toma(guion, c),
				trange(f"{t:.4f}s", f"{salida:.4f}s"),
				source_timerange=trange(f"{c['desde']}s", f"{c['dura']}s"),
				volume=c.get("volumen", VOLUMEN_CLASE.get(c.get("clase"), 1.0)),
				clip_settings=ajuste,
			)
			t += salida
		guionista.add_segment(seg)

	if musica:
		pista = RAIZ / musica["pista"]
		largo = min(total, comun.duracion(buscar("ffprobe"), str(pista)))
		guionista.add_segment(cc.AudioSegment(str(pista), trange("0s", f"{largo:.4f}s"), volume=musica.get("volumen", 0.3)), "musica")

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
	# la voz: las frases que el usuario pasará a texto a voz en CapCut, como subtítulos pequeños abajo
	for x in guion.get("voz", {}).get(idioma, []):
		guionista.add_segment(
			cc.TextSegment(
				x["texto"],
				trange(f"{x['en']}s", f"{x['dura']}s"),
				font=fuente,
				style=TextStyle(size=TAM_VOZ, bold=False, color=(1.0, 0.95, 0.6), align=1, auto_wrapping=True),
				border=TextBorder(width=60.0),
				clip_settings=ClipSettings(transform_y=x.get("y", -0.3 if formato != "youtube" else -0.4)),
			),
			"voz",
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
	total = validar(guion)
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
		hecho = borrador(guion, idioma, total)
		print("Borrador creado:", hecho)
		if not a.no_instalar:
			print("Instalado en CapCut:", instalar(hecho))
	return 0


if __name__ == "__main__":
	sys.exit(main())
