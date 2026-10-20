# Sistemas de animación de Primal Banana Islands

Lee esto antes de crear o cambiar una animación. Resume cómo se reproducen hoy las animaciones del
juego para que lo nuevo encaje con el código que las usa.

## Índice

1. Qué sistema usa cada cosa
2. Monos y jefes
3. Personaje del jugador con armas
4. Animaciones por código (mascotas, poses de habilidades)
5. Piezas del R15

## 1. Qué sistema usa cada cosa

| Qué | Cómo se anima | Fuente | Dónde se enlaza | Quién la reproduce |
|---|---|---|---|---|
| Monos y jefes | KeyframeSequence publicada | Hechas a mano en el Animation Editor (en el place: `ServerStorage.RBX_ANIMSAVES.RigMono`) | `src/shared/Data/MonkeyAnimations.luau` | `src/island/server/Monkeys/MonkeyAnimator.luau` (servidor) |
| Jugador con arma a distancia (R15) | KeyframeSequence publicada | Generadas por código: `src/island/tools/WeaponAnimationBuilder.luau` | `src/shared/Data/WeaponAnimations.luau` | `src/combatClient/Controllers/WeaponController.luau` (cliente) |
| Cuerpo del jugador sin armas (gestos de habilidades, esquivar, comer, beber, curarse, construir, fabricar, caído, reanimar) | KeyframeSequence publicada | Generadas por código: `src/island/tools/PlayerAnimationBuilder.luau` | `src/shared/Data/PlayerAnimations.luau` | `src/combatClient/BodyAnimations.luau` (cliente), llamado desde `RoleController`, `DodgeController`, `SurvivalController`, `HealController`, `BuildController`, `CraftingController` y `LifeController` |
| Jugador con arma cuerpo a cuerpo | El tajo de Roblox (`toolslash` del avatar o el estándar) | — | `WeaponController` (`DEFAULT_SLASH`) | `WeaponController` |
| Mascotas (Lobby e Isla) | Por código, cada fotograma: senos (`joint`) y, encima, clips con fotogramas clave (`CLIPS`) | `src/shared/PetModels.luau` | — | `src/shared/UI/PetFollowers.luau` llama a `PetModels.animate` y decide qué clip suena; lo arrancan los `PetController` de los dos places |
| Pose del grito de guerra, de respaldo | Por código, girando articulaciones (solo si la animación `WarCry` no existe) | `src/combatClient/Controllers/AbilityFxController.luau` (`scream`, `poseJoint`) | — | `AbilityFxController` |

## 2. Monos y jefes

Rig articulado con Motor6D (`MonkeyModels.luau`), con un `Humanoid` R15 y su `Animator`. Las
animaciones se enlazan por el **nombre de las piezas**, iguales en todas las especies:

| Pieza (Pose) | Cuelga de | Articulación |
|---|---|---|
| `Torso` | `HumanoidRootPart` | `RootJoint` |
| `Head` | `Torso` | `Neck` |
| `Right Arm` / `Left Arm` | `Torso` | `Right Shoulder` / `Left Shoulder` |
| `Right Leg` / `Left Leg` | `Torso` | `Right Hip` / `Left Hip` |
| `Tail` | `Torso` | `TailJoint` |

Las demás piezas (cara, manos, adornos de los jefes) van soldadas a una de estas. Los simios
(gorila, chimpancé, orangután, gibón) no tienen cola: lo que mueve `Tail` no les afecta. Las patas
delanteras de los monos a cuatro patas son los brazos. Detalles y recetas de cada acción en
`docs/ANIMACIONES.md`.

**Escala.** Se anima a escala 1 (`Anim.monkeyRig` lo hace por defecto). Las especies van de 0,45
a 3,2 de escala y los desplazamientos en studs no se escalan: usa rotaciones.

**Cómo las reproduce `MonkeyAnimator`:**
- `Idle`, `Walk` y `Run` se cambian solos según la velocidad (`RunThreshold`; sin `Run`, `Walk`
  acelerada) y se fuerzan a bucle. `Walk` y `Run` se aceleran según `WalkReferenceSpeed` /
  `RunReferenceSpeed`.
- Las acciones las lanzan `MonkeyService` y `BossService` con `MonkeyAnimator.play(model, accion)`.
- La prioridad la pone el código, no la secuencia: `Idle` → Idle, `Walk`/`Run` → Movement,
  `Death` → Action4, el resto → Action. Por eso un `Attack` que solo mueve el brazo deja las
  piernas andando debajo (revísalo con `under` = el id de `Walk`).
- `Death` no se usa: el mono desaparece con un "¡puf!".
- Ids: `Default` para todos; `Overrides[especie o jefe]` para cambiar solo esa (el jefe va encima
  de la especie) y `Phases[jefe]` según su fase (ver abajo). Una vacía en `Default` no se
  reproduce; una vacía en `Overrides` o `Phases` se ignora y se queda la de debajo.
- **No hay animación de prueba en Studio**: a diferencia de las armas, `MonkeyAnimator` solo usa
  ids publicados. Para ver una animación de mono sin publicar, usa la tira. Si el usuario quiere
  probarla en Play antes de publicarla, propón añadir el mismo mecanismo que `WeaponController`
  (`KeyframeSequenceProvider:RegisterKeyframeSequence` cuando el id está vacío y se está en Studio).

**Fuente en git.** Las primeras (las de `Default`) se hicieron a mano y su fuente es el id
publicado (se bajan con `Anim.download`). Las propias de cada especie y del Gorila de Ceniza están
como specs en `src/island/tools/MonkeyAnimationSpecs/` (un módulo por lote: `MonosPequenos`,
`MonosMedianosYGrandes`, `GorilaDeCeniza`), y `MonkeyAnimationBuilder.build("<lote>")` las deja en
`ServerStorage.RBX_ANIMSAVES.<lote>` para publicarlas. El nombre de cada animación
(`Titi_Run`, `Cenizo_Attack2`) es el que lleva su hueco en `Data/MonkeyAnimations`. Una animación
nueva o retocada va a su lote; si es de un grupo nuevo, crea otro módulo.

**Fases de los jefes.** `MonkeyAnimations.Phases[jefe][2 | 3]` cambia animaciones según la fase
(66 % y 33 % de vida), encima de `Overrides`, y la 3 hereda lo de la 2. `MonkeyAnimator` las cambia
al cambiar el atributo `BossPhase`. Un id vacío en `Overrides` o `Phases` se ignora: se puede dejar
el hueco antes de publicar. Los jefes heredan además los `Overrides` de su especie base (atributo
`MonkeyType`): lo que se haga al gorila le llega al Gorila Albino y al de Ceniza.

**Acciones en bucle.** `Invoke` se reproduce en bucle con prioridad de acción hasta que el código la
para con `MonkeyAnimator.stop` (la invocación de lava del Gorila de Ceniza en fase 3; `BossService`
la lanza quieto y fuera del cuerpo a cuerpo, ver `channelFromPhase` en `Data/Bosses`). Entran con un
fundido de 0,3 s en vez de 0,1.

**Velocidades.** Los monos van siempre a su `walkSpeed` y casi todos superan `RunThreshold` (16):
en cuanto una especie tiene `Run`, es lo que más se ve, y `Walk` solo sale cuando la ralentizan. El
aullador (15), el mandril (15), el orangután (12) y el gorila (15) andan. `Run` se acelera con
`velocidad / 20`; `Walk`, con `velocidad / 10`.

### Lo que se sabe de cada rig (medido con `Anim.measure`)

- **Cuadrúpedos con cola** (casi todos los pequeños y medianos): brazos y piernas cuelgan
  verticales de hombro y cadera hasta el suelo. Andar en diagonal con brazos ±25° y piernas ±22°
  apenas hunde nada; galope a brincos ±40–50° vale. La cola sale hacia atrás: **X negativo la
  levanta** y X positivo la baja (la del tití y la de la marteja rozan el suelo enseguida).
- **Simios** (gorila, chimpancé, orangután, y los jefes que salen de ellos): sin cola. Los pies y
  los nudillos sobresalen hacia atrás, así que **una pata o un brazo que va hacia atrás se clava**
  (−0,3 con −20°). Que recorran hacia atrás la mitad que hacia delante.
- **Gibón**: de pie, con los brazos larguísimos colgando hasta casi el suelo (modelo voxel, desde el
  18-10-2026; antes los tenía en alto y X negativo los echaba adelante). Ahora X positivo los echa
  hacia delante, como en los demás. Sin cola. Tiene `Gibon_Walk`, `Gibon_Attack` y `Gibon_Pounce`
  propios en `MonkeyAnimationSpecs/MonosMedianosYGrandes`.
- **Cuándo hace daño cada acción**: el golpe de la animación tiene que coincidir con el del código,
  y no siempre es al empezar. `MonkeyService` hace el daño del pisotón del gorila al instante
  (`Gorila_Stomp` golpea a 0,14 s); `BossService` lo hace a 0,9 s (`STOMP_IMPACT_SECONDS`,
  `Cenizo_Stomp2`, que comparten los tres jefes con pisotón). Míralo en el servicio antes de fijar
  los tiempos.
- **Torso**: gira sobre su centro, con los hombros por delante y las caderas por detrás. Levantar el
  pecho (X+) baja las caderas y hunde los pies; bajar el pecho (X−) los hace flotar. Para alzarse
  (pisotón, invocación), las piernas tienen que ir unos 40–50° adelantadas respecto al suelo.
- **Desplazamientos**: `MonkeyModels` escala el tamaño de cada pieza, no el modelo, así que una
  traslación en studs no crece con la especie ni con el jefe. Todo con rotaciones.

## 3. Personaje del jugador con armas

`WeaponAnimationBuilder` genera desde código las animaciones de las armas a distancia (R15):
`Hold` (brazo derecho colgando con el arma, en bucle, prioridad Action) y un disparo por tipo de
proyectil (`Stone` honda, `Arrow` arco, `Spell` bastón, `Dart` cerbatana; prioridad Action2).

- **La fuente es el código**, no un spec: para cambiar un disparo, cambia sus ángulos en `SHOTS`
  (`pose` = la pose de disparo, `pulse` = el golpe al soltar, `raise` = segundos hasta la pose,
  `pulseSeconds`, `seconds`). El golpe empieza en el `fxDelay` de `Data/WeaponAnimations`
  (marcador "Disparo"), que es cuando sale el efecto.
- Sus ángulos **no** son los de `CFrame.Angles`: `joint(raise, swing)` es
  `CFrame.Angles(0, swing, 0) * CFrame.Angles(raise, 0, 0)` (primero sube y luego abre), y al
  brazo derecho se le suma la base de 90° (`BASE`). Por eso `Anim.dump` de un disparo da números
  como `{ 86.78, -3.83, 49.89 }` para un `joint(85, -50)`: no los copies de vuelta al generador.
- Los disparos empiezan y acaban en la pose `Hold`, no en reposo: los avisos de `Anim.show` sobre
  eso son esperados.
- Generar y ver:
  ```lua
  Anim.freshRequire("ServerStorage.Tools.WeaponAnimationBuilder").build()
  local ks = game.ReplicatedStorage.WeaponAnimations.Arrow
  return Anim.show(Anim.playerRig("R15"), ks, { view = "frente" })
  ```
  Con `Hold` debajo, como en el juego: `under = game.ReplicatedStorage.WeaponAnimations.Hold`.
- **En Play**, `WeaponController` usa el id publicado si lo hay; solo con el id vacío usa la
  secuencia generada. Para probar en Play un cambio aún sin publicar, el usuario tiene que vaciar
  ese id temporalmente (díselo; no lo dejes vacío al cerrar).
- Tras publicar, el id nuevo va en `Data/WeaponAnimations` (con el mismo `fxDelay` si el golpe no
  se movió).

### Cuerpo del jugador sin armas

`PlayerAnimationBuilder` genera desde specs (mismo formato que `MonkeyAnimationBuilder`, con
`MonkeyAnimationBuilder.sequence(spec, PARENT_R15)`) los gestos de `Data/PlayerAnimations`:
`Quake`, `WarCry`, `Charge`, `Smash` (golpe de dos manos al suelo a 0,25 s), `CastForward`, `CastArea`, `Place`, `Consume`, `Bandage` (Action3),
`Whirlwind` (Action3, en bucle mientras `RoleController` hace girar al guerrero), `DodgeRoll` y
`DodgeBack` (la esquiva elige según vaya hacia donde mira o no), `Hammer` (construir y quitar
piezas), `Craft` (fabricar y cocinar, solo si el botón está activo) y `Crawl`, `Revive` (Action4, en
bucle). `build()` los deja en `ReplicatedStorage.PlayerAnimations` y, como las armas,
en Studio se usan mientras el id esté vacío. `Data/PlayerAnimations.Abilities` dice qué gesto lleva
cada habilidad de `Data/Roles`.
- **En el jugador sí valen los desplazamientos** (`{ x, y, z, px, py, pz }`): todos los personajes
  miden lo mismo. Agacharse, arrodillarse o tumbarse baja `LowerTorso` (el suelo queda 3,19 studs
  bajo la raíz; tumbado, −1,55 con X −80).
- **Signos en el R15**: brazo o muslo hacia delante con X+; el codo se dobla con X+ y la rodilla
  con X−; el torso se inclina hacia delante con X−. Con el codo doblado, abrir el hombro en Z apenas
  mueve la mano: para llevarla al centro (a la boca) gira el brazo en Y (+ en el derecho).
- **Medir**: `Anim.measure(Anim.playerRig("R15"), ks)` da manos, espinillas y pies respecto al
  suelo y dónde quedan la mano derecha y la cabeza (alto, delante y a qué lado).
- **Vueltas enteras (voltereta)**: `LowerTorso` gira sobre la cadera, así que un giro de 360° tal
  cual mete la cabeza 2 studs bajo el suelo al ir boca abajo. Para que ruede sobre el centro del
  cuerpo encogido, mide ese centro `c` (en el espacio de la articulación Root) y en cada fotograma
  desplaza `p = centroDeseado − giro(ángulo) · c`. Pon un fotograma cada 45° (con 90°, el giro va en
  arco y el desplazamiento en recta, y entre fotogramas se hunde) y sube un poco la bola al ir boca
  abajo (las esquinas de la cabeza sobresalen). Roblox interpola por el camino corto: más de 180°
  entre dos fotogramas gira al revés. Ver `ROLL` en `PlayerAnimationBuilder`.
- Las acciones se aplican al instante en el servidor: el momento fuerte llega pronto (el pisotón
  pisa a 0,2 s; el Rompehuesos golpea a 0,25 s porque `AbilityService` retrasa su daño eso).
- **Ver el arma en la tira**: el maniquí no lleva arma y un golpe sin ella no se lee. Suelda una
  pieza larga a `RightHand` con `C0 = RightGripAttachment.CFrame * CFrame.new(0, 1.2, 0)` (el mango
  va a lo largo de la Y de esa articulación, como `tool.Grip` en `WeaponTools`) y una bola en la
  punta: así se mide si el arma llega al suelo. Ojo al leer el perfil: el maniquí mira a la
  izquierda de la captura. Los gestos que solo mueven tronco y brazos dejan las piernas andando.

## 4. Animaciones por código

**Mascotas (`PetModels`).** Cada constructor registra las piezas que se mueven con
`joint(rig, pieza, bisagra, eje, amplitud, velocidad, fase, gait)`: el ángulo es
`sin(tiempo * velocidad + fase) * amplitud` en **radianes**, multiplicado por cuánto anda el dueño
(0–1) si `gait` es `true`. Una extremidad de varias piezas se registra con la misma bisagra en cada
pieza. `PetFollowers` llama a `PetModels.animate(model, reloj, moving)` cada fotograma (con
`moving = 1` al atacar). El mismo código corre en el **Lobby** y en la **Isla** (cada uno tiene su
`PetController` que llama a `PetFollowers.start()`): un cambio afecta a los dos, y se puede revisar
en el Studio que esté abierto en modo edición.
- Para cambiar el movimiento, cambia esos números en el constructor (más rápido = `velocidad`,
  más amplio = `amplitud`, a destiempo = `fase`).
- Para mover un grupo de piezas sueltas (la cabeza con ojos, orejas y bigotes; la cola con sus
  plumas) usa `swingRegion(rig, bisagra, eje, amplitud, velocidad, fase, gait, filtro)` al final del
  constructor: articula todas las piezas cuyo centro (sin escalar) cumple el filtro y que no se
  movían ya. Cada pieza solo admite **una** articulación (`animate` no las suma): si una pieza ya se
  mueve (la antena del X-7), pon la bisagra nueva sobre ella para que no se despegue.
- **Clips** (`CLIPS` en `PetModels`): posturas con fotogramas clave que se suman a los senos, por
  familia (`rig.family`: `Cat`, `X7`, `Bird`) y por mascota (`CLIPS.Ocelote`). Mueven **huesos**
  (`joint(...).bone`, o el último parámetro de `swingRegion`): en el felino `Body` (la mascota entera,
  alrededor de `around`, con desplazamiento), `Head`, `Tail` (cola encadenada por tramos: girar
  todos lo mismo la enrosca y las ondas la recorren con retraso), `FL`/`FR`/`BL`/`BR` y sus tramos de
  abajo `FL2`…; en el X-7 `ArmL`/`ArmR`/`LegL`/`LegR`/`Head`; en las aves `WingL`/`WingR`. Giros en
  grados con `CFrame.fromEulerAnglesYXZ` (primero gira a un lado, luego cabecea). Un fotograma puede
  llevar `gait` (cuánto andan las patas), `amp` (factor del seno de un hueso: 0 lo para) y `waves`
  (`{ x = 7, speed = 16 }`, ondas que se suman). Nombres que usa `PetFollowers`: `Idle…` (rutinas de
  reposo al azar con el dueño quieto; `IdleRub` además da la vuelta a sus piernas), `Attack` (0,85 s,
  golpe a 0,35 s), `Run` (galope cuando el dueño esprinta, con el reloj de las zancadas) y `Glide`
  (aves planeando). Se ven con `PetModels.animate(model, t, 0, { { clip = "IdleGroom", time = t,
  weight = 1 } }, t)` dentro de `Anim.showCode`.
- Las patas que andan (`gait`) usan el reloj de las zancadas (`stride`), que va al paso del dueño o
  de lo que se mueve la propia mascota.
- **Perros** (`CLIPS.Dog` y `CLIPS.Beagle`/`Labrador`/`Pointer`, 19-10-2026): huesos del felino más
  `EarL`/`EarR` (X negativo echa la oreja atrás; Z la abre: negativo la izquierda, positivo la
  derecha). `Walk` es un clip que `PetFollowers` suma mientras anda y no galopa (peso
  `moving × (1 − run)`, con el reloj de las zancadas): el bote del cuerpo y la cabeza, y las orejas.
  Rutinas: `IdleSit` los tres y una propia cada uno (`IdleShow`, `IdleSide`, `IdlePoint`).
  Lo aprendido:
  - **Sentarse con patas largas**: la fórmula del felino (ángulo fijo por la altura del anca) dejaba
    al pointer casi de pie y con la grupa y las patas de atrás hundidas 0,4–0,6. El ángulo sale de
    dos condiciones: las manos siguen en el suelo (`drop = alcance × sen s`) y la esquina de la grupa
    (`dims.rump`) lo toca; el muslo va adelante hasta que la rodilla casi roza el suelo
    (`acos((alto de la cadera − 0,08) / largo del muslo)`) y el tramo de abajo, tumbado atrás.
  - **Cola por tramos**: los giros en X de cada tramo se suman (el tercero gira tres veces), y el
    cuerpo inclinado la mueve también. Un ángulo fijo clavaba la cola en el suelo o la dejaba en
    diagonal: el de sentarse se busca por bisección (punta justo sobre el suelo, con `dims.tail`).
    De lado, el giro en Y de la cola la sube y la baja: poca amplitud y la pose algo levantada.
  - **Un hueso que lleva un bloque grande** (el anca o el hombro van con la pata) se despega del
    cuerpo como una tabla si se gira mucho en una pose quieta: muslo a −10° en la exposición del
    beagle (con −20 salía) y brazo a 44° en la muestra del pointer (con 58 asomaba el hombro).
  - Las rutinas se comprueban en Play sin verlas: el `UpVector` de `Hips` respecto al pivote dice si
    está de lado (X), sentado (Z) o de pie.
- La rana salta con `|sin(zancadas * 6)|` en `PetFollowers`; sus patas usan velocidad 12 y fase −π/2
  para patalear en el aire. Los dos usan el mismo reloj (`follower.clock`).
- **Un seno va igual de lejos hacia los dos lados**: si una pata baja en el aire, sube lo mismo al
  caer (en la rana parecía una aleta levantada). Para que solo vaya hacia un lado, pasa a `joint` el
  último parámetro `bias` = amplitud: el giro va de 0 a 2 × amplitud.
- Para verlo, `Anim.showCode` construye una mascota por instante (no vale clonar: `animate` solo
  mueve las que construyó esa copia del módulo):
  ```lua
  local PetModels = Anim.freshRequire("ReplicatedStorage.Shared.PetModels")
  return Anim.showCode(function()
  	return PetModels.build("Tucan")
  end, function(model, t)
  	PetModels.animate(model, t, 1)
  end, { 0, 0.1, 0.2, 0.3, 0.4 })
  ```
  Reparte los instantes en un periodo: `2π / velocidad` segundos. Las mascotas son pequeñas: para
  ver el detalle usa la cámara de cada fotograma.

**Poses por código (`AbilityFxController`).** El grito de guerra giraba articulaciones por código
(`Motor6D.C0` o el `Attachment0` de los `AnimationConstraint`). Eso solo funciona en articulaciones
que ninguna animación esté moviendo: con un arma en la mano, Roblox reproduce `toolnone` sobre el
brazo y el brazo **tiembla**. Las poses del brazo que sujeta un arma (o de cualquier articulación
animada) tienen que ser KeyframeSequence, como los disparos de `WeaponAnimationBuilder`. Por eso el
grito es ahora la animación `WarCry` (`PlayerAnimationBuilder`, la misma pose medida igual) y la
pose por código queda de respaldo mientras la animación no exista: `BodyAnimations.has("WarCry")`
da lo mismo en todos los clientes y decide cuál se usa. **Nunca las dos a la vez**: el giro del
`C0` y el de la animación se suman y la pose saldría el doble de exagerada.

## 5. Piezas del R15

El R15 que crea `Anim.playerRig("R15")` (y el de los jugadores) cuelga así:

`LowerTorso` ← `HumanoidRootPart`; `UpperTorso` ← `LowerTorso`; `Head` ← `UpperTorso`;
`RightUpperArm` / `LeftUpperArm` ← `UpperTorso`; `RightLowerArm` ← `RightUpperArm`;
`RightHand` ← `RightLowerArm` (igual a la izquierda); `RightUpperLeg` / `LeftUpperLeg` ←
`LowerTorso`; `RightLowerLeg` ← `RightUpperLeg`; `RightFoot` ← `RightLowerLeg`.

En Studio ese R15 lleva articulaciones nuevas (`AnimationConstraint`) en vez de Motor6D; las
animaciones se aplican igual y `Anim.hierarchy` entiende las dos. El R6 tiene las piezas de los
monos (`Torso`, `Head`, `Right Arm`…).
