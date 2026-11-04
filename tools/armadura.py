"""Papeleo de las mallas de las armaduras y los trajes (Fase 20, Q6): del volcado de Studio a `Data/ArmorMeshes.luau`.

Cada "clave" es una armadura con su rol (`Armor_FurVest_Guerrero`) o un traje con su grado (`Outfit_BlueFireStalkerOutfit_4`).
Una malla por parte del cuerpo y clase de material: grupos `<Anclaje>_<Soft|Hard>` (RightUpperArm_Hard, UpperTorso_Soft…),
sin espejos (la izquierda y la derecha son diseños propios).

Flujo por tanda:
  1. En el Studio de la Isla (Edit), con el diseño aprobado:
         local m = game.ServerStorage.Tools.Mallas:Clone()
         local shared = game.ReplicatedStorage.Shared:Clone()
         require(m).volcarArmadura("FurVest", "Guerrero", shared)                        -- una armadura
         require(m).volcarArmadura(nil, "Cazador", shared, "BlueFireStalkerOutfit", 4)   -- un traje y su grado
         m:Destroy()
  2. python tools/armadura.py exportar Armor_FurVest_Guerrero
         junta el volcado del log del Studio en tools/mallas/<clave>.txt (y los tamaños de ancla `@@REF` en
         tools/mallas/<clave>.ref.json), convierte con tools/mallas.py (`--fino 0.07 --texel 0.01`, sin espejos) y lista los
         .obj de build/mallas/<clave> que hay que importar (Import 3D, escala por defecto).
  3. El usuario importa y, en el Studio de la Isla (Edit), se lista lo importado:
         local out = {}
         for _, d in workspace:GetChildren() do
             local mp = d:FindFirstChildWhichIsA("MeshPart", true)
             if mp then out[#out + 1] = d.Name .. " | " .. mp.MeshId .. " | " .. mp.TextureID end
         end
         return table.concat(out, "\\n")
     Se guarda en un archivo de texto (una línea `Clave_Grupo | rbxassetid://… | rbxassetid://…` por malla; p. ej.
     `Armor_FurVest_Guerrero_RightUpperArm_Hard | … | …`).
  4. python tools/armadura.py ids Armor_FurVest_Guerrero --texto ids.txt
         escribe (o sustituye) la entrada de cada clave en src/shared/Data/ArmorMeshes.luau con sus ids, `ref` (volcado) y
         `offset`, `size` y `triangles` (manifiesto), y avisa de lo que falte. Las entradas quedan entre las marcas
         `-- @entrada <Tipo> <id> <sub>` y `-- @fin`: no las quites, así las demás claves se conservan.
         Luego: stylua src/shared && selene src

Parámetros por defecto: `--escala 1` (los bloques se vuelcan sin escalar), `--fino 0.07` y `--texel 0.01`.
"""

import argparse
import json
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, "tools"))
import mallas  # noqa: E402

ARMOR_MESHES = os.path.join(RAIZ, "src", "shared", "Data", "ArmorMeshes.luau")
CARPETA_VOLCADOS = os.path.join(RAIZ, "tools", "mallas")


def analizar_clave(clave):
    """`Armor_<id>_<rol>` o `Outfit_<id>_<grado>` -> (tipo, id, sub)."""
    p = clave.split("_")
    if len(p) != 3 or p[0] not in ("Armor", "Outfit"):
        sys.exit(f"Clave no válida: {clave} (usa Armor_<armaduraId>_<rol> u Outfit_<trajeId>_<grado>)")
    if p[0] == "Outfit" and not p[2].isdigit():
        sys.exit(f"{clave}: el grado de un traje es un número (0..4)")
    return p[0], p[1], p[2]


def buscar_log(ruta):
    """El log de Studio indicado o el último que tenga volcados (`@@V`)."""
    if ruta:
        return ruta
    carpeta = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
    candidatos = sorted(
        (os.path.join(carpeta, n) for n in os.listdir(carpeta) if "Studio" in n and n.endswith(".log")),
        key=os.path.getmtime,
        reverse=True,
    )
    for c in candidatos:
        if "@@V " in open(c, encoding="utf-8", errors="replace").read():
            return c
    sys.exit(f"Ningún log de Studio de {carpeta} tiene trozos @@V")


def leer_refs(ruta_log, clave):
    """Los `@@REF <clave> <Anclaje> x y z` del último volcado de la clave: { Anclaje: [x, y, z] }."""
    refs = {}
    for linea in open(ruta_log, encoding="utf-8", errors="replace"):
        if f"Volcado de {clave} empieza" in linea:
            refs = {}
            continue
        i = linea.find("@@REF ")
        if i < 0:
            continue
        p = linea[i:].split()
        if len(p) >= 6 and p[1] == clave:
            refs[p[2]] = [float(v) for v in p[3:6]]
    return refs


def exportar(claves, texel, fino, log):
    for clave in claves:
        analizar_clave(clave)
        ruta_log = buscar_log(log)
        destino = os.path.join(CARPETA_VOLCADOS, f"{clave}.txt")
        mallas.juntar_log(ruta_log, destino, clave)
        refs = leer_refs(ruta_log, clave)
        if not refs:
            sys.exit(f"{clave}: el log no tiene líneas @@REF; vuelve a volcar con Mallas.volcarArmadura")
        with open(os.path.join(CARPETA_VOLCADOS, f"{clave}.ref.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(refs, f, indent=2)
            f.write("\n")
        salida = os.path.join(RAIZ, "build", "mallas", clave)
        if os.path.isdir(salida):
            for f in os.listdir(salida):
                os.remove(os.path.join(salida, f))
        orden = [sys.executable, "-I", os.path.join(RAIZ, "tools", "mallas.py"), destino, "--jefe", clave,
                 "--escala", "1", "--fino", str(fino), "--texel", str(texel)]
        resultado = subprocess.run(orden, cwd=RAIZ, capture_output=True, text=True, encoding="utf-8")
        if resultado.returncode != 0:
            sys.exit(f"{clave}: falló mallas.py\n{resultado.stdout}{resultado.stderr}")
        print(resultado.stdout.rstrip())
        for f in sorted(os.listdir(salida)):
            if f.endswith(".obj"):
                print(f"  importar: build/mallas/{clave}/{f}")


def leer_ids(ruta):
    ids = {}
    for linea in open(ruta, encoding="utf-8"):
        partes = [p.strip() for p in linea.split("|")]
        if len(partes) == 3 and partes[1].startswith("rbxassetid://"):
            ids[partes[0]] = (partes[1], partes[2])
    return ids


def vector(v):
    return f"Vector3.new({v[0]:.4f}, {v[1]:.4f}, {v[2]:.4f})"


def cuerpo_entrada(tipo, sub, manifiesto, refs, ids, clave):
    """El texto de una entrada (a tres tabuladores), o None y los ids que faltan."""
    faltan = [f"{clave}_{g}" for g in manifiesto if f"{clave}_{g}" not in ids]
    if faltan:
        return None, faltan
    usadas = sorted({g.split("_")[0] for g in manifiesto})
    clave_sub = sub if tipo == "Armor" else f"[{int(sub)}]"
    t = "\t"
    lineas = [f"{t * 3}{clave_sub} = {{", f"{t * 4}ref = {{"]
    for ancla in usadas:
        if ancla not in refs:
            sys.exit(f"{clave}: falta @@REF de {ancla}; vuelve a ejecutar `exportar`")
        lineas.append(f"{t * 5}{ancla} = {vector(refs[ancla])},")
    lineas += [f"{t * 4}}},", f"{t * 4}groups = {{"]
    for grupo in sorted(manifiesto):
        datos = manifiesto[grupo]
        malla, textura = ids[f"{clave}_{grupo}"]
        lineas += [
            f'{t * 5}["{grupo}"] = {{',
            f'{t * 6}mesh = "{malla}",',
            f'{t * 6}texture = "{textura}",',
            f"{t * 6}offset = {vector(datos['offset'])},",
            f"{t * 6}size = {vector(datos['tamano'])},",
            f"{t * 6}triangles = {datos['triangulos']},",
            f"{t * 5}}},",
        ]
    lineas += [f"{t * 4}}},", f"{t * 3}}},"]
    return "\n".join(lineas) + "\n", []


PATRON = re.compile(r"^\t\t\t-- @entrada (\S+) (\S+) (\S+)\n(.*?)^\t\t\t-- @fin\n", re.S | re.M)


def escribir_archivo(entradas):
    """Reescribe ArmorMeshes.luau con { (tipo, id, sub): texto } conservando el encabezado."""
    contenido = open(ARMOR_MESHES, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    inicio = contenido.index("local ArmorMeshes: ArmorMeshes = {")
    fin = contenido.index("return ArmorMeshes")
    cabecera = contenido[:inicio]
    pie = contenido[fin:]
    t = "\t"
    salida = ["local ArmorMeshes: ArmorMeshes = {"]
    for tipo in ("Armor", "Outfit"):
        ids = sorted({k[1] for k in entradas if k[0] == tipo})
        if not ids:
            salida.append(f"{t}{tipo} = {{}},")
            continue
        salida.append(f"{t}{tipo} = {{")
        for id_ in ids:
            salida.append(f"{t * 2}{id_} = {{")
            subs = [k for k in entradas if k[0] == tipo and k[1] == id_]
            subs.sort(key=lambda k: int(k[2]) if tipo == "Outfit" else k[2])
            for k in subs:
                salida.append(f"{t * 3}-- @entrada {k[0]} {k[1]} {k[2]}")
                salida.append(entradas[k].rstrip("\n"))
                salida.append(f"{t * 3}-- @fin")
            salida.append(f"{t * 2}}},")
        salida.append(f"{t}}},")
    salida.append("}\n\n")
    with open(ARMOR_MESHES, "w", encoding="utf-8", newline="") as f:
        f.write(cabecera + "\n".join(salida) + pie)


def poner_ids(claves, texto):
    ids = leer_ids(texto)
    contenido = open(ARMOR_MESHES, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    entradas = {(m.group(1), m.group(2), m.group(3)): m.group(4) for m in PATRON.finditer(contenido)}
    for clave in claves:
        tipo, id_, sub = analizar_clave(clave)
        ruta = os.path.join(RAIZ, "build", "mallas", clave, "manifiesto.json")
        ruta_ref = os.path.join(CARPETA_VOLCADOS, f"{clave}.ref.json")
        if not os.path.exists(ruta) or not os.path.exists(ruta_ref):
            sys.exit(f"{clave}: faltan {ruta} o {ruta_ref}; ejecuta antes `exportar`")
        manifiesto = json.load(open(ruta, encoding="utf-8"))
        refs = json.load(open(ruta_ref, encoding="utf-8"))
        texto_entrada, faltan = cuerpo_entrada(tipo, sub, manifiesto, refs, ids, clave)
        if faltan:
            sys.exit(f"{clave}: faltan ids de {', '.join(faltan)} en {texto}")
        entradas[(tipo, id_, sub)] = texto_entrada
        print(f"{clave}: {len(manifiesto)} mallas, entrada escrita en ArmorMeshes.luau")
    escribir_archivo(entradas)
    print("Ahora: stylua src/shared && selene src")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Papeleo de las mallas de armaduras y trajes (Fase 20, Q6)")
    sub = ap.add_subparsers(dest="orden", required=True)
    e = sub.add_parser("exportar", help="junta el volcado del log y genera los .obj")
    e.add_argument("claves", nargs="+", help="Armor_<armaduraId>_<rol> u Outfit_<trajeId>_<grado>")
    e.add_argument("--texel", type=float, default=0.01)
    e.add_argument("--fino", type=float, default=0.07)
    e.add_argument("--log", help="log de Studio (por defecto, el último con volcados)")
    i = sub.add_parser("ids", help="escribe los ids importados en ArmorMeshes.luau")
    i.add_argument("claves", nargs="+")
    i.add_argument("--texto", required=True, help="archivo con una línea `Clave_Grupo | malla | textura` por malla")
    a = ap.parse_args()
    if a.orden == "exportar":
        exportar(a.claves, a.texel, a.fino, a.log)
    else:
        poner_ids(a.claves, a.texto)


if __name__ == "__main__":
    main()
