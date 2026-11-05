"""Papeleo de las mallas de las armas (Fase 20, Q7): del volcado de Studio a `Data/WeaponMeshes.luau`.

Cada "clave" es un arma tal como la construye `WeaponTools.BUILDERS` (`Weapon_LavaStaff`). Una malla por clase de material:
grupos `Handle_Soft` (Fabric y Leather) y `Handle_Hard` (el resto de materiales lisos). El arma no se escala por avatar.

Flujo por tanda:
  1. En el Studio de la Isla (Edit), con el diseño aprobado:
         local m = game.ServerStorage.Tools.Mallas:Clone()
         require(m).volcarArma("LavaStaff", game.ReplicatedStorage.Shared:Clone())
         m:Destroy()
  2. python tools/arma.py exportar Weapon_LavaStaff
         junta el volcado del log del Studio en tools/mallas/<clave>.txt, convierte con tools/mallas.py (`--fino 0.07
         --texel 0.01`) y lista los .obj de build/mallas/<clave> que hay que importar (Import 3D, escala por defecto).
  3. El usuario importa y, en el Studio de la Isla (Edit), se lista lo importado (ver tools/armadura.py, paso 3), con una
     línea `Clave_Grupo | rbxassetid://… | rbxassetid://…` por malla (p. ej. `Weapon_LavaStaff_Handle_Hard | … | …`).
  4. python tools/arma.py ids Weapon_LavaStaff --texto ids.txt
         escribe (o sustituye) la entrada de cada clave en src/shared/Data/WeaponMeshes.luau con sus ids, `offset`, `size` y
         `triangles`. Las entradas quedan entre las marcas `-- @entrada Weapon <id>` y `-- @fin`: no las quites.
         Luego: stylua src/shared && selene src
"""

import argparse
import json
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, "tools"))
import armadura  # noqa: E402
import mallas  # noqa: E402

WEAPON_MESHES = os.path.join(RAIZ, "src", "shared", "Data", "WeaponMeshes.luau")
CARPETA_VOLCADOS = os.path.join(RAIZ, "tools", "mallas")


def analizar_clave(clave):
    """`Weapon_<id>` -> id."""
    p = clave.split("_")
    if len(p) != 2 or p[0] != "Weapon":
        sys.exit(f"Clave no válida: {clave} (usa Weapon_<armaId>)")
    return p[1]


def exportar(claves, texel, fino, log):
    for clave in claves:
        analizar_clave(clave)
        ruta_log = armadura.buscar_log(log)
        destino = os.path.join(CARPETA_VOLCADOS, f"{clave}.txt")
        mallas.juntar_log(ruta_log, destino, clave)
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


def cuerpo_entrada(manifiesto, ids, clave):
    """El texto de una entrada (a dos tabuladores), o None y los ids que faltan."""
    faltan = [f"{clave}_{g}" for g in manifiesto if f"{clave}_{g}" not in ids]
    if faltan:
        return None, faltan
    t = "\t"
    v = armadura.vector
    lineas = [f"{t * 2}{clave.split('_')[1]} = {{", f"{t * 3}groups = {{"]
    for grupo in sorted(manifiesto):
        datos = manifiesto[grupo]
        malla, textura = ids[f"{clave}_{grupo}"]
        lineas += [
            f'{t * 4}["{grupo}"] = {{',
            f'{t * 5}mesh = "{malla}",',
            f'{t * 5}texture = "{textura}",',
            f"{t * 5}offset = {v(datos['offset'])},",
            f"{t * 5}size = {v(datos['tamano'])},",
            f"{t * 5}triangles = {datos['triangulos']},",
            f"{t * 4}}},",
        ]
    lineas += [f"{t * 3}}},", f"{t * 2}}},"]
    return "\n".join(lineas) + "\n", []


PATRON = re.compile(r"^\t\t-- @entrada Weapon (\S+)\n(.*?)^\t\t-- @fin\n", re.S | re.M)


def escribir_archivo(entradas):
    """Reescribe WeaponMeshes.luau con { id: texto } conservando el encabezado."""
    contenido = open(WEAPON_MESHES, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    inicio = contenido.index("local WeaponMeshes: WeaponMeshes = {")
    fin = contenido.index("return WeaponMeshes")
    t = "\t"
    salida = ["local WeaponMeshes: WeaponMeshes = {"]
    if not entradas:
        salida.append(f"{t}Weapon = {{}},")
    else:
        salida.append(f"{t}Weapon = {{")
        for id_ in sorted(entradas):
            salida.append(f"{t * 2}-- @entrada Weapon {id_}")
            salida.append(entradas[id_].rstrip("\n"))
            salida.append(f"{t * 2}-- @fin")
        salida.append(f"{t}}},")
    salida.append("}\n\n")
    with open(WEAPON_MESHES, "w", encoding="utf-8", newline="") as f:
        f.write(contenido[:inicio] + "\n".join(salida) + contenido[fin:])


def poner_ids(claves, texto):
    ids = armadura.leer_ids(texto)
    contenido = open(WEAPON_MESHES, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    entradas = {m.group(1): m.group(2) for m in PATRON.finditer(contenido)}
    for clave in claves:
        id_ = analizar_clave(clave)
        ruta = os.path.join(RAIZ, "build", "mallas", clave, "manifiesto.json")
        if not os.path.exists(ruta):
            sys.exit(f"{clave}: falta {ruta}; ejecuta antes `exportar`")
        manifiesto = json.load(open(ruta, encoding="utf-8"))
        texto_entrada, faltan = cuerpo_entrada(manifiesto, ids, clave)
        if faltan:
            sys.exit(f"{clave}: faltan ids de {', '.join(faltan)} en {texto}")
        entradas[id_] = texto_entrada
        print(f"{clave}: {len(manifiesto)} mallas, entrada escrita en WeaponMeshes.luau")
    escribir_archivo(entradas)
    print("Ahora: stylua src/shared && selene src")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Papeleo de las mallas de las armas (Fase 20, Q7)")
    sub = ap.add_subparsers(dest="orden", required=True)
    e = sub.add_parser("exportar", help="junta el volcado del log y genera los .obj")
    e.add_argument("claves", nargs="+", help="Weapon_<armaId>")
    e.add_argument("--texel", type=float, default=0.01)
    e.add_argument("--fino", type=float, default=0.07)
    e.add_argument("--log", help="log de Studio (por defecto, el último con volcados)")
    i = sub.add_parser("ids", help="escribe los ids importados en WeaponMeshes.luau")
    i.add_argument("claves", nargs="+")
    i.add_argument("--texto", required=True, help="archivo con una línea `Clave_Grupo | malla | textura` por malla")
    a = ap.parse_args()
    if a.orden == "exportar":
        exportar(a.claves, a.texel, a.fino, a.log)
    else:
        poner_ids(a.claves, a.texto)


if __name__ == "__main__":
    main()
