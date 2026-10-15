---
name: modelos-3d-roblox
description: Crea y edita modelos 3D de Roblox (piezas, armas, armaduras, mascotas, monos, árboles, rocas, construibles, decorado, edificios, vehículos) a partir de una descripción o de una imagen de referencia, viéndolos en Roblox Studio a través de su MCP (execute_luau y screen_capture) para revisar y corregir hasta que se parezcan a lo pedido. Úsala siempre que el usuario pida hacer, rehacer, mejorar, remodelar o retocar la forma, el tamaño, los colores o los detalles de cualquier objeto visible del juego ("hazme un hacha de piedra", "que la palmera se parezca a esta foto", "el gorila tiene los brazos muy cortos", "crea una cabaña", "modelo 3D", "mesh", "greybox", "low-poly"), aunque no diga "modelo 3D" ni mencione Studio. No es para animaciones, interfaces ni efectos de partículas.
---

# Modelos 3D en Roblox Studio

Esta skill convierte una descripción o una imagen en un modelo de Roblox hecho con piezas (o, si
hace falta, mallas) y lo itera **mirándolo**: lo construyes en Studio con el MCP, lo capturas desde
varios ángulos, lo comparas con lo pedido y lo corriges. Sin ese ciclo los modelos salen con piezas
flotando, proporciones raras o mirando hacia atrás, y el usuario tiene que hacer de tus ojos.

Recursos de la skill (rutas relativas a esta carpeta):
- `references/estilo-del-proyecto.md`: dónde vive cada tipo de modelo, ejes, paleta, escala y
  presupuesto de piezas. **Léelo antes de escribir código de modelos.**
- `references/herramientas-mcp.md`: qué hace cada herramienta del MCP de Studio, la generación con
  IA y cómo ponerlo en marcha si no está conectado.
- `scripts/vista_previa.luau`: pone un modelo en una zona de pruebas aislada y devuelve su tamaño, sus
  piezas y las cámaras para las capturas.
- `scripts/volcar_modelo.luau`: vuelca un modelo del place a código Luau (para inspeccionarlo o
  traducirlo al estilo del repo).

Los scripts no se ejecutan en tu terminal: lee el archivo y manda su contenido con `execute_luau`
(`datamodel_type = "Edit"`), añadiendo al final las líneas del encargo.

## 0. Conexión con Studio

1. Busca las herramientas `mcp__Roblox_Studio__*` (si están diferidas, cárgalas con ToolSearch).
2. `list_roblox_studios` → guarda el `studio_id`. Si hay varios, elige el place que toca (Isla o
   Lobby).
3. `get_studio_state`: tiene que estar en edición, no en Play. Si está en Play, pide al usuario que
   pare (o usa `start_stop_play` si te lo permite).

Si el MCP no está disponible, explica en dos líneas cómo activarlo (ver la sección final de
`references/herramientas-mcp.md`) y pregunta si prefiere activarlo o seguir sin él. Sin MCP puedes
escribir el código igual, pero dilo claramente: no lo has visto, y pídele capturas de frente, de lado
y en 3/4 para revisarlo.

## 1. Entender el encargo

Antes de colocar una sola pieza, escribe una **ficha** breve (en la conversación, no en un archivo):

- **Qué es** y **para qué se usa en el juego** (se sostiene en la mano, se pisa, se repite cien veces
  por el mapa, sale una vez en el Lobby…). Esto decide dónde va y cuántas piezas puede tener.
- **Dónde vive**: en un módulo del repo (la mayoría; tabla en `estilo-del-proyecto.md` §1) o en el
  place (decorado colocado a mano). Si es un tipo nuevo que no encaja en ningún módulo, propón dónde
  ponerlo antes de crear un archivo nuevo.
- **Tamaño en studs** (alto x ancho x fondo), comparado con un personaje de 5 studs.
- **Silueta y masas principales**: las 3–6 formas grandes que hacen que se reconozca a 30 studs. Los
  detalles van después y solo si se ven.
- **Paleta**: 3–6 colores, reutilizando las constantes del módulo.
- **Pivote y frente** según las reglas del módulo (casi siempre el frente mira a -Z).
- **Presupuesto de piezas** (`estilo-del-proyecto.md` §6).

**Con una imagen de referencia**, mírala con atención y anota: proporciones (alto:ancho:fondo, y las
de las partes entre sí: "la cabeza es un tercio del cuerpo"), la silueta, los colores dominantes, y
qué rasgos la hacen reconocible frente a lo que es solo ruido. El objetivo es una versión low-poly
fiel en silueta y color al estilo de la isla, no una copia pieza a pieza de algo realista. Si solo
se ve un lado, deduce los demás con sentido común y dilo.

La **pose** de la foto no manda si el modelo está articulado y animado: un mono sentado en la foto se
queda a cuatro patas en el juego, porque las animaciones de andar, atacar y lanzar parten de esa
postura. Toma de la imagen la silueta, los colores y los rasgos, no la pose, y díselo al usuario.
Por lo mismo, un accesorio que en la foto cuelga de la mano (un collar, una bolsa) atraviesa el
suelo en un mono que se apoya en los nudillos: llévalo al cuello, al pecho o a la espalda.

Si falta algo que cambia el resultado (¿es para un jugador o para un jefe gigante?, ¿sustituye a un
modelo que ya existe?), pregunta. Lo demás (colores exactos, número de detalles) decídelo tú y
menciónalo.

## 2. Elegir la técnica

| Técnica | Cuándo | Resultado |
|---|---|---|
| **Primitivas por código** (por defecto) | Casi siempre: es el estilo del juego, queda en git y se ajusta con números. | Constructor Luau en el módulo del repo. |
| **`generate_procedural_model` como borrador** | Objetos grandes o complejos, o cuando hay imagen de referencia y quieres un punto de partida. | Lo vuelcas con `volcar_modelo.luau`, lo limpias y lo traduces a un constructor. Nunca se queda tal cual. |
| **`generate_mesh` / Creator Store** | Formas orgánicas o realistas que con primitivas no salen, y solo si el usuario lo acepta tras explicarle las pegas. | Malla guardada en el place; el código la clona. |
| **Retoque en el place** | Modelos que ya están en el place y no vienen del repo (decorado, cosas de la Caja de herramientas). | Cambios con `execute_luau` y registro de deshacer. |

Detalles de cada herramienta y advertencias en `references/herramientas-mcp.md`.

## 3. Construir por capas

Construye en este orden y mira el resultado entre capas; corregir la silueta cuando ya hay cuarenta
detalles encima es mucho más caro:

1. **Masas**: las formas grandes con su tamaño y posición. Compara la silueta con la referencia.
2. **Formas secundarias**: extremidades, ramas, mangos, techos.
3. **Detalles**: ojos, cordones, remaches, vetas. Solo los que se vean a distancia de juego.

Escribe el código como lo escribiría quien hizo el módulo: sus funciones de ayuda, sus constantes de
color, comentarios en español explicando el porqué de lo que no es obvio, `--!strict`, simetría con
`for side = -1, 1, 2`. Medidas derivadas de unas pocas variables (`height`, `width`) en vez de
números sueltos, para que luego "hazlo un poco más alto" sea cambiar un valor.

## 4. Ciclo de revisión en Studio

Repite hasta que esté bien (y como mucho unas 5 vueltas antes de enseñárselo al usuario):

1. **Llevar el código a Studio.** Si el modelo está en el repo y Rojo está conectado, comprueba con
   `script_grep` que Studio ya tiene tu cambio (busca una línea nueva) y carga el módulo con
   `Preview.freshRequire`. Si Rojo no está conectado, puedes mandar el constructor directamente
   dentro del `execute_luau` para iterar más rápido, y pasarlo al repo al final.
2. **Mostrar.** Manda `scripts/vista_previa.luau` + tu llamada, por ejemplo:
   ```lua
   local model = Preview.freshRequire("ReplicatedStorage.Shared.PetModels").build("Tucan")
   return Preview.show(model)
   ```
   Devuelve tamaño, piezas y cámaras (`frente`, `lado`, `detras`, `tresCuartos`, `arriba`).
3. **Capturar** con `screen_capture` usando esas cámaras: como mínimo `frente`, `lado` y
   `tresCuartos`; `arriba` si la planta importa (casas, alfombras). Si la herramienta no acepta
   cámara, mueve la cámara con `Preview.look(position, lookAt)` en un `execute_luau` antes de capturar.
   **Una captura por llamada, nunca varias en paralelo**: el usuario ha rechazado capturas lanzadas
   en paralelo. Para los detalles (cara, adornos), acerca la cámara en vez de fiarte de la vista
   general: a esa distancia una barba suelta o unos ojos saltones no se notan.
4. **Criticar** cada captura con esta lista, comparando con la ficha y la referencia:
   - ¿Se reconoce qué es solo por la silueta?
   - ¿Proporciones y tamaño correctos frente al maniquí de 5 studs?
   - ¿Mira hacia donde debe (frente a -Z)?
   - ¿Piezas flotando, rendijas que deberían estar cerradas, piezas que atraviesan donde se ve?
   - ¿Z-fighting (caras coplanarias que parpadean)?
   - ¿Colores fieles a la referencia y coherentes con la paleta del juego? Con la luz de Studio los
     tonos claros se ven más claros todavía (`estilo-del-proyecto.md` §4).
   - ¿Simetría donde debe haberla?
   - ¿Piezas dentro del presupuesto? Mira el número que devuelve `Preview.show` en cada vuelta: los
     adornos repetidos en bucle (plumas, cuentas) lo disparan sin que se note.
5. **Corregir** lo que falle, empezando por lo más gordo (silueta y proporciones antes que detalles).

Para comparar dos versiones, muéstralas a la vez con
`Preview.show(otra, { keep = true, offset = Vector3.new(15, 0, 0) })`.

Cuando lo enseñes, di qué cambiaste en cada vuelta y qué no has conseguido. El usuario lo verá en su
Studio: deja la cámara apuntando al modelo con `Preview.look` para que lo encuentre (la zona de
vista previa está lejos del mapa, en `Workspace._VistaPrevia`).

## 5. Integrar y cerrar

1. El constructor final en el módulo del repo, conectado a los datos (`Data/...`) si es un objeto
   nuevo. Si el modelo cambia el nombre de piezas que usan animaciones u otros sistemas, busca con
   grep quién las usa antes de tocarlas.
   Si cambias valores en `Data/...` (colores, `scale`), comprueba con `git diff` que solo cambió la
   entrada que querías: un `sed` por valor también cambia otras especies que compartan ese color.
   Si cambia el alto de un mono o de un jefe, actualiza la tabla de tamaños del GDD
   (`estilo-del-proyecto.md` §5).
2. `stylua src` y `selene src` sin errores (el CI los pasa).
3. Una última vista previa con el módulo real (no con el código pegado) para confirmar que lo que
   quedó en el repo es lo que viste.
4. `Preview.clear()` para borrar `Workspace._VistaPrevia`: no la dejes en el place del usuario.
5. Si tocaste algo del place (no del repo), recuerda al usuario que guarde y publique.
6. Resume: qué modelo, dónde está el código, tamaño, número de piezas, y cómo verlo en juego (por
   ejemplo, el expositor de armas del panel de pruebas para las armas).

## Editar un modelo existente

- **Si viene del repo** (búscalo con grep por su id o nombre): lee su constructor, muéstralo con
  `vista_previa.luau` **antes** de cambiar nada para ver el punto de partida, haz el cambio pedido y
  repite el ciclo. Cambia lo mínimo: el usuario pidió "brazos más largos", no rehacer el mono.
- **Si vive en el place**: encuéntralo con `search_game_tree`, vuélcalo con `volcar_modelo.luau` y
  haz una copia en la vista previa (`Preview.show(Preview.find(ruta):Clone())`) para probar ahí.
  Cuando esté bien, aplica el cambio al original con un registro de `ChangeHistoryService` (para que
  funcione Ctrl+Z) y avisa de que hay que guardar el place. Nunca toques `Workspace.Mapa` ni
  `Workspace.Naufragio` a mano: los generadores los rehacen.

## Si algo no cuadra

- "No veo el cambio" → caché de `require` en Studio (usa `freshRequire`; si el cambio está en un
  módulo del que depende, recárgalo también o reinicia Studio) o Rojo desconectado.
- El modelo sale en otro sitio o girado → revisa el pivote (`GetPivot`) y que el frente sea -Z.
- `execute_luau` da error → léelo entero; casi siempre es una ruta mal escrita en `Preview.find`.
