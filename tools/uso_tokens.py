"""Mide cuántos tokens gasta Claude Code en este proyecto, por sesión, por modelo y por herramienta.

Lee las transcripciones de ~/.claude/projects/<proyecto>/ (las sesiones y, dentro de cada una,
subagents/*.jsonl) y no escribe nada. Sirve para comparar el reparto de agentes de CLAUDE.md
con las sesiones de antes.

    python tools/uso_tokens.py              # las 10 últimas sesiones
    python tools/uso_tokens.py -n 40        # las 40 últimas
    python tools/uso_tokens.py <id>         # solo la sesión cuyo id empieza así

"Leídos de caché" es el contexto que se vuelve a leer en cada turno. Es la cifra que más crece
cuando la conversación principal se llena de salidas de grep, archivos y capturas.
"""

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Claude Code nombra la carpeta con la ruta del proyecto: letra de unidad en minúscula y "-" por cada separador.
PROJECT = str(ROOT).replace(":", "-").replace("\\", "-").replace("/", "-").replace("_", "-")
PROJECTS = Path.home() / ".claude" / "projects"

FIELDS = (
	("input_tokens", "entrada"),
	("cache_creation_input_tokens", "escritos a caché"),
	("cache_read_input_tokens", "leídos de caché"),
	("output_tokens", "salida"),
)
# Una imagen cuenta como unos 1.500 tokens; se pasa a caracteres (≈4 por token) para sumarla con el texto.
IMAGE_CHARS = 6000


def project_dir() -> Path:
	for d in PROJECTS.iterdir():
		if d.is_dir() and d.name.lower() == PROJECT.lower():
			return d
	raise SystemExit(f"No encuentro la carpeta de transcripciones {PROJECT} en {PROJECTS}")


def records(path: Path):
	with path.open(encoding="utf-8", errors="ignore") as f:
		for line in f:
			try:
				yield json.loads(line)
			except json.JSONDecodeError:
				continue


def result_chars(content) -> int:
	if not isinstance(content, list):
		return len(str(content or ""))
	total = 0
	for part in content:
		if part.get("type") == "text":
			total += len(part.get("text", ""))
		elif part.get("type") == "image":
			total += IMAGE_CHARS
	return total


def measure(path: Path, stats: dict) -> None:
	names = {}
	for rec in records(path):
		msg = rec.get("message") or {}
		if rec.get("type") == "assistant" and msg.get("usage"):
			model = msg.get("model") or "?"
			if model == "<synthetic>":
				continue
			stats["turns"][model] += 1
			for key, _ in FIELDS:
				stats["usage"][model][key] += msg["usage"].get(key) or 0
		content = msg.get("content")
		if not isinstance(content, list):
			continue
		for block in content:
			if block.get("type") == "tool_use":
				names[block["id"]] = block["name"]
				stats["calls"][block["name"]] += 1
			elif block.get("type") == "tool_result":
				name = names.get(block.get("tool_use_id"), "?")
				stats["chars"][name] += result_chars(block.get("content"))


def new_stats() -> dict:
	return {
		"turns": Counter(),
		"usage": defaultdict(Counter),
		"calls": Counter(),
		"chars": Counter(),
	}


def merge(whole: dict, part: dict) -> None:
	whole["turns"].update(part["turns"])
	whole["calls"].update(part["calls"])
	whole["chars"].update(part["chars"])
	for model, usage in part["usage"].items():
		whole["usage"][model].update(usage)



def fmt(n: int) -> str:
	return f"{n / 1e6:,.1f} M" if n >= 1e6 else f"{n / 1e3:,.0f} k"


def report(title: str, main: dict, subs: dict, tools: bool) -> None:
	print(f"\n=== {title}")
	for label, stats in (("principal", main), ("subagentes", subs)):
		for model, turns in stats["turns"].most_common():
			u = stats["usage"][model]
			per_turn = u["cache_read_input_tokens"] // max(turns, 1)
			parts = ", ".join(f"{name} {fmt(u[key])}" for key, name in FIELDS[1:])
			print(f"  {label:10} {model:22} {turns:6} turnos | {parts} | {fmt(per_turn)} por turno")
	if not tools:
		return
	print("  Herramientas (principal): llamadas y caracteres que devolvieron")
	for name, chars in main["chars"].most_common(12):
		print(f"    {main['calls'][name]:6}  {chars // 1000:7} k  {name}")


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("session", nargs="?", help="comienzo del id de una sesión")
	parser.add_argument("-n", type=int, default=10, help="número de sesiones recientes (por defecto 10)")
	args = parser.parse_args()
	sys.stdout.reconfigure(encoding="utf-8")

	folder = project_dir()
	sessions = sorted(folder.glob("*.jsonl"), key=lambda p: p.stat().st_mtime)
	if args.session:
		sessions = [p for p in sessions if p.stem.startswith(args.session)]
	else:
		sessions = sessions[-args.n :]

	total_main, total_subs = new_stats(), new_stats()
	for path in sessions:
		main_stats, sub_stats = new_stats(), new_stats()
		measure(path, main_stats)
		for sub in (folder / path.stem / "subagents").glob("*.jsonl"):
			measure(sub, sub_stats)
		for whole, part in ((total_main, main_stats), (total_subs, sub_stats)):
			merge(whole, part)
		report(path.stem[:8], main_stats, sub_stats, tools=bool(args.session))

	report(f"Total de {len(sessions)} sesiones", total_main, total_subs, tools=True)

if __name__ == "__main__":
	main()
