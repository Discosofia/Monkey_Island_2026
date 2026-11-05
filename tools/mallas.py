"""Mallas con textura para los jefes (Fase 21).

Convierte las partes en bloques de un jefe (el volcado que hace `ServerStorage.Tools.Mallas.volcar` en el Studio de
la Isla) en una malla por parte con su textura: la silueta son los bloques gruesos, fusionados y sin caras tapadas, y
los bloques finos (mechones, manchas de pelo) se pintan en la textura (0,05 studs por texel). Un torso del Albino pasa de 2.212 a 468
triángulos. Se importan en Studio con Import 3D (la escala por defecto, 1 unidad = 1 stud, es la buena) y los ids
resultantes van en `src/shared/Data/BossMeshes.luau`, que lee `MonkeyModels`.

Uso:
    python tools/mallas.py tools/mallas/GorilaAlbino.txt --jefe GorilaAlbino \\
        --espejo Left_Arm=Right_Arm --espejo Left_Leg=Right_Leg
    python tools/mallas.py tools/mallas/GorilaAlbino.txt --jefe GorilaAlbino --ids ids.json --luau

Monturas (Fase 21): `Mallas.volcarMontura` imprime una parte por hueso, en trozos que `--del-log` junta:
    python tools/mallas.py tools/mallas/Llama.txt --del-log
    python tools/mallas.py tools/mallas/Llama.txt --jefe Llama --escala 1 --fino 0.07 --texel 0.01 \\
        --espejo LegFL=LegFR --espejo ShinFL=ShinFR --espejo LegBL=LegBR --espejo ShinBL=ShinBR --espejo EarL=EarR
(`--escala` es el `size` de Data/Mounts; los huesos de las monturas miden pocos studs y piden un texel mucho menor que
el de un jefe.)

Formato del volcado (una parte tras otra; los números son studs respecto al centro de su primer bloque):
    PART Torso 146 [suma de control]
    x y z ancho alto fondo RRGGBB
    ...
    END
El umbral de bloque fino (`--fino`, 0,2 studs) es de 0,4 celdas: para un jefe de otra escala se ajusta (Gorila de Ceniza, escala 3,625:
`--fino 0.25 --escala 3.625`).
Salida, en `build/mallas/<jefe>/`: `<Parte>.obj`, `.mtl` y `.png` de cada parte, y `manifiesto.json` con los
triángulos, el atlas y el `offset` (centro de la caja envolvente respecto al centro de la parte).
"""

import argparse
import json
import os
import struct
import sys
import zlib

E = 1e-3
ANCHO_ATLAS = 1024
ALTO_MAXIMO = 1024


def leer_volcado(ruta):
    """Devuelve { nombre: [caja] } con caja = { lo, hi, size, color }; comprueba el número de cajas y la suma de control."""
    partes = {}
    actual = None
    for linea in open(ruta, encoding="utf-8"):
        p = linea.split()
        if not p:
            continue
        if p[0] == "PART":
            actual = {"nombre": p[1], "n": int(p[2]), "chk": float(p[3]) if len(p) > 3 else None, "cajas": [], "chk_calc": 0.0}
            continue
        if p[0] == "END":
            if len(actual["cajas"]) != actual["n"]:
                sys.exit(f"{actual['nombre']}: faltan cajas ({len(actual['cajas'])} de {actual['n']})")
            if actual["chk"] is not None and abs(actual["chk"] - actual["chk_calc"]) > 0.05:
                sys.exit(f"{actual['nombre']}: la suma de control no coincide ({actual['chk_calc']:.2f} y no {actual['chk']:.2f}); revisa la copia")
            partes[actual["nombre"]] = actual["cajas"]
            actual = None
            continue
        if actual is None or len(p) != 7:
            continue
        x, y, z, sx, sy, sz = (float(v) for v in p[:6])
        color = tuple(int(p[6][i : i + 2], 16) for i in (0, 2, 4))
        actual["chk_calc"] += x + y * 3 + z * 5 + sx * 7 + sy * 11 + sz * 13 + int(p[6], 16) % 1000
        actual["cajas"].append(
            {
                "lo": (x - sx / 2, y - sy / 2, z - sz / 2),
                "hi": (x + sx / 2, y + sy / 2, z + sz / 2),
                "size": (sx, sy, sz),
                "color": color,
            }
        )
    return partes


def espejar(cajas):
    """El lado izquierdo es el derecho reflejado en X."""
    out = []
    for c in cajas:
        out.append(
            {
                "lo": (-c["hi"][0], c["lo"][1], c["lo"][2]),
                "hi": (-c["lo"][0], c["hi"][1], c["hi"][2]),
                "size": c["size"],
                "color": c["color"],
            }
        )
    return out


def restar(rects, c):
    out = []
    for r in rects:
        if c[0] >= r[2] - E or c[2] <= r[0] + E or c[1] >= r[3] - E or c[3] <= r[1] + E:
            out.append(r)
            continue
        if c[0] > r[0] + E:
            out.append((r[0], r[1], c[0], r[3]))
        if c[2] < r[2] - E:
            out.append((c[2], r[1], r[2], r[3]))
        x0, x1 = max(r[0], c[0]), min(r[2], c[2])
        if c[1] > r[1] + E:
            out.append((x0, r[1], x1, c[1]))
        if c[3] < r[3] - E:
            out.append((x0, c[3], x1, r[3]))
    return out


def fusionar(rects):
    """Une rectángulos vecinos de la misma extensión en un eje, hasta que no quede ninguno."""
    rects = [list(r) for r in rects]
    cambio = True
    while cambio:
        cambio = False
        for dim in (0, 1):
            a0, a1, b0, b1 = dim, 2 + dim, 1 - dim, 3 - dim
            cubos = {}
            for r in rects:
                cubos.setdefault((round(r[a0], 3), round(r[a1], 3)), []).append(r)
            salida = []
            for lista in cubos.values():
                lista.sort(key=lambda r: r[b0])
                cur = list(lista[0])
                for r in lista[1:]:
                    if abs(r[b0] - cur[b1]) < E:
                        cur[b1] = r[b1]
                        cambio = True
                    else:
                        salida.append(cur)
                        cur = list(r)
                salida.append(cur)
            rects = salida
    return rects


def superficies(cajas):
    """Caras que se ven de un conjunto de cajas, fusionadas por plano: [{ eje, s, p, rect }]."""
    grupos = {}
    for ia, a in enumerate(cajas):
        for eje in range(3):
            j, k = (eje + 1) % 3, (eje + 2) % 3
            for s in (1, -1):
                p = a["hi"][eje] if s > 0 else a["lo"][eje]
                q = p + s * E
                resto = [(a["lo"][j], a["lo"][k], a["hi"][j], a["hi"][k])]
                for ib, b in enumerate(cajas):
                    if ib == ia or not resto:
                        continue
                    tapa = b["lo"][eje] < q < b["hi"][eje]
                    if not tapa:
                        # Cara coplanar del mismo lado: solo cuenta una (la de índice menor).
                        if s > 0:
                            igual = abs(b["hi"][eje] - p) < E and b["lo"][eje] < p - E
                        else:
                            igual = abs(b["lo"][eje] - p) < E and b["hi"][eje] > p + E
                        tapa = igual and ib < ia
                    if tapa:
                        resto = restar(resto, (b["lo"][j], b["lo"][k], b["hi"][j], b["hi"][k]))
                grupos.setdefault((eje, s, round(p, 3)), []).extend(resto)
    salida = []
    for (eje, s, p), rects in grupos.items():
        for r in fusionar(rects):
            salida.append({"eje": eje, "s": s, "p": p, "rect": r})
    return salida


def escribir_png(ruta, ancho, alto, pixeles):
    crudo = bytearray()
    for y in range(alto):
        crudo.append(0)
        crudo += pixeles[y * ancho * 4 : (y + 1) * ancho * 4]

    def trozo(tag, datos):
        c = struct.pack(">I", len(datos)) + tag + datos
        return c + struct.pack(">I", zlib.crc32(tag + datos) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0))
    png += trozo(b"IDAT", zlib.compress(bytes(crudo), 9))
    png += trozo(b"IEND", b"")
    with open(ruta, "wb") as f:
        f.write(png)


def empaquetar(caras, texel):
    """Reparte un cuadro de textura por cara en estantes, con 1 texel de margen. Devuelve el alto necesario."""
    cx = cy = alto_fila = 0
    for f in caras:
        r = f["rect"]
        tw = max(1, -(-int(round((r[2] - r[0]) / texel * 1000)) // 1000))
        th = max(1, -(-int(round((r[3] - r[1]) / texel * 1000)) // 1000))
        w, h = tw + 2, th + 2
        if cx + w > ANCHO_ATLAS:
            cx, cy, alto_fila = 0, cy + alto_fila, 0
        f["tile"] = (cx, cy, tw, th)
        cx += w
        alto_fila = max(alto_fila, h)
    return cy + alto_fila


def cubren(f, finas, texel):
    """Bloques finos que se pintan sobre una cara gruesa, de dentro afuera.

    Cuentan los que la tocan y también los apilados sobre otros finos (los marcos de una manta, una greca sobre un
    marco); el de más arriba va el último para que tape a los de debajo."""
    eje, s, p = f["eje"], f["s"], f["p"]
    j, k = (eje + 1) % 3, (eje + 2) % 3
    r = f["rect"]
    cerca = [
        t
        for t in finas
        if t["hi"][j] > r[0] - texel and t["lo"][j] < r[2] + texel and t["hi"][k] > r[1] - texel and t["lo"][k] < r[3] + texel
    ]
    alcance = p
    encima = []
    avanzo = True
    while avanzo:
        avanzo = False
        for t in cerca:
            if t in encima:
                continue
            if s > 0:
                toca = t["lo"][eje] <= alcance + E and t["hi"][eje] > p + E
                sube = t["hi"][eje]
            else:
                toca = t["hi"][eje] >= alcance - E and t["lo"][eje] < p - E
                sube = t["lo"][eje]
            if toca:
                encima.append(t)
                alcance = max(alcance, sube) if s > 0 else min(alcance, sube)
                avanzo = True
    encima.sort(key=lambda t: t["hi"][eje] if s > 0 else -t["lo"][eje])
    return encima


def convertir(nombre, cajas, jefe, salida, texel, fino):
    # Un bloque fino solo se puede pintar sobre la cara de uno grueso de su misma parte. El que no se apoya en ninguno
    # (los labios de una mandíbula, una línea que flota) se perdería sin avisar: pasa a ser geometría.
    promovidas = set()
    while True:
        gruesas = [b for b in cajas if min(b["size"]) >= fino or id(b) in promovidas]
        finas = [b for b in cajas if min(b["size"]) < fino and id(b) not in promovidas]
        caras = superficies(gruesas)
        usadas = set()
        for f in caras:
            j, k = (f["eje"] + 1) % 3, (f["eje"] + 2) % 3
            r = f["rect"]
            for t in cubren(f, finas, texel):
                if t["hi"][j] > r[0] and t["lo"][j] < r[2] and t["hi"][k] > r[1] and t["lo"][k] < r[3]:
                    usadas.add(id(t))
        sueltas = [t for t in finas if id(t) not in usadas]
        if not sueltas:
            break
        promovidas |= {id(t) for t in sueltas}

    # Si el atlas no cabe en 1024 de alto, se baja la resolución de la textura.
    while True:
        alto_necesario = empaquetar(caras, texel)
        if alto_necesario <= ALTO_MAXIMO:
            break
        texel *= 1.25
    alto = 1
    while alto < alto_necesario:
        alto *= 2

    por_plano = {}
    for b in gruesas:
        for eje in range(3):
            for s in (1, -1):
                p = b["hi"][eje] if s > 0 else b["lo"][eje]
                por_plano.setdefault((eje, s, round(p, 3)), []).append(b)

    pixeles = bytearray(ANCHO_ATLAS * alto * 4)

    def poner(px, py, c):
        o = (py * ANCHO_ATLAS + px) * 4
        pixeles[o : o + 4] = bytes((c[0], c[1], c[2], 255))

    for f in caras:
        eje, s, p = f["eje"], f["s"], f["p"]
        j, k = (eje + 1) % 3, (eje + 2) % 3
        r = f["rect"]
        tx0, ty0, tw, th = f["tile"]
        base = por_plano[(eje, s, p)]
        encima = cubren(f, finas, texel)
        du, dv = (r[2] - r[0]) / tw, (r[3] - r[1]) / th
        for ty in range(th + 2):
            for tx in range(tw + 2):
                u = r[0] + (tx - 1 + 0.5) * du
                v = r[1] + (ty - 1 + 0.5) * dv
                color = base[0]["color"]
                for bb in base:
                    if bb["lo"][j] - E <= u <= bb["hi"][j] + E and bb["lo"][k] - E <= v <= bb["hi"][k] + E:
                        color = bb["color"]
                        break
                for t in encima:
                    if t["lo"][j] <= u <= t["hi"][j] and t["lo"][k] <= v <= t["hi"][k]:
                        color = t["color"]
                poner(tx0 + tx, ty0 + ty, color)

    base_nombre = f"{jefe}_{nombre}"
    escribir_png(os.path.join(salida, base_nombre + ".png"), ANCHO_ATLAS, alto, pixeles)
    with open(os.path.join(salida, base_nombre + ".mtl"), "w", newline="\n") as m:
        m.write(f"newmtl {base_nombre}\nKa 1 1 1\nKd 1 1 1\nmap_Kd {base_nombre}.png\n")

    normales = {}
    lineas = [f"mtllib {base_nombre}.mtl", f"o {base_nombre}", f"usemtl {base_nombre}"]
    vs, vts, fs = [], [], []
    nv = nvt = triangulos = 0
    for f in caras:
        eje, s, p = f["eje"], f["s"], f["p"]
        j, k = (eje + 1) % 3, (eje + 2) % 3
        r = f["rect"]
        tx0, ty0, tw, th = f["tile"]

        def esquina(u, v):
            c = [0.0, 0.0, 0.0]
            c[eje], c[j], c[k] = p, u, v
            return c

        for c in (esquina(r[0], r[1]), esquina(r[2], r[1]), esquina(r[2], r[3]), esquina(r[0], r[3])):
            vs.append("v %.4f %.4f %.4f" % tuple(c))
        for px, py in ((tx0 + 1, ty0 + 1), (tx0 + 1 + tw, ty0 + 1), (tx0 + 1 + tw, ty0 + 1 + th), (tx0 + 1, ty0 + 1 + th)):
            vts.append("vt %.5f %.5f" % (px / ANCHO_ATLAS, 1 - py / alto))
        n = [0, 0, 0]
        n[eje] = s
        n = tuple(n)
        ni = normales.setdefault(n, len(normales) + 1)
        vi, ti = nv + 1, nvt + 1
        orden = ((0, 1, 2), (0, 2, 3)) if s > 0 else ((0, 2, 1), (0, 3, 2))
        for a, b, c in orden:
            fs.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % (vi + a, ti + a, ni, vi + b, ti + b, ni, vi + c, ti + c, ni))
            triangulos += 1
        nv += 4
        nvt += 4
    for n, _ in sorted(normales.items(), key=lambda kv: kv[1]):
        lineas.append("vn %d %d %d" % n)
    with open(os.path.join(salida, base_nombre + ".obj"), "w", newline="\n") as o:
        o.write("\n".join(lineas + vs + vts + fs) + "\n")

    xs = [b["lo"][0] for b in gruesas] + [b["hi"][0] for b in gruesas]
    ys = [b["lo"][1] for b in gruesas] + [b["hi"][1] for b in gruesas]
    zs = [b["lo"][2] for b in gruesas] + [b["hi"][2] for b in gruesas]
    centro = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    tamano = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    return {
        "archivo": base_nombre,
        "cajas": len(cajas),
        "gruesas": len(gruesas),
        "finas": len(finas),
        "triangulos": triangulos,
        "triangulos_union_aprox": len(cajas) * 12,
        "atlas": [ANCHO_ATLAS, alto],
        "texel": round(texel, 4),
        "offset": [round(c, 4) for c in centro],
        "tamano": [round(t, 4) for t in tamano],
    }


def luau(jefe, manifiesto, ids, escala):
    """Escribe la entrada de `Data/BossMeshes.luau` de un jefe, con los ids de Import 3D si se dan."""
    lineas = [f"\t{jefe} = {{", f"\t\tscale = {escala},", "\t\tparts = {"]
    for nombre, datos in manifiesto.items():
        real = nombre.replace("_", " ")
        id_ = ids.get(nombre, {})
        mesh = id_.get("mesh", "")
        textura = id_.get("texture", "")
        o = datos["offset"]
        lineas.append(
            f'\t\t\t["{real}"] = {{ mesh = "{mesh}", texture = "{textura}", triangles = {datos["triangulos"]}, offset = Vector3.new({o[0]}, {o[1]}, {o[2]}) }},'
        )
    lineas += ["\t\t},", "\t},"]
    return "\n".join(lineas)


def juntar_log(ruta_log, destino, nombre=None):
    """Junta los trozos `@@V <hueso> <nn>` que imprime `Mallas.volcarMontura` en el log del Studio y escribe el volcado.

    Sin `ruta_log` busca, en %LOCALAPPDATA%/Roblox/logs, el último log de Studio que los contiene. Si el volcado se
    hizo varias veces, vale el último trozo de cada número. Con `nombre` (el id de la montura o la mascota) vale el
    último volcado completo de ese nombre, aunque después se hayan volcado otros."""
    if not ruta_log:
        carpeta = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
        candidatos = sorted(
            (os.path.join(carpeta, n) for n in os.listdir(carpeta) if "Studio" in n and n.endswith(".log")),
            key=os.path.getmtime,
            reverse=True,
        )
        for c in candidatos:
            if "@@V " in open(c, encoding="utf-8", errors="replace").read():
                ruta_log = c
                break
        if not ruta_log:
            sys.exit(f"Ningún log de Studio de {carpeta} tiene trozos @@V")
    trozos = {}
    ultimo = {}  # el último volcado completo: lo que había justo antes de su "Volcado de … listo"
    por_nombre = {}
    volcando = None
    actual = None
    for linea in open(ruta_log, encoding="utf-8", errors="replace"):
        linea = linea.rstrip("\r\n")
        if linea[:4].isdigit() and linea[4:5] == "-" and "T" in linea[:20]:
            actual = None  # empieza otro mensaje del log
            if "Volcado de " in linea and linea.endswith(" empieza"):
                trozos = {}  # los trozos de volcados anteriores (o de jefes) ya no valen
                volcando = linea.split("Volcado de ", 1)[1].rsplit(" empieza", 1)[0].strip()
                continue
            if "Volcado de " in linea and " listo" in linea:
                ultimo, trozos = trozos, {}
                if volcando:
                    por_nombre[volcando] = ultimo
                continue
            i = linea.find("@@V ")
            etiqueta = linea[i:].split() if i >= 0 else []
            if len(etiqueta) >= 3:
                actual = trozos.setdefault((etiqueta[1], int(etiqueta[2])), [])
                actual.clear()
            continue
        if actual is not None and linea:
            actual.append(linea)
    huesos = {}
    if nombre:
        if nombre not in por_nombre:
            sys.exit(f"{ruta_log}: no hay un volcado completo de {nombre}")
        elegido = por_nombre[nombre]
    else:
        elegido = trozos or ultimo
    for (hueso, n), lineas in sorted(elegido.items()):
        huesos.setdefault(hueso, []).extend(lineas)
    if not huesos:
        sys.exit(f"{ruta_log}: no hay trozos @@V")
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        for lineas in huesos.values():
            f.write("\n".join(lineas) + "\n")
    print(f"{len(huesos)} huesos de {ruta_log} -> {destino}")
    leer_volcado(destino)  # comprueba cajas y sumas de control


def main():
    # La consola de Windows usa cp1252 y no escribe todos los símbolos.
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Mallas con textura para los jefes y las monturas (Fase 21)")
    ap.add_argument("volcado")
    ap.add_argument("--nombre", help="con --del-log: el volcado de este id (montura o mascota), no el último del log")
    ap.add_argument("--del-log", nargs="?", const="", metavar="LOG", help="escribe `volcado` juntando los trozos @@V del log de Studio (sin LOG, el último que los tenga) y termina")
    ap.add_argument("--jefe", help="nombre del jefe o de la montura (prefijo de los archivos)")
    ap.add_argument("--salida", default="build/mallas")
    ap.add_argument("--texel", type=float, default=0.05, help="studs por texel de la textura (0,05 por defecto; si no cabe en 1024x1024 se sube solo)")
    ap.add_argument("--fino", type=float, default=0.2, help="los bloques con una dimensión menor van a la textura")
    ap.add_argument("--espejo", action="append", default=[], help="Izquierda=Derecha: la parte sale reflejada de otra")
    ap.add_argument("--escala", type=float, default=2.9, help="escala del jefe con la que se volcaron los bloques")
    ap.add_argument("--ids", help="JSON { Parte: { mesh, texture } } con los ids de Import 3D")
    ap.add_argument("--luau", action="store_true", help="escribe la entrada de BossMeshes.luau")
    a = ap.parse_args()
    if a.del_log is not None:
        juntar_log(a.del_log, a.volcado, a.nombre)
        return
    if not a.jefe:
        ap.error("falta --jefe")

    partes = leer_volcado(a.volcado)
    for par in a.espejo:
        izq, der = par.split("=")
        partes[izq] = espejar(partes[der])
    salida = os.path.join(a.salida, a.jefe)
    os.makedirs(salida, exist_ok=True)
    manifiesto = {}
    for nombre, cajas in partes.items():
        manifiesto[nombre] = convertir(nombre, cajas, a.jefe, salida, a.texel, a.fino)
        m = manifiesto[nombre]
        print(
            f"{nombre:10s} cajas {m['cajas']:3d} (finas {m['finas']:3d})  triángulos {m['triangulos']:4d} "
            f"(unión ≈ {m['triangulos_union_aprox']})  atlas {m['atlas'][0]}x{m['atlas'][1]}  offset {m['offset']}"
        )
    total = sum(m["triangulos"] for m in manifiesto.values())
    print(f"total {total} triángulos en {len(manifiesto)} partes -> {salida}")
    with open(os.path.join(salida, "manifiesto.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifiesto, f, indent=2, ensure_ascii=False)
        f.write("\n")
    if a.luau:
        ids = json.load(open(a.ids, encoding="utf-8")) if a.ids else {}
        print(luau(a.jefe, manifiesto, ids, a.escala))


if __name__ == "__main__":
    main()
