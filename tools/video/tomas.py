"""Fase 22 V3: de la carpeta de tomas al storyboard. Inventario, exploración, detalle de un plano y storyboard en HTML.

Las tomas viven en O:/Videos Primal banana/<vídeo>/ (solo lectura). Todo lo que se escribe va a build/videos/proyectos/<slug>/.
  inventario <carpeta>            duración, resolución y clase (juego/studio) de cada toma + hoja gruesa (una miniatura cada ~30 s)
  explorar <carpeta>              cambios de escena y picos de sonido de cada toma + hojas de contacto con la marca «T<toma> m:ss»
  detalle <carpeta> <toma> <t>    3 fotogramas (inicio, medio, final) de cada tramo con el recuadro; t = «desde+dura,desde+dura»
  storyboard <guion.json>         página HTML autocontenida con los 3 fotogramas de cada corte del guion, lista para publicar como Artifact
<carpeta> es el nombre dentro de O:/Videos Primal banana o una ruta; <toma> es el número del inventario o el nombre del archivo.
Uso: build/videos/.venv/Scripts/python -I tools/video/tomas.py inventario "Upgrading Quetzaqatl"
"""

import argparse
import base64
import html
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # con `python -I` la carpeta del script no entra sola

import comun  # noqa: E402
from comun import CARPETA_TOMAS, CLASES, FORMATOS, RAIZ, TOMA_H, TOMA_W, buscar, lienzo, recuadro, ruta_toma  # noqa: E402

PROYECTOS = RAIZ / "build" / "videos" / "proyectos"
EXTENSIONES = (".mkv", ".mp4", ".mov")
UMBRAL_ESCENA = 0.3
SALTO_GRUESO = 30.0  # segundos entre miniaturas de la hoja gruesa
SALTO_RELLENO = 15.0  # en la exploración, una miniatura cada tanto aunque no haya cambios de escena
HUECO_MIN = 4.0  # segundos mínimos entre dos candidatos
MINIATURA = (320, 180)
COLUMNAS, FILAS = 4, 4


def correr(orden: list[str]) -> subprocess.CompletedProcess:
	return subprocess.run(orden, capture_output=True, text=True, encoding="utf-8", errors="replace")


def slug(nombre: str) -> str:
	sin = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
	return re.sub(r"[^a-z0-9]+", "-", sin.lower()).strip("-") or "video"


def carpeta_de(arg: str) -> Path:
	ruta = Path(arg)
	if not ruta.is_absolute():
		ruta = CARPETA_TOMAS / arg
	if not ruta.is_dir():
		raise SystemExit(f"No existe la carpeta {ruta}")
	return ruta


def salida_de(carpeta: Path) -> Path:
	destino = PROYECTOS / slug(carpeta.name)
	destino.mkdir(parents=True, exist_ok=True)
	return destino


def listar_tomas(carpeta: Path) -> list[Path]:
	tomas = sorted(p for p in carpeta.iterdir() if p.suffix.lower() in EXTENSIONES)
	if not tomas:
		raise SystemExit(f"No hay tomas ({', '.join(EXTENSIONES)}) en {carpeta}")
	return tomas


def elegir_toma(carpeta: Path, ref: str) -> Path:
	tomas = listar_tomas(carpeta)
	if ref.isdigit() and 1 <= int(ref) <= len(tomas):
		return tomas[int(ref) - 1]
	for p in tomas:
		if p.name == ref or p.stem == ref:
			return p
	raise SystemExit(f"No encuentro la toma «{ref}» (usa el número del inventario o el nombre).")


def fotograma(ffmpeg: str, toma: str, t: float, destino: Path, filtro: str | None = None, calidad: int = 4) -> bool:
	orden = [ffmpeg, "-v", "error", "-y", "-ss", f"{max(t, 0):.3f}", "-i", toma, "-frames:v", "1"]
	if filtro:
		orden += ["-vf", filtro]
	r = correr(orden + ["-q:v", str(calidad), str(destino)])
	return r.returncode == 0 and destino.exists()


def sonda(ffprobe: str, toma: Path) -> dict:
	r = correr([ffprobe, "-v", "error", "-show_entries", "stream=codec_type,width,height,r_frame_rate:format=duration", "-of", "json", str(toma)])
	datos = json.loads(r.stdout)
	video = next(s for s in datos["streams"] if s["codec_type"] == "video")
	num, den = video["r_frame_rate"].split("/")
	return {
		"duracion": round(float(datos["format"]["duration"]), 3),
		"ancho": video["width"],
		"alto": video["height"],
		"fps": round(int(num) / int(den), 2),
		"audio": any(s["codec_type"] == "audio" for s in datos["streams"]),
	}


def clase_de(ffmpeg: str, toma: Path, duracion: float, tmp: Path) -> str:
	"""`studio` si la franja de arriba (5 % de la altura) es la barra clara de Studio (media > 215; medida: Studio 241, juego < 155)
	en todos los fotogramas muestreados, `juego` si en ninguno y `mixta` si en algunos (la toma cambia de una a otra: se mira por tramo)."""
	from PIL import Image, ImageStat

	votos = total = 0
	for f in (0.1, 0.3, 0.5, 0.7, 0.9):
		img = tmp / "clase.jpg"
		if not fotograma(ffmpeg, str(toma), duracion * f, img, "scale=640:-2"):
			continue
		total += 1
		with Image.open(img) as im:
			w, h = im.size
			if ImageStat.Stat(im.crop((0, 0, w, int(h * 0.05))).convert("L")).mean[0] > 215:
				votos += 1
	if votos == 0:
		return "juego"
	return "studio" if votos == total else "mixta"


def minutos(t: float) -> str:
	return f"{int(t) // 60}:{int(t) % 60:02d}"


def hojas(ffmpeg: str, candidatos: list[tuple[str, float, str]], destino: Path, prefijo: str, tmp: Path) -> list[Path]:
	"""Hojas de contacto de 4x4 miniaturas. candidatos: (ruta de la toma, segundo, etiqueta). Devuelve las hojas escritas."""
	from PIL import Image, ImageDraw

	for vieja in destino.glob(f"{prefijo}-*.jpg"):
		vieja.unlink()
	ancho, alto = MINIATURA
	por_hoja = COLUMNAS * FILAS
	escritas = []
	for n, inicio in enumerate(range(0, len(candidatos), por_hoja), 1):
		grupo = candidatos[inicio : inicio + por_hoja]
		hoja = Image.new("RGB", (COLUMNAS * (ancho + 4) + 4, FILAS * (alto + 4) + 4), "black")
		for i, (ruta, t, etiqueta) in enumerate(grupo):
			mini = tmp / "mini.jpg"
			if not fotograma(ffmpeg, ruta, t, mini, f"scale={ancho}:{alto}"):
				continue
			with Image.open(mini) as im:
				im = im.copy()
			d = ImageDraw.Draw(im)
			d.rectangle((0, alto - 14, 8 * len(etiqueta) + 6, alto), fill="black")
			d.text((3, alto - 13), etiqueta, fill="yellow")
			hoja.paste(im, (4 + (i % COLUMNAS) * (ancho + 4), 4 + (i // COLUMNAS) * (alto + 4)))
		salida = destino / f"{prefijo}-{n}.jpg"
		hoja.save(salida, quality=80)
		escritas.append(salida)
	return escritas


def cmd_inventario(a: argparse.Namespace) -> int:
	carpeta = carpeta_de(a.carpeta)
	destino = salida_de(carpeta)
	tmp = destino / "tmp"
	tmp.mkdir(exist_ok=True)
	ffmpeg, ffprobe = buscar("ffmpeg"), buscar("ffprobe")
	tomas = []
	candidatos = []
	for n, p in enumerate(listar_tomas(carpeta), 1):
		info = sonda(ffprobe, p)
		info["n"] = n
		info["archivo"] = p.name
		info["clase"] = clase_de(ffmpeg, p, info["duracion"], tmp)
		tomas.append(info)
		t = 0.0
		while t < info["duracion"]:
			candidatos.append((str(p), t, f"T{n} {minutos(t)}"))
			t += SALTO_GRUESO
		print(f"{n}  {p.name}  {minutos(info['duracion'])}  {info['ancho']}x{info['alto']} {info['fps']:g}fps  {info['clase']}")
	(destino / "inventario.json").write_text(json.dumps({"carpeta": str(carpeta), "tomas": tomas}, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="")
	for h in hojas(ffmpeg, candidatos, destino, "gruesa", tmp):
		print("Hoja:", h)
	print(f"Total: {minutos(sum(t['duracion'] for t in tomas))} en {len(tomas)} tomas. Inventario en {destino / 'inventario.json'} (la clase se puede corregir a mano).")
	return 0


def escenas(ffmpeg: str, toma: Path, umbral: float) -> list[float]:
	filtro = f"fps=4,scale=320:-2,select=gt(scene\\,{umbral}),metadata=print:file=-"
	r = correr([ffmpeg, "-v", "error", "-i", str(toma), "-an", "-vf", filtro, "-f", "null", "-"])
	return [float(m.group(1)) for m in re.finditer(r"pts_time:([\d.]+)", r.stdout)]


def picos_sonido(ffmpeg: str, toma: Path) -> list[float]:
	"""Segundos con el sonido más fuerte que el resto (golpes, explosiones): RMS por segundo, 6 dB sobre la mediana, los 10 mayores."""
	filtro = "aresample=8000,asetnsamples=n=8000:p=0,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-"
	r = correr([ffmpeg, "-v", "error", "-i", str(toma), "-vn", "-af", filtro, "-f", "null", "-"])
	tiempos = [float(x) for x in re.findall(r"pts_time:([\d.]+)", r.stdout)]
	niveles = []
	for x in re.findall(r"RMS_level=(\S+)", r.stdout):
		niveles.append(-120.0 if "inf" in x or "nan" in x else float(x))
	pares = sorted(zip(tiempos, niveles), key=lambda p: p[0])
	if not pares:
		return []
	ordenados = sorted(n for _, n in pares)
	mediana = ordenados[len(ordenados) // 2]
	fuertes = sorted((p for p in pares if p[1] > mediana + 6), key=lambda p: -p[1])
	elegidos: list[float] = []
	for t, _ in fuertes:
		if all(abs(t - e) >= 5 for e in elegidos):
			elegidos.append(t)
		if len(elegidos) == 10:
			break
	return sorted(elegidos)


def cmd_explorar(a: argparse.Namespace) -> int:
	carpeta = carpeta_de(a.carpeta)
	destino = salida_de(carpeta)
	tmp = destino / "tmp"
	tmp.mkdir(exist_ok=True)
	ffmpeg, ffprobe = buscar("ffmpeg"), buscar("ffprobe")
	cache = destino / "cache"
	cache.mkdir(exist_ok=True)
	candidatos: list[tuple[str, float, str]] = []
	resumen = []
	for n, p in enumerate(listar_tomas(carpeta), 1):
		clave = {"umbral": a.umbral, "tam": p.stat().st_size, "version": 1}
		archivo = cache / f"{p.stem}.json"
		datos = None
		if archivo.exists():
			previo = json.loads(archivo.read_text(encoding="utf-8"))
			if previo.get("clave") == clave:
				datos = previo
		if datos is None:
			print(f"Explorando {n}: {p.name}…", flush=True)
			datos = {"clave": clave, "duracion": comun.duracion(ffprobe, str(p)), "escenas": escenas(ffmpeg, p, a.umbral), "picos": picos_sonido(ffmpeg, p)}
			archivo.write_text(json.dumps(datos, indent="\t"), encoding="utf-8", newline="")
		marcas: dict[float, str] = {}
		t = 0.0
		while t < datos["duracion"]:
			marcas[round(t, 1)] = ""
			t += SALTO_RELLENO
		for t in datos["escenas"]:
			marcas[round(t, 1)] = ""
		for t in datos["picos"]:
			marcas[round(t, 1)] = "!"
		previo_t = -99.0
		for t in sorted(marcas):
			if t - previo_t < HUECO_MIN and not marcas[t]:
				continue
			previo_t = t
			candidatos.append((str(p), t, f"T{n} {minutos(t)}{marcas[t]}"))
		resumen.append((n, p.name, len(datos["escenas"]), len(datos["picos"])))
	tope = a.hojas_max * COLUMNAS * FILAS
	if len(candidatos) > tope:
		paso = len(candidatos) / tope
		candidatos = [candidatos[int(i * paso)] for i in range(tope)]
	for n, nombre, e, pk in resumen:
		print(f"{n}  {nombre}: {e} cambios de escena, {pk} picos de sonido (! en la hoja)")
	for h in hojas(ffmpeg, candidatos, destino, "explorar", tmp):
		print("Hoja:", h)
	return 0


def cmd_detalle(a: argparse.Namespace) -> int:
	carpeta = carpeta_de(a.carpeta)
	destino = salida_de(carpeta) / "detalle"
	destino.mkdir(exist_ok=True)
	ffmpeg = buscar("ffmpeg")
	toma = elegir_toma(carpeta, a.toma)
	corte = {"cx": a.cx, "cy": a.cy, "zoom": a.zoom, "clase": a.clase}
	for i, tramo in enumerate(a.tramos.split(","), 1):
		desde, dura = (float(x) for x in tramo.split("+"))
		tira = tira_de_corte(ffmpeg, str(toma), desde, dura, corte, a.formato, destino / f"{i:02d}")
		print(f"Tramo {i} ({toma.name} {desde}+{dura}):", tira)
	return 0


def tira_de_corte(ffmpeg: str, toma: str, desde: float, dura: float, corte: dict, formato: str, base: Path) -> Path:
	"""Tres fotogramas (inicio, medio y final) recortados con el recuadro del corte, uno al lado del otro."""
	from PIL import Image

	cw, ch = FORMATOS[formato][:2]
	pw, ph = cw // 4, ch // 4
	cx, cy, _, _, w, h = recuadro(corte, formato)
	x0, y0 = cx * TOMA_W - w / 2, cy * TOMA_H - h / 2
	filtro = f"crop={w:.0f}:{h:.0f}:{x0:.0f}:{y0:.0f},scale={pw}:{ph}"
	partes = []
	for k, f in enumerate((0.02, 0.5, 0.98)):
		img = base.parent / f"{base.name}-{k}.jpg"
		if fotograma(ffmpeg, toma, desde + dura * f, img, filtro, 5):
			partes.append(img)
	tira = Image.new("RGB", (3 * (pw + 4) + 4, ph + 8), "black")
	for k, img in enumerate(partes):
		with Image.open(img) as im:
			tira.paste(im, (4 + k * (pw + 4), 4))
		img.unlink()
	salida = base.parent / f"{base.name}.jpg"
	tira.save(salida, quality=80)
	return salida


def datauri(ruta: Path) -> str:
	return "data:image/jpeg;base64," + base64.b64encode(ruta.read_bytes()).decode()


def cmd_storyboard(a: argparse.Namespace) -> int:
	guion = json.loads(a.guion.read_text(encoding="utf-8"))
	formato = guion.get("formato", "short")
	ffmpeg = buscar("ffmpeg")
	cw, ch = lienzo(guion)
	destino = PROYECTOS / guion["id"]
	destino.mkdir(parents=True, exist_ok=True)
	filas = []
	t = 0.0
	for i, c in enumerate(guion["cortes"], 1):
		if c["toma"] == "portada":
			salida = c["dura"]
			img = destino / f"corte-{i:02d}.jpg"
			from PIL import Image

			with Image.open(comun.RAIZ / "art" / "portada" / "portada-principal-1920x1080.png") as im:
				pw, ph = (cw // 4, ch // 4)
				fondo = Image.new("RGB", (pw, ph), "black")
				mini = im.convert("RGB").resize((pw, int(pw * 9 / 16)))
				fondo.paste(mini, (0, (ph - mini.height) // 2))
				tira = Image.new("RGB", (3 * (pw + 4) + 4, ph + 8), "black")
				for k in range(3):
					tira.paste(fondo, (4 + k * (pw + 4), 4))
				tira.save(img, quality=80)
			origen = "Portada del juego"
		else:
			vel = c.get("velocidad", 1.0)
			salida = c["dura"] / vel
			img = tira_de_corte(ffmpeg, ruta_toma(guion, c), c["desde"], c["dura"], c, formato, destino / f"corte-{i:02d}")
			origen = f"{Path(c['toma']).name} · desde {c['desde']:.1f} s · {c['dura']:.1f} s" + (f" · ×{vel:g}" if vel != 1.0 else "") + (f" · {c['clase']}" if c.get("clase") else "")
		fin = t + salida
		dentro = lambda x: x["en"] < fin - 0.01 and x["en"] + x["dura"] > t + 0.01  # noqa: E731
		textos = {lg: [x["texto"].replace("\n", " ") for x in lista if dentro(x)] for lg, lista in guion.get("textos", {}).items()}
		voz = {lg: [x["texto"] for x in lista if dentro(x)] for lg, lista in guion.get("voz", {}).items()}
		filas.append({"n": i, "t": f"{t:.1f}–{fin:.1f} s", "origen": origen, "nota": c.get("nota", ""), "img": datauri(img), "textos": textos, "voz": voz})
		t = fin
	pagina = pagina_storyboard(guion, formato, t, filas)
	salida = destino / "storyboard.html"
	salida.write_text(pagina, encoding="utf-8", newline="")
	print(f"Storyboard: {salida} ({salida.stat().st_size // 1024} KB, {t:.1f} s)")
	return 0


def e(texto: str) -> str:
	return html.escape(texto, quote=True)


def pagina_storyboard(guion: dict, formato: str, total: float, filas: list[dict]) -> str:
	cw, ch, minimo, maximo = FORMATOS[formato]
	aviso = "" if minimo <= total <= maximo else f'<p class="aviso">Dura {total:.1f} s: un {formato} dura entre {minimo:.0f} y {maximo:.0f} s.</p>'
	cuerpo = []
	for f in filas:
		lineas = []
		for etiqueta, grupo in (("Texto", f["textos"]), ("Voz", f["voz"])):
			for lg, lista in grupo.items():
				if lista:
					lineas.append(f'<p><b>{etiqueta} {lg.upper()}</b> {e(" · ".join(lista))}</p>')
		cuerpo.append(
			f'<article><img src="{f["img"]}" alt="Corte {f["n"]}: inicio, medio y final"><div><h2>{f["n"]} <small>{f["t"]}</small></h2>'
			f'<p class="origen">{e(f["origen"])}</p><p>{e(f["nota"])}</p>{"".join(lineas)}</div></article>'
		)
	musica = guion.get("musica")
	pie = f'<p><b>Música</b> {e(Path(musica["pista"]).name)} a {musica.get("volumen", 0.3)}</p>' if musica else "<p><b>Música</b> ninguna (la pones tú en CapCut)</p>"
	faltan = guion.get("faltan", [])
	if faltan:
		items = "".join(f"<li><b>{e(x.get('plano', ''))}</b>. {e(x.get('como', ''))} <i>Sustituto: {e(x.get('sustituto', '—'))}</i></li>" for x in faltan)
		pie += f"<h2>Tomas por grabar</h2><ul>{items}</ul>"
	return f"""<title>{e(guion.get('titulo', guion['id']))}</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
:root{{--bg:#f6f5f1;--card:#fff;--tx:#1d1d1b;--mut:#6b6a63;--ac:#b45309;--ln:#e3e1d8}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#161614;--card:#222220;--tx:#efeee8;--mut:#a3a199;--ac:#f0a35a;--ln:#38372f;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#161614;--card:#222220;--tx:#efeee8;--mut:#a3a199;--ac:#f0a35a;--ln:#38372f;color-scheme:dark}}
body{{margin:0;background:var(--bg);color:var(--tx);font:16px/1.45 system-ui,sans-serif;padding-block:20px 48px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}}
main{{max-width:980px;margin:0 auto}}
h1{{margin:0 0 4px;font-size:1.5rem;text-wrap:balance}} h2{{font-size:1.05rem;margin:0 0 4px}} small{{color:var(--mut);font-weight:400}}
.meta{{color:var(--mut);margin:0 0 20px}} .aviso{{color:var(--ac);font-weight:600}}
article{{display:flex;gap:16px;align-items:flex-start;background:var(--card);border:1px solid var(--ln);border-radius:10px;padding:12px;margin:0 0 12px}}
article img{{flex:0 0 auto;width:56%;max-width:100%;height:auto;border-radius:6px}}
article div{{min-width:0}} article p{{margin:2px 0}} .origen{{color:var(--mut);font-size:.9rem}}
@media (max-width:640px){{article{{flex-direction:column}}article img{{width:100%}}}}
</style>
<main>
<h1>{e(guion.get('titulo', guion['id']))}</h1>
<p class="meta">{formato} · {cw}×{ch} · {total:.1f} s · {len(filas)} cortes · inicio, medio y final de cada corte con el recuadro</p>{aviso}
{''.join(cuerpo)}{pie}
</main>
"""


def main() -> int:
	ap = argparse.ArgumentParser()
	sub = ap.add_subparsers(dest="orden", required=True)
	s = sub.add_parser("inventario")
	s.add_argument("carpeta")
	s.set_defaults(f=cmd_inventario)
	s = sub.add_parser("explorar")
	s.add_argument("carpeta")
	s.add_argument("--umbral", type=float, default=UMBRAL_ESCENA)
	s.add_argument("--hojas-max", type=int, default=8)
	s.set_defaults(f=cmd_explorar)
	s = sub.add_parser("detalle")
	s.add_argument("carpeta")
	s.add_argument("toma")
	s.add_argument("tramos", help="desde+dura separados por comas, p. ej. 45+3.2,100+2")
	s.add_argument("--cx", type=float, default=0.5)
	s.add_argument("--cy", type=float, default=0.5)
	s.add_argument("--zoom", type=float, default=1.0)
	s.add_argument("--clase", choices=list(CLASES))
	s.add_argument("--formato", choices=list(FORMATOS), default="short")
	s.set_defaults(f=cmd_detalle)
	s = sub.add_parser("storyboard")
	s.add_argument("guion", type=Path)
	s.set_defaults(f=cmd_storyboard)
	a = ap.parse_args()
	return a.f(a)


if __name__ == "__main__":
	sys.exit(main())
