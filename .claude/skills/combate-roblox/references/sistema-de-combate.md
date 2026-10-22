# Cómo funciona el combate (mecánicas, detección y red)

Estado del repo el 22 de octubre de 2026, al empezar la Fase 10 ("Combate v2", `docs/PLAN.md`).
Cada apartado dice **qué hay hoy** y, si cambia, **qué está planificado** y en qué grupo (C1–C13).
Cuando un grupo se cierra, actualiza aquí su apartado: lo planificado pasa a ser lo que hay. Si algo
no coincide con el código, manda el código.

## 1. Mapa

| Pieza | Hoy | Fase 10 |
|---|---|---|
| Golpe con arma | `CombatService.onUseWeapon` → cadena (`Shared/MeleeChain`, C4 ✅) + `meleeAttack` / `rangedAttack` | Proyectiles reales (C9) |
| Esquiva | `DodgeController` (cliente: empuje con `Dash.push`) + `CombatService.onDodge` (invulnerabilidad, estamina del servidor) | Evasivo (C7) |
| Estados del jugador | `Shared/CombatState` + `Combat/StateMachine` (C2 ✅) | Guardia, cadena, Evasivo… (C4–C8) |
| Estados de enemigos | `Combat/Status` (atributos del modelo), con control decreciente por modelo (C6 ✅) | — |
| Ataques de monos y jefes | Preparación con aviso y golpe al acabarla (`Combat/EnemyAttack`, `EnemyWindupController`, C6 ✅) | — |
| Detección | `Combat/Hitbox` + `Combat/PositionHistory` (C3 ✅): arma, áreas, cono de puntería y disparos rectos; monos y jefes (C6 ✅) | Proyectiles (C9), muros de los empujes (C10) |
| Defensa | Esquiva, armadura, Grito de guerra, Escudo de hojas; bloqueo, parry y guardia (`Combat/Guard`, `GuardController`, C5 ✅), también contra monos y jefes, con sus imbloqueables (C6 ✅) | Amagos (C8) |
| Empujes | `Combat/Knockback` (C2 ✅): a los monos el servidor, a los jugadores su cliente | Rebote contra muros (C10) |
| Reglas por place | `Combat/CombatRules` | Campos nuevos de guardia, escalado y entorno |

## 2. Estados

**Hoy (C2, 22-10-2026).**
- `Shared/CombatState` (funciones puras, lo leen cliente y servidor): estados `Idle`, `Attacking`,
  `Casting`, `Blocking`, `Parrying`, `Dodging`, `Evading`, `Staggered`, `Stunned`, `GuardBroken` y
  `Downed` (= caído de `LifeState`), y la tabla de qué acciones impide cada uno (`Attack`, `Ability`,
  `Dodge`, `Guard`, `Evasive`). `CombatState.canAct(player, acción)`.
- `Combat/StateMachine` (servidor): `enter(player, estado, segundos)` solo si su prioridad
  (`Config.CombatStates.Priority`) es igual o mayor que la del estado en curso, o si este ya terminó;
  `leave`, `reset`. Publica `CombatState` y `CombatStateUntil` en el `Player` y usa un "ticket" por
  jugador para que un temporizador viejo no libere antes de tiempo. Se limpia al reaparecer.
- Comprueban `canAct`: en el servidor, `CombatService.onUseWeapon` ("Attack"), `onDodge` ("Dodge") y
  `AbilityService.onUseAbility` ("Ability"); en el cliente, `WeaponController`, `DodgeController` y
  `RoleController.useAbility`, para no mandar lo que el servidor va a rechazar.
- Entran `Stunned` (con `Status.stunPlayer`), `Attacking` (cada paso de la cadena, lo que dura),
  `Staggered` (el tambaleo de la cadena en PvP, C4, y el parry recibido, C5), `Parrying`, `Blocking`
  (sin fin: `StateMachine.enter` sin segundos dura hasta `leave`) y `GuardBroken` (C5, con
  `Status.stunPlayer(…, "GuardBroken")`); `Casting`, `Dodging` y `Evading` los usan C7–C8.
  `CombatState.isGuarding` = `Blocking` o `Parrying` (los controladores de movimiento: ×0,6 y sin correr).
- Si el estado pasa a algo que no es `Idle` ni `Attacking` (tambaleo, aturdido, guardia), la cadena
  de golpes vuelve al primero, en el servidor (`CombatService`) y en la predicción del cliente
  (`WeaponController`).
- **Inmovilizado** (`Status.holdPlayer`: `StunnedUntil`, no anda pero pega) y **aturdido**
  (`Status.stunPlayer`: lo mismo y el estado `Stunned`, no pega ni usa habilidades ni esquiva), con la
  misma inmunidad de 2 s al soltarse. Qué usa cada uno: `sistema-de-habilidades.md` §2.4.
- Otros atributos del jugador: `ControlImmuneUntil`, `InvulnerableUntil` (esquiva),
  `GuardUntil`/`GuardReduction` (Grito), `ShieldUntil`/`ShieldHealth` (escudo), `IntimidatedUntil`
  (rugido del mandril), `MovementLocked` (portador de la bandera en Dunas), `SlowedUntil`/`SlowFactor`
  en el personaje (PvP con `pvpStatus`), `Stamina` (§4).

Probado en Play (Isla, 22-10-2026): aturdido 3 s, el servidor rechaza golpe, Rompehuesos y esquiva y
al terminar el estado se limpia; inmovilizado 3 s, velocidad 0 y el garrote pega.

## 3. Golpe con arma

**Hoy.**
- **Cadena de golpes (C4).** Las armas cuerpo a cuerpo que no son herramientas (`MeleeChain.uses`:
  `kind = "Melee"` sin `tool`) pegan en cadena de 4. `Shared/MeleeChain` (funciones puras, las usan
  el cliente y el servidor con su reloj, y la calculadora mide lo mismo en la sección 7):
  - cada paso dura `Config.Chain.Steps[k].time` × `cooldownSeconds` del arma y hace `damage` × su
    daño; el golpe cae a `WindupFraction` (35 %) del paso: preparación → golpe → recuperación;
  - `advance(estado, arma, ahora, margen)`: el siguiente paso sigue la cadena si se pulsa antes de
    `LinkWindowSeconds` (0,8 s) desde que se puede; si no, al cambiar de arma o tras el remate, vuelve
    al 1. `readyAt = max(ahora, readyAt) + paso`: el margen del servidor no se acumula, así que no
    sube el ritmo;
  - `hitstunSeconds`: tambaleo en PvP (`PvPHitstunSeconds`, recortado para dejar siempre
    `Config.Reaction` hasta el golpe siguiente); el remate no tambalea, empuja.
- Cliente (`WeaponController`): con un arma de cadena predice el paso, reproduce su tajo
  (`Slash1`–`Slash4` de `Data/WeaponAnimations`, generados por `WeaponAnimationBuilder` y estirados a
  lo que dura el paso; sin ellos, el tajo de Roblox) y manda `UseWeapon` solo cuando empieza un paso.
  Una pulsación hasta `BufferSeconds` (0,3 s) antes de poder se guarda y sale a tiempo. Si al caer el
  golpe la caja toca a un enemigo o a otro jugador, parón de impacto (`HitStopSeconds`, el remate
  `FinisherHitStopSeconds`) y en el remate un temblor de cámara (`Humanoid.CameraOffset`). Las demás
  armas: el tajo de Roblox o el disparo (distancia) y `UseWeapon` en cada pulsación.
- Servidor (`CombatService.onUseWeapon`):
  - Cadena: `MeleeChain.advance` con margen `Config.Net.JitterSeconds` (0,05 s) + 2 × `Latency`
    (con solo el mismo reloj en los dos lados, una pulsación que llegaba milisegundos antes se
    rechazaba y la cadena se rompía). `chainAttack`: estado `Attacking` lo que dura el paso, atributo
    `ChainStep` en el `Player` y el golpe tras la preparación menos `Latency.compensation` (el
    atacante ya la empezó en su pantalla). No sale si mientras tanto le tambalean, le aturden, cae o
    cambia de arma (`canAct "Attack"`). En el remate, `Knockback.push` hacia donde mira
    (`FinisherKnockback` 35 durante 0,2 s) o, si no hay suelo a `AirborneGroundDistance` bajo su raíz,
    con `lift` = `FinisherLaunch` (45); los monos de categoría ≤ `FinisherStaggerTier` y los muñecos
    se tambalean (`Status.stun`, 0,6 s); los alfas y los jefes no (a los jefes tampoco los mueve).
  - Herramientas (hacha, pico, hoz): golpe suelto cada `cooldownSeconds`, como antes.
  - `meleeAttack` (los dos): **una caja** de `MELEE_HITBOX` (7 × 6) × `range` delante de la raíz, con
    `Hitbox.inBox` (C3): solo a quien se ve desde la raíz del atacante y también donde estaba hace
    `Latency.compensation` (rebobinado, ≤ 0,15 s). Se usa `inBox` en el instante del golpe y no
    `sweepBox` (que solo devuelve lo primero que toca): un tajo alcanza a todos los de la caja.
- Probado en Play (Isla, 22-10-2026, guerrero con garrote de piedra): pasos cada 0,81 · 0,81 · 0,90 ·
  1,26 s y golpes a 0,28 · 0,28 · 0,32 · 0,46 s de cada paso, daño 24 · 24 · 27 · 37 (29,6/s frente a
  30/s suelto); la ventana (a 1,2 s sigue, tras 2 s vuelve al 1) y el búfer (pulsar 0,2 s antes da el
  paso 2); el hacha sigue suelta; el remate tambalea 0,6 s a un capuchino, no a un mandril alfa, empuja
  a 35 studs/s y en el aire lanza a 45.
  - Distancia (`rangedAttack`): munición (`CombatRules.useAmmo`); ayuda de puntería
    (`findAimTarget`, cono `aimAssistDegrees` y `aimDeviation`) entre los monos que se ven
    (`Hitbox.inSphere`). Si encuentra un mono, el proyectil visible vuela hacia él y el daño llega con
    `task.delay` **aunque el mono se haya apartado** (hasta C9). Contra un jugador solo vale un rayo
    directo (sin ayuda): asimetría.
- PvP: daño del arma × `pvpWeaponMultiplier` × `pvpWeaponMultipliers[arma]` (arena: ×0,55, arco ×0,7).

- Guardia (C5): cada golpe de la cadena contra un jugador se puede bloquear o parar (§5); gasta
  `ChainGuardDamage` (el remate `FinisherGuardDamage`) × `cooldownSeconds` ÷ `ChainReferenceCooldown`,
  y los disparos `ProjectileGuardDamage`. Bloqueado no tambalea ni empuja (lo hace `onResult`).

**Planificado.** C7: escalado en PvP y contador `ChainFinishers`. C8: amago (cancelar la
preparación). C9: proyectiles simulados por el servidor (ver §6). C10: el remate contra un muro aturde.

## 4. Esquiva, estamina y Evasivo

**Hoy.** Q / B / botón "Esquivar". El cliente predice la estamina (`combatClient/Stamina`), empuja con
`Dash.push` (fuerza limitada, se corta contra una pared) y manda `Remotes.Dodge`. El servidor
(`CombatService.onDodge`) comprueba el estado (`canAct "Dodge"`), la recarga
(`DodgeCooldownSeconds` menos el doble del margen de `Combat/Latency`) y la estamina, y pone
`InvulnerableUntil` (`DodgeInvulnerableSeconds`, 0,35 s): `damagePlayer` y `canHitPlayer` lo respetan.

**Estamina (C2).** La lleva el servidor (`Combat/StaminaServer`, atributo `Stamina` del `Player`): la
gasta correr (el cliente avisa con el remoto `Sprint` y el servidor mira que se mueva de verdad, a más
de 2 studs/s) y `tryConsume` (la esquiva, con `StaminaSyncTolerance` de margen porque el cliente va un
poco por delante); se recupera tras `StaminaRegenDelay` al ritmo de `CombatRules.staminaRegenFactor`
(Isla: `WeakStaminaRegenFactor` con hambre o sed bajas, `Survival.isWeak`). El cliente predice con los
mismos números y toma la del servidor si se separan más de `StaminaSyncTolerance`. Probado en Play:
5 esquivas seguidas 100 → 12; 2,5 s corriendo de verdad 100 → 72.

**Planificado.** C7: **Evasivo**, la misma esquiva pulsada estando
`Stunned`, `GuardBroken`, `Rooted` o `Launched`: rompe el estado, da invulnerabilidad y aparta;
recarga `Config.Evasive` (~25 s), con icono en el HUD.

## 5. Defensa

**Hoy (C5 ✅, 22-10-2026).** Orden: zona segura, invulnerable o caído → **guardia** (parry → bloqueo)
→ crítico del atacante → `mitigate`: armadura (`Data/Armor`) → tótem guardián (`WardReduction`) →
Grito de guerra (`GuardReduction`) → Escudo de hojas (`ShieldHealth`, absorbe). En `damagePvP`, la
marca y el expuesto (con `pvpStatus`) van después de la guardia, con el crítico.

**Guardia (`Combat/Guard`, servidor; `GuardController`, cliente).** Números en `Config.Guard`.
- Remoto `Guard` (pulsar con la hora del servidor en el reloj del cliente; soltar). F / L2 / botón
  "Guardia" (casilla encima de "Esquivar"). El controlador solo está enlazado con el jugador vivo:
  caído, F es "Rendirse" (`LifeController`). Beber pasó de F a E.
- Pulsar abre el **parry** (`Parrying`, `ParryWindowSeconds` 0,3 s **aunque se suelte**) si han
  pasado `ParryRearmSeconds` (0,8 s) desde el anterior; si no, solo bloquea. Mantener = **bloqueo**
  (`Blocking`, sin fin hasta soltar). Pulsado mientras pega, está tambaleado o aturdido, se pone al
  acabar si sigue pulsando (`Guard.start` vigila el atributo `CombatState`). Esquivar la suelta
  (`Guard.drop` en `onDodge`): hay que volver a pulsar.
- Solo de frente: `BlockAngle` (120°) desde la raíz del defensor hacia `from` (la raíz del atacante).
- `Guard.resolve(jugador, golpe, instante)` → `"Hit" | "Blocked" | "Parried" | "Broken"` y la
  fracción del daño que entra. Bloqueado: ×(1 − `BlockReduction` 0,5) contra jugadores o
  ×(1 − `BlockReductionEnemies` 0,7) contra monos y jefes, y gasta el `guardDamage` del golpe; a 0,
  `Broken`: guardia rota (`Status.stunPlayer(…, "GuardBreak", "GuardBroken")`, `BreakStunSeconds`
  1,2 s; si la rompe un jugador, ×`pvpControlMultiplier`), con la inmunidad de 2 s de siempre.
  Parry: no entra, +`ParryGuardRefund` (20), atributo `ParryAt` y, si el atacante está a menos de
  `ParryStaggerRange` (12 studs), le tambalea (`ParryStaggerPvP` 0,6 s; un mono `Status.stun`
  `ParryStaggerMonkey` 1 s, un jefe la mitad por `BossControlMultiplier`). Así parar un disparo de
  lejos no tambalea al tirador. Imbloqueable a quien está en guardia: `Broken` y entra entero.
- Barra `Guard` (atributo del `Player`): se recupera `RegenPerSecond` (25/s) tras `RegenDelaySeconds`
  (1 s) sin recibir golpes, también bloqueando. El HUD (`CombatClient/GuardBar`, a la derecha de la
  estamina en la Isla y en Dunas) solo la enseña si no está llena o se está en guardia: plateada,
  dorada 0,4 s tras un parry y naranja con la guardia rota.
- Qué se puede defender hoy:
  - **De otros jugadores** (`damagePvP` con `guard`): la cadena y los disparos de arma (esperan el
    margen del parry, §7), y las habilidades (`AbilityService.hurt`: `guardDamage` de `Data/Roles` o
    `AbilityGuardDamage` 25). `unblockable` en `Data/Roles`: Rompehuesos, Pisotón y Meteoro. Una
    habilidad bloqueada o parada tampoco aplica su control, su lentitud ni el empuje de la Embestida
    (`Guard.defended`, 0,1 s tras el golpe). El veneno no se defiende.
  - **De monos y jefes** (`damagePlayer` con `Guard.enemyHit`): mordisco, robo del capuchino (si
    lo bloqueas o lo paras no te quita nada), piedra del chimpancé, mordisco del asedio y golpe normal
    del jefe. Gastan `MonkeyGuardDamage` por categoría (×1,5 alfa) o `BossGuardDamage`. Un mordisco
    bloqueado no agarra (orangután). `damagePlayer` devuelve además el resultado (`false, "Parried"`
    con un parry). Llegan tras su preparación (§8 bis) y esperan el margen del defensor.
    **Imbloqueables** (C6): el pisotón del gorila, la embestida del jefe y los peligros (`Hazards`:
    pisotón de jefe, rocas, lava, rayos) llevan `unblockable` (rompen la guardia y entran enteros); el
    agarre del jefe no la mira (te agarra aunque estés en guardia).
- Lo que se ve y se oye: `AbilityFx` "GuardFx" (`Block`: chispa blanca; `Parry`: contorno, aro y
  chispas doradas; `Break`: contorno naranja, esquirlas y grietas) y los sonidos `Block`, `Parry` y
  `GuardBreak` (provisionales en `Data/Sounds`). Pose `Guard` de `Data/WeaponAnimations` (en bucle,
  `Action3`), generada por `WeaponAnimationBuilder` (`GUARD_POSE`).
- Probado en Play (Isla, 22-10-2026, guerrero contra un mandril alfa sujeto delante): sin guardia
  18 por mordisco; bloqueando 5 y −27 de guardia, que se recupera a 25/s; por detrás entra entero y no
  gasta guardia; 2 parries en 9 toques cada 0,85 s: el golpe no entra y el mandril queda aturdido
  1,00 s; con varios monos la guardia se rompe (`GuardBroken` 1,2 s) y vuelve sola a 100. Mantener =
  parry 0,3 s → bloqueo → soltar; pulsar otra vez antes de 0,8 s solo bloquea; pulsar a mitad del
  tajo pone la guardia al acabar el paso; en guardia no pega; esquivar la suelta; velocidad 9,6
  (16 × 0,6). Caído: F enlazada a Rendirse y no a la guardia; al revivir, al revés.

## 6. Detección de impactos

Regla: **nunca `.Touched`**. Una consulta en el servidor en el instante del impacto, con filtros que
excluyen al atacante, los efectos y lo que no colisiona, y una tabla para dañar a cada objetivo una
sola vez por ataque.

| Ataque | Hoy (C3 ✅) | Planificado |
|---|---|---|
| Golpe con arma | `Hitbox.inBox` en el instante del golpe de cada paso de la cadena (C4 ✅) + `visible` desde la raíz del atacante + rebobinado | — |
| Disparo de arma | Ayuda de puntería entre los que se ven + daño con retraso aunque se aparte | Proyectil del servidor: un `sweepSphere` por paso de `Heartbeat` (C9) |
| Habilidades que viajan | `castShot` (`Hitbox.sweepSphere` en el instante) + daño con retraso | El mismo proyectil por pasos (C9) |
| Áreas (`targetsAround`, `targetsAroundGround`, `targetsOnGround`) | `Hitbox.inSphere` + `visible` desde el centro: **las paredes protegen** | — |
| Ayuda de puntería (`bestInCone`, `findAimTarget`) | Cono entre los que se ven (`inSphere`) | Solo orienta la dirección inicial; mismo cono para todos (C9) |
| Flecha perforante | `Hitbox.ray` hasta el terreno o una pared + línea, sin `visible` (el rayo ya mira el camino) | Proyectil que atraviesa (C9) |
| Mordisco de mono y golpe de jefe | Preparación (C6 ✅) y al acabarla, tras el margen del defensor, una caja delante (`EnemyAttack.reaches`: `GetPartBoundsInBox` con solo el personaje + `Hitbox.visible` desde la raíz) | — |
| Empujes | El cliente corta el empuje propio contra una pared | `Hitbox.ray` por la trayectoria en el servidor: rebote contra muros (C10) |
| Marcar presas | Distancia, sin línea de visión (a propósito: señala por el olfato) | — |

**`Combat/Hitbox`** (C3). Lo arranca `CombatService:Start` (`Hitbox.start`).
- **Combatientes**: los modelos con `Config.Combat.EnemyTag` y los personajes. La lista se rehace
  solo cuando cambia (etiquetas, `CharacterAdded`/`Removing`) y sirve de lista de inclusión para
  las consultas de piezas y de exclusión para la línea de visión.
- `ray(origen, dirección)`: contra el mundo, con `RespectCanCollide` e `IgnoreWater`, sin
  combatientes. Solo tapan las piezas que chocan y el terreno; el decorado del proyecto es
  `CanCollide = false` (y las marcas, `CanQuery = false`), así que no tapa.
- `visible(desde, modelo)`: rayo a la raíz y, si está tapada, a la cabeza (medio escondido tras algo
  bajo también cuenta).
- `inSphere(centro, radio, consulta)`: raíz a menos del radio (**la misma medida de antes**, para que
  la calculadora siga valiendo) + `visible`. `inBox(cframe, tamaño, consulta)`: piezas dentro de la
  caja (`GetPartBoundsInBox` con la lista de inclusión) + `visible`. La consulta lleva `exclude`
  (el atacante), `from` (desde dónde se mira; por defecto el centro), `throughWalls`, `rewind`
  (segundos) y `flatHeight` (en horizontal, para lo que está en el suelo).
- Las áreas que caen en el suelo (Meteoro, Lluvia, Polvo, Cepo) miran desde
  `Config.Combat.AreaSightLift` (3 studs) sobre el suelo; la explosión de la Bola de fuego, desde
  1 stud antes del impacto (si da en una pared, lo de detrás no se quema).
- `sweepSphere` / `sweepBox`: `Spherecast` / `Blockcast` que devuelven lo primero que tocan; no ven
  lo que ya tocan al salir. Sin `RespectCanCollide`: las piezas de los monos no chocan y el disparo
  las atravesaría.
- `rewound(modelo, segundos)` y **`Combat/PositionHistory`**: la raíz de cada combatiente a
  `Config.Net.HistoryRate` (20) muestras por segundo durante `HistorySeconds` (1), en un anillo fijo
  sin crear tablas; `at` interpola entre muestras.

Probado en Play (Isla, 22-10-2026), con el muro de la línea base (1 × 14 × 8 entre el guerrero y el
muñeco del centro): Torbellino 7 golpes → **0** (sin muro, 7 de 6); garrote a 6,5 studs 4 de 4 →
**0 de 4** (sin muro, 4 de 27); Pisotón y Nova dan a los muñecos de los lados, que se ven, y no al
del centro; la Bola de fuego contra el muro no quema al de detrás (sin muro, 24). Rebobinado: una
caja vacía en el sitio viejo de un muñeco movido 5 studs lo encuentra con `rewind = 0,3` y sin
rebobinar no. Coste: 47–66 µs por consulta con 109 combatientes (copia que rehace la lista cada
vez: cota superior); peleando con 32 mandriles, heartbeat 0,32 ms y física 2,27 ms (antes 0,31 y 2,21).

## 7. Red y lag

**Hoy.** El cliente manda la intención (puntería, hueco de habilidad, "desde/hasta" del Parpadeo, que
el servidor acepta con `BLINK_POINT_SLACK`); el servidor comprueba recargas con margen (0,25 s en las
habilidades; en la esquiva, `Combat/Latency`) y decide el daño. Los movimientos propios (Embestida,
Parpadeo, Torbellino, esquiva) los hace el cliente, que simula su personaje: por eso el servidor no
puede empujar a un jugador poniéndole velocidad.
- `Combat/Latency.compensation(player)`: `Player:GetNetworkPing()` (segundos, aproximadamente de ida)
  sin pasar de `Config.Net.MaxCompensationSeconds` (0,15 s).
- `Combat/Knockback.push(modelo, dirección, velocidad, segundos)`: a un mono le pone la velocidad (y
  un pequeño salto); a un jugador le manda el remoto `Knockback` y lo aplica su cliente
  (`KnockbackController` → `Dash.push`); a un jefe, nada. Hasta C2 la Embestida **no empujaba a los
  jugadores a propósito** (`not target.player`); ahora sí, en PvP. Probado en Play: el remoto mueve al
  jugador 10,5 studs (45 studs/s, 0,2 s); la Embestida lanza a un mandril a 44 studs/s.
  Desde C4 lleva un `lift` opcional (studs/s hacia arriba): el remate de la cadena dado en el aire.
  El cliente lo suma como velocidad vertical después de `Dash.push` (que solo empuja en horizontal).
- `Config.Net.JitterSeconds` (C4, 0,05 s): margen fijo cuando el servidor comprueba un ritmo que el
  cliente lleva con su propio reloj (la cadena de golpes), además del de `Latency`.

- Rebobinado (C3): el golpe con arma también vale contra donde estaba el objetivo hace
  `Latency.compensation(atacante)` segundos (`Hitbox.inBox` con `rewind`, `Combat/PositionHistory`).
  Las áreas no rebobinan: son generosas y así miden lo mismo que la calculadora.

- Margen del parry a favor del defensor (C5): `CombatService.damagePvP` con `waitForParry` (la cadena
  y los disparos de arma) espera `Guard.grace(defensor)` = `min(ping, Config.Net.ParryGraceMaxSeconds
  0,12)` antes de resolver (0 si ya está en guardia, si no podría abrir el parry o si es menos de un
  fotograma), y resuelve con la hora del golpe. La pulsación cuenta desde la hora que manda el cliente,
  como mucho ese margen antes de llegar. Lo que el golpe hace además del daño (tambaleo, empuje,
  veneno) va en `onResult`, porque puede resolverse más tarde. Las habilidades no esperan (C8 les
  pone preparación).
- Monos y jefes (C6): al acabar la preparación, `EnemyAttack.strike` espera `Guard.grace(presa)` y
  entonces mira si sigue en la caja (con su posición más reciente: a favor del defensor) y resuelve la
  guardia con la hora del golpe (`Guard.Hit.at`). El cliente sabe en qué instante del servidor cae el
  golpe (`WindupUntil`), así que el parry se acierta igual con cualquier ping.

Regla de equidad: los topes nunca pasan de ~0,15 s y son los mismos para todos.

## 8. Control y escape

**Hoy.** Enemigos: `Status.stun` (aturdir, congelar, inmovilizar y dormir son lo mismo para la IA);
los jefes se quedan `BossControlMultiplier` (0,5). **Rendimientos decrecientes** (C6 ✅,
`Config.ControlDR`), por modelo y para todo control (habilidades, parry, remate): 1 → 0,8 → 0,6 → 0,4
y después inmune hasta 6 s después del último que entró (`ControlResistedAt` → "INMUNE" en los
clientes). Jugadores: `holdPlayer` con inmunidad de 2 s. En PvP: control ×`pvpControlMultiplier`
(Isla 0,5, arena 0,5).

Probado en Play (Isla, 22-10-2026): 6 parries seguidos al muñeco de sparring le aturden 1,00 · 0,80 ·
0,60 · 0,40 s, "INMUNE", "INMUNE"; 3 al Orangután del Manglar, 0,50 · 0,40 · 0,30 s.

**Planificado.** C7: escalado en PvP por víctima (daño y tambaleo bajan con cada golpe seguido, con
mínimo; se reinicia tras ~1 s sin recibir) y Evasivo.

## 8 bis. Preparación de monos y jefes (C6 ✅)

`Combat/EnemyAttack` (servidor) y `EnemyWindupController` (cliente). Números en `Config.Windup`.
- `windup(modelo, segundos, tipo, golpe)`: pone `WindupUntil` (hora del servidor del golpe) y
  `WindupKind` ("Strike" o "Unblockable") y llama a `golpe` al acabar si sigue vivo. Un cambio de
  `StunnedUntil` (cualquier `Status.stun`) la corta. `busy`: la IA (`think`, `siegeThink`,
  `BossService.tick`, el sparring) lo deja quieto y no empieza otro ataque. `face`: se gira hacia la
  presa al empezar y ya no gira: apartarse de lado también vale.
- `strike(modelo, jugador, alcance, entra, falla?, imbloqueable?)`: margen del defensor (§7) y caja de
  largo alcance + `ReachMargin` (1,5), ancho alcance × `HitWidthFactor` (1,2) y alto
  max(`HitHeight` 8, alcance), delante de la raíz, + `Hitbox.visible`.
- Avisos: mordisco, robo y piedra de los monos `MonkeyByTier` (0,4 · 0,5 · 0,6 s), pisotón del gorila
  `MonkeyStompSeconds` (0,8, "‼"), golpe y agarre de los jefes `BossSeconds` (0,7; el agarre "‼"),
  embestida `BossChargeSeconds` (0,7, "‼"); el pisotón de jefe lleva "‼" lo que tarda su onda (0,9).
  La animación `Attack` empieza `AttackLeadSeconds` (0,2) antes del golpe: la cabeza del mandril
  baja a los ~0,22 s de sus 0,5 s. El chillido (`Monkey<voz>Attack`, `BossAttack`) suena al empezar.
- La recarga de cada ataque cuenta desde que empieza la preparación, que cabe en ella (la sección 10
  de la calculadora avisa si no): el DPS de los monos no cambia; baja solo para quien esquiva, se
  aparta o se defiende.
- Cliente: "!" blanco (o "‼" naranja) sobre la cabeza que crece hasta el golpe y los `Eye` del modelo
  en neón (crema o naranja) mientras dura; "INMUNE" que sube con `ControlResistedAt`.
- **Muñeco de sparring** (`TrainingDummies.placeSparring`, Basecamp y Lobby): pega cada
  `Config.Combat.SparringAttackSeconds` (1,8 s) a quien esté a menos de `SparringRange` (6), con
  aviso `SparringWindupSeconds` (0,5) y `SparringGuardDamage` (18). No hace daño: `Guard.resolve` y,
  si entra, destello rojo y "¡ay!".

Probado en Play (22-10-2026): sparring en la Isla y en el Lobby (golpe a los 0,50 s del aviso,
bloqueo −18 de guardia, parry 3 de 3 y 2 de 2, apartarse 6,5 studs a un lado 2 de 2 fallos); mandril
alfa (aviso 0,5 s, ritmo 1,55 s como antes, apartarse 7 studs 3 de 3 fallos); gorila alfa (pisotón
"‼" 0,8 s rompe la guardia, mordisco 0,6 s); Orangután del Manglar (golpe 0,7 s, agarre "‼"
0,7 s, parry 3 de 3).

## 9. Entorno

**Hoy.** Peligros de los jefes (`island/server/Combat/Hazards`: onda, rocas, lava, rayos) con marca de
aviso; suelo ardiendo del Meteoro rematado (`MeteorBurnTicks`). Sin rebote contra muros, coberturas que
se rompan ni puntos disputados.

**Planificado.** C10: rebote contra muros (aturde con `Config.WallBang` y da 1,5 s de inmunidad) y
`Combat/Zones` (suelo ardiendo, hielo, nube). C11 (Dunas): coberturas `Destructible` que se rompen y
reaparecen, y un altar en la pirámide central que da a su equipo una ventaja pequeña de 30 s.

## 10. Controles

| Acción | PC | Mando | Móvil |
|---|---|---|---|
| Arma | Clic | Gatillo (R2) | Tocar la pantalla |
| Habilidades Z X C R V | Teclas | Mantener R1 + A, B, X, Y, L1 | 5 botones junto al salto |
| Esquivar | Q | B | "Esquivar" |
| Correr | Mayús | L3 | "Correr" |
| Guardia (C5 ✅) | F (caído: Rendirse) | L2 | "Guardia", encima de "Esquivar" |
| Beber (Isla) | E (antes F) | X | Tocar el aviso |
| Evasivo (C7) | Q estando aturdido | B estando aturdido | "Esquivar" estando aturdido |
| Bloqueo de cámara (C2) | Ctrl (el shift lock de Roblox; el jugador lo enciende en el menú de Roblox) | — | — |

El shift lock: `EnableMouseLockOption = true` en los tres `*.project.json` y `CameraLockController`
cambia las teclas de Mayús a Ctrl. El `PlayerModule` de Roblox se carga hoy desde
`StarterPlayer.PlayerModule` (no se copia a `PlayerScripts`) y lee las teclas del sistema de acciones
de entrada: `InputContexts.CameraContext.MouseLockSwitchAction` con un `InputBinding` por tecla
(`KeyboardPrimaryBinding`, `KeyboardSecondaryBinding`). El controlador cambia su `KeyCode`; para un
`PlayerModule` antiguo cambia su valor `BoundKeys`. La acción solo se activa si el jugador tiene el
bloqueo de cámara encendido en sus ajustes de Roblox (`GameSettings.ControlMode`).
