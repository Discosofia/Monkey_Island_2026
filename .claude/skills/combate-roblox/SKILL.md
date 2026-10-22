---
name: combate-roblox
description: Crea, revisa, administra y equilibra todo el combate del juego con un control medible. Cubre las habilidades (las 5 de cada rol, ataques especiales de monos y jefes, ayuda de las mascotas), las mecánicas (golpe con arma y su cadena, esquiva, bloqueo, parry y guardia, amagos, Evasivo, aturdido e inmovilizado, empujes y rebote contra muros, zonas de peligro, proyectiles), la detección de impactos (rayos, esferas, cajas, línea de visión, lag), los combos de habilidades y sus conexiones, los estilos de cada rol y la equidad entre roles, dispositivos y jugadores en la Isla (PvE) y en la arena de Dunas (PvP). Antes de tocar el código mide la propuesta con una calculadora que corre en Roblox Studio por MCP (daño por uso, DPS, segundos de arma, control, curación, valor del combo, tiempo para matar, duelos de la arena, golpe máximo de los enemigos, combos sin escape, guardia) y la compara con los límites; luego la implementa en todos los archivos que toca y la prueba. Úsala siempre que el usuario pida o pregunte algo del combate ("haz una habilidad de bumerán", "el torbellino pega poco", "baja la recarga de la nova", "el gorila aturde demasiado", "el parry es imposible en el móvil", "me matan sin poder hacer nada", "añade un remate al garrote", "el golpe atraviesa paredes", "que el jefe haga una lluvia de lava", "¿está roto X?"), o por equilibrio, DPS, combos, críticos, recargas, cooldowns, talentos, aturdimientos, bloqueo, parry, hitbox, lag, PvP, tiempo para matar o estilos de juego, aunque no diga "combate" ni "habilidad". No es para la animación del gesto (skill animaciones-roblox), el modelo 3D de un objeto (modelos-3d-roblox) ni el HUD (interfaz-roblox), aunque puede pedirlas.
---

# Combate y equilibrio

Esta skill crea, revisa y administra el combate **midiéndolo antes de escribirlo**. Un número mal medido
se nota tarde: un rol que hace el doble que otro, un combo que nadie necesita o que todos están
obligados a hacer, un mono que te deja quieto para siempre, un jefe que cae antes de enseñar su
segunda fase, un combo del que no se puede salir o una ventana de parry que en el móvil no se puede
acertar. Aquí cada propuesta pasa por la calculadora, se compara con la línea base y con los
límites, y solo entonces se implementa en todos los archivos que toca.

Abarca cuatro cosas, cada una con su receta:
- **Habilidades** (§1–§4 abajo): las de los roles, los monos, los jefes y las mascotas.
- **Mecánicas** (§7): cómo se ataca, se defiende, se escapa y se detecta un golpe.
- **Combos y estilos** (`references/estilos-y-combos.md`): qué hace cada rol, cómo se enlaza y qué
  no puede pasar (combos sin escape, opciones sin respuesta).
- **Equidad** (§8): entre roles, entre dispositivos (PC, móvil, mando) y entre jugadores con distinto ping.

Recursos (rutas relativas a esta carpeta):
- `references/sistema-de-habilidades.md`: cómo funcionan hoy las habilidades de jugadores, combos,
  críticos, estados, monos, jefes y mascotas; qué archivo hace qué y el orden de los
  multiplicadores. **Léelo antes de tocar código.**
- `references/sistema-de-combate.md`: las mecánicas (estados y prioridades, golpe con arma, esquiva,
  guardia, Evasivo, empujes, proyectiles), la **detección de impactos** y la red (lag, quién decide
  qué). Dice qué existe hoy y qué está planificado en la Fase 10. **Léelo antes de tocar una mecánica.**
- `references/estilos-y-combos.md`: arquetipo de cada rol, estructura abre → extiende → remata,
  reglas contra los combos infinitos, amagos y lectura. **Léelo antes de diseñar un combo o un rol.**
- `references/equilibrio.md`: principios (con fuentes), qué mide la calculadora, los **límites**, la
  línea base actual, hallazgos pendientes y recetas de ajuste. **Léelo antes de proponer números.**
- La calculadora es una herramienta del repo: `src/island/tools/Equilibrio.luau`, que Rojo pone en
  `ServerStorage.Tools.Equilibrio` del place de la Isla. Se ejecuta en Studio y devuelve un informe
  en tablas.

## 0. Conexión con Studio

1. Carga las herramientas `mcp__Roblox_Studio__*` con ToolSearch si están diferidas.
2. `list_roblox_studios`: la calculadora va en el place **"Isla"** (el que se llama "Isla de plátanos
   primitivos" es el Lobby). `get_studio_state`: en **Edit**. Si el usuario está en Play, no lo
   pares: espera o pídele que pare.
3. Comprueba que **Rojo está conectado** (`rojo serve island.project.json`, puerto 34873, y el
   plugin de Rojo de Studio conectado): `ServerStorage.Tools.Equilibrio` tiene que existir y lo que
   mides tiene que ser lo que hay en el repo. Si no lo está, pide al usuario que lo conecte; mientras
   tanto puedes crear una copia temporal con `multi_edit` (`ServerStorage._EquilibrioTemporal`,
   fuera de lo que gestiona Rojo) y borrarla al terminar.
4. Carga la calculadora con una **copia** del módulo (el `require` del modo edición guarda la versión
   vieja) y déjala en `_G` para las pruebas siguientes:
   ```lua
   local m = game.ServerStorage.Tools.Equilibrio:Clone()
   _G.Equilibrio = require(m)
   m:Destroy()
   return _G.Equilibrio.informe()
   ```
   Después, cada prueba es una línea: `return _G.Equilibrio.informe(opciones, propuesta)`. Si cambias
   el archivo, vuelve a cargarla así cuando Rojo lo haya sincronizado.
5. Cada informe lee una **copia nueva** de `ReplicatedStorage.Shared`, así que los datos del juego
   tampoco salen de la caché; pero son los que hay **en Studio**.

Sin MCP puedes razonar con la línea base de `equilibrio.md` §4 y las fórmulas de §2, pero dilo:
los números no están medidos.

## 1. Ficha de diseño

Antes de tocar nada, escribe en la conversación una ficha breve:

- **Quién**: rol y hueco (Z/X/C/R activa o V definitiva), especie de mono, jefe y fase, o mascota.
  Si sustituye a otra, cuál.
- **Fantasía y función**: qué siente el jugador al usarla y qué problema del rol resuelve (agrupar,
  castigar en área, rematar a uno, escapar, sostener, controlar). Su **familia**: daño a uno, daño en
  área, control, defensa, curación, movilidad o apoyo.
- **Combo**: ¿prepara (marca lo que toca), enlaza o remata? ¿Qué extra da enlazada? Recuerda la
  ventana de 6 s y que ninguna definitiva entra en combos.
- **Lectura y respuesta**: cómo se ve, se oye y se avisa; en los enemigos, cuánto aviso y cómo se
  esquiva. En PvP: ×0,5 de daño y de control.
- **Móvil y mando**: hacia dónde apunta sin ratón (hacia donde mira la cámara) y el texto corto del
  botón (`short`, ~9 letras).
- **Números de partida** en las medidas de `equilibrio.md` §2: recarga, segundos de arma por uso,
  control (% del tiempo), curación. Parte del pariente más cercano que ya existe.
- **Talento** que la mejora (los 4 talentos de cada rol mejoran uno cada habilidad) y su ventaja en
  `Data/Perks`.

Para un **retoque**, la ficha es más corta: el síntoma ("pega poco", "nadie la usa", "aturde
demasiado"), qué medida lo confirma y qué palanca de `equilibrio.md` §6 vas a mover.

Pregunta solo lo que cambia el diseño (¿sustituye a otra?, ¿entra en el combo?, ¿también para PvP?).
Si hay varias formas razonables, el usuario prefiere ofrecerlas como opciones del jugador cuando
tenga sentido (p. ej. el modo de apuntado). Los números los propones tú, con el informe delante.

## 2. Medir antes

1. Saca el informe actual (paso 0.4) o solo el rol afectado:
   `_G.Equilibrio.informe({ soloRol = "Cazador" })`. Opciones útiles: `talentos = "max"`,
   `grupo = 6`, `armas = { Mago = "SilverStaff" }`, `critico = 0.15`, `aliados = 8`, `dias = { 1, 12 }`,
   `segundosCombo = 240`, `jugadoresJefe = { 1, 4, 12 }`, `armasPorDia = { [1] = 0, [4] = 1 }`,
   `secciones = { mascotas = false, … }`.
2. Mira también con `talentos = "max"`: lo que entra justo sin talentos suele salirse con ellos.
3. Guarda las cifras que vas a mover (fila de la habilidad, fila de la simulación del rol y las
   alertas) para la tabla de antes/después.

## 3. Probar la propuesta en la calculadora

La `propuesta` (segundo argumento) cambia los datos solo para ese informe:

```lua
return _G.Equilibrio.informe({ soloRol = "Cazador" }, {
	-- números de Config (cualquier tabla: Abilities, Combo, Crit, Combat…)
	config = { Abilities = { BoomerangDamage = 14, BoomerangRange = 40 } },
	-- huecos de Data/Roles: cambia campos o pon una habilidad nueva en un hueco
	roles = { Cazador = { [2] = { id = "Boomerang", name = "Bumerán", short = "Bumerán", cooldownSeconds = 8 } } },
	-- cómo medir la nueva: el mismo formato de ficha que MODELOS del script
	modelos = {
		Boomerang = function(A, perk, remate, combo)
			local dano = A.BoomerangDamage * perk("RangedDamage")
			return {
				familia = "Daño en línea (ida y vuelta)",
				golpes = {
					{ cantidad = dano, en = 0.4, objetivos = { fijo = 2 } },
					{ cantidad = dano, en = 1.0, objetivos = { fijo = 2 } },
				},
			}
		end,
	},
	-- combos de Data/Combos
	combos = { Cazador = { steps = { "Trap", "Boomerang", "MultiShot" } } },
	-- cualquier otro módulo de Shared/Data (Monkeys, Bosses, Pets, Weapons, Talents, Perks, Armor…)
	-- (una ventaja nueva de un talento nuevo va primero en Perks: { Perks = { BoomerangBounces = 1 } })
	datos = { Weapons = { Bow = { damage = 20 } } },
})
```

El formato de la ficha (golpes, objetivos por radio o fijos, control, lento, provoca, vulnerable,
mitiga, cura, escudo, movilidad) está explicado en el comentario de `MODELOS` de la calculadora. El modelo
tiene que **reproducir lo que hará el handler**: mismos números de Config, mismas ventajas, mismos
extras del remate.

Itera hasta que no haya alertas nuevas o hasta que cada alerta que quede tenga una razón de diseño
explícita. Enseña al usuario una tabla **antes → después** con: recarga, segundos de arma, DPS en
grupo, control, la fila de su rol en la simulación (sin combos y con combos, 1 objetivo y grupo) y
las alertas que aparecen o desaparecen. Para enemigos y mascotas, sus filas de las secciones 4 y 5.

**Monos, jefes y mascotas** se prueban igual, con `datos` (p. ej.
`datos = { Monkeys = { Orangutan = { grab = 1.5 } } }`) y `config` (`Monkeys`, `Difficulty`, `Pets`,
`Crit`, `Bosses`). Un especial de mono o de jefe **nuevo** necesita además su línea en la sección 4
de la calculadora (`mono.<campo>` o `especial.id == …`) para salir con su daño y su bloqueo.

## 4. Implementar

Reglas del proyecto: los números van en `Config`/`Data`, nunca sueltos en la lógica; el servidor
decide el daño y los estados; los efectos los dibuja cada cliente; comentarios y textos en español,
con la densidad y el tono del archivo que tocas. `--!strict` donde ya lo está.

### Habilidad del jugador (nueva o sustituta)

1. `src/shared/Data/Roles.luau`: entrada en `abilities` del rol, en el hueco de su tecla (`id`,
   `name`, `short`, `description` para el jugador, `cooldownSeconds`, `ultimate`).
2. `src/shared/Config.luau` → `Abilities`: sus números, con un comentario por número que lo pida
   (unidades: "por golpe", "segundos", "studs").
3. `src/combat/Services/AbilityService.luau`: el handler en la sección del rol, con las
   piezas comunes (`targetsAround`, `castShot`, `hurt`, `control`, `heal`, `comboOpener`…), y su
   entrada en `HANDLERS`. Devuelve `false` si no se pudo usar (no gasta recarga). Actualiza la lista
   de la cabecera del archivo.
4. Si **mueve al jugador**: la parte del movimiento en `RoleController.useAbility` (como `Charge`,
   `Blink`, `Whirlwind`) y en el servidor solo el daño/efecto con `AbilityFx.others`.
5. Efecto: función nueva en `AbilityFxController` y su entrada en `EFFECTS` con el comentario de sus
   datos; el servidor la lanza con `AbilityFx.all` (o `others`). Actualiza la cabecera del
   controlador. Si deja un objeto en el mundo (como el cepo), su forma con la skill
   `modelos-3d-roblox`.
6. Gesto: `Data/PlayerAnimations.Abilities[id]` con uno existente (`CastForward`, `CastArea`,
   `Place`…) o uno nuevo con la skill `animaciones-roblox`.
7. `src/shared/UI/SettingsPanel.luau` → `ABILITY_INFO`: qué número enseña y qué ventajas lo
   multiplican (solo si hace daño o cura).
8. Talento: `Data/Talents` (el que mejoraba la habilidad sustituida pasa a la nueva o se rehace) y su
   ventaja con valor por defecto en `Data/Perks`. Si quitas un talento, los puntos vuelven solos.
9. Combo: `Data/Combos` (pasos, `finisher` para el jugador, `damageBonus`) y, si es paso 1, llama a `comboOpener`
   cuando toque algo; si da un extra enlazada, usa `ComboService.isPayoff` y pon el número en
   `Config.Combo`. Si el cliente debe predecir el remate, `ComboController.nextStep`.
10. **Modelo de la calculadora**: añade su entrada a `MODELOS` en `src/island/tools/Equilibrio.luau`
    (la de la propuesta, ya probada). Si cambias cómo funciona una existente, cambia también su modelo.
11. `docs/GDD.md` §6.3 (tabla de roles y recargas) y §6.4 si toca combos o críticos.

### Ataque especial de un mono

Campo opcional en el tipo `MonkeyDefinition` y valor en la especie (`Data/Monkeys`), función en
`MonkeyService` con burbuja, voz, animación y `CombatService.damagePlayer(…, monkey.model, nil, nil,
golpe)`, su llamada en `think` (y en `siegeThink` si también asedia), campo de espera en el tipo
`Monkey` y su valor inicial en `spawnMonkey`. Escala su daño con `monkey.damage / definition.damage`.
Actualiza la `description` (diario de campo) y `docs/GDD.md` §8.2. Todo lo que hace daño, con
**preparación** (`Combat/EnemyAttack.windup`, su tiempo en `Config.Windup`, que quepa en su recarga) y
al acabarla con `EnemyAttack.strike` (a uno) o `Hitbox.inSphere` (área); `golpe` = `Guard.enemyHit`, con
`unblockable = true` (y `WindupKind` "Unblockable") si no se puede bloquear.

### Especial de un jefe

Entrada en `specials` del jefe (`Data/Bosses`; el **orden es la prioridad**), función en `SPECIALS`
de `BossService` (daño como fracción de `boss.damage`), animación en `SPECIAL_ANIMATIONS` y, si cae
del cielo o sale del suelo, un peligro de `Combat/Hazards` con su marca de aviso (los peligros son
imbloqueables). Lo que pega de cerca, con `EnemyAttack.windup` como el golpe normal (si es
imbloqueable, "Unblockable"). Comenta el nuevo `id` en la cabecera de `Data/Bosses` y añade su línea
a la sección 4 del script y a la de imbloqueables de la sección 10.

### Mascota

Entrada en `Data/Pets` (`kind`, `attackDamage`/`healPerTick`/`tracks`/`perks`, `description` con
los números). Un tipo de ayuda nuevo necesita su rama en `PetService.tick` (o en el cliente si es
visual); su forma va en `PetModels` con la skill `modelos-3d-roblox`.

## 5. Verificar

1. `stylua src`, `selene src` y `rojo build island.project.json` desde la raíz del repo (lo mismo que
   el CI).
2. Vuelve a sacar el informe con el repo ya sincronizado (sin propuesta): tiene que dar lo mismo que
   la propuesta aprobada. Si no, el handler y el modelo no hacen lo mismo.
3. En Play (si el usuario puede o te deja arrancarlo con `start_stop_play`): panel de pruebas →
   "🎭 Siguiente rol" hasta el rol, "⚡ Habilidades listas", y úsala contra los muñecos del Basecamp o
   un "🐒 Mandril aquí". Comprueba en la Salida que no hay errores, que los números cuadran con la
   ficha y que el efecto se ve. Para jefes: "👑 Siguiente jefe" y "💔 Jefe al 30 %" para la fase 3.
   Cómo hacerlo por MCP sin perder tiempo, en §5.1.
4. Si no has podido probarla en Play, dilo, y di qué parte no se ha podido probar.

### 5.1 Probar por MCP en Play: lo que funciona

- **Mandar las órdenes como el jugador**: desde el datamodel `Client`,
  `require(ReplicatedStorage.Shared.Remotes)` y `Remotes.DebugCommand:FireServer("NextRole")` (los
  ids están en `Shared/DebugCommands`) o `Remotes.UseAbility:FireServer(hueco, puntería, desde,
  hasta)`. Antes de cada uso espera a que `AbilityReadyAt<hueco>` haya pasado
  (`workspace:GetServerTimeNow()`), y entre dos combos deja pasar la ventana (6 s).
- **El `require` del MCP es otra copia**: lo que ejecutas con `execute_luau` corre en otra máquina
  de Luau, así que `require` de un servicio o de `Shared/Crit` te da una copia aparte. Un oyente
  (`CombatService.onEnemyDamaged`) o un parche (`Crit.roll = …`) **no afecta al juego**. Mide con
  las instancias, que sí son las mismas: `Humanoid.HealthChanged` del objetivo, atributos del
  jugador (`AbilityReadyAt<n>`, `ComboStep`, `ComboStreak`) y de `ReplicatedStorage` (`BossHealth`,
  `BossMaxHealth`). Para quitar el azar de los críticos usa el atributo del panel:
  `workspace:SetAttribute("DebugAlwaysCrit", true)` (todo crítico) y quítalo al acabar.
- **Muñecos**: hay tres en fila al este de la hoguera (z = −10, 0 y 10). Elige siempre **el más
  cercano** en todos los scripts (cliente y servidor), escucha a los tres (las áreas alcanzan a los
  vecinos) y súbeles la vida (`MaxHealth = 1000`) para que no se rompan a mitad de prueba. La
  mascota activa también les pega cada 2 s: no confundas sus golpes con los tuyos.
- **Apunta desde la cabeza**: los disparos de habilidad (`castShot`) salen de `Head`, así que la
  puntería es `(objetivo − cabeza).Unit`, no desde `HumanoidRootPart`.
- **Mono concreto sin comando**: el panel solo crea mandriles; para otra especie busca en el
  servidor un modelo de `workspace.Monos` con `MonkeyType` = su id, súbete la vida, pon al personaje
  a 4 studs con `PivotTo` (y vuelve a ponerlo si se aleja) y registra `StunnedUntil` y
  `HealthChanged` durante 20 s. Ojo: vienen también sus compañeros de grupo.
- **Guardia** (C5): pulsa F de verdad con `user_keyboard_input` (`keyDown`/`keyUp`, `keyPress` dura
  ~0,2 s) o manda `Remotes.Guard:FireServer(true, workspace:GetServerTimeNow())` / `(false)` desde el
  cliente. Registra en el servidor `CombatState`, `Guard`, `ParryAt` y el `HealthChanged` del
  personaje. Para tener un mono delante: el comando "Mandrill" fuera del Basecamp (zona segura: ahí no
  pegan), súbete la vida, borra los demás monos a menos de 60–80 studs (otros llegan solos y pegan
  también) y sujeta el mandril a 3,5 studs con `PivotTo` en cada `Heartbeat`, delante o detrás según
  la `LookVector` de la raíz (para el cono). Para cazar un parry sin reloj, toques cada 0,85 s (>
  `ParryRearmSeconds`): cae en la ventana ~1 de cada 4.
- **Habilidades que mueven al jugador** (`Charge`, `Blink`, `Whirlwind`): el movimiento lo hace
  `RoleController`, así que con `UseAbility:FireServer` a pelo el personaje no se mueve. Ponlo antes
  con `PivotTo` a 3 studs del muñeco para que el servidor lo encuentre al pasar.
- **Combos**: registra `ComboStep`, `ComboStepUntil − ahora`, `ComboStreak` y `AbilityReadyAt<n>` tras
  cada paso. Para probar la ventana, usa primero suelta la habilidad larga del paso 2, abre con el paso 1
  y espera más de 6 s antes de enlazar.
- **Estados del jugador** (Fase 10): para probar un aturdido o un inmovilizado, `require` en el
  servidor de `ServerScriptService.Combat.Status` y `Status.stunPlayer(player, 3, "Prueba")` (o
  `holdPlayer`). Aunque es otra copia del módulo, escribe en los atributos del `Player`
  (`CombatState`, `StunnedUntil`), que son los que mira el juego. Quita antes `ControlImmuneUntil`.
- **Preparación de monos y jefes** (C6): el muñeco de sparring (Basecamp, `MuñecosDePractica`, en
  (45, _, 22) desde la hoguera; en el Lobby, junto a los otros tres) pega cada 1,8 s a quien esté a
  menos de 6 studs: es la forma rápida de probar el aviso, el bloqueo y el parry sin monos. Registra en
  el servidor `WindupUntil` del enemigo (el golpe cae cuando pasa a nil), el `HealthChanged` del
  personaje (o el `Highlight` del destello con el sparring, que no quita vida), `Guard`, `ParryAt` y
  `StunnedUntil − ahora` del enemigo (control decreciente: 1 → 0,8 → 0,6 → 0,4 → "INMUNE"). Para el
  parry desde el cliente: lee `WindupUntil`, espera hasta 0,1 s antes y manda
  `Remotes.Guard:FireServer(true, workspace:GetServerTimeNow())` y a los 0,15 s `(false)`. Para
  apartarse: `PivotTo` 6–7 studs fuera de la caja 0,1–0,15 s después de empezar el aviso. El "!" sale
  en el cliente (`Head.EnemyWindup`), no en las capturas. Al llevar al personaje lejos con `PivotTo`,
  los monos de antes siguen pegando unos segundos y llegan otros de la zona: cuenta solo lo que
  coincide con el aviso del que mides.
- **Evasivo** (C7): aturde (`Status.stunPlayer`), sujeta (`holdPlayer`) o rompe la guardia
  (`stunPlayer(…, "GuardBroken")`) desde el servidor, quitando antes `ControlImmuneUntil` y
  `EvasiveReadyAt`, y pulsa Q con `user_keyboard_input`. La tecla llega 1–3 s después de la llamada
  anterior: usa controles de **8 s** (con 3 s ya se había acabado y salió una esquiva normal). Registra
  `StunnedUntil`, `CombatState`, `EvasiveReadyAt`, `InvulnerableUntil` y la distancia recorrida. Para
  "lanzado", `Knockback.push(personaje, dir, 5, 0.1, 45)` (pone `LaunchedUntil` +0,46 s) y alárgalo a
  mano. Los rendimientos decrecientes PvP se prueban con `holdPlayer(p, 1, "PvP")` seguidos en **una
  sola** llamada (la tabla es de la copia del MCP) y esperando 6 s entre pruebas.
- **Cadena de golpes** (C4): pulsa como el jugador con `tool:Activate()` desde el cliente (pasa por
  `WeaponController`: tajo, búfer y remoto) cada 0,1 s, y registra en el servidor el atributo
  `ChainStep` del `Player` y el `HealthChanged` de los muñecos con su hora (`ChainStep` no avisa si
  repite valor: un 1 tras otro 1 no sale). Para el remate contra un mono, sujétalo delante del jugador
  con `PivotTo` en cada `Heartbeat` y suéltalo 0,5 s tras el 4.º golpe para medir su velocidad.
- **Saltar**: `Humanoid.Jump = true` desde el MCP no salta (los controles de Roblox lo pisan). Para
  estar en el aire en un instante (el remate que lanza), sube al personaje con `PivotTo` unos 9 studs
  justo antes.
- **Correr de verdad**: `Humanoid:Move` desde el MCP no mueve al personaje (los controles de Roblox lo
  pisan en cada fotograma). Usa `user_keyboard_input` (mantener W y LeftShift) para la estamina.
- **Remotos del servidor al cliente**: dispara la instancia real
  (`ReplicatedStorage.Remotes.Knockback:FireClient(...)`), no la del módulo `Remotes` copiado.
- **El `PlayerModule` de Roblox** se carga desde `StarterPlayer.PlayerModule` (no está en
  `PlayerScripts` ni en modo edición). Sus teclas son `InputBinding` del sistema de acciones de
  entrada (`InputContexts`).
- **Línea de visión** (C3): pon un muro (`Part` anclada que choque) entre el jugador y el muñeco del
  centro y apunta los golpes de los tres muñecos en un atributo de `workspace` desde el servidor
  (`HealthChanged`): el cliente y el servidor del MCP comparten las instancias, así que la secuencia es
  servidor (montar y vaciar el registro) → cliente (`UseAbility`/`UseWeapon`) → servidor (leerlo).
  Repite sin el muro como control. Para probar `Hitbox` aparte, la copia del MCP no está arrancada:
  rehace la lista en cada consulta (sus tiempos son una cota superior) y, para el rebobinado, llama
  antes a `Hitbox.start()` en la copia y espera más de un segundo.
- **Lo que no se puede probar**: con un solo jugador no cambia nada que dependa de cuántos hay (la
  vida de los jefes, curaciones a aliados, PvP). Pide al usuario Test → Clientes y servidores con 2.

### 5.2 Lecciones de equilibrio

- El premio del combo tiene dos partes: el daño del remate y acercar la definitiva. La segunda solo
  se ve en peleas más largas que una recarga de la V; por eso el valor del combo se mide en
  `segundosCombo` (180 s) y no en los 60 s de la tabla.
- Un extra igual para todos los roles no los iguala: cada combo se cierra con distinta frecuencia
  (el mago cada ~9 s, el cazador cada ~18 s) y su remate pega distinto. Las palancas de equilibrio
  van por rol (`damageBonus` en `Data/Combos`) y las de "que no se dispare" con tope
  (`UltRefundMaxSeconds`).
- Para la duración de los jefes mide con las armas de la forja que se tienen **ese día**
  (`armasPorDia`): con las básicas salen el doble de largos de lo que serán.
- Un control sobre el jugador que dura más que la cadencia de quien lo pone (el agarre del
  orangután, 2,5 s cada 1,8 s) es un bloqueo total si cada golpe lo renueva. No se arregla bajando
  números de una especie, sino con la regla común `Status.holdPlayer` (no se alarga mientras dura +
  inmunidad al soltarte), que también cubre a dos monos turnándose. Todo control nuevo sobre
  jugadores pasa por ella; su bloqueo real es `duración ÷ (ceil((duración + inmunidad) ÷ cadencia) ×
  cadencia)`, y en Play sale algo más alto (~+5 puntos) porque la cadencia real varía.
- Telemetría (`TelemetryService`): contar en el servidor y mandar los totales al final de la
  partida, no un evento por uso; Roblox limita los eventos por minuto, admite 3 campos de texto por
  evento y 8000 combinaciones de valores, así que los campos son ids (rol, habilidad, especie), nunca
  números ni jugadores. Una habilidad o un mono nuevos no necesitan código de telemetría. Una
  mecánica nueva sí: un nombre más en `CombatRules.Mechanic` y su llamada a `telemetry.mechanic`
  (Isla y Dunas la cuentan con el place en el segundo campo).
- La simulación de combos juega perfecto: solo abre un combo cuando todos sus pasos van a estar listos.
  Un jugador real usa suelta la habilidad corta del paso 1 y luego no tiene el paso 2. Mira siempre
  el **hueco entre combos** (la recarga más larga de sus pasos, ×0,92 por nivel de racha) y si el
  paso 1 recarga mucho antes que el 2: por eso la ventana espera a que el paso siguiente esté listo
  (`ComboService.stepDeadline`). Hoy: mago ~9 s, guerrero 12 s (Grito), cazador 15 s (Marcar) y
  médico 15 s (Ungüento). Para acortarlo sin cambiar el equilibrio, baja la recarga y el efecto en
  la misma proporción (y lo que escale con él: el talento de duración, el remate).
- Con dos combos que se conectan, cada habilidad del bucle va enlazada casi siempre: el premio del
  combo deja de venir del `damageBonus` y pasa a los críticos seguros y a la racha, que se queda en
  x5. Para medir cuánto pesa cada cosa, pon a 0 `damageBonus`, `StreakCooldownBonus` y
  `UltRefundSeconds` de uno en uno. En Play, al probar una conexión, pega con el arma mientras
  esperas un paso largo o la racha se pierde a los 8 s y parece un fallo.
- **Mascota de prueba**: el comando "Pet" pone `ActivePet` y recalcula las ventajas, y se queda toda
  la partida: `PlayerData` solo vuelve a publicar `ActivePet` cuando cambia la mascota guardada (antes
  la pisaba con cada `PlayerData.update`, por ejemplo al derrotar un mono).
- **Las capturas no enseñan los BillboardGui que crean los scripts del cliente** (la diana, la huella
  del pointer, el cartel del olfato), aunque existan y caigan dentro de la pantalla; sí los del servidor
  ("Parcela libre", los nombres) y las ScreenGui. Compruébalos por instancias (`workspace.AbilityFx`,
  `Adornee`, `WorldToViewportPoint`) y pide al usuario que los mire. Los creados o clonados desde el MCP
  tampoco se pintan.
- Al probar por MCP no lances una habilidad justo después de mover al personaje con `PivotTo` desde
  el cliente: el servidor aún lo ve donde estaba (el cepo se queda en el sitio viejo). Espera ~0,5 s.
- Un ritmo que llevan a la vez el cliente y el servidor, cada uno con su reloj (la cadena de golpes),
  necesita un margen fijo en el servidor (`Config.Net.JitterSeconds`) además del ping: sin él, en
  Studio (ping ~0) una pulsación que llegaba milisegundos antes se rechazaba y la cadena se rompía. Para
  que el margen no suba el ritmo, el siguiente paso cuenta desde `max(ahora, listoEn)`.
- Prueba primero una rejilla pequeña (2–3 valores por palanca, todos los roles) con un script que
  extraiga las filas del informe, y solo después afina; enseña al usuario la tabla final.

## 6. Cerrar

- Resume para el usuario: qué hace, sus números, la tabla antes → después y las alertas que quedan
  con su razón.
- Si la línea base de `equilibrio.md` §4 ha cambiado de forma apreciable (más del ~10 % en la fila de
  un rol), actualízala. Si has resuelto uno de los hallazgos de §5, quítalo; si encuentras uno nuevo,
  añádelo.
- Si cambias un límite, cámbialo en `equilibrio.md` §3 **y** en `LIMITES` de la calculadora.
- Si aprendes algo nuevo de cómo probar o equilibrar, añádelo a §5.1 o §5.2.
- Deja Studio como estaba: borra la copia temporal (`ServerStorage._EquilibrioTemporal`) si la
  creaste, quita `DebugAlwaysCrit` y para el Play si lo arrancaste tú.

## 7. Mecánicas de combate

Una mecánica (algo que tienen todos los roles: el golpe con arma, la esquiva, la guardia, el Evasivo,
un estado nuevo, una regla de empuje) toca más cosas que una habilidad y cambia el juego de todos.
Mira primero `references/sistema-de-combate.md` (qué hay hoy) y el plan de la Fase 10 si sigue
abierto (`docs/PLAN.md`, Fase 10, y su archivo de plan con los handoffs).

### 7.1 Ficha de una mecánica

- **Problema**: qué no puede hacer hoy el jugador o qué es injusto ("me matan sin poder responder",
  "en el móvil no llego", "el golpe me da a través de la pared").
- **Regla**: qué cambia, en una frase que entienda un jugador de 10 años.
- **Estados**: en qué estado entra quien la usa y quien la recibe, cuánto dura, qué prioridad tiene y
  qué acciones bloquea (`canAct`). Ningún estado nuevo fuera de la máquina de estados.
- **Respuesta**: cómo se contrarresta (toda opción fuerte tiene una: bloqueo → imbloqueable o
  rotura; parry → amago; combo → Evasivo; imbloqueable → preparación larga y castigo si falla).
- **Red**: quién decide (siempre el servidor), qué predice el cliente, qué margen de lag da y con
  qué tope (`Config`).
- **Detección**: qué consulta usa (`Combat/Hitbox`: rayo, esfera, caja, área con línea de visión).
  Nunca `.Touched`.
- **Lectura**: cómo se ve y cómo se oye, también sin sonido y en un teléfono. Colores con
  significado: verde curación, morado veneno, rojo daño recibido, dorado parry, naranja con grietas
  guardia rota.
- **Isla y Dunas**: si cambia por place, con qué regla de `CombatRules`.
- **Números** y qué sección de la calculadora la mide.

### 7.2 Implementar una mecánica

1. Números en `Config` (un bloque por mecánica, con un comentario por número) y datos en `Data`.
2. La regla en el servidor (`src/combat`), compartida por los tres places; lo que cambia por place,
   en `CombatRules` y en el `Init` de `IslandCombatRules`, `DunasCombatRules` y `LobbyCombatRules`.
3. El cliente (`src/combatClient`): entrada (teclado, mando y botón táctil en `ActionButtons`),
   predicción y efectos. Las poses son `AnimationTrack` (skill `animaciones-roblox`).
4. Su sección o su caso en la calculadora (`Equilibrio`) y sus límites en `LIMITES` y en
   `references/equilibrio.md` §3.
5. Telemetría: un contador nuevo por `CombatRules.telemetry` si responde a una pregunta de diseño.
6. Documentación: `references/sistema-de-combate.md` y `docs/GDD.md` §6.
7. Prueba en Play en la Isla **y** en Dunas; lo que dependa de dos jugadores (PvP, parry entre
   jugadores, lag) se pide al usuario con *Test → Clientes y servidores* con 2.

## 8. Equidad

Antes de dar por buena una propuesta, repasa:

- **Entre roles**: el reparto de §3 de `equilibrio.md` (±20 % en grupo, ±30 % a un objetivo) y los
  duelos de la arena. Cada rol gana en su escenario (`references/estilos-y-combos.md`), ninguno en
  todos.
- **Entre dispositivos**: las mismas ventanas y los mismos números en PC, móvil y mando. Si algo es
  difícil en el móvil, se ensancha para todos o se hace más legible; nunca se da ventaja a un
  dispositivo. Los avisos se ven sin sonido.
- **Entre pings**: la compensación de lag favorece al defensor y tiene tope; nadie gana por tener más
  ping.
- **Sin salida**: ningún combo sin escape pasa del límite de vida de `equilibrio.md` §3; todo control
  sobre un jugador pasa por `Status` (inmunidad al soltarse) y tiene respuesta (Evasivo).
- **Pago**: nada que se compre con Robux da poder; el equipo de Ámbar de Dunas es horizontal.
