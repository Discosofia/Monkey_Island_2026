# Cómo funciona el combate (mecánicas, detección y red)

Estado del repo el 22 de octubre de 2026, al cerrar la Fase 10 ("Combate v2", `docs/PLAN.md`): los grupos
C1–C13 están hechos y cada apartado dice **qué hay hoy** (con el grupo que lo trajo). Antes y después, medida
a medida: `docs/combate-v2/comparativa.md`. Si cambias una mecánica, actualiza aquí su apartado. Si algo no
coincide con el código, manda el código.

## 1. Mapa

| Pieza | Hoy | Fase 10 |
|---|---|---|
| Golpe con arma | `CombatService.onUseWeapon` → cadena (`Shared/MeleeChain`, C4 ✅) + `meleeAttack` / `rangedAttack` con proyectiles reales (`Combat/Projectiles`, C9 ✅) y disparo de remate (`Shared/RangedChain`, C9b ✅) | — |
| Esquiva | `DodgeController` (cliente: empuje con `Dash.pushWithCarry`, V3, y efecto en `DodgeFeel`) + `CombatService.onDodge` (invulnerabilidad, estamina del servidor); Evasivo (`Combat/Evasive`, `CombatClient/EvasiveIcon`, C7 ✅) | — |
| Estados del jugador | `Shared/CombatState` + `Combat/StateMachine` (C2 ✅); `Casting` de las habilidades (C8 ✅) | — |
| Estados de enemigos | `Combat/Status` (atributos del modelo), con control decreciente por modelo (C6 ✅) | — |
| Ataques de monos y jefes | Preparación con aviso y golpe al acabarla (`Combat/EnemyAttack`, `EnemyWindupController`, C6 ✅) | — |
| Detección | `Combat/Hitbox` + `Combat/PositionHistory` (C3 ✅): arma, áreas, cono de puntería y disparos rectos; monos y jefes (C6 ✅); proyectiles paso a paso (C9 ✅); muros de los empujes (C10 ✅) | — |
| Defensa | Esquiva, armadura, Grito de guerra, Escudo de hojas; bloqueo, parry y guardia (`Combat/Guard`, `GuardController`, C5 ✅), también contra monos y jefes, con sus imbloqueables (C6 ✅); amagos (`Combat/Feint`, `CombatClient/Feint`, C8 ✅) | — |
| Empujes | `Combat/Knockback` (C2 ✅): a los monos el servidor, a los jugadores su cliente; rebote contra muros (C10 ✅, §9) | — |
| Escalado del combo (PvP) | `Combat/ComboScaling` en `CombatService.damagePvP` (C7 ✅); controles PvP con rendimientos decrecientes en `Status.holdPlayer` | — |
| Entorno | Rebote contra muros y zonas de peligro (`Combat/Zones`, `ZoneController`, C10 ✅, §9) | Coberturas y altar de Dunas (C11) |
| Claridad (C12 ✅) | Temblor común con su ajuste (`CombatClient/CameraShake`, `cameraShake`), indicador de la cadena (`ChainPipsController`, de `WeaponController.progress`), estallidos de la guardia en `ComicFxController` (`ComicBurst`: `Parry`, `GuardBroken`, `Counter`), sonidos de `Data/Sounds`, ayuda de controles y cadena en `SettingsPanel`, paso de la guardia en la guía del Lobby | — |
| Reglas por place | `Combat/CombatRules`; telemetría de mecánicas (`telemetry.mechanic`, C7 ✅: Isla `TelemetryService`, Dunas `ArenaTelemetryService`) | Campos de entorno (C11) |

## 2. Estados

**Hoy (C2, 22-10-2026).**
- `Shared/CombatState` (funciones puras, lo leen cliente y servidor): estados `Idle`, `Attacking`,
  `Casting`, `Blocking`, `Parrying`, `Dodging`, `Evading`, `Staggered`, `Stunned`, `GuardBroken` y
  `Downed` (= caído de `LifeState`), y la tabla de qué acciones impide cada uno (`Attack`, `Ability`,
  `Dodge`, `Guard`, `Evasive`, `Slide`, V2). `CombatState.canAct(player, acción)`.
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
  `Status.stunPlayer(…, "GuardBroken")`) y `Evading` (el Evasivo, C7, lo que dura su invulnerabilidad);
  `Casting` (C8: la preparación de una habilidad; no pega, ni otra habilidad, ni esquiva; la guardia
  la amaga). `Dodging` no se usa: la esquiva solo pone `InvulnerableUntil`.
- **Atrapado** (`CombatState.isTrapped`, C7): aturdido, guardia rota, inmovilizado (`StunnedUntil`) o
  lanzado (`LaunchedUntil`, que pone `Knockback.push` con `lift` a un jugador: lo que tarda en caer,
  `2 × lift ÷ gravedad`, ~0,46 s). Atrapado, la esquiva es el Evasivo; `onDodge` la rechaza.
  `CombatState.isGuarding` = `Blocking` o `Parrying` (en el movimiento: ×0,6 con el modificador `Guard` de
  `Movement`, y sin correr en `LocomotionController`).
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
  - Distancia (`rangedAttack`, C9 ✅): munición (`CombatRules.useAmmo`) y un **proyectil real**
    (`Combat/Projectiles`, §6 bis) hacia donde dice `CombatService.aimShot` y da al primero que
    encuentra (atraviesa a los aliados): si el mono se aparta, falla. El veneno de las cerbatanas y su
    cura al aliado entran al impactar. Contra un jugador, el mismo proyectil (se puede bloquear y parar
    con el margen del defensor, `waitForParry`). Antes de C9 el daño llegaba con `task.delay` aunque el
    mono se apartara, y contra jugadores solo valía un rayo directo.
  - **Origen (V7, Fase 15):** `UseWeapon` manda también el origen (la cámara en primera persona, o la
    punta del arma) y la hora del disparo. El servidor acepta el origen del cliente si es un `Vector3`
    finito, está a ≤ `Headshot.OriginToleranceStuds` (5) de la cabeza del tirador rebobinada y no hay
    pared entre su cabeza actual y ese punto; si no, sale de su propia cabeza. `lag` =
    `min(ahora − hora, Latency.compensation)`. La dispersión la pone el servidor (V8, abajo): la dirección
    del cliente no se valida contra un cono.
  - **Cabeza (V7):** con la regla `headshots` (Dunas y el Laboratorio), el proyectil se prueba contra los
    jugadores rebobinados `lag` segundos y sale algo adelantado (`ShotLeadMaxSeconds` 0,1 s). Cada
    jugador es una esfera de cabeza (radio visible × `HeadRadiusScale` 1,15) más una cápsula de cuerpo
    (`BodyRadius` 1,2; pies a cuello, con los brazos). Un impacto directo a la cabeza hace ×1,5
    (`Headshot.Multiplier`) solo con armas a distancia contra jugadores, y no se suma al crítico: cuenta
    el mayor. Las áreas y el cañón de suero no tienen cabeza. Telemetría `Headshots`; el número sale
    como «¡Cabeza!» (estilo crítico) y `DamageFxController` lo reacciona como `head`.
  - **Disparo de remate** (C9b ✅, `Shared/RangedChain`, `Config.RangedChain`): el 4.º disparo
    seguido al mismo ritmo (hasta `LinkWindowSeconds` 0,8 s después de poder disparar; cambiar de arma,
    tambalearse, aturdirse o ponerse en guardia vuelven al primero) es un proyectil distinto, más
    fuerte: los normales ×0,9 y el remate ×1,3 (mismo DPS contra uno). Cada arma el suyo
    (`finisher` en `Data/Weapons`): **arco** `Pierce` (atraviesa al primero y da al siguiente con el
    35 %, `maxHits` 2), **bastón** `Burst` (estalla donde se para, también en una pared o al final:
    35 % a los de 6 studs con línea de visión), **cerbatana** `Sap` (cura el doble a un aliado; al
    propio médico, lo normal: en un duelo no se sostiene más) y **honda** `Stagger` (tambalea 0,6 s a
    un mono de categoría ≤ 2, no alfas, jefes ni jugadores). Lo que alcanza a los demás no envenena,
    no cura ni tambalea. El veneno doble de la cerbatana se descartó: el remate llega antes de que se
    acabe y quedaba doble siempre (+20 % de DPS). El ritmo lo lleva también el cliente
    (`WeaponController`, con `RangedChain.advance`) para el destello del remate; el servidor admite el
    margen `Config.Net.JitterSeconds` + ping, sin acumularlo. Telemetría `ShotFinishers`.
- PvP: daño del arma × `pvpWeaponMultiplier` × `pvpWeaponMultipliers[arma]` (arena: ×0,55, arco ×0,7).

- Guardia (C5): cada golpe de la cadena contra un jugador se puede bloquear o parar (§5); gasta
  `ChainGuardDamage` (el remate `FinisherGuardDamage`) × `cooldownSeconds` ÷ `ChainReferenceCooldown`,
  y los disparos `ProjectileGuardDamage`. Bloqueado no tambalea ni empuja (lo hace `onResult`).

- Escalado del combo (C7, §8): cada golpe de la cadena que entra a un jugador cuenta; su daño y su
  tambaleo bajan desde el 4.º seguido. Un remate que alcanza algo suma `ChainFinishers` en la telemetría.

- Amago (C8, §5 bis): pulsar la guardia durante la preparación del golpe (`chainAttack` lo registra
  en `Combat/Feint`) lo cancela; la cadena vuelve al primero. Gratis, uno por segundo.

- Rebote contra muros (C10 ✅, §9): el remate que estampa a un mono o a un rival contra una pared
  le aturde y le quita un poco (`finisherPush` pasa el atacante a `Knockback.push`).

## 4. Esquiva, estamina y Evasivo

**Hoy.** Q / B / botón "Esquivar". El cliente predice la estamina (`combatClient/Stamina`), empuja con
`Dash.pushWithCarry` (V3: 55 studs/s durante `DodgeDurationSeconds` 0,2 s, ≈ 11 studs, y al terminar
sigue un segundo empuje al 40 % de la velocidad que baja a 0 en 0,2 s, ≈ 2,2 más: unos 13,2 en total;
contra una pared se corta y no hay segundo empuje) y manda `Remotes.Dodge`. El servidor
(`CombatService.onDodge`) comprueba el estado (`canAct "Dodge"`), la recarga
(`DodgeCooldownSeconds` menos el doble del margen de `Combat/Latency`) y la estamina, y pone
`InvulnerableUntil` (`DodgeInvulnerableSeconds`, 0,35 s): `damagePlayer` y `canHitPlayer` lo respetan.
Los valores están en `Config.Combat` y en `Config.Movement.Dodge` (`CarryKeep` 0,4, `CarrySeconds` 0,2).

**Efecto de la esquiva (Fase 15, V3).** `combatClient/DodgeFeel.luau` (solo el cliente que esquiva) y
`AbilityFxController` (`DodgeFx`: estela fina blanco-azulada pegada a la raíz, bocanada de polvo a los
pies y el sonido `Dodge`, provisional). Los demás jugadores lo ven por `AbilityFx.others` en
`CombatService.onDodge`. El empujón del campo de visión es +6° en 0,25 s (`FovKick`, `FovKickSeconds`),
se suma solo a la diferencia de la curva para convivir con el zoom del rifle, respeta el ajuste
`cameraShake` y lo usan la esquiva, el Evasivo y la Embestida (sin estela de esquiva). Estilo `Dash`
(`Movement.rules().dodgeStyle`, el Laboratorio): sin voltereta ni salto atrás (`DodgeRoll`/`DodgeBack`
solo en el estilo `Roll`), la cámara se inclina `LabTiltDegrees` 8° hacia el lado de la esquiva en
0,25 s (el signo es por razonamiento, por comprobar) y el arma de la vista se aparta `LabWeaponShift`
0,6 studs. Probado en Studio (Lobby e Isla, 28-10-2026): distancias, FOV, invulnerabilidad, pared, sin
errores y Equilibrio sin alertas nuevas. Lo que queda, en `docs/VERIFICACION.md` §33.

**Estamina (C2).** La lleva el servidor (`Combat/StaminaServer`, atributo `Stamina` del `Player`): la
gasta correr, salvo con `movement.staminaFree` (el Lobby, V1) (el cliente avisa con el remoto `Sprint` y
el servidor mira que se mueva de verdad, a más de 2 studs/s) y `tryConsume` (la esquiva, con `StaminaSyncTolerance` de margen porque el cliente va un
poco por delante); se recupera tras `StaminaRegenDelay` al ritmo de `CombatRules.staminaRegenFactor`
(Isla: `WeakStaminaRegenFactor` con hambre o sed bajas, `Survival.isWeak`). El cliente predice con los
mismos números y toma la del servidor si se separan más de `StaminaSyncTolerance`. Probado en Play:
5 esquivas seguidas 100 → 12; 2,5 s corriendo de verdad 100 → 72.

**Movimiento (Fase 15, V1).** Un solo escritor de `Humanoid.WalkSpeed`: `combatClient/Movement.luau`, con
velocidad = base × modificadores. Base: `Movement.addBase` (la montura, `Mount`, y el gateo, `Downed`;
gana la primera que devuelva número); si no hay ninguna, andar `Config.Movement.WalkSpeed` (18) o correr
`SprintSpeed` (26). Modificadores (`addModifier`, se multiplican): `Guard` ×0,6, `Slow` (ralentizar),
`Stun` (aturdido o inmovilizado = 0), `Egg` (huevo a cuestas, ×0,75 o ×0,9 con Guerrero), `Flag` (bandera
rival en Dunas) y `MoveSpeed` (ventaja de equipo). `combatClient/Controllers/LocomotionController` los
registra, lleva Mayús, L3 y el botón "Correr" (que alterna) y predice la estamina. Las reglas del place
(`CombatRules.movement`: `staminaFree`, `slide`, `dodgeStyle`) van como atributos `MovementStaminaFree`,
`MovementSlide` y `MovementDodgeStyle` de `ReplicatedStorage`, y las lee `Movement.rules()`. Valores: Lobby
`staminaFree = true`; Laboratorio `dodgeStyle = "Dash"`; el resto `"Roll"`; `slide = true` en todos (lo usa
V2). `LifeService` ya no guarda ni restaura la velocidad (el gateo es una base, no un valor guardado), y
`SurvivalController` de la Isla solo come y bebe. Se borraron los `MovementController` de Dunas y del Lab.
Probado en Studio (28-10-2026): Isla andar 18 y correr 26 con estamina, aturdido 0, ralentizado ×0,5,
guardia 10,8 sin correr, gateo 4 y vuelta a 18, huevo ×0,9 con Guerrero; Lobby 18/26 sin gasto de
estamina, montura 33 y vuelta a 18. Lo que falta, en `docs/VERIFICACION.md` §31.

**Deslizar (Fase 15, V2).** `combatClient/Slide.luau`, solo corriendo: Alt izquierdo (C en el Laboratorio,
por `slideKey`), R3 en el mando y, en el móvil, el botón Correr pasa a "Deslizar" mientras se corre. Empuja
con `Dash.push` de `Config.Movement.Slide.StartSpeed` (36) a `EndSpeed` (18) en `Seconds` (0,75 s), con el
cuerpo agachado (`BodyAnimations` "Slide", provisional hasta publicar su secuencia). Cooldown de 1 s, mínimo
de velocidad `MinSpeed` (22) y `StaminaCost` (15) de estamina con `StaminaServer.tryConsume` (el Lobby no la
cobra, `staminaFree`). El remoto `Slide` lo valida `CombatService.onSlide`: regla `slide`, sin llevar la
bandera, `canAct "Slide"`, sin estar atrapado, cooldown con el margen del ping y estamina; pone
`SlidingUntil` y cuenta la telemetría `Slides`. No da invulnerabilidad ni suelta la guardia. Saltar lo
termina y conserva `JumpKeep` (0,9) de la velocidad en el aire (salto deslizado, sin encadenar). Con hambre
o sed bajas, ×0,85. `Slide.cancel` lo corta al aturdirte, atraparte, caer, morir y al esquivar
(`DodgeController`). Probado en Studio en el Lobby y el Laboratorio (28-10-2026); lo que queda, en
`docs/VERIFICACION.md` §32.

**Evasivo (C7 ✅).** La misma esquiva pulsada estando atrapado (`CombatState.isTrapped`: aturdido,
guardia rota, inmovilizado o lanzado). El cliente (`DodgeController`) salta a `Config.Evasive.Speed`
durante `DurationSeconds` (12 studs, más el empuje que sigue al salto con V3: ~14,4 en total), dibuja `EvasiveFx` y manda `Remotes.Evasive`; el servidor
(`Combat/Evasive`) comprueba `canAct "Evasive"`, que estaba atrapado (hasta `JitterSeconds` + 2 × su
margen de red antes) y la recarga (`EvasiveReadyAt`, `CooldownSeconds` 25), y entonces quita
`StunnedUntil` y `LaunchedUntil`, pone `ControlImmuneUntil` (2 s), `InvulnerableUntil` y el estado
`Evading` (`InvulnerableSeconds` 0,5), suelta la guardia, termina el combo que recibía
(`ComboScaling.reset`) y cuenta `Evasives`. No gasta estamina. Atrapado y en recarga no se esquiva: la
esquiva normal ya no saca de un agarre (antes `Dash` movía aunque `WalkSpeed` fuera 0). HUD:
`CombatClient/EvasiveIcon` (💨 detrás de la guardia, con cortina de recarga; atrapado y listo, late con
la tecla); botón táctil "¡Evasivo!" / "Evasivo 12".

Probado en Play (Isla, 22-10-2026): aturdido 8 s → Evasivo a los 0,12 s (recarga 25, `Evading` 0,5 s,
inmune 2 s, 14 studs, vuelve a andar); otra vez aturdido con él en recarga → Q no hace nada; sujeto
(`holdPlayer`) → sale (14,6 studs); sujeto y en recarga → no se mueve; lanzado (0,46 s reales) y guardia
rota → salen; sin estar atrapado, esquiva normal (0,35 s, estamina 100 → 75). En Dunas (batalla con
"Empezar ya"): icono y Evasivo igual (14,5 studs; contra el basamento del templo solo 4,4, porque `Dash`
se corta en la pared) y, al acabar la partida, `ArenaTelemetryService` manda sus eventos sin errores.

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
  `GuardBreak` (audios del Creator Store en `Data/Sounds` desde C12). Pose `Guard` de `Data/WeaponAnimations` (en bucle,
  `Action3`), generada por `WeaponAnimationBuilder` (`GUARD_POSE`).
- Probado en Play (Isla, 22-10-2026, guerrero contra un mandril alfa sujeto delante): sin guardia
  18 por mordisco; bloqueando 5 y −27 de guardia, que se recupera a 25/s; por detrás entra entero y no
  gasta guardia; 2 parries en 9 toques cada 0,85 s: el golpe no entra y el mandril queda aturdido
  1,00 s; con varios monos la guardia se rompe (`GuardBroken` 1,2 s) y vuelve sola a 100. Mantener =
  parry 0,3 s → bloqueo → soltar; pulsar otra vez antes de 0,8 s solo bloquea; pulsar a mitad del
  tajo pone la guardia al acabar el paso; en guardia no pega; esquivar la suelta; velocidad 9,6
  (16 × 0,6). Caído: F enlazada a Rendirse y no a la guardia; al revivir, al revés.

## 5 bis. Preparación de las habilidades y amagos (C8 ✅)

- **Preparación**: `castSeconds` de cada habilidad en `Data/Roles` (sin él,
  `Config.Windup.AbilityDefaultSeconds` 0,2). `AbilityService.onUseAbility` valida y llama a `cast`:
  estado `Casting` (con 0,5 s de margen, por si cae a mitad) durante `castSeconds −
  Latency.compensation` y al acabar `release` (si sigue en `Casting` y con su ticket: un aturdimiento,
  un tambaleo o caer la cortan sin gastar la recarga). `release` cuenta el uso (`useKey`), llama a
  `ComboService.onAbilityUsed` (el paso cuenta al salir, no al pulsar), al handler y pone la recarga.
  `castSeconds = 0` (Grito, Parpadeo, Escudo): `release` al momento, como antes.
- Cliente (`RoleController.useAbility`): el gesto al pulsar (`BodyAnimations.playAbility(id,
  castSeconds)`, que estira el de `impactSeconds` —el Rompehuesos, 0,25 s— para que el golpe caiga al
  salir) y lo que mueve al personaje (la carga de la Embestida, el giro del Torbellino, que ya se agacha
  al pulsar) al acabar, si no ha amagado ni le han aturdido. El Parpadeo no lleva preparación: se
  teletransporta al pulsar y manda `from`/`to`. Mientras prepara, `CombatClient/Feint.casting()` no
  deja pegar (`WeaponController`), ni usar otra (`RoleController`), ni esquivar (`DodgeController`).
- El Rompehuesos ya no lleva su `task.delay(0.25)` ni el efecto su espera: la preparación es eso.
- **Amagos** (`Combat/Feint`, servidor; `CombatClient/Feint`, cliente; `Config.Feint`): quien
  prepara algo lo registra (`Feint.begin(player, "Attack" | "Ability", segundos, cancel)` y
  `finish` al salir). `Guard` llama a `Feint.try` al pulsar, **antes** de poner la guardia: si puede,
  cancela y la guardia se pone ya (amagar y parar en la misma pulsación). Golpe: gratis, uno cada
  `WeaponCooldownSeconds` (1). Habilidad: `AbilityStaminaCost` (15) de `StaminaServer` y
  `AbilityReadyAt<hueco>` = ahora + `AbilityPenaltySeconds` (1,5). `FeintFx` a los demás (humo gris
  delante del pecho; el propio cliente lo dibuja al momento) y telemetría `Feints`. Si no puede, la
  guardia espera a que acabe, como antes. El cliente predice igual (`GuardController` → `Feint.try`):
  para el tajo o el gesto y no lanza el movimiento; solo hasta su ping antes de que salga (después la
  pulsación llegaría tarde) y avisa "💨 Sin estamina para amagar".
- **Guardia una vez por uso**: `AbilityService.hurt` manda `hitKey = useKey` (`"<UserId>:<id>:<usos>"`),
  y `CombatService.damagePvP` cobra la guardia de una clave una sola vez por víctima (la primera vez
  que la bloquea; `guardSpent`, se olvida a los 15 s). El escalado del combo usa la misma clave: antes
  era por habilidad, y dos usos de la misma en un combo largo contaban como uno.
- `guardDamage` por habilidad (Data/Roles): 25 las fuertes (Torbellino, Flecha perforante, Bola de
  fuego, Rayo), 20 las medias (Embestida, Disparo múltiple, Lluvia), 15 las de control (Cepo, Nova,
  Polvo), 10 el Dardo. Imbloqueables: Rompehuesos, Pisotón y Meteoro.

Probado en Play en el Lobby (22-10-2026, guerrero contra los muñecos, por remotos y con teclas
reales): Rompehuesos `Casting` 0,30 s y golpe y recarga al acabar; amago del Torbellino a los 0,08 s
(estamina 100 → 85, recarga 1,5 s, `Parrying`, sin daño; 1,9 s después sale normal); aturdido a mitad
(no sale ni gasta la recarga; luego sale); amago del garrote (sin daño; el segundo antes de 1 s no
vale y el golpe entra; pasado el segundo vale otra vez); Z y F con teclas reales (humo `FeintFx` en
el cliente, sin giro); Z y X sin amagar (giro a los 0,22 s y carga a los 0,23 s de la tecla).

## 6. Detección de impactos

Regla: **nunca `.Touched`**. Una consulta en el servidor en el instante del impacto, con filtros que
excluyen al atacante, los efectos y lo que no colisiona, y una tabla para dañar a cada objetivo una
sola vez por ataque.

| Ataque | Hoy (C3 ✅) | Planificado |
|---|---|---|
| Golpe con arma | `Hitbox.inBox` en el instante del golpe de cada paso de la cadena (C4 ✅) + `visible` desde la raíz del atacante + rebobinado | — |
| Disparo de arma | Proyectil del servidor (C9 ✅, §6 bis): en cada `Heartbeat`, `Hitbox.ray` (mundo) + `Hitbox.sweepCombatants` (esfera entre los combatientes) de la posición anterior a la nueva. En Dunas y el Laboratorio (regla `headshots`, V7): los jugadores, rebobinados, con `Hitbox.sweepPlayers` (esfera de cabeza + cápsula de cuerpo) | — |
| Habilidades que viajan (Disparo múltiple, Bola de fuego, Dardo) | El mismo proyectil (C9 ✅); `castShot` queda para dónde cae un área | — |
| Áreas (`targetsAround`, `targetsAroundGround`, `targetsOnGround`) | `Hitbox.inSphere` + `visible` desde el centro: **las paredes protegen** | — |
| Ayuda de puntería (`CombatService.aimShot`; `bestInCone` del Rayo) | Solo elige la dirección de salida (C9 ✅), entre los que se ven y solo si la línea de tiro ya casi los toca: monos a ≤ 2,5 studs de ella (adonde estarán al llegar), jugadores a ≤ 1,5 (adonde están) | — |
| Flecha perforante | Proyectil que atraviesa (C9 ✅, `pierce`): a cada uno una vez, cuando le llega; la para el mundo | — |
| Mordisco de mono y golpe de jefe | Preparación (C6 ✅) y al acabarla, tras el margen del defensor, una caja delante (`EnemyAttack.reaches`: `GetPartBoundsInBox` con solo el personaje + `Hitbox.visible` desde la raíz) | — |
| Empujes | `Hitbox.ray` por la trayectoria en el servidor (C10 ✅, §9): rebote contra muros; el cliente sigue cortando el empuje propio contra la pared (`Dash`) | — |
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

## 6 bis. Proyectiles (C9 ✅)

`Combat/Projectiles` (lo arranca `CombatService:Start`). `Projectiles.fire(shot)` con `owner`, `look`
(aspecto en el cliente), `origin`, `direction`, `speed`, `range`, `radius`, `pierce` (con `maxHits`,
se para al dar a tantos: el remate del arco, C9b), `onHit`, `onEnd`, `extra` y `counts`.
- **En arco** (Fase 13, el cañón de suero del Laboratorio): con `gravity` (studs/s²) cae mientras vuela;
  cada paso es un tramo recto entre dos puntos de la parábola (se mira igual) y `range` es lo que
  recorre por la curva. `CombatService` (`acidLob`) le da la velocidad para caer donde apunta y el
  cliente dibuja la misma curva a la hora del servidor.
- **Laboratorio** (Fase 13, `Data/LabWeapons`, mezcladas en `Data/Weapons`): sin remate ni crítico; al
  acertar, `labHit` pone `Status.slowStack` (lanzadardos: −4 % por dardo hasta −20 %, 1,5 s) o
  `Status.entangle` (lanzarredes: −35 % 1 s, sin repetirse antes de 3 s; nunca deja quieto). Las
  reglas del place (`CombatRules`: `roleWeapons`, `abilities = false`, `guard = false`) quitan roles,
  habilidades y guardia; sin guardia, el disparo a un jugador entra sin esperar el parry.
- **Cargador, recarga y dispersión (V8, Fase 15; solo el Laboratorio).** `Data/LabWeapons` da `magazine` y
  `reloadSeconds` (dardos 24 / 1,6 s, rifle 5 / 2,2 s, arpón 3 / 1,8 s, ácido 4 / 2,0 s) y `automatic`
  (solo los dardos: mantener el gatillo repite el disparo a su cadencia). `LabAmmoService` guarda el
  cargador por jugador; `CombatRules.takeShot` (Laboratorio) gasta una bala y devuelve la dispersión en
  grados, o `nil` si no hay balas o recarga (el disparo no sale). Lo ven los clientes por los atributos
  `LabAmmo` (balas) y `ReloadingUntil` (hora del servidor en que acaba la recarga). `Remotes.LabReload`
  pide la recarga; sin pedirla, se recarga sola al vaciarse. El cargador se llena al aparecer y al
  cambiar de arma. `Shared/LabSpread` calcula los grados (base, +moverse, +aire, +0,35 por disparo hasta
  3, se recuperan a 6°/s; el zoom del rifle da 0); el cliente manda `zoomed` en `UseWeapon`, y
  `CombatService` (`scatter`) desvía el tiro con esa dispersión sobre la dirección de `aimShot`. El
  cliente predice (`combatClient/LabShooting`) y se corrige con los atributos. V7 preveía validar la
  dirección contra la dispersión + 2°: no se ha hecho, el servidor ya decide la dispersión.
- **Servidor**: un solo bucle de `Heartbeat` para todos. En cada paso, de la posición anterior a la
  nueva: `Hitbox.ray` contra el mundo (solo lo que choca y el terreno: el decorado que no choca no
  para un disparo) y `Hitbox.sweepCombatants` (`Spherecast` con la lista de inclusión de los
  combatientes, saltando al tirador y a los ya tocados) hasta la pared. `onHit(modelo)` devuelve si le
  vale: un aliado, un caído o un mono muerto devuelven `false` y el proyectil sigue. Sin `pierce`, se
  para en el primero que vale; con `pierce`, solo en el mundo o al final del alcance. Al salir mira
  también desde 1,5 studs antes del origen (la esfera no ve lo que ya toca: el mono pegado).
- **Sin lag a favor del tirador**: el proyectil sale cuando llega la orden y con las posiciones de
  ahora (no se rebobina: así favorece al que esquiva). Contra un jugador, los disparos de arma esperan
  el margen del parry (`waitForParry`); los de habilidad, no (como el resto de habilidades).
- **Ayuda de puntería** (`CombatService.aimShot`): solo la dirección de salida; el proyectil no
  persigue. Mide **en studs desde la línea de tiro**, no en grados: engancha al más cercano a la línea
  si su centro está a menos de `MonkeyAimStuds` (2,5; de lejos, dentro de `MonkeyAimMinDegrees` 2°)
  y apunta adonde estará al llegar (`leadPoint`: velocidad horizontal × tiempo de vuelo, hasta
  `LeadMaxSeconds` 0,8 s). Contra jugadores, `PlayerAimStuds` 1,5 (`PlayerAimMinDegrees` 1°) y adonde
  están. De cerca (`CloseAimRange`/`CloseAimHeight`) a los monos solo se mide en horizontal: el mono
  pequeño por debajo de la cámara. El Dardo curativo busca también a los aliados. Igual para todos
  los dispositivos y todas las armas. Con conos de 10–12° (y 30° de cerca) apuntar entre dos muñecos
  separados 10 studs mandaba el disparo a uno de ellos (lo vio el usuario el 22-10-2026); ahora pasa
  entre ellos.
- **Cliente** (`AbilityFxController`, efectos `Projectile` y `ProjectileEnd`): cada aspecto de `LOOKS`
  (piedra, flecha, dardo, bola del bastón, flechas del Disparo múltiple y la perforante, Bola de fuego,
  Dardo curativo) vuela recto y se dibuja donde está **a la hora del servidor** (con ping llega tarde,
  pero adelantado: todos lo ven en el mismo sitio). Se para donde dice `ProjectileEnd` o, antes, si
  en ese cliente choca con el mundo o con un mono (no espera al servidor); al pararse deja lo suyo
  (chispas, la explosión de la Bola de fuego). Los remates de las armas (C9b) son
  `<estilo>Finisher` (`StoneFinisher`, `ArrowFinisher`, `SpellFinisher` con su radio en `extra`,
  `DartFinisher`): más grandes, del color del remate y con estela; al disparar, `WeaponShotFx` con su
  tercer dato a `true` pone una chispa de ese color en el arma.
- **Telemetría**: `ShotsHit` / `ShotsMissed` por rol y place (`counts = false` en el abanico del
  Disparo múltiple y en la perforante, que fallan o atraviesan a propósito): la tasa de acierto real
  para la opción `acierto` de la calculadora.
- **Calculadora**: los golpes con `velocidad` y las armas a distancia cuentan con `OPCIONES.acierto`
  (1 − falla × distancia ÷ velocidad; contra monos 30 studs y 0,25/s, contra jugadores 35 studs y
  0,9/s, mínimo 0,5). Por eso el daño de las armas a distancia subió 1 punto y el de la perforante y la
  Bola de fuego 1–2 (mismo DPS real en la Isla), y `Config.Arena.WeaponMultipliers` compensa los
  duelos (arco 0,85, bastón 1,35, cerbatana 1,1, honda 1,2).

Probado en Play (Lobby, 22-10-2026, muñecos a 30 studs): honda a los 0,215 s (30 ÷ 140) con 9 de daño;
muñeco apartado 5 studs a los 0,11 s → la piedra pasa de largo hasta su alcance y no hay daño; un muro
delante la para y el de detrás no recibe; a través de una pieza que no choca, sí. Disparo múltiple: 5
flechas, una a cada muñeco a los 0,35 s (0,2 + 30 ÷ 200), 5 de daño. Flecha perforante en línea: los
tres, cada uno cuando le llega (+0,11 · 0,16 · 0,20 s), 12 de daño. Bola de fuego: 0,53 s, 20 de daño.
Dardo curativo: 0,33 s, 6. Cerbatana: 0,18 s, 11, y el veneno al impactar. Adelanto: blanco que cruza
a 16 studs/s, 3 de 3 (se dispara con él en z −19,9 y le da en −16,4).

Remate (C9b, Lobby, 22-10-2026, muñecos en fila a 30 studs, disparos cada `cooldown` + 0,05 s): arco
15 · 15 · 15 · **22** + 8 al de detrás (10 studs más allá) y el 5.º otra vez 15; bastón 10 · 10 · 10 ·
**14** + 5 de la explosión al de 4,5 studs, y cada 1,8 s (fuera del ritmo) ningún remate; honda 11 ·
11 · 11 · **15** y `StunnedUntil` +0,6 s; cerbatana 12 · 12 · 12 · **17**, el veneno 4/s y al propio
médico +2 (lo normal). En el cliente, los cuatro aspectos se distinguen de los normales.

## 7. Red y lag

**Hoy.** El cliente manda la intención (puntería, hueco de habilidad, "desde/hasta" del Parpadeo, que
el servidor acepta con `BLINK_POINT_SLACK`); el servidor comprueba recargas con margen (0,25 s en las
habilidades; en la esquiva, `Combat/Latency`) y decide el daño. Los movimientos propios (Embestida,
Parpadeo, Torbellino, esquiva) los hace el cliente, que simula su personaje: por eso el servidor no
puede empujar a un jugador poniéndole velocidad.
- `Combat/Latency.compensation(player)`: `Player:GetNetworkPing()` (segundos, aproximadamente de ida)
  sin pasar de `Config.Net.MaxCompensationSeconds` (0,15 s).
- **Rebobinado de proyectiles (V7):** en Dunas y el Laboratorio, el disparo de arma prueba a cada jugador
  donde estaba `lag` segundos antes (`PositionHistory`) y sale adelantado hasta 0,1 s. El origen que
  manda el cliente vale si cae a ≤ 5 studs de la cabeza rebobinada del tirador y sin pared (§3).
- `Combat/Knockback.push(modelo, dirección, velocidad, segundos)`: a un mono le pone la velocidad (y
  un pequeño salto); a un jugador le manda el remoto `Knockback` y lo aplica su cliente
  (`KnockbackController` → `Dash.push`); a un jefe, nada. Hasta C2 la Embestida **no empujaba a los
  jugadores a propósito** (`not target.player`); ahora sí, en PvP. Probado en Play: el remoto mueve al
  jugador 10,5 studs (45 studs/s, 0,2 s); la Embestida lanza a un mandril a 44 studs/s.
  Desde C4 lleva un `lift` opcional (studs/s hacia arriba): el remate de la cadena dado en el aire.
  El cliente lo suma como velocidad vertical después de `Dash.push` (que solo empuja en horizontal).
- `Config.Net.JitterSeconds` (C4, 0,05 s): margen fijo cuando el servidor comprueba un ritmo que el
  cliente lleva con su propio reloj (la cadena de golpes), además del de `Latency`.
- Rebote contra muros (C10): el servidor ve moverse a un jugador empujado **tarde** (en Studio, con
  ping ~0, lo ve empezar ~0,28 s después del remoto y llegar a los ~0,35 s). Por eso no comprueba la
  llegada en un instante: desde la llegada esperada (+ 2 × ping + `JitterSeconds`) mira en cada
  `Heartbeat` durante `WallBang.ArriveWindowSeconds` (0,5 s) si ya está contra la pared.

- Rebobinado (C3): el golpe con arma también vale contra donde estaba el objetivo hace
  `Latency.compensation(atacante)` segundos (`Hitbox.inBox` con `rewind`, `Combat/PositionHistory`).
  Las áreas no rebobinan: son generosas y así miden lo mismo que la calculadora.

- Margen del parry a favor del defensor (C5): `CombatService.damagePvP` con `waitForParry` (la cadena
  y los disparos de arma) espera `Guard.grace(defensor)` = `min(ping, Config.Net.ParryGraceMaxSeconds
  0,12)` antes de resolver (0 si ya está en guardia, si no podría abrir el parry o si es menos de un
  fotograma), y resuelve con la hora del golpe. La pulsación cuenta desde la hora que manda el cliente,
  como mucho ese margen antes de llegar. Lo que el golpe hace además del daño (tambaleo, empuje,
  veneno) va en `onResult`, porque puede resolverse más tarde. Las habilidades no esperan el margen:
  su preparación (C8) ya avisa antes, y el servidor la empieza `Latency.compensation` más corta.
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

**Escalado del combo en PvP (C7 ✅, `Combat/ComboScaling`, `Config.ComboScaling`).** Por víctima:
`damagePvP` con `guard` apunta cada golpe que entra (`Hit` o `Broken`) y multiplica su daño por
`damageFactor` (desde `FromHit` 4: −8 % por golpe, mínimo 0,5); el tambaleo de la cadena, por
`hitstunFactor` (−15 %, mínimo 0,4). Los golpes con la misma `hitKey` cuentan una vez (`AbilityService.hurt`
pone `"<UserId>:<habilidad>"`: el Torbellino es un golpe); el veneno (sin `guard`) no cuenta. Se
reinicia tras `ResetSeconds` 1 sin recibir, con un `Blocked`/`Parried` y con el Evasivo.

**Controles de jugadores (C7 ✅).** `Status.holdPlayer` con `cause == "PvP"` (lo que ponen las
habilidades, `AbilityService.control`) aplica además `Config.ControlDR` por jugador (1 → 0,8 → 0,6 →
0,4 → no entra hasta 6 s sin ninguno), después de mirar la inmunidad de 2 s; `stunPlayer` deja el
estado lo mismo que el agarre acortado. Los de monos, jefes y la guardia rota no cambian. Calculadora
(sección 9): 4 rivales controlándote con todo, 16 % del tiempo → 11 % (talentos al máximo 22 → 14 %).

Probado en Play (Isla): PvP 1,00 · 0,80 · 0,60 · 0,40 · INMUNE · INMUNE; un aturdido PvP seguido,
estado 1,00 y luego 0,80 (igual que el agarre); monos 1,00 · 1,00 · 1,00; escalado (copia del módulo)
golpes 1–3 ×1, 4.º ×0,92/0,85, … 9.º ×0,52/0,40, dos golpes con la misma clave cuentan uno, se reinicia
tras 1,05 s y con `reset`.

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
aviso.

**Rebote contra muros (C10 ✅, `Combat/Knockback`, `Config.WallBang`).**
- Lo hacen los empujones de un jugador: la Embestida, el Rompehuesos (nuevo en C10: aparta a los del
  cono `SmashKnockback` 30 studs/s durante 0,15 s, hacia fuera del guerrero) y el remate de la cadena.
  `Knockback.push(modelo, dirección, velocidad, segundos, lift?, atacante?)`: sin atacante no hay
  rebote (los empujes de monos y jefes no lo hacen). Los jefes no se empujan.
- Al empujar, `Hitbox.ray` desde la raíz por la trayectoria (velocidad × segundos + `BodyReach` 2,5).
  Es pared si la normal sube menos de `MaxNormalY` 0,6 (una ladera suave no estampa). Al llegar, la raíz
  tiene que estar a menos de `BodyReach` + `ArriveSlack` (1,5) del plano de la pared, mirado en cada
  `Heartbeat` durante `ArriveWindowSeconds` (§7): si se ha apartado o un mono se ha frenado antes, no
  rebota.
- El rebote (`CombatService` lo registra con `Knockback.onWallBang`): `WallBang.Damage` 5 y aturdido
  `StunSeconds` 0,5. A un mono, `Status.stun` (con el control decreciente: si ya iba aturdido o
  tambaleado, apenas alarga). A un rival, como el control de una habilidad: `damagePvP` sin guardia
  (× `pvpDamageMultiplier`) y `Status.stunPlayer(…, StunSeconds × pvpControlMultiplier, "PvP")`, que no
  alarga un aturdido que ya tenga; recién salido con el Evasivo (invulnerable), nada. Después,
  `ImmunitySeconds` 1,5 sin otro rebote al mismo. Efecto `WallBang` (hundimiento y grietas en la pared,
  polvo, piedrecitas y temblor), sonido `WallBang` (piedra contra la pared, C12) y telemetría `WallBangs` del que empuja.
- Probado en Play (Lobby, 22-10-2026) con un blanco suelto (`PlatformStand`) y un muro 6 studs detrás:
  Embestida −15 y a los 0,08 s rebote −4 y aturdido 0,5; Rompehuesos solo −23, aparta 3,4 studs y
  rebota a los 0,12 s; Embestida y Rompehuesos 0,7 s después: el segundo no rebota (inmunidad); remate
  del garrote −29 y rebote −4 a los 0,1 s; sin muro no rebota. Un jugador empujado contra el muro
  (remoto real + copia de `Knockback` del MCP): rebote a los 0,35 s.

**Zonas de peligro (C10 ✅, `Combat/Zones`, `Config.Zones`).**
- `Zones.create({ kind, owner, center, radius, seconds, tickSeconds, firstTick?, onTick })`: un solo
  bucle de `Heartbeat` para todas (lo arranca `CombatService:Start`); cada zona llama a su `onTick`
  mientras dura y se quita si se va su dueño. Quien la crea (`AbilityService`) decide a quién alcanza
  (solo monos y rivales de quien la pone) y qué le hace. Todos los clientes la dibujan igual: efecto
  `Zone` (`AbilityFxController`), con baldosas voxel que siguen el suelo (`groundTiles`: en una ladera
  no se entierran).
- **Fuego** ("Fire"): el Meteoro que cierra "Lluvia de estrellas", igual que antes (`MeteorBurnTicks`
  golpes de `MeteorBurnDamage`, uno por segundo, a quien siga en el radio).
- **Hielo** ("Ice"): cada Nova deja su radio helado `Ice.Seconds` 3 s. Cada `TickSeconds` 0,25 s, a quien
  está dentro (`targetsOnGround`, `Height` 5): lento ×`Ice.SlowFactor` 0,6 durante tick + `LingerSeconds`
  (no recorta una lentitud más fuerte y más larga: `Status.slow`) y, a un rival donde las habilidades
  le ralentizan (`pvpStatus`), `SlipperyUntil` en el personaje: su cliente (`ZoneController`) resbala
  (una `LinearVelocity` de fuerza limitada cuya velocidad sigue a la que quiere con `Traction` 3/s;
  cede ante otro empuje). Medido: con W tarda ~0,3 s en coger velocidad y al soltar se desliza ~1 s
  (sin hielo, de 16 a 0 en un fotograma).
- **Nube** ("Cloud"): la del Polvo se queda `Cloud.Seconds` 3 s desde que cae: a quien entra le entra
  sueño (lento ×`PowderSlowFactor`, renovado cada tick), sin dormirle; a los jefes, nada. Los que
  estaban al caer se duermen como antes.
- Probado en Play (Lobby): hielo (el de dentro sigue ×0,5 de la Nova y luego ×0,6 de la zona; el que
  entra a 1 s, ×0,6 cada 0,25 s hasta los 3 s), nube (el de dentro se duerme 1,5 s; el que entra a
  1,5 s solo va lento) y fuego (−8 a +1, +2 y +3 s tras el Meteoro rematado).

**Coberturas que se rompen (C11, Dunas; `Combat/Destructibles`, `CoverService`, `Config.Arena.Covers`).**
- Las 16 estelas y las 4 columnas de pie de la arena son modelos con la etiqueta
  `Config.Combat.DestructibleTag` (`World/ArenaBuilder` v5; su zócalo o su basa se quedan). Las columnas
  caídas y los altares bajos del carril no se rompen: siempre queda algo detrás de lo que ponerse.
- El combate solo dice qué las alcanza (`Destructibles.blast` para un área, `inBox` para la caja del
  remate de la cadena, `hitPart` para el proyectil que se para en una, con `breaks` en el `Shot`), con
  una tabla `once` por uso (cada cobertura una vez: las flechas del abanico, las vueltas del
  Torbellino) y línea de visión desde el centro (lo de detrás de una pared no se rompe). Tipos:
  `Ability` (las de daño: Torbellino, Embestida, Pisotón, Rompehuesos, Disparo múltiple, Lluvia,
  Flecha perforante, Bola de fuego, Nova, Meteoro; el Rayo encadenado no), `Ultimate`, `Finisher` y
  `ShotFinisher`. Los golpes normales no las rompen. Sin modelos con la etiqueta (Isla, Lobby), no hace nada.
- `CoverService` (Dunas) les quita la piedra de `Damage`, solo durante la partida. Sin piedra: no se
  ven, no chocan, no tapan (las áreas y los disparos pasan) y vuelven a los `RespawnSeconds` (45 s) en
  cuanto no hay nadie dentro. Al empezar la partida y al volver a esperar, todas enteras. Lo publica en
  atributos del modelo (`CoverHealth`, `CoverMaxHealth`, `CoverBroken`); `CoverController` dibuja las
  esquirlas de cada golpe, las grietas voxel con dos tercios y un tercio de piedra, los trozos que caen
  (anclados, movidos por el cliente: no empujan a nadie) y el polvo. Son modelos atómicos para el
  streaming. Telemetría `CoversBroken` (quien la rompe).
- Probado en Play (Dunas): Torbellino −25 una sola vez, Rompehuesos −25, remate del garrote −20, 4.º
  disparo del bastón −20 una vez (toca y estalla), Bola de fuego −25, Pisotón la rompe de golpe; rota,
  un rayo la atraviesa; vuelve a los 45,0 s, y con el jugador dentro espera hasta que se aparta (0,9 s).

**Altar de la pirámide (C11, Dunas; `AltarService`, `AltarController`, `Config.Arena.Altar`).**
- En la cima de la pirámide del centro (`Arena.Altar`: pilares con gema, glifo, haz de luz y la pieza
  `Captura`, su centro). Se enciende a los `FirstSeconds` (30 s) de empezar y lo toma el equipo que se
  queda a `CaptureRadius` (7 studs en horizontal, hasta 8 por encima) `CaptureSeconds` (6 s) sin
  rivales: con los dos equipos se para (disputado), si entra el otro solo primero la vacía, y sin nadie
  se vacía en `DecaySeconds` (12 s). Da `BuffSeconds` (30 s) con la definitiva de todo el equipo ×2 (30 s
  menos de espera; la recarga en `AbilityReadyAt<hueco>` avanza de más). Vuelve a los `RespawnSeconds`
  (75 s). Atributos en `ReplicatedStorage` (`AltarState`, `AltarProgress`, `AltarTeam`,
  `AltarContested`, `AltarBuffTeam`, `AltarBuffUntil`, `ArenaAltars_<equipo>`, en la cabecera del
  servicio). Se ve: haz y gemas blancos encendido, del color del equipo que lo toma, parpadeo disputado;
  cartel con la barra; línea en el HUD bajo la de la fase y en los resultados. Telemetría `AltarCaptures`.
- Probado en Play (Dunas, un jugador): se toma en 6,0 s; la barra baja sola (−0,25 en 3 s); con 2 s de
  ventaja, la V baja 7 s en 5 s (2 × 2 + 3); acaba y vuelve al ritmo normal. Sin probar: disputado
  (hacen falta dos equipos).

**Barreras del templo (C11).** Delante de la cara del basamento de cada templo (sus relieves hacían de
peldaño: el glifo en rombo, a 45°) y por los otros tres bordes de su terraza hay piezas invisibles que
chocan sin rayos ("Barrera"): antes se subía al basamento y se salía de la arena por detrás.

## 10. Controles

| Acción | PC | Mando | Móvil |
|---|---|---|---|
| Arma | Clic | Gatillo (R2) | Tocar la pantalla |
| Disparo automático (V8, dardos del Laboratorio) | Mantener el clic | Mantener R2 | Mantener el toque |
| Recargar (V8, solo Laboratorio) | R | X | "Recargar" |
| Habilidades Z X C R V | Teclas | Mantener R1 + A, B, X, Y, L1 | 5 botones junto al salto |
| Esquivar | Q | B | "Esquivar" |
| Correr | Mayús | L3 | "Correr" |
| Deslizar (V2) | Alt izquierdo (C en el Laboratorio) | R3 | "Deslizar", el botón Correr mientras corres |
| Guardia (C5 ✅) | F (caído: Rendirse) | L2 | "Guardia", encima de "Esquivar" |
| Beber (Isla) | E (antes F) | X | Tocar el aviso |
| Evasivo (C7 ✅) | Q estando atrapado | B estando atrapado | "¡Evasivo!" (el de "Esquivar") |
| Bloqueo de cámara (C2) | Ctrl (el shift lock de Roblox; el jugador lo enciende en el menú de Roblox) | — | — |

La misma tabla, para el jugador, en Ajustes → "Controles del combate" (`SettingsPanel.CONTROLS`, C12): si
cambia una tecla, cámbiala también allí. La guía del Lobby enseña la guardia con el muñeco de sparring
(`LobbyGuideController`, paso "Sparring"; se completa con `ParryAt` y se guarda en `combatGuideDone`).

El shift lock: `EnableMouseLockOption = true` en los tres `*.project.json` y `CameraLockController`
cambia las teclas de Mayús a Ctrl. El `PlayerModule` de Roblox se carga hoy desde
`StarterPlayer.PlayerModule` (no se copia a `PlayerScripts`) y lee las teclas del sistema de acciones
de entrada: `InputContexts.CameraContext.MouseLockSwitchAction` con un `InputBinding` por tecla
(`KeyboardPrimaryBinding`, `KeyboardSecondaryBinding`). El controlador cambia su `KeyCode`; para un
`PlayerModule` antiguo cambia su valor `BoundKeys`. La acción solo se activa si el jugador tiene el
bloqueo de cámara encendido en sus ajustes de Roblox (`GameSettings.ControlMode`).
