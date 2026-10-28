"""Comprueba que cada icono significa una sola cosa (regla "Un icono, una sola cosa" de CLAUDE.md).

Avisa si en Data/Items:
  - dos objetos comparten icono, o tienen dos que se confunden (LOOKALIKE),
  - un objeto usa un icono reservado (RESERVED: el Ámbar y las barras),
  - un objeto comparte icono con un construible, una estación o una estructura de la parcela
    (Data/Buildables, Data/Stations, Data/PlotStructures), salvo lo que dice ALLOWED.
Sale con error si hay alguno. Lo ejecuta el CI.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "src" / "shared" / "Data"

# Iconos que ya significan otra cosa en todo el juego.
RESERVED = {
    "✨": "el Ámbar",
    "🍖": "la barra de hambre",
    "💧": "la barra de sed",
}

# Iconos distintos que de un vistazo se confunden: cuentan como el mismo.
LOOKALIKE = [
    {"🔺", "🔻"},
    {"🔶", "🔸"},
    {"🔷", "🔹"},
    {"🌿", "🌱", "☘️", "🍀"},
    {"⚪", "⬜", "▫️", "◻️", "◽"},
    {"⚫", "⬛", "▪️", "◼️", "◾"},
]

# Objeto y edificio que pueden compartir icono porque son lo mismo o el edificio lo da.
ALLOWED = {
    ("Torch", "Buildables.StandingTorch"),
    ("Torch", "Stations.Campfire"),
    ("Banana", "PlotStructures.Garden"),
}

ENTRY = re.compile(r"^\t(\w+) = \{", re.MULTILINE)
ICON = re.compile(r'icon = "([^"]+)"')


def icons_of(name: str) -> dict[str, str]:
    """Primer icono de cada entrada de primer nivel de Data/<name>.luau."""
    text = (DATA / f"{name}.luau").read_text(encoding="utf-8")
    starts = list(ENTRY.finditer(text))
    result = {}
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        icon = ICON.search(text, match.end(), end)
        if icon:
            result[match.group(1)] = icon.group(1)
    return result


def family(icon: str) -> str:
    """El icono que representa a todos los que se confunden con este."""
    for group in LOOKALIKE:
        if icon in group:
            return min(group)
    return icon


def main() -> int:
    items = icons_of("Items")
    errors = []

    seen: dict[str, str] = {}
    for item_id, icon in items.items():
        if icon in RESERVED:
            errors.append(f"Items.{item_id} usa {icon}, que es {RESERVED[icon]}")
        key = family(icon)
        if key in seen:
            other = seen[key]
            errors.append(f"Items.{item_id} ({icon}) se confunde con Items.{other} ({items[other]})")
        else:
            seen[key] = item_id

    for source in ("Buildables", "Stations", "PlotStructures"):
        for entry_id, icon in icons_of(source).items():
            owner = seen.get(family(icon))
            if owner and (owner, f"{source}.{entry_id}") not in ALLOWED:
                errors.append(f"{source}.{entry_id} ({icon}) se confunde con Items.{owner} ({items[owner]})")

    for error in errors:
        print(error)
    if errors:
        print(f"\n{len(errors)} iconos repetidos: cambia uno o, si es lo mismo, añádelo a ALLOWED.")
        return 1
    print(f"Iconos: {len(items)} objetos, ninguno repetido.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
