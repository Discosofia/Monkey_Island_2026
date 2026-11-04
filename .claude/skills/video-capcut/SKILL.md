---
name: video-capcut
description: Prepara los Shorts de YouTube y TikTok (9:16, 15-30 s, sin voz propia, en español e inglés) del juego como borradores de CapCut hechos por script a partir de las tomas de OBS en O:/ y del tráiler, y deja el acabado (filtro, voz generada, música, exportar) al usuario. Úsala siempre que el usuario pida un Short, un vídeo vertical, un borrador de CapCut, "haz el Short de jefes en inglés", un Short nuevo con tomas nuevas, cambiar los cortes, los textos o el encuadre de un Short, o título, descripción y etiquetas de un Short, aunque no diga "CapCut". No es para el tráiler 16:9 completo ni para grabar tomas (eso es docs/videos/README.md y Trailer.toma), ni para publicar.
---

# Shorts del juego con CapCut

El agente escribe el borrador; el usuario lo abre, lo acaba y lo exporta. Nunca se publica, exporta ni borra nada sin que el usuario lo pida. Todo es local y gratis.

## Archivos

- `docs/videos/shorts/<id>.json`: guion de un Short (cortes, textos ES/EN). Formato y tablas en `docs/videos/shorts.md`. Hay `jefes`, `mascotas`, `roles` y `pvp`.
- `tools/video/short.py`: crea el borrador de un guion. `borrador.py` saca la lista de cortes de un borrador de CapCut (sobre copia). `fotogramas.py` saca fotogramas con la guía 9:16.
- Reglas de contenido y de música: `docs/videos/README.md`. Títulos, descripciones y etiquetas: `docs/videos/shorts.md`.

## Hacer un Short

1. **Lee el guion de uno parecido** (`docs/videos/shorts/jefes.json`) y `docs/videos/trailer.md`/`build/videos/cortes/trailer-esp.md` (qué toma, desde y duración tiene cada plano del tráiler; si falta, se regenera con `borrador.py` sobre una copia en `build/videos/copias/<fecha>-<nombre>/`).
2. **Escribe `<id>.json`**: 15-30 s, gancho con texto en el primer segundo, 3-5 cortes, cierre con la portada de 3 s («¡Ven con tus amigos!» + «Gratis en Roblox · Hasta 5 amigos»). Sin Robux, sin «gana dinero», sin gore. El texto va entre -0,33 y 0,33 de altura y cada texto acaba antes del vídeo. Los tiempos de los textos se calculan con la suma de los cortes (`dura / velocidad`): el script avisa si no cuadran.
3. **Elige el recuadro mirando**: `build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/<id>.json --solo-vista` y mira `build/videos/shorts/<id>/hoja.jpg`. Ajusta `cx`, `cy` y `zoom` (mínimo 1,28: el script recorta la barra de Studio y la franja de abajo). Repite hasta que el sujeto quede centrado.
4. **Crea el borrador** con CapCut cerrado: mismo comando sin `--solo-vista` (`--lang es|en` para uno solo). Sale `build/videos/borradores/<id>-<idioma>-vN/`, que el script copia a `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft\` (con `--no-instalar` no lo copia). Cada ejecución crea una versión nueva; nunca se sobrescribe un borrador.
5. **Apunta en `docs/VERIFICACION.md`** lo que el usuario debe abrir, exportar y medir (minutos de retoque; objetivo 10 o menos), y entrega el título, descripción y etiquetas.

## Lo que hace el usuario en CapCut (pasos fijos)

Abrir el borrador, ajustar cortes, añadir un filtro suave (se usó «Escritorio retro» a 30 y «Now Gen2 niebla»; los filtros Pro no valen), una voz generada que lea los textos (texto a voz, «hype guy» en inglés o «Narrador» en español; volumen +16 dB), música de la biblioteca de CapCut, YouTube o TikTok (-10 dB), y exportar a 1080×1920, 30 fps, sin marca de agua. El agente **no puede** poner filtro, voz ni música por script (`pycapcut` no los probó); computer use queda fuera.

## Receta fija (medida)

Tiempos de retoque del usuario: `jefes-en` 3 min 15 s, `roles-es` 3 min 40 s, `mascotas-es` 9 min 30 s, `pvp-en` 15 min 29 s (este por rehacer cortes). Con el guion bien encuadrado, **el proceso fijo cuesta unos 3 min**, así que lo que se repite es esto, siempre en este orden:

1. Filtro suave a lo largo de todo el vídeo («Now Gen2 niebla» o «Escritorio retro» a 30).
2. Texto a voz de los textos (EN «hype guy», ES «Narrador» / «Narrador Cálido»), +16 dB.
3. Música de la biblioteca de CapCut (-10 dB).
4. Exportar 1080×1920, 30 fps, sin marca de agua.

El agente al entregar un borrador lo dice en una línea y no pregunta por ello. Lo que se puede automatizar (ordenado por esfuerzo): música con un archivo local (`pycapcut.AudioSegment` ya se usó en `spike_v0.py`; la música de la biblioteca de CapCut es de la nube y no se puede poner por script); el filtro, solo si su nombre está en `pycapcut.FilterType` (los de la lista de CapCut no están: solo `VHS_*` y `cowboy_retro` se parecen); la voz, solo con un TTS local. Antes de usar cualquiera, un spike como `spike_v0.py` y comprobar que CapCut abre el borrador.

## Trampas conocidas

- Las tomas de `O:/` son la ventana entera de Studio: el script recorta del 14,5 % al 92,5 % de la altura. Mira las tomas: el panel de Localización, avisos del juego («Hay un huevo común…», «¡2 monos van a por ti!») y carteles de la bandera pueden tapar la acción; en `roles` el corte 3 hubo que recortarlo a mano.
- `pycapcut==0.0.4` escribe `new_version` 140.0.0; CapCut 9.7.0.4153 lo abre y lo reescribe. Una actualización de CapCut pide repetir `tools/video/spike_v0.py`. El script avisa si la versión no es la probada.
- La marca Pro de `pycapcut` (`is_vip`) no es la de CapCut: probar cada fuente o animación nueva antes de usarla. Anton no lleva marca.
- Dos textos a la vez no caben en una pista: el texto chico del cierre va en la pista `pie`.
- Tomas, copias y borradores están en `build/` (no se sube a git). `O:/` solo se lee.
- Las tomas nuevas se graban en OBS (16:9) con el recuadro central 9:16 libre (`TrailerCamara.guia(true)`).
