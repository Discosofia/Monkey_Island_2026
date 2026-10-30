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
En Windows sin Playwright vale Edge sin ventana, una vez por imagen:
`msedge --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=1920,1080 --screenshot=portada-1920x1080.png file:///<ruta>/portada.svg`
(y `--window-size=512,512` con `icono.svg` para el icono).

## Portadas con el equipo real del juego

| Archivo | Uso |
|---|---|
| `prompts.md` | Un prompt por imagen (principal, icono, Dunas, Laboratorio), con las referencias que se adjuntan a Gemini. |
| `ref/` | Capturas de Studio: los 4 roles con su mejor equipo (frente y espalda), los 4 jefes, las armas del Laboratorio por bando y los fondos de Dunas y del Laboratorio. |
| `titulo.py` | Pone el título sobre la imagen de Gemini: `python titulo.py principal fondo.png` (también `icono`, `dunas`, `laboratorio`). Reutiliza `title()` de `gen.py`. |

Las cuatro imágenes ya hechas (el fondo de Gemini y el comando que pone el título):

| Imagen | Fondo | Comando |
|---|---|---|
| `portada-principal-1920x1080.png` | `fondo-principal-gemini.jpg` | `python titulo.py principal fondo-principal-gemini.jpg --cx 330 --top 30 --escala .68` |
| `icono-512.png` | `fondo-icono-gemini.jpg` | `python titulo.py icono fondo-icono-gemini.jpg` |
| `portada-dunas-1920x1080.png` | `fondo-dunas-gemini.jpg` | `python titulo.py dunas fondo-dunas-gemini.jpg --cx 960 --top 15 --escala .75` |
| `portada-laboratorio-1920x1080.png` | `fondo-laboratorio-gemini.jpg` | `python titulo.py laboratorio fondo-laboratorio-gemini.jpg --cx 340 --top 30 --escala .72` |

El título se coloca donde hay cielo o niebla libre: arriba a la izquierda en la principal y el Laboratorio, y
centrado en Dunas.

Las fichas de `ref/` se sacan con `src/island/tools/Portada.luau` (ver `prompts.md`, al final).

## Composición original (SVG)

Composición: el náufrago en primer plano con el garrote con colmillos y una antorcha; detrás, los 4 jefes
(Orangután del Manglar, Chimpancé Caudillo, Gorila de Ceniza y Gorila Albino); al fondo, el volcán en
erupción con bombas de lava al atardecer.
