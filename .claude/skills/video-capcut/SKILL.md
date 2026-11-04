---
name: video-capcut
description: Crea los vídeos del juego (Short y Reel 9:16, vídeo de YouTube 16:9 de 1-3 min; en español e inglés, sin voz propia) de principio a fin hasta un borrador de CapCut casi final. Parte de una petición ("haz un short del desarrollo del Quetzalcóatl"), escribe primero el guion por escenas, busca los planos en las tomas de O:\Videos Primal banana\<vídeo>\ (inventario, detección de escenas, hojas de contacto), arma un storyboard con fotogramas y, aprobado, crea el borrador con textos, líneas de voz, música local y encuadres; el usuario pone la voz generada y el filtro y exporta. Úsala siempre que el usuario pida un Short, un Reel, un vídeo de YouTube o del juego, un vídeo vertical, un borrador de CapCut, un guion o storyboard de vídeo, "haz el Short de jefes en inglés", un vídeo con tomas nuevas, cambiar los cortes, los textos o el encuadre, o título, descripción y etiquetas, aunque no diga "CapCut". No es para el tráiler 16:9 completo ni para grabar tomas (eso es docs/videos/README.md y Trailer.toma), ni para publicar.
---

# Vídeos del juego con CapCut

El agente escribe el guion y el borrador; el usuario lo abre, pone la voz y el filtro y lo exporta. Nunca se publica, exporta ni borra nada sin que el usuario lo pida. **`O:/` solo se lee**: nada se escribe allí. Todo es local y gratis.

## Archivos

- `docs/videos/guiones/<id>.md`: guion narrativo por escenas (primer paso; formato en su `README.md`).
- `docs/videos/shorts/<id>.json`: guion técnico (cortes, textos, voz, música). Formato y campos en `docs/videos/shorts.md`. Modelos: `jefes.json`, `mascotas`, `roles`, `pvp`.
- `docs/videos/notas-plantilla.txt`: plantilla de `notas.txt` (opcional), que el usuario deja en la carpeta del vídeo.
- `tools/video/tomas.py`: `inventario`, `explorar`, `detalle` y `storyboard`. `short.py`: el borrador (y `--solo-vista`). `comun.py`: formatos, zonas útiles y recuadro. `borrador.py` y `fotogramas.py`: tráiler.
- Reglas de contenido y de música: `docs/videos/README.md`. Títulos, descripciones y etiquetas: `docs/videos/shorts.md`.
- Todo lo generado va a `build/videos/` (no se sube). Python: `build/videos/.venv/Scripts/python -I tools/video/<script>.py`.

## Tipos de vídeo

| Tipo | Lienzo | Duración | Notas |
|---|---|---|---|
| `short` | 1080×1920 | 15-60 s | YouTube Shorts y TikTok |
| `reel` | 1080×1920 | hasta 90 s | Instagram y TikTok |
| `youtube` | 1920×1080 | 1-3 min | devlog: gancho, 3-6 bloques con título, cierre con la portada |

Si el usuario no dice el tipo, se pregunta con AskUserQuestion (junto con lo que falte: la carpeta, los idiomas).

## Flujo (dos paradas: el guion y el storyboard)

1. **Petición.** De la frase salen el tema, el tipo y la carpeta: el nombre dentro de `O:\Videos Primal banana\` (si hay dudas, se listan y se confirma). Se lee `notas.txt` de la carpeta si existe; si no, se sigue con lo que dijo el usuario (la plantilla es `docs/videos/notas-plantilla.txt`).
2. **Inventario**: `tomas.py inventario "<carpeta>"`. Duración, resolución y clase de cada toma (`juego`, `studio` o `mixta`) y `gruesa-N.jpg` en `build/videos/proyectos/<slug>/` (una miniatura cada 30 s, con la marca `T<toma> m:ss`). Se mira para saber qué hay.
3. **Guion por escenas** → `docs/videos/guiones/<id>.md`: gancho → desarrollo → cierre, con objetivo, plano buscado, texto en pantalla ES/EN, voz ES/EN (~2,5 palabras/s) y segundos. Reglas de `docs/videos/README.md`: gancho en el primer segundo, sin Robux, sin «gana dinero», sin gore, cierre con la portada («¡Ven con tus amigos!» + «Gratis en Roblox · Hasta 5 amigos»). **PARADA 1: se enseña el guion en el chat y se espera el visto bueno o los cambios.** Nada se busca antes.
4. **Buscar los planos**: `tomas.py explorar "<carpeta>"` saca los cambios de escena y los picos de sonido (con caché por toma) y las hojas `explorar-N.jpg` (como mucho 8, marca `T<toma> m:ss`; `!` = pico de sonido). Se miran solo las hojas, pocas y pequeñas, y se empareja cada escena con un tramo (toma, desde, dura). Para afinar: `tomas.py detalle "<carpeta>" <toma> "desde+dura,…" --cx --cy --zoom --clase --formato` (3 fotogramas por tramo con el recuadro). El sonido de las tomas de OBS suele ser plano (ambiente): no sirve para elegir momentos. Lo que no está en las tomas va a la lista `faltan` (qué grabar, cómo encuadrar) con un sustituto propuesto con lo que hay.
5. **Storyboard**: se escribe el JSON técnico (con `formato`, `carpeta`, `clase`, `voz`, `musica`, `faltan`), se comprueba con `short.py … --solo-vista` (`build/videos/shorts/<id>/hoja.jpg`; el sujeto centrado, sin paneles de Studio ni avisos del juego) y se crea la página con `tomas.py storyboard docs/videos/shorts/<id>.json`. Se publica `build/videos/proyectos/<id>/storyboard.html` como **Artifact** privado (carga antes `artifact-design`; la página ya es autocontenida). **PARADA 2: se espera el visto bueno o los cambios.**
6. **Borrador**: con CapCut cerrado, `short.py docs/videos/shorts/<id>.json` (`--lang es|en` para uno solo). Sale `build/videos/borradores/<id>-<idioma>-vN/` y se copia a `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft\` (`--no-instalar` no copia). Cada ejecución crea una versión nueva; nunca se sobrescribe. Trae los cortes con su encuadre, los textos, la pista `voz` (las frases para el texto a voz), la música local si el guion la pide y las tomas de Studio en silencio.
7. **Entrega**: `build/videos/proyectos/<id>/publicacion.md` con título, descripción y etiquetas por idioma y red (reglas y ejemplos en `docs/videos/shorts.md`; `#Shorts` solo en YouTube Shorts), una línea con lo que queda en CapCut y, en `docs/VERIFICACION.md`, lo que el usuario debe abrir, exportar y medir (minutos de retoque; objetivo 5 o menos).

## Zonas útiles y clases de toma

`juego` = el juego a pantalla completa (se quita la franja de arriba). `studio` = el juego corriendo dentro de Studio (Play), sin la cinta ni el Explorador. `visor` = Studio en edición: solo el visor 3D. La cinta de Studio es clara (franja de arriba con media > 215; el juego, < 155), así se detecta. Una toma `mixta` cambia de una a otra: la clase se elige por corte. Sin `clase` se usa la zona de siempre (guiones antiguos). Las zonas están medidas sobre «Upgrading Quetzaqatl» (`comun.ZONAS`); si Studio cambia de disposición, se ajustan mirando la vista.

## Lo que hace el usuario en CapCut (pasos fijos)

Abrir el borrador, ajustar cortes si quiere, añadir un filtro suave (se usó «Escritorio retro» a 30 y «Now Gen2 niebla»; los filtros Pro no valen), generar la voz desde la pista `voz` (texto a voz; «hype guy» en inglés, «Narrador» o «Narrador Cálido» en español; +16 dB), añadir música de la biblioteca de CapCut si el guion no puso una local (-10 dB), y exportar a 1080×1920 (o 1920×1080), 30 fps, sin marca de agua. El agente **no puede** poner filtro ni voz por script; computer use queda fuera. El agente al entregar lo dice en una línea y no pregunta por ello.

Tiempos de retoque medidos (antes de la voz en la pista): `jefes-en` 3 min 15 s, `roles-es` 3 min 40 s, `mascotas-es` 9 min 30 s, `pvp-en` 15 min 29 s (este por rehacer cortes). Con el guion bien encuadrado, el proceso fijo cuesta unos 3 min.

## Música del repositorio

`docs/videos/musica/{alta,media,baja}/` guarda pistas por energía (ver su `README.md`). Al preparar un vídeo se propone una según el guion (jefes y PvP: alta; roles, mascotas y devlogs: media; cierres: baja) y `short.py` solo acepta las que tienen fila en el registro de licencias (`"musica"` en el guion; volumen 0,3). Música generada con IA: antes de apuntarla, confirmar el plan con el que se generó (los planes de pago incluyen uso comercial; el gratis no está claro).

## Trampas conocidas

- Las tomas de `O:/` son la ventana entera de Studio o el juego: mira siempre la hoja. El panel de Localización, avisos del juego («Hay un huevo común…», «¡2 monos van a por ti!»), el botón Admin y los carteles de la bandera pueden tapar la acción.
- Las imágenes son lo caro: se miran hojas de contacto pequeñas y solo se pide el detalle de lo elegido. Las tomas van a 60 fps y duran minutos: `explorar` tarda ~1 min por cada 15 min de toma la primera vez (después hay caché).
- `pycapcut==0.0.4` escribe `new_version` 140.0.0; CapCut 9.7.0.4153 lo abre y lo reescribe. Una actualización de CapCut pide repetir `tools/video/spike_v0.py`. El script avisa si la versión no es la probada. Las pistas de audio (`musica`) y el lienzo 16:9 están hechos con la misma API, pero hay que comprobar que CapCut abre el borrador (ver `docs/VERIFICACION.md`).
- La marca Pro de `pycapcut` (`is_vip`) no es la de CapCut: probar cada fuente o animación nueva antes de usarla. Anton no lleva marca.
- Dos textos a la vez no caben en una pista: el texto chico del cierre va en `pie` y la voz en `voz`.
- Las tomas nuevas se graban en OBS (16:9) con el recuadro central 9:16 libre (`TrailerCamara.guia(true)`).
