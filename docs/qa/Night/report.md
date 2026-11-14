# QA de Night (11-11-2026), vueltas 1 a 5

Arnés `tools/cine_qa.luau` con `CineNight` (31 s, 61 muestras) y 4 fotogramas fijos de modo edición (`03.0`, `08.0`, `13.0_antes`, `13.0_despues`). En edición no hay avatar propio, monos de servidor ni luna roja, y la luz del cielo es aproximada. Revisor: subagente de solo lectura.

## Defectos

| # | Defecto | Prueba | Causa | Estado |
|---|---|---|---|---|
| 1 | El Cazador salía cortado por el borde derecho en el plano bajo de 11 a 16 s | `13.0_antes.jpg` | `HUNTER_NOW` en z=7 | **Corregido**: z=5,5 (`13.0_despues.jpg`). Solo queda la punta del arco rozando el borde |

## Vuelta 2: decisiones del usuario (11-11-2026)

El usuario grabó `O:\Videos Primal banana\2026-11-11 08-15-26.mkv` (hoja en `hoja_video_1.jpg`). Decidió: mover la cámara del plano lateral, bajar la cámara del cierre, y la hierba de primer plano se ve bien.

| # | Cambio | Fotograma |
|---|---|---|
| 2 | Plano lateral de 5 a 11 s: cámara de `(10, 4, -24)` a `(9, 5, -26)` mirando a f=-1 y de ahí a `(18, 5, -26)` mirando a f=12, FOV 62. Probé primero x=-2 y x=6: a menos de x≈87 la valla de la puerta tapa el plano | `07.0_lateral.jpg`, `10.0_lateral.jpg` (con un maniquí de relleno en el sitio del avatar) |
| 3 | Cierre de 26 a 29 s: cámara de y=2,2 a y=1,2 y mira a y=3,5 en vez de 6 | `27.5_cierre.jpg`. El cuerpo del avatar queda por encima de la zona del cartel (y 0,64 a 0,76); el logo, centrado, sigue cubriendo su torso mientras dura |
| 4 | El Gorila se solapaba con el avatar: el salto acababa en `gt(5, 0)` y el avatar está en `gt(2, 0)` | Aterriza en `gt(10, 0)`. Solo comprobado por geometría: los monos de servidor no existen en edición |
| 5 | La horda de 16 a 19 s salía casi negra (vídeo): la única luz que seguía a la cámara era de 0,6 | Luz propia desde 15,2 s (rosa fría, brillo 1,3, alcance 60, 4,4 s; antes en 15,8 s y el usuario la vio encenderse tarde). Con 1,8 los maniquíes salían pálidos a 8 studs. Edición no es de noche: el brillo definitivo se juzga en el vídeo |

## Vuelta 3: marcas de cámara de A8 (11-11-2026)

Con las marcas `camcerca` y `camalta` del arnés (A8, regla D1: ≥ 12 st de los actores y ≥ 4,5 st del suelo) salieron cinco planos por debajo de la regla. El usuario pidió corregirlos todos; se midió con el arnés recortado (solo la parte de cámara) en Play.

| # | Plano | Antes | Ahora | Motivo |
|---|---|---|---|---|
| 6 | Plano bajo hacia la luna, 11-16 s | cámara a 1,3 st (0,9 sobre el suelo) | 5,5 st, misma inclinación a la luna | `camalta`: a < 3 st la hierba tapa el plano |
| 7 | Contraplano de la horda, 19-22 s | 2,5 st, a x −16/−12 | 5,5 st, a x −21/−18 | `camalta` y `camcerca` (Cazador y Mago a 9,3 st a 21,8 s) |
| 8 | Choque, 22-26 s | 4,5 y 4 st (≈ 4,1 sobre el suelo) | 6,5 st | `camalta` por 0,4 st |
| 9 | Grúa, 0-5 s | final en (−21, 5,5, 7), Cazador a 10,3 st | (−26, 6, 8) | `camcerca` |
| 10 | Cierre, 26-29 s | 1,2 st rasante, a x −15/−13, FOV 48/44; el Mago a 9,5 st hacia 26 s | 5,5 st, a x −24/−22, FOV 42/38 | **Decisión del usuario:** el rasante estaba justificado (el Gorila salta hacia la cámara y el cuerpo del avatar quedaba sobre la zona del cartel, cambio 3 de la vuelta 2), pero marcaba `camalta` y el Mago. Se sube y se aleja; el FOV baja para que el Gorila siga llenando el plano |

Medido en Play después: la cámara del cierre queda a ≥ 5,4 st del suelo y a 18,5 (Mago), 20,1 (Cazador) y 23,3 st (avatar) de los maniquíes. Queda marcado solo el Babuino a 11,3 st hacia 16,9 s (corte del plano de la horda, sin tocar).

**Coste del cierre (a mirar en vídeo):** con la cámara a 5,5 st, hacia 27,4-28,5 s la cabeza del avatar queda a 0,40 de la altura de pantalla y sus pies a 0,71-0,72, y el cartel «Luna roja» empieza en 0,63. Las piernas del avatar vuelven a quedar bajo el cartel (antes el cambio 3 las había subido por encima). El título y el logo siguen tapando el torso, como ya se había decidido. Si estorba, hay que bajar el punto de mirada del cierre (y = 3,5) para subir al avatar en cuadro, no bajar la cámara.

## Vuelta 4: arnés completo (11-11-2026)

Arnés `tools/cine_qa.luau` completo, en Play con un jugador en el Studio de la Isla y sin copia del perfil (DataStore 502, §10.0), con `CineNight` (31,2 s, 61 muestras). Sin errores de Lua ni `camError`. La repetición usó el reloj nuevo de `SceneLight` (ver «Reloj»). Sin código nuevo en `Night`.

| Marca | Hora | Valor | Veredicto |
|---|---|---|---|
| `camalta` | — | Ninguna. Mínimo 4,9 st a 5,0 s | Cumple la regla de 4,5 st |
| `camcerca` Babuino | 16,9 s | 11,8 st en la primera pasada (1 muestra); 11,1 st en la repetición (16,8–17,0 s, 5 cuadros) | **Justificado.** Corte de la horda: el mínimo absoluto está por encima de 9 st (límite de «muy cerca») y solo cae en ese corte. No se mueve la cámara |
| `camcerca` Cazador y Mago | — | Ninguna | Ya no salen |
| «Deslizando» Mago, Cazador y avatar | 6,3–11,4 s | Cortes de plano con los actores en marcha | Falso positivo, como en la vuelta 1 |
| «Suelo» | 8,3 s | 0,36 st en 2 muestras | Ignorado, como en la vuelta 1 |
| «Gui» Caption sobre el Cazador | 0,5–15,1 s | Sobre el Cazador | **Decisión del usuario** (no es cámara) |
| «Gui» Title y Logo sobre el avatar | 26,5–29,2 s | Sobre el avatar | **Decisión del usuario** (VERIFICACION §188.3) |
| «Luz» Fade | 29,2–29,7 s | Negro del cierre | Normal |

**Reloj.** `ClockTime` de `Night` baja solo al arrancar (19,55 → 18,60, transición desde la hora real) y al acabar (21,58 → 6,89, cambio de noche a día tras el Fade). Es lo esperado y no se congela: queda cerrada la duda de la guarda A7 que se abrió en `Endless`.

**Sin probar** (VERIFICACION §194.1 y §194.2): la captura quieta del poste `Empalizada.GatePost` en la grúa, hacia 4,8 s, y el vídeo de los planos de la vuelta 3 (piernas del avatar bajo el cartel y Gorila del cierre).

## Vuelta 5: vídeo del 11-11 y arreglos (11-11-2026)

El usuario grabó `O:\Videos Primal banana\2026-11-11 14-44-40.mkv` (31,5 s; hojas en `build/videos/regrabar/night`). Bien en el vídeo: el plano lateral de 6 a 11 s salió limpio. Lo que estaba mal se corrigió en `src` (sin commit) y se midió con el arnés en Play. La luz y los planos nuevos solo se juzgan en el siguiente vídeo.

| # | Defecto | Causa | Arreglo | Estado |
|---|---|---|---|---|
| 11 | La horda de 16 a 19 s salía casi negra (vídeo) | Luz de cámara floja: brillo 1,3 y alcance 60 no bastaban en el tramo de la horda | Brillo 1,3 → 1,6 y alcance 60 → 70. Exposición +0,3 con tinte (255, 190, 185) a 16,0 s y −0,35 (255, 170, 160) a 19,0 s. Sin acercar la cámara (regla D1) | Corregido en `src`. Solo se juzga en el vídeo (VERIFICACION §194.2.9) |
| 12 | Choque de 22 a 26 s: acción pequeña y un poste de la valla tapando a los héroes (vídeo) | Plano lejano: cámara en gc(12, 6.5, −30) y gc(16, 6.5, −29), y el poste en la línea de visión | Cámara a gc(11, 6.5, −24) y gc(13, 6.5, −23), FOV 52/50. Mira a gc(12, 3, 0) y gc(14, 3.5, 0) | Corregido. El arnés final no marca nada en el choque. Vídeo: VERIFICACION §194.2.2 |
| 13 | Cierre de 26 a 29 s: Gorila pequeño tras el avatar (vídeo) | Cámara de la vuelta 3 a x −24/−22 con FOV 42/38: el avatar tapa al Gorila y el plano no llena | Cámara a gc(−20, 5.5, −3) y gc(−18, 5.5, −3), FOV 30/27. Mira a gc(10, 3.5, 0) y gc(8, 3.5, 0). Con x −16 el Mago salía a 10,6 st (160 muestras), por eso −20/−18 | Corregido. El arnés final no marca nada en el cierre. Vídeo: VERIFICACION §194.2.3 |
| 14 | Plano de la luna de 11 a 16 s: el Cazador a 11,9 st en un cuadro (arnés) | Cámara en gc(−16), cerca del Cazador | Cámara a gc(−18, 5.5, 0) | Corregido. El arnés final no marca al Cazador |
| 15 | Fogonazo al final (vídeo, en Night, Endless y Survival): se veía el mundo unas décimas antes de la tarjeta «Volviendo al Basecamp…» | `Presentation.finish` devolvía la imagen con un fundido de 0,5 s. El primer intento esperaba a `ArrivalHold`, pero ya valía «Arrive» y no servía | Mantiene el negro hasta que exista `PlayerGui.CinematicHold` (máx. `HOLD_BLACK_SECONDS` = 1,5 s). Cambio de motor compartido por todas las escenas que acaban en negro | Medido cada 0,05 s en Night, Endless y Survival: la tarjeta aparece 0,17–0,25 s antes de borrarse el gui y lo cubre, sin hueco. Falta el negro en el place publicado y en arranque en frío (VERIFICACION §194.1.5) y en vídeo (§194.2.10) |

**Marca de cámara justificada (Babuino).** `camcerca` a 11,1 st durante 0,3 s (16,75–17,05 s, corte de la horda). **Justificado:** no baja de 9 st (el límite de «muy cerca»), dura un solo corte, y acercar la cámara quitaría la horda, que tiene que verse (regla D1). No se mueve la cámara.

**Arnés final (Play, un jugador, sin copia del perfil: 502).** `CineNight` de 31,3 s. Sin `camalta` (mínimo 4,9 st). Una sola `camcerca`: el Babuino de arriba. Sin marcas del Mago ni del Cazador. Resto = falsos positivos conocidos: «deslizando» en los cortes, «suelo» de 0,3 a 0,7 st, «fuera» en el plano del jefe, «Fade» final, «gui» (decisión del usuario).

La vuelta 5 es el tope de la skill (cinco vueltas): lo que queda va al vídeo.

**Sin probar:** el juicio visual de la horda y del Gorila (los monos de servidor y la luz de la horda no salen en el arnés), el choque y el cierre en vídeo, dos jugadores, perfil real (502) y el negro final en el place publicado y en arranque en frío.

**Vídeo del 11-11 a las 15:25** (`2026-11-11 15-25-13.mkv`, 29,9 s; hojas en `build/videos/regrabar2/night`): el choque de 22 a 26 s sale mucho mejor, con el poste de la puerta aún tapando un poco; la horda de 16,5 a 18,5 s sigue casi negra (luz 1,6/70 y exposición +0,3 casi no se notan); el cierre de 26,5 a 28,5 s sale peor (Mago y Cazador enormes a los lados, Gorila pequeño y oscuro detrás del avatar, que aterriza en gt(10,0)); el vídeo acaba en negro a 29,5 s sin llegar a la tarjeta. Pasa al bloque siguiente: Gorila a un lado con cámara oblicua, más luz en la horda y poste librado en el choque.

## Vuelta 6: cuatro arreglos tras el vídeo de las 15:25 (14-11-2026)

Cambios en `Night.luau` (sin commit), arnés completo en Play (un jugador, sin copia del perfil: 502), dos pasadas de `CineNight` (31,2 s, 61 muestras, sin `error` ni `camError`).

| # | Cambio | Resultado del arnés |
|---|---|---|
| 16 | **Cierre 26-29 s:** el Gorila aterriza a un lado, gt(10, 6) (el Macaco 3 frena en gt(14, 3) para no chocar con él), y la cámara va oblicua por ese mismo lado: gc(−17, 6, 9) → gc(−16, 6, 9), mira a gc(6, 3.5, 3), FOV 40/38. (El Handoff proponía z ≈ −12, pero por ese lado el Mago tapa al Gorila y la recta avatar–Gorila pasa justo por ahí) | Primera pasada con la cámara en (−15, 6, 10): Cazador a 11,3 st (`camcerca`, 26,9–29,5 s). Alejada a (−17, 6, 9): **sin marca del Cazador ni del Mago**. Gorila y poste solo por geometría (ver §195.2) |
| 17 | **Horda 16-19 s:** luz de cámara 1,6/70 → 3/90 (3,8 s) y segunda luz fría fija en gc(62, 12, −2), 2,5/60, desde 15,2 s | No se mide en el arnés. Se juzga en vídeo (§195.1.2) |
| 18 | **Choque 22-26 s:** cámara +2 st en x (gc(13, 6.5, −24) → gc(15, 6.5, −23), mira a gc(14, 3, 0) → gc(16, 3.5, 0)) y el Mago avanza a gt(2, −6) de 21 a 21,9 s para librar el poste de z = −11 | Sin marcas de cámara en el choque |

**Marca justificada (Babuino):** `camcerca` a 11,5 st durante 0,2 s (16,8-17,0 s, corte de la horda). No baja de 9 st y acercarla quitaría la horda (igual que en la vuelta 5). Mínimo de altura 4,9 st (`camalta` sin marcas). Resto de marcas: falsos positivos conocidos (`deslizando`, `suelo` 0,35 st, `luz` Fade final) y `gui` (decisión del usuario). Sin `banda`, `fuera`, `terreno` ni `atraviesa`.

| 19 | **Cabezas blancas de noche** (captura del usuario, todas las escenas nocturnas) | Medido en Play: antorcha en mano de brillo 3 a 2,6-2,8 st de la cabeza, luces de armadura de 1,2-1,5 a 1-2 st, cientos de piezas Neon y Bloom 1,0/2,0. Luz efectiva sobre la cabeza ~4-7 | `dimLights` (0,3 / partículas 0,5, Neon se queda) y `bloom` 0,25/3 desde 0 s; antorcha a 1,2 (`TORCH_GLOW`). Efectiva 1,1-2,2; el Bloom vuelve a 1,0/2,0 al acabar. Lección general en la skill §5. Juicio en vídeo (§195.1.6) |

**Sin probar:** el juicio visual de los cuatro cambios (VERIFICACION §195). No había vídeo nuevo, así que no hay hojas nuevas en `build/videos`.

## Vuelta 7: vídeo del 14-11 (14-11-2026)

El usuario regrabó `O:\Videos Primal banana\2026-11-14 11-58-49.mkv` (30,4 s). Hojas en `build/videos/regrabar3/night/` (fps 2, recorte 1566:800:24:140) y cuadros sueltos en `build/videos/regrabar3/zoom/`. Sin cambios de código en esta vuelta.

| # | Plano | Resultado |
|---|---|---|
| 1 | Grúa de 0 a 5 s, poste de la valla a 4,8 s | **Bien**: el poste queda al borde y no tapa al avatar |
| 2 | Horda de 15,5 a 18,5 s (luz de cámara 3/90 y luz fría fija) | **Bien**: los monos y el Gorila se leen, sin negro ni quemado; va algo rojiza |
| 3 | Choque de 21,5 a 25 s | **Bien**: héroes a la derecha, el poste al borde sin tapar a nadie |
| 4 | Cierre de 26 a 28,5 s (cámara oblicua, Gorila en gt(10, 6)) | **Pasa con nota** (decisión del usuario): el Gorila ya no queda detrás del avatar y no salen Mago o Cazador enormes, pero el Cazador lo tapa en parte, sale oscuro y rojizo y el poste queda pegado al borde derecho. Se deja así |
| 5 | Cabezas sin brillo | **Bien a simple vista**: color y sombra, sin halo blanco. No se midió con la receta de la skill §5 |
| 6 | Negro final | **Bien**: negro de 28,5 a 29,5 s y tarjeta «Volviendo al Basecamp…» a 30 s. Cierra el punto (d) de la vuelta 5 |
| 7 | Título y logo sobre el avatar | Decisión ya tomada |

**B2 (medido en Play, 14-11):** `CinematicRedMoon` vale 0 desde que arranca la escena hasta ~11 s. Muestreado cada segundo con `CineNight`: 0 hasta la muestra de 13,1 s del reloj propio y 1 en la de 14,2 s, con la escena arrancada entre 2 y 3 s de ese reloj. El salto cae entre 11,2 y 12,2 s de escena, y el evento `redMoon` está a 11,5 s. A ~8 s vale 0 (VERIFICACION §186.2, paso 3). Incertidumbre de ±1 s por el muestreo. En el vídeo la luna es azul-violeta a ~3,5 s y a ~11 s, y rosa a 11,5 s.

## Marcas que quedan para el vídeo (no confirmadas)

| Marca | Lo que se sabe | Veredicto |
|---|---|---|
| Plano lateral de 5 a 11 s sin reparto en cuadro | Geometría: la cámara mira casi a +Z y el Cazador y el Mago quedan a unos 45° del eje, con un semicampo de 36°. Salen de cuadro de 5,2 a 10,3 s. El avatar entra a mitad del plano | **Decisión del usuario.** Vídeo del 11-11: de 6 a 11 s salió limpio. Puede ser a propósito (llegan las Martejas), pero el comentario del plano dice «avatar en medio» |
| Hierba amarilla en primer plano en `08.0.jpg` (cámara a 3 studs del suelo) | Se ve en el fotograma. No se sabe si tapa al avatar en Play | Mirar en el vídeo (VERIFICACION §188.2) |
| Título y logo sobre el avatar de 26,4 a 29 s | El arnés mide el solape. El cartel va fijo (y=0,70 y centro) y el cierre deja al avatar en el centro | **Decisión del usuario** (VERIFICACION §188.3) |
| «Deslizando» del Cazador y del Mago (6,7 a 10,9 s) | Van a 3,5 st/s con speed 0,58 | Falso positivo |
| «Deslizando» del avatar (6 a 8,6 s) | Va a 8,1 st/s y la animación se limita a speed 1,2 con referencia 6, unos 12 % por encima de lo que siguen las piernas | Leve. Apuntado en §188.4 |
| «Suelo» de 0,38 st en una sola muestra (8,3 s) | Una muestra, mientras caminan | Ignorado |
| Gorila y avatar a 3 studs (26 a 27 s) | Suposición del revisor, no se ve en edición | Mirar en Play |
| Teletransporte del avatar en 11 s | Lo tapa el corte de cámara | Probable, confirmar en el vídeo |
| Coreografía de la horda sincronizada | Los 7 monos arrancan a 17,0 s y tardan 4,3 s | Subjetivo |
| `camcerca` Babuino a 11,1 st (16,75–17,05 s) | Corte de la horda. Ya no sale en el Cazador ni en el Mago | **Justificado** (vuelta 5): más de 9 st y un solo corte. Sin acercar la cámara |

## Lo que se vio bien

Los pies tocan el suelo (`03.0`, `13.0`), vestuario del Mago y del Cazador correcto, y ningún terreno atraviesa a los actores en los fotogramas.

## Limitaciones de esta pasada

No se vieron el avatar propio, los monos de servidor ni la luna roja. El juicio de planos en movimiento y de luminancia es del vídeo del usuario.
