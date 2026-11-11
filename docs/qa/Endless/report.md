# QA de Endless (11-11-2026), 2 vueltas del arnés

Arnés `tools/cine_qa.luau` con `CineEndless` (30,6 s), en Play con un jugador y sin copia del perfil (DataStore 502 en Studio), y fotogramas fijos de modo edición con un Caudillo temporal en (0, 100) (`22.6_contrapicado_inicio.jpg`, `25.2_contrapicado_fin.jpg`, `25.2_lateral_antes.jpg`, `25.2_lateral_despues.jpg`, `27.6_cierre.jpg`). En edición no hay avatar propio, monos de servidor ni luna roja, y la luz del cielo es aproximada. Los defectos a a g son los de la grabación del 10-11 (hojas en `build/videos/endless_hojas/`, VERIFICACION §187.7); el h salió del arnés. Medidos en Play: duración ≈ 30,6 s, sin líneas «[CinematicClient]», sin errores de Lua y sin avisos de carga de perfil.

## Defectos

| # | Defecto | Causa | Arreglo | Estado |
|---|---|---|---|---|
| a | El Caudillo de plató se veía pequeño en la puerta sur de día (Día 11) | `runEndless` lo planta en (0, 100) al lanzar y la grúa del Día 11 mira hacia la puerta | Nace enterrado 400 studs (`StageSpot`) y el evento de servidor `stageShow` lo sube a 20,9 s; `stageHide` queda disponible | Medido en servidor: −400 hasta ≈20,4–20,9 s y 0 después. Sin ver en vídeo |
| b | La barra del jefe pisaba el reloj grande del Día 12 | `BossBar` y `DayClock` van los dos a `TOP_BAND` + 12–14 px | `dayClock` acepta `drop`; el Día 12 usa 52 (reloj a Offset.Y 64, la barra mide 56 bajo la franja) | Medido (Y 64). Sin ver en vídeo |
| c | Plano del Caudillo casi quieto y cortado; Roar y Stomp fuera de cuadro | El plano se movía 2 studs a y 9–10 desde 15 studs; el Roar caía en el contraplano lejano | Tres planos de noche: contraplano 21–22,6, contrapicado 22,6–25,2 y lateral con travelling 25,2–27,6; Roar y rugido a 23,0, Stomp a 25,5, con sacudidas a 23,1 y 25,8 | El jefe sale entero en los dos primeros. El lateral original (cámara a y=1,5) salía tapado por la hierba y con la valla en cuadro (`25.2_lateral_antes.jpg`): subido a y=4,5 y acercado (`25.2_lateral_despues.jpg`). Sin ver en vídeo |
| d | El Cazador tapaba al avatar el Día 10 | La línea cámara → avatar pasaba a 1,8 studs del Cazador | Cazador a `pl(-12,0,-13)` y Médico a `pl(5,0,-13)` de 15,0 a 18,0 | Solo por geometría (la línea queda a unos 6 studs). Sin ver en vídeo |
| e | El plano general del Día 11 quedaba lejos para leer el grado III | Grúa de unos 50 a 60 studs | Grúa de `pl(-22,8,-22)` a `pl(-16,16,-28)`, FOV 55 a 58 (unos 30 studs) | Sin ver en vídeo |
| f | El título «Modo infinito» quedaba tapado por el cartel «🏡 Parcela de …» | La cámara del cierre a `pl(0,5,-24)` miraba a +Z a través del cartel | `plotSign { show = false }` a 27,4; cámara más baja, mirando al cielo (`27.6_cierre.jpg`: cielo detrás del título, empalizada al fondo) | Sin ver en vídeo |
| g | El reloj del Día 7 iba hacia atrás (07:29, 06:34, 06:18, 07:30) | `CinematicClockSeconds` son los segundos para recorrer 12 h, no la duración del cambio (`LightingController`, l. 163–178) | `ramp` en `Endless` (seconds = 12·duración/\|Δhora\|) y guarda A7 en `PlotActor` (dentro de un día el texto no baja la hora) | Medido: el texto solo baja en los cambios de día. Sin ver en vídeo |
| h | El Cazador del cierre atravesaba `Cofre III.LidTop` (27,5–30,1 s) | Estaba en `pl(-6,0,-10)`, sobre el cofre de `pl(-8,0,-8,5)` | Los tres del cierre en `pl(0,0,-10)`, `pl(-4,0,-12)` y `pl(4,0,-12)` | Arnés repetido: sin marca «atraviesa» |

## Marcas que quedan para el vídeo (no confirmadas)

| Marca | Lo que se sabe | Veredicto |
|---|---|---|
| ClockTime del Día 12 que baja | En la primera pasada de Play bajó de 18,4 a 17,3 h y el texto se quedó en 18:28. En la segunda, subió de 18,5 a 19,5 h (+0,19 h/s). No se reprodujo. Hipótesis sin confirmar: ambigüedad de 12 h entre la hora real y la fijada, que `LightingController` resuelve por el camino corto | **Abierta.** Mirar el Día 12 en el vídeo y repetir el Play 2–3 veces |
| Guarda A7 en `Night` | Podría congelar la hora si allí retrocede sin cambiar de día | **Abierta.** Pasar el arnés a `Night` |
| El Caudillo en la grúa del Día 11 | Sube de golpe a 20,9 s; no se sabe si asoma antes | Mirar en el vídeo |
| Rugido y pisotón en cuadro | Solo vistos los planos quietos | Mirar en el vídeo |
| «Suelo» 0,5–0,67 st constante | Igual para los tres, de 1 a 29 s | Falso positivo probable |
| «Deslizando» (6,2–27,5 s) | Coincide con los cortes de plano | Falso positivo |
| «Fuera» de los tres en 22,8–27 s | Es el plano del jefe, a propósito | Normal |
| «Fuera» del Cazador desde 6,2 s | Sin comprobar | Mirar en el vídeo |
| «Gui» Caption sobre el Médico, 0,5–22,3 s | Duración sospechosa | Falso positivo probable |
| «Gui» Title, Subtitle y Logo sobre el Cazador, 28,0–30,1 s | Con la cámara baja el cartel ocupa el centro | **Decisión del usuario**, como en `Night` |
| «Luz» Fade 29,6–30,1 s | Es el negro final | Normal |

## Cambio posterior a las dos vueltas

El usuario vio que el subtítulo «¿Cuántos días aguantas?» duraba muy poco. El cierre se alargó 1,4 s: título con `seconds` 2,6 (antes 1,4), logo a 30,4 s, negro a 30,6 s y la escena pasa de ≈ 30,6 s a ≈ 32 s. Sin medir en Play ni ver en vídeo.

## Lo que se vio bien

Duración ≈ 30,6 s sin líneas de `waitTerrain`; sin errores de Lua; ninguna marca de terreno en las dos vueltas; sin «atraviesa» tras mover el cierre; el Caudillo se ve entero en los dos primeros planos de noche; el cierre no tiene terreno ni árboles en medio.

## Limitaciones de esta pasada

- Sin copia del perfil (§10.0): el 502 de Studio la impide, y `Endless` pudo quedar en `cinematicsSeen`.
- Un solo jugador. Sin 2 jugadores, calidades Baja y Media, juego publicado ni `Rendimiento`.
- No se vieron el avatar propio, los monos de servidor ni la luna. `waitTerrain` sin medir para las cámaras de noche (≈ 20 studs de `(0,0,81)`).
- Los arreglos a a h no se han visto en vídeo: el juicio de planos en movimiento es de la grabación del usuario.
