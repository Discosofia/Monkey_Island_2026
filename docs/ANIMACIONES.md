# Animaciones de los monos

Los monos y los jefes son un rig articulado con **Motor6D** (`src/island/server/Monkeys/MonkeyModels.luau`). Las animaciones se crean en Studio con el **Animation Editor** y el servidor las reproduce (`Monkeys/MonkeyAnimator.luau`). Las que aún no existen simplemente no se reproducen: el juego funciona igual sin ellas.

## Piezas del rig

Las animaciones se enlazan por el **nombre de las piezas**. No los cambies o habrá que rehacer las animaciones.

| Articulación (Motor6D) | De → a | Gira sobre |
| --- | --- | --- |
| `RootJoint` | `HumanoidRootPart` → `Torso` | el centro del cuerpo |
| `Neck` | `Torso` → `Head` | la base del cuello |
| `Right Shoulder` / `Left Shoulder` | `Torso` → `Right Arm` / `Left Arm` | el hombro |
| `Right Hip` / `Left Hip` | `Torso` → `Right Leg` / `Left Leg` | la cadera |
| `TailJoint` | `Torso` → `Tail` | la base de la cola |

Las demás piezas (cara, ojos, orejas, manos, pies, punta de la cola…) van soldadas a una de estas y se mueven con ella.

Girar una articulación en **X** la balancea adelante/atrás, en **Y** la gira a los lados y en **Z** la inclina de costado (con los ejes del modelo, sea cual sea la forma de la pieza).

### Modelos por especie

Cada especie tiene su propio modelo (constructores `BUILDERS` en `MonkeyModels.luau`); solo una especie nueva sin constructor usaría el **genérico** (cuerpo encorvado y erguido).

- **A cuatro patas, con cola** (los brazos son las patas delanteras): `MonoArdilla`, `AulladorRojo`, `CapuchinoLadron`, `Marimonda`, `Titi`, `Marteja`, `Mandril` (cola cortita), `Macaco`, `Babuino` y `ColaLarga`.
- **Simios sin cola** apoyados en los nudillos: `Gorila`, `Chimpance` y `Orangutan`. Las animaciones que mueven `Tail` simplemente no les afectan. Los jefes usan estos modelos con sus colores y sus detalles propios (`BOSS_EXTRAS`: musgo, plumas y pinturas, cristales, grietas de lava).
- **Gibón**: simio sin cola que anda **erguido** con los brazos en alto.

Todos los modelos tienen las mismas piezas animables, así que una animación sirve para todos. Si una especie necesita una distinta (p. ej. un andar a cuatro patas solo para ella), ponla en `Overrides` con el id de esa especie.

## Paso 1: poner un mono en Studio para animarlo

1. Abre el place de la **Isla** con `rojo serve island.project.json` conectado, en modo edición (sin darle a Play).
2. Copia **solo la línea de código** de abajo (sin las marcas ```` ``` ````), pégala en la **barra de comandos** (Vista → Barra de comandos) y pulsa Ejecutar:

```
local Monkeys = require(game.ReplicatedStorage.Shared.Data.Monkeys); local MonkeyModels = require(game.ServerScriptService.Server.Monkeys.MonkeyModels); local especie = "AulladorRojo"; local look = table.clone(Monkeys[especie]); look.scale = 1; local cam = workspace.CurrentCamera.CFrame; local rig = MonkeyModels.build(especie, look, cam.Position + cam.LookVector * 15 - Vector3.new(0, 2, 0)); rig.Name = "RigMono"; rig.PrimaryPart.Anchored = true; rig.Parent = workspace; game.Selection:Set({ rig })
```

Aparece `RigMono` delante de la cámara, ya seleccionado y a **escala 1** (anima siempre con esta escala). Para animar sobre otro modelo, cambia el nombre de la especie al principio de la línea (p. ej. `"MonoArdilla"`, `"Gorila"` o `"Gibon"`). Conviene revisar cada animación nueva en un mono a cuatro patas, en un simio y en el gibón. Si no lo ves, búscalo en el Explorador y pulsa **F**; si no está, mira los errores en la ventana **Salida**.

## Paso 2: abrir el editor

1. Con `RigMono` seleccionado, pestaña **Avatar** → **Editor de clips** (icono `<◇>`).
   > ⚠️ El botón **Animación…** de esa misma pestaña **no** es el editor: abre *Reasignar rig*. Ciérralo sin pulsar *Crear*.
2. Abajo se abre el **Editor de animación** con un clip vacío ("Clip de animación") de 0 a 1 s. No hay que crear nada más.
3. Pulsa el **⊕** a la derecha de `RigMono` (lista de la izquierda) → **Añadir todo**: aparecen `Torso`, `Head`, `Right Arm`, `Left Arm`, `Right Leg`, `Left Leg` y `Tail`.
4. Ajusta la duración en las casillas `0 / 1` junto a los botones de reproducción (p. ej. `0.8` para andar).

Para una animación nueva más adelante: **⋯** (junto al nombre del clip) → **Nueva**.

## Paso 3: animar

1. Pon la línea azul en un momento (clic en la regla de tiempo de arriba).
2. Haz clic en una pieza del mono en la vista 3D y gírala con los anillos (si salen flechas, **Ctrl+2**). Cada giro deja un rombo (fotograma clave).
3. Repite en otros momentos. Para que un bucle no dé saltos, copia los rombos del inicio (recuadro + **Ctrl+C**) y pégalos al final (**Ctrl+V**).
4. Activa el **bucle** (botón **⟲**) en las que lo necesiten y pulsa **▶** para verla.

Consejos:
- Usa sobre todo **rotaciones**. Cada especie y cada jefe tiene un tamaño distinto (de 0.45 a 3.2), y los desplazamientos en studs no se escalan: se verían exagerados en los monos pequeños y cortos en los jefes.
- No toques `HumanoidRootPart`.
- Las de andar, correr y estar quieto deben ser en **bucle**. Las demás, de una vez y cortas (0.3 a 0.8 s), porque se lanzan en el momento del golpe.

Ejemplo, **Walk** (0.8 s, en bucle):

| Momento | Pose |
| --- | --- |
| 0 | `Right Arm` adelante 30°, `Left Arm` atrás 30°, `Right Leg` atrás 25°, `Left Leg` adelante 25°, `Tail` a un lado |
| 0.4 | Lo contrario (cola al otro lado); un poco de balanceo de `Head` o `Torso` (5–10°) |
| 0.8 | Copia de la pose de 0 |

### Recetas para cada acción

Reglas generales:

- **Las acciones solo cambian las piezas que animas.** Si `Attack` solo mueve el brazo derecho y la cabeza, las piernas siguen andando debajo. Pon fotogramas clave solo en lo que debe moverse.
- Las acciones **empiezan y terminan en la pose de reposo** (sin girar nada), salvo `Death`.
- El golpe suena **en cuanto empieza** la animación, así que el momento fuerte (zarpazo, lanzamiento, golpe) debe llegar pronto: 0.15–0.25 s.
- Bucle **solo** en `Idle`, `Walk` y `Run`.
- **El `Torso` mueve el mono entero**: todo cuelga de él. Si lo inclinas, **compensa las piernas** con el giro contrario (Torso X 10° → cada pierna X −10°) para que los pies sigan en el suelo. En `Death` no hace falta: ahí se cae entero.
- "Brazo adelante" en un mono a cuatro patas es adelantar la pata delantera; en el gibón, con los brazos en alto, es echarlos hacia delante. La misma animación sirve para todos.

| Acción | Duración | Bucle | Poses (momento → pose) | Quién la usa |
| --- | --- | --- | --- | --- |
| `Idle` | 2.5 s | Sí | 0 → reposo · 0.8 → `Head` mira a un lado (Y 15°), brazos un poco adelante (X 4°, como respirar), `Tail` se mece (Y 10°) · 1.6 → `Head` al otro lado (Y −15°), brazos a 0, `Tail` (Y −10°) · 2.5 → copia de 0. Sin tocar el `Torso` | Todos |
| `Attack` | 0.4 s | No | 0 → reposo · 0.12 → `Right Arm` atrás 40°, `Head` atrás 10° · 0.22 → `Right Arm` adelante 80°, `Head` y `Torso` adelante 10° · 0.4 → reposo | Todos (mordisco, golpe del jefe, golpes al Basecamp) |
| `Hurt` | 0.3 s | No | 0 → reposo · 0.08 → `Head` atrás 15°, `Torso` atrás 8°, brazos un poco abiertos (Z ±15°) · 0.3 → reposo | Todos |
| `Death` | 2 s | No | 0 → reposo · 0.3 → `Torso` se ladea (Z 30°), `Head` cae (X 25°) · 0.7 → `Torso` tumbado (Z 80°), brazos y piernas sueltos, `Tail` caída · 2 → **copia de 0.7** (se queda tumbado mientras se desvanece) | Todos |
| `Run` | 0.5 s | Sí | Como `Walk` pero más amplio: brazos ±50°, piernas ±45°, `Torso` adelante 10° (piernas compensadas), `Tail` más alta. 0 / 0.25 / 0.5 (copia de 0) | Todos (opcional: sin ella se usa `Walk` acelerada) |
| `Pounce` | 0.6 s | No | 0 → reposo · 0.12 → se agacha: `Torso` adelante 15°, piernas adelante 20° · 0.25 → se estira: los dos brazos adelante 90°, piernas atrás 40°, `Head` arriba 10° · 0.45 → igual · 0.6 → reposo | Marimonda, gibón; embestida del jefe |
| `Roar` | 1 s | No | 0 → reposo · 0.2 → `Head` arriba 25°, `Torso` atrás 10°, brazos abiertos (Z ±40°) · 0.4 / 0.6 / 0.8 → `Head` tiembla (Y ±8°) · 1 → reposo | Mandril; jefes (al aparecer, al cambiar de fase, al apagar antorchas) |
| `Throw` | 0.6 s | No | 0 → reposo · 0.1 → `Right Arm` atrás por encima de la cabeza (≈ −150°), `Torso` gira (Y 20°) · 0.2 → `Right Arm` adelante 60°, `Torso` gira al otro lado (Y −20°) · 0.6 → reposo | Chimpancé; lluvia de rocas del jefe |
| `Stomp` | 0.6 s | No | 0 → reposo · 0.1 → los dos brazos arriba (X 150°), `Torso` atrás 10° · 0.2 → brazos abajo con fuerza (X 40°), `Torso` adelante 20°, `Head` abajo · 0.6 → reposo | Gorila; onda de choque del jefe |
| `Steal` | 0.5 s | No | 0 → reposo · 0.15 → `Right Arm` adelante 70°, `Head` adelante · 0.3 → `Right Arm` vuelve hacia el pecho (X 20°), `Head` ladeada pícara (Z 15°) · 0.5 → reposo | Capuchino ladrón |
| `Howl` | 1.2 s | No | 0 → reposo · 0.25 → `Head` muy arriba (X 40°), `Torso` atrás 10°, `Tail` arriba · 0.5 / 0.8 → `Head` se balancea (Y ±6°) · 1.2 → reposo | Aullador rojo; el jefe pide refuerzos |

Orden recomendado: `Idle`, `Attack` y `Hurt` primero (se ven en todos los monos), luego `Run` y, al final, las especiales.

## Paso 4: guardar, publicar y sacar el ID

1. **⋯** → **Guardar como** con el nombre de la acción (`Walk`, `Idle`…).
2. **⋯** → **Publicar en Roblox**. Como dueño, elige el **mismo que es dueño del juego** (tu cuenta o el grupo); si no, Roblox no deja reproducirla.
3. Studio no siempre muestra el ID al publicar. Para encontrarlo:
   - **Gestor de recursos** → sube con **‹** al nivel principal → carpeta **Animaciones** → clic derecho sobre la animación → **Copiar ID de recurso**; o
   - **Caja de herramientas** → **Inventario** → **Animaciones** → clic derecho → **Copiar ID de recurso**; o
   - create.roblox.com → **Creaciones** → **Artículos de desarrollo** → **Animaciones**: el número de la dirección de la página.

## Paso 5: conectarla al juego

Pega el ID en `src/shared/Data/MonkeyAnimations.luau`:

```lua
Default = {
	Idle = "rbxassetid://1234567890",
	Walk = "rbxassetid://1234567891",
	...
```

- `Default` vale para todos los monos y jefes.
- `Overrides` cambia una animación solo para una especie (id de `Data/Monkeys`) o un jefe (id de `Data/Bosses`). Ejemplo: `GorilaAlbino = { Walk = "rbxassetid://…" }`.

| Acción | Cuándo suena |
| --- | --- |
| `Idle` / `Walk` / `Run` | Solas, según la velocidad (`RunThreshold`). Sin `Run`, se usa `Walk` más rápido. |
| `Attack` | Mordisco, golpe del jefe, golpes a piezas del Basecamp, agarre del jefe |
| `Pounce` | Salto sobre la presa; embestida del jefe |
| `Roar` | Rugido del mandril; al aparecer y al cambiar de fase el jefe; rugido que apaga antorchas |
| `Throw` | Piedra del chimpancé; lluvia de rocas del jefe |
| `Stomp` | Golpe en el pecho del gorila; onda del jefe |
| `Steal` | El capuchino roba |
| `Howl` | El aullador llama a la tropa; el jefe pide refuerzos |
| `Hurt` | Al recibir un golpe |
| `Death` | Sin uso: los monos derrotados desaparecen con un "¡puf!" (Combat/Poof) para que la violencia sea de caricatura |

Para probarla: **Probar** (▶) y acércate a un mono. Si no se mueve, mira la ventana **Salida**: un aviso tipo *Failed to load animation* suele significar que se publicó con otro dueño que el del juego.

`RigMono` no afecta al juego: puedes dejarlo mientras animas y borrarlo al terminar.
