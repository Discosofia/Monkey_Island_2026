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
  Otras ayudas de `PetModels`: `capsule(..., material?)` (sin material es `Fabric`: una rana con
  patas de tela parece de peluche), `surfacePoint(frame, semi, direction)` (punto de un óvalo y su
  normal, para pegar placas, manchas y escamas), `blotch` (mancha de dos tonos), `feather`,
  `featheredWing`, `tailFan`, `birdEye` (aves), `cat` (felinos) y la forma `"Spike"` para cristales.
  Para medir un tamaño de cabeza o de casco sin rehacer números, mide todo lo que va en ella desde
  su centro con un factor (`onHead(offset)` y `hk` en el Mono X-7).
  **Articulación encadenada** (rodilla, codo): registra el tramo de arriba con `joint` (devuelve la
  articulación) y el de abajo con `joint(..., bias, parent)` y bisagra en la rodilla. Para que se
  doble hacia atrás solo mientras la pata avanza en el aire: `amplitude` y `bias` negativos e iguales
  (-0,3) y `phase` = la de la pata + π/2.
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
- **Rasgos sobre una cabeza esférica** (monos con cola de `MonkeyModels`): un óvalo plano delante
  de la cabeza se despega por los bordes y parece un plato o una visera. `headPatch` lo coloca en la
  dirección de la normal y por dentro es un óvalo hondo hundido en la cabeza (size.Z = lo que
  sobresale): cara, cejas, rayas, crestas. Para gorros y coronillas, `hairCap`: una bola algo menor
  que la cabeza desplazada hacia arriba asoma solo por ese lado y sigue su forma (un óvalo encima
  parece una boina). Los ojos (`sphereEyes`) llevan `out` = lo que sobresale la cara, o quedan
  enterrados debajo de ella.
- **Extremidades y colas por tramos** (`capsule`): cada óvalo sobresale 0,6 × su ancho por cada
  punta. Con menos solape, las articulaciones se estrechan y parecen cuentas de un collar.
- **Signo de las inclinaciones:** `CFrame.Angles(math.rad(a), 0, 0)` con `a` positivo lleva la parte de
  arriba de la pieza hacia +Z (atrás) y la de abajo hacia -Z (delante). Una barba, un flequillo o
  una pluma que debe apuntar hacia abajo y adelante va con ángulo **positivo**. Con el signo al
  revés, la pieza queda como un disco plano despegado de la cara.
- **Abanicos y arcos** (tocados de plumas, cuentas en una banda, collares en U): reparte las piezas
  con un bucle sobre un ángulo o un parámetro `t` en vez de colocarlas a mano, y deja el número de
  piezas en una variable (`local count = 9`), porque es lo primero que hay que recortar si te pasas
  del presupuesto.
- **Pegar cosas a un óvalo largo** (rosetas en un felino de 2 studs de largo): `surfacePoint` con una
  *dirección* como `(1, y, z)` aplasta todo hacia el centro y las manchas se amontonan en un parche.
  Pasa el *punto* que quieres (x calculada para que quede en la superficie a esa y y z) y deja que lo
  proyecte. Las ancas y paletillas tapan el cuerpo: lo que va ahí se pega a su propio óvalo.
- **Parches en una cabeza redonda** (piel del ojo, mejillas): un óvalo plano se despega por los
  bordes y parece una moneda. Hazlo hondo (size.Z ≈ 0,2) y hundido, como `headPatch` de los monos.
  Dos parches concéntricos de colores distintos parecen una diana: solápalos desplazados.
- **Rayas largas sobre un lomo curvo:** un óvalo recto de 1,2 studs flota sobre los extremos. Hazla a
  trozos cortos, cada uno en su punto de la superficie.
- **Rosetas de felino:** contorno negro con el centro tostado oscuro y grande (74 % × 60 %); con el
  centro claro y pequeño parecen donuts.
- **Ojos de ave** (`birdEye`): anillo de piel, ojo, pupila, dos brillos y párpado. Mide la pupila y
  los brillos desde el centro del ojo y déjalos fuera de su bola, o se entierran y el ojo sale sin
  pupila. El párpado del color de la piel le da expresión. En una rana, un párpado encima del ojo
  parece un gorro: sobra.
- **Alas de plumas sueltas:** remeras anchas (26 % del largo del ala) y muy solapadas, o parecen una
  mano con dedos. Por capas (brazo liso, escamas pequeñas, cobertoras mayores, álula, remeras con
  su cañón claro) se lee como un ala de verdad; las cobertoras como óvalos grandes parecen tortitas.
- **Patas de felino:** un óvalo por pata parece un palillo. Dos tramos con músculo (tríceps, muslo,
  gemelo) y el corvejón hacia atrás en las de detrás.
- **Uñas y dedos** de patas gordas (tortuga): a un 28 % del ancho del pie; más grandes parecen bolas.

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

Cuando el usuario pide "texturas", se hacen con materiales (no con imágenes subidas):
- `Fabric`: pelo y plumas.
- `Wood` en placas verdes (el caparazón de la tortuga): la veta parece los anillos de crecimiento.
- `Glacier` con `Transparency` 0,15 para un animal de cristal o hielo: tiene facetas. Con `Glass`
  parecía un globo y se veían por dentro todas las piezas solapadas. `Glass` sí va bien en cristales
  sueltos (`"Spike"`) con un núcleo `Neon`.
- `Grass` para musgo; `Metal` con `Reflectance` 0,15 para plumas tornasoladas (colibrí);
  `Reflectance` 0,12 en `SmoothPlastic` para piel mojada (rana). Más de 0,3 en un ojo refleja el
  horizonte como una canica.

Para un aura o una nube de energía, un `ParticleEmitter` en el cuerpo se ve mejor que muchas
piezas `Neon` flotando. Lo que aprendimos con el Mono X-7, cuyas chispas no se veían en juego:
- Por defecto salen de **dentro** de la pieza: si es un óvalo tapado por pelo, brazos o casco, se
  quedan escondidas. Usa `Shape = Sphere`, `ShapeStyle = Surface`, `ShapeInOut = Outward` y una
  velocidad que las saque (1,5–2,5 con `Drag` 2).
- Con `LightEmission = 1` y la luz del día salen casi blancas. Con 0,4, `Brightness` 2 y
  `LightInfluence` 0 conservan el color.
- Tamaño de unos 0,5 × `rig.scale` en su punto más alto, unas 14 por segundo y `ZOffset` 1.
- En modo edición no se simulan solas: para verlas en una captura, llama a `emitter:Emit(20)` en
  el mismo `execute_luau` que monta la vista previa.

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

En los monos, el tamaño de `Preview.show` incluye además la raíz invisible (`HumanoidRootPart`, que
llega a 2,9 × `scale` del suelo): en los monos bajos (el Tití, el Capuchino) es la raíz y no el
cuerpo lo que marca el alto. Sácala igual que los adornos antes de medir.

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
fotograma (`UI/PetFollowers`) y recoloca las piezas registradas con `joint`. `PetModels.animate`
las mueve todas juntas con `workspace:BulkMoveTo` (1,5 µs por pieza frente a 3,7 µs una a una):
con eso caben unas 110 articuladas por mascota (un ave con alas de plumas sueltas) y las 10
mascotas a la vez se animan en ~1,4 ms por fotograma en un PC. No pases de ahí; lo que no se mueve
va como detalle fijo. Una articulación encadenada (rodilla, codo) se registra con
`joint(..., parent)` pasando la articulación de arriba.

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
