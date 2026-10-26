"""Genera los presets de LM Studio ("Monos – …") a partir de los resúmenes de esta carpeta.

Cada preset lleva como prompt de sistema base.md más el resumen de su tarea. También copia base.md
a AGENTS.md en la raíz del repo, que es donde CodeGPT lee sus instrucciones. Vuelve a ejecutarlo
cuando cambie alguno de los .md:

    python docs/llm-local/generar_presets.py
"""

import json
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
DESTINO = Path.home() / ".lmstudio" / "config-presets"
AGENTS = CARPETA.parent.parent / "AGENTS.md"
AVISO = "<!-- Generado por docs/llm-local/generar_presets.py a partir de docs/llm-local/base.md. No lo edites aquí. -->\n\n"

# id del preset, nombre visible, resumen y temperatura (más baja para el código, más alta para las ideas)
PRESETS = [
	("monos-modelos", "Monos – Modelos", "modelos.md", 0.6),
	("monos-animaciones", "Monos – Animaciones", "animaciones.md", 0.6),
	("monos-interfaz", "Monos – Interfaz", "interfaz.md", 0.6),
	("monos-combate", "Monos – Combate", "combate.md", 0.5),
	("monos-economia", "Monos – Economía", "economia.md", 0.5),
	("monos-diseno", "Monos – Diseño", "diseno.md", 1.0),
	("monos-auditoria", "Monos – Auditoría", "auditoria.md", 0.3),
]


def leer(nombre: str) -> str:
	return (CARPETA / nombre).read_text(encoding="utf-8")


def main() -> None:
	DESTINO.mkdir(parents=True, exist_ok=True)
	base = leer("base.md")
	for ident, nombre, resumen, temperatura in PRESETS:
		preset = {
			"identifier": f"@local:{ident}",
			"name": nombre,
			"changed": False,
			"operation": {
				"fields": [
					{"key": "llm.prediction.systemPrompt", "value": base + "\n\n---\n\n" + leer(resumen)},
					{"key": "llm.prediction.temperature", "value": temperatura},
				]
			},
			"load": {"fields": []},
		}
		ruta = DESTINO / f"{ident}.preset.json"
		with open(ruta, "w", encoding="utf-8", newline="") as f:
			json.dump(preset, f, ensure_ascii=False, indent=2)
		print(f"{nombre}: {ruta}")
	with open(AGENTS, "w", encoding="utf-8", newline="") as f:
		f.write(AVISO + base)
	print(f"CodeGPT: {AGENTS}")


if __name__ == "__main__":
	main()
