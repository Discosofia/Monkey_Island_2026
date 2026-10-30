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
| Reloj, indicador del Basecamp, vida del campamento, líneas de estado (asedio, huevo, baliza), "Volver al Lobby" (el primer toque lo pone en rojo, "¿Salir? Pierdes todo", con un aviso; solo el segundo en 4 s viaja), ⚙️ y ventana de Ajustes, "Saltar fase" | `src/island/client/Controllers/IslandHUDController.luau` | `IslandHUD`, `SettingsUI` | Isla |
| Rastreador de misiones: las 3 del día y las 5 de la semana, plegable tocando su cabecera (🔼/🔽; plegado, una línea "hoy 1/3 · semana 2/5"). En PC, panel bajo los combos (12, 240), desplegado o no según el ajuste `missionsOpen`; en un teléfono (táctil sin teclado), fichas compactas en la franja de la barra de Roblox, tras sus botones (`GuiService.TopbarInset`, ScreenGui `MissionBand` con IgnoreGuiInset: icono de cada misión del día con lo que llevas, "📆 2/5" y 🔽), y tocarlas abre la lista debajo (empieza plegada: tapa las barras) | `src/island/client/Controllers/MissionTrackerController.luau` | `MissionHUD`, `MissionBand` | Isla |
| Barras de hambre, sed, estamina y fiebre | `src/island/client/Controllers/SurvivalHUDController.luau` | `SurvivalHUD` | Isla |
| Casillas de habilidades Z X C R V | `src/combatClient/Controllers/RoleController.luau` (`buildHud`) | `RoleHUD` | Isla |
| Panel de combos y "¡COMBO!" | `src/combatClient/Controllers/ComboController.luau` | `ComboHUD` | Isla |
| Números de daño, curación, críticos y lo recogido | `src/combatClient/Controllers/CombatTextController.luau` + `src/shared/UI/CombatTextColumn.luau` | `CombatText` | Isla |
| Bolsa (B): ventana centrada con casillas por secciones | `src/island/client/Controllers/InventoryHUDController.luau` | `InventoryHUD` | Isla |
| Barra de vida del jefe | `src/island/client/Controllers/BossHUDController.luau` | `BossHUD` | Isla |
| Contador de munición (arco, honda) con la barrita del carcaj | `src/island/client/Controllers/AmmoHUDController.luau` | `AmmoHUD` | Isla |
| Cartel de caído / espíritu | `src/island/client/Controllers/LifeController.luau` | `LifeHUD` | Isla |
| Mesa de fabricación | `src/island/client/Controllers/CraftingController.luau` | `CraftingHUD` | Isla |
| Ventana «🏡 Tu parcela» (Fase 12; la abre el cartel de tu hueco; en pantallas bajas ocupa todo y va en dos columnas) | `src/island/client/Controllers/PlotController.luau` | `PlotHUD` | Isla |
| Ventana del cofre de una parcela (Fase 12, P4; la abre el aviso «Abrir» del cofre): al dueño, dos columnas de casillas como las de la Bolsa (su Bolsa, con el selector «🔒 Privado / 🤝 Compartido» de dónde guarda, y el cofre con las casillas usadas; las del cofre llevan 🔒 o 🤝 arriba a la izquierda); a los demás, solo lo compartido. Abajo, el detalle del objeto y la cantidad por toque (1 / 10 / Todo). En PC se ensancha con más columnas antes de encoger las casillas (mínimo 44 px); en pantallas bajas ocupa todo | `src/island/client/Controllers/ChestController.luau` | `ChestHUD` | Isla |
| Panel de construcción: en PC, ventana opaca "🔨 Construir" a la derecha (12 piezas en 3 columnas x 4 filas de 118 x 62, unos 382 x 312 px, fondo `Active` para que ningún clic lo atraviese); en un teléfono, una ficha con la pieza elegida y ◀ ▶ (300 x 52) arriba en el centro, a 4 px bajo la barra de Roblox (de noche tapa la vida del campamento mientras se lleva el martillo; decidido por el usuario el 26-10-2026) | `src/island/client/Controllers/BuildController.luau` | `BuildHUD` | Isla |
| Diario | `src/island/client/Controllers/JournalController.luau` + `src/shared/UI/Journal.luau` | `JournalHUD` | Isla |
| Tutorial | `src/island/client/Controllers/TutorialController.luau` | `Tutorial` | Isla |
| Resultados de la partida | `src/island/client/Controllers/ResultsController.luau` | `Results` | Isla |
| Botones táctiles (Esquivar, Correr, habilidades…) | `src/combatClient/ActionButtons.luau` | `ActionButtons` | Isla |
| Contenido de Ajustes (vista previa del personaje, tus números de combate y opciones) | `src/shared/UI/SettingsPanel.luau` + `src/shared/Settings.luau` | — | ambos |
| Avisos cortos arriba | `src/shared/UI/Toast.luau` | `Toasts` | ambos |
| Panel de pruebas (solo Studio) | `src/shared/UI/DebugPanel.luau` | `DebugPanel` | ambos |
| Panel de administradores (T4): botón "👑 Admin" encima de Pruebas y ventana con pestañas (👥 Jugadores · 📢 Todos · 🎉 Eventos · 🖥️ Servidor · 📜 Registro; la elegida en dorado, como las de Misiones) de madera oscura, con el listado para dar (buscador) al lado, hacia el centro. Botones pequeños dorados de 8 px de esquina con tope de letra de 18 px. "Dar" para todos pide un segundo toque ("¿A todos?", 3 s). En cada jugador, 🛡️ abre en ese mismo sitio la ventana del jugador con dos pestañas, 🛡️ Moderar y 📋 Perfil (resumen, copia, reiniciar, copias para restaurar y cosas para quitar, con segundo toque; por nombre de usuario, solo el perfil). Moderar: (motivo, silenciar, banear y expulsar en rojo de cerrar con segundo toque "¿Seguro?", ir hasta, espiar, congelar) | `src/shared/UI/AdminPanel.luau` (la arranca `AdminController` en cada place) | `AdminPanel` | Lobby, Isla y Dunas |
| Golpes del administrador gigante (T4e): columna de 3 botones de 64 px (madera oscura, borde dorado, icono y "I · Pisotón", "O · Ola", "P · Rugido") a la derecha, centrada en 0.55, con la recarga en grande encima; solo mientras el Player lleva "AdminBoss" | `src/island/client/Controllers/GiantAdminController.luau` | `GiantHUD` | Isla |
| Franja de los eventos en vivo (T4b): una pastilla de madera oscura por evento (esquinas redondas, borde dorado si está en marcha, cian si está programado: "⏳ … en 4:59") centrada **dentro de la franja de la barra de Roblox** (`GuiService.TopbarInset`, IgnoreGuiInset). Con dos o más eventos, o en un teléfono, solo icono y tiempo: con nombres pisaba la pastilla del Ámbar del Lobby (216–516 px en PC). Tocarla explica el evento con un aviso | `src/shared/UI/LiveEventsBand.luau` (la arranca `AdminController`) | `LiveEvents` | Lobby, Isla y Dunas |
| Cartel de los anuncios de los administradores: arriba en el centro, a 6 px de la barra de Roblox, madera oscura con borde dorado, "📢 Anuncio · nombre" y el texto (hasta 24 px), 10 s | `src/shared/UI/AnnounceBanner.luau` (lo arranca `AdminController`) | `Announce` | Lobby, Isla y Dunas |
| Todo el Lobby: título (se funde a los 5 s), pastilla del Ámbar en la franja de la barra de Roblox, ventanas de las estaciones de la plaza (Misiones con pestañas "📅 Hoy" y "📆 Semana": las pestañas son botones de 8 px de esquina, la elegida en dorado como los formatos de la Arena; cada misión es una fila con "🔄 Cambiar" mientras quede el cambio gratis, que pide un segundo toque, o lo que llevas; Rol, Arena, Mascotas, Ranking, Pase: las abre el aviso de su cartel o del nido y se cierran solas al alejarse) y del menú, barra del menú (columna a la izquierda bajo los combos en PC; fila de iconos en la franja de la barra de Roblox en táctil o pantalla baja), "Ir a la Isla de monos", "Invitar amigos" | `src/lobby/client/Controllers/LobbyUIController.luau` | `LobbyUI` | Lobby |
| Tienda del Lobby, pestaña "🎨 Cosméticos" (la otra, "✨ Mejoras", son filas): ventana ancha colocada por su panel; "✨ En Ámbar · cambia en…" con 4 tarjetas, "💰 En Robux · cambia en…" con 3 y una casilla que se explica ("Nuevos cada lunes…"), "🎟️ Siempre a la venta" con los Game Passes en tarjetas pequeñas (imagen a la izquierda) y una línea abajo con lo que es la tarjeta tocada. Tarjetas con imagen 3D (`RewardModels.cosmetic`; las armas, `WeaponTools.preview`), borde de rareza (`Widgets.rarityBorder`), nombre, rareza y botón ("✨ 900", que pide un segundo toque "¿Comprar?"; "R$ 149"; "✅ Tuyo" en gris). En una pantalla baja Ámbar y Robux van una al lado de la otra, sin la línea de la rareza: cabe en 844 × 390 sin desplazarse | `src/shared/UI/CosmeticShopPanel.luau` (la monta `LobbyUIController`, ventana `Tienda`) | — | Lobby |
| Ventana del pase de temporada, "salida del volcán": fondo volcánico a pantalla completa detrás (`PassBackdrop`, DisplayOrder -1, brasas y ceniza animadas), marco de obsidiana con borde de lava (lo pone y lo quita `SeasonPassPanel.close`), cabecera con el medallón del nivel, barra de XP de lava y "Reclamar todo"; las dos pistas (premium arriba, gratis abajo, camino de lava con los niveles en medio) se **deslizan juntas** en horizontal (excepción a "sin desplazamiento" pedida por el usuario; la otra es la pestaña Estilos del Armario), con tarjetas de imagen 3D (`Shared/RewardModels` en `ViewportFrame`, nunca emojis), nombre, detalle y estado; abajo el sello "PASE PREMIUM ACTIVO" o la frase que invita y las compras. Al reclamar celebra en la tarjeta (sin aviso). Contenido: 500 px en PC (ventana hasta 1.240 de ancho, unas 7 columnas) y 270 en una pantalla baja (cabe en 844 × 390) | `src/shared/UI/SeasonPassPanel.luau` (la monta `LobbyUIController`, ventana `Pase`) | `PassBackdrop` | Lobby |
| Cartel del pase en la plaza (panel de obsidiana con borde de lava: medallón del nivel, temporada y cuenta atrás, barra de lava, "Siguiente premio" con su imagen 3D girando y premios por reclamar; el aviso va en el poste, no encima del contenido). La estructura volcánica la hace `volcanoBoard` en `LobbyBuilder` | `src/lobby/client/Controllers/PassBoardController.luau` | `SurfaceGui` "TablaPase" | Lobby |
| Línea de la XP del pase en los resultados de la Isla y de Dunas | `SeasonPass.gainText` (`src/shared/SeasonPass.luau`) en `ResultsController` y `ArenaResultsController` | — | Isla y Dunas |
| Tarjetas de rol de la arena (icono, nombre y ventaja en combate) | `src/shared/UI/ArenaRoleCards.luau` | — | Lobby y Dunas |
| Arena de Dunas: marcador con reloj y estado de las banderas (arriba a la derecha, **dentro de la franja de la barra de Roblox**: `GuiService.TopbarInset`, en un ScreenGui `ArenaScore` con IgnoreGuiInset), línea de la fase (arriba en el centro, a 6 px bajo la barra), barras de vida y estamina (12, 10), "Reapareces en N" (centro, 0.4) | `src/dunas/client/Controllers/ArenaHUDController.luau` | `ArenaHUD`, `ArenaScore` | Dunas |
| Arena de Dunas: ventana "Antes de la batalla" (equipo, rol, equipo de la arena con `Shared/UI/ArenaGearPicker`, ¡Listo!) colgada a 40 px, bajo la línea de la fase; su alto se ajusta al contenido (el usuario quiere verlo todo sin desplazarse en PC) y en pantallas de menos de 500 px de alto usa filas de 44 px y se parte en dos columnas (izquierda: equipos, roles 2 × 2, ¡Listo!; derecha: el equipamiento en cuadrícula de 3 × 3 con una barra que explica la opción tocada y su botón); cabe en 844 × 390 sin desplazarse. Plegada deja "🛡️ Equipo y rol" en ese sitio | `src/dunas/client/Controllers/ArenaLobbyController.luau` | `ArenaLobby` (DisplayOrder 6) | Dunas |
| Rueda de emotes: 6 huecos redondos (76 px) en círculo de 118 px de radio alrededor del centro, con la X roja en medio, velo oscuro detrás (tocarlo la cierra) y la línea "Se para al moverte" debajo. Se abre con "." (el menú de emotes de Roblox se apaga) o con el botón 😀 (52 × 52, como el ⚙️): en la Isla a la izquierda del ⚙️, en el Lobby en la barra del menú (entrada "Emotes", tras Armario), en Dunas abajo a la derecha en PC y arriba a la derecha, bajo las banderas, en táctil | `src/shared/UI/EmoteWheel.luau` (la arrancan `IslandHUDController`, `LobbyUIController` y `ArenaHUDController`) | `EmoteWheel` (DisplayOrder 7, IgnoreGuiInset) | Isla, Lobby y Dunas |
| Ajustes de Lab y Dunas: ⚙️ (52 × 52, a la izquierda del 😀 y centrado en su alto, con 6 px de hueco; en táctil queda bajo el marcador, sin pisar la línea de la fase) y ventana con el contexto "Arena" de `SettingsPanel`: "🎯 Mira" (con vista previa viva), opciones, controles y temblor/idioma; sin números, personaje ni estadísticas. En PC la ventana es una columna con desplazamiento (excepción a "sin desplazamiento", pendiente de decidir si se reparte en columnas como el Lobby); en pantallas bajas ocupa casi todo y no esconde `ActionButtons` ni `TouchGui`. En el Laboratorio, abrirla suelta el ratón (`FirstPersonController.freeCursor("Settings")`) | `src/shared/UI/ArenaSettings.luau` (la enganchan `LabHUDController` y `ArenaHUDController`) | `SettingsUI` (DisplayOrder 8) | Lab, Dunas, Isla y Lobby |
| Mira configurable (forma, color, tamaño, grosor y dinámica, en Ajustes; la dispersión y el anillo de recarga los ponen las armas con `setSpread` y `setCooldown`): en el Laboratorio, la del centro de la pantalla (`FirstPersonController`, que da su Handle con `crosshair()`); en Dunas, solo con un arma a distancia en la mano y el jugador vivo: con ratón sigue al cursor y esconde el icono del sistema salvo sobre botones y ventanas, y sin ratón va al centro (`RangedCrosshairController`, en CombatClient). Sin verde ni morado | `src/shared/UI/Crosshair.luau` (la montan `FirstPersonController` y `RangedCrosshairController`; al apuntar entra `UI/Sights`) | `Mira` (DisplayOrder 5, IgnoreGuiInset) | Lab y Dunas |
| Armario del Lobby: visor a la izquierda y pestañas en dos filas con páginas de 9 tarjetas (6 en el teléfono) y flechas; la pestaña "🎨 Estilos" va en tres columnas con título (🔢 Números, 💥 Estallidos, 🪺 Nido) que se deslizan hacia abajo por separado (excepción a "sin desplazamiento", pedida el 26-10-2026), con 3 tarjetas a la vista (2 en el teléfono) y la posición de cada columna recordada al rehacer la ventana | `src/shared/UI/WardrobePanel.luau` (la monta `LobbyUIController`, ventana `Armario`) | — | Lobby |
| Marcos de jugador (cosméticos `Frame`): borde con degradado (`UIStroke` en modo Border) y piezas en las esquinas (remaches o esquirlas), en el legendario la lava que corre por el borde y brasas que suben. Se ponen en las filas del ranking (con 12 px de margen a la izquierda, para que las esquinas no pisen la medalla), las filas de la ventana Grupo, las fichas del grupo de los resultados de la Isla (bajo "Sobrevivisteis") y las filas de los resultados de Dunas | `src/shared/UI/PlayerFrames.luau` (`apply(objeto, frameId)`) | — | Lobby, Isla y Dunas |
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
| Aviso pendiente (punto rojo, aura que palpita) | 235, 70, 60 | punto rojo de los iconos de la barra del Lobby, aura del atajo a los talentos (`pulseAura`) |
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
| Rarezas | común 225, 225, 225 · poco común 120, 220, 120 · raro 90, 160, 255 · épico 200, 110, 255 · legendario 255, 180, 50 · mítico 255, 70, 110 (solo cosméticos; su borde lleva un degradado con oro 255, 214, 110 que gira, `UI/WardrobePanel`) | `Data/Rarities.luau` (úsalo, no copies los valores) |

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
- **Invitar a pulsar algo** (lo que el jugador debería mirar ahora: talentos por gastar tras elegir
  rol): un **aura roja que palpita**, `UIStroke` de 235, 70, 60 cuyo grosor se multiplica por 2,5 y
  se apaga en bucle (`TweenInfo` 0,7 s, Sine, repetición -1, de ida y vuelta), en la fila y en su
  botón (`pulseAura` de `LobbyUIController`). Va con el mismo rojo que el punto de aviso de la barra,
  para que el jugador relacione los dos. El usuario lo pidió así (20-10-2026): el botón dorado solo
  no destacaba entre los demás botones dorados.
- **Ventanas que aprovechan la pantalla** (el usuario lo pide): en PC se ajustan a su contenido sin
  desplazarse y, si no caben, se reparten en columnas; en un teléfono (menos de 500 px de alto)
  ocupan todo el ancho y el alto libres con filas y textos más pequeños (tope de 16/12/15 px para
  título/detalle/botón) y también se reparten en columnas de al menos 280 px. Con una ventana abierta
  se esconde lo que la tapa en el teléfono: los botones táctiles de combate (`ActionButtons`) y la
  `TouchGui` de Roblox (joystick y salto).
- Animaciones de interfaz: `TweenService` con un "pop" de escala (`UIScale` 1.35 → 1, el crítico
  1.7 → 1 con un giro de ±8°) y fundidos de transparencia. Cortas: 0.15–0.4 s.

## 5. Capas (DisplayOrder)

| DisplayOrder | Pantalla |
|---|---|
| -1 | `CombatText` (debajo de todo; IgnoreGuiInset) |
| — | `BillboardGui` del mundo (números sobre enemigos, `ComicFx`): siempre por debajo de todos los ScreenGui. Entre ellos no hay orden fijo, así que el estallido de cómic va sobre el pecho del enemigo y la columna de números encima de la cabeza, sin pisarse |
| 0 | HUD normales (`IslandHUD`, `SurvivalHUD`, `RoleHUD`, `ComboHUD`, `BossHUD`, `AmmoHUD`, `LifeHUD`, `BuildHUD`, `Tutorial`, `LobbyUI`) y `ChainPips` (IgnoreGuiInset: los rombos de la cadena, que siguen los pies del personaje; Fase 10, C12) |
| 1 | `LiveEvents` (franja de los eventos en vivo, en la barra de Roblox) |
| 5 | `ActionButtons`, `CraftingHUD`, `PlotHUD`, `InventoryHUD` (la Bolsa, por encima de Z X C R V y las barras) |
| 5 | `DamageFx` (arco y viñeta de daño, sin botones: `Active` apagado, no bloquea toques) |
| 5 | `Mira` (la mira del Laboratorio y de Dunas, con arma a distancia: sin botones, `Active` apagado) |
| 6 | `JournalHUD`, `ArenaLobby` (Dunas), `ChestHUD` (el cofre: en el teléfono tapa los botones táctiles de combate) |
| 7 | `EmoteWheel` (la rueda de emotes, con velo) |
| 8 | `SettingsUI` (también los Ajustes del Laboratorio y de Dunas, `ArenaSettings`) |
| 10 | `Toasts` |
| 11 | `Announce` (anuncios de los administradores) |
| 20 | `DebugPanel` |
| 21 | `AdminPanel` |
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

El panel de construcción (3 x 4 piezas, centrado a la derecha) mide unos 312 px de alto: en PC queda
entre el indicador del Basecamp y "Volver al Lobby" sin tocarlos. En un teléfono es una ficha arriba en el
centro.

## 7. Dependencias entre elementos

- El rastreador de misiones (`MissionTrackerController`) en PC es una columna (`Tracker`, 12, 240,
  324 px de ancho) bajo los combos: el panel de misiones y, 6 px debajo, la tarjeta del contrato de
  expedición (G6), que sigue al panel al plegarlo. En el teléfono, la ficha "📜" va en la franja de la
  barra de Roblox con las de las misiones y la tarjeta solo se ve con la lista abierta.

- `SettingsButton` (⚙️) va **a la izquierda de `ReturnToLobbyButton`**, colocado con `place()` a
  partir de la posición y el tamaño reales del botón: si mueves el botón, el ⚙️ lo sigue solo. El
  botón 😀 de los emotes (`EmoteButton`) sigue igual al ⚙️, a su izquierda.
- `ReturnToLobbyButton` está abajo a la derecha en PC y, con `UserInputService.TouchEnabled`, bajo el
  indicador del Basecamp (0.125 + 8 px). Si cambias el reloj o el indicador de alto, revisa ese 0.125.
- `DebugPanel` (Pruebas) se coloca a 0.9 en la Isla para dejar sitio a "Saltar fase" (0.98), y en el
  Lobby abajo a la derecha (a la izquierda van la barra del menú y "Invitar amigos").
- `ActionButtons` copia `IgnoreGuiInset` y `ScreenInsets` de la `TouchGui` de Roblox para alinearse
  con el salto. `maqueta_ui.luau` repite sus cuentas: si cambian, cámbialas también allí.
- La vista previa de Ajustes (`SettingsPanel`, `PREVIEW_RECTS`) dibuja las tres disposiciones de los
  números de combate: si cambias dónde salen, cámbiala también.
- **Lobby** (desde el 20-10-2026 carga el combate compartido para probar el rol en la plaza):
  `JoinIslandButton` y la línea de provisiones van a 112 px del borde de abajo (`HOTBAR_CLEARANCE`),
  encima de la barra de objetos de Roblox con las armas del rol (en PC su borde de arriba queda a unos
  100 px del de abajo: con 76 se tapaban, captura del usuario). La barra del menú en columna empieza
  en `BAR_TOP` (244 px; 9 botones desde el G9c: "Emotes" no abre ventana, abre la rueda), debajo de las casillas de habilidades (`RoleHUD`, 118–164) y de los combos
  (`ComboHUD`, 170–232): si cambian de alto, revisa `BAR_TOP`; "Invitar amigos" va 8 px debajo de la
  barra. Con una ventana abierta (`openWindow`) se esconden la barra de objetos
  (`SetCoreGuiEnabled(Backpack)`), el botón de viaje, las provisiones, "Invitar amigos", `RoleHUD` y
  `ComboHUD`, y la ventana se ajusta a su contenido hasta 12 px del borde de abajo. Las ventanas no
  tapan la barra del menú en columna (`BAR_ROOM` a cada lado). Las listas largas compartidas con la
  Isla (Diario, Ajustes) se reparten en PC en 2–4 columnas (`spreadColumns`) para verse sin desplazarse.
  En una pantalla de menos de 500 px de alto (`compactUi`, un teléfono) la ventana ocupa todo el ancho
  y el alto libres, las filas miden 52 px con textos con tope (título 16, detalle 12, botón 15) y
  cualquier ventana que no quepa se reparte en columnas de al menos 280 px; Arena, Mascotas y Ranking
  se colocan solas en dos columnas. Con una ventana abierta también se esconden `ActionButtons` y la
  `TouchGui` de Roblox (joystick y salto), que en el teléfono la tapaban.

## 8. Ajustes del jugador

Cuando haya varias formas razonables de colocar o mostrar algo, el usuario quiere que sean
**opciones del jugador** en Ajustes, no una elección suya: `Shared/Settings.luau` (valores, defectos y
`sanitize`), `Shared/UI/SettingsPanel.luau` (la fila del panel) y el código que lo dibuja leyendo
`Settings.get()` y `Settings.onChanged`. Ejemplos ya hechos: `textLayout` ("Head", "Column",
"Screen") y `numberFont` ("Comic", "Classic") para los números de combate, `comicFx` / `comicLevel` / `comicSize` para los estallidos de
cómic y `cameraShake` ("On", "Soft", "Off") para el temblor de la cámara (`CombatClient/CameraShake`: todo
temblor nuevo pasa por ahí). En el Lobby las secciones de Ajustes se reparten en columnas por orden: la del
temblor va sola detrás de "Controles del combate" porque en la de opciones ya no cabía sin desplazarse. En el panel, `choiceRow` (fila de botones para elegir uno) y `toggleLine` (Sí/No) son las
piezas para añadir una opción nueva. Otro ejemplo, de la mira de la arena (Fase 15, V6): `crosshairStyle`
("Cross", "Dot", "Circle", "CrossDot", "T"), `crosshairColor` (blanco, amarillo, cian, magenta y rojo claro: nunca
verde ni morado), `crosshairSize`, `crosshairThickness` y `crosshairDynamic` (Sí por defecto), en la sección
"🎯 Mira" del contexto "Arena" de `SettingsPanel`, con su vista previa viva. La mira de Lab y Dunas lee esos
ajustes (`Shared/UI/Crosshair`): una opción nueva de mira se añade ahí, no en el código de cada arena.
