"""Revisa los cortes de una cinemática grabada en Studio (§209.1, 19-11-2026).

Uso:
    python tools/video/revisar_cortes.py "O:/Videos Primal banana/2026-11-19 11-29-20.mkv" [más vídeos…] [--salida carpeta]
    python tools/video/revisar_cortes.py --desde "2026-11-19 11:08"   (todos los .mkv de la carpeta de vídeos desde esa hora)

Por cada vídeo:
  - Recorta la ventana del juego (sin el Explorer ni la barra de Studio) y quita los cuadros repetidos: Studio dibuja a
    menos de 60 fps y cada cuadro nuevo parecería un corte.
  - Marca un corte donde la diferencia con el cuadro real anterior es mucho mayor que el movimiento de sus vecinos.
  - Avisa de dos fallos: DESTELLO (un cuadro distinto del anterior y del siguiente, que se parecen entre sí: plano
    equivocado colado o un relámpago) y PLANO CORTO (otro corte a 3 cuadros reales o menos: cámara en tránsito, luz que
    llega tarde).
  - Escribe <vídeo>_cortes.txt y hojas <vídeo>_tiras_N.jpg: una fila por grupo de cortes, de 2 cuadros antes a 6 después,
    a 60 fps. Se miran las hojas, no el vídeo entero.
Necesita ffmpeg en el PATH, numpy y Pillow.
"""

from __future__ import annotations

import argparse
import datetime as dt
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

VIDEOS = Path("O:/Videos Primal banana")
CROP = "crop=1640:880:0:60"  # ventana del juego en una grabación de Studio a 1920x1010
DIFF_W, DIFF_H = 160, 86
TILE_W, TILE_H = 240, 129
STRIP = 9  # cuadros por fila: 2 antes del corte y 6 después
ROWS_PER_SHEET = 12
REPEAT_DIFF = 0.4  # por debajo, el cuadro es una repetición
CUT_MIN = 12.0  # diferencia mínima (gris 0-255) para un corte
CUT_RATIO = 3.0  # y veces el movimiento de los vecinos
GROUP_GAP = 8  # cuadros de vídeo para juntar cortes en una fila


def frames_of(src: Path, vf: str, w: int, h: int, channels: int, pix: str):
	cmd = ["ffmpeg", "-v", "error", "-i", str(src), "-an", "-vf", f"{CROP},scale={w}:{h}{vf}", "-pix_fmt", pix]
	p = subprocess.Popen(cmd + ["-f", "rawvideo", "-"], stdout=subprocess.PIPE)
	size = w * h * channels
	try:
		while True:
			buf = p.stdout.read(size)
			if len(buf) < size:
				break
			yield buf
	finally:
		p.kill()


def detect(src: Path) -> tuple[list[str], list[tuple[int, bool]]]:
	frames: list[np.ndarray] = []
	idx: list[int] = []
	n = 0
	for buf in frames_of(src, "", DIFF_W, DIFF_H, 1, "gray"):
		f = np.frombuffer(buf, np.uint8).astype(np.int16)
		if not frames or np.abs(f - frames[-1]).mean() > REPEAT_DIFF:
			frames.append(f)
			idx.append(n)
		n += 1

	def d(a: int, b: int) -> float:
		return float(np.abs(frames[a] - frames[b]).mean())

	diffs = [0.0] + [d(i - 1, i) for i in range(1, len(frames))]
	cuts = []
	for i in range(1, len(frames)):
		near = sorted(diffs[max(1, i - 8) : i] + diffs[i + 1 : i + 9])
		med = near[len(near) // 2] if near else 0.0
		if diffs[i] > CUT_MIN and diffs[i] > CUT_RATIO * med:
			cuts.append(i)
	lines = [f"{src.name}: {n} cuadros, {len(frames)} reales, {len(cuts)} cortes"]
	marks: list[tuple[int, bool]] = []
	for k, i in enumerate(cuts):
		tag = ""
		if i + 1 < len(frames) and diffs[i + 1] > CUT_MIN and d(i - 1, i + 1) < 0.5 * min(diffs[i], diffs[i + 1]):
			tag = "  <<< DESTELLO de 1 cuadro"
		elif k + 1 < len(cuts) and cuts[k + 1] - i <= 3:
			tag = f"  <<< PLANO CORTO: {idx[cuts[k + 1]] - idx[i]} cuadros de vídeo hasta el siguiente corte"
		lines.append(f"  {idx[i] / 60:8.3f}s  f{idx[i]:6d}  dif {diffs[i]:5.1f}{tag}")
		marks.append((idx[i], bool(tag)))
	return lines, marks


def sheets(src: Path, marks: list[tuple[int, bool]], prefix: Path) -> list[Path]:
	groups: list[list] = []
	for f, flag in marks:
		if groups and f - groups[-1][1] <= GROUP_GAP:
			groups[-1][1] = f
			groups[-1][2] |= flag
		else:
			groups.append([f, f, flag])
	if not groups:
		return []
	need: dict[int, list[tuple[int, int]]] = {}
	for gi, (a, _, _) in enumerate(groups):
		for k in range(STRIP):
			need.setdefault(a - 2 + k, []).append((gi, k))
	last = max(need)
	tiles: dict[tuple[int, int], Image.Image] = {}
	for n, buf in enumerate(frames_of(src, "", TILE_W, TILE_H, 3, "rgb24")):
		if n > last:
			break
		if n in need:
			img = Image.frombuffer("RGB", (TILE_W, TILE_H), buf).copy()
			for key in need[n]:
				tiles[key] = img
	out = []
	for s in range(0, len(groups), ROWS_PER_SHEET):
		sub = groups[s : s + ROWS_PER_SHEET]
		sheet = Image.new("RGB", (STRIP * TILE_W, len(sub) * (TILE_H + 14)), "black")
		draw = ImageDraw.Draw(sheet)
		for r, (a, b, flag) in enumerate(sub):
			y = r * (TILE_H + 14)
			draw.text((2, y), f"{a / 60:.3f}s  (f{a}-{b}){'  <<<' if flag else ''}", fill="red" if flag else "yellow")
			for k in range(STRIP):
				tile = tiles.get((s + r, k))
				if tile:
					sheet.paste(tile, (k * TILE_W, y + 14))
		path = prefix.with_name(f"{prefix.name}_tiras_{s // ROWS_PER_SHEET + 1}.jpg")
		sheet.save(path, quality=85)
		out.append(path)
	return out


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("videos", nargs="*", type=Path)
	ap.add_argument("--desde", help='"AAAA-MM-DD HH:MM": todos los .mkv de la carpeta de vídeos desde esa hora')
	ap.add_argument("--salida", type=Path, default=Path("build/cortes"))
	args = ap.parse_args()
	videos = list(args.videos)
	if args.desde:
		since = dt.datetime.strptime(args.desde, "%Y-%m-%d %H:%M").timestamp()
		videos += sorted((p for p in VIDEOS.glob("*.mkv") if p.stat().st_mtime >= since), key=lambda p: p.stat().st_mtime)
	if not videos:
		ap.error("sin vídeos")
	args.salida.mkdir(parents=True, exist_ok=True)
	for src in videos:
		prefix = args.salida / src.stem.replace(" ", "_")
		lines, marks = detect(src)
		text = "\n".join(lines) + "\n"
		with open(prefix.with_name(prefix.name + "_cortes.txt"), "w", encoding="utf-8", newline="") as f:
			f.write(text)
		print(text, end="")
		for path in sheets(src, marks, prefix):
			print(f"  hoja: {path}")


if __name__ == "__main__":
	main()
