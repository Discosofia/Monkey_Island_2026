---
name: habilidades-roblox
description: Crea, edita y equilibra habilidades del juego (las 4 de cada rol del jugador, los combos, los ataques especiales de los monos, los especiales de los jefes y la ayuda de las mascotas) con un control de equilibrio medible. Antes de tocar el código mide la propuesta con una calculadora que corre en Roblox Studio por MCP (daño por uso, DPS sostenido, daño acumulado en el tiempo, pico, "segundos de arma", control, curación, si compensa el combo, tiempo para matar, golpe máximo de los enemigos) y la compara con los límites del proyecto; luego la implementa en todos los archivos que toca y la prueba. Úsala siempre que el usuario pida una habilidad nueva o cambiar una ("haz una habilidad de bumerán para el cazador", "el torbellino pega poco", "baja la recarga de la nova", "el gorila aturde demasiado", "que el jefe haga una lluvia de lava", "una mascota que congele"), o pregunte por equilibrio, DPS, daño por segundo, combos, críticos, recargas, cooldowns, talentos, aturdimientos, curación, tiempo para matar o "¿está roto X?", aunque no diga "habilidad". No es para la animación del gesto (skill animaciones-roblox), el modelo 3D de un objeto que deja la habilidad (modelos-3d-roblox) ni el HUD (interfaz-roblox), aunque puede pedirlas.
---

# Habilidades y equilibrio

Esta skill crea o retoca habilidades **midiéndolas antes de escribirlas**. Una habilidad mal medida
se nota tarde: un rol que hace el doble que otro, un combo que nadie necesita o que todos están
obligados a hacer, un mono que te deja quieto para siempre, un jefe que cae antes de enseñar su
segunda fase. Aquí cada propuesta pasa por la calculadora, se compara con la línea base y con los
límites, y solo entonces se implementa en todos los archivos que toca.

Recursos (rutas relativas a esta carpeta):
- `references/sistema-de-habilidades.md`: cómo funcionan hoy las habilidades de jugadores, combos,
  críticos, estados, monos, jefes y mascotas; qué archivo hace qué y el orden de los
  multiplicadores. **Léelo antes de tocar código.**
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

- **Quién**: rol y hueco (Z/X/C activa o V definitiva), especie de mono, jefe y fase, o mascota.
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
3. `src/island/server/Services/AbilityService.luau`: el handler en la sección del rol, con las
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
`MonkeyService` con burbuja, voz, animación y `CombatService.damagePlayer(…, monkey.model)`, su
llamada en `think` (y en `siegeThink` si también asedia), campo de espera en el tipo `Monkey` y su
valor inicial en `spawnMonkey`. Escala su daño con `monkey.damage / definition.damage`. Actualiza la
`description` (diario de campo) y `docs/GDD.md` §8.2. Todo lo fuerte, con aviso.

### Especial de un jefe

Entrada en `specials` del jefe (`Data/Bosses`; el **orden es la prioridad**), función en `SPECIALS`
de `BossService` (daño como fracción de `boss.damage`), animación en `SPECIAL_ANIMATIONS` y, si cae
del cielo o sale del suelo, un peligro de `Combat/Hazards` con su marca de aviso. Comenta el nuevo
`id` en la cabecera de `Data/Bosses` y añade su línea a la sección 4 del script.

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
- **Habilidades que mueven al jugador** (`Charge`, `Blink`, `Whirlwind`): el movimiento lo hace
  `RoleController`, así que con `UseAbility:FireServer` a pelo el personaje no se mueve. Ponlo antes
  con `PivotTo` a 3 studs del muñeco para que el servidor lo encuentre al pasar.
- **Combos**: registra `ComboStep`, `ComboStepUntil − ahora`, `ComboStreak` y `AbilityReadyAt<n>` tras
  cada paso. Para probar la ventana, usa primero suelta la habilidad larga del paso 2, abre con el paso 1
  y espera más de 6 s antes de enlazar.
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
  números ni jugadores. Una habilidad o un mono nuevos no necesitan código de telemetría.
- La simulación de combos juega perfecto: solo abre un combo cuando todos sus pasos van a estar listos.
  Un jugador real usa suelta la habilidad corta del paso 1 y luego no tiene el paso 2. Mira siempre
  el **hueco entre combos** (la recarga más larga de sus pasos, ×0,92 por nivel de racha) y si el
  paso 1 recarga mucho antes que el 2: por eso la ventana espera a que el paso siguiente esté listo
  (`ComboService.stepDeadline`). Hoy: mago ~9 s, guerrero 12 s (Grito), cazador 15 s (Marcar) y
  médico 15 s (Ungüento). Para acortarlo sin cambiar el equilibrio, baja la recarga y el efecto en
  la misma proporción (y lo que escale con él: el talento de duración, el remate).
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
