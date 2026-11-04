"""Fase 22 V1: lee un borrador de CapCut (copia) y saca la lista de cortes.

Solo lee. Si le pasas una carpeta que no esté bajo build/videos/copias/, se niega: copia antes el borrador.
Uso: python -I tools/video/borrador.py "build/videos/copias/2026-11-03/trailer esp" [--json salida.json] [--md salida.md]
"""

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
COPIAS = RAIZ / "build" / "videos" / "copias"
US = 1_000_000


def segundos(micro: int) -> float:
	return micro / US


def leer(carpeta: Path) -> dict:
	carpeta = carpeta.resolve()
	if COPIAS not in carpeta.parents:
		raise SystemExit(f"Solo se leen copias bajo {COPIAS}. Copia el borrador antes.")
	with open(carpeta / "draft_content.json", encoding="utf-8") as f:
		return json.load(f)


def cortes(borrador: dict) -> list[dict]:
	"""Los segmentos de las pistas de vídeo, en orden de línea de tiempo."""
	videos = {m["id"]: m for m in borrador["materials"]["videos"]}
	lista = []
	for pista in borrador["tracks"]:
		if pista["type"] != "video":
			continue
		for seg in pista["segments"]:
			mat = videos[seg["material_id"]]
			src, dst, clip = seg["source_timerange"], seg["target_timerange"], seg["clip"]
			lista.append({
				"toma": mat["path"],
				"toma_duracion": segundos(mat["duration"]),
				"ancho": mat["width"],
				"alto": mat["height"],
				"inicio": segundos(src["start"]),
				"duracion": segundos(src["duration"]),
				"en_linea": segundos(dst["start"]),
				"velocidad": seg.get("speed", 1.0),
				"volumen": seg.get("volume", 1.0),
				"escala": clip["scale"]["x"],
				"x": clip["transform"]["x"],
				"y": clip["transform"]["y"],
			})
	lista.sort(key=lambda c: c["en_linea"])
	return lista


def textos(borrador: dict) -> list[dict]:
	"""Los textos con su momento en la línea de tiempo."""
	mats = {m["id"]: m for m in borrador["materials"]["texts"]}
	lista = []
	for pista in borrador["tracks"]:
		if pista["type"] != "text":
			continue
		for seg in pista["segments"]:
			mat = mats.get(seg["material_id"])
			if not mat:
				continue
			try:
				contenido = json.loads(mat["content"])["text"]
			except (ValueError, KeyError, TypeError):
				contenido = mat.get("content", "")
			t = seg["target_timerange"]
			lista.append({"texto": contenido, "en_linea": segundos(t["start"]), "duracion": segundos(t["duration"])})
	lista.sort(key=lambda c: c["en_linea"])
	return lista


def mm_ss(s: float) -> str:
	return f"{int(s // 60)}:{s % 60:05.2f}"


def tabla(lista: list[dict]) -> str:
	filas = ["| # | Línea | Toma | Desde | Dura | Esc. | x | y |", "|--:|---|---|---|--:|--:|--:|--:|"]
	for i, c in enumerate(lista, 1):
		nombre = c["toma"].rsplit("/", 1)[-1]
		filas.append(
			f"| {i} | {mm_ss(c['en_linea'])} | {nombre} | {mm_ss(c['inicio'])} | {c['duracion']:.2f} s "
			f"| {c['escala']:.2f} | {c['x']:.2f} | {c['y']:.2f} |"
		)
	return "\n".join(filas)


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("carpeta", type=Path)
	ap.add_argument("--json", type=Path)
	ap.add_argument("--md", type=Path)
	a = ap.parse_args()
	b = leer(a.carpeta)
	c, t = cortes(b), textos(b)
	print(f"Borrador {b.get('name', '')}: {mm_ss(segundos(b['duration']))}, {len(c)} cortes, {len(t)} textos")
	md = tabla(c)
	print(md)
	if a.json:
		a.json.parent.mkdir(parents=True, exist_ok=True)
		a.json.write_text(json.dumps({"cortes": c, "textos": t}, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="")
	if a.md:
		a.md.parent.mkdir(parents=True, exist_ok=True)
		a.md.write_text(md + "\n", encoding="utf-8", newline="")
	return 0


if __name__ == "__main__":
	sys.exit(main())
