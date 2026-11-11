---
name: cinematicas-roblox
description: Crea, revisa y corrige las cinemáticas del juego (escenas de Shared/Data/Scenes, motor Cinematics, cómics, reels, escenas de jefes, monturas, mascotas, pelota, Naufragio, Supervivencia, Noche, Endless o Laboratorio), con las trampas aprendidas en la Fase 25 y un bucle de revisión automática (arnés tools/cine_qa.luau + subagente revisor) que se pasa ANTES de pedir al usuario que grabe. Úsala siempre que el usuario pida hacer, retocar, arreglar, regrabar o dejar lista para grabar una cinemática ("regraba Night", "el avatar se hunde en la pendiente", "que el título no tape al mono", "revisa la escena antes de grabar", "QA visual", "cómic", "reel"), aunque no diga "skill".
---

Reglas de fondo en `CLAUDE.md` («Cinemáticas (Fase 25)», «Lista de entrega de cinemáticas», «Trampas de Luau»). Detalle por grupo en `docs/PLAN.md` → Fase 25 (cada Handoff trae sus «trampas»; las citas G2, G4… de abajo remiten a ellos). Esta skill junta lo aprendido y el método de revisión.

Si la orden puede referirse a varias cosas (qué cinemática, qué jefe, «rayos» = relámpagos o destellos), repite tu interpretación en una línea y confirma antes de editar.

## 1. Motor y archivos

- Escena nueva: `Shared/Data/Scenes/<Nombre>.luau` con `require` de `Shared/Data/CinematicKit` (tipos, `cameraKey`, `cutShots`, `actionWriters`, `yawBetween`, `DUSK_HOUR`) y una línea en `Data/Cinematics`. Ese archivo está en el tope de locales de Luau (200): bloques en funciones propias, y mide antes de añadir (G10, G14c).
- Toda escena lleva `hour` (`DUSK_HOUR` 18,8). Sin ella sale con el ciclo real y el sol la quema. La hora va por el evento `clock` de `Cinematics/SceneLight`; no escribas `Lighting` a mano, `LightingController` lo pisa cada cuadro (usa `CinematicBrightnessScale` y la ColorCorrection propia).
- **No quitar el `seek`**: los eventos de servidor (`bossAct`, `bossRoar`, `bossSkill`, monos) se programan con `task.delay` desde `CinematicService.play` y el `seek` los alinea; sin él `Night` y `Endless` se desfasan ~4 s (G14d). El `seek` no rebobina actores ni repite `title`/`caption`.
- Actores: `Actors.spawn(def, anchor, ctx)` y `Actors.cleanup(ctx)` (campos `copy`, `localPlayer`, `snap`, `weapon`, `role`, `armor`, `torch`, `ballGear`…). Se llaman `Cinematic_<rol>`. El avatar de escena es una copia (`copy = true`); el real se esconde (Dunas lo manda a la sala de espera a los ~0,5 s).
- Monos reales: `hideEnemies` y `freeze` en toda escena con el avatar fuera del Basecamp; los monos de cinemática llevan `Config.Combat.CinematicActorTag` y los borra `CinematicService.onEnd`. Vegetación real en plano: evento `hideReal`.
- Cada escena nueva necesita su orden en `DebugCommands` (`CineXxx`) y su id en la lista del servicio del place (Isla `DebugService`, Dunas `ArenaDebugService`, Lab `LabDebugService`, Lobby `CineShipwreck`). Textos con `T()` y `Data/Strings/Content.luau`.
- Jefe de plató (G14d): nace enterrado (atributo `StageSpot`, que guarda `DebugService.runEndless`) y el evento `stageShow` lo sube; `stageHide` lo esconde. Sin el evento se ve desde el inicio del día, como en el Día 11 de `Endless`. Cada jefe de plató tiene su entrada en `Shared/Data/StageBosses` (jefe, carpeta, place `map` o `basecamp`, offset, facing, hidden) y se monta con `StageBoss.mount(sceneId, basecampAnchor?)`. `IslandBossHooks` avisa con `[StageBosses]` (warn) si no cuadra con los eventos: jefe enterrado sin `stageShow`, escena con `stageShow`/`stageHide` sin entrada, o entrada sin escena (A5).
- `require` de `Data/Cinematics` en modo edición se cuelga: las escenas se prueban en Play.

## 2. Suelo, terreno y avatar real

- El terreno lejano (~950 studs) llega grueso y alto: trae al personaje cerca, espera `waitTerrain` y 2,5 s. **`waitTerrain` compara `anchor.Y + point.Y`**: con una y mal medida nunca se cumple y se pierde la apertura sin avisar (4 s en `Night` y `Endless`, G14d). Mide la altura real. `CinematicClient` avisa «waitTerrain X s» si pasa de 0,3 s.
- `RequestStreamAroundAsync` caduca a los ~5 s: `CinematicService` lo renueva cada segundo (`STREAM_RENEW_SECONDS`).
- Al volver al Basecamp espera `Remotes.ArrivalGround` (4 rayos con suelo) o el personaje cae al vacío.
- `Actors` `snap` coloca con rayo contra Terrain. Rayos desde dentro de la roca no dan nada: usa `Terrain:ReadVoxels`.
- Hierba (~3 studs): una cámara a menos de ~8 studs sobre césped queda tapada.
- La cámara a menos de 9–12 studs de un actor o de un grito de guerra tapa la imagen.
- Cámara a menos de 3 studs de altura: se llena de hierba (en `Endless`, a 1,5 st, tapaba al jefe). Usa ≥ 4,5 st salvo plano a propósito.
- El cierre de escena no debe poner actores sobre estructuras: en `Endless`, el Cazador atravesaba Cofre III.LidTop. El arnés lo marca como «atraviesa».

## 3. Armas, animaciones y poses

- `WeaponTools.build` mezcla `Weld` y `WeldConstraint`: `Actors.alignWeapon` **antes** de meter el maniquí al `Workspace` (G4).
- Las poses del juego (`Aim*`, `Hold`, `toolnone`) no sirven para un maniquí quieto: pose propia `WeaponCarry` (Action4, por encima de los gestos Action3). Los gestos con el brazo del arma (`GESTURES_WITH_WEAPON_ARM`) pausan la pose.
- `AnimationTrack` cargada con el modelo sin padre queda con peso 0: cárgala cuando ya está en el mundo (G8). Los rigs con `AnimationConstraint` no se mueven en edición: mide en Play.
- Las pistas `Run*` ignoran `speed`; `animSpeed` solo vale para actores de cliente (los de servidor, como el Gorila de `Night`, no).
- Un `fpView` activo bloquea otro: apágalo antes de cambiar de actor (G13). Un avatar copia nace invisible si hereda `Transparency = 1` (G14b).

## 4. Cómic, interfaz y textos

- El `ScreenGui` «Cinematic» usa `ZIndexBehavior.Global`: la capa de página va a `ZIndex` 1 y manda el orden de creación; los paneles salen negros si no (G7).
- Cartel en y=0,70 y subtítulo en y=0,80 (zona segura 9:16). Un texto dura 0,5 + `seconds` + 0,6 s. Bocadillos sobre la cara: `side`. Onomatopeyas: una guarda omite las de menos de 0,7 s. Banda reel: `Comic.reelBand`, sin medidas fijas.
- Barra del jefe y reloj del día: `dayClock` acepta `drop` (px) para no pisarse (Día 12 de `Endless`, drop 52). El cartel de la parcela se apaga con `plotSign {show}` y `plotMarker {sign=false}`: el título del cierre no puede caer sobre él.
- «Saltar» (`Skip`, 160×48 abajo a la derecha): el texto de esa esquina lo tapa. `noSkip` en el Naufragio. Solo se pulsa con clic real por `instance_path`.
- Viñetas congeladas: tope `Config.Budgets.Comic.FrozenParts` = 1.500. Una viñeta grande de 14 studs deja un avatar pequeño sobre fondo vacío.
- Línea que empieza por `(` se pega a la anterior como llamada; tildes o eñes en comentarios de código mandado por MCP rompen el parseo.

## 5. Luz y efectos

- `AbilityShow.launch`: máximo 2 grandes vivos y 0,4 s entre grandes, contra `Config.Budgets.Vfx[calidad]`. `BossFx.release` no admite una pieza sin padre (revienta el siguiente `acquire`).
- Armaduras con `PointLight` y el `Bloom` global queman el plano cercano; tres tintes naranja apilados amarillean: usa tinte frío (G4b). A 19,5 h los actores salen negros: luz fría que sigue a la cámara (`light` con `follow`) y `exposure` bajo solo en el choque (G14c).
- Luna pegada a la cámara quema el casco a menos de 40 studs. Luna roja: atributos `CinematicRedMoon…`, manda el atributo sobre el evento.
- `dimLights` a t=0 baja las luces de los maniquíes al 30 %; `torch lit=true` a t=0,05 se las devuelve. `noBlur` apaga DepthOfField y Blur.
- `clock seconds` = segundos para recorrer 12 h, no la duración del cambio. Para pasar de `from` a `to` en `over` segundos usa una rampa seconds = 12·over/|Δhora| (`ramp` en `Endless`, G14d). Con el valor directo el reloj iba hacia atrás al empezar. El texto del reloj no baja dentro de un día (guarda A7 de `PlotActor`).
- Topes medidos con `Rendimiento` (`informe({ filtro = "…", mallas = false })`; el informe completo agota la llamada).

## 6. Probar sin romper nada

- Play escribe `cinematicsSeen` en el **perfil real**: copia antes y restaura después (VERIFICACION §10.0).
- Si el Studio está en Play y no lo iniciaste, avisa y espera. Si Rojo acaba de sincronizar, espera ~2 s; el primer Play puede correr código viejo (comprueba un valor con `execute_luau`).
- `execute_luau`: un `return` devuelve texto, un `print` no. Mide con el reloj del cliente (repone la cámara a `Custom`). `get_console_output` devuelve miles de líneas: `warn` con prefijo.
- **Lo que las capturas del MCP no pueden hacer:** `screen_capture` con `camera_position` no dibuja la escena en vivo, y en Play llegan 1,5–5 s tarde. El juicio de planos en movimiento se hace con **el vídeo del usuario**. Una a una, nunca en paralelo.
- Para ver un plano quieto: en edición, sobre un clon de `Shared` (caché de `require`), `Sequencer.play` + `seek(t)` con un Heartbeat y captura. Para verlo de cerca, alarga la duración en un archivo temporal y restáuralo.
- Hojas de contacto del vídeo con ffmpeg: `fps=2`, `crop` de la ventana del juego (`1920:850:0:150`, `1554:858:18:144`…; reel `486:858:552:144`); `tools/video/lab_detectar.py` y `lab_hojas.py`. Con el recorte, el botón «Skip» tapa la esquina inferior derecha.

## 7. Revisión automática antes de pedir que grabe

Se repite hasta que la lista salga limpia o solo queden cosas subjetivas (máximo 5 vueltas). El usuario solo ve la versión que ya pasó. **No hay commit hasta su «aprobado».**

1. **Condiciones:** `list_roblox_studios` devuelve un Studio; no está en Play de otro (si lo está, avisa y espera); perfil copiado.
2. **Arnés `tools/cine_qa.luau`** (no es código del juego: lo lees y lo pegas como `code` en `execute_luau`, datamodel `Client`, en Play, cambiando solo `OPTS`):
   - `MODE = "start"`, `command = "CineXxx"`, `expect = function() … end` (un valor que acabas de cambiar: si Rojo no ha llegado, se para). Lanza la escena y muestrea cada 0,5 s en un hilo.
   - `MODE = "read"` cuando acabe (la duración de la escena + unos segundos) devuelve el JSON del atributo `CineQA`.
   - Marca, con hora: **suelo** (pies a más de 0,3 st del suelo), **terreno** (el cuerpo atraviesa el Terrain), **deslizando** (avanza sin pista de andar con peso), **atraviesa** (pilares o props en el torso), **fuera** (maniquí fuera de pantalla), **gui** (textos que se pisan, que tapan al maniquí o a «Saltar»), **luz** (velo `Fade` casi opaco; exposición, brillo o bloom extremos).
   - **Límites:** no lee píxeles, así que negro y quemado son aproximaciones; no sabe cuál es el sujeto de cada plano; da falsos positivos en saltos, barcos y monturas. Cada marca es una pista con hora, no una sentencia.
3. **Fotogramas:** de los instantes marcados (y de cada cambio de plano) saca capturas por el método quieto del §6, de una en una, guardadas en `docs/qa/<escena>/` (`<t>.png`). Con el vídeo del usuario, hoja de contacto con ffmpeg. **No** captures cada 0,5 s en Play por el MCP: llegan tarde y no dibujan la escena.
4. **Subagente revisor, solo lectura.** Pásale la carpeta, la lista de entrega de CLAUDE.md, el JSON del arnés y qué debería verse en cada plano. Que devuelva una lista numerada de defectos con marca de tiempo y el fotograma que lo prueba. Léelo con espíritu crítico y comprueba lo dudoso en el fotograma: es una afirmación, no un hecho.
5. **Informe:** escribe `docs/qa/<escena>/report.md` (defectos, causa, arreglo, estado) y la hoja de contacto numerada.
6. **Corrige** todo defecto real (Edit; si pasa de ~50 líneas, al `programador`), espera a Rojo, repite desde el 2.
7. **Entrega:** di «lista para grabar» solo con la lista limpia. Da la hoja de contacto, el informe y las **decisiones subjetivas** que quedan para el usuario (ritmo, composición, gusto). Lo que no se pudo verificar va a `docs/VERIFICACION.md`. Deja la cámara de edición en `Fixed`.

Qué mira el revisor: los seis puntos de la lista de entrega de CLAUDE.md más lo que solo se ve en vídeo (fotogramas vacíos o negros, quemados, texto bajo «Saltar», título sobre el sujeto, onomatopeyas cortadas, coreografías repetidas entre jefes).

## 8. Errores que más rondas costaron

`waitTerrain` mal medido · armas descolocadas al colgar el maniquí · avatar copia invisible · monos reales que reaparecen (`clearArea` barre durante toda la escena) · cámara demasiado cerca · tintes naranja apilados · `dayClock` que salta atrás en `Endless` (A7, arreglado en G14d; falta el vídeo) · `clock seconds` tomado como duración (G14d) · jefe de plató visible desde el inicio (G14d) · cámara a 1,5 st tapada por la hierba (G14d) · cierre con actores sobre el Cofre III (G14d) · `plotHide` mandado dos veces · módulos temporales olvidados en `src` · frases sin subir a Creator Hub (G7, G8, G9, G14b–G14d).

## 9. Órdenes de prueba

CineTest, CineStage(+Comic), CineRescue, CineArrival, CineVoyage, CineBattle(+Comic/Reel), CineBossBattle(+Comic/Reel), CineFlyover(+Comic), CinePets(+Reel/Comic), CineMounts(+Reel/Comic), CineSurvival, CineNight, CineEndless, CineShipwreck, CineBallgame(+Reel/Comic), CineFlag(+Comic), CineLabEngine, CineLab(+Comic).
