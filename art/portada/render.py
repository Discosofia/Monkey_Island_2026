"""Rasterize the SVG sources to PNG with the pre-installed Chromium.

Usage: python3 render.py            -> renders portada + icon (+ previews)
"""
import glob
import os
import sys

from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = sorted(glob.glob('/opt/pw-browsers/chromium-*/chrome-linux/chrome'))[-1]

JOBS = [
    # (svg, png, width, height, css_size)
    ('portada.svg', 'portada-1920x1080.png', 1920, 1080, None),
    ('icono.svg', 'icono-512.png', 512, 512, None),
    ('icono.svg', 'preview-icono-128.png', 128, 128, None),
    ('portada.svg', 'preview-portada-480.png', 480, 270, None),
]


def main(only=None):
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=CHROME, args=['--no-sandbox'])
        for svg, png, w, h, _ in JOBS:
            if only and only not in svg:
                continue
            page = browser.new_page(viewport={'width': w, 'height': h}, device_scale_factor=1)
            html = (
                '<!doctype html><html><head><style>html,body{margin:0;padding:0;background:#000}'
                f'img{{display:block;width:{w}px;height:{h}px}}</style></head>'
                f'<body><img src="file://{os.path.join(HERE, svg)}"></body></html>'
            )
            tmp = os.path.join(HERE, '_render.html')
            with open(tmp, 'w') as f:
                f.write(html)
            page.goto('file://' + tmp)
            page.wait_for_load_state('networkidle')
            page.wait_for_timeout(300)
            page.screenshot(path=os.path.join(HERE, png), clip={'x': 0, 'y': 0, 'width': w, 'height': h})
            page.close()
            os.remove(tmp)
            print('wrote', png)
        browser.close()


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)
