# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

*Primal Banana Islands: Monkey Survival*, un juego de Roblox (móvil y PC) en Luau. Es una sola experiencia con tres places que comparten código y perfil de jugador:

| Place | Proyecto de Rojo | Puerto | Studio |
|---|---|---|---|
| Lobby | `lobby.project.json` | 34872 | "Islas de plátano primitivas" |
| Isla (supervivencia PvE, hasta 5 amigos) | `island.project.json` | 34873 | "🍌Isla de monos🐒(supervivencia)" |
| Isla de Dunas (arena PvP, captura la bandera) | `dunas.project.json` | 34874 | "🎖️Isla de dunas☠️(PvP)" |

Diseño en `docs/GDD.md`. Fases, grupos y su estado en `docs/PLAN.md`. Preparar Studio y Rojo: `docs/SETUP.md`. El código, los comentarios, los textos del juego, la documentación y los mensajes de commit van en **español**; los identificadores, en inglés.

## Comandos

```bash
rokit install                                       # Rojo 7.7.1, StyLua 2.3.1 y Selene 0.30.0 (rokit.toml)
rojo serve lobby.project.json                       # o island / dunas: sincroniza con el Studio abierto
stylua src                                          # formatea (tabs, 120 columnas, LF)
selene src                                          # lint
rojo build island.project.json --output build/island.rbxl
```

El CI (`.github/workflows/ci.yml`) ejecuta `stylua --check src`, `selene src` y `rojo build` de los tres places. No hay tests automáticos. Se verifica en Roblox Studio por el MCP `Roblox_Studio` (`.mcp.json`) y con dos calculadoras que corren en modo edición en el Studio de la Isla (están en `ServerStorage.Tools`):

```lua
local m = game.ServerStorage.Tools.Economia:Clone()   -- o Equilibrio; el Clone evita la caché de require
print(require(m).informe()); m:Destroy()
```

`Economia` mide Ámbar, misiones, huevos, pase y reglas de pago (skill `economia-retencion`). `Equilibrio` mide el daño, el control y los tiempos para matar (skill `combate-roblox`). Las dos aceptan `informe(opciones, propuesta)`, para probar números antes de tocar el repo, y terminan con una sección "Alertas".

## Arquitectura

**Mapa de carpetas a Studio** (igual en los tres proyectos de Rojo):

| Carpeta | En Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (Config, Data, modelos, UI) |
| `src/combatClient` | `ReplicatedStorage.CombatClient` |
| `src/serverShared` | `ServerScriptService.ServerShared` (perfil, compras, pase, cosméticos, retención) |
| `src/combat` | `ServerScriptService.Combat` (combate de la Isla, Dunas y los muñecos del Lobby) |
| `src/<place>/server`, `src/<place>/client` | `ServerScriptService.Server`, `StarterPlayerScripts.Client` |
| `src/island/tools` | `ServerStorage.Tools` (solo en la Isla) |

`sourcemap.project.json` junta todo para luau-lsp.

- **Arranque:** cada `init.server.luau` / `init.client.luau` llama a `Shared/Loader`. Este carga todos los `ModuleScript` de `Services/` (servidor) o `Controllers/` (cliente), más los del combate compartido. Primero llama a `Init()` en todos (solo estado propio) y después a `Start()` en todos, cada uno en su propio hilo. Los nombres de módulo tienen que ser únicos entre todas las carpetas cargadas.
- **Red:** todos los `RemoteEvent` están en una tabla de `Shared/Remotes`. El servidor los crea y el cliente los espera. Un evento nuevo es una línea más allí.
- **Datos y números:** todo lo que se equilibra está en `Shared/Config`. El contenido (armas, monos, cosméticos, temporadas, misiones…) está en `Shared/Data/*`. La lógica lee de ahí.
- **Reglas por place:** el combate es el mismo código en todos los places. Lo que cambia (PvP, zona segura, munición, equipos) lo registra cada place en `Combat/CombatRules.set` desde el `Init` de uno de sus servicios (`IslandCombatRules`, `DunasCombatRules`, `LobbyCombatRules`).
- **Perfil:** `ServerShared/PlayerData` guarda en el DataStore `PlayerData_v1` con bloqueo de sesión, versionado con migraciones. Es el mismo perfil en los tres places. El cliente no lee el perfil: el servidor copia lo que necesita a atributos del `Player` (`Amber`, y JSON en `Progress`, `Settings`, `Eggs`, `Retention`, `Season`…), y los módulos de `Shared` (`Progression`, `SeasonPass`, `EggIncubation`…) los decodifican.
- **Cosméticos:** `Data/Cosmetics` dice el tipo, la rareza y el origen de cada uno. `Shared/CosmeticSlots` asigna los huecos y los grados I/II/III. `ServerShared/CosmeticsServer` publica lo equipado como atributos (`Outfit`, `WeaponSkin`, `Frame`, `PetSkin`, `NumberStyle`, `BurstStyle`, `NestDecor`), que lee cada módulo que lo dibuja. En el Lobby y en Dunas publica también el mejor equipo fabricado en la Isla (perfil `bestGear`) como `ArmorLook` y `WeaponLook`: solo el modelo, sin los números. `Shared/RewardModels` hace sus imágenes voxel para los `ViewportFrame`.
- **Compras:** cada producto se registra con `ServerShared/Purchases.register`, con recibo idempotente guardado en el perfil.
- **Mundo:** los escenarios del Lobby y de Dunas los generan `World/LobbyBuilder` y `World/ArenaBuilder`. Tienen versión: el servidor los reconstruye al arrancar si faltan o son viejos, y para dejarlos fijos en el place se ejecuta `require(game.ServerScriptService.Server.World.<Builder>).build()` en modo edición. La isla la genera `island/tools/MapBuilder` (`build({ islandRadius = 950 })`, una sola vez, y borra el terreno). Lo generado se guarda en el place, no en el repo: después hay que guardar y publicar.

## Reglas del proyecto

- La premium del pase y todo lo de Robux es **solo cosmético**. El Ámbar, el tiempo de huevo y las provisiones nunca se venden: el Ámbar compra mejoras de poder. La sección "Reglas de pago" de `Economia` lo comprueba.
- Colores con significado: verde solo para la curación, morado para el veneno, rojo para el daño recibido.
- Los modelos son **voxel** (bloques en rejilla con pocos tonos planos) salvo que se pida otra cosa. Las referencias están en `docs/img`. Las variantes (alfas, rarezas, estilos) tienen que distinguirse de la normal a primera vista, también por detrás.
- Las ventanas del PC enseñan todo sin desplazamiento, salvo el pase. Las poses de las armas son `AnimationTrack`, nunca articulaciones giradas por código.
- No se editan en Studio los scripts sincronizados: Rojo los sobrescribe.
- Al escribir archivos con Python en Windows, hay que forzar LF (`newline=""`).
- Flujo de trabajo: cada grupo de `docs/PLAN.md` es una sesión. Se prueba en Studio y con la calculadora, después se hace el commit, y el push solo cuando el usuario dice "aprobado". Entonces se marca la fila en `PLAN.md` en un commit aparte.

## Studio y MCP: trampas conocidas

- **Caché de `require`:** la barra de comandos y el MCP reutilizan módulos ya cargados. Para ver un cambio, clona el módulo (o la carpeta `Shared`) y haz `require` del clon. Un módulo que requiere `Settings` o `Remotes` se cuelga en modo edición, porque espera a los remotos.
- **En Play, el `require` del MCP es otra copia** con su propio estado. Para tocar el estado del juego, dispara los remotos desde el cliente (`Remotes.DebugCommand:FireServer("GrantCosmetic", id)`, `Remotes.EquipCosmetic`).
- **Play en Studio escribe el perfil real del usuario** (`PlayerData_v1`, clave `u_<userId>`). Haz copia en `PlayerData_v1_backups` antes de probar y restáurala después.
- **Cámara:** `screen_capture` con cámara deja la cámara de edición en `Scriptable`, y eso se guarda en el place. Ponla en `Fixed` como último paso.
- **Clics del MCP:** los clics por coordenadas fallan por el inset. Usa `instance_path`, renombrando antes los padres repetidos (`Frame.Frame`). En el código que se manda por MCP, los nombres con "ñ" van por `FindFirstChild("MuñecosDePractica")`.
- **Rojo:** no recarga en caliente los cambios de los `*.project.json` y se desconecta al reabrir el place. La captura de Studio en Play no dibuja los `BillboardGui` del mundo.

## Skills del proyecto (`.claude/skills/`)

| Skill | Para qué |
|---|---|
| `modelos-3d-roblox` | Modelos y su revisión |
| `animaciones-roblox` | Animaciones; se ven en edición con `StepAnimations`, las publica el usuario |
| `interfaz-roblox` | HUD y ventanas, con maquetas de teléfono y PC |
| `combate-roblox` | Combate: habilidades, mecánicas, estados, combos, estilos y su equilibrio, con `Equilibrio` |
| `economia-retencion` | Economía y pase, con `Economia` |

`docs/llm-local/` tiene resúmenes de estas skills y de este archivo para el modelo local (gpt-oss-20b en LM Studio y CodeGPT). Si cambias una skill o este archivo, actualiza su resumen y ejecuta `python docs/llm-local/generar_presets.py`.
