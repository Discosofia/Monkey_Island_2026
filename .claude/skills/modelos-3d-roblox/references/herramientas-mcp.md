# Herramientas del MCP de Roblox Studio

Studio trae su propio servidor MCP (Assistant > … > Manage MCP Servers > *Enable Studio as MCP
server*). En este repo está configurado en `.mcp.json` con el nombre `Roblox_Studio`, así que las
herramientas aparecen como `mcp__Roblox_Studio__<nombre>`. Si no aparecen, ver "Puesta en marcha" al
final.

Documentación oficial: https://create.roblox.com/docs/studio/mcp (puede haber cambiado: si una
herramienta no responde como se describe aquí, fíate de su esquema y de lo que devuelve).

## Las que usa esta skill

| Herramienta | Para qué |
|---|---|
| `list_roblox_studios` | Da el `studio_id` que piden **todas** las demás. Llámala primero. Si hay varios Studios abiertos, elige el del place correcto (Isla o Lobby) y pregunta si no está claro. |
| `get_studio_state` | Si Studio está en Play o en edición. Para construir hay que estar en edición (Stop). |
| `execute_luau` | Ejecuta Luau en Studio y devuelve el resultado o el error. Usa `datamodel_type = "Edit"` para construir y revisar modelos. Devuelve lo que haga `return` (mejor una cadena o JSON). |
| `screen_capture` | Captura la vista de Studio y te la devuelve como imagen. Acepta posición de cámara y punto al que mirar: usa las cámaras que devuelve `vista_previa.luau`. **Una por llamada**: no lances varias en paralelo (el usuario las ha rechazado). Las líneas blancas finas que salen en los modelos articulados son las articulaciones (Motor6D y soldaduras) que Studio dibuja, no piezas: ignóralas. Si hay algo seleccionado y su recuadro estorba, vacía la selección con `game.Selection:Set({})` en el `execute_luau` anterior. |
| `inspect_instance` | Propiedades, atributos e hijos de una instancia. Útil para un vistazo rápido; para un modelo entero usa `volcar_modelo.luau`. |
| `search_game_tree` | Busca instancias en el árbol del place (por ruta, tipo o palabras). Para encontrar un modelo que el usuario nombra sin dar la ruta. |
| `script_grep` / `script_read` | Lee los scripts **tal como están en Studio**. Sirve para comprobar que Rojo ya sincronizó un cambio. No edites scripts sincronizados por Rojo desde aquí: se editan en el repo. |
| `get_console_output` | La Salida de Studio, para ver errores o `print`. |

## Generación con IA (usar con criterio)

| Herramienta | Qué hace | Cuándo |
|---|---|---|
| `generate_procedural_model` | Crea un modelo **de primitivas** (bloques, bolas, cilindros, cuñas) a partir de una descripción; admite **imágenes de referencia** y esquemas de piezas. Es un trabajo asíncrono: devuelve un id. | Para tener un primer borrador rápido de algo complejo (un barco, un templo) o cuando el usuario da una imagen. Después se vuelca con `volcar_modelo.luau` y se limpia/traduce al estilo del repo. |
| `wait_job_finished` | Espera a que termine un trabajo de `generate_procedural_model`. | Justo después de lanzar la generación. |
| `store_image` | Carga una imagen **local** (ruta de archivo) y devuelve una URI para pasarla a otras herramientas. | Para dar una referencia a `generate_procedural_model`. Una imagen pegada en el chat no tiene ruta: pide al usuario que la guarde en un archivo si quieres usarla así (tú puedes verla igualmente para comparar). |
| `generate_mesh` | Genera una **malla 3D texturizada** (MeshPart) a partir de un texto. | Solo para formas orgánicas o realistas que con primitivas quedan mal y cuando el usuario lo acepta. Ver advertencias abajo. |
| `generate_material` | Crea una variante de material (MaterialVariant) y devuelve el material base y el nombre de la variante. | Para texturas especiales (corteza, escamas). Las variantes viven en `MaterialService` del place: no en git. |
| `generate_texture` / `segment_mesh` | Aparecen en el servidor aunque la documentación no las describe: textura generada y división de una malla en partes. | Solo junto a mallas; lee su esquema antes de usarlas. |
| `search_asset` / `insert_asset` | Busca e inserta modelos de la Creator Store / inventario. | Cuando el usuario prefiere un modelo ya hecho. Revisa que no traiga scripts (pueden ser maliciosos) y quítaselos. |

No sé a ciencia cierta dónde deja Studio el resultado de las herramientas de generación ni sus
límites de uso: tras usarlas, búscalo con `search_game_tree` o en `Workspace` y míralo con
`volcar_modelo.luau` antes de dar nada por hecho.

### Advertencias sobre las mallas (generate_mesh, insert_asset)

- La malla es un **asset de Roblox**, no código: no queda en git y el modelo depende de su id. Para
  usarla en el juego hay que guardarla en el place (por ejemplo en `ReplicatedStorage` o
  `ServerStorage`) y que el código la clone, o crearla con `AssetService:CreateMeshPartAsync`.
- Desentona con el estilo de piezas simples del resto del juego si es muy realista.
- Una malla cuenta como una pieza pero puede tener miles de triángulos: vigila el rendimiento en móvil.
- Avisa al usuario de todo esto antes de usarla en vez de primitivas.

## Llamadas a execute_luau

- Siempre `datamodel_type = "Edit"` para construir. En Play los cambios se pierden al parar.
- Haz que el código termine con `return` de una cadena (o JSON con `HttpService:JSONEncode`, que
  funciona sin activar HTTP). Lo que no devuelvas no lo verás.
- Si cambias algo fuera de `Workspace._VistaPrevia` (un modelo del place), envuélvelo en un registro de
  deshacer para que el usuario pueda volver atrás con Ctrl+Z:

  ```lua
  local ChangeHistoryService = game:GetService("ChangeHistoryService")
  local recording = ChangeHistoryService:TryBeginRecording("Retocar barca")
  -- ... cambios ...
  if recording then
  	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
  end
  ```

- `require` en Studio guarda el primer resultado de cada módulo toda la sesión. Usa
  `Preview.freshRequire` de `vista_previa.luau` para cargar la versión recién sincronizada. Esto
  vale también para los **datos**: si cambias un color o un `scale` en `Data/Monkeys` o
  `Data/Bosses`, cárgalos con `freshRequire` y pásaselos tú al constructor. Con un `require` normal
  verías los valores viejos aunque el constructor sí esté actualizado.
- Para no mandar `vista_previa.luau` entero en cada vuelta, la primera vez termina el script con
  `_G.Preview = Preview` y en las siguientes usa `local Preview = _G.Preview`: `_G` se conserva entre
  llamadas mientras Studio no se cierre. Al terminar, `_G.Preview = nil`.
- Si Studio se reinicia, cambia el `studio_id` (vuelve a llamar a `list_roblox_studios`) y el plugin
  de Rojo **no se reconecta solo**: los servidores siguen activos (34872 Lobby, 34873 Isla), pero hay
  que pulsar *Connect* en el plugin. Con `script_grep` de una línea nueva lo notas; pídeselo al
  usuario en vez de pegar el código en los scripts del place.
- Para probar algo de juego (por ejemplo una orden del panel de pruebas) sin Rojo ni botones: Play
  con `start_stop_play` y `execute_luau` con `datamodel_type = "Server"`, pegando la función. En Play
  no hay datamodel `Edit`: para tocar la vista previa, para el juego antes.
- Antes de cargar el módulo, comprueba que Rojo ya sincronizó el cambio: `script_grep` de una línea
  nueva, o dentro del mismo `execute_luau`,
  `assert(Preview.find(ruta).Source:find("texto nuevo"), "Rojo aún no ha sincronizado")`.

## Puesta en marcha (si las herramientas no aparecen)

1. En Studio (en español): abre el **Asistente** con el icono redondo de colores de arriba a la
   derecha (no está en el menú Ventana), **⋯ > Configuración del asistente > Servidores MCP** y activa
   **Habilitar Studio como servidor MCP**. No se puede activar desde la barra de comandos.
2. Para comprobar que Studio está conectado sin reiniciar Claude Code, habla con el servidor por
   stdio (`initialize` + `tools/call` de `list_roblox_studios`): si devuelve `"studios":[]`, falta el
   paso 1 o Studio está cerrado.
3. El repo ya trae `.mcp.json` con el servidor `Roblox_Studio`
   (`cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`). Al abrir Claude Code en el repo, aprueba el servidor
   cuando lo pregunte (o revisa `/mcp`).
4. Reinicia Claude Code. En Studio, en *Servidores MCP*, debe verse un indicador verde.
5. Si sigue sin ir: reinicia Studio y Claude Code, y comprueba que existe
   `%LOCALAPPDATA%\Roblox\mcp.bat`.
6. Para que Studio tenga el código del repo, Rojo tiene que estar conectado:
   `rojo serve island.project.json` (o `lobby.project.json`) y *Connect* en el plugin de Rojo.
