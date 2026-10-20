---
name: economia-retencion
description: Diseña, revisa y equilibra la economía, la retención y la monetización del juego (Ámbar y sus fuentes y sumideros, mejoras de la tienda, calendario de entrada, misiones diarias y semanales, contratos de partida, huevos y tiempos del nido, pase de temporada gratis y premium, tiendas de cosméticos en Ámbar y Robux, Developer Products y Game Passes, precios, ritmo de la partida y del equipo) midiendo cada cambio antes de escribirlo con una calculadora que corre en Roblox Studio por MCP (Ámbar ganado y gastado por perfil de jugador en 30 días, día en que termina el pase, minutos que pide cada misión, huevos eclosionados, día de partida en que se tiene cada nivel de equipo y auditoría de que nada de pago dé poder). Úsala siempre que el usuario pida o pregunte por recompensas, retención, monetización o balance de progreso ("haz misiones semanales", "las misiones se hacen muy rápido", "¿cuánto cobro por el pase?", "añade un premio al nivel 10", "pon a la venta este cosmético", "el ámbar no sirve para nada", "los jugadores se maxean el día 3", "¿esto es pay to win?", "nueva temporada", "battle pass", "daily rewards", "Robux", "precio", "tienda", "LTV", "D1/D7"), aunque no diga "economía". No es para los números de combate de una habilidad (skill habilidades-roblox), la forma de un cosmético (modelos-3d-roblox), su animación o emote (animaciones-roblox) ni la ventana del pase o la tienda (interfaz-roblox), aunque puede pedirlas.
---

# Economía, retención y monetización

Esta skill cambia la economía **midiéndola antes de escribirla**. Una economía mal medida se nota
tarde: misiones que se cumplen en la primera media hora y dejan al jugador sin metas, Ámbar que se
acumula sin uso, un pase que solo terminan quienes juegan todos los días, o algo de pago que
termina dando ventaja. Aquí cada propuesta pasa por la calculadora, se compara con la línea base y
con los límites, y solo entonces se implementa en todos los archivos que toca.

Recursos (rutas relativas a esta carpeta):
- `references/modelo-economico.md`: principios del juego (las reglas de pago no se negocian),
  fuentes y sumideros, perfiles de jugador, **línea base** medida y hallazgos pendientes. **Léelo
  antes de proponer números.**
- `references/limites.md`: los **límites** de la calculadora con su porqué (espejo de `LIMITES`).
- `references/politicas-roblox.md`: objetos aleatorios de pago, `PolicyService`, Game Passes y
  Developer Products (`ProcessReceipt` idempotente), Creator Rewards y la guía de Roblox para pases
  de temporada. **Léelo antes de vender algo con Robux.**
- `references/nueva-temporada.md`: lista para preparar una temporada del pase.
- La calculadora es una herramienta del repo: `src/island/tools/Economia.luau`, que Rojo pone en
  `ServerStorage.Tools.Economia` del place de la Isla. Se ejecuta en Studio y devuelve un informe en
  tablas.

## 0. Conexión con Studio

1. Carga las herramientas `mcp__Roblox_Studio__*` con ToolSearch si están diferidas.
2. `list_roblox_studios`: la calculadora va en el place **"Isla"** (el que se llama "Islas de
   plátano primitivas" es el Lobby). `get_studio_state`: en **Edit**. Si el usuario está en Play,
   no lo pares.
3. Comprueba que **Rojo está conectado** (`rojo serve island.project.json`, puerto 34873):
   `ServerStorage.Tools.Economia` tiene que existir. Si la Isla no está abierta pero sí el Lobby,
   la calculadora también funciona allí (solo lee `ReplicatedStorage.Shared`, que es el mismo): crea
   una copia temporal con `multi_edit` en `ServerStorage._EconomiaTemporal` con el contenido del
   archivo y bórrala al terminar.
4. Cárgala con una **copia** del módulo (el `require` del modo edición guarda la versión vieja) y
   déjala en `_G`:
   ```lua
   local m = game.ServerStorage.Tools.Economia:Clone()
   _G.Economia = require(m)
   m:Destroy()
   return _G.Economia.informe()
   ```
   Después, cada prueba es una línea: `return _G.Economia.informe(opciones, propuesta)`.
5. Cada informe lee una copia nueva de `ReplicatedStorage.Shared`: los datos son los que hay **en
   Studio**, no en el disco, si Rojo no está conectado.

Sin MCP puedes razonar con la línea base de `modelo-economico.md`, pero dilo: los números no están
medidos.

## 1. Ficha del cambio

Antes de tocar nada, escribe en la conversación una ficha breve:

- **Qué**: misión, premio (calendario, misión, nivel del pase), producto de Robux, precio en Ámbar,
  cosmético, evento o regla de partida. Si sustituye a algo, a qué.
- **Para quién y cuándo**: qué perfil lo nota (casual, habitual, intenso, amigos) y en qué momento
  (primera sesión, día 7, semana 3, días 4–8 de la partida).
- **Qué problema resuelve**: falta de metas, Ámbar sin uso, pase demasiado largo, hueco de mitad de
  partida, ingreso.
- **Regla de pago**: ¿lo puede conseguir alguien que paga? Si sí, tiene que ser **solo cosmético**
  (§ principios de `modelo-economico.md`). ¿Es aleatorio? Entonces nunca de pago.
- **Números de partida** con su pariente más cercano y la palanca de `modelo-economico.md` que mueve.

Pregunta solo lo que cambia el diseño. Si hay varias formas razonables, ofrécelas como opciones al
usuario con la recomendada primero. Los números los propones tú, con el informe delante.

## 2. Medir antes

1. Saca el informe actual (paso 0.4). Opciones útiles: `dias = 45`,
   `perfiles = { habitual = { minutosIsla = 90, diasPorSemana = 4 } }`, `ritmos = { Kill = 1.5 }`,
   `secciones = { partida = false, … }`.
2. Guarda las cifras que vas a mover (fila de la misión, fila de cada perfil, día de término del
   pase, alertas) para la tabla de antes/después.
3. Si el cambio depende de un ritmo (monos por minuto, recursos…), di que es un **supuesto** y pide
   datos de telemetría si los hay (`TelemetryService`, Analytics del Creator Dashboard).

## 3. Probar la propuesta en la calculadora

La `propuesta` (segundo argumento) cambia los datos solo para ese informe:

```lua
return _G.Economia.informe({ secciones = { partida = false } }, {
	-- números de Config (Match, Daily, Egg, Arena, Season, Shop…)
	config = { Daily = { GeneralMissions = 3 }, Match = { AmberPerDay = 15 } },
	-- cualquier módulo de Shared/Data (Missions, Upgrades, Recipes, Cosmetics, Seasons…)
	datos = {
		Missions = { Kills = { target = 40, difficulty = "Media" } },
		Recipes = { ThickBoneMaul = { cost = { [4] = { itemId = "ChieftainCrown", amount = 1 } } } },
	},
})
```

Itera hasta que no haya alertas nuevas o hasta que cada alerta que quede tenga una razón de diseño
explícita. Enseña al usuario una tabla **antes → después** con las filas que cambian y las alertas
que aparecen o desaparecen. Una alerta de **pago** (algo de Robux que no es cosmético o da Ámbar,
tiempo de huevo, objetos o algo aleatorio) nunca se acepta con una razón: se rediseña.

## 4. Implementar

Reglas del proyecto: los números van en `Config`/`Data`, nunca sueltos en la lógica; el servidor
decide premios y compras; los clientes solo piden y dibujan; comentarios y textos en español, con la
densidad y el tono del archivo que tocas. `--!strict` donde ya lo está.

### Misión (diaria, semanal o de rol)
1. `src/shared/Data/Missions.luau`: entrada con `icon`, `text` (`{target}`), `event`, `target`,
   `role?`, `difficulty?`, `weekly?` y `reward`. Solo cosas que se puedan hacer jugando solo.
2. Si el `event` es nuevo: el aviso `Retention.progress(player, "<Evento>", n)` en el servicio que lo
   detecta (lista de enganches en `references/modelo-economico.md`) y su ritmo en `OPCIONES.ritmos` de la
   calculadora (o su regla en `minutosMision`).
3. Texto y rastreador: la ventana Misiones del Lobby y el rastreador de la Isla lo leen de Data.

### Premio (calendario, misión, nivel del pase)
- Formato `Config.Reward` (`amber`, `items`, `eggSeconds`, `egg`) y, en el pase, `cosmetic`. Lo
  entrega `ServerShared/Retention.grant` (o el servicio del pase). Tiempo de huevo ganado jugando:
  con tope (`capped`).

### Cosmético
- `src/shared/Data/Cosmetics.luau`: `kind`, `name`, `icon`, `description`, `order`, su fuente
  (`gamePassId`, `productId`, `amber`, `season` o `earned`) y lo que necesite su tipo. La forma con
  `modelos-3d-roblox`; el emote con `animaciones-roblox` (lo publica el usuario).

### Producto de Robux (Game Pass o Developer Product)
1. Léete `references/politicas-roblox.md`.
2. Id en Data/Config con `0` = "Próximamente"; el usuario lo crea en el Creator Hub y pone el id
   (apúntalo en `docs/LANZAMIENTO.md`).
3. Developer Product: su manejador en el `ProcessReceipt` común, idempotente (recibo apuntado en el
   perfil antes de devolver `PurchaseGranted`).
4. Solo cosméticos o el pase (premium, niveles): la calculadora lo comprueba en la sección 5.

### Evento de partida o cambio de ritmo del equipo
- Números en `Config`/`Data`; el daño o la vida de enemigos con `habilidades-roblox`; el día en que
  se tiene cada nivel de equipo se mide en la sección 3.

## 5. Verificar

1. `stylua src`, `selene src` y `rojo build` de `lobby.project.json`, `island.project.json` y
   `dunas.project.json` desde la raíz (lo mismo que el CI).
2. Vuelve a sacar el informe con el repo sincronizado (sin propuesta): tiene que dar lo mismo que la
   propuesta aprobada.
3. En Play, con el panel de pruebas (`Shared/DebugCommands`): cambiar de día (`NextDay`), forzar
   premios, comprar en modo prueba de Studio. Las compras de Studio son de prueba y sí llaman a
   `ProcessReceipt`.
4. Si no has podido probarlo en Play, dilo, y di qué parte no se ha podido probar.
5. Si cambian los datos guardados (perfil), recuerda: **se publican los 3 places a la vez**.

## 6. Cerrar

- Resume para el usuario: qué cambia, sus números, la tabla antes → después y las alertas que
  quedan con su razón.
- Si la línea base de `modelo-economico.md` ha cambiado de forma apreciable, actualízala. Si
  resuelves un hallazgo pendiente, quítalo; si encuentras uno nuevo, añádelo.
- Si cambias un límite, cámbialo en `limites.md` **y** en `LIMITES` de la calculadora.
- Si cambia lo que ve el jugador (GDD §4, §11, §14), actualiza `docs/GDD.md`; si cambia cómo
  probarlo, `docs/VERIFICACION.md`; si hay que crear algo en el Creator Hub, `docs/LANZAMIENTO.md`.
- Deja Studio como estaba: borra `ServerStorage._EconomiaTemporal` si la creaste y para el Play si
  lo arrancaste tú.
