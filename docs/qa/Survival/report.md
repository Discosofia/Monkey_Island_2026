# QA de Survival (14-11-2026), B3: luz de las cabezas y arnés completo

Arnés `tools/cine_qa.luau` con `CineSurvival` en Play, en el Studio de la Isla (30,4 s, 59 muestras, sin `error` ni `camError`), tras los cambios de luz de esta vuelta. Medidas de luz con la receta de la skill §5 (brillo × (1 − distancia/alcance) de las luces que alcanzan la cabeza). Sin vídeo nuevo de Survival: el usuario regraba con un avatar de piel normal.

## B3: lo que pedía el plan

| Punto | Resultado |
|---|---|
| Manos amarillo-verdosas | **No es un fallo del material.** Cabeza, manos y torso del personaje real y de la copia de la escena tienen el mismo color, (0,70, 0,75, 0,27): es la piel real del avatar de prueba (verde lima, con gafas). El usuario lo cambia por uno normal. Se confirma en el vídeo siguiente (VERIFICACION §196.1.1) |
| Triángulo de luz de la grúa de apertura | **Es sombra de la empalizada.** En Play, con `GlobalShadows` apagado, las dos cuñas oscuras del suelo desaparecen y queda solo una banda suave en el borde. Es el sol bajo de las 16 h a través de las puertas |
| Cabezas brillantes (el usuario las vio como en `Night`) | **Era real**: sin la receta, `Survival` sumaba 2,1-2,8 a 1,5 s, 3,0 a 22 s y 3,5-3,6 a 25 s, con el Bloom en 1,0/2,0. Se corrigió (abajo) |

## Cambios de luz

| # | Cambio | Archivo |
|---|---|---|
| 1 | `dimLights` (luces ×0,3, partículas ×0,5, el Neon se queda) y `bloom` 0,25/3 desde 0 s | `Data/Scenes/Survival.luau` |
| 2 | `TORCH_BRIGHTNESS` de 4 a 1,5: a 25 s la `StandingTorch` caía a 4 st de la cara del avatar y aportaba 3,5 | `Cinematics/SurvivalActor.luau` |
| 3 | Evento nuevo `campfireLight { scale }` (0,5): baja a la mitad las luces de `Mapa.Basecamp.Hoguera` en este cliente mientras dura la escena y las devuelve al acabar (si nadie las tocó). La hoguera aportaba 1,4 a 22 st | `Cinematics/SurvivalActor.luau`, `Data/Scenes/Survival.luau` |

Luz efectiva sobre cada cabeza, en Play:

| t escena | Antes (avatar / cazador / médico) | Después |
|---|---|---|
| 1,5 s | 2,1 / 2,5 / 2,8 | 1,0 / 1,1 / 1,2 |
| 22 s | 1,4 / 2,9 / 3,0 | 0,7 / 1,3 / 1,3 |
| 25,3 s | 3,6 / 3,4 / 3,5 | 2,0 / 1,6 / 1,6 |
| 26,5 s | — | 2,0 / 2,3 / 1,9 |

Bloom a 0,25/3 durante la escena y de vuelta a 1,0/2,0 al acabar. Brillo de la hoguera: 2,5 → 1,25 en la escena y 2,5 al acabar.

## Marcas del arnés (no son de este cambio; sin corregir)

El arnés con las marcas de cámara de A8 nunca se había pasado en `Survival`. Salen estas, todas con hora de escena:

| Marca | Detalle | Estado |
|---|---|---|
| **camalta** | cámara a 3,2 st sobre el suelo como mínimo (a 8,9 s y 14,3 s), con la marca de 2,4 a 25,8 s (192 muestras): es la más persistente | **Abierto**: corregir o justificar plano a plano (skill §7, paso 2b) |
| **camcerca** | Avatar a 5,3 st a 18,0 s («muy cerca», de 2,4 a 19,5 s) y Cazador a 8,4 st a 8,8 s («muy cerca», de 7,2 a 14,3 s) | **Abierto**: mismo criterio. Los planos de la mesa de fabricación (16-19 s) son los candidatos a ser a propósito |
| **gui** | Caption «tapa al maniquí» Cazador de 1,6 a 17,7 s; el logo tapa al avatar de 27,7 a 28,3 s | El logo sobre el avatar es decisión ya tomada. El caption hay que mirarlo en un fotograma |
| **suelo** | los tres flotan 0,55-0,91 st de 0,5 a 27,2 s | Sospecha de falso positivo (posición fija sobre `Terrain` con snap por escena). A confirmar con captura quieta |
| **deslizando** | los tres «anclados sin pista de andar» a ~17 st/s de 0,5 a 26,2 s | Casi seguro falso positivo (corren con `move` por script al llegar al campamento). A confirmar |
| **fuera** | sin cabeza ni pies en pantalla, sobre todo Cazador y Médico | El arnés no sabe quién es el sujeto del plano; falta que lo mire el revisor |
| **luz** | `Fade` casi opaco de 28,3 a 28,8 s | Es el fundido final; a confirmar con el vídeo |
| terreno, atraviesa, banda, sinbanda | ninguna | Bien |

## Limitaciones de esta pasada

- Sin captura del anochecer con la antorcha encendida a 25-26 s: las capturas por MCP llegan tarde. Las medidas de luz son del motor; el juicio visual queda para el vídeo del usuario (VERIFICACION §196.1.2).
- No se pasó el subagente revisor ni se sacaron fotogramas por plano: solo el arnés y las medidas de luz. Quedan abiertas las marcas de cámara de arriba.

---

# Vuelta 2 (14-11-2026): marcas de cámara de A8 (skill §7, paso 2b)

Cambios solo en el bloque `shots` de `Data/Scenes/Survival.luau`. Medido en Play, Studio de la Isla, con el arnés completo y un muestreo por cuadro de la cámara (reloj anclado a los cortes nominales de plano, desfase ≈ −0,2 s, incertidumbre ~0,05 s). Alturas sobre el suelo real por rayo; distancias a la caja del maniquí visible.

## Cámara por plano: antes y después

| # | t (s) | Antes: alt. mín. / dist. mín. | Después: alt. mín. / dist. mín. | Cambio | Estado |
|---|---|---|---|---|---|
| 1 | 0-2,5 | 12,5 / 17,8 | 12,5 / 17,8 | ninguno | bien |
| 2 | 2,5-5,6 | 3,6 / 10,8 (avatar) | 5,1 / 14,1 | cámara a 4,9 de altura y a 16 st del avatar; FOV 46/44 | **corregida** |
| 3 | 5,6-7,3 | −0,5 (bajo el terreno) / 15,4 | 5,15 / copa a ≥ 21 st | cámara a g(24, 9,3, −42) → g(25, 9,3, −43), FOV 46 (ver «Vídeo del 14-11») | **corregida** (en dos pasos) |
| 4 | 7,3-9 | 3,2 / 8,3 (Cazador) | 4,7 / 11,7 (en el último cuadro) | cámara en diagonal, 4,9 de altura, FOV 42/40 | **corregida** |
| 5 | 9-11,8 | 3,3 / 7,6 (avatar) | 5,1 / 14,5 | a 4,9 de altura y 16-17 st, FOV 38/35 | **corregida** |
| 6 | 11,8-14,5 | 3,2 / 9,4 (Cazador) | 5,1 / 13,2 | a 4,9 de altura, FOV 46/40 | **corregida** |
| 7 | 14,5-17 | 6,4 / 7,0 (avatar) | 6,6 / 14,8 | de lado desde el sur, a 18 st, FOV 42/40 | **corregida** |
| 8 | 17-20 | 4,5 / 5,2 (avatar) | 5,6 / 12,9 | barrido por el sur (-38 a -24, y 5,8, z 16), FOV 38/44 | **corregida** |
| 9-11 | 20-23,5 | 4,5-4,8 / ≥ 14,8 | 4,9-5,2 / ≥ 14,8 | alturas +0,4 | bien |
| 12 | 23,5-26 | 3,6 / 12,9 | 3,07 en 1 cuadro (23,50) / 12,8 | a 4,9 de altura | **corregida** (1 cuadro de corte) |
| 13 | 26-28 | 6,5 / 16,8 | 5,75 / 16,8 | ninguno | bien |

Planos 2, 5, 6 y 7: el Cazador y el Médico (o el avatar) no salen en cuadro, sus distancias no cuentan.

## Marcas del arnés tras los cambios

| Marca | Resultado | Decisión |
|---|---|---|
| **camalta** | la vuelta 2 la dejó solo en el plano 3 (contrapicado a 3,9, 1,5-1,9 st sobre Terrain); tras el cambio de cámara del plano 3 (ver abajo) **ninguna marca**: altura mínima de los 13 planos 4,74 st (5,6 s, corte) y 5,15 en el plano 3, 0 cuadros < 4,5 | **Corregida.** Ya no hay plano bajo que justificar |
| **camcerca** | un solo cuadro cada vez, siempre a ~0,2-0,25 s de un corte (reloj del arnés): avatar 7,0 st a 2,3 s (corte 1→2), avatar 6,4 st a 7,1 s (corte 3→4), avatar a 23,3 s (corte 11→12), Cazador 10,0 y Médico 4,1 st a 25,8-25,9 s (corte 12→13) | **Artefacto del corte.** El muestreo por cuadro (reloj anclado a los cortes) no ve ningún cuadro visible a menos de 12 st (mínimos: avatar 13,3, Cazador 13,8, Médico 17,7), y en el vídeo del 14-11 los fotogramas de 7,0 y 7,5 s (plano 4) no tienen al avatar cerca. Sin cambio de código |
| **gui** (caption → Cazador, 1,6-17,7 s) | sin cambio | **Por mirar** en un fotograma (§197.1.4) |
| **gui** (logo → avatar, 27,6-28,1 s) | sin cambio | Decisión ya tomada |
| **suelo / deslizando** | sin cambio | Falsos positivos probables (teletransportes entre planos y marcha por script); a confirmar con una captura (§197.1.5) |
| **fuera** | sin cambio | El arnés no sabe quién es el sujeto de cada plano; en los planos 2, 4, 5 y 6 solo sale una pareja a la vez (a propósito) |
| **luz** (Fade 28,0-28,7 s) | sin cambio | Es el negro final |
| terreno, atraviesa, banda, sinbanda | ninguna | Bien |

Rayos cámara → cabeza del avatar y cámara → «Mesa de trabajo»: sin ningún cuadro interrumpido en los planos 7 y 8 (en la primera medición, el tronco `Log` de la mesa tapaba al avatar de 18,8 a 19,9 s, con la cámara por el oeste). En el plano 8, la cabeza del avatar y el centro de la mesa están dentro de pantalla en las 13 muestras (cada 0,25 s), con el avatar a 13-15 st.

## Vídeo del 14-11 (`O:\Videos Primal banana\2026-11-14 17-51-27.mkv`, 32,7 s) y plano 3

Hojas de contacto en `build/videos/regrabar3/survival/` (`hoja_1` a `hoja_4`, 2 fps, recorte del juego `1564:796:25:143`, y `plano3_detalle.png`, 4 fps de 5,5 a 7,5 s). Avatar de piel normal (las manos verdosas de B3 ya no aparecen).

- **Defecto 1 (corregido): la copa del árbol se estrellaba contra la cámara del plano 3.** A 6,25-6,5 s de escena, la copa del árbol que cae (hacia +x, llega a x ≈ 36) llena la pantalla con un cubo verde (`plano3_detalle.png`). Causa: la cámara de x = 30 y 3,9 st de altura estaba en el trayecto de la copa. No lo vio el arnés (solo mide maniquíes). Arreglo en dos pasos: (a) cámara perpendicular a la caída, a g(24, y, −42), a ~26 st del árbol y FOV 46; (b) el terreno sube hacia el norte (~4,2 st sobre el anchor en z = −42, medido en Play: con y = 6,7 la cámara quedaba a 2,5 st), así que y = 9,3 (5,2-5,4 st sobre el suelo). Medido en Play: copa a ≥ 21,8 st en todo el plano (nunca < 10), cabeza del avatar y centro del árbol en pantalla en todas las filas, rayo cámara → cabeza libre. El rayo cámara → tronco lo corta el Terrain de 6,9 a 7,2 s, cuando el árbol ya ha caído (la base queda tras el relieve): por mirar en el vídeo.
- **Resto del vídeo, sin defectos nuevos a simple vista:** mesa (planos 7 y 8, el arma sube, gira y pasa a la mano, avatar sin tapar), comer y beber (sujetos pequeños a 16-20 st pero legibles), travelling de muros, contraplano de la antorcha con llama visible, cierre con los tres actores, negro de 28 a 28,5 s y tarjeta «Volviendo al Basecamp». El caption «tapa al Cazador» (`gui`) no tapa su cara ni la acción en ningún plano del vídeo.
- **Anotaciones menores:** a 20,0 s hay un destello blanco en la esquina superior izquierda (el sol bajo, no un defecto de la escena); el aviso de Roblox «playing Build A Boat» arriba a la derecha hasta ~5 s es de Studio.
- **Pendiente:** el vídeo es de antes del cambio del plano 3, así que ese plano (y el árbol cayendo desde el norte) hay que verlo en una regrabación (VERIFICACION §197.1.1).

## Limitaciones de esta vuelta

- **Sin fotogramas quietos ni subagente revisor.** `screen_capture` devolvió la imagen en blanco en tres capturas (plano 3, una vista alta y otra del Basecamp), con solo el gizmo de ejes dibujado: el visor de Studio no dibujaba el mundo. Se limpiaron los marcadores y se dejó la cámara de edición en `Fixed`. Queda en VERIFICACION §197.1.
- El arnés no mira píxeles: que algo tape al sujeto sin cortar el rayo de la cabeza o del centro de la mesa no se ha medido.
- Una copia del perfil por pasada (`…antesCamSurvival`, `2`, `3`, `4` y `5` en `PlayerData_v1_backups`). No se restauró (desde Edit, «Access forbidden»); el perfil vivo solo difería de la copia en `session.time` (VERIFICACION §197.2).
- Sin commit hasta «aprobado».

## Vuelta 3 (14-11-2026, vídeo `2026-11-14 18-15-48.mkv`, 30,3 s)

Hojas en `build/videos/regrabar3/survival2/` (`hoja_1` a `hoja_4`, 2 fps, recorte `1564:796:25:143`; la escena empieza ~0,5 s dentro del vídeo).

- **Plano 3 (5,6-7,3 s): bien.** Sin cubo verde; el árbol cae hacia la derecha y se ve entero en el suelo a ~7 s (copa y tronco). El avatar queda a la **derecha** del árbol (no a la izquierda). La copa se corta un poco por arriba en los dos primeros cuadros.
- **Planos 2, 4, 5 y 8: bien.** Plano 6 (el Cazador bebe): sujetos pequeños (~60 px de 190 de alto), legibles. Plano 8: se parece de composición al 7 (mesa a un lado, avatar al otro) pero con otro fondo.
- **Defectos del vídeo, corregidos en esta vuelta (`Data/Scenes/Survival.luau`):**
  1. Plano 1: los tres actores entraban por la esquina inferior derecha, con los pies cortados hasta ~1,5 s. Ahora entran desde avatar (14, 16), Cazador (−4, 12) y Médico (14, 6).
  2. Caption «El hambre y la sed no esperan» (plano 5) y «Fabrica tu propio equipo» (plano 7) pisaban las piernas del avatar: la cámara mira más abajo (plano 5: look y 3,6 → 2,2; plano 7: 3/3,5 → 1,0/1,5) y los captions duran menos (1,7 y 1,4 s en vez de 2,2).
  3. Plano 6: FOV 46/40 → 42/36.
- **Arnés recortado** (cámara y caption contra actores; no el completo) en dos pasadas de Play, `CineSurvival`: `camalta` ninguna (mín. 4,8 st); `camcerca` solo de un cuadro pegado a un corte (avatar 7,6 st a 2,3 y 5,4 s; Cazador 10,1 st a 25,8 s; trampa g) y mínimo fuera de cortes 12,9 st; `caption` solo a 11,8 y 17,0 s (un cuadro en el corte, con el texto ya casi apagado) y a ~1,4 s en el plano 1 (pies del Cazador bajo el texto). Queda un `cortado` del Cazador de un cuadro a 0,83 s (pies bajo el borde): no se ve en el vídeo, se mira en la regrabación.
- **Perfil:** copia `u_8620190944_antesCamSurvival6`; el perfil guardado solo difiere de `…antesCamSurvival` y `…6` en `session.time`. Sin restaurar nada.
- **Sin fotogramas quietos** (trampa f); la corrección de planos 1, 5, 6 y 7 se juzga con la regrabación (VERIFICACION §198.1).

## Vuelta 4 (14-11-2026, vídeo `2026-11-14 18-29-09.mkv`, 33,5 s): cuerpos cortados

Hojas en `build/videos/regrabar3/survival3/` y `z4/` (6 fps de 6,6 a 8,4 s). El usuario vio personajes cortados en varias tomas. Causas, todas mías o del motor:

1. **Cabeza cortada por la franja de arriba en los planos 5 y 7**: bajar la mirada para despegar el caption de las piernas (vuelta 3) subió demasiado al avatar. Medido por actor y cada 0,25 s en Play (cabeza y pies como fracción del alto; las franjas son 0,12 y 0,88): cada stud que baja la mirada mueve el cuerpo 0,136 del cuadro. Ahora: plano 5 mira a 3,0/3,5 (cabeza 0,16 a 0,13, pies 0,67-0,70), plano 7 a 2,2/2,7 (cabeza 0,17-0,19, pies 0,60-0,64) y plano 8 a 4,4/3,3 (pies 0,77 en vez de 0,93).
2. **Plano 1, Cazador con los pies cortados 0,7-1,3 s**: `run` solo mueve al actor desde donde esté (su `from` solo da giro y velocidad), así que cambiar el `from` no hizo nada. La salida está en `actors` (`pos`): ahora avatar (10, −8), Cazador (−10, −6) y Médico (14, −6) (antes z 34-41), detrás de la hoguera y lejos de la cámara.
3. **Avatar enorme durante un cuadro a 7,3 s (corte plano 3 → 4)**: `cutShots` dejaba 10 ms de mezcla entre el último punto de un plano y el primero del siguiente, y a 60 fps un cuadro cae ahí (la cámara pasa a medio camino, por spline). Era lo que el arnés llamaba «camcerca de un cuadro pegado a un corte» y se tomó por artefacto del reloj (trampa g, **era real**). `CinematicKit.cutShots` deja ahora 0,5 ms: afecta a todas las escenas que lo usan (Night, Endless, Survival y las de `Cinematics`).
- **Medido tras los arreglos (Play, `CineSurvival`):** 0 cuerpos con la cabeza sobre 0,13 o los pies bajo 0,88 en toda la escena; cada corte es un salto único de cámara (2,3, 5,4, 7,2, 11,7, 14,4, 16,9, 19,9, 23,4 y 25,9 s), sin cuadros a medio camino; sin `camcerca`.

## Vuelta 5 (14-11-2026, vídeo `2026-11-14 18-59-27.mkv`, 33,3 s)

Hojas en `build/videos/regrabar3/survival4/`. Planos 1, 3, 4, 6, 7, 8, travelling, antorcha y cierre sin defectos; las cabezas ya no tocan la franja, los pies entran en cuadro, los tres actores entran enteros por detrás de la hoguera y el corte de 7,3 s ya no enseña el avatar enorme. **Defecto que quedaba:** en el plano 5 los zapatos cruzaban el caption («El hambre y la sed no esperan») al final del plano. Arreglo: FOV 38/35 → 46/43 con la misma altura de mirada. Medido en Play (9 a 11,8 s): cabeza ≥ 0,22, pies ≤ 0,70 y ningún cuerpo cortado en toda la escena. Falta verlo en una regrabación (VERIFICACION §198.1).
