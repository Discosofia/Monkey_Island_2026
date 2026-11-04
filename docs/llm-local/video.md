# Shorts con CapCut (resumen de la skill video-capcut)

<!-- Fuente: .claude/skills/video-capcut/SKILL.md, 03-11-2026. Detalles: docs/videos/shorts.md y docs/videos/README.md. -->

El agente escribe el borrador de CapCut con un script; el usuario lo abre, lo acaba y lo exporta. Nunca se publica, exporta ni borra nada sin pedirlo.

1. Guion en `docs/videos/shorts/<id>.json` (15-30 s, 3-5 cortes, gancho con texto en el primer segundo, cierre con la portada de 3 s, textos entre -0,33 y 0,33 de altura, sin Robux ni gore). Modelo: `jefes.json`.
2. `build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/<id>.json --solo-vista` y mirar `build/videos/shorts/<id>/hoja.jpg` para elegir `cx`, `cy`, `zoom` (mínimo 1,28).
3. Con CapCut cerrado, el mismo comando sin `--solo-vista` crea `<id>-<es|en>-vN` y lo copia a CapCut.
4. Anota en `docs/VERIFICACION.md` los pasos del usuario (retoque, objetivo 10 min) y entrega título, descripción y etiquetas (`docs/videos/shorts.md`).

El usuario añade filtro, voz generada (+16 dB), música (-10 dB) y exporta a 1080×1920, 30 fps. El agente no puede poner filtro, voz ni música por script.

Trampas: las tomas de `O:/` incluyen la barra de Studio y avisos del juego que tapan la acción; `pycapcut==0.0.4` con CapCut 9.7; la marca Pro de `pycapcut` no es fiable; `O:/` solo se lee; todo en `build/`.
