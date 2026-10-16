# Sistemas de animación de Primal Banana Island

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
| Jugador con arma a distancia (R15) | KeyframeSequence publicada | Generadas por código: `src/island/tools/WeaponAnimationBuilder.luau` | `src/shared/Data/WeaponAnimations.luau` | `src/island/client/Controllers/WeaponController.luau` (cliente) |
| Jugador con arma cuerpo a cuerpo | El tajo de Roblox (`toolslash` del avatar o el estándar) | — | `WeaponController` (`DEFAULT_SLASH`) | `WeaponController` |
| Mascotas (Lobby e Isla) | Por código, cada fotograma (senos) | `src/shared/PetModels.luau` (`joint(...)` en cada constructor) | — | `src/shared/UI/PetFollowers.luau` llama a `PetModels.animate`; lo arrancan los `PetController` de los dos places |
| Poses de habilidades (grito de guerra) | Por código, girando articulaciones | `src/island/client/Controllers/AbilityFxController.luau` (`poseJoint`) | — | `AbilityFxController` |

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
- **Gibón**: de pie, con los brazos en alto y abiertos. Con un brazo que apunta arriba los signos
  se invierten: **X negativo lo echa hacia delante**. Sin cola. Por eso las acciones comunes que
  echan los brazos adelante (el `Pounce` de `Default`) le salen al revés: tiene `Gibon_Pounce`.
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
- La rana salta con `|sin(reloj * 6)|` en `PetFollowers`; sus patas usan velocidad 12 y fase −π/2
  para patalear en el aire. Los dos usan el mismo reloj (`follower.clock`).
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

**Poses de habilidades (`AbilityFxController`).** El grito de guerra gira articulaciones por código
(`Motor6D.C0` o el `Attachment0` de los `AnimationConstraint`). Eso solo funciona en articulaciones
que ninguna animación esté moviendo: con un arma en la mano, Roblox reproduce `toolnone` sobre el
brazo y el brazo **tiembla**. Las poses del brazo que sujeta un arma (o de cualquier articulación
animada) tienen que ser KeyframeSequence, como los disparos de `WeaponAnimationBuilder`.

## 5. Piezas del R15

El R15 que crea `Anim.playerRig("R15")` (y el de los jugadores) cuelga así:

`LowerTorso` ← `HumanoidRootPart`; `UpperTorso` ← `LowerTorso`; `Head` ← `UpperTorso`;
`RightUpperArm` / `LeftUpperArm` ← `UpperTorso`; `RightLowerArm` ← `RightUpperArm`;
`RightHand` ← `RightLowerArm` (igual a la izquierda); `RightUpperLeg` / `LeftUpperLeg` ←
`LowerTorso`; `RightLowerLeg` ← `RightUpperLeg`; `RightFoot` ← `RightLowerLeg`.

En Studio ese R15 lleva articulaciones nuevas (`AnimationConstraint`) en vez de Motor6D; las
animaciones se aplican igual y `Anim.hierarchy` entiende las dos. El R6 tiene las piezas de los
monos (`Torso`, `Head`, `Right Arm`…).
