"""Papeleo de las mallas de las mascotas (Fase 21, Q5): del volcado de Studio a `Data/PetMeshes.luau`.

Flujo por tanda (las mascotas se pueden volcar todas seguidas en Studio y exportar de una vez):
  1. En el Studio de la Isla (Edit), con el diseño aprobado:
         local m = game.ServerStorage.Tools.Mallas:Clone()
         for _, id in { "Colibri", "Guacamaya" } do require(m).volcarMascota(id, game.ReplicatedStorage.Shared:Clone()) end
         m:Destroy()
  2. python tools/mascota.py exportar Colibri Guacamaya   (con --sin Ear* Tail* los grupos que se quedan en bloques no se exportan)
     
         junta cada volcado del log del Studio en tools/mallas/<Mascota>.txt, detecta los pares izquierda/derecha
         (FL/FR, WingL/WingR…) que son reflejo exacto y los pasa como --espejo, convierte con tools/mallas.py y
         lista los .obj de build/mallas/<Mascota> que hay que importar (Import 3D, escala por defecto).
  3. El usuario importa y, en el Studio de la Isla (Edit), se lista lo importado:
         local out = {}
         for _, d in workspace:GetChildren() do
             local mp = d:FindFirstChildWhichIsA("MeshPart", true)
             if mp then out[#out + 1] = d.Name .. " | " .. mp.MeshId .. " | " .. mp.TextureID end
         end
         return table.concat(out, "\\n")
     Se guarda la salida en un archivo de texto (una línea `Mascota_Grupo | rbxassetid://… | rbxassetid://…` por malla).
  4. python tools/mascota.py ids Colibri Guacamaya --texto ids.txt
         escribe (o sustituye) la entrada de cada mascota en src/shared/Data/PetMeshes.luau con sus ids y los
         `offset` del manifiesto, y avisa de lo que falte.

Parámetros por defecto: `--escala 1` (los bloques se vuelcan sin escalar), `--fino 0.035` y `--texel 0.01`.
"""

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, "tools"))
import mallas  # noqa: E402

PET_MESHES = os.path.join(RAIZ, "src", "shared", "Data", "PetMeshes.luau")


def pares_espejo(partes):
    """Devuelve ['FL=FR', …] para cada par Xl/Xr cuyas cajas son reflejo exacto en X."""
    pares = []
    for nombre in sorted(partes):
        m = re.match(r"^(.*)L(\d*)$", nombre)  # FL, WingL, FL2…
        if not m or f"{m.group(1)}R{m.group(2)}" not in partes:
            continue
        derecha = f"{m.group(1)}R{m.group(2)}"

        def clave(cajas):
            return sorted(
                (round(c["lo"][0], 3), round(c["lo"][1], 3), round(c["lo"][2], 3),
                 round(c["hi"][0], 3), round(c["hi"][1], 3), round(c["hi"][2], 3), c["color"])
                for c in cajas
            )

        if clave(partes[nombre]) == clave(mallas.espejar(partes[derecha])):
            pares.append(f"{nombre}={derecha}")
        else:
            print(f"  aviso: {nombre} y {derecha} no son reflejo exacto; se exportan las dos")
    return pares


def exportar(mascotas, texel, fino, log, sin):
    for pet in mascotas:
        destino = os.path.join(RAIZ, "tools", "mallas", f"{pet}.txt")
        mallas.juntar_log(log or "", destino, pet)
        if sin:
            # Los grupos que se quedan en bloques (orejas, tramos de cola…) no se exportan: se quitan del volcado.
            lineas = open(destino, encoding="utf-8").read().splitlines()
            salida_txt, saltando = [], False
            for linea in lineas:
                if linea.startswith("PART "):
                    saltando = any(fnmatch.fnmatch(linea.split()[1], patron) for patron in sin)
                if not saltando:
                    salida_txt.append(linea)
                if linea.startswith("END"):
                    saltando = False
            with open(destino, "w", encoding="utf-8", newline="") as f:
                f.write(chr(10).join(salida_txt) + chr(10))
        partes = mallas.leer_volcado(destino)
        espejos = pares_espejo(partes)
        salida = os.path.join(RAIZ, "build", "mallas", pet)
        if os.path.isdir(salida):
            for f in os.listdir(salida):
                os.remove(os.path.join(salida, f))
        orden = [sys.executable, "-I", os.path.join(RAIZ, "tools", "mallas.py"), destino, "--jefe", pet,
                 "--escala", "1", "--fino", str(fino), "--texel", str(texel)]
        for par in espejos:
            orden += ["--espejo", par]
        resultado = subprocess.run(orden, cwd=RAIZ, capture_output=True, text=True, encoding="utf-8")
        if resultado.returncode != 0:
            sys.exit(f"{pet}: falló mallas.py\n{resultado.stdout}{resultado.stderr}")
        print(resultado.stdout.rstrip().splitlines()[-1])
        print(f"{pet}: espejos {espejos or 'ninguno'}")
        for f in sorted(os.listdir(salida)):
            if f.endswith(".obj"):
                print(f"  importar: build/mallas/{pet}/{f}")


def leer_ids(ruta):
    ids = {}
    for linea in open(ruta, encoding="utf-8"):
        partes = [p.strip() for p in linea.split("|")]
        if len(partes) == 3 and partes[1].startswith("rbxassetid://"):
            ids[partes[0]] = (partes[1], partes[2])
    return ids


def entrada(pet, manifiesto, ids):
    lineas = [f"\t{pet} = {{", "\t\tscale = 1,", "\t\tparts = {"]
    faltan = []
    for grupo in sorted(manifiesto, key=lambda g: (g != "Static", g)):
        clave = f"{pet}_{grupo}"
        if clave not in ids:
            faltan.append(clave)
            continue
        malla, textura = ids[clave]
        o = manifiesto[grupo]["offset"]
        lineas += [
            f'\t\t\t["{grupo}"] = {{',
            f'\t\t\t\tmesh = "{malla}",',
            f'\t\t\t\ttexture = "{textura}",',
            f"\t\t\t\toffset = Vector3.new({o[0]:.4f}, {o[1]:.4f}, {o[2]:.4f}),",
            "\t\t\t},",
        ]
    lineas += ["\t\t},", "\t},"]
    return "\n".join(lineas) + "\n", faltan


def poner_ids(mascotas, texto):
    ids = leer_ids(texto)
    contenido = open(PET_MESHES, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    for pet in mascotas:
        ruta = os.path.join(RAIZ, "build", "mallas", pet, "manifiesto.json")
        if not os.path.exists(ruta):
            sys.exit(f"{pet}: falta {ruta}; ejecuta antes `exportar`")
        nueva, faltan = entrada(pet, json.load(open(ruta, encoding="utf-8")), ids)
        if faltan:
            sys.exit(f"{pet}: faltan ids de {', '.join(faltan)} en {texto}")
        antigua = re.search(rf"^\t{pet} = \{{\n.*?^\t\}},\n", contenido, re.S | re.M)
        if antigua:
            contenido = contenido[: antigua.start()] + nueva + contenido[antigua.end():]
        else:
            fin = contenido.rindex("}\n\nreturn PetMeshes")
            contenido = contenido[:fin] + nueva + contenido[fin:]
        print(f"{pet}: {len(ids)} ids leídos, entrada escrita en PetMeshes.luau")
    with open(PET_MESHES, "w", encoding="utf-8", newline="") as f:
        f.write(contenido)
    print("Ahora: stylua src && selene src")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Papeleo de las mallas de las mascotas (Fase 21, Q5)")
    sub = ap.add_subparsers(dest="orden", required=True)
    e = sub.add_parser("exportar", help="junta los volcados del log y genera los .obj")
    e.add_argument("mascotas", nargs="+")
    e.add_argument("--texel", type=float, default=0.01)
    e.add_argument("--fino", type=float, default=0.035)
    e.add_argument("--log", help="log de Studio (por defecto, el último con volcados)")
    e.add_argument("--sin", nargs="*", default=[], metavar="GRUPO", help="grupos que no se exportan (admite comodines: Ear* Tail*)")
    i = sub.add_parser("ids", help="escribe los ids importados en PetMeshes.luau")
    i.add_argument("mascotas", nargs="+")
    i.add_argument("--texto", required=True, help="archivo con una línea `Mascota_Grupo | malla | textura` por malla")
    a = ap.parse_args()
    if a.orden == "exportar":
        exportar(a.mascotas, a.texel, a.fino, a.log, a.sin)
    else:
        poner_ids(a.mascotas, a.texto)


if __name__ == "__main__":
    main()
