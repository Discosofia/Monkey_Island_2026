# Cómo funciona el combate (mecánicas, detección y red)

Estado del repo el 22 de octubre de 2026, al empezar la Fase 10 ("Combate v2", `docs/PLAN.md`).
Cada apartado dice **qué hay hoy** y, si cambia, **qué está planificado** y en qué grupo (C1–C13).
Cuando un grupo se cierra, actualiza aquí su apartado: lo planificado pasa a ser lo que hay. Si algo
no coincide con el código, manda el código.

## 1. Mapa

| Pieza | Hoy | Fase 10 |
|---|---|---|
| Golpe con arma | `CombatService.onUseWeapon` → `meleeAttack` / `rangedAttack` | Cadena de 4 golpes (C4), proyectiles reales (C9) |
| Esquiva | `DodgeController` (cliente: empuje con `Dash.push`) + `CombatService.onDodge` (invulnerabilidad, estamina del servidor) | Evasivo (C7) |
| Estados del jugador | `Shared/CombatState` + `Combat/StateMachine` (C2 ✅) | Guardia, cadena, Evasivo… (C4–C8) |
| Estados de enemigos | `Combat/Status` (atributos del modelo) | Control decreciente por modelo (C6) |
| Detección | Distinta en cada sitio | `Combat/Hitbox` para todo (C3) |
| Defensa | Esquiva, armadura, Grito de guerra, Escudo de hojas | Bloqueo, parry y guardia (C5) |
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
- Hoy solo entra `Stunned` (con `Status.stunPlayer`); los demás estados los usan los grupos C4–C8.
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
- Cliente (`WeaponController`): al activar la Tool reproduce el tajo (cuerpo a cuerpo) o el disparo
  (distancia, `Data/WeaponAnimations`) y manda `Remotes.UseWeapon:FireServer(puntería)`.
- Servidor (`CombatService.onUseWeapon`): espera `cooldownSeconds` del arma (`os.clock`).
  - Cuerpo a cuerpo (`meleeAttack`): **una caja** de `MELEE_HITBOX` (7 × 6) × `range` delante de la
    raíz, con `GetPartBoundsInBox`, **en el instante y sin mirar paredes**. Un golpe suelto, sin
    preparación ni recuperación.
  - Distancia (`rangedAttack`): munición (`CombatRules.useAmmo`); ayuda de puntería
    (`findAimTarget`, cono `aimAssistDegrees` y `aimDeviation`) con un rayo de línea de visión. Si
    encuentra un mono, el proyectil visible vuela hacia él y el daño llega con `task.delay` **aunque
    el mono se haya apartado**. Contra un jugador solo vale un rayo directo (sin ayuda): asimetría.
- PvP: daño del arma × `pvpWeaponMultiplier` × `pvpWeaponMultipliers[arma]` (arena: ×0,55, arco ×0,7).

**Planificado.** C4: `chain` en `Data/Weapons` (4 pasos con preparación, activo, recuperación,
multiplicador y caja; el 4.º remata empujando, o lanza hacia arriba si el atacante va en el aire),
búfer de entrada en el cliente, tambaleo corto por golpe en PvP. El hacha y el pico siguen con el
golpe suelto. C9: proyectiles simulados por el servidor (ver §6).

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

**Hoy.** Orden de `CombatService.damagePlayer` (monos y peligros): zona segura, invulnerable o caído
→ crítico del atacante → `mitigate`: armadura (`Data/Armor`) → tótem guardián (`WardReduction`) →
Grito de guerra (`GuardReduction`) → Escudo de hojas (`ShieldHealth`, absorbe). `damagePvP`: marca y
expuesto (con `pvpStatus`) → crítico → `mitigate`. No hay bloqueo ni parry.

**Planificado (C5).** Remoto `Guard` (F / L2 / botón "Guardia"; al estar caído, F sigue siendo
Rendirse). Barra `Guard` (0–100). Bloqueo de frente (cono en `Config`): reduce el daño y gasta
guardia con el `guardDamage` del ataque; vacía → `GuardBroken` (aturdido). Parry: ventana desde que se
pulsa (~0,3 s, igual para todos), se rearma tras un tiempo; anula el golpe, tambalea al atacante y
devuelve guardia. Margen a favor del defensor: el servidor espera el parry hasta `min(ping, tope)`
antes de aplicar un golpe. Imbloqueables (`unblockable`) rompen la guardia. Orden nuevo: invulnerable
→ parry → bloqueo → armadura → tótem → Grito → escudo.

## 6. Detección de impactos

Regla: **nunca `.Touched`**. Una consulta en el servidor en el instante del impacto, con filtros que
excluyen al atacante, los efectos y lo que no colisiona, y una tabla para dañar a cada objetivo una
sola vez por ataque.

| Ataque | Hoy | Planificado |
|---|---|---|
| Golpe con arma | `GetPartBoundsInBox` en el instante, sin paredes | `Hitbox.sweepBox` (`Blockcast`) en el instante activo, con posiciones rebobinadas y `visible` (C3, C4) |
| Disparo de arma | Rayo + ayuda; daño con retraso aunque se aparte | Proyectil del servidor: un `Spherecast` por paso de `Heartbeat` (C9) |
| Habilidades que viajan | `castShot` (`Spherecast` en el instante) + daño con retraso | El mismo proyectil por pasos (C9) |
| Áreas (`targetsAround`, `targetsOnGround`) | **Solo distancia: atraviesan paredes** | `inSphere`/`inBox` + `visible` desde el centro (C3) |
| Ayuda de puntería (`bestInCone`, `findAimTarget`) | Cono + rayo de línea de visión | Igual, solo orienta la dirección inicial; mismo cono para todos (C9) |
| Mordisco de mono | Distancia al empezar el ataque, daño en el mismo instante | Preparación visible y `inBox` + `visible` al acabarla (C6) |
| Empujes | El cliente corta el empuje propio contra una pared | Rayo por la trayectoria en el servidor: rebote contra muros (C10) |

`Combat/Hitbox` (C3): `ray`, `sweepSphere`, `sweepBox`, `inBox`, `inSphere`, `visible` y `rewound`
(con `Combat/PositionHistory`: posiciones del último segundo a 20 Hz). Las áreas consultan solo las
piezas de personajes y monos (lista de inclusión por etiquetas).

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

**Planificado.** C3: rebobinar posiciones al golpear, con tope.
C5: margen del parry a favor del defensor, con tope. Regla de equidad: el tope nunca pasa de ~0,15 s
y es el mismo para todos.

## 8. Control y escape

**Hoy.** Enemigos: `Status.stun` (aturdir, congelar, inmovilizar y dormir son lo mismo para la IA),
sin rendimientos decrecientes; los jefes se quedan `BossControlMultiplier` (0,5). Jugadores:
`holdPlayer` con inmunidad de 2 s. En PvP: control ×`pvpControlMultiplier` (Isla 0,5, arena 0,5).

**Planificado.** C6: rendimientos decrecientes por modelo (100 → 50 → 25 % → inmune, se reinicia) y
jefes aparte. C7: escalado en PvP por víctima (daño y tambaleo bajan con cada golpe seguido, con
mínimo; se reinicia tras ~1 s sin recibir) y Evasivo.

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
| Guardia (C5) | F | L2 | "Guardia" |
| Evasivo (C7) | Q estando aturdido | B estando aturdido | "Esquivar" estando aturdido |
| Bloqueo de cámara (C2) | Ctrl (el shift lock de Roblox; el jugador lo enciende en el menú de Roblox) | — | — |

El shift lock: `EnableMouseLockOption = true` en los tres `*.project.json` y `CameraLockController`
cambia las teclas de Mayús a Ctrl. El `PlayerModule` de Roblox se carga hoy desde
`StarterPlayer.PlayerModule` (no se copia a `PlayerScripts`) y lee las teclas del sistema de acciones
de entrada: `InputContexts.CameraContext.MouseLockSwitchAction` con un `InputBinding` por tecla
(`KeyboardPrimaryBinding`, `KeyboardSecondaryBinding`). El controlador cambia su `KeyCode`; para un
`PlayerModule` antiguo cambia su valor `BoundKeys`. La acción solo se activa si el jugador tiene el
bloqueo de cámara encendido en sus ajustes de Roblox (`GameSettings.ControlMode`).
