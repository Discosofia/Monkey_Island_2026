import os
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)

# (t0, t1, etiqueta, acto): las tomas de la escena Lab, por segundo de escena.
TAKES = [
    (0, 1.6, "1.1a", 1), (1.6, 2.8, "1.1b", 1), (2.8, 4, "1.1c", 1), (4, 7, "1.2", 1), (7, 10, "1.3", 1), (10, 14, "1.4", 1), (14, 14.5, "1.5", 1),
    (14.5, 16.35, "2.1 avatar", 2), (16.35, 17.85, "2.2 pirata", 2), (17.85, 20, "2.3 avatar", 2), (20, 21.6, "2.4 pirata", 2),
    (21.6, 24, "2.5 avatar", 2), (24, 25, "2.6 pirata", 2), (25, 26.95, "2.7 avatar", 2), (26.95, 28.45, "2.8 pirata", 2), (28.45, 29.5, "2.9 avatar", 2),
    (29.5, 33, "3.1", 3), (33, 37, "3.2", 3), (37, 40, "3.3", 3), (40, 41.5, "3.4 pirata", 3), (41.5, 46, "3.5", 3),
]
COL = {1: (60, 110, 200), 2: (190, 120, 40), 3: (50, 140, 140)}


def take(t):
    for t0, t1, label, act in TAKES:
        if t0 <= t < t1:
            return label, act, t0
    return TAKES[-1][2], 3, TAKES[-1][0]


files = sorted(f for f in os.listdir(SRC) if f.endswith(".jpg"))
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)
cells = []
for i, name in enumerate(files):
    t = i * 0.5
    im = Image.open(os.path.join(SRC, name)).convert("RGB")
    label, act, t0 = take(t)
    w, h = im.size
    cell = Image.new("RGB", (w, h + 34), (20, 20, 20))
    cell.paste(im, (0, 34))
    d = ImageDraw.Draw(cell)
    d.rectangle([0, 0, w, 33], fill=COL[act])
    d.text((8, 3), f"TOMA {label}", font=font, fill=(255, 255, 255))
    d.text((w - 250, 7), f"Acto {act} · t {t:4.1f} s", font=small, fill=(255, 255, 255))
    if abs(t - t0) < 0.26:
        d.rectangle([0, 0, w - 1, h + 33], outline=(255, 255, 255), width=4)
    cells.append(cell)

COLS, ROWS = 3, 6
per = COLS * ROWS
cw, ch = cells[0].size
n = 0
for s in range(0, len(cells), per):
    chunk = cells[s : s + per]
    rows = (len(chunk) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * cw + (COLS + 1) * 6, rows * ch + (rows + 1) * 6), (0, 0, 0))
    for j, c in enumerate(chunk):
        x = 6 + (j % COLS) * (cw + 6)
        y = 6 + (j // COLS) * (ch + 6)
        sheet.paste(c, (x, y))
    n += 1
    sheet.save(os.path.join(OUT, f"hoja_{n}.jpg"), quality=85)
    print(f"hoja_{n}: t {s * 0.5:.1f} a {(s + len(chunk) - 1) * 0.5:.1f} s")
