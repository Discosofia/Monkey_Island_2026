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
| Mascotas | Por código, cada fotograma (senos) | `src/shared/PetModels.luau` (`joint(...)` en cada constructor) | — | `src/shared/UI/PetFollowers.luau` llama a `PetModels.animate` |
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
  de la especie). Una vacía no se reproduce.
- **No hay animación de prueba en Studio**: a diferencia de las armas, `MonkeyAnimator` solo usa
  ids publicados. Para ver una animación de mono sin publicar, usa la tira. Si el usuario quiere
  probarla en Play antes de publicarla, propón añadir el mismo mecanismo que `WeaponController`
  (`KeyframeSequenceProvider:RegisterKeyframeSequence` cuando el id está vacío y se está en Studio).

**Fuente en git.** Las de los monos se hicieron a mano y su fuente es el id publicado (se puede
bajar con `Anim.download`). Cuando crees o cambies una, la primera vez propón al usuario guardar
los specs en el repo, por ejemplo en `src/island/tools/MonkeyAnimationBuilder.luau` con el mismo
esquema que `WeaponAnimationBuilder` (una tabla de specs y un `build()` que deja las
KeyframeSequence en el place para publicarlas). No lo crees sin preguntar.

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
`moving = 1` al atacar).
- Para cambiar el movimiento, cambia esos números en el constructor (más rápido = `velocidad`,
  más amplio = `amplitud`, a destiempo = `fase`).
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
