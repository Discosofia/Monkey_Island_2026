# QA de Endless (11-11-2026), vueltas 1 a 4 del arnés

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

## Vuelta 3 (arnés completo con A8 y A6, 11-11-2026)

Arnés completo `tools/cine_qa.luau` (con `camcerca`, `camalta`, `banda` y `sinbanda`) en `CineEndless`, en Play con un jugador en el Studio de la Isla, sin copia del perfil (DataStore 502). Cinco pasadas (tope de la skill). Duración medida 33,5–33,8 s con el reloj de muestreo: la escena dura 32,0 s y el arnés suma unos 1,5 s de lanzamiento y fundido. Sin errores de Lua y sin líneas `[CinematicClient]` ni `[StageBosses]`.

### Defectos

| Marca | Causa | Arreglo | Estado |
|---|---|---|---|
| Caudillo a 4,7 st (23,9–27,4 s) | El contrapicado y el lateral iban demasiado cerca del jefe. Su caja mide ±3,9 × ±5,1 st en horizontal y crece con la animación | Contrapicado 22,6–25,2 s de (16,4,84)→(8,3,86), FOV 55/58, a (24,5.6,76)→(18,5.6,78), FOV 42/44. Lateral 25,2–27,6 s de (−14,4.5,92)→(−10,5,90), FOV 52, a (−20,6,92)→(−18,6.4,88), FOV 44, mirando a (0,9.5,100) | Medido en la 5.ª pasada: queda una marca de 8,7 st en una muestra (25,0 s) con la versión anterior del contrapicado. Después se alejó más **sin volver a medir**. Medido en la vuelta 4 (abajo): sin marca del jefe |
| `camalta` mínimo 2,2 st (0–28 s) | Cámara baja en el plano inicial (2,2 y 2,4 st) y en el contraplano de 21 a 22,6 s (3,2 st) | Plano inicial 0–3 s a 6,2 y 6,4 st. Contraplano de (0,3,46)/(1,3.2,49) a (0,5.8,42)/(1,6,45), mirando a (0,10,100) | Cerrado: mínimo 5,0 st en la 5.ª pasada |
| Cazador a 10,8 st y Médico a 11,8 st al inicio del cierre (27,5 s) | Cámara del cierre en `pl(0,2.5,-24)`, baja y cerca de los tres del cierre | Cierre de `pl(0,2.5,-24)` a `pl(0,5.8,-30)`, mirando a `pl(0,10,4)` | Cerrado: sin `camcerca` de Cazador, Médico ni avatar en la 5.ª pasada |

### Reloj

**Causa:** `LightingController` perseguía un desfase sin envolver y no sabía la hora de origen. En el Día 7 el salto y la rampa caían en el mismo cuadro: ganaba la rampa y el cielo bajaba desde la hora residual (9,1 → 7,9). En el Día 12 el objetivo cruzaba las 12 h y el desfase daba la vuelta de 23 h (18,5 → 17,9).

**Arreglo:** `SceneLight.setClock` admite `from` (con `seconds` 0 usa su propia hora) y escribe `CinematicClockFrom` y el contador `CinematicClockJump`. `LightingController` coloca el desfase en esa hora en el mismo cuadro y avanza por la diferencia envuelta. `Endless.ramp` manda `from`.

**Medido en 3 Plays:** en el Día 7, `ClockTime` sube monótono de 6,14 a 7,54 h; en el Día 12, de 18,65 a 19,50 h. Solo baja en los reinicios de día esperados (Días 8 a 11, de 17,5 a 6,x h) y al final. Es por cliente: cada jugador ve su propia hora. Falta el vídeo (VERIFICACION §194.2).

### El Caudillo de plató

Medido en el cliente en dos Plays: sube de golpe a 20,78 y 20,83 s desde el inicio de la escena. Coincide con `stageShow` (20,9 s) y cierra la duda del informe de la vuelta 2 («sube tarde»). Caja: centro `(0, 18.1, 99.4)`, tamaño `(7.76, 12.36, 10.20)`, suelo en Y 12,0. Sin ver en vídeo.

### Marcas que quedan

| Marca | Lo que se sabe | Veredicto |
|---|---|---|
| Caudillo a 8,7 st (25,0 s) | Una muestra, al final del contrapicado con la caja abierta (rugido). Se midió antes de alejar el plano | **Cerrada en la vuelta 4.** Con el contrapicado nuevo, a ≥ 21 st, no sale ninguna marca del jefe (VERIFICACION §194.1) |
| «Deslizando» en los cortes, 57 a 78 st/s | Coincide con los cortes de plano | Falso positivo |
| «Suelo» de 0,4 a 0,7 st constante | Igual que en la vuelta 2 | Falso positivo probable |
| «Fuera» de los tres en 22,9–27,0 s | Es el plano del jefe | Normal |
| «Luz» Fade final | Negro del cierre | Normal |
| «Gui» Caption sobre el Médico, 0,5–22,4 s | Igual que en la vuelta 2 | Falso positivo probable |
| «Gui» Title, Subtitle y Logo sobre el avatar y el Cazador, 27,6–31,2 s | El cartel ocupa el centro del cierre | **Decisión del usuario**, como en `Night` |

**Cerradas de la vuelta 2:** `ClockTime` del Día 12 (ya no baja, medido en 3 Plays), guarda A7 en `Night` (no se congela, vuelta 4 de `Night`) y el Caudillo que «sube tarde» (medido a 20,8 s). «Fuera» del Cazador desde 6,2 s: sin datos nuevos. Abiertas para el vídeo: rugido y pisotón en cuadro.

## Vuelta 4: vídeo del 11-11 y arreglos (11-11-2026)

El usuario grabó `O:\Videos Primal banana\2026-11-11 14-45-19.mkv` (33,3 s; hojas en `build/videos/regrabar/endless`). Bien en el vídeo: el reloj ya no baja (Día 7, de 06:13 a 07:00; Día 12, de 18:31 a 19:30) y el Caudillo sube a 20,8 s sin asomar antes. Mal: el contrapicado de 22,5 a 24,5 s y el cierre, más el fogonazo final. Todo se corrigió en `src` (sin commit) y se midió en Play con el arnés.

| # | Defecto | Causa | Arreglo | Estado |
|---|---|---|---|---|
| i | Contrapicado de 22,5 a 24,5 s: solo se veía una pared naranja (vídeo) | **Regresión mía de la vuelta 3:** la cámara (24,5, 5.6, 76) → (18, 5.6, 78) quedó dentro de la empalizada (radio ≈ 80 < 81) | (28, 5.8, 90) → (25, 5.8, 88), FOV 42/44. Fuera de la empalizada (radio ≥ 91) | Corregido. El arnés final no marca al Caudillo. Vídeo: VERIFICACION §194.2.6 |
| j | Cierre de 27,6 a 30,5 s: parcela y héroes diminutos con el título encima, y la barra «Chimpancé Caudillo» aún en pantalla (vídeo) | Cámara de la vuelta 3 (pl(0, 5.8, −30), mira a pl(0, 10, 4)) demasiado lejos. La barra del jefe no tenía evento para quitarla al acabar su escena | Cámara a pl(0, 5.8, −28), mira a pl(0, 9, 4), FOV 44. Evento nuevo `bossBarHide { seconds? }` (`BattleActor`, fundido de 0,4 s) a 27,4 s en `Endless` | Corregido. Medido: la barra desaparece entre 27,56 y 27,81 s. Vídeo: VERIFICACION §194.2.7 |
| k | Fogonazo final: se veía el mundo unas décimas antes de la tarjeta «Volviendo al Basecamp…» (vídeo) | Mismo motivo que la fila 15 de `Night` (vuelta 5) | `Presentation.finish` mantiene el negro hasta `CinematicHold` (máx. 1,5 s) | Medido cada 0,05 s: la tarjeta aparece 0,17–0,25 s antes de borrarse el gui. Vídeo: VERIFICACION §194.2.10 |

Arnés `CineEndless` completo en Play (33,9 s), un jugador, sin copia del perfil (502):

| Marca | Hora | Valor | Veredicto |
|---|---|---|---|
| `camcerca` Cazador | 17,9 s | 11,5 st, una muestra | **Justificado.** Último tramo del plano del Día 10 (15 a 18 s, cámara sin tocar), corte a la grúa del Día 11 |
| `camcerca` avatar | 22,4 s | 9,5 st, de una pasada anterior (n = 2) | **No reproducido.** En 21,5–24 s, medido a 0,1 s, la distancia mínima fue 16,4 st (la caja del avatar es pequeña). Probablemente un cuadro de corte con el reloj del arnés desfasado. Abierto para el vídeo (VERIFICACION §194.2.5 y §194.2.6) |
| `camcerca` Caudillo | — | Ninguna con el contrapicado nuevo (a ≥ 21 st) | **Cerrada.** La marca de 8,7 st de la vuelta 3 ya no sale |
| `camalta` | — | Ninguna. Mínimo 4,9 st | Cumple la regla de 4,5 st |
| «Deslizando», «suelo», «fuera» del jefe, «gui» y «Fade» | — | Igual que en la vuelta 3 | Falsos positivos, o decisión del usuario (logo sobre el Cazador) |

**Sin probar:** el juicio visual en vivo (el MCP no dibuja la escena), dos jugadores, perfil real (502), el negro final en el place publicado y en arranque en frío, y la marca del avatar a 9,5 st (no reproducida).

**Vídeo del 11-11 a las 15:25** (`2026-11-11 15-25-53.mkv`, 35,6 s; hojas en `build/videos/regrabar2/endless`; la escena empieza 2,5 s dentro del vídeo): contrapicado sin pared naranja y lateral limpio; barra del jefe fuera en el cierre; reloj del Día 12 de 18:31 a 19:30; negro de 33,5 a 34,5 s y tarjeta a 35,0 s, sin fogonazo; el cierre (30 a 32 s del vídeo) arranca muy cerca y «Modo infinito» cae sobre el grupo: abierto.

## Vuelta 5: cierre más bajo (14-11-2026)

Cambio en `Endless.luau` (sin commit): cierre de 27,6 a 32 s, de cameraKey(endCamera, pl(0, 9, 4), 44) → cameraKey(pl(3, 20, −60), pl(0, 4, 3), 60) a cameraKey(endCamera, pl(0, 1, 4), 50) → cameraKey(pl(3, 15, −48), pl(0, 1, −4), 52). Mirar más bajo sube al grupo en el cuadro y evita que los pies queden bajo la franja y el título; el final se acerca para que la parcela no salga pequeña. El Handoff pedía mirar a pl(0, 5, 4); con eso los pies quedan hacia 0,82 de pantalla, dentro de la banda del título (0,64-0,76), así que se bajó a y = 1.

Arnés completo en Play (33,7 s, 66 muestras, sin `error` ni `camError`): **ningún `camcerca` de Cazador, Médico ni avatar y ninguna `camalta`** (mín. 5,7 st); sin `terreno`, `atraviesa` ni `sinbanda`. El cierre no se midió por la marca de pantalla: se juzga en vídeo (VERIFICACION §195.1.4).

| Marca | Detalle | Veredicto |
|---|---|---|
| `camcerca` Caudillo | 4,0 st, **un solo cuadro**, t = 25,0 s (corte del contrapicado al plano lateral, con la caja del jefe abierta por el rugido) | **Sin cerrar, no es de este cambio.** La vuelta 4 midió 8,7 st en el mismo punto y lo dio por cerrado con el contrapicado alejado; ahora vuelve más cerca. Un cuadro en el corte; se mira en vídeo (§195.1.5) y, si se ve, se aleja el final del contrapicado |
| `banda` DayClock + `gui` DayClock+Name | una sola muestra a 27,5 s | Es el cambio de `dayClock show=false` a 27,5 s; falso positivo de una muestra |
| `deslizando` (56-77 st/s), `fuera`, `suelo` 0,5-0,7 st | maniquíes anclados que saltan de sitio entre planos | Falsos positivos conocidos |

**Cabezas blancas de noche (14-11-2026).** Mismo defecto que en `Night` (ver su vuelta 6, fila 19): `dimLights` y `bloom` 0,25/3 a 21,0 s, al empezar el Día 12. Medido en Play a 24,5 s: Bloom 0,25/3,0 y luz efectiva sobre la cabeza 0,0-0,3. Juicio en vídeo (VERIFICACION §195.1.6).

## Vuelta 6: vídeo del 14-11 (14-11-2026)

El usuario regrabó `O:\Videos Primal banana\2026-11-14 11-59-28.mkv` (37,3 s; la escena empieza ~2,5 s dentro). Hojas en `build/videos/regrabar3/endless/` y cuadros sueltos en `build/videos/regrabar3/zoom/` (`endless_27.6.jpg`, `endless_27.8.jpg`). Sin cambios de código en esta vuelta.

| # | Plano | Resultado |
|---|---|---|
| 1 | Cierre de 27,6 a 32 s (pl(0, 5,8, −28) mirando a pl(0, 1, 4), FOV 50) | **Bien**: los tres salen enteros, sin cortar por el borde inferior ni por la franja. «Modo infinito» cae debajo del grupo, no encima. La parcela queda pequeña pero legible. A 33,5 s del vídeo el logo vuelve a cubrir al grupo (decisión del usuario) |
| 2 | `camcerca` del Caudillo a 25,0 s (4,0 st en un cuadro, corte al lateral) | **Sin defecto visible**: a 27,6 y 27,8 s del vídeo (≈ 25,1 y 25,3 s de escena) el Caudillo sale entero y de lado, sin la cámara dentro ni un cuadro tapado. A 2 fps no se resuelve el cuadro exacto del corte |
| 3 | Reloj del Día 12 | **Bien**: de 18:30 a 19:30 sin dar la vuelta |
| 4 | Negro final | **Bien**: negro de 33,5 a 34,5 s y tarjeta sin fogonazo |
| 5 | Cabezas | **Bien a simple vista**: las del Caudillo y los héroes salen normales. No se midió con la receta de la skill §5 |
| 6 | Pies del Caudillo en el contrapicado | Cortados por la franja y el subtítulo (ya anotado, no bloquea) |

## Lo que se vio bien

Duración ≈ 30,6 s sin líneas de `waitTerrain`; sin errores de Lua; ninguna marca de terreno en las dos vueltas; sin «atraviesa» tras mover el cierre; el Caudillo se ve entero en los dos primeros planos de noche (**corrección de la vuelta 4:** en el vídeo del 11-11 el contrapicado de la vuelta 3 salió con pared naranja, ya arreglado); el cierre no tiene terreno ni árboles en medio.

## Limitaciones de esta pasada

- Sin copia del perfil (§10.0): el 502 de Studio la impide, y `Endless` pudo quedar en `cinematicsSeen`.
- Un solo jugador. Sin 2 jugadores, calidades Baja y Media, juego publicado ni `Rendimiento`.
- No se vieron el avatar propio, los monos de servidor ni la luna. `waitTerrain` sin medir para las cámaras de noche (≈ 20 studs de `(0,0,81)`).
- Los arreglos a (Caudillo de plató) y g (reloj) se confirman en el vídeo del 11-11. El c (planos del Caudillo) y el cierre del f salieron mal en ese vídeo y se corrigieron en la vuelta 4 (filas i y j). Los arreglos b, d, e y h no constan en el vídeo del 11-11: sin verificar en vídeo.
