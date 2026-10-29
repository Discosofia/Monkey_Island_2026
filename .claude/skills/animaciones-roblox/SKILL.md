---
name: animaciones-roblox
description: Crea y modifica animaciones de Roblox (KeyframeSequence / AnimationTrack) de los monos, los jefes, el personaje del jugador con armas y las mascotas, viéndolas en Roblox Studio a través de su MCP (execute_luau y screen_capture). Monta tiras de poses congeladas en cada instante para revisarlas y corregirlas, baja y edita las animaciones ya publicadas y deja la nueva lista para publicar y enlazar en los datos del juego. Úsala siempre que el usuario pida hacer, rehacer, retocar, acelerar, exagerar o arreglar un movimiento o una pose ("el gorila ataca muy flojo", "haz una animación de saludo", "el brazo tiembla al disparar con el arco", "que el capuchino corra más gracioso", "las alas del tucán aletean muy lento", "animación", "keyframes", "pose", "Animation Editor", "rig"), aunque no diga "animación" ni mencione Studio. No es para la forma ni los colores de un modelo (eso es la skill modelos-3d-roblox), ni para interfaces o efectos de partículas.
---

# Animaciones en Roblox Studio

Esta skill crea o retoca una animación y la itera **mirándola**: la construyes en Studio con el MCP,
congelas el rig en varios instantes puestos en fila (una "tira"), capturas la tira, la comparas
con lo pedido y la corriges. Sin ese ciclo las animaciones salen con brazos que giran al revés,
pies que se hunden, bucles que dan un salto y golpes que llegan tarde, y el usuario tiene que hacer
de tus ojos.

Recursos de la skill (rutas relativas a esta carpeta):
- `references/sistemas-de-animacion.md`: los cuatro sistemas de animación del juego (monos, armas
  del jugador, mascotas, poses por código), dónde vive cada uno, nombres de las piezas y cómo se
  enlazan. **Léelo antes de tocar una animación.**
- `scripts/animacion.luau`: la biblioteca `Anim`. Crea rigs, baja animaciones publicadas, las
  vuelca a una tabla editable, construye la `KeyframeSequence` desde esa tabla, monta la tira y la
  guarda en el place.

El script no se ejecuta en tu terminal: lee el archivo y manda su contenido con `execute_luau`
(`datamodel_type = "Edit"`). La primera vez, termínalo con `_G.Anim = Anim` y tu código; en las
llamadas siguientes basta con `local Anim = _G.Anim` (dura hasta que se cierra Studio). Si cambias
el archivo, vuelve a mandarlo entero.

Con Rojo conectado (place de la Isla) es más rápido no pegarlo: copia el archivo con `return Anim`
al final a `src/island/tools/_AnimTemporal.luau`, espera a que Rojo lo lleve a
`ServerStorage.Tools`, cárgalo con una copia (`local c = m:Clone(); c.Parent = m.Parent;
_G.Anim = require(c); c:Destroy()`) y **borra el archivo** en cuanto esté en `_G` (no lo subas).

Para el estilo de los modelos, la paleta y la puesta en marcha del MCP, mira la skill hermana
`.claude/skills/modelos-3d-roblox` (sobre todo `references/herramientas-mcp.md`).

## 0. Conexión con Studio

1. Busca las herramientas `mcp__Roblox_Studio__*` (si están diferidas, cárgalas con ToolSearch).
2. `list_roblox_studios` → guarda el `studio_id`. Suele haber dos abiertos: **"Isla"** (tiene
   `ServerScriptService.Combat.Monkeys`, los monos y las armas) y el del Lobby (se llama "Isla de
   plátanos primitivos"). Las animaciones de monos y armas se trabajan en la Isla. Las mascotas
   están en los dos (`PetModels` y `PetFollowers` son de `ReplicatedStorage.Shared`): su animación
   es la misma y se puede revisar en cualquiera, y un cambio se ve en ambos.
3. `get_studio_state`: tiene que estar en edición (Edit), no en Play. Si está en Play, el usuario
   probablemente está probando: pídele que pare, no lo pares tú.

Si el MCP no está, explica en dos líneas cómo activarlo y pregunta si prefiere activarlo o seguir
sin él. Sin MCP puedes escribir la tabla de la animación igual, pero dilo claramente: no la has
visto.

## 1. Entender el encargo

Escribe una **ficha** breve en la conversación antes de tocar nada:

- **Qué rig**: mono o jefe (¿de qué especie la vas a revisar?), personaje del jugador (R15) o
  mascota. Decide el sistema (tabla en `sistemas-de-animacion.md` §1).
- **Qué acción** y **quién la usa**: una animación de mono vale para todas las especies salvo que
  vaya en `Overrides`. Un cambio en `Default` cambia a todos los monos y jefes.
- **Nueva o retoque**: si existe, se parte de la publicada (§"Editar una animación existente").
- **Duración, bucle y momento fuerte**: `Idle`/`Walk`/`Run` en bucle; las acciones, de una vez,
  cortas (0,3–0,8 s), y el golpe pronto (0,15–0,25 s), porque el sonido y el daño salen al empezar.
- **Qué piezas se mueven** y en qué sentido, con ángulos aproximados por fotograma. La receta de
  cada acción de los monos está en `docs/ANIMACIONES.md`: úsala como punto de partida.
- **Lo que no debe cambiar**: piezas que otra animación mueve debajo (las piernas al andar), la
  pose de partida (los disparos parten de `Hold`).

Si falta algo que cambia el resultado (¿solo para el gorila o para todos?, ¿sustituye la que ya
existe?), pregunta. Lo demás (ángulos exactos, easing) decídelo tú y menciónalo.

## 2. Formato spec

Las animaciones de KeyframeSequence se escriben como una tabla; `Anim.build(spec, rig)` la convierte
en `KeyframeSequence` y `Anim.dump(ks)` hace lo contrario:

```lua
local SPEC = {
	name = "Attack",
	loop = false,
	priority = "Action", -- MonkeyAnimator y WeaponController la sobrescriben al cargarla
	easing = "Cubic", -- por defecto de todas las poses: Linear, Cubic, Elastic, Bounce, Constant
	direction = "Out", -- In, Out, InOut
	keyframes = {
		{ t = 0, reposo = true },
		{ t = 0.12, ["Right Arm"] = { -40, 0, 0 }, Head = { 10, 0, 0 } },
		{ t = 0.22, ["Right Arm"] = { 80, 0, 0 }, Head = { -10, 0, 0 }, marcador = "Golpe" },
		{ t = 0.4, reposo = true },
	},
}
```

- Cada pose es `{ x, y, z }` en grados: los de `CFrame.Angles`, en el espacio de la pieza de la
  que cuelga. Con desplazamiento: `{ x, y, z, px, py, pz }` en studs (evítalo en los monos: no se
  escala con la especie). Para el easing de una sola pose: `{ 80, 0, 0, easing = "Bounce" }`.
- **Un fotograma vacío no mantiene la pose**: no tiene poses, así que Roblox interpola entre sus
  vecinos como si no estuviera. Para una pausa, repite la pose entera en los dos fotogramas.
- `reposo = true` pone a 0 todas las piezas animadas que ese fotograma no nombra. **Sin `reposo`,
  una pieza que no aparece no tiene pose** en ese fotograma y Roblox la interpola entre los de
  alrededor (útil para que la cabeza siga su camino mientras el brazo hace otra cosa).
- Las piezas animadas son las que aparecen en algún fotograma. Las demás no se tocan: la animación
  de debajo (Walk) sigue moviéndolas.
- **El easing de una pose rige el tramo que sale de ella** hacia el fotograma siguiente
  (comprobado en Studio). `Constant` salta enseguida a la pose siguiente.
- Easings que existen en las poses: `Linear`, `Constant`, `Cubic`, `Elastic`, `Bounce` y `CubicV2`
  (no hay `Sine` ni `Quad`: `build` falla). Para un fotograma entero, pon `easing`/`direction` en el
  fotograma, no en cada pose: así las poses siguen siendo listas `{ x, y, z }` y el spec se puede
  copiar tal cual a `MonkeyAnimationBuilder`.
- `marcador` añade un `KeyframeMarker` (las armas usan "Disparo" para sacar el efecto).

**Signos** (con las articulaciones alineadas con el modelo, como las de los monos y el R15):
X positivo lleva lo que cuelga por debajo de la articulación hacia delante (-Z) y arriba: un brazo
a 90° apunta al frente. En la cabeza, X positivo la echa atrás (mira arriba). Y positivo gira hacia
la izquierda del personaje; Z inclina de costado. Ante la duda, no lo razones: móntalo y míralo en
la tira.

## 3. Ciclo de revisión en Studio

Repite hasta que esté bien (y como mucho unas 5 vueltas antes de enseñárselo al usuario):

1. **Rig.** `Anim.monkeyRig("Gorila")` (especie o jefe, a escala 1; `{ scale = true }` para la real),
   `Anim.playerRig("R15")` o `Anim.placeRig("Workspace.Ruta")`. En el Lobby no hay monos:
   `Anim.playerRig("R6")` tiene las mismas piezas (Torso, Head, Right Arm…) pero otras proporciones.
2. **Construir y mostrar.**
   ```lua
   local rig = Anim.monkeyRig("Gorila")
   local ks = Anim.build(SPEC, rig)
   return Anim.show(rig, ks, { under = "rbxassetid://106939439241748" }) -- Walk debajo
   ```
   `show` pone en `Workspace._VistaAnimacion` una copia del rig por fotograma clave (o por cada
   `times = {…}` que le pases), con un rótulo de tiempo y marcador en el suelo, y devuelve JSON con
   la cámara de la tira (`tira`), una cámara por fotograma, el `suelo` de cada uno (negativo = se
   hunde) y `avisos` (bucle que no cierra, acción que no empieza o acaba en reposo, piezas que el
   rig no tiene, pies hundidos). Opciones: `view = "frente"` (por defecto, perfil: los giros en X,
   los más comunes, solo se ven de lado), `under` para la animación que suena debajo en el juego,
   `keep = true` + `offset = Vector3.new(0, 0, 30)` para poner otra versión al lado.
3. **Capturar** con `screen_capture` y la cámara `tira`. **Una captura por llamada**, nunca varias
   en paralelo (el usuario las ha rechazado). Si da *timeout* aunque `execute_luau` responda, la
   ventana de Studio suele estar minimizada o tapada: pídele al usuario que la traiga al frente y,
   si sigue sin ir, no te quedes parado: mide con `Anim.measure(rig, ks)` (abajo) y di claramente
   que no la has visto. Para un detalle (la mano en el golpe, la cara), usa
   la cámara de ese fotograma o `Anim.showOne(rig, ks, 0.22)`. Mira al menos el perfil; añade el
   frente si hay giros en Y o Z (torsiones, brazos abiertos). Las líneas verdes o blancas finas son
   las articulaciones que dibuja Studio: ignóralas.
4. **Criticar** cada captura:
   - ¿Se entiende la acción solo con la tira? (preparación → golpe → vuelta).
   - ¿Cada pieza gira hacia donde debe? El fallo más común es el signo cambiado.
   - ¿El momento fuerte llega pronto y es claro? ¿La preparación va en sentido contrario al golpe?
   - ¿Pies en el suelo? Si el `Torso` se inclina, las piernas compensan con el giro contrario.
   - ¿Empieza y acaba en reposo (acciones) o cierra el bucle (Idle/Walk/Run)?
   - ¿Se lee igual en un mono a cuatro patas, en un simio y en el gibón? Una animación de `Default`
     se revisa al menos en dos especies distintas.
   - ¿Los ángulos son creíbles? Un hombro a más de ~160° o un cuello a más de ~45° se rompen.
5. **Corregir** lo más gordo primero (sentido y tiempos antes que matices de easing).

**Medir sin ver.** `Anim.measure(rig, ks, times?)` da, por instante, lo más bajo de cada extremidad
(con el antebrazo, la mano, la espinilla y el pie que lleva pegados) respecto al suelo en reposo, la
altura de la punta de la cola y dónde queda la cabeza. Sirve para lo que la tira enseña peor:
- Pies o nudillos que se clavan: negativo. Hasta −0,15 a escala 1 no se nota; más, corrígelo.
- Si el golpe llega lejos y a qué altura: un brazo a 0,7 va "bajo", a 1,6 va a la altura de la cara.
- Si la cola roza el suelo: sale "Tail" con un valor negativo.
Los valores son a escala 1: en un jefe a escala 3,6, −0,3 son más de 1 stud.

Entre fotogramas clave no hay copia: si sospechas de un tramo (un brazo que atraviesa el cuerpo al
pasar de atrás adelante), pide instantes intermedios con `times`.

## 4. Integrar y cerrar

1. **Guardar en el place**: `Anim.save(ks, "RigMono")` la deja en
   `ServerStorage.RBX_ANIMSAVES.RigMono` (donde guarda el Animation Editor; los disparos de arma
   los genera `WeaponAnimationBuilder` en `ReplicatedStorage.WeaponAnimations`) y la selecciona en
   el Explorador. Tiene registro de deshacer.
2. **Publicar lo hace el usuario**: el MCP no puede subir animaciones. Pídele: clic derecho en la
   KeyframeSequence seleccionada → *Guardar en Roblox* (*Save to Roblox*), con **el mismo dueño que
   el juego** (su cuenta o el grupo) o no cargará en el juego publicado, y que te pase el id. Dónde
   encontrar el id si Studio no lo enseña: `docs/ANIMACIONES.md`, paso 4.
3. **Comprobar lo publicado**: `Anim.download(id)` + `Anim.show` y compara con la tira aprobada. Un
   id con otro dueño falla al bajarlo.
4. **Enlazar**: pega el id en `src/shared/Data/MonkeyAnimations.luau` (`Default` u `Overrides`) o
   en `src/shared/Data/WeaponAnimations.luau`. Si cambias código (`WeaponAnimationBuilder`,
   `PetModels`), `stylua src` y `selene src` sin errores.
5. **La fuente queda en git**: el spec final de un mono o un jefe va en
   `src/island/tools/MonkeyAnimationSpecs/<lote>.luau` (un módulo por lote; la clave es el nombre de
   la animación) y `MonkeyAnimationBuilder.build("<lote>")` lo deja en `RBX_ANIMSAVES.<lote>`. El
   texto de `Anim.dump` se pega tal cual (ver el formato arriba). Las armas viven en
   `WeaponAnimationBuilder`. Sin esto, la próxima vez habrá que reconstruirla bajándola del id.
6. **Deja la tira montada para que el usuario la apruebe**, con la cámara de Studio apuntando a ella
   (`show` ya la deja así). Cuando la apruebe (o pida quitarla), `Anim.clear()` y `_G.Anim = nil`.
7. Recuerda que hay que **guardar el place** si cambió algo fuera de la vista previa
   (RBX_ANIMSAVES, ReplicatedStorage.WeaponAnimations).
8. Resume: qué animación, qué cambió (con ángulos y tiempos), dónde está la fuente, si falta
   publicarla y qué id hay que pegar dónde, y cómo verla en juego: Play y acercarse a un mono, o
   coger el arma.

## Editar una animación existente

1. Busca su id en `Data/MonkeyAnimations` (o `Data/WeaponAnimations`) y bájala:
   ```lua
   local ks = Anim.download("rbxassetid://117189969986819")
   ks.Name = "Attack"
   return Anim.dump(ks) .. "\n\n" .. Anim.show(Anim.monkeyRig("Gorila"), ks)
   ```
2. Mira la tira **antes** de cambiar nada para ver el punto de partida.
3. Copia el texto de `dump` como SPEC, cambia lo mínimo ("ataca más fuerte" es más preparación y
   más recorrido en el golpe, no rehacerla) y monta la nueva al lado de la vieja con
   `keep = true, offset = Vector3.new(0, 0, 30)` para compararlas en una captura.
4. Las armas no se editan así: su fuente es `src/island/tools/WeaponAnimationBuilder.luau` (cambia
   los ángulos allí y genera con su `build()`; ver la referencia §3).

`dump` redondea a centésimas y no guarda las poses de peso 0 (solo dan la jerarquía): reconstruida,
la animación es la misma a efectos prácticos.

## Si algo no cuadra

- **La tira sale en reposo / "no cargó"** → la pista carga de forma asíncrona y `Anim.load` la espera
  hasta 8 s. Si falla con un id publicado, suele ser de otro dueño o no es una animación.
- **"X no es una pieza articulada"** → nombre mal escrito o rig equivocado (los monos usan
  `Right Arm`, el R15 `RightUpperArm`). `Anim.hierarchy(rig)` lista las piezas.
- **`Anim.monkeyRig` sale con el cuerpo viejo de una especie voxel** → el `require` interno de
  MonkeyModels guarda la primera copia de `VoxelSpecs/<Especie>` que cargó en la sesión. Construye el
  rig tú: `MM.voxelSpecs[id] = Anim.freshRequire(spec)`, `MM.build` con `scale = 1`, ponlo en
  Workspace y pásalo a `Anim.placeRig`.
- **La tira enseña la cara normal en un golpe** → las expresiones por acción (`spec.faces`) las cambia
  MonkeyAnimator al sonar la acción, no `Anim.show`. En la tira, pon `Transparency` según el atributo
  `Face` de cada pieza; para comprobar el cambio de verdad, `MonkeyAnimator.attach` + `play` en una
  copia y `animator:StepAnimations`.
- **No veo un cambio del repo** → caché de `require` en Studio: `Anim.freshRequire`, o Rojo
  desconectado (comprueba con `script_grep` una línea nueva).
- **El brazo del jugador tiembla con un arma en la mano** → algo gira la articulación por código
  mientras Roblox reproduce `toolnone`. Las poses del brazo que sujeta un arma tienen que ser
  AnimationTracks (referencia §4).
- **El modelo flota o se hunde en todos los fotogramas** → el `suelo` se mide respecto al reposo:
  si pasa en todos, es la animación de debajo (`under`) o una traslación del `Torso`.
- **`"Tail" no es una pieza articulada del rig`** → los simios (gorila, chimpancé, orangután) y el
  gibón no tienen cola: quítala de sus specs.
- **`screen_capture` da timeout** → ver §3, paso 3: ventana al frente o `Anim.measure`.
- **Probar en Play**: `start_stop_play` y `execute_luau` con `datamodel_type = "Client"` sirven para
  comprobar que una animación carga y suena (`require` del módulo del cliente desde
  `PlayerScripts`). Las teclas de `user_keyboard_input` no llegan si la ventana de Studio no tiene
  el foco (W no mueve al personaje), y un script de prueba no puede lanzar una acción de
  `ContextActionService` (`CallFunction` pide permisos de Roblox): lo que dependa de pulsar una
  tecla lo prueba el usuario. Para la partida al terminar.
- **Una función de un módulo de `ServerStorage.Tools` falla con `attempt to index nil`** → con
  `freshRequire`, el código corre en una copia que ya no tiene padre: toma `script.Parent` al
  cargar el módulo, no dentro de la función.
- **`PlayerAnimationBuilder.build()` da "Requested module experienced an error while loading"** →
  `build()` se vuelve a cargar desde su propio `script`; si lo llamas en una copia que ya has
  destruido (lo que hace `Anim.freshRequire`), esa recarga falla. Clona el módulo, déjalo con padre,
  llama a `require(copia).build({ fresh = true })` y destruye la copia después.
- **Un golpe con arma** (gestos de habilidades del guerrero) no se lee en el maniquí sin arma:
  suéldale una (referencia §3, "Ver el arma en la tira") y mide dónde queda su punta.
- **Las capturas salen teñidas o sin rótulos** → los `BillboardGui` no salen en `screen_capture`;
  los rótulos de `show` son `SurfaceGui` sobre una pieza por eso.
