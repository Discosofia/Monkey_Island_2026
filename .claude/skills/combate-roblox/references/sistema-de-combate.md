# Cómo funciona el combate (mecánicas, detección y red)

Estado del repo el 22 de octubre de 2026, al empezar la Fase 10 ("Combate v2", `docs/PLAN.md`).
Cada apartado dice **qué hay hoy** y, si cambia, **qué está planificado** y en qué grupo (C1–C13).
Cuando un grupo se cierra, actualiza aquí su apartado: lo planificado pasa a ser lo que hay. Si algo
no coincide con el código, manda el código.

## 1. Mapa

| Pieza | Hoy | Fase 10 |
|---|---|---|
| Golpe con arma | `CombatService.onUseWeapon` → `meleeAttack` / `rangedAttack` | Cadena de 4 golpes (C4), proyectiles reales (C9) |
| Esquiva | `DodgeController` (cliente: empuje con `Dash.push`) + `CombatService.onDodge` (invulnerabilidad) | Estamina del servidor (C2), Evasivo (C7) |
| Estados del jugador | Atributos sueltos en el `Player` | `Shared/CombatState` + `Combat/StateMachine` (C2) |
| Estados de enemigos | `Combat/Status` (atributos del modelo) | Control decreciente por modelo (C6) |
| Detección | Distinta en cada sitio | `Combat/Hitbox` para todo (C3) |
| Defensa | Esquiva, armadura, Grito de guerra, Escudo de hojas | Bloqueo, parry y guardia (C5) |
| Empujes | La Embestida pone `AssemblyLinearVelocity` al objetivo | `Combat/Knockback` (C2) y rebote contra muros (C10) |
| Reglas por place | `Combat/CombatRules` | Campos nuevos de guardia, escalado y entorno |

## 2. Estados

**Hoy.** No hay máquina de estados: cada cosa es un atributo con la hora del servidor en que termina.
- Jugador: `StunnedUntil` (solo le pone `WalkSpeed` a 0 en `SurvivalController` y en el
  `MovementController` de Dunas; **puede pegar, usar habilidades y esquivar**), `ControlImmuneUntil`,
  `InvulnerableUntil` (esquiva), `GuardUntil`/`GuardReduction` (Grito), `ShieldUntil`/`ShieldHealth`
  (escudo), `IntimidatedUntil` (rugido del mandril), `MovementLocked` (portador de la bandera en
  Dunas), `SlowedUntil`/`SlowFactor` en el personaje (PvP con `pvpStatus`).
- Todo control sobre un jugador pasa por `Status.holdPlayer(player, segundos, causa)`: no se alarga
  mientras dura y al soltarse hay `Config.Combat.PlayerControlImmunitySeconds` (2 s) de inmunidad.

**Planificado (C2).** `Shared/CombatState` (funciones puras, lo leen cliente y servidor) con los
estados `Idle`, `Attacking` (preparación, activo y recuperación), `Casting`, `Blocking`, `Parrying`,
`Dodging`, `Evading`, `Staggered`, `Stunned`, `GuardBroken` y `Downed`, y las condiciones que se
suman `Rooted`, `Slowed`, `Invulnerable` y `Launched`. Prioridades en `Config.CombatStates` y
`canAct(estado, acción)`. `Combat/StateMachine` en el servidor publica `CombatState` y
`CombatStateUntil` en el `Player` y usa un "ticket" por jugador para que un temporizador viejo no
libere antes de tiempo. **Aturdido** (no anda, no pega ni usa habilidades; sí el Evasivo) y
**inmovilizado** (no anda; sí pega) se separan: `Status.stunPlayer` y `Status.holdPlayer`.

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

**Hoy.** Q / B / botón "Esquivar". El cliente gasta estamina (`combatClient/Stamina`, **solo en el
cliente**: el servidor no la valida), empuja con `Dash.push` (fuerza limitada, se corta contra una
pared) y manda `Remotes.Dodge`. El servidor acepta una cada `DodgeCooldownSeconds × 0,8` y pone
`InvulnerableUntil` (`DodgeInvulnerableSeconds`, 0,35 s): `damagePlayer` y `canHitPlayer` lo respetan.

**Planificado.** C2: estamina con autoridad del servidor (`Combat/StaminaServer`, atributo `Stamina`;
el cliente predice con la misma fórmula). C7: **Evasivo**, la misma esquiva pulsada estando
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
habilidades, ×0,8 en la esquiva) y decide el daño. Los movimientos propios (Embestida, Parpadeo,
Torbellino, esquiva) los hace el cliente, que simula su personaje. **Consecuencia:** el servidor no
puede empujar de verdad a un jugador poniéndole velocidad (el retroceso de la Embestida contra
jugadores probablemente no funciona; se comprueba en C2).

**Planificado.** C2: `Combat/Latency` (`GetNetworkPing` con tope) y `Combat/Knockback` (a un jugador
lo empuja su propio cliente con el remoto `Knockback`). C3: rebobinar posiciones al golpear, con tope.
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
| Bloqueo de cámara (C2) | Ctrl (el shift lock de Roblox, `BoundKeys`) | — | — |
