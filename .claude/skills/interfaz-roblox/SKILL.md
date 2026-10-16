---
name: interfaz-roblox
description: Crea, edita, mueve y reorganiza la interfaz del juego (HUD, botones, menús, ventanas, barras, avisos, iconos, textos en pantalla, carteles sobre la cabeza, efectos en pantalla como un destello de golpe crítico) en la Isla y el Lobby, manteniendo la coherencia visual con lo que ya hay (paleta, fuentes, capas y sitio en pantalla) y comprobándola en Roblox Studio a través de su MCP con maquetas de teléfono y PC, el volcado del HUD real en Play y capturas. Úsala siempre que el usuario pida añadir, mover, rediseñar, agrandar, ordenar o arreglar cualquier cosa de la interfaz ("mueve el reloj abajo a la derecha", "pon una imagen cuando haga un crítico", "el botón de volver al lobby tapa algo", "haz un menú de mascotas", "en el móvil no se lee", "HUD", "UI", "GUI", "ScreenGui", "botón", "icono", "panel", "ventana", "popup"), aunque no diga "interfaz" ni mencione Studio, o cuando pase una captura del juego con zonas marcadas. No es para modelos 3D (skill modelos-3d-roblox) ni animaciones (skill animaciones-roblox).
---

# Interfaz del juego en Roblox Studio

Esta skill cambia o crea piezas de la interfaz y comprueba **mirándolas** que encajan: en un teléfono
y en un PC, sin tapar nada y con el mismo aspecto que el resto del juego. La interfaz de este juego
se hace toda por código (no hay nada a mano en `StarterGui`), así que los cambios van al repo; Studio
sirve para ver y medir.

Lo que más se rompe al tocar la interfaz, y que esta skill está pensada para evitar:
- Lo que en PC se ve bien choca en el móvil con el salto, los botones táctiles o el joystick.
- Cada pieza nueva estrena colores, esquinas y fuentes, y la interfaz deja de parecer de un juego.
- Mover una pieza deja atrás a otra que dependía de ella (el ⚙️ va pegado a "Volver al Lobby").

Recursos de la skill (rutas relativas a esta carpeta):
- `references/estilo-ui.md`: dónde se crea cada pieza, paleta, fuentes, medidas, capas
  (`DisplayOrder`), mapa de la pantalla con las zonas ocupadas y dependencias entre piezas.
  **Léelo antes de escribir código de interfaz.**
- `scripts/maqueta_ui.luau` (modo edición): monta pantallas de teléfono, tablet y PC en
  `StarterGui._VistaPreviaUI` con las zonas de Roblox marcadas en rojo, para construir ahí la pieza y
  devolver un informe de solapes, piezas fuera de pantalla, botones pequeños y textos ilegibles.
- `scripts/volcar_hud.luau` (en Play, lado cliente): lee el HUD real del jugador y devuelve el
  rectángulo de cada pieza y qué se tapa con qué. No cambia nada.

Los scripts no se ejecutan en tu terminal: lee el archivo y manda su contenido con `execute_luau`,
añadiendo al final las líneas del encargo. Para no mandarlos enteros en cada vuelta, la primera vez
termina con `_G.UI = UI` (o `_G.Hud = Hud`) y en las siguientes empieza con `local UI = _G.UI`. `_G`
del modo edición y el del cliente en Play son distintos, y el del cliente se pierde al parar.

## 0. Conexión con Studio

1. Carga las herramientas `mcp__Roblox_Studio__*` con ToolSearch si están diferidas.
2. `list_roblox_studios`: el place **"Isla"** es la isla; **"Isla de plátanos primitivos"** es, pese
   al nombre, el **Lobby**. Elige el del HUD que vas a tocar.
3. `get_studio_state`. La maqueta va en **edición**; el volcado del HUD real, en **Play** (datamodel
   `Client`). Si el usuario está jugando una prueba, no la pares: usa ese Play para volcar y capturar
   y deja la maqueta para cuando vuelva a edición. Si hace falta Play y está en edición, puedes
   arrancarlo con `start_stop_play` y pararlo al terminar.

Si el MCP no está disponible, la puesta en marcha está en
`../modelos-3d-roblox/references/herramientas-mcp.md` (sección final). Sin MCP puedes escribir el
código igual, pero dilo claramente: no lo has visto. Pide al usuario una captura en PC y otra con el
emulador de dispositivos de Studio en un teléfono.

## 1. Entender el encargo

Antes de tocar nada, escribe una **ficha** breve en la conversación:

- **Qué pieza** y **para qué** (información que se mira de reojo, botón que se pulsa a menudo, aviso
  de un momento, ventana que se abre a veces). Eso decide tamaño, sitio y capa.
- **Dónde se crea**: archivo y función (tabla de `estilo-ui.md` §1, o grep por su texto). Si es
  nueva, en qué controlador encaja o si merece uno propio (`src/island/client/Controllers/`, o
  `src/shared/UI/` si la usan los dos places).
- **En qué place**: Isla, Lobby o ambos.
- **Sitio en pantalla** en los dos tamaños que importan: teléfono apaisado (844 x 390) y PC. Mira el
  mapa y las zonas ocupadas de `estilo-ui.md` §6.
- **Estados**: vacío, texto largo, día y noche, con y sin jefe, con la ventana de Ajustes abierta.
- **Qué arrastra**: piezas que dependen de esta (`estilo-ui.md` §7).
- **Estilo**: qué colores, fuente, esquinas y capa toma de lo que ya hay. Lo nuevo copia a su pariente
  más cercano (un botón nuevo es un `Widgets.button`; una ventana nueva, como la de Ajustes o la de
  fabricación).

**Con una captura marcada** (cuadros de colores sobre una imagen del juego), describe con tus
palabras qué entiendes que va de dónde a dónde antes de hacerlo, sobre todo si hay más de un cuadro
de cada color. Si el destino choca con una zona ocupada en algún dispositivo (lo típico: abajo a la
derecha, donde en móvil están el salto y los botones táctiles), dilo y propón alternativas
(otra esquina, otra disposición solo en táctil, o una opción en Ajustes) antes de construir.

Cuando haya varias formas razonables de hacerlo, el usuario prefiere que sean **opciones del
jugador en Ajustes** (`estilo-ui.md` §8): pregunta qué opciones quiere ofrecer, no cuál de ellas
elige.

## 2. Coherencia: las reglas

Todo lo concreto está en `estilo-ui.md`; lo esencial:

1. **Usa las piezas comunes**: `Widgets.screen`, `Widgets.label`, `Widgets.button`. Si repites el
   mismo bloque de propiedades en dos sitios, es una pieza común que falta: añádela a `Widgets`.
2. **Paleta del juego**: dorado = acción, madera oscura = fondos, verde/naranja/rojo = bien/aviso/
   peligro. Nada de colores nuevos sin motivo; si hace falta uno, añádelo a la tabla.
3. **Fuentes BuilderSans**, texto blanco con borde sobre el mundo, emojis como iconos.
4. **Medidas**: esquinas 12–14 px, botones de al menos 44 px de lado en móvil (mejor 48), margen de
   12 px o del 2 % al borde, ventanas con `UISizeConstraint`.
5. **Capas**: el `DisplayOrder` de la tabla, según lo que sea.
6. **Pantallas distintas**: posiciones en escala (`fromScale`) con `AnchorPoint` en la esquina a la
   que se pega la pieza, y tamaños con `UISizeConstraint` o `UITextSizeConstraint` para que no
   crezcan sin fin en un monitor grande ni encojan hasta no leerse en un teléfono. Lo que deba estar
   en otro sitio en táctil, decídelo con `UserInputService.TouchEnabled` (o `PreferredInput`) y
   reacciona al cambio.
7. **Agrupa lo que va junto** en un `Frame` contenedor con `UIListLayout`, en vez de colocar cada
   pieza con cuentas que dependen de la otra.
8. **Breve en el centro**: lo que salga en mitad de la pantalla dura poco y no bloquea los toques
   (`Active = false`, sin botones).

## 3. Maqueta en modo edición

Para piezas nuevas y cambios de sitio. Es lo más rápido: no hace falta Play ni Rojo.

1. Manda `scripts/maqueta_ui.luau` + tu código. Recrea en la maqueta lo que vas a cambiar copiando
   las líneas de diseño del controlador (`AnchorPoint`, `Position`, `Size`, colores) y las piezas
   vecinas con las que podría chocar:
   ```lua
   _G.UI = UI
   local Widgets = UI.freshRequire("ReplicatedStorage.Shared.UI.Widgets")
   UI.montar({ "telefono", "pc" })
   UI.cada(function(pantalla)
   	local reloj = Widgets.label("Día 12 · 🌙 10:00", pantalla.normal)
   	reloj.Name = "Clock"
   	reloj.AnchorPoint = Vector2.new(1, 1)
   	reloj.Position = UDim2.fromScale(0.98, 0.98)
   	reloj.Size = UDim2.fromScale(0.3, 0.06)
   end)
   return UI.informe()
   ```
   `pantalla.normal` es un ScreenGui normal (debajo de la barra de Roblox); `pantalla.completa`, uno
   con `IgnoreGuiInset`. Para que una pieza del juego que no tocas cuente como ocupada, añádela con
   `UI.zona(pantalla, "Nombre", Vector2.new(x, y), Vector2.new(ancho, alto))` (píxeles del
   dispositivo, por ejemplo los de `volcar_hud.luau`).
   Usa **textos de caso peor** (el número más largo, el nombre más largo) para ver si caben.
2. Lee el **informe**: solapes entre piezas, piezas que pisan una zona de Roblox, fuera de pantalla,
   botones de menos de 44 px en táctil, textos de menos de 11 px.
3. **Captura** con `screen_capture` (sin cámara: la maqueta tapa el visor). **Una captura por
   llamada**, nunca varias en paralelo. Para mirar el teléfono de cerca, móntalo solo:
   `UI.montar({ "telefono" })`.
4. **Critica**: ¿se lee en el teléfono?, ¿pisa algo?, ¿parece del mismo juego que lo de al lado
   (color, esquinas, fuente, borde)?, ¿está alineado con sus vecinos (mismo margen, misma altura)?,
   ¿el orden de lectura tiene sentido (lo importante arriba o junto al pulgar)?
5. Corrige y repite (unas 5 vueltas como mucho antes de enseñárselo al usuario).

**Antes de darle a Play, borra la maqueta** con `UI.limpiar()`: todo lo que hay en `StarterGui` se
copia al jugador al empezar la partida y la maqueta taparía el juego.

## 4. Llevarlo al repo

1. Cambia el controlador (o crea la pieza) con lo que salió de la maqueta, con el estilo del
   archivo: `--!strict`, comentarios en español que expliquen el porqué de lo que no es obvio,
   constantes de color arriba del archivo.
2. Si mueves algo, revisa sus dependientes (`estilo-ui.md` §7) y los comentarios que nombran su sitio
   ("debajo del reloj…"): actualízalos.
3. Si cambias la paleta, las capas, el mapa o las dependencias, actualiza `references/estilo-ui.md`.
4. `stylua src` y `selene src` sin errores (el CI los pasa).

## 5. Comprobar en el juego

1. Con Rojo conectado, comprueba con `script_grep` que Studio ya tiene el cambio (busca una línea
   nueva). Rojo **no se reconecta solo** tras reiniciar Studio: si no está, pídele al usuario que
   pulse *Connect* en el plugin.
2. Play (si no lo está) y manda `scripts/volcar_hud.luau` con `datamodel_type = "Client"`:
   `return Hud.volcar()`. Mira que las piezas estén donde esperabas y la lista de `solapes`. Para el
   detalle de una, `Hud.arbol("IslandHUD.Clock")`. Espera unos segundos tras arrancar: los
   controladores crean el HUD al empezar.
3. `screen_capture` en Play enseña el juego real con el HUD (sin los botones de Roblox de arriba,
   que sí están). Fuerza los estados que importen (de noche con "Saltar fase", con el jefe, con un
   aviso) desde el panel de pruebas o con `execute_luau` en `Server`.
4. **Pruebas rápidas sin tocar el repo**: en Play puedes cambiar el HUD real del cliente con
   `execute_luau` (`Players.LocalPlayer.PlayerGui.IslandHUD.ReturnToLobbyButton.Position = …`) y
   capturar. Se pierde al parar: sirve para enseñarle al usuario dos opciones sin escribir código.
5. **Móvil**: la única forma fiable de ver los controles táctiles reales es el emulador de
   dispositivos de Studio (pestaña *Prueba* > *Dispositivo*), que no se puede activar desde el MCP.
   Si el cambio afecta a la parte de abajo o a los lados, pídele al usuario que elija un teléfono
   en el emulador antes del Play; `volcar_hud` te dirá el tamaño del visor y si es táctil.
6. Si lo arrancaste tú, para el Play al terminar.

## Imágenes (un destello de crítico, un icono, un marco)

Orden de preferencia, de más a menos coherente y barato:

1. **Con piezas de interfaz**: `Frame`, `UICorner` (círculos con 0.5), `UIStroke`, `UIGradient`
   (con `Transparency` para brillos), `Rotation`, texto con emoji y borde. Queda en git, se ajusta con
   números y no pasa moderación. Ejemplo ya hecho: la estrella de brillo `glare` de
   `AbilityFxController.luau` (rayos con gradiente que giran y se apagan). Es la opción por defecto
   para destellos, estallidos, marcos y fondos.
2. **Imagen propia**: solo si con piezas no sale (un dibujo, un sello con textura). Se dibuja como
   SVG o con Python (como la portada en `art/portada/gen.py`), con la paleta del juego y fondo
   transparente, y se guarda en `art/ui/<nombre>.png` (fuente editable al lado). Para subirla,
   `upload_image` pide una URL http: sirve la carpeta con `python -m http.server` en segundo plano y
   pasa `http://localhost:<puerto>/<nombre>.png`. **Pide permiso antes de subir**: se publica en la
   cuenta de Roblox del usuario y pasa moderación (puede tardar o rechazarse). El `rbxassetid://`
   que devuelve va a una constante del código, no a un `Image` suelto en el place.
3. **Creator Store** (`search_asset`/`insert_asset`): solo si el usuario lo prefiere; revisa la
   licencia y que encaje con el estilo.

Para un efecto que acompaña a un suceso del juego (un crítico, subir de nivel), engánchalo donde el
cliente ya se entera de ese suceso en vez de crear un remoto nuevo. Los críticos llegan a
`CombatTextController.luau` por `Remotes.CombatText` (cada número trae `crit`), y
`CombatTextColumn.luau` ya hace el "pop" y el temblor del número. Un efecto de crítico tiene que ser
**corto** (menos de medio segundo), no tapar el centro, salir solo para los críticos que hace el
jugador (no los de los aliados ni los que recibe, salvo que se pida) y probablemente ser una opción
en Ajustes. Para verlo: "🎯 Críticos al 100 %" en el panel de pruebas y golpear al muñeco de
práctica del Basecamp. Los avisos de estado se fuerzan igual ("👑 Siguiente jefe", "🥚 Huevo",
"⏩ Saltar fase" para la noche).

## 6. Cerrar

1. `UI.limpiar()` en modo edición: no puede quedar `_VistaPreviaUI` en `StarterGui` (se vería en el
   juego publicado). Comprueba con `search_game_tree` o `inspect_instance` que no está.
2. Si tocaste algo del place (no del repo), recuérdale al usuario que guarde y publique.
3. Resume: qué cambiaste y en qué archivos, cómo queda en teléfono y en PC (con la última captura),
   lo que no has podido comprobar (por ejemplo, los controles táctiles reales sin el emulador) y qué
   decisiones tomaste por tu cuenta.

## Si algo no cuadra

- "No veo el cambio" en Play → Rojo desconectado o Studio sin sincronizar; compruébalo con
  `script_grep`. En la maqueta → caché de `require` (usa `UI.freshRequire`; los `require` internos
  del módulo siguen en caché).
- La maqueta sale en el juego → no se limpió antes del Play: para, `UI.limpiar()` y vuelve a empezar.
- Las piezas salen 58 px más arriba o más abajo de lo esperado → mezclas un ScreenGui con
  `IgnoreGuiInset` y otro sin él. `volcar_hud` da todo medido desde la esquina de la pantalla entera.
- Un texto se ve diminuto en el teléfono → `TextScaled` con una caja baja o un texto largo; dale alto
  mínimo en píxeles o parte el texto en dos líneas.
- Un botón no responde en el móvil → otra pieza con `Active = true` o un `ScreenGui` con más
  `DisplayOrder` lo tapa (aunque sea transparente).
- `execute_luau` en `Client` dice que no hay datamodel → Studio no está en Play.
- Un `require` desde `execute_luau` da **otra copia** del módulo, no la del juego: parchear
  `ComicBurst.play` no cambia lo que dibuja el controlador, `require(Shared.Remotes)` en el servidor
  crea una segunda carpeta `Remotes` con remotos que nadie escucha, y lo que la copia de `CombatText`
  deja para enviar por lotes nunca sale. Para simular un golpe, dispara el `RemoteEvent` que ya
  existe (`ReplicatedStorage.Remotes.CombatText:FireAllClients({...})`) antes de requerir nada.
- Un efecto que dura medio segundo ya no está cuando llega la siguiente llamada del MCP: regístralo
  con `PlayerGui.ChildAdded` (o clónalo a los 0.2 s para que quede quieto) antes de provocarlo.
- `screen_capture` da timeout o `ViewportSize` es 1 x 1 → la ventana de Studio está minimizada o el
  visor está oculto; pide al usuario que la deje a la vista.
- Los efectos de cómic (`ComicFx`) son estallidos del mundo con el dibujo en `art/ui/comic/gen.py`
  (un atlas de 1024 en blanco y negro que se tiñe); para retocar formas, cambia el script, súbelo de
  nuevo (con permiso) y actualiza `ATLAS` en `ComicBurst.luau`.
- Editar archivos del repo con Python en Windows → ábrelos con `newline=''`, o `git diff` marcará el
  archivo entero como cambiado.
