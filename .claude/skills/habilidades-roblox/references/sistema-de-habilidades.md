# Cómo funcionan las habilidades del juego

Estado del repo en octubre de 2026. Si algo de aquí no coincide con el código, manda el código: léelo
y corrige esta página.

## 1. Mapa: quién tiene habilidades y dónde viven

| Quién | Datos (números) | Lógica (servidor) | Lo que se ve (cliente) |
|---|---|---|---|
| Jugador (5 por rol: Z, X, C, R y la definitiva V; la R es el hueco 5) | `src/shared/Data/Roles.luau` (id, nombre, recarga), `Config.Abilities` (daños, radios, duraciones), `Data/Perks`, `Data/Talents` | `src/combat/Services/AbilityService.luau` (un *handler* por habilidad) | `RoleController` (teclas, casillas, movimientos propios), `AbilityFxController` (efectos), `Data/PlayerAnimations.Abilities` (gesto) |
| Combos (2 por rol, de 3 habilidades en orden, que se conectan) | `Data/Combos.luau`, `Config.Combo` | `Services/ComboService.luau` | `ComboController` (indicador y racha), iconos de marca en `AbilityFxController` |
| Críticos | `Config.Crit`, `critChance` en `Data/Weapons` | `src/shared/Crit.luau` (funciones puras), los tira `CombatService` | `CombatTextController`, `ComicFxController` |
| Estados de enemigos (aturdido, lento, provocado) | `Config.Abilities.BossControlMultiplier` | `src/combat/Status.luau` | contornos (servidor) y hielo/brillo verde (`AbilityFxController`) |
| Monos (ataques especiales) | campos de `Data/Monkeys.luau` (`pounce`, `roar`, `throws`, `grab`, `stomp`, `howl`, `thief`…), `Config.Monkeys`, `Config.Difficulty` | `Services/MonkeyService.luau` (`think`, `bite`, `pounce`, `roar`, `throwStone`, `stomp`, `howl`, `steal`) | `MonkeyAnimator` + `Data/MonkeyAnimations`, burbujas de texto |
| Jefes (especiales por fase) | `Data/Bosses.luau` (`specials`) | `Services/BossService.luau` (`SPECIALS`, `tick`, `updatePhase`) y peligros de `Combat/Hazards.luau` | marcas de aviso en el suelo (Hazards), `AbilityFx` "Quake", animaciones |
| Mascotas | `Data/Pets.luau` (`attackDamage`, `healPerTick`, `tracks`, `perks`), `Config.Pets` | `Services/PetService.luau` (cada 2 s) | `src/shared/UI/PetFollowers.luau` (salto al mono), rastreo en el cliente |
| Telemetría (usos, combos, daño y curación por fuente, tiempo quieto, caídas, jefes) | | `Services/TelemetryService.luau` → `ServerShared/Analytics` | Creator Hub → Analítica |

Remotos (`src/shared/Remotes.luau`): `UseAbility` (cliente → servidor: hueco, puntería, desde, hasta),
`AbilityFx` (servidor → clientes: tipo de efecto y datos), `PetAttack`.

## 2. Habilidades del jugador

### 2.1 Recorrido de un uso

1. **Cliente** (`RoleController.useAbility`): comprueba rol, vida, `AbilityReadyAt<hueco>` y que no
   se mandó hace menos de 0,5 s. Calcula la puntería (`Aim.direction`). Las de **movimiento** las
   hace el propio cliente, que es quien mueve a su personaje: `Charge` (empuje), `Blink`
   (teletransporte, manda `from`/`to`) y `Whirlwind` (giro). Pone el gesto con
   `BodyAnimations.playAbility(id)` y manda `Remotes.UseAbility:FireServer(slot, aim, from, to)`.
2. **Servidor** (`AbilityService.onUseAbility`): valida tipos, rol, vida, `LifeState.isAlive` y la
   recarga (con 0,25 s de margen por la red). Llama a `ComboService.onAbilityUsed` **antes** del
   handler (así el handler ya sabe si va enlazado) y luego a `HANDLERS[id](player, character, root,
   aim, { from, to })`.
3. El handler devuelve `true` si la habilidad se usó. **Si devuelve `false` no gasta recarga** (el
   Rayo encadenado sin mono a tiro).
4. Recarga = `cooldownSeconds × Perk CooldownRate × ComboService.cooldownFactor` → atributo
   `AbilityReadyAt<hueco>` (hora del servidor). El cliente pinta la casilla con él.

### 2.2 Piezas comunes de `AbilityService`

| Función | Para qué |
|---|---|
| `targetsAround(attacker, centro, radio)` | enemigos vivos con la etiqueta `Enemy` y jugadores con PvP en una esfera |
| `targetsOnGround(attacker, centro, radio, alto)` | igual pero en horizontal (cosas en el suelo, laderas) |
| `bestInCone(attacker, character, origen, puntería, alcance, grados)` | el mejor alineado y sin obstáculos |
| `castShot(character, origen, dirección, alcance, radio)` | disparo recto con `Spherecast`: punto final y a qué dio |
| `targetFromPart`, `enemyTarget`, `playerTarget` | de una pieza a un `Target` |
| `groundBelow(posición, ignorar)` | suelo y su normal (para apoyar cosas) |
| `hurt(attacker, target, cantidad, abilityId)` | daño de habilidad: PvP ×`PvPDamageMultiplier`; crítico seguro si es golpe de combo, si no, con la probabilidad del arma |
| `control(target, segundos, "Stun" \| "Freeze" \| "Root")` | aturde/congela/inmoviliza (jugadores con PvP: ×`PvPControlMultiplier`) |
| `heal(healer, player, cantidad, abilityId)` | curación con críticos (seguro si es el remate) |
| `comboOpener(player, abilityId, target)` | marca el objetivo si es el paso 1 del combo |

Los proyectiles con viaje (Bola de fuego, Dardo, flechas) aplican el daño con `task.delay` al
tiempo de vuelo, a la vez que el efecto que dibujan los clientes.

### 2.3 Orden de los multiplicadores de daño (jugador → mono)

1. Número de `Config.Abilities` × ventajas (`MeleeDamage`, `RangedDamage` o `SpellDamage` del rol,
   más la del talento de esa habilidad) y, si toca, extras del remate del combo.
2. `hurt`: redondeo; contra jugadores ×0,5 y crítico del arma; contra monos, crítico = combo seguro
   **o** tirada del arma.
3. `CombatService.damage`: ×`Config.Combat.PlayerDamageMultiplier` (0,7; no a mascotas) →
   intimidado por un mandril ×0,7 → marcado por un cazador ×(1 + `MarkBonus`) → expuesto (dormido
   por la Nana del médico) ×(1 + `ExposedBonus`) → crítico ×`Config.Crit.Multiplier` (1,35) →
   `TakeDamage`, número flotante (morado si es veneno), `ComboService.onActivity`, oyentes
   (`BossService` apunta participantes).

Daño a un jugador (`CombatService.damagePlayer`): no en el Basecamp, esquivando ni caído → crítico
del mono/jefe (`Crit.sourceChance`) → `mitigate`: armadura (`Data/Armor`) → Grito de guerra
(`GuardUntil`/`GuardReduction`) → Escudo de hojas (`ShieldHealth`, absorbe) → fiebre por mordisco →
si es mortal, `LifeService.down`.

### 2.4 Estados

- **Enemigos** (`Combat/Status`): `StunnedUntil` (aturdir, congelar e inmovilizar son lo mismo para
  la IA: ni anda ni ataca; cambia solo cómo se ve), `SlowedUntil` + `SlowFactor`, `TauntedBy` +
  `TauntedUntil`. Los jefes se quedan la fracción `BossControlMultiplier` (0,5). **No hay
  rendimientos decrecientes**: un aturdimiento nuevo solo alarga si acaba más tarde. Los leen
  `MonkeyService.think`/`siegeThink` y `BossService.tick` en cada vuelta.
- **Marca del cazador**: `MarkedUntil` + `MarkBonus` en el modelo (+ `Highlight`).
- **Veneno** (`Status.poison(modelo, dps, segundos, atacante, fuente)`): un golpe cada
  `Config.Abilities.PoisonTickSeconds` (1 s) por `CombatService.damage` con `poison = true` (número
  morado, sin destello ni sonido, sin crítico; cuenta para la racha y el botín de quien lo puso). No
  se acumula: uno igual o más fuerte lo renueva y uno más flojo no hace nada mientras dure. El cliente
  dibuja vapor morado con el atributo `PoisonedUntil`. Lo usan las cerbatanas (`poison` en
  `Data/Weapons`, con la ventaja de daño del arma) y el remate de "Cura de urgencia". Los dardos
  venenosos del médico son munición opcional (`boostItemId` del veneno de la cerbatana): mientras
  queden, cada disparo gasta uno y el veneno se multiplica por su `poisonMultiplier` (Data/Items). Status no depende de CombatService:
  CombatService le da la función de daño al empezar (`Status.setPoisonDamage`).
- **Expuesto** (`Status.expose(modelo, bonus, segundos)`): `ExposedUntil` + `ExposedBonus`, recibe más
  daño. Lo pone el remate de "Nana de la selva" a los dormidos; el "💤" lleva debajo "+30 %".
- **Jugadores**: `StunnedUntil` solo pone `WalkSpeed` a 0 en `SurvivalController` (puede atacar,
  usar habilidades y esquivar). Se pone **siempre** con `Status.holdPlayer(player, segundos, causa)`:
  mientras dura otro no lo alarga y al acabar hay `Config.Combat.PlayerControlImmunitySeconds` (2 s)
  de inmunidad (`ControlImmuneUntil`). Devuelve false si no ha sujetado (para no avisar de un agarre
  que no ha entrado). `IntimidatedUntil` (rugido),
  `GuardUntil` (grito), `ShieldUntil`/`ShieldHealth` (escudo), `InvulnerableUntil` (esquiva).

### 2.5 Combos (`Data/Combos`, `ComboService`, `Config.Combo`)

- Dos combos por rol (`Data/Combos[rol]` es una lista). Cada uno empieza con una habilidad distinta y
  la que se usa primero decide cuál está en marcha (`ComboIndex`). Una habilidad que es paso 1 de un
  combo y paso 2 o 3 del otro (Grito, Marcar, Bola de fuego, Escudo) enlaza el combo en marcha si toca
  y, si no, abre el suyo.
- **Conexión** (`complete`): al cerrar un combo, el otro queda en su paso 1 con las marcas alargadas y
  lo que golpee o cure el remate se marca (`ComboService.touch`, desde `hurt` y `heal`). Un combo
  cerrado así sube la racha `ConnectStreakBonus` más; `ComboChain` cuenta los seguidos y
  `ComboConnected` dice si el combo en marcha vino de una conexión. El "¡COMBO!" (paso 3) se ve
  1,5 s (`displayUntil`) y luego se publica el paso 1 del siguiente.
- Los remates de los segundos combos (la habilidad nueva de cada rol) usan `isPayoff` como los otros;
  `payoffs` guarda una hora por habilidad, así un paso nuevo no corta el remate anterior (el Torbellino
  sigue girando con críticos aunque ya hayas enlazado la Embestida del otro combo).

- Paso 1 (prepara): el handler llama a `comboOpener`/`ComboService.opener` cuando **toca** algo;
  lo marca (`ComboMarkBy`/`ComboMarkUntil`) y empieza el combo.
- Pasos 2 y 3: usar la siguiente antes de `StepWindowSeconds` (6 s) la enlaza. Si la siguiente aún
  se está recargando, los 6 s cuentan desde que esté lista (`stepDeadline`, con `AbilityReadyAt<hueco>`;
  la marca dura lo mismo): el combo no se pierde por haber usado antes suelta una de sus habilidades. Durante
  `PayoffSeconds` sus golpes contra los marcados son críticos seguros y hacen `damageBonus` de su
  combo más de daño (`isComboHit` + `linkedDamageBonus`, en `AbilityService.hurt`), y el handler
  puede dar un extra con `ComboService.isPayoff(player, id)` (más flechas, más giro, radio…).
  `damageBonus` va por combo (+25 % guerrero, +10 % cazador, nada el mago) porque cada rol cierra
  combos con distinta frecuencia y su remate pega distinto (`linkedDamageBonus(player, id)`).
- Cada paso enlazado que no sea la definitiva le quita `UltRefundSeconds` (10 s) a la recarga de la
  V, como mucho `UltRefundMaxSeconds` (20 s) por recarga (`State.ultRefunded`, vuelve a 0 al usar la
  V): sin tope, el rol con los pasos más baratos (el mago) la lanzaba casi el triple. Cada combo completo sube la racha (x1…x5): desde x2, recargas un `StreakCooldownBonus` (4 %; era 8 % con un combo por rol)
  más rápidas por nivel; se pierde tras `StreakSeconds` sin dañar ni curar.
- Ningún combo usa la definitiva. El cliente predice el remate con `ComboController.nextStep`
  (el Torbellino gira más en el propio cliente).

### 2.6 Críticos (`Shared/Crit`)

Habilidades del jugador: la probabilidad del arma de la mano o, si no es un arma, la de la mejor que
lleve (5 % básica, 10 % y 15 % con las mejoras de la forja). Curaciones del médico: 10 % + la del
arma + 30 % si el aliado tiene menos del 35 % de vida. Mascotas 10 %. Monos de categoría 2/3: 15/20 %.
Jefes 25 % (28 % en furia). Panel de pruebas: "Críticos al 100 %".

### 2.7 Lo que se ve y se oye

- Efectos: `AbilityFx.all(tipo, …)` (todos) o `AbilityFx.others(player, tipo, …)` (los demás; el
  propio cliente ya lo dibujó). Cada tipo es una función en la tabla `EFFECTS` de
  `AbilityFxController`, con un comentario de qué datos recibe. Lo que dura (diana de marca,
  burbuja de escudo, iconos de combo) sale de **atributos** que vigila el cliente, no del evento.
- Gesto del cuerpo: `Data/PlayerAnimations.Abilities[id] = "CastForward" | "CastArea" | "Place" |
  "Quake" | "WarCry" | "Charge"…`. Un gesto nuevo se hace con la skill `animaciones-roblox`.
- Sonido: `Sfx.play(nombre, dónde)` con claves de `Data/Sounds`.
- Avisos: `Remotes.Notify:FireClient(player, texto)`.

### 2.8 Interfaz y textos

- Casillas bajo las barras y botones táctiles: `short` de `Data/Roles` (cabe ~9 letras).
- Lobby (`LobbyUIController`): lista los nombres por rol con `passive`.
- Ajustes → vista previa (`src/shared/UI/SettingsPanel.luau`, tabla `ABILITY_INFO`): qué número de
  `Config.Abilities` enseña cada habilidad y qué ventajas lo multiplican.
- Documento de diseño: `docs/GDD.md` §6.3 (tabla de roles y recargas) y §6.4 (críticos y combos).

### 2.9 Progresión que toca a las habilidades

- `Data/Perks`: valor por defecto de cada ventaja (p. ej. `WhirlwindSeconds = 2`, `ChainJumps = 4`).
- `Data/Talents`: 4 por rol, uno por habilidad (el del médico también su pasiva); `perRank` ×
  `maxRank` (3 rangos casi siempre).
- `Data/Upgrades` (tienda) y `Data/Pets.perks` también suman ventajas. `Progression.computePerks`
  lo suma todo y `RoleService` lo publica como atributos `Perk_<nombre>`; se leen con
  `Progression.perk(player, nombre)`.

### 2.10 Probar en Studio

Panel de pruebas (solo Studio, `Shared/DebugCommands`): "🎭 Siguiente rol", "⚡ Habilidades listas",
"🎯 Críticos al 100 % (sí/no)", "🐒 Mandril aquí", "👑 Siguiente jefe", "💔 Jefe al 30 %",
"🐾 Siguiente mascota", "❤️ Curar y llenar". Muñecos de práctica (100 de vida) al este de la hoguera
del Basecamp (`TrainingDummyService`).

## 3. Monos

- Cada especie activa sus ataques con campos de `Data/Monkeys` (el tipo `MonkeyDefinition` lista
  todos). Los tiempos de espera viven en el estado de cada mono (`pounceReadyAt`, `roarReadyAt`,
  `throwReadyAt`, `stompReadyAt`) y algunos en `Config.Monkeys` (`PounceCooldownSeconds`,
  `RoarCooldownSeconds`).
- `think` (estado `Chase`): pisotón si el objetivo está a menos de `radio × 0,6`; mordisco a
  `attackRange` cada `attackCooldownSeconds` (o robo si es ladrón; el agarre va en el mordisco);
  fuera de alcance, salto entre 8 y 18 studs o piedra a `throws.range`. Aullido y rugido al
  detectarte (estado `Idle`). El asedio (`siegeThink`) no usa especiales.
- Escalado: `Config.Difficulty` sube vida (+12 %/día) y daño (+8 %/día) hasta ×2,5; los alfas
  ×2,5 de vida y ×1,5 de daño. Los especiales escalan con `monkey.damage / definition.damage`.
- Cada especial: burbuja (`showBubble`), voz (`playVoice`), animación (`MonkeyAnimator.play`) y,
  si hace daño, `CombatService.damagePlayer(player, daño, false, monkey.model)` (para que pueda ser
  crítico según la categoría).
- Un especial nuevo: campo opcional en `MonkeyDefinition` + datos de la especie + función en
  `MonkeyService` + su llamada en `think` + campo de espera en el tipo `Monkey` (y su valor inicial
  en `spawnMonkey`) + animación si hace falta + `description` (diario de campo) + `docs/GDD.md` §8.2.

## 4. Jefes

- `Data/Bosses.specials`: `{ id, fromPhase, cooldownSeconds, species?, count?, channelFromPhase?,
  channelSeconds? }`. Cada `id` es una función de la tabla `SPECIALS` de `BossService` y una
  animación de `SPECIAL_ANIMATIONS`.
- Programación (`tick`): como mucho un especial cada 3 s (`nextSpecialAt`); cada uno empieza con
  3–6 s de espera aleatoria; se lanza **el primero de la lista** que esté listo y desbloqueado, así
  que **el orden de la lista es la prioridad**. Con `channelFromPhase` se queda quieto invocando
  (solo si su objetivo no está cuerpo a cuerpo) y un aturdimiento lo interrumpe.
- Fases al 66 % y 33 % de vida: daño +20 % por fase, velocidad +15 %, crítico 25 → 28 %.
- Daño de los especiales como fracción de `boss.damage`: pisotón 0,8 (+1,5 s), rocas/lava 0,7 cada
  una, agarre 0,6 (+3 s), embestida 1,0 (+1 s).
- Avisos: todo lo que cae del cielo o sale del suelo usa `Combat/Hazards` (`shockwave`,
  `fallingRock`, `lavaBomb`, `lightning`) con una marca en el suelo durante `warnSeconds`; la
  embestida espera 0,6 s con "¡!".
- Vida: `maxHealth` de `Data/Bosses` es la de un jugador solo; `Config.Bosses` la multiplica por
  ×(`HealthBase` + `HealthPerExtraPlayer` × (jugadores − 1)), con los jugadores **que pelean**
  (`countFighters`: vivos, fuera del Basecamp y a menos de `leashRange` de la guarida).
  `rescaleHealth` la recalcula en cada vuelta de `tick` cuando cambia ese número, sin cambiar el %
  (las fases van por %). Con 0,75 por jugador el jefe dura casi lo mismo con 1, 4 o 20. El daño
  del jefe no sube con los días.

## 5. Mascotas

- `PetService`, cada `Config.Pets.TickSeconds` (2 s): las de combate atacan al mono más cercano a
  su dueño a menos de `AttackRange` (25); el cliente las hace saltar (`PetAttack`) y el daño llega a
  los `StrikeDelaySeconds`. Las de curación curan a su dueño. **No pasan por
  `PlayerDamageMultiplier`**; críticos al 10 %; sus números salen más pequeños.
- Rastreo: en el cliente (`UI/PetFollowers`). Las que olfatean (`sniffsEggs`, el beagle) señalan
  además el huevo del suelo a menos de `EggSniffRadius`: huellas hacia él y su distancia; su sitio lo
  publica `EggService` en `ReplicatedStorage` ("EggPosition"), porque con el streaming el cliente puede
  no tenerlo cargado.
- Marca (`marks`, el pointer): en `PetService.tick` marca al mono más cercano (`nearestEnemy`) con la
  misma marca que "Marcar presas" (`MarkedUntil`/`MarkBonus`, que suma `CombatService.damage` a todo el
  que le pega) y `MarkSource = "Pet"`; `MarkBonus` 0,15 durante `MarkSeconds`, ×`MarkBossMultiplier` a
  los jefes. No toca una marca mayor activa y `markPrey` siempre escribe la suya encima (borrando
  `MarkSource`). Los clientes dibujan la diana roja o, con `MarkSource = "Pet"`, una huella naranja
  (`AbilityFxController.watchMarks`).
- Apoyo y carga: `perks`, que suma `Progression.computePerks`. `LootBonus` (el labrador) lo tira
  `MonkeyService.giveLoot` por cada jugador del reparto: +1 de un objeto de los que han caído, con el
  icono de su mascota en la línea del botín.
- Un tipo de ayuda nuevo necesita su rama en `PetService.tick` (o en el cliente si es visual) y su
  texto en `description`.

## 6. Catálogo actual (sin talentos)

Los números exactos y sus medidas salen de la calculadora (`src/island/tools/Equilibrio.luau`, sección 1).

| Rol | Z | X | C | R | V (definitiva) | Combos (pasos) |
|---|---|---|---|---|---|---|
| Guerrero | Torbellino 7 s | Embestida 6 s | Grito de guerra 12 s | Rompehuesos 8 s | Pisotón 90 s | Embestida → Grito → Torbellino · Grito → Embestida → Rompehuesos |
| Cazador | Disparo múltiple 5 s | Marcar presas 15 s | Cepo 9 s | Flecha perforante 8 s | Lluvia de proyectiles 90 s | Cepo → Marcar → Disparo múltiple · Marcar → Cepo → Flecha perforante |
| Mago (recargas ×0,85) | Bola de fuego 6 s | Nova de hielo 11 s | Parpadeo 7 s | Meteoro 10 s | Rayo encadenado 90 s | Nova → Parpadeo → Bola de fuego · Bola de fuego → Nova → Meteoro |
| Médico | Ungüento 15 s | Dardo curativo 6 s | Escudo de hojas 12 s | Polvo somnífero 12 s | Tótem sanador 90 s | Dardo → Escudo → Ungüento · Escudo → Dardo → Polvo somnífero |

Pasiva del médico: +15 de vida máxima y "Savia protectora" (ventaja `SapShield`, en
`AbilityService` con `CombatService.onPlayerHealed`): al curar a otro jugador gana un escudo de 10
durante `SapShieldSeconds`, como mucho uno cada `SapShieldCooldown`; no pisa un escudo mayor. Con un
solo jugador no se puede probar (no hay a quién curar).

Dormir (`control(…, "Sleep")`, `Status.stun` con aspecto "Sleep" y efecto "Asleep") es un aturdimiento
que se ve con "💤"; el Polvo somnífero no se lo aplica a los jefes.
