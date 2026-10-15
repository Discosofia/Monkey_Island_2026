# Estilo de los modelos de Primal Banana Island

Lee esto antes de escribir o cambiar un constructor de modelos del repo. Resume cómo están hechos los
que ya existen para que lo nuevo no desentone ni rompa a quien los usa.

## Índice

1. Dónde vive cada tipo de modelo
2. Ejes y pivotes
3. Piezas y trucos con primitivas
4. Paleta y materiales
5. Escala
6. Rendimiento
7. Modelos que viven en el place, no en el repo

## 1. Dónde vive cada tipo de modelo

Casi todo lo que se ve en el juego se construye **por código** con piezas simples. Un modelo nuevo de un
tipo que ya existe va en su módulo, con un constructor más y su entrada en los datos.

| Qué | Módulo | Punto de entrada | Datos que lo enlazan |
|---|---|---|---|
| Armas y herramientas (Tool) | `src/shared/WeaponTools.luau` | `WeaponTools.build(weaponId)` | `src/shared/Data/Weapons.luau` |
| Armaduras puestas | `src/island/server/Combat/ArmorModels.luau` | `ArmorModels.wear(character, armorId)` | `src/shared/Data/Armor.luau` |
| Mascotas | `src/shared/PetModels.luau` | `PetModels.build(petId)` | `src/shared/Data/Pets.luau` |
| Monos y jefes (articulados) | `src/island/server/Monkeys/MonkeyModels.luau` | `MonkeyModels.build(...)` | `src/shared/Data/Monkeys.luau`, `Bosses.luau` |
| Árboles, palmeras, rocas, matas | `src/serverShared/NodeModels.luau` | `NodeModels.build(nodeType, ground, rng)` | `src/shared/Data/ResourceNodes.luau` |
| Piezas construibles | `src/shared/BuildModels.luau` | `BuildModels.build(buildableId)` | `src/shared/Data/Buildables.luau` |
| Escenario del Lobby | `src/lobby/server/World/LobbyBuilder.luau` | `LobbyBuilder.build()` | — |
| Isla generada (terreno + decorado) | `src/island/tools/MapBuilder.luau` | `MapBuilder.build()` | — |

Antes de escribir, abre el módulo de destino y copia su forma de trabajar: sus funciones de ayuda
(`newPart`, `make.block`, `piece`, `limb`…), sus constantes de color y cómo nombra las piezas. No
crees otro sistema de ayuda en paralelo dentro del mismo módulo.

Las rutas en Studio (con Rojo conectado) siguen `island.project.json` / `lobby.project.json`:
`src/shared` → `ReplicatedStorage.Shared`, `src/serverShared` → `ServerScriptService.ServerShared`,
`src/island/server` → `ServerScriptService.Server`, `src/island/tools` → `ServerStorage.Tools`.
Por ejemplo, PetModels es `ReplicatedStorage.Shared.PetModels` y ArmorModels es
`ServerScriptService.Server.Combat.ArmorModels`.

## 2. Ejes y pivotes

El frente de casi todo mira hacia **-Z**. Respeta las reglas de cada módulo, porque el código que usa
el modelo depende de ellas (las animaciones, el agarre, la colocación en el suelo):

- **Armas (WeaponTools):** respecto a la pieza `Handle`, +Y va de la mano hacia la punta y -Z es hacia
  donde golpea (el filo). `tool.Grip` marca dónde va la mano. El `Handle` suele ser invisible.
- **Armaduras (ArmorModels):** todo soldado al torso (`UpperTorso` en R15, `Torso` en R6) y ajustado a su
  tamaño. -Z es el pecho, +Z la espalda, +Y los hombros. Piezas `Massless`, sin colisión.
- **Mascotas (PetModels):** alrededor de una pieza invisible `Root` (pivote), -Z hacia delante. Las partes
  que se mueven (alas, patas, cola) se registran con `joint(...)`. Atributos `Motion` y `Height`.
  Para una extremidad con varias piezas (brazo, codo, mano, nudillos, una calva cosida encima),
  junta todas en una lista y registra cada una con la **misma bisagra**: así se mueven como una
  sola. `capsule(rig, name, from, to, width, color)` hace un óvalo de pelo entre dos puntos (brazos,
  muslos) y `UPRIGHT` pone de pie un cilindro. `PetModels` lee `Data.Pets` con un `require`
  normal, que en Studio queda en caché: para ver en la vista previa un `color` o un `size` nuevos,
  cámbialos también en la tabla en caché (`require(game.ReplicatedStorage.Shared.Data.Pets).MonoX7.size = 1.15`)
  antes de llamar a `freshRequire` sobre `PetModels`.
- **Monos (MonkeyModels):** articulados (RootJoint, Neck, Shoulders, Hips, TailJoint). Las animaciones se
  enlazan por el **nombre** de las piezas: no renombres piezas animables. Las piezas decorativas
  (cara, barba, pelo, adornos) se pueden renombrar o quitar, pero antes comprueba con grep que nadie
  las busca por nombre. Posiciones respecto a la raíz y a escala 1, con el suelo en `GROUND = -1.9`.
  Los jefes reutilizan el constructor de su especie: lo que solo debe tener el jefe va detrás de
  `if rig.boss` (más pelo, nudillos) o en `BOSS_EXTRAS[bossId]` (adornos propios: tocados, collares).
  Un mismo cuerpo sirve a especies y jefes de colores muy distintos si los tonos secundarios salen
  de `bodyColor`/`faceColor` con `Lerp` (el pecho del gorila es `fur:Lerp(skin, 0.4)`) en vez de
  ser constantes. Si un jefe necesita otro tono, recolorea esa pieza por nombre en su `BOSS_EXTRAS`.
  **Al cambiar el cuerpo de una especie, revisa todos sus jefes:** los adornos de `BOSS_EXTRAS`
  van en coordenadas fijas sobre la superficie del cuerpo viejo, y si el cuerpo crece quedan
  enterrados (le pasó a las grietas de lava del Gorila de Ceniza).
  Para verlo en la vista previa, construye el jefe como lo hace `BossService`:

  ```lua
  local MM = Preview.freshRequire("ServerScriptService.Server.Monkeys.MonkeyModels")
  local Monkeys = Preview.freshRequire("ReplicatedStorage.Shared.Data.Monkeys")
  local Bosses = Preview.freshRequire("ReplicatedStorage.Shared.Data.Bosses")
  local boss = Bosses.ChimpanceCaudillo
  local look = table.clone(Monkeys[boss.baseSpecies])
  look.name, look.scale = boss.name, boss.scale
  look.bodyColor, look.faceColor = boss.bodyColor, boss.faceColor
  return Preview.show(MM.build(boss.baseSpecies, look, Vector3.zero, "ChimpanceCaudillo"))
  ```
- **Construibles (BuildModels):** pieza invisible `Bounds` del tamaño de la pieza; es la `PrimaryPart` y el
  centro, así que se colocan con `PivotTo`.
- **Nodos (NodeModels):** se construyen sobre un punto del suelo (`ground`) y crecen hacia +Y.

## 3. Piezas y trucos con primitivas

- Los **cilindros** de Roblox tienen el eje en **X**. Para ponerlos de pie: `CFrame.Angles(0, 0, math.rad(90))`
  (en el repo se llama `UPRIGHT` o `ALONG_Y`). Mirando al frente (discos): `CFrame.Angles(0, math.rad(90), 0)`.
- Las **Ball** solo son esferas. Para un **elipsoide** (copas, frutos, barrigas): `Part` + `SpecialMesh`
  con `MeshType = Sphere` y la `Size` que quieras (`newEllipsoid` en NodeModels, forma "Oval" en PetModels).
- **Púas, colmillos, orejas puntiagudas:** dos `WedgePart` espalda con espalda (`spike` en ArmorModels).
- **Cristales y puntas en una sola pieza:** `CornerWedgePart` (forma `"Spike"` de `piece` en
  MonkeyModels), alargada en Y y orientada con
  `CFrame.lookAt(c, c + dir) * CFrame.Angles(-math.pi / 2, 0, 0)` para que su Y siga a `dir`. Se ve
  en punta desde cualquier lado. Una `WedgePart` sola parece una tabla plana, y una pirámide fina
  parece una espina: dale una base ancha (ancho ≈ 40 % del largo). Para cristales, `Glass` con
  `Transparency` 0,3; `Neon` solo en el núcleo que brilla. Colocarlos con una función
  `crystal(anchor, from, to, length, width)` deja cada cristal en una línea; con una tabla de
  campos, stylua parte cada entrada en siete líneas.
- **Caras con expresión:** para una cara de **furia**, cejas finas (alto ≈ 0,18) giradas unos 0,6 rad
  en Z con `side` (el lado de dentro más bajo, en V), ojos como óvalos aplastados con la misma
  inclinación, y boca abierta oscura con colmillos (`Spike` girada `math.pi` en X para que apunte
  abajo). Unas cejas gruesas y redondas, aunque estén inclinadas, dan cara de **preocupado**. No
  pongas bolitas negras cerca de los ojos (orificios de la nariz): se leen como un segundo par de
  ojos.
- **Casco con la cara al aire** (escafandras, cascos de buzo): una `Ball` para el casco, un disco
  (`Cylinder` mirando a -Z) algo más ancho que la abertura para el aro, y delante un óvalo de pelo y
  el óvalo de la cara asomando por delante del disco. Comprueba que el pelo sobresale del disco
  en todo el borde: si quedan en el mismo plano, hay z-fighting. Remaches del aro con un bucle de
  ángulos.
  **Visor de espejo** (cara oculta, como el Mono X-7): en lugar de pelo y cara, una cúpula
  (`Oval`) que sobresale del aro, color oscuro azulado (25, 35, 55) con `Reflectance` 0,6: refleja
  el cielo y queda como un cromado de dibujo. Añade uno o dos brillos blancos pegados a la cúpula
  (punto de la superficie del elipsoide y su normal, girados en diagonal). Un visor dorado de
  astronauta (200, 150, 60) con reflejo salió blanquecino y verdoso, peor que el oscuro.
- **Placas y letreros sobre una esfera** (`SurfaceGui` en una pieza `Block` puesta con
  `CFrame.lookAt(centro + normal * radio, ...)`): no los pongas encima de una cresta u otra pieza
  que cruce la esfera, porque la atraviesa y tapa el texto. Llévalos a un lado de la cresta.
- **Tubos anillados** (mangueras, cables gruesos): bolas en una curva de Bézier cuadrática
  (`from:Lerp(control, t):Lerp(control:Lerp(to, t), t)`), alternando una gruesa y otra fina de
  otro tono. Unas 14 por tubo bastan para que se lea como una manguera.
- **Óxido y manchas sobre metal:** óvalos todos del mismo tamaño parecen lunares (o una vaca).
  Haz cada mancha con dos óvalos solapados de dos tonos, girados y de tamaños distintos.
- **Calvas, cicatrices y costuras de caricatura:** un óvalo rosado con 2–3 puntadas finas oscuras
  que lo cruzan y una a lo largo. Si va en una extremidad que se mueve, añade sus piezas a la
  lista de la extremidad para que se muevan con ella.
- **Ramas, troncos y cadenas:** encadena tramos de cilindro; cada tramo devuelve el marco de su extremo
  (`limb` en NodeModels).
- **Simetría:** usa `for side = -1, 1, 2 do ... end` y multiplica X por `side`. Ahorra la mitad del código
  y evita que un lado quede distinto del otro.
- **Superficies:** `TopSurface`/`BottomSurface` = `Smooth`.
- Evita `UnionOperation` (CSG) en modelos hechos por código: es lento al crearlo y no se puede ajustar
  con un número. Mejor varias piezas solapadas.
- Las piezas se pueden solapar sin miedo; lo que se nota son las **rendijas** entre piezas que deberían
  tocarse y el **z-fighting** (dos caras en el mismo plano con colores distintos, parpadean). Separa
  esas caras al menos 0,02–0,05 studs o haz una un poco más grande.
- **Signo de las inclinaciones:** `CFrame.Angles(math.rad(a), 0, 0)` con `a` positivo lleva la parte de
  arriba de la pieza hacia +Z (atrás) y la de abajo hacia -Z (delante). Una barba, un flequillo o
  una pluma que debe apuntar hacia abajo y adelante va con ángulo **positivo**. Con el signo al
  revés, la pieza queda como un disco plano despegado de la cara.
- **Abanicos y arcos** (tocados de plumas, cuentas en una banda, collares en U): reparte las piezas
  con un bucle sobre un ángulo o un parámetro `t` en vez de colocarlas a mano, y deja el número de
  piezas en una variable (`local count = 9`), porque es lo primero que hay que recortar si te pasas
  del presupuesto.

## 4. Paleta y materiales

Estilo de isla tropical de caricatura, low-poly, colores saturados pero no chillones. Los colores
van como constantes con nombre al principio del módulo (`local BARK = Color3.fromRGB(110, 75, 45)`).
Reutiliza las que ya existan antes de inventar otras casi iguales. Ejemplos del repo:

| Nombre | RGB | Uso |
|---|---|---|
| WOOD | 110, 72, 40 | madera de mangos |
| LIGHT_WOOD | 175, 130, 80 | madera clara |
| BARK | 110, 75, 45 | troncos |
| LEAF (varios) | 45, 120, 55 / 60, 140, 60 / 35, 100, 45 | hojas |
| FIBER | 150, 135, 85 | cuerdas, cordones |
| LEATHER | 60–70, 40–47, 25–30 | cuero |
| FUR | 150, 70, 45 | pelaje rojizo |
| GOLDEN_FUR | 235, 190, 80 | pelaje dorado |
| BONE | 230, 220, 195 | hueso |
| STONE | 120, 120, 125 | piedra |
| SILVER | 200, 205, 215 | plata |

Materiales habituales: `SmoothPlastic` (por defecto), `Fabric` (pelaje, telas), `Wood` / `WoodPlanks`,
`Slate` / `Rock` (piedra), `Grass`, `Sand`, `Metal`, `Neon` solo para brillos (ojos que brillan,
magia). Un modelo con 3–6 colores se lee mejor que uno con quince. Para el pelo, `Fabric` da
un aspecto de peluche que encaja con el estilo cartoon (el Mono X-7).

Para un aura o una nube de energía, un `ParticleEmitter` pequeño en el cuerpo (unas 6 por segundo,
`LightEmission = 1`, tamaño escalado con el modelo) se ve mejor que muchas piezas `Neon`
flotando. En las capturas del X-7 en modo edición no se distinguían: compruébalo en Play.

Una `PointLight` con mucho alcance (más de ~20 studs ya escalada) tiñe todo el modelo y el suelo
de su color: para un brillo rojo en el pecho, alcance 6 y brillo 1 a escala 1 bastan.

**Con la luz de Studio los tonos claros se ven más claros** de lo que parecen en el RGB. Una piel
de 190, 160, 135 sale casi blanca en la captura. Para una piel marrón rosada como la de un
chimpancé, ve a valores de 165, 125, 105. Compara siempre la captura con la referencia, no el número.

## 5. Escala

1 stud ≈ 28 cm. Referencias para no fallar el tamaño:

| Cosa | Studs |
|---|---|
| Personaje R15 por defecto | ~5 de alto, 2 de ancho, 1 de fondo |
| Puerta | 7 de alto, 4 de ancho |
| Pared de una planta | 10–12 de alto |
| Arma de una mano | 3–4 de largo |
| Mascota | 2–4,5 de alto con adornos (el Mono X-7 mide 3,9 con la antena) |
| Mono de categoría 1 / 2 / 3 | 1,3–3 / 2,4–4 / 3,4–5,5 de alto |
| Jefe | 9–11 de alto (unos dos personajes) |
| Árbol de la isla | 15–35 de alto |
| Radio de la isla | 950 |

El maniquí azul de `vista_previa.luau` mide 2 x 5 x 1: compáralo en las capturas.

Los monos y los jefes tienen un tamaño estándar por categoría, con sus excepciones, en
`docs/GDD.md` §8.2 "Tamaño estándar de monos y jefes". Mide un mono construido con su `scale` de
`Data/Monkeys` o `Data/Bosses` (no a escala 1) y, si se sale de la franja, ajusta `scale` antes
que el modelo.

Si el cuerpo de una especie crece, crece también su jefe y puede salirse de la franja: vuelve a
medir la especie y todos sus jefes, y ajusta su `scale`. Un jefe más grande también necesita más
`attackRange` en `Data/Bosses`, porque se mide de raíz a raíz y la cara queda más lejos de la raíz
(la cara del gorila está a unos 2,8 × `scale` studs). Si el usuario pide un jefe más grande que la
franja a propósito, apúntalo en las excepciones del GDD.

El tamaño que devuelve `Preview.show` incluye los adornos. Un tocado de plumas sube al Chimpancé
Caudillo de 8,5 a 11,5 studs. Mide también el cuerpo sin los adornos: saca un momento esas piezas del
modelo (`part.Parent = nil`), mide con `GetBoundingBox()` y vuelve a meterlas. Sumar las esquinas de
cada pieza da de más con los óvalos girados. Si el modelo se pasa de alto solo por un adorno,
apúntalo en la lista de "Se pasan de alto a propósito" del GDD. Cuando cambies el alto de una
especie, actualiza también la columna "Ahora" de esa tabla.

## 6. Rendimiento

La isla se juega en móviles de gama baja con *streaming* (ver `docs/RENDIMIENTO.md`). Presupuesto
orientativo de piezas por modelo:

| Tipo | Piezas |
|---|---|
| Nodo que se repite mucho (árbol, roca, mata) | 10–25 |
| Arma, armadura | 15–40 |
| Mascota (solo una por jugador) | 80–160 |
| Mono normal (hay muchos a la vez) | 15–30 |
| Jefe (solo hay uno) | hasta 60 |
| Construible | 5–20 |
| Pieza única de decorado (barco, templo) | hasta unos cientos |

Las mascotas tienen un presupuesto alto a propósito: van siempre al lado del jugador, se ven de
cerca y el usuario quiere que el detalle se lea muy definido (remaches, costuras, anillos de un
tubo, nudillos). Aun así, cada cliente mueve todas las mascotas del servidor con `PivotTo` en cada
fotograma (`UI/PetFollowers`), y las piezas registradas con `joint` se recolocan una a una: deja
las articuladas en unas 60 como mucho y gasta el resto en detalle fijo.

Además:
- Lo decorativo (hojas, frutos, detalles, todo lo que no se pisa) va con `CanCollide`, `CanTouch` y
  `CanQuery` en `false`. En las piezas pequeñas, `CastShadow = false`.
- Lo que va soldado a un personaje: `Massless = true` y sin `Anchored`.
- Si un detalle no se ve a 20 studs, sobra.

## 7. Modelos que viven en el place, no en el repo

El mapa, el terreno y los modelos colocados a mano se guardan en el place de Roblox, **no en git**.
- No pongas nada dentro de `Workspace.Mapa` (Isla) ni de `Workspace.Naufragio` (Lobby): los generadores
  los borran y los rehacen. Lo hecho a mano va en `Workspace.Decoracion` u otra carpeta fuera de esas.
- Para que un modelo del place sea un punto de recolección, una mesa de trabajo, etc., se le pone un
  atributo (ver `docs/MAPA.md`), no se toca el código.
- Recuerda al usuario que **guarde y publique** el place: si cierra Studio sin guardar, se pierde.
