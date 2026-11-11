# QA de Night (11-11-2026), vuelta 1 de 5

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

## Marcas que quedan para el vídeo (no confirmadas)

| Marca | Lo que se sabe | Veredicto |
|---|---|---|
| Plano lateral de 5 a 11 s sin reparto en cuadro | Geometría: la cámara mira casi a +Z y el Cazador y el Mago quedan a unos 45° del eje, con un semicampo de 36°. Salen de cuadro de 5,2 a 10,3 s. El avatar entra a mitad del plano | **Decisión del usuario.** Puede ser a propósito (llegan las Martejas), pero el comentario del plano dice «avatar en medio» |
| Hierba amarilla en primer plano en `08.0.jpg` (cámara a 3 studs del suelo) | Se ve en el fotograma. No se sabe si tapa al avatar en Play | Mirar en el vídeo (VERIFICACION §188.2) |
| Título y logo sobre el avatar de 26,4 a 29 s | El arnés mide el solape. El cartel va fijo (y=0,70 y centro) y el cierre deja al avatar en el centro | **Decisión del usuario** (VERIFICACION §188.3) |
| «Deslizando» del Cazador y del Mago (6,7 a 10,9 s) | Van a 3,5 st/s con speed 0,58 | Falso positivo |
| «Deslizando» del avatar (6 a 8,6 s) | Va a 8,1 st/s y la animación se limita a speed 1,2 con referencia 6, unos 12 % por encima de lo que siguen las piernas | Leve. Apuntado en §188.4 |
| «Suelo» de 0,38 st en una sola muestra (8,3 s) | Una muestra, mientras caminan | Ignorado |
| Gorila y avatar a 3 studs (26 a 27 s) | Suposición del revisor, no se ve en edición | Mirar en Play |
| Teletransporte del avatar en 11 s | Lo tapa el corte de cámara | Probable, confirmar en el vídeo |
| Coreografía de la horda sincronizada | Los 7 monos arrancan a 17,0 s y tardan 4,3 s | Subjetivo |

## Lo que se vio bien

Los pies tocan el suelo (`03.0`, `13.0`), vestuario del Mago y del Cazador correcto, y ningún terreno atraviesa a los actores en los fotogramas.

## Limitaciones de esta pasada

No se vieron el avatar propio, los monos de servidor ni la luna roja. El juicio de planos en movimiento y de luminancia es del vídeo del usuario.
