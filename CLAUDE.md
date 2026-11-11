# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

*Primal Banana Islands: Monkey Survival*, un juego de Roblox (móvil y PC) en Luau. Es una sola experiencia con cuatro places que comparten código y perfil de jugador:

| Place | Proyecto de Rojo | Puerto | Studio |
|---|---|---|---|
| Lobby | `lobby.project.json` | 34872 | "Islas de plátano primitivas" |
| Isla (supervivencia PvE, hasta 5 amigos) | `island.project.json` | 34873 | "🍌Isla de monos🐒(supervivencia)" |
| Isla de Dunas (arena PvP, captura la bandera) | `dunas.project.json` | 34874 | "🎖️Isla de dunas☠️(PvP)" |
| Laboratorio en ruinas (shooter por equipos sin roles; Fase 13, en construcción) | `laboratorio.project.json` | 34875 | "🧪Laboratorio en ruinas🏴‍☠️(PvP)" |

Diseño en `docs/GDD.md`. Fases, grupos y su estado en `docs/PLAN.md`. Preparar Studio y Rojo: `docs/SETUP.md`. El código, los comentarios, los textos del juego, la documentación y los mensajes de commit van en **español**; los identificadores, en inglés.

## Comandos

```bash
rokit install                                       # Rojo 7.7.1, StyLua 2.3.1 y Selene 0.30.0 (rokit.toml)
rojo serve lobby.project.json                       # o island / dunas: sincroniza con el Studio abierto
stylua src                                          # formatea (tabs, 120 columnas, LF)
selene src                                          # lint
rojo build island.project.json --output build/island.rbxl
python tools/mallas.py tools/mallas/GorilaAlbino.txt --jefe GorilaAlbino --espejo Left_Arm=Right_Arm --espejo Left_Leg=Right_Leg   # mallas de un jefe (monturas: --del-log, ver Arquitectura)
```

El CI (`.github/workflows/ci.yml`) ejecuta `stylua --check src`, `selene src` y `rojo build` de los cuatro places. No hay tests automáticos. Se verifica en Roblox Studio por el MCP `Roblox_Studio` (`.mcp.json`) y con tres calculadoras que corren en modo edición en el Studio de la Isla (están en `ServerStorage.Tools`):

```lua
local m = game.ServerStorage.Tools.Economia:Clone()   -- o Equilibrio o Rendimiento; el Clone evita la caché de require
print(require(m).informe()); m:Destroy()
```

`Economia` mide Ámbar, misiones, huevos, pase y reglas de pago (skill `economia-retencion`). `Equilibrio` mide el daño, el control y los tiempos para matar (skill `combate-roblox`). `Rendimiento` cuenta las piezas de cada modelo antes y después de fusionarlas (`Shared/VoxelMerge`) contra los topes de `Config.Budgets`; los totales por escena y los efectos se añaden en los grupos R5 y R6 de la Fase 16 (skill `modelos-3d-roblox`, §6). Las tres aceptan `informe(opciones, propuesta)`, para probar números antes de tocar el repo, y terminan con una sección "Alertas".

## Arquitectura

**Mapa de carpetas a Studio** (igual en los cuatro proyectos de Rojo):

| Carpeta | En Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (Config, Data, modelos, UI) |
| `src/combatClient` | `ReplicatedStorage.CombatClient` |
| `src/serverShared` | `ServerScriptService.ServerShared` (perfil, compras, pase, cosméticos, retención) |
| `src/combat` | `ServerScriptService.Combat` (combate de la Isla, Dunas, el Laboratorio y los muñecos del Lobby) |
| `src/<place>/server`, `src/<place>/client` | `ServerScriptService.Server`, `StarterPlayerScripts.Client` |
| `src/island/tools` | `ServerStorage.Tools` (solo en la Isla) |

`sourcemap.project.json` junta todo para luau-lsp.

- **Arranque:** cada `init.server.luau` / `init.client.luau` llama a `Shared/Loader`. Este carga todos los `ModuleScript` de `Services/` (servidor) o `Controllers/` (cliente), más los del combate compartido. Primero llama a `Init()` en todos (solo estado propio) y después a `Start()` en todos, cada uno en su propio hilo. Los nombres de módulo tienen que ser únicos entre todas las carpetas cargadas.
- **Red:** todos los `RemoteEvent` están en una tabla de `Shared/Remotes`. El servidor los crea y el cliente los espera. Un evento nuevo es una línea más allí.
- **Datos y números:** todo lo que se equilibra está en `Shared/Config`. El contenido (armas, monos, cosméticos, temporadas, misiones…) está en `Shared/Data/*`. La lógica lee de ahí.
- **Textos e idioma (GDD §18):** todo texto que ve el jugador pasa por `Shared/Strings`: `local T = Strings.t`, `T("Ámbar: {n}", { n = amber })`. La clave es el español (un literal entre comillas dobles, nunca una interpolación con `` ` ``), y su inglés va en `Data/Strings/*`. Una frase guardada en una tabla para traducirla después se marca con `Strings.later("…")`, y un nombre de `Data` se traduce al dibujarlo (`T(def.name)`). El servidor no traduce: manda la plantilla en español y sus argumentos (`Remotes.Notify:FireClient(player, "…{n}…", { n = 3 })`), y un argumento puede ser otra frase (`{ "texto", args }`) o una lista (`{ list = … }`). `UI/Localizer` traduce en el cliente los carteles del mundo, los `ProximityPrompt` y las herramientas de la mochila. `python tools/strings.py` (también en el CI) avisa de las frases sin inglés; `--audit` lista los textos que aún no pasan por `T()`. Se quedan en español solo las herramientas de desarrollo y el panel de administración. **Tabla de Creator Hub:** las subidas se suman a la nube y Creator Hub solo admite un CSV de 90 filas a la vez, así que nunca se sube la tabla entera. `tools/strings_subidas.txt` guarda las claves que ya están en la nube. Al cerrar un grupo con frases nuevas: `python tools/strings.py --csv-nuevas build/localization_nuevas.csv`, el usuario sube ese archivo (o los `_1`, `_2`… si pasa de 90) y después `python tools/strings.py --marcar-subidas` apunta las claves y se incluye `strings_subidas.txt` en el commit. Para revisar lo que hay de verdad, el usuario descarga la tabla de la nube y se comparan sus claves (`Key`) con las del juego.
- **Reglas por place:** el combate es el mismo código en todos los places. Lo que cambia (PvP, zona segura, munición, equipos, si hay roles, habilidades y guardia) lo registra cada place en `Combat/CombatRules.set` desde el `Init` de uno de sus servicios (`IslandCombatRules`, `DunasCombatRules`, `LobbyCombatRules`, `LabCombatRules`). El cliente de un place puede dejar sin cargar controladores del combate (`Loader.load(carpetas, skip)`: el Laboratorio no carga `RoleController`, `GuardController`, `ComboController` ni `ChainPipsController`). **Vista y puntería (Fase 24):** `CombatClient/ViewMode` dice la cámara del place («Third» en Lobby, Isla y Dunas; «First» en el Laboratorio y en el modo shooter del campo; `Config.View`). La ayuda de puntería es solo táctil: `AimInputService` guarda el último control de cada jugador (`InputReporter` lo avisa por `Remotes.ReportInput`), `CombatRules.aimAssistProfile` elige el perfil de `Config.AimAssist` (`Touch` o `Lab`) y `CombatService.aimShot` lo aplica. **Bloqueo de cámara:** Ctrl, propio del juego (`CombatClient/CameraLock` guarda el estado, `CameraLockController` lee Ctrl y `ShoulderAimController` lo aplica); el de Roblox no se usa (`EnableMouseLockOption` en false en los cuatro places: depende de un ajuste del jugador que en Studio viene apagado y su estado no se lee del PlayerModule actual). La mira del bastón (`Sights`, Arc) marca con un punto donde cae el tiro de verdad (`Aim.landing`). `AimViewReporter` avisa de la vista (`Data/AimViews`) y la calibración del campo de tiro separa las filas por arma y vista. La balística de los proyectiles está en `Shared/Ballistics` (cuentas) y `Shared/Data/Ballistics` (números); `Projectiles.fire` la toma sola por `source` y `look`. El campo de tiro mide todo con la consola «Calibración» y `Equilibrio` (sección «Distancia») lo compara.
- **Perfil:** `ServerShared/PlayerData` guarda en el DataStore `PlayerData_v1` con bloqueo de sesión, versionado con migraciones. Es el mismo perfil en todos los places. El cliente no lee el perfil: el servidor copia lo que necesita a atributos del `Player` (`Amber`, y JSON en `Progress`, `Settings`, `Eggs`, `Retention`, `Season`…), y los módulos de `Shared` (`Progression`, `SeasonPass`, `EggIncubation`…) los decodifican.
- **Cosméticos:** `Data/Cosmetics` dice el tipo, la rareza y el origen de cada uno. `Shared/CosmeticSlots` asigna los huecos y los grados I/II/III. `ServerShared/CosmeticsServer` publica lo equipado como atributos (`Outfit`, `WeaponSkin`, `Frame`, `PetSkin`, `NumberStyle`, `BurstStyle`, `NestDecor`), que lee cada módulo que lo dibuja. En el Lobby y en Dunas publica también el mejor equipo fabricado en la Isla (perfil `bestGear`) como `ArmorLook` y `WeaponLook`: solo el modelo, sin los números. `Shared/RewardModels` hace sus imágenes voxel para los `ViewportFrame`.
- **Compras:** cada producto se registra con `ServerShared/Purchases.register`, con recibo idempotente guardado en el perfil.
- **Mallas de jefes y monturas (Fase 21):** las partes del cuerpo de un jefe (y los huesos de una montura, ver abajo) pueden ser una `MeshPart` con textura en lugar de la unión de bloques. Flujo: `ServerStorage.Tools.Mallas.volcar(bossId)` en el Studio de la Isla imprime los bloques de cada parte → se guardan en `tools/mallas/<Jefe>.txt` → `python tools/mallas.py` genera `.obj` + `.mtl` + `.png` en `build/mallas/<Jefe>` (la silueta son los bloques gruesos; los finos van pintados en la textura) → el usuario los importa con Import 3D (yo no puedo subir mallas) → los ids van en `Shared/Data/BossMeshes`. `MonkeyModels` usa la malla de una parte si tiene id y los bloques si no. `EditableMesh` no sirve en el servidor (el cliente ve cuadros). **Monturas:** `Tools.Mallas.volcarMontura(id, <clon de Shared>)` vuelca una parte por hueso en trozos `@@V`, `python tools/mallas.py tools/mallas/<Montura>.txt --del-log` los junta desde el log de Studio, los ids van en `Shared/Data/MountMeshes` y `MountModels.build` sustituye las cajas de cada hueso (soldadas con `Weld`, no `WeldConstraint`; `build` espera a cargar las mallas, así que no se puede reentrar). Un bloque fino solo se pinta sobre uno grueso de su misma parte; `mallas.py` pasa a geometría los que no se apoyan. **Mascotas (Q5):** `Mallas.volcarMascota(id, <clon de Shared>)` vuelca un grupo por articulación (`PetModels.meshGroups`), los ids van en `Shared/Data/PetMeshes` y `PetModels.build` los usa solo sin skin y con las mallas ya cargadas (`PetFollowers` las pide al arrancar); `python tools/mascota.py exportar <Mascota>…` y `python tools/mascota.py ids <Mascota>… --texto ids.txt` hacen el papeleo (ver su docstring). Ver el Handoff de la Fase 21 y el de Q4b en `docs/PLAN.md`.
- **Mundo:** los escenarios del Lobby y de Dunas los generan `World/LobbyBuilder` y `World/ArenaBuilder`. Tienen versión: el servidor los reconstruye al arrancar si faltan o son viejos, y para dejarlos fijos en el place se ejecuta `require(game.ServerScriptService.Server.World.<Builder>).build()` en modo edición. El campo de tiro del Lobby es `World/RangeBuilder` (`Workspace.CampoDeTiro`): tiene versión propia, el servidor lo reconstruye al arrancar si falta o es viejo, y para dejarlo fijo se ejecuta `require(game.ServerScriptService.Server.World.RangeBuilder).build()` en modo edición. La isla la genera `island/tools/MapBuilder` (`build({ islandRadius = 950 })`, una sola vez, y borra el terreno). Lo generado se guarda en el place, no en el repo: después hay que guardar y publicar.
- **Cinemáticas (Fase 25):** `Shared/Data/Cinematics` junta las escenas y tiene casi el tope de locales de Luau. Las escenas nuevas van en su propio archivo en `Shared/Data/Scenes/<Nombre>.luau` (con `require` de `Shared/Data/CinematicKit`: tipos, `cameraKey`, `cutShots`, `actionWriters`, `yawBetween`, `DUSK_HOUR`) y se registran con una línea en `Cinematics`.

## Lista de entrega de cinemáticas (antes de pedir al usuario que grabe)

1. Con raycast, apoya en el suelo a cada actor y montura: nada flotando, hundido en una pendiente ni deslizándose.
2. Comprueba que ningún terreno, árbol, roca o prop atraviesa a los actores, el campamento o el recorrido de la cámara.
3. Los actores llevan el vestuario y el armamento de la escena, **no** el equipo del jugador; el avatar real se ve y el servidor no lo recoloca.
4. Los títulos y logos no tapan al sujeto principal, y las onomatopeyas y los rótulos no quedan cortados.
5. Cada jefe o batalla tiene una coreografía distinta (sin repetir secuencias).
6. Captura cada plano cada 0,5 s y revisa la hoja de contacto: sin fotogramas vacíos, en pose o quemados de luz.

## Reglas del proyecto

- La premium del pase y todo lo de Robux es **solo cosmético**. El Ámbar, el tiempo de huevo y las provisiones nunca se venden: el Ámbar compra mejoras de poder. La sección "Reglas de pago" de `Economia` lo comprueba.
- Colores con significado: verde solo para la curación, morado para el veneno, rojo para el daño recibido.
- **Un icono, una sola cosa.** Dos objetos distintos no comparten emoji, ni un objeto con el Ámbar (✨), las barras (🍖 hambre, 💧 sed) o un edificio que sale junto a costes en materiales. Los parecidos (🔺/🔻, 🌿/🌱) cuentan como iguales. Solo puede repetirlo la receta o el construible que fabrica ese objeto.
- Los modelos son **voxel** (bloques en rejilla con pocos tonos planos) salvo que se pida otra cosa. Las referencias están en `docs/img`. Las variantes (alfas, rarezas, estilos) tienen que distinguirse de la normal a primera vista, también por detrás.
- Los topes de piezas viven en `Config.Budgets` (`Shared/Config`). Cada modelo nuevo se mide con `Rendimiento` antes del commit, y si cambias un tope, cámbialo en `Config.Budgets`.
- Las ventanas del PC enseñan todo sin desplazamiento, salvo el pase y la pestaña Estilos del Armario. Las poses de las armas son `AnimationTrack`, nunca articulaciones giradas por código.
- No se editan en Studio los scripts sincronizados: Rojo los sobrescribe.
- Al escribir archivos con Python en Windows, hay que forzar LF (`newline=""`).
- Flujo de trabajo: cada grupo de `docs/PLAN.md` es una sesión. Se prueba en Studio y con la calculadora, después se hace el commit, y el push solo cuando el usuario dice "aprobado". Entonces se marca la fila en `PLAN.md` en un commit aparte.
- **Commits y push:**
  - No se hace commit ni push hasta que el usuario aprueba de forma explícita («aprobado»). Con la aprobación, commit y push en un solo paso.
  - Se añaden al índice **solo** los archivos que cambiaste en la tarea, nunca los cambios sin confirmar del usuario. Antes de hacer el commit, `git status` y se enseña la lista de archivos.
  - Nunca se suben commits anteriores de otra fase sin preguntar antes.
  - Los hashes y el estado de las filas de `PLAN.md` se escriben con la herramienta Edit, no con `sed` ni heredocs: el texto por shell es poco fiable en este Windows.
- **Lo que queda sin probar va a `docs/VERIFICACION.md`.** Si algo no se ha podido probar (hacen falta 2 jugadores, el juego publicado, el emulador de teléfono…), se apunta allí como sección nueva, en su formato (`1. [ ] paso` y debajo `✅ lo que debe pasar`), agrupado por cómo se prueba, y va en el mismo commit que el cambio. `PLAN.md`, los handoffs y el resumen al usuario solo remiten a esa sección.

## Studio y MCP: trampas conocidas

- **Caché de `require`:** la barra de comandos y el MCP reutilizan módulos ya cargados. Para ver un cambio, clona el módulo (o la carpeta `Shared`) y haz `require` del clon. Un módulo que requiere `Settings` o `Remotes` se cuelga en modo edición, porque espera a los remotos.
- **En Play, el `require` del MCP es otra copia** con su propio estado. Para tocar el estado del juego, dispara los remotos desde el cliente (`Remotes.DebugCommand:FireServer("GrantCosmetic", id)`, `Remotes.EquipCosmetic`).
- **Play en Studio escribe el perfil real del usuario** (`PlayerData_v1`, clave `u_<userId>`). Haz copia en `PlayerData_v1_backups` antes de probar y restáurala después.
- **Cámara:** `screen_capture` con cámara deja la cámara de edición en `Scriptable`, y eso se guarda en el place. Ponla en `Fixed` como último paso.
- **Clics del MCP:** los clics por coordenadas fallan por el inset. Usa `instance_path`, renombrando antes los padres repetidos (`Frame.Frame`). En el código que se manda por MCP, los nombres con "ñ" van por `FindFirstChild("MuñecosDePractica")`.
- **Rojo:** no recarga en caliente los cambios de los `*.project.json` y se desconecta al reabrir el place. La captura de Studio en Play no dibuja los `BillboardGui` del mundo.
- **Play del usuario:** nunca pares un Play que inició el usuario; si Studio está ocupado, pídele que lo libere. Tras una prueba, para el Play solo si lo iniciaste tú.
- **Rojo sincronizado antes de probar:** antes de cualquier prueba en Play, confirma con `execute_luau` un valor o marca de versión que acabas de cambiar. El código viejo ha dado falsos resultados.

## Trampas de Luau

- Una función o script admite como máximo 200 locales. En cinemáticas grandes, agrupa el estado en tablas o usa `CinematicKit` desde el principio.
- Carga los `AnimationTrack` **después** de poner el modelo en `workspace`: en un modelo sin padre se quedan con peso 0.
- Los `ScreenGui` de cinemáticas usan `ZIndexBehavior.Sibling`; con el global, los paneles salen negros.
- El texto de las esquinas no invade la zona del botón Saltar. Cuenta el inset de la barra superior al colocar miras e interfaz.
- Las piezas de FX reutilizadas (`BossFx`) se liberan o se recrean cuando se destruye la carpeta que las contiene.
- No pongas un fundido de entrada en la primera ejecución sin probar el arranque en frío (causó una pantalla negra).

## Comunicación

Si una orden corta puede referirse a varias cosas (qué cinemática, qué jefe o gorila, «rayos» = relámpagos o destellos, deshacer código o actualizar docs), repite tu interpretación en una línea y confirma antes de editar.

## Skills del proyecto (`.claude/skills/`)

| Skill | Para qué |
|---|---|
| `modelos-3d-roblox` | Modelos y su revisión |
| `animaciones-roblox` | Animaciones; se ven en edición con `StepAnimations`, las publica el usuario |
| `interfaz-roblox` | HUD y ventanas, con maquetas de teléfono y PC |
| `combate-roblox` | Combate: habilidades, mecánicas, estados, combos, estilos y su equilibrio, con `Equilibrio` |
| `economia-retencion` | Economía y pase, con `Economia` |
| `video-capcut` | Shorts 9:16 en borradores de CapCut con `tools/video/short.py` |
| `cinematicas-roblox` | Cinemáticas y su revisión automática antes de grabar, con `tools/cine_qa.luau` |
| `ship` | Cierra un grupo tras el aprobado: commit de los archivos de la tarea, push, PLAN.md, strings y Handoff |

`docs/llm-local/` tiene resúmenes de estas skills y de este archivo para el modelo local (gpt-oss-20b en LM Studio y CodeGPT). Si cambias una skill o este archivo, actualiza su resumen y ejecuta `python docs/llm-local/generar_presets.py`.

## Agentes (`.claude/agents/`)

La sesión principal (Opus) planea, pregunta, decide los números, revisa las capturas y el diff, y hace los commits. Lo que se repite en cada grupo lo delega, para que el modelo sea más barato y, sobre todo, para que el contexto principal no crezca con salidas de grep, archivos leídos y consola:

| Agente | Modelo | Cuándo |
|---|---|---|
| `search` (en `~/.claude/agents`) | Haiku | Localizar algo que pide más de 2 o 3 búsquedas: archivos, usos de un nombre, valores de Config, pasajes del GDD o de PLAN.md |
| `programador` | Sonnet | Escribir un grupo ya especificado (archivos, comportamiento, números) de más de unas 50 líneas. Lo deja pasando stylua, selene, `strings.py` y `rojo build`. Lo pequeño lo hace la sesión principal |
| `probador-studio` | Sonnet | Pruebas funcionales en Studio (modo edición, Play, consola, remotos de depuración) y ejecutar `Economia` o `Equilibrio`. Uno a la vez: hay un solo Studio |
| `documentador` | Haiku | `VERIFICACION.md`, la fila de `PLAN.md`, el handoff, los resúmenes de `docs/llm-local` y el borrador del commit |

- La especificación para el `programador` dice los archivos, el comportamiento, los números y la skill que aplica. Al volver, la sesión principal revisa el diff contra las reglas del proyecto antes de probar.
- Las capturas (`screen_capture`) y el juicio visual de modelos, interfaz y animaciones se quedan en la sesión principal. Pocas capturas y pequeñas.
- Los subagentes no hablan con el usuario. Las preguntas y el "aprobado" siguen en la sesión principal.
- `python tools/uso_tokens.py` mide los tokens por sesión, modelo y herramienta, para comparar antes y después.
