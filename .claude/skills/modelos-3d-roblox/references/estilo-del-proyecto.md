# Estilo de los modelos de Primal Banana Islands

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
8. Estilo voxel (bloques grandes)

## 1. Dónde vive cada tipo de modelo

Casi todo lo que se ve en el juego se construye **por código** con piezas simples. Un modelo nuevo de un
tipo que ya existe va en su módulo, con un constructor más y su entrada en los datos.

| Qué | Módulo | Punto de entrada | Datos que lo enlazan |
|---|---|---|---|
| Armas y herramientas (Tool) | `src/shared/WeaponTools.luau` | `WeaponTools.build(weaponId)` | `src/shared/Data/Weapons.luau` |
| Armaduras puestas | `src/island/server/Combat/ArmorModels.luau` | `ArmorModels.wear(character, armorId)` | `src/shared/Data/Armor.luau` |
| Mascotas | `src/shared/PetModels.luau` | `PetModels.build(petId)` | `src/shared/Data/Pets.luau` |
| Monos y jefes (articulados) | `src/island/server/Monkeys/MonkeyModels.luau` | `MonkeyModels.build(...)` | `src/shared/Data/Monkeys.luau`, `Bosses.luau` |
| Monos en estilo voxel | `src/island/server/Monkeys/VoxelSpecs/<Especie>.luau` (datos) | `voxelMonkey` en MonkeyModels (§8) | `VOXEL_SPECS` en MonkeyModels |
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
- **Armaduras (ArmorModels):** cada pieza soldada a la parte del cuerpo que cubre (`body.torso`,
  `body.waist`, `body.upperArm[side]`, `body.lowerArm[side]`, `body.upperLeg[side]`) y medida desde su
  `size`, para que se mueva con ella al andar o golpear y valga para cualquier avatar. En R6 se usa
  el trozo equivalente del brazo, la pierna o el torso. Respecto a cada parte, -Z es el frente,
  +Z la espalda y +Y arriba. Piezas `Massless`, sin colisión. **La espalda es lo que más se ve**
  (la cámara va detrás del jugador): cada armadura lleva ahí su motivo más llamativo (huella de
  mano, calavera con huesos cruzados, cabeza de gorila de ojos rojos), no un panel liso. Nada en la cabeza: chocaría con el
  pelo y los sombreros del avatar. Lo que cuelga por delante de las caderas va en el muslo
  (faldones), no en la cintura, o la pierna lo atraviesa al andar. Para probarla en Studio, crea
  un R15 con `Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"),
  Enum.HumanoidRigType.R15)`, quítale el `BodyColors` (pisa los colores que le pongas) y llama a
  `ArmorModels.wear(rig, id)`. Sus articulaciones son `AnimationConstraint` (sin `C0`), así que
  en edición no se pueden posar.
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
  sobresale): cara, cejas, rayas, crestas. Para gorros y coronillas, una bola algo menor que la
  cabeza desplazada hacia arriba asoma solo por ese lado y sigue su forma (un óvalo encima parece
  una boina; la ayuda `hairCap` se borró con los monos que pasaron a voxel). Los ojos (`sphereEyes`) llevan `out` = lo que sobresale la cara, o quedan
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
- **Colmillos, mechones y flecos** con `fang` (ArmorModels): la punta de una `CornerWedgePart` queda
  sobre una esquina, no en el centro. Girada `math.pi` en Z para que apunte abajo, su base ocupa de
  `at.X - ancho` a `at.X` y de `at.Z - ancho` a `at.Z`: suma medio ancho en X para centrarla y pon
  `at.Z` en la cara de fuera de lo que cuelga, o se queda escondida dentro del peto o la capa.
- **Cejas sobre una cara o un cráneo:** un óvalo oscuro ancho encima de los ojos parece una boina,
  y uno claro que sobresale, la visera de una gorra. Dos cejas finas inclinadas en V (más bajas por
  dentro) tapando un poco el borde de arriba de los ojos dan cara de furia.
- **Nariz de gorila:** un óvalo pequeño con dos orificios juntos en el centro parece un hocico de
  cerdo. Hazla ancha y plana (0,44 × 0,17 del ancho de la cara) con los orificios separados abajo.
- **Emblemas grandes sobre una capa o un peto:** un solo óvalo claro sobre un fondo oscuro parece un
  huevo o un plato. O baja el contraste (dos grises: se lee como brillo del pelo) o conviértelo en
  algo reconocible (una cara, una calavera, una huella de mano).
- **Láminas de una hombrera:** bloques muy inclinados y separados parecen un abanico de tablas;
  óvalos (`Oval`, alto ≈ 0,28) apilados con poco desplazamiento parecen una concha por capas.
- **Mantos y cuellos de pelaje sobre el torso:** un bloque que baja por delante tapa todo lo del
  pecho (placas, medallón). Llévalo hacia la espalda y cierra el borde de delante con un óvalo de
  pelaje bajo la barbilla.

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

**Proporción frente al jugador: 1 m real ≈ 3 studs.** El avatar R15 estándar mide 5,3–5,5 studs de
los pies a la coronilla y representa a una persona de 1,75 m. Úsala para los animales: un gorila
macho a cuatro patas tiene los hombros a ~1,5 m, así que van a ~4,4 studs, a la altura de los del
jugador. Las medidas de `docs/MONOS.md` y `docs/MASCOTAS.md` son de largo del cuerpo (o de alto de
pie en los simios), no la altura a cuatro patas: conviértelas pensando en la postura del juego. (El
"1 stud = 28 cm" de la física de Roblox no sirve para esto: con él, un jugador mediría 1,4 m.)

**Animales voxel: tamaño real con mínimo** (decidido por el usuario; tabla de objetivos en el GDD
§8.2, "Tamaño real con mínimo"):
- Si el tamaño real en studs queda por debajo del umbral, se usa `mínimo + real / 2`. Monos:
  umbral 2,4 y mínimo 1,2. Mascotas: umbral 3 y mínimo 1,5. Así el orden de tamaños se mantiene y
  nada queda diminuto.
- Ajusta `unit` del spec (o `scale` en Data) hasta llegar al alto de la tabla.
- Si el animal acaba distinto de la tabla, actualiza su fila del GDD.

Referencias para no fallar el tamaño:

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
| Arma | 15–40 |
| Armadura (cada rango más detallado que el anterior; hoy 52 / 75 / 101) | 40–105 |
| Mascota (solo una por jugador) | 80–160 |
| Mono normal (hay muchos a la vez) | 15–30 |
| Jefe (solo hay uno) | hasta 60 |
| Mono voxel (§8), bloques de diseño | hasta ~150 (unidos en ≤ 10 piezas en juego); jefe hasta 500 (techo 1.000) |
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

## 8. Estilo voxel (bloques grandes)

Estilo de juguete de bloques o videojuego retro, de resolución media: cajas grandes alineadas a una
rejilla, siluetas en escalones y 3–5 tonos planos. La referencia es el gorila de bloques que pasó el
usuario. El primero fue el Gorila (`VoxelSpecs/Gorila.luau`).
- **Especie:** usa el voxel en cuanto su spec está en `VOXEL_SPECS` de MonkeyModels.
- **Jefes:** siguen con el modelo de antes hasta que se añaden a `VOXEL_BOSSES`, porque cada uno
  necesita sus detalles y adornos en bloques. Para probar uno sin activarlo, en la vista previa:
  `MM.voxelBosses.<bossId> = true`.

**Por qué así y no en Blender:** cada caja es una línea de números, así que iterar es cambiar datos
y no código, y se ve en Studio en la misma llamada. Se conservan el rig, las animaciones y el
recolor de los jefes. Ver la nota sobre Blender en `SKILL.md` §2.

### Formato del spec

Un ModuleScript por especie que devuelve `{ unit, parts }`:

```lua
return {
	unit = 0.18, -- studs por celda a escala 1: cambiarlo escala todo el animal
	parts = {
		{ name = "Torso", joint = "RootJoint", boxes = { ... } }, -- sin pivot: gira sobre la raíz
		{ name = "Head", joint = "Neck", parent = "Torso", pivot = { 0, 13, -8 }, boxes = { ... } },
		{ name = "Arm", joint = "Shoulder", parent = "Torso", mirror = true, pivot = { 7.5, 14, -6 }, boxes = { ... } },
	},
}
```

- Caja: `{ x, y, z, ancho, alto, fondo, tono, nombre?, simétrica? }` en celdas. x y z son el centro
  (frente a -Z), y es el centro **medido desde el suelo** (el constructor suma `GROUND`).
- Todas las cajas de una parte se **unen en una sola pieza** (`mergeBoxes`, con
  `GeometryService:UnionAsync`) con el nombre de siempre (`Torso`, `Head`, `Right Arm`…). Esa pieza
  es la que se articula. Los nombres de las demás cajas solo sirven para leer el spec, salvo los de
  `VOXEL_LOOSE` (`Eye`, que `glowEyes` enciende, y `Chest`/`Pec`, que el Gorila de Ceniza
  recolorea): esas no se unen y van soldadas aparte. Si un jefe nuevo busca otra pieza por nombre,
  añádela a `VOXEL_LOOSE`, o desaparecerá dentro de la unión. **Nunca uses el nombre de una pieza
  animable** en una caja: las animaciones y `partNamed` cogerían la que no es.
- `mirror = true`: la parte se describe del lado derecho (+X) y sale también la izquierda,
  reflejada (`Right Arm` / `Left Arm`, `Right Shoulder` / `Left Shoulder`). `simétrica` (noveno
  campo) hace lo mismo con una caja suelta (ojos, orejas, orificios de la nariz).
- Tonos (`voxelTones`, salen de `bodyColor` = pelo y `faceColor` = piel): `fur`, `shag`
  (pelo algo más claro), `chest`, `silver`, `skin`, `paws`, `dark`, `mouth`, `eye`. Si una especie
  necesita otro tono, añádelo ahí, sacado de esos dos colores con `Lerp`: así sus jefes recolorean
  solos.
- Pivotes: copia los del constructor viejo de la especie (hombro, cadera, cuello) para que sus
  animaciones sigan valiendo sin rehacerlas. Las especies ya en voxel no tienen constructor
  redondo (se borró al aprobarlas): sus pivotes están en su spec, y los viejos, en el historial de
  git (`git log -S "local function tamarin"`).
- `unit`: elígela para que el animal tenga su tamaño real frente al jugador (§5) con el `scale` que
  ya tiene en Data. Así sus jefes quedan como dice el GDD §8.2 y no hay que tocar su `attackRange`.
  El gorila usa 0,18: hombros a 4,2–4,4 studs (≈1,5 m) y 5,2 de alto. Comprueba siempre la tabla
  del GDD **y su lista de excepciones** antes de cambiar `unit`. Con 0,15 el gorila parecía estar
  bien, pero medía 1 stud menos que el de antes, y el Gorila de Ceniza perdió los 13,4 studs que
  tiene a propósito.
- **Jefes** (`bosses = { [bossId] = { remove?, add?, groups? } }` en el spec de su especie, tipo
  `VoxelBoss`):
  - `remove`: nombres de cajas del cuerpo base que el jefe quita. Por ejemplo `Brow`, `Eye` y
    `Mouth`, porque su cara va por fases.
  - `add = { [parte] = { cajas } }`: cajas que se suman a una parte, como los músculos. Se unen con
    ella, así que no añaden piezas. En las partes con `mirror` van del lado derecho.
  - `groups`: adornos, con la forma
    `{ anchor, name, color? | tone?, material?, transparency?, mirror?, phase?, boxes }`.
    - Las cajas tienen el mismo formato que las de las partes. Su tono es opcional; sin él usan el
      `color` o el `tone` del grupo, y `tone` sirve para que el adorno salga del color de cada jefe.
    - Cada grupo se une en **una** pieza de su material: la unión copia material, transparencia y
      sombra de su primera caja. No mezcles cristal y neón en un grupo.
    - Con `mirror`, el grupo va a `Right <anchor>` y a `Left <anchor>`.
    - Con `phase = n`, el grupo solo se ve en esa fase del combate. `showPhase` muestra la fase más
      alta que tenga piezas y no pase de la actual, y `spawnBoss` lo llama al cambiar `BossPhase`.
      Así salen las caras por fase (`phaseFaces` del gorila: seria, gruñido y rugido) y lo que se
      enciende en la fase 3 (venas de rubí, más lava). Si una pieza la busca otro sistema por
      nombre, dale ese nombre al grupo: los ojos de cada fase se llaman `Eye` para que `glowEyes`
      los encienda.
  - `tones = { [clave] = Color3 }`: cambia tonos de la especie solo para ese jefe. El Gorila de
    Ceniza lleva `silver` gris ceniza oscuro: con el tono de siempre, el lomo salía casi blanco sobre
    un cuerpo casi negro.
  - El tono de una caja puede ser también un `Color3` fijo, para colores propios del jefe que no
    salen de sus colores de Data (abdominales carbón, manchas de ceniza).
  - **Moteado** (`mottle(semilla, cuántas, colores, caras)` en el spec del gorila): manchas planas
    de 0,1 celdas de grueso, de tamaños y colores al azar con semilla fija, sobre las caras visibles
    de una parte. Van en `add`, dentro de la unión, así que no cuestan piezas.
    - Pon caras **delante** (bíceps, antebrazo, hombro): sin ellas, de frente no se veía el moteado.
    - Mezcla tonos más oscuros y más claros que la base, para que se vean sobre el pelo y sobre el
      lomo.
    - Una `PointLight` de mucho alcance (43 studs a escala de jefe) teñía todo de naranja y tapaba
      el moteado. Con alcance 5 ilumina el suelo de alrededor y no tiñe el cuerpo.
  - Para juntar cajas de varias fuentes en `add`, `combine(BOSS_MUSCLES, CENIZA_MUSCLES, CENIZA_ASH)`.
    Para rasgos de más en cada fase, `phaseFaces(glow, { [fase] = { cajas } })`.
  - Lecciones de las caras:
    - Las cejas de furia van en **tono oscuro**: del color del pelo, en el Albino no se leían.
    - Una boca abierta con los dientes en fila **parece una sonrisa**. El gruñido es boca cerrada
      con dos colmillos hacia abajo y arrugas en el hocico.
    - Placas de 2,5 celdas sobre un jefe parecían botones: hazlas de 3,5–4.
  Las funciones de `BOSS_EXTRAS` miran `rig.voxel`:
  - con el cuerpo voxel solo ponen los efectos (luz, partículas, ojos encendidos, recolores);
  - con el cuerpo viejo ponen además sus adornos redondos.

  Para formas que se repiten, pon una función de ayuda local en el spec. `crystal(x, y, z, s,
  forward?)` del gorila da tres bloques en escalera que se estrechan; las grietas de lava son filas
  de celdas de neón de 0,2 de grueso, pegadas a la cara (+0,05).

### Cómo se dibuja un animal voxel

- **Masas grandes primero.** El torso del gorila son 4–5 cajas. Un escalonado (cresta, lomo que baja
  a la grupa) son 3 cajas apiladas que se van estrechando, no un voxel por celda.
- **Rasgos de 1 celda o menos** pegados a la cara: ojos 1 × 0,6, orificios 0,6 × 0,6, boca
  2,6 × 0,3. Sobresalen 0,05–0,2 celdas de la cara para que no haya z-fighting. Sin pupilas: la
  referencia lleva ojos claros lisos, y así caben en el presupuesto.
- **Dedos**: 3 cajas de 1,2 de ancho separadas 1,5 delante de la mano. La rendija de 0,3 se lee
  como dedos.
- **Masa del hombro** (`Deltoid`): una caja encima de cada brazo, como parte del brazo, que
  sobresale de los hombros del torso. Sin ella la parte de arriba es una losa plana.
- Lo que en el gorila funcionó y lo que no:
  - El lomo plateado de **una sola caja parecía un cubo pegado** en la espalda. En tres escalones
    que bajan hacia la grupa se lee como en la referencia.
  - Escalones de anchos distintos, vistos desde atrás, parecían **los cajones de una cómoda**. Los
    tres igual de anchos y el último bajando hasta las patas: desde atrás se ve un solo panel y los
    escalones se siguen viendo desde el lado y desde arriba. Revisa siempre la vista de espaldas.
  - Las cajas pueden solaparse sin miedo, igual que las primitivas. Cuida que dos caras visibles de
    tono distinto no queden en el mismo plano.
- `SmoothPlastic` siempre: las aristas limpias son el estilo (nada de `Fabric`).
- **Monos pequeños** (Tití, Mono ardilla, Capuchino, Marteja, Cola larga, Marimonda, Aullador): `unit = 0,1` y el cuerpo dibujado alrededor
  de los pivotes del modelo redondo (pásalos a celdas: `(x / 0,1, (y + 1,9) / 0,1, z / 0,1)`); el
  alto del GDD se ajusta con `scale` en Data, no con `unit`. Sus animaciones solo giran
  articulaciones, así que con los mismos pivotes valen sin rehacerlas. Colas en fila de bloques y
  dedos con `VoxelSpecs/Shapes` (`tail`, `fingers`). Las patas parecían zancos con el tronco de 7
  celdas: bájalo por abajo (9) sin tocar el hombro.
- **Nada de piezas sueltas de menos de ~0,05 studs.** Con una celda de 0,05 studs, los ojos sueltos
  (`Eye`, de `VOXEL_LOOSE`) medían 0,01 de fondo y Studio los dibujaba como cubos negros enormes y
  bloques grises translúcidos alrededor, que no se iban ni con `Transparency = 1`. En una especie
  sin jefe, nombra esas cajas de otra forma (`Pupil`, `Bib`) para que entren en la unión. La unión
  diminuta sí se dibuja bien (agrandarla antes de unir no cambió nada).
  - **Ojos de neón** (`glowEyes = true` en el spec, como la marteja): las cajas `Eye` quedan sueltas y
    de `Neon`. Dales al menos 2 celdas de fondo, hundidas en la cara: con 1,2 (0,07 studs a su
    escala) salían verdes. Una pupila de 0,2 celdas delante del ojo salía como un bloque verde
    translúcido: sin pupila se lee mejor.
  - **Bloque gris translúcido entre dos piezas sueltas** en edición: es el dibujo de las
    `WeldConstraint` que hace Studio (sigue aunque la desactives). No sale en el juego. Para verlo
    limpio en la vista previa, cambia cada una por un `Weld` con `C0 = Part0.CFrame:Inverse() *
    Part1.CFrame`. No las borres: sin soldadura, las piezas sueltas (ojos, expresiones) se quedan
    donde estaban cuando una animación mueve la cabeza, y parece que la cara no está.
- Para revisar modelos pequeños, cámara a ~8 studs con `FieldOfView = 20` (teleobjetivo): de cerca
  con el campo de visión normal se deforman y no se ve lo mismo que en juego.

### Mascotas voxel (felinos)

Las mascotas no usan specs ni uniones: `voxelCat` en PetModels coloca cajas sueltas (las construye
cada cliente y son pocas a la vez) medidas en celdas de `VOXEL = 0,11` studs, con el suelo en 0.
Mantiene los huesos y los `dims` de `cat`, así que valen los mismos clips (sentarse, tumbarse, el
salto del ocelote). Va detrás de `PetModels.voxelCats` (activo desde el 18-10-2026; `false` vuelve a los redondos). Lo aprendido:
- **Manchas** (`speckle`): una rejilla de huecos de ~1,6 celdas por cara con una mancha al azar
  (cuadro 0,9, barra 1,5 × 0,6, L, parche tostado), semilla fija. Con huecos de 2,3 salían tres
  manchas por costado; pon también en paletillas, ancas (por detrás) y patas, como la referencia.
- Una nariz en bloque con una raya vertical debajo parecía un buzón: nariz ancha en la esquina de
  arriba del hocico y la boca como una raya aparte.
- Hocico y patas claros solo en los felinos con manchas: en el jaguarundí parecían bozal y calcetines.
- Cristales: tres bloques de vidrio escalonados con núcleo `Neon`; con el color del cuerpo se
  perdían contra el cielo, mézclalo con el del brillo (`color:Lerp(glow, 0.55)`).
- **Musculatura en bloques:** con un solo color, paletilla y anca grandes parecían tablones (y en
  el jaguarundí, más bajo, sobresalían del lomo). Lo que se lee es el escalón de tono y de
  silueta: hombro con un omóplato más estrecho y algo más claro (+8 % de blanco) que asoma sobre el
  lomo, anca a ras del lomo con un glúteo más oscuro (-12 %) que abulta hacia fuera (desde atrás
  las caderas se ven más anchas que la cintura), tramo de arriba de la pata más grueso y el de abajo
  más fino con un bloque de antebrazo o gemelo arriba, pecho hondo y un cuello que asoma tras la
  cabeza. Mide la altura de lo que asoma desde `top` y `bottom`, no en celdas fijas, o no vale
  para el cuerpo esbelto.
- **Tronco que se dobla al girar:** pecho (fijo, manda el rumbo) y cadera (`Hips`, 0,4 celdas más
  estrecha y recogida por abajo, metida 1,2 celdas en el pecho para que no se abra rendija). La
  cadera es una articulación con `bend = -0,8` sobre la cintura, y de ella cuelgan las patas de
  atrás y la cola (`parent`); la cabeza lleva `bend = 0,5`. `PetFollowers` mide el giro de la
  mascota en cada fotograma y lo pasa a `PetModels.animate(..., bend)` (+ a la izquierda, con tope
  0,45 rad). Lo pegado a la cadera que no se mueve solo (vientre, manchas, cristales de atrás) va
  en `rig.bend.parts`: se mueve únicamente mientras gira, así no suma articuladas al andar recto.
  Signo: + es girar a la izquierda; la cadera va hacia dentro de la curva (-X) y la cabeza mira
  hacia ella. Compruébalo con números, no a ojo: construye, `animate(m, 0, 0, nil, nil, 0.45)` y
  mira que `Hips.Position.X` salga negativo.
- **Probar una mascota en Play** (con MCP): en el servidor,
  `Players:GetPlayers()[1]:SetAttribute("ActivePet", id)`. En el cliente aparece en
  `workspace.Mascotas`; para ver cómo gira, mueve al personaje en círculo con `Humanoid:MoveTo` y mide
  el giro de `Hips` respecto a `PrimaryPart` (el ocelote llegó a 0,32 rad). `screen_capture` en Play
  enseña la vista del jugador.
- Pesa sobre todo lo articulado: el ocelote lleva 144 piezas y 105 articuladas (límite ~110). Si
  sube, recorta manchas en las patas antes que en el lomo (el tríceps detrás del brazo apenas se
  veía y se quitó por eso).

### Presupuesto: bloques de diseño frente a piezas en juego

Lo que cuesta en cada fotograma son las **piezas que se mueven**, no los bloques que se ven. Prueba
en Studio (PC, modo edición, 160 gorilas moviéndose a la vez, el máximo de monos activos):

| Versión | Piezas por mono | Triángulos | Fotograma medio |
|---|---|---|---|
| 40 bloques sueltos | 41 | 492 | 32,6 ms |
| 120 bloques sueltos | 119 | 1.428 | 124,5 ms (~8 FPS) |
| 120 bloques unidos por extremidad | 8 | 1.092 | 17,1 ms (~60 FPS) |

Con la unión por extremidad:
- **Mono normal:** hasta ~150 bloques de diseño; ≤ 10 piezas en juego (una por extremidad más las
  sueltas de `VOXEL_LOOSE`).
- **Jefe:** hasta **500 bloques**. Techo de 1.000 solo para un jefe especial, y avisando antes al
  usuario. En juego, ~15 piezas (extremidades, un grupo por material de adorno y las sueltas).
- **Triángulos:** vigílalos, porque sí crecen con el detalle (~12,5 por bloque).

Mide las dos cosas en cada vuelta: los bloques del spec y las piezas del modelo ya unido.

Coste de un jefe según sus bloques (gorila jefe a escala 3,6, 6 uniones, ninguna falló):

| Bloques | Tiempo de unión | Triángulos |
|---|---|---|
| 100 | 99 ms | 1.672 |
| 250 | 167 ms | 3.864 |
| 500 | 267 ms | 6.888 |
| 1.000 | 533 ms | 12.518 |

Con 500 bloques un jefe tiene lo que un avatar con varios accesorios. Suele haber un jefe en
pantalla como mucho. Con 1.000 ya es mucho para un móvil de gama baja si coincide con muchos
monos. Reparto orientativo de los 500:

| Para qué | Bloques |
|---|---|
| Cara y expresiones (cejas, ceño, colmillos, arrugas) | 40–80 |
| Musculatura (pectorales, bíceps, antebrazos, espalda en escalones) | 100–150 |
| Adornos (cristales, lava, tocados, collares) | 150–250 |
| Cuerpo base | el resto |

El tiempo de unir se paga una vez por servidor:
- los monos normales salen de una plantilla por especie (`MonkeyModels.spawn`);
- los jefes, de una por jefe (`MonkeyModels.spawnBoss`, que pone en cada copia la vida y la
  velocidad de esa aparición).

**Expresiones por acción** (monos normales; la primera, el grito del aullador al llamar a la tropa):
`faces = { { name = "Normal", boxes }, { name = "Grito", actions = { "Howl" }, boxes } }` en el spec.
- Cada expresión se une en una pieza `Expression` soldada a la cabeza, con los atributos `Face` y
  `FaceActions`. Lo que cambia entre expresiones (cejas, ojos, boca, colmillos) va ahí y no en la
  unión de la cabeza; lo fijo (cara, nariz, mandíbula, barba) sigue en la cabeza.
- `MonkeyModels.showFace(model, acciones)` enseña la de una acción que suena, o la `Normal`.
  `MonkeyAnimator` la llama al lanzar una acción con `play` y cuando su pista se para, así que basta
  con que la acción tenga animación. Cuesta una pieza más por expresión.
- Para probarlo en edición: `MonkeyAnimator.attach` (con `freshRequire`) en la copia de la vista
  previa, `play(model, "Howl")`, pausa la pista a mitad y mira `Transparency` de las `Expression`;
  luego avanza con `animator:StepAnimations(0.1)` hasta que pare y comprueba que vuelve la `Normal`.
  Una pista recién cargada a veces no pinta la pose al primer `StepAnimations`: vuelve a poner
  `TimePosition` y repite. Mira la expresión en la pose de la acción y desde una cámara algo elevada:
  en el aullido la cabeza sube unos 45° y una boca pequeña quedaba de escorzo y no se leía.

**Expresiones por fase del combate** (cara distinta en cada fase, en el atributo `BossPhase` del
modelo, de 1 a 3). Las piezas de una expresión que cambia no pueden ir dentro de la unión de la
cabeza:
- van en grupos sueltos, uno por fase, soldados a `Head`;
- solo el de la fase actual es visible; los demás con `Transparency = 1`;
- se cambian al cambiar `BossPhase`, como hace `MonkeyAnimator` con las animaciones.

Lo que no cambia entre fases (colmillos, arrugas fijas) va dentro de la unión. Está hecho con
grupos `phase` y `showPhase` (ver "Jefes" en §8). Lo usan el Gorila Albino y el de Ceniza, y está
probado en Play: cambia en el servidor y el jugador lo ve.
- BossService sube `BossPhase` desde su bucle (`tick` → `updatePhase`): fase 2 con ≤ 66 % de vida y
  fase 3 con ≤ 33 %. Solo sube: si quitas mucha vida de golpe, salta de la 1 a la 3.
- **Para probarlo desde MCP en Play:** `require` de BossService da una copia aparte, sin su bucle en
  marcha.
  - Con `BS.spawn(id)` el jefe aparece, pero bajarle la vida no cambia la fase.
  - Arranca el bucle en la copia con `task.spawn(function() BS:Start() end)` y entonces sí cambia.
  - Para un jefe aún no activado, pon antes `require(MonkeyModels).voxelBosses[id] = true`, en la
    misma copia que usará esa BossService.
  - Mira lo visible por el atributo `Phase` y `Transparency < 1`, en el servidor y también con
    `datamodel_type = "Client"`. Acerca antes el jefe al jugador, porque la isla solo carga cerca.

Las cifras absolutas exageran: mover con `PivotTo` desde Luau cuesta más que la animación real. Lo
que vale es la proporción. Falta confirmarlo en un móvil real y en Play en la Isla: que la unión
funcione en el servidor y lo que pesa enviar a los jugadores la de un jefe de 500 bloques.

### Ciclo de revisión barato en tokens

- Si Rojo y la Isla están conectados: `Preview.freshRequire` de MonkeyModels y cambia
  `MM.voxelSpecs.<Especie>` por el spec recién cargado con `freshRequire`, porque el `require`
  interno del spec queda en caché. Para un jefe aún no activado, añade
  `MM.voxelBosses.<bossId> = true`.
- Si no (por ejemplo, solo está abierto el Lobby): la primera llamada pega una versión mínima de
  `Preview` y una función `Preview.voxel(spec, fur, skin, scale)` que solo coloca cajas ancladas,
  sin articulaciones ni unión, y las guarda en `_G`. Para ver cómo queda unido, agrupa las cajas por
  zona y únelas con `GeometryService:UnionAsync(primera, resto, { SplitApart = false })` y
  `UsePartColor = false`: en el gorila se veía igual que suelto, con todos sus colores. Las siguientes solo mandan el spec (`_G.GorilaSpec`)
  o los cambios a sus cajas. No pegues MonkeyModels entero: son 65 KB.
- Captura cerca (unos 10 studs del centro): las cámaras de `Preview.show` quedan lejos para un
  modelo de 5 studs. La luz del Lobby (atardecer) tiñe todo de rosa: juzga ahí la forma, y los
  colores en la Isla.
- Para enseñárselo al usuario en **una sola captura**: tres copias en fila, como en la referencia.
  Vistas desde delante (-Z): espalda a la izquierda (+X, girada π), 3/4 en el centro (girada
  -40°) y frente a la derecha (-X). Quita el maniquí. La cámara va a unos 19 studs delante, algo
  por encima.
- `screen_capture` da "Request timeout" si la pantalla del PC está bloqueada (el usuario trabaja en
  remoto): no reintentes en bucle, avisa y espera.

### Al activarlo en una especie

- **Adornos de sus jefes:** los de `BOSS_EXTRAS` van en coordenadas del cuerpo redondo viejo y
  sobre el voxel quedan enterrados o flotando. Pásalos a bloques en la sección `bosses` del spec y
  deja en la función solo los efectos.
- **Alto:** mide la especie y sus jefes con su `scale` (franja del GDD §8.2).
- **Animación:** prueba una de verdad en edición. Con todas las piezas ancladas no se mueve nada:
  ancla solo `HumanoidRootPart`, carga la pista con el `Animator` del modelo, `Play(0)`,
  `AdjustSpeed(0)`, pon `TimePosition` y llama a `animator:StepAnimations(0)`. Tres copias en fila
  (andar, golpe y pisotón en su punto más fuerte) se revisan en una sola captura.
- **Al aprobarlo:** borra el constructor redondo de la especie, su entrada en `BUILDERS` y lo que
  solo usaba él (ayudas como `hairCap`, las ramas `if not rig.voxel` de sus jefes en
  `BOSS_EXTRAS`); `selene` avisa de las ayudas que quedan sin usar. Antes, comprueba en
  `Data/Bosses` (`baseSpecies`) que todos sus jefes estén en `VOXEL_BOSSES`: sin constructor
  redondo, un jefe que no esté ahí saldría con el cuerpo del mono genérico.
- **Para probar sus jefes en la vista previa** carga también el spec con `freshRequire` y ponlo en
  `MM.voxelSpecs.<Especie>`: el `require` interno de MonkeyModels puede devolver una copia vieja
  del spec en caché, y el jefe sale sin sus grupos (sin cristales ni caras por fase) aunque el
  código esté bien.
