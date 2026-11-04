# Vídeos con CapCut (resumen de la skill video-capcut)

<!-- Fuente: .claude/skills/video-capcut/SKILL.md, 04-11-2026. Detalles: docs/videos/shorts.md y docs/videos/README.md. -->

El agente escribe el guion y el borrador de CapCut con scripts; el usuario lo abre, pone la voz y el filtro y lo exporta. Nunca se publica, exporta ni borra nada sin pedirlo. `O:/` solo se lee. Tipos: `short` (9:16, 15-60 s), `reel` (9:16, hasta 90 s), `youtube` (16:9, 1-3 min). Si no se dice el tipo, se pregunta. Las tomas están en `O:\Videos Primal banana\<vídeo>\`.

1. Petición: tema, tipo y carpeta. Se lee `notas.txt` de la carpeta si existe (plantilla: `docs/videos/notas-plantilla.txt`).
2. `build/videos/.venv/Scripts/python -I tools/video/tomas.py inventario "<carpeta>"`: duración y clase de cada toma (`juego`, `studio`, `mixta`) y hojas de contacto.
3. Guion por escenas en `docs/videos/guiones/<id>.md` (objetivo, plano, texto ES/EN, voz ES/EN, segundos). **Parada 1: el usuario lo aprueba.**
4. `tomas.py explorar "<carpeta>"` (escenas y picos de sonido, hojas `T<toma> m:ss`) y `tomas.py detalle` para afinar un tramo. Lo que falta va a `faltan` (qué grabar) con un sustituto.
5. Guion técnico `docs/videos/shorts/<id>.json` (`formato`, `carpeta`, `clase`, `voz`, `musica`, `faltan`; campos en `docs/videos/shorts.md`), vista con `short.py … --solo-vista` y `tomas.py storyboard` (HTML con fotogramas, se publica como Artifact). **Parada 2: el usuario lo aprueba.**
6. Con CapCut cerrado, `short.py docs/videos/shorts/<id>.json` crea `<id>-<es|en>-vN` y lo copia a CapCut (cortes, textos, pista `voz`, música local con licencia, Studio en silencio).
7. Entrega `publicacion.md` (título, descripción, etiquetas) y anota en `docs/VERIFICACION.md` los pasos del usuario (retoque, objetivo 5 min).

El usuario genera la voz desde la pista `voz` (+16 dB), añade filtro y música si no hay local (-10 dB), y exporta a 1080×1920 (o 1920×1080), 30 fps. El agente no puede poner filtro ni voz por script.

Trampas: las tomas de `O:/` traen la barra de Studio, el Admin y avisos del juego que tapan la acción (mira siempre la hoja); solo se miran hojas pequeñas; `pycapcut==0.0.4` con CapCut 9.7; la marca Pro de `pycapcut` no es fiable; todo en `build/`.
