"""Pone el título del juego encima de una imagen de fondo (la que sale de Gemini con los prompts de
prompts.md) y saca el PNG final. Así el título sale siempre entero y bien escrito.

Uso:  python titulo.py <preset> <fondo.png|jpg> [salida.png] [--cx N] [--top N] [--escala N]

  --cx, --top, --escala   mueven y reducen el título si se solapa con algo de la imagen
                          (cx = centro en x, top = borde superior, ambos en píxeles de la salida).

Presets (tamaño, sitio y cinta del título):
  principal     1920x1080  miniatura de la página: título arriba a la izquierda, "MONKEY SURVIVAL"
  icono         512x512    icono de la experiencia: título pequeño abajo, sin cinta
  dunas         1920x1080  Isla de Dunas (PvP), cinta "DUNES ISLAND · PvP"
  laboratorio   1920x1080  Laboratorio en ruinas (PvP), cinta "RUINED LAB · PvP"

Genera un SVG temporal con la imagen incrustada (no toca icono.svg ni portada.svg) y lo convierte a PNG con Edge sin ventana (o con Chrome).
Si no encuentra ninguno, deja el SVG para abrirlo y exportarlo a mano (ver README.md).
"""
import base64
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile

import gen

HERE = os.path.dirname(os.path.abspath(__file__))

PRESETS = {
    'principal': dict(w=1920, h=1080, cx=420, top=50, scale=.86, sub=True, bunch=True, sub_text='MONKEY SURVIVAL',
                      png='portada-principal-1920x1080.png'),
    # El degradado oscuro de abajo da fondo al título sobre los pies de los personajes.
    'icono': dict(w=512, h=512, cx=256, top=330, scale=.46, sub=False, bunch=False, sub_text='',
                  png='icono-512.png', sombra=.8),
    'dunas': dict(w=1920, h=1080, cx=420, top=50, scale=.86, sub=True, bunch=True, sub_text='DUNES ISLAND · PvP',
                  png='portada-dunas-1920x1080.png'),
    'laboratorio': dict(w=1920, h=1080, cx=420, top=50, scale=.86, sub=True, bunch=True,
                        sub_text='RUINED LAB · PvP', png='portada-laboratorio-1920x1080.png'),
}

BROWSERS = [
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
]


def data_uri(path):
    mime = mimetypes.guess_type(path)[0] or 'image/png'
    with open(path, 'rb') as f:
        return f'data:{mime};base64,' + base64.b64encode(f.read()).decode()


def build(preset, fondo, ajustes=None):
    p = dict(PRESETS[preset], **(ajustes or {}))
    gen.DEFS.clear()
    gen.base_defs()
    w, h = p['w'], p['h']
    sombra = p.get('sombra')
    degradado = ''
    if sombra:
        grad = gen.lin([(0, '#14020a', 0), (1, '#14020a', sombra)], 0, 0, 0, 1)
        degradado = f'<rect x="0" y="{h * .55:.0f}" width="{w}" height="{h * .45:.0f}" fill="{grad}"/>'
    layers = [
        f'<image href="{data_uri(fondo)}" x="0" y="0" width="{w}" height="{h}" preserveAspectRatio="xMidYMid slice"/>',
        degradado,
        gen.title(p['cx'], p['top'], p['scale'], sub=p['sub'], bunch=p['bunch'], sub_text=p['sub_text']),
    ]
    return gen.svg_doc(w, h, '\n'.join(layers))


def render(svg, png, w, h):
    browser = next((b for b in BROWSERS if os.path.exists(b)), shutil.which('msedge') or shutil.which('chrome'))
    if not browser:
        print('No hay Edge ni Chrome: abre', svg, 'en un navegador y expórtalo a PNG.')
        return False
    subprocess.run([browser, '--headless=new', '--hide-scrollbars', '--force-device-scale-factor=1',
                    f'--window-size={w},{h}', f'--screenshot={png}', 'file:///' + svg.replace('\\', '/')],
                   check=True)
    return True


def main():
    args = sys.argv[1:]
    ajustes = {}
    for flag, clave in (('--cx', 'cx'), ('--top', 'top'), ('--escala', 'scale')):
        if flag in args:
            i = args.index(flag)
            ajustes[clave] = float(args[i + 1])
            del args[i:i + 2]
    if len(args) < 2 or args[0] not in PRESETS:
        print(__doc__)
        sys.exit(1)
    preset, fondo = args[0], os.path.abspath(args[1])
    p = PRESETS[preset]
    svg = os.path.join(tempfile.gettempdir(), f'titulo-{preset}.svg')
    png = os.path.abspath(args[2]) if len(args) > 2 else os.path.join(HERE, p['png'])
    with open(svg, 'w', encoding='utf-8', newline='') as f:
        f.write(build(preset, fondo, ajustes))
    if render(svg, png, p['w'], p['h']):
        os.remove(svg)
        print('wrote', png)


if __name__ == '__main__':
    main()
