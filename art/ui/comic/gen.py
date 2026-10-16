"""Atlas de los efectos de cómic del combate (ComicFxController).

Dibuja en blanco con borde negro, sobre fondo transparente, para que el juego los tiña con
ImageColor3 (el blanco toma el color y el negro se queda negro). La trama de puntos va en gris claro:
al teñirla sale un tono algo más oscuro del mismo color, como la trama de un cómic impreso.

Celdas del atlas (1024 x 1024), en píxeles (x, y, ancho, alto), las mismas que ATLAS en el código:
    burstA  (0,   0,   512, 512)  estrella de 14 picos irregulares, con trama
    burstB  (512, 0,   512, 512)  estrella de 20 picos más finos, con trama
    rays    (0,   512, 512, 512)  rayos finos desde el centro
    puff    (512, 512, 256, 256)  nubecita con rayas de velocidad (la nube a la derecha)
    star    (768, 512, 256, 256)  estrella de 5 puntas

    python gen.py   ->  comic-atlas.png
"""
import math
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SS = 4  # supermuestreo: se dibuja a 4x y se reduce, para bordes suaves
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)
DOT = (212, 212, 212, 255)


def star_points(cx, cy, count, outer, inner, jitter, seed, phase=0.0):
    rng = random.Random(seed)
    points = []
    for i in range(count * 2):
        angle = phase + math.pi * i / count + rng.uniform(-jitter, jitter) * math.pi / count
        radius = outer if i % 2 == 0 else inner
        radius *= rng.uniform(0.82, 1.0) if i % 2 == 0 else rng.uniform(0.9, 1.08)
        points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return points


def outlined(draw, points, stroke):
    draw.polygon(points, fill=WHITE)
    # Se cierra repitiendo los dos primeros puntos: así la primera esquina también se redondea.
    draw.line(points + points[:2], fill=BLACK, width=stroke, joint="curve")


def halftone(cell, mask_points, cx, cy, reach, spacing):
    """Puntos grises dentro del polígono, más grandes hacia el borde."""
    mask = Image.new("L", cell.size, 0)
    ImageDraw.Draw(mask).polygon(mask_points, fill=255)
    dots = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(dots)
    for row, y in enumerate(range(0, cell.size[1], spacing)):
        shift = spacing / 2 if row % 2 else 0
        x = shift
        while x < cell.size[0]:
            distance = math.hypot(x - cx, y - cy) / reach
            radius = spacing * 0.42 * max(0.0, min(1.0, (distance - 0.35) / 0.6))
            if radius > spacing * 0.06:
                draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=DOT)
            x += spacing
    clipped = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    clipped.paste(dots, (0, 0), mask)
    cell.alpha_composite(clipped)


def burst(size, count, inner_ratio, jitter, seed):
    s = size * SS
    cell = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    stroke = int(s * 0.03)
    cx = cy = s / 2
    outer = s / 2 - stroke
    points = star_points(cx, cy, count, outer, outer * inner_ratio, jitter, seed)
    draw = ImageDraw.Draw(cell)
    draw.polygon(points, fill=WHITE)
    halftone(cell, points, cx, cy, outer * inner_ratio, int(s / 22))
    ImageDraw.Draw(cell).line(points + points[:2], fill=BLACK, width=stroke, joint="curve")
    return cell.resize((size, size), Image.LANCZOS)


def rays(size, count, seed):
    s = size * SS
    cell = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(cell)
    rng = random.Random(seed)
    cx = cy = s / 2
    stroke = int(s * 0.007)
    for i in range(count):
        angle = 2 * math.pi * i / count + rng.uniform(-0.12, 0.12)
        length = s / 2 * rng.uniform(0.7, 0.97)
        start = s * 0.12
        half = rng.uniform(0.07, 0.13)
        base_a = (cx + math.cos(angle - half) * start, cy + math.sin(angle - half) * start)
        base_b = (cx + math.cos(angle + half) * start, cy + math.sin(angle + half) * start)
        tip = (cx + math.cos(angle) * length, cy + math.sin(angle) * length)
        outlined(draw, [base_a, tip, base_b], stroke)
    return cell.resize((size, size), Image.LANCZOS)


def puff(size):
    s = size * SS
    cell = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(cell)
    stroke = int(s * 0.035)
    # Rayas de velocidad hacia la izquierda (de donde viene el golpe).
    for offset, length in ((-0.13, 0.4), (0.0, 0.5), (0.13, 0.36)):
        y = s * (0.5 + offset)
        x1 = s * 0.6
        x0 = x1 - s * length
        draw.polygon([(x0, y), (x1, y - s * 0.05), (x1, y + s * 0.05)], fill=WHITE)
        draw.line([(x0, y), (x1, y - s * 0.05), (x1, y + s * 0.05), (x0, y)], fill=BLACK, width=stroke // 2, joint="curve")
    # Nube: círculos con borde y luego el relleno encima, para que el borde quede solo por fuera.
    circles = [(0.7, 0.5, 0.17), (0.6, 0.38, 0.13), (0.62, 0.62, 0.13), (0.8, 0.36, 0.12), (0.82, 0.62, 0.13), (0.86, 0.5, 0.11)]
    for cx, cy, r in circles:
        r2 = r * s + stroke
        draw.ellipse((cx * s - r2, cy * s - r2, cx * s + r2, cy * s + r2), fill=BLACK)
    for cx, cy, r in circles:
        r2 = r * s
        draw.ellipse((cx * s - r2, cy * s - r2, cx * s + r2, cy * s + r2), fill=WHITE)
    return cell.resize((size, size), Image.LANCZOS)


def small_star(size):
    s = size * SS
    cell = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    stroke = int(s * 0.05)
    outer = s / 2 - stroke
    points = star_points(s / 2, s / 2 + s * 0.03, 5, outer, outer * 0.45, 0, 1, phase=-math.pi / 2)
    outlined(ImageDraw.Draw(cell), points, stroke)
    return cell.resize((size, size), Image.LANCZOS)


def main():
    atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    atlas.alpha_composite(burst(512, 14, 0.62, 0.55, 7), (0, 0))
    atlas.alpha_composite(burst(512, 20, 0.7, 0.4, 11), (512, 0))
    atlas.alpha_composite(rays(512, 22, 3), (0, 512))
    atlas.alpha_composite(puff(256), (512, 512))
    atlas.alpha_composite(small_star(256), (768, 512))
    atlas.save(os.path.join(HERE, "comic-atlas.png"))


if __name__ == "__main__":
    main()
