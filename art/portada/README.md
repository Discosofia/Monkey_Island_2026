# Portada e icono

| Archivo | Uso |
|---|---|
| `portada-1920x1080.png` | Primera miniatura de la página del juego (Creator Hub → tu experiencia → Lugares/Información básica → Miniaturas). |
| `icono-512.png` | Icono de la experiencia. |
| `portada.svg`, `icono.svg` | Fuentes editables (vectoriales, con la tipografía del título incrustada). |
| `gen.py` | Genera los dos SVG: posiciones, colores y poses se cambian aquí. |
| `render.py` | Convierte los SVG en PNG con Chromium (Playwright). |
| `title-font.woff2` | Subconjunto de Inter Display Black (licencia OFL) para el título. |

Para regenerar: `python3 gen.py && python3 render.py` (necesita `pip install playwright` y Chromium).

Composición: el náufrago en primer plano con el garrote con colmillos y una antorcha; detrás, los 4 jefes
(Orangután del Manglar, Chimpancé Caudillo, Gorila de Ceniza y Gorila Albino); al fondo, el volcán en
erupción con bombas de lava al atardecer.
