# Estilo de la interfaz de Primal Banana Islands

Lo que ya usa el juego, sacado del código (octubre de 2026). Es la referencia para que lo nuevo
encaje con lo que hay. Si cambias algo de esta lista en el código (un color, una capa, un sitio),
actualiza también este archivo: la siguiente persona que use la skill parte de aquí.

No existe todavía un módulo de tema (`Shared/UI/Theme.luau`): los colores están repetidos como
constantes en cada controlador. Si un encargo toca varios archivos con los mismos colores, propón
crear ese módulo con los valores de abajo (y migrar solo lo que el encargo toca, no todo el juego de
golpe).

## 1. Dónde vive cada cosa

| Qué | Archivo | ScreenGui | Place |
|---|---|---|---|
| Piezas comunes: `screen`, `label`, `button` | `src/shared/UI/Widgets.luau` | — | ambos |
| Reloj, indicador del Basecamp, vida del campamento, líneas de estado (asedio, huevo, baliza), "Volver al Lobby", ⚙️ y ventana de Ajustes, "Saltar fase" | `src/island/client/Controllers/IslandHUDController.luau` | `IslandHUD`, `SettingsUI` | Isla |
| Barras de hambre, sed, estamina y fiebre | `src/island/client/Controllers/SurvivalHUDController.luau` | `SurvivalHUD` | Isla |
| Casillas de habilidades Z X C R V | `src/combatClient/Controllers/RoleController.luau` (`buildHud`) | `RoleHUD` | Isla |
| Panel de combos y "¡COMBO!" | `src/combatClient/Controllers/ComboController.luau` | `ComboHUD` | Isla |
| Números de daño, curación, críticos y lo recogido | `src/combatClient/Controllers/CombatTextController.luau` + `src/shared/UI/CombatTextColumn.luau` | `CombatText` | Isla |
| Bolsa (B): ventana centrada con casillas por secciones | `src/island/client/Controllers/InventoryHUDController.luau` | `InventoryHUD` | Isla |
| Barra de vida del jefe | `src/island/client/Controllers/BossHUDController.luau` | `BossHUD` | Isla |
| Contador de munición (arco, honda) con la barrita del carcaj | `src/island/client/Controllers/AmmoHUDController.luau` | `AmmoHUD` | Isla |
| Cartel de caído / espíritu | `src/island/client/Controllers/LifeController.luau` | `LifeHUD` | Isla |
| Mesa de fabricación | `src/island/client/Controllers/CraftingController.luau` | `CraftingHUD` | Isla |
| Panel de construcción | `src/island/client/Controllers/BuildController.luau` | `BuildHUD` | Isla |
| Diario | `src/island/client/Controllers/JournalController.luau` + `src/shared/UI/Journal.luau` | `JournalHUD` | Isla |
| Tutorial | `src/island/client/Controllers/TutorialController.luau` | `Tutorial` | Isla |
| Resultados de la partida | `src/island/client/Controllers/ResultsController.luau` | `Results` | Isla |
| Botones táctiles (Esquivar, Correr, habilidades…) | `src/combatClient/ActionButtons.luau` | `ActionButtons` | Isla |
| Contenido de Ajustes (vista previa del personaje, tus números de combate y opciones) | `src/shared/UI/SettingsPanel.luau` + `src/shared/Settings.luau` | — | ambos |
| Avisos cortos arriba | `src/shared/UI/Toast.luau` | `Toasts` | ambos |
| Panel de pruebas (solo Studio) | `src/shared/UI/DebugPanel.luau` | `DebugPanel` | ambos |
| Todo el Lobby (título, pestañas, unirse, invitar) | `src/lobby/client/Controllers/LobbyUIController.luau` | `LobbyUI` | Lobby |
| Arena de Dunas: marcador con reloj y estado de las banderas (arriba a la derecha, **dentro de la franja de la barra de Roblox**: `GuiService.TopbarInset`, en un ScreenGui `ArenaScore` con IgnoreGuiInset), línea de la fase (arriba en el centro, a 6 px bajo la barra), barras de vida y estamina (12, 10), "Reapareces en N" (centro, 0.4) | `src/dunas/client/Controllers/ArenaHUDController.luau` | `ArenaHUD`, `ArenaScore` | Dunas |
| Arena de Dunas: ventana "Antes de la batalla" (equipo, rol, equipo de la arena con `Shared/UI/ArenaGearPicker`, ¡Listo!) colgada a 40 px, bajo la línea de la fase; su alto se ajusta al contenido (el usuario quiere verlo todo sin desplazarse en PC) y en pantallas de menos de 500 px de alto usa filas de 44 px y se parte en dos columnas (izquierda: equipos, roles 2 × 2, ¡Listo!; derecha: el equipamiento en cuadrícula de 3 × 3 con una barra que explica la opción tocada y su botón); cabe en 844 × 390 sin desplazarse. Plegada deja "🛡️ Equipo y rol" en ese sitio | `src/dunas/client/Controllers/ArenaLobbyController.luau` | `ArenaLobby` (DisplayOrder 6) | Dunas |
| Efectos en pantalla de habilidades (destellos, estrellas) | `src/combatClient/Controllers/AbilityFxController.luau` | varios | Isla |
| Estallidos de cómic del combate (BAM! POW! K.O.! OUCH!) | `src/combatClient/Controllers/ComicFxController.luau` + `src/shared/UI/ComicBurst.luau` (dibujo, también en la vista previa de Ajustes) | `BillboardGui` "ComicFx" | Isla y Dunas |
| Carteles sobre cosas del mapa ("Parcela libre", "Tótem PvP", nombres de monos, títulos cosméticos, vida del campamento sobre la hoguera) | `BillboardGui` creados en el servidor: `BuildingService`, `PvPService`, `MonkeyService`, `BossService`, `CosmeticsServer`, `BasecampService`… | — | Isla |

Todos los HUD se crean por código al arrancar (no hay nada hecho a mano en `StarterGui`), así que
cualquier cambio va al repo. Para encontrar dónde se crea algo que el usuario nombra por su texto,
busca el texto con grep (`"Volver al Lobby"`).

## 2. Paleta

| Uso | Color (RGB) | Dónde |
|---|---|---|
| **Botón principal** (dorado) | 242, 178, 36 | `Widgets.button`, botón listo en fabricación, casilla elegida en construcción |
| Texto sobre botón dorado | 40, 25, 5 | `Widgets.button` |
| Texto normal | 255, 255, 255 con borde (`TextStrokeTransparency = 0.5`) | `Widgets.label` |
| Texto secundario | 210, 200, 185 / 230, 220, 200 | descripciones de recetas, resultados |
| Fondo de ventana (madera oscura) | 25, 20, 15 con transparencia 0.05–0.15 | Ajustes, fabricación, tutorial |
| Fondo de ventana de resultados | 30, 24, 18 sobre velo 10, 8, 6 al 0.25 | `Results` |
| Fondo de fila / tarjeta | 45, 38, 30 | recetas, construcción |
| Casilla de información dentro de una tarjeta (no se pulsa) | 25, 20, 15 al 0.25, esquinas de 8 px | casillas de habilidades de "Tus números de combate" (Ajustes) |
| Fondo de botón cuadrado (⚙️) | 40, 34, 28 al 0.2 | `SettingsButton` |
| Paneles translúcidos del HUD | 20–25, 20–25, 20–25 al 0.25–0.35 | barras, materiales, habilidades, combos, avisos |
| Botón secundario (Studio, deshabilitado) | 90, 90, 110 / 90, 90, 90 | "Saltar fase", recetas bloqueadas |
| Cerrar X | 150, 60, 50 | ventanas de Ajustes y Bolsa, menú del Lobby |
| Seguro / válido / curación | 120, 230, 140 · 90, 230, 110 | Basecamp, construcción válida, curación |
| Peligro / aviso | 255, 170, 60 | fuera del Basecamp |
| Error / daño / no válido | 235, 70, 60 · 255, 70, 70 · 240, 70, 60 | barra baja, daño recibido, construcción no válida |
| Asedio | 255, 120, 90 | línea de estado |
| Huevo | 150, 240, 255 | línea de estado |
| Baliza | 255, 150, 140 | línea de estado |
| Oro / combo / daño que haces | 255, 205, 70 · 255, 220, 90 (crítico 255, 185, 30) | combos, números |
| Siguiente paso del combo | 120, 230, 255 | combos |
| Tecla de habilidad | 255, 220, 120 | casillas Z X C R V |
| Jefe | título 255, 200, 120; barra 220, 50, 40 sobre 30, 20, 20 | `BossHUD` |
| Barras de supervivencia | hambre 230, 150, 70 · sed 80, 170, 240 · estamina 240, 220, 80 · fiebre 190, 90, 200 | `SurvivalHUD` |
| Cómic: golpe | estrella 255, 235, 140 · letra blanca con borde 230, 90, 30 | `ComicBurst` |
| Cómic: crítico | estrella 255, 140, 30 y 255, 215, 40 · rayos 255, 240, 170 · letra 255, 230, 40 con borde 220, 40, 30 | `ComicBurst` |
| Cómic: K.O. | estrella 220, 40, 30 y 255, 185, 30 · letra blanca con borde 200, 30, 20 | `ComicBurst` |
| Cómic: recibir | estrella 235, 70, 60 y 255, 215, 205 · letra blanca con borde 170, 20, 20 | `ComicBurst` |
| Rarezas | común 225, 225, 225 · poco común 120, 220, 120 · raro 90, 160, 255 · épico 200, 110, 255 · legendario 255, 180, 50 | `Data/Rarities.luau` (úsalo, no copies los valores) |

Reglas que salen de ahí:
- Un solo color de acción: el **dorado** es "pulsa aquí". No lo uses para decorar ni para avisos.
- Los fondos son **madera oscura** (marrones casi negros), no grises ni azules. Los grises puros
  (20, 20, 20) son de paneles pequeños del HUD.
- El significado del color es fijo en todo el juego: verde = bien/curación/seguro, naranja = aviso,
  rojo = daño/peligro/error, dorado = acción/logro, cian = huevo y "lo siguiente".
- Texto blanco sobre el mundo **siempre con borde** (`TextStrokeTransparency` 0.3–0.5 o `UIStroke`):
  el fondo puede ser cielo, arena o noche.

## 3. Tipografía

- Fuente: **BuilderSansBold** para casi todo (`Widgets`), **BuilderSans** para descripciones largas
  y **BuilderSansExtraBold** para los números de combate con la letra "Clásica". No metas otras
  fuentes sin preguntar. Única excepción aprobada: **Bangers** (`Enum.Font.Bangers`) en las palabras
  de los estallidos de cómic (`ComicBurst`) y en los números de combate con la letra "¡Cómic!" (la de
  por defecto, ajuste `numberFont`: brillo con `UIGradient`, borde negro proporcional al tamaño y
  caja ×1.45, porque Bangers dibuja la cifra más pequeña que su caja), también en lo recogido
  ("+3 🌲 Madera"); no la uses en el resto del HUD. Un `UIGradient` **tiñe también los emojis**: lo
  que lleva emoji va de un solo color, sin brillo.
- BuilderSans **no tiene el signo ✕** (sale una caja vacía): para cerrar usa "X" en
  BuilderSansExtraBold.
- Tamaño: casi todo usa `TextScaled = true` dentro de una caja con tamaño en escala o en píxeles.
  Con `TextScaled` el tamaño depende de la caja y del largo del texto: un texto que cambia ("Día 1"
  vs "Día 12 · 🌙 10:00") puede encoger. Para textos que varían mucho, añade un
  `UITextSizeConstraint` (`MaxTextSize`/`MinTextSize`) en vez de cajas enormes.
- Mínimo legible en móvil: unos **11–12 px** de alto de letra en un teléfono de 844x390
  (`maqueta_ui.luau` lo avisa).
- Iconos: el juego usa **emojis** en el texto (🍖 💧 ⚡ 🏕️ ⚙️ 🎒 🛠️) en vez de imágenes. Se ven
  distintos en cada plataforma, pero son coherentes con todo lo demás. Un icono nuevo, primero en
  emoji; una imagen solo si el emoji no existe o se ve mal (ver SKILL.md §Imágenes).

## 4. Forma y medidas

- Esquinas: `UICorner` de **12–14 px** en ventanas, paneles y botones; **8 px** en casillas y
  pestañas; 6 px en barras finas; 16 px solo en la ventana de resultados.
- Relleno de botón: `UIPadding` 8 px arriba/abajo y 12 px a los lados (`Widgets.button`).
- Botones: mínimo **160 x 48** y máximo 360 x 80 (`UISizeConstraint` de `Widgets.button`). Los
  botones cuadrados de icono, 44–52 px. Nada pulsable por debajo de **44 px** en móvil.
- Ventanas: centradas (`AnchorPoint 0.5, 0.5`), tamaño en escala con `UISizeConstraint` de mínimo
  ~320 x 240 y máximo ~640–720 de ancho; título arriba a la izquierda en (14, 8) con 34–36 px de
  alto; X de cerrar arriba a la derecha de 44–48 px; contenido en un `ScrollingFrame` desde y = 52–58 con
  `UIListLayout` (relleno 4–6 px) y `AutomaticCanvasSize = Y`.
- Separación desde el borde de la pantalla: **12 px** (columna de la izquierda) o **2 %** de la
  pantalla (`0.02` / `0.98`) en lo que usa escala. No mezcles las dos en un mismo borde.
- Animaciones de interfaz: `TweenService` con un "pop" de escala (`UIScale` 1.35 → 1, el crítico
  1.7 → 1 con un giro de ±8°) y fundidos de transparencia. Cortas: 0.15–0.4 s.

## 5. Capas (DisplayOrder)

| DisplayOrder | Pantalla |
|---|---|
| -1 | `CombatText` (debajo de todo; IgnoreGuiInset) |
| — | `BillboardGui` del mundo (números sobre enemigos, `ComicFx`): siempre por debajo de todos los ScreenGui. Entre ellos no hay orden fijo, así que el estallido de cómic va sobre el pecho del enemigo y la columna de números encima de la cabeza, sin pisarse |
| 0 | HUD normales (`IslandHUD`, `SurvivalHUD`, `RoleHUD`, `ComboHUD`, `BossHUD`, `AmmoHUD`, `LifeHUD`, `BuildHUD`, `Tutorial`, `LobbyUI`) |
| 5 | `ActionButtons`, `CraftingHUD`, `InventoryHUD` (la Bolsa, por encima de Z X C R V y las barras) |
| 6 | `JournalHUD`, `ArenaLobby` (Dunas) |
| 8 | `SettingsUI` |
| 10 | `Toasts` |
| 20 | `DebugPanel` |
| 50 | `Results` (IgnoreGuiInset, con velo) |

Algo nuevo entra en la capa de lo que se le parece: un HUD fijo en 0, una ventana que se abre entre
5 y 8, un aviso en 10, algo que tapa toda la partida en 50. Si necesitas una capa nueva, añádela a
esta tabla.

## 6. Mapa de la pantalla (Isla)

Medido con `volcar_hud.luau` en PC (1488 x 793, barra de Roblox de 58 px). Las posiciones en escala
son las del código; en otro tamaño de pantalla cambian los píxeles, no el sitio.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│[Roblox ≡ 💬]                                                                  │ ← barra de Roblox (58 px)
│ 🍖━━━━  (12,10)                               Día 1 · ☀️ 5:41 (0.98, 0.02) ▸│
│ 💧━━━━                                   🏕️ Basecamp: zona segura (0.085) ▸│
│ ⚡━━━━                  asedio (0.13) · aviso Toast (0.15)   táctil: [⚙️][Volver│
│ 🤒━━━━                  jefe (0.175) · tutorial (0.18)        al Lobby] (0.125)│
│ [Z][X][C][V] (12,118)   huevo (0.24) · baliza (0.275)                         │
│ combos (12,170)         ¡COMBO! (0.3) · caído/espíritu (0.32)                 │
│                                                                    construcción│
│ Bolsa (centro, B)        daño ◀ (0.44,0.42)  ▶ curación (0.56)     (derecha,   │
│                                              lo recogido debajo     centro)   │
│                                                                               │
│                              [🏹 23] munición (0.5, 1 −76 px, 92x40)          │
│ [🛠️ Pruebas] (0.02,0.9)                         PC: [⚙️][Volver al Lobby]     │
│ [⏩ Saltar fase] (0.02,0.98)  [barra de objetos]     (0.98, 0.98) · móvil: salto │
└──────────────────────────────────────────────────────────────────────────────┘
```

Zonas que están **siempre ocupadas** aunque en PC parezcan libres:
- **Abajo a la derecha en móvil y tablet**: el salto de Roblox y, encima, la cuadrícula de
  `ActionButtons` (hasta 6 columnas x 3–4 filas). En PC está vacío, por eso en las capturas de PC
  parece un buen sitio; en un teléfono no lo es.
- **Abajo a la izquierda en móvil**: el joystick (la mitad inferior del 40 % izquierdo).
- **Abajo en el centro**: la barra de objetos de Roblox (las armas y herramientas 1–5) y, justo
  encima, el contador de munición (`AmmoHUD`, solo con arco u honda en la mano). En un teléfono
  apaisado ese hueco, entre el joystick y los botones de acción, mide unos 130 px de ancho: no cabe
  nada más ahí.
- **Arriba a la izquierda, 58 px**: los botones de Roblox (menú, chat, …). Las capturas de
  `screen_capture` **no los muestran**, pero están.
- **El centro**: es la partida. Los números de combate viven en 0.42–0.56; lo que salga ahí tiene
  que ser breve (menos de 1 s) o muy transparente.

La columna central de arriba (de 0.13 a 0.32) ya está muy llena: asedio, avisos, jefe, tutorial,
huevo, baliza, combo y caído. Algo nuevo no debería ir ahí sin quitar o agrupar otra cosa. En la
franja de 0.02 a 0.13 del centro va la vida del campamento (`BasecampHealth`, 240 x 30 px a 0.02,
solo de noche, dañado o caído); en un teléfono acaba a unos 37 px de la línea del asedio, así que
no cabe nada más debajo. Sus textos son cortos a propósito: con más de ~25 caracteres bajan de
11 px en un teléfono.

El panel de construcción (10 piezas de 54 px, centrado a la derecha) mide unos 600 px: en PC roza el
indicador del Basecamp y "Volver al Lobby" mientras construyes, y en un teléfono no cabe entero.

## 7. Dependencias entre elementos

- `SettingsButton` (⚙️) va **a la izquierda de `ReturnToLobbyButton`**, colocado con `place()` a
  partir de la posición y el tamaño reales del botón: si mueves el botón, el ⚙️ lo sigue solo.
- `ReturnToLobbyButton` está abajo a la derecha en PC y, con `UserInputService.TouchEnabled`, bajo el
  indicador del Basecamp (0.125 + 8 px). Si cambias el reloj o el indicador de alto, revisa ese 0.125.
- `DebugPanel` (Pruebas) se coloca a 0.9 en la Isla para dejar sitio a "Saltar fase" (0.98).
- `ActionButtons` copia `IgnoreGuiInset` y `ScreenInsets` de la `TouchGui` de Roblox para alinearse
  con el salto. `maqueta_ui.luau` repite sus cuentas: si cambian, cámbialas también allí.
- La vista previa de Ajustes (`SettingsPanel`, `PREVIEW_RECTS`) dibuja las tres disposiciones de los
  números de combate: si cambias dónde salen, cámbiala también.

## 8. Ajustes del jugador

Cuando haya varias formas razonables de colocar o mostrar algo, el usuario quiere que sean
**opciones del jugador** en Ajustes, no una elección suya: `Shared/Settings.luau` (valores, defectos y
`sanitize`), `Shared/UI/SettingsPanel.luau` (la fila del panel) y el código que lo dibuja leyendo
`Settings.get()` y `Settings.onChanged`. Ejemplos ya hechos: `textLayout` ("Head", "Column",
"Screen") y `numberFont` ("Comic", "Classic") para los números de combate y `comicFx` / `comicLevel` / `comicSize` para los estallidos de
cómic. En el panel, `choiceRow` (fila de botones para elegir uno) y `toggleLine` (Sí/No) son las
piezas para añadir una opción nueva.
