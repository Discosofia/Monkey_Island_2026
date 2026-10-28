"""Comprueba los textos traducibles del juego (Shared/Strings, GDD §18).

Sin opciones: busca en src/ las frases de T("…"), Strings.t("…"), Strings.later("…"), Toast.show("…"),
Remotes.Notify y los ActionText, ObjectText y ToolTip fijos (y los campos de texto de Data que dice
DATA_FIELDS), las compara con las tablas inglesas de src/shared/Data/Strings/*.luau y avisa de:
  - frases sin inglés en las rutas de COVERED (las ya traducidas),
  - entradas inglesas que ya no usa nadie (alguien retocó el español) o que están en dos tablas,
  - argumentos {x} distintos entre el español y el inglés,
  - T(` … `) con interpolación, que no se puede traducir.
Sale con error si hay alguna. Lo ejecuta el CI.

Opciones:
  --missing [rutas…]   imprime las frases sin inglés como entradas de Luau, para pegarlas en una tabla.
  --audit [rutas…]     lista los textos entre comillas que parecen españoles y no pasan por T().
  --review [rutas…]    imprime en JSON las frases (es, en) de esas rutas, agrupadas por archivo.
  --csv ARCHIVO        escribe la LocalizationTable para Creator Hub (Key, Context, Example, Source, es).
"""

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TABLES = SRC / "shared" / "Data" / "Strings"

# Se quedan solo en español (decidido en el plan de I1): herramientas de desarrollo y administración.
EXCLUDED = [
    "src/island/tools/",
    "src/island/server/Services/DebugService.luau",
    "src/shared/DebugCommands.luau",
    "src/shared/UI/AdminPanel.luau",
    "src/shared/UI/DebugPanel.luau",
    "src/serverShared/Admin.luau",
    "src/serverShared/AdminLog.luau",
    "src/serverShared/AdminNet.luau",
    "src/serverShared/AdminProfile.luau",
    "src/serverShared/GearShowcase.luau",
    "src/lobby/server/Services/AdminService.luau",
    "src/dunas/server/Services/ArenaDebugService.luau",
    "src/lobby/server/Services/DebugService.luau",
    "src/lobby/client/Controllers/AdminController.luau",
    "src/lobby/client/Controllers/DebugController.luau",
    "src/shared/Data/Strings/",
]

# Rutas ya pasadas a T(): en ellas una frase sin inglés es un error. Cada tanda de la I1 añade las suyas.
COVERED = [
    "src/shared/",
    "src/combatClient/",
    "src/island/",
    "src/lobby/",
    "src/serverShared/",
    "src/dunas/",
    "src/combat/",
]

# Campos de Data que se traducen por su nombre (T(def.name)): archivo → campos.
DATA_FIELDS: dict[str, list[str]] = {
    "src/shared/Data/ArenaGear.luau": ["name", "description", "Weapon", "Armor", "Amulet"],
    "src/shared/Data/Armor.luau": ["name", "Cazador", "Mago", "Medico"],
    "src/shared/Data/Bosses.luau": ["name", "description"],
    "src/shared/Data/Buildables.luau": ["name", "description"],
    "src/shared/Data/Combos.luau": ["name", "mark", "finisher", "short"],
    "src/shared/Data/Contracts.luau": ["name", "description", "title", "text"],
    "src/shared/Data/Cosmetics.luau": ["name", "description", "title"],
    "src/shared/Data/Items.luau": ["name", "note"],
    "src/shared/Data/LiveEvents.luau": ["name", "detail"],
    "src/shared/Data/MidEvents.luau": ["name", "eve", "start", "status"],
    "src/shared/Data/Missions.luau": ["text"],
    "src/shared/Data/Monkeys.luau": ["name", "description"],
    "src/shared/Data/Mounts.luau": ["name", "shortName", "description", "label", "origin"],
    "src/shared/Data/Pets.luau": ["name", "description", "kind"],
    "src/shared/Data/PlotStructures.luau": ["name", "description", "effect", "CHEST_EFFECT"],
    "src/shared/Data/Rarities.luau": ["name"],
    "src/shared/Data/Recipes.luau": ["name", "description"],
    "src/shared/Data/ResourceNodes.luau": ["name", "actionText"],
    "src/shared/Data/Roles.luau": ["name", "short", "description", "passive", "edge"],
    "src/shared/Data/Seasons.luau": ["name"],
    "src/shared/Data/Stations.luau": ["name", "actionText"],
    "src/shared/Data/Talents.luau": ["name", "description"],
    "src/shared/Data/Upgrades.luau": ["name", "description"],
    "src/shared/Data/Weapons.luau": ["name"],
}

STRING = r'"((?:[^"\\\n]|\\.)*)"'
CALLS = [
    re.compile(r"\bT\(\s*" + STRING),
    re.compile(r"\bStrings\.t\(\s*" + STRING),
    re.compile(r"\b(?:Strings\.later|later)\(\s*" + STRING),
    re.compile(r"\bToast\.show\(\s*" + STRING),
    re.compile(r"\bNotify:FireClient\(\s*[\w.\[\]:()]+\s*,\s*" + STRING),
    re.compile(r"\bNotify:FireAllClients\(\s*" + STRING),
    re.compile(r"\bsetWorldText\(\s*[\w.\[\]]+\s*,\s*" + STRING),
    re.compile(r"\bStrings\.pack\(\s*" + STRING),
    re.compile(r"\bStrings\.forPlayer\(\s*[\w.]+\s*,\s*" + STRING),
    # Las funciones locales notify(jugadores, "…", args) que avisan por Remotes.Notify.
    re.compile(r"\bnotify\(\s*[\w.\[\]{} ]+\s*,\s*" + STRING),
    # Las funciones locales de los servicios de la Isla que avisan a todos o ponen una línea del HUD.
    re.compile(r"\b(?:announce|setStatus)\(\s*" + STRING.replace(")*", ")+", 1)),
    re.compile(r"\bsetText\(\s*[\w.\[\]]+\s*,\s*\"\w+\"\s*,\s*" + STRING),
    re.compile(r"\b(?:ActionText|ObjectText|ToolTip)\s*=\s*" + STRING),
]
INTERPOLATED = re.compile(r"\b(?:T|Strings\.t)\(\s*`")
ENTRY = re.compile(r"^\s*\[" + STRING + r"\]\s*=\s*" + STRING + r"\s*,?\s*$")
ARG = re.compile(r"\{([\w]+)\}")
SPANISH = re.compile(r"[áéíóúñ¿¡ÁÉÍÓÚÑ]|\b[A-Za-záéíóúñ]{2,} [a-záéíóúñ]{2,}\b")
NOT_UI = re.compile(
    r"\b(print|warn|error|assert|require|GetAttribute|SetAttribute|FindFirstChild|WaitForChild|GetService"
    r"|FindFirstAncestor|Name\s*=|\.Name\b|DataStore|:Get\(|tag|Tag)\b"
)


def decode(text: str) -> str:
    """Las secuencias de escape de Luau que se usan en los textos."""
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), text)


def encode(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def key(es: str) -> str:
    """FNV-1a de 32 bits, como Strings.key."""
    h = 2166136261
    for b in es.encode("utf-8"):
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return f"{h:08x}"


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def source_files(paths: list[str] | None = None):
    for path in sorted(SRC.rglob("*.luau")):
        name = rel(path)
        if any(name.startswith(prefix) for prefix in EXCLUDED):
            continue
        if paths and not any(name.startswith(p.replace("\\", "/").rstrip("/")) for p in paths):
            continue
        yield path, name


def strip_comment(line: str) -> str:
    """Quita el comentario de una línea sin cortar los textos que llevan "--"."""
    in_string = None
    i = 0
    while i < len(line):
        c = line[i]
        if in_string:
            if c == "\\":
                i += 1
            elif c == in_string:
                in_string = None
        elif c in "\"'`":
            in_string = c
        elif line.startswith("--", i):
            return line[:i]
        i += 1
    return line


def used_phrases(paths: list[str] | None = None):
    """{español: [archivo:línea, …]} y la lista de T(` … `)."""
    phrases: dict[str, list[str]] = {}
    interpolated: list[str] = []
    for path, name in source_files(paths):
        text = path.read_text(encoding="utf-8")
        code = "\n".join(strip_comment(line) for line in text.split("\n"))
        for pattern in CALLS:
            for match in pattern.finditer(code):
                line = code.count("\n", 0, match.start()) + 1
                phrases.setdefault(decode(match.group(1)), []).append(f"{name}:{line}")
        for match in INTERPOLATED.finditer(code):
            interpolated.append(f"{name}:{code.count(chr(10), 0, match.start()) + 1}")
        fields = DATA_FIELDS.get(name)
        if fields:
            # El texto puede seguir en las líneas de abajo ("…" .. "…").
            field = re.compile(r"\b(?:" + "|".join(fields) + r")\s*=\s*(" + STRING + r"(?:\s*\.\.\s*" + STRING + r")*)")
            for match in field.finditer(code):
                line = code.count("\n", 0, match.start()) + 1
                es = "".join(decode(part) for part in re.findall(STRING, match.group(1)))
                phrases.setdefault(es, []).append(f"{name}:{line}")
    return phrases, interpolated


# Frases que están en más de una tabla (al cargarlas, la segunda pisa a la primera).
repeated: list[str] = []


def english_tables():
    """{español: (inglés, tabla)}."""
    entries: dict[str, tuple[str, str]] = {}
    repeated.clear()
    for path in sorted(TABLES.glob("*.luau")):
        for line in path.read_text(encoding="utf-8").split("\n"):
            match = ENTRY.match(line)
            if match:
                es = decode(match.group(1))
                if es in entries:
                    repeated.append(f"{es!r} en Data/Strings/{entries[es][1]} y {path.stem}")
                entries[es] = (decode(match.group(2)), path.stem)
    return entries


def check() -> int:
    phrases, interpolated = used_phrases()
    english = english_tables()
    problems = 0
    for es, places in sorted(phrases.items()):
        if not any(place.startswith(prefix) for place in places for prefix in COVERED):
            continue
        if es not in english:
            print(f"Sin inglés: {es!r}  ({places[0]})")
            problems += 1
        elif sorted(set(ARG.findall(es))) != sorted(set(ARG.findall(english[es][0]))):
            print(f"Argumentos distintos: {es!r} → {english[es][0]!r}  ({places[0]})")
            problems += 1
    for es, (_, table) in sorted(english.items()):
        if es not in phrases:
            print(f"Entrada sin uso en Data/Strings/{table}: {es!r}")
            problems += 1
    for entry in repeated:
        print(f"Entrada repetida: {entry}")
        problems += 1
    for place in interpolated:
        print(f"T() con interpolación (usa una plantilla y argumentos): {place}")
        problems += 1
    print(f"{len(phrases)} frases, {len(english)} en inglés, {problems} problemas.")
    return 1 if problems else 0


def missing(paths: list[str]) -> int:
    phrases, _ = used_phrases(paths or None)
    english = english_tables()
    for es in sorted(phrases):
        if es not in english:
            print(f'\t["{encode(es)}"] = "",')
    return 0


def audit(paths: list[str]) -> int:
    count = 0
    for path, name in source_files(paths or None):
        for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            code = strip_comment(line)
            if NOT_UI.search(code):
                continue
            for match in re.finditer(r'"((?:[^"\\]|\\.)*)"|`((?:[^`\\]|\\.)*)`', code):
                text = match.group(1) if match.group(1) is not None else match.group(2)
                if not SPANISH.search(text):
                    continue
                before = code[: match.start()]
                if re.search(r"\b(?:T|Strings\.t|Toast\.show|FireClient|FireAllClients)\([^()]*$", before):
                    continue
                print(f"{name}:{number}: {text}")
                count += 1
    print(f"{count} textos sin T().")
    return 0


def review(paths: list[str]) -> int:
    phrases, _ = used_phrases(paths or None)
    english = english_tables()
    groups: dict[str, list[dict[str, str]]] = {}
    for es, places in sorted(phrases.items(), key=lambda item: item[1][0]):
        file = places[0].rsplit(":", 1)[0]
        groups.setdefault(file, []).append({"es": es, "en": english.get(es, ("", ""))[0]})
    print(json.dumps(groups, ensure_ascii=False, indent=1))
    return 0


def write_csv(out: str) -> int:
    phrases, _ = used_phrases()
    english = english_tables()
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["Key", "Context", "Example", "Source", "es"])
        for es, places in sorted(phrases.items()):
            if es in english:
                writer.writerow([key(es), places[0], "", english[es][0], es])
    print(f"Escrito {out}.")
    return 0


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    if not argv:
        return check()
    option, rest = argv[0], argv[1:]
    if option == "--missing":
        return missing(rest)
    if option == "--audit":
        return audit(rest)
    if option == "--review":
        return review(rest)
    if option == "--csv" and rest:
        return write_csv(rest[0])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
