# Isla Calavera, la mazmorra: diseño (quinto place)

Diseño de la tanda T9 de los pedidos del 26-10-2026 (punto 14, "isla de aventuras"), decidido en la entrevista del 27-10-2026. Todavía no hay código: se construirá en su propia fase (`docs/PLAN.md`, "Fase 14"). Resumen en el GDD §7.2.

## 1. Qué es

Una **mazmorra por instancias** para el grupo de amigos, dentro de la roca con forma de cráneo de mono de la **Isla Calavera** (la más cercana al Lobby, al suroeste; GDD §7.1). Por dentro es un **ala de pruebas del Proyecto PRIMAL**, excavada en la roca y abandonada después de la erupción: celdas, salas de pruebas con trampas para medir a los primates mejorados, y en el fondo lo que el laboratorio nunca pudo controlar.

La Isla del Volcán es supervivencia abierta y larga (días y noches). La Calavera es lo contrario: **un recorrido de 25–35 minutos**, de sala en sala, con un final claro y un botín que solo sale aquí.

## 2. El grupo

- **De 1 a 5 jugadores**, el mismo grupo de amigos de la Isla.
- Cada uno llega con su **rol, sus talentos y su mejor equipo forjado** (el `bestGear` del perfil, esta vez con sus números, no solo el aspecto como en el Lobby y Dunas). Es PvE: aquí sí cuenta el progreso.
- La **dificultad escala con el número de jugadores** (vida y daño de los monos y de los jefes, número de monos por oleada), con la misma regla de `Config.Difficulty` que la Isla.
- **Entrada:** un embarcadero nuevo en el Lobby con su barca hacia la Calavera y el cartel **💀Isla Calavera🗝️(mazmorra)** en la plaza. Se va con el grupo del Lobby o por **cola** (la cola de Dunas, `ArenaQueueService`, con la dificultad como clave) para completar el grupo con otros. Se elige la dificultad antes de zarpar.

## 3. El recorrido

**Tres pisos**, cada uno con **5–6 salas hechas a mano**. En cada partida se elige al azar una **variante** de cada sala (qué oleada, qué trampa o qué acertijo trae), así que el orden y la forma de los pisos se aprenden, pero lo que pasa dentro cambia. Cada piso tiene una **sala secreta** escondida.

| Piso | Ambiente | Salas | Final del piso |
|---|---|---|---|
| **1. Las Fauces** | Cueva de la boca de la calavera: roca, antorchas, raíces, los colmillos de piedra como columnas | 5 + 1 secreta | Jefe intermedio: **el Narigudo Carcelero** |
| **2. Las Celdas del PRIMAL** | Celdas y salas de pruebas del laboratorio, metal oxidado, agua estancada y tubos de suero | 6 + 1 secreta | Jefe intermedio: **el Dril del Suero** |
| **3. El Ojo** | La cavidad del cráneo: lava detrás de los ojos de la calavera, cristales de ámbar gigantes | 5 + 1 secreta | Jefe final: **el Gelada Rey Calavera** |

- **Puertas:** cada sala se cierra al entrar y se abre al cumplirla. Entre salas hay pasillos cortos para respirar (y donde vuelven los caídos, §4).
- **Duración:** unos 8–10 min por piso y 25–35 min en total en Normal con 4 jugadores. Se medirá en la fase de código con la duración real de las oleadas y de los jefes.

### 3.1 Tipos de sala

Cada sala es de uno de estos tipos; las variantes cambian los detalles.

- **Oleada:** 2–3 oleadas de monos de las especies de la Isla (en el piso 3, con algún alfa). La sala se abre al vencer la última.
- **Trampa:** hay que cruzarla. Ejemplos:
  - **Pasillo de lanzas:** salen del suelo en filas con aviso (las baldosas tiemblan antes).
  - **Dardos de las paredes:** caras de mono talladas que escupen dardos envenenados (veneno **morado**) cuando pisas una placa.
  - **Péndulos:** hachas de piedra que cruzan el pasillo a ritmo; el ritmo se acelera en Pesadilla.
  - **Suelo falso:** baldosas que se hunden en lava; las buenas tienen un símbolo que se ve si te fijas.
- **Acertijo:** se puede resolver **con 1 jugador** (con más, más rápido). Ejemplos:
  - **Espejos:** girar espejos para llevar un rayo de luz al ojo de una estatua.
  - **Campanas:** tocar campanas en el orden de un mural.
  - **Pesos:** empujar bloques de piedra a placas de presión para abrir la puerta.
  - **Palancas del laboratorio:** activar palancas que encienden luces de colores hasta copiar el panel de la pared.
- **Mezcla:** en los pisos 2 y 3, salas con oleada **y** trampa a la vez (pelear entre las lanzas).

Los avisos de las trampas se ven sin sonido y en el teléfono (`Combat/Hazards`, con su marca, como los especiales de los jefes que caen del cielo). Las trampas también hacen daño a los monos.

### 3.2 Secretos

- Una **sala secreta por piso**, detrás de una pared agrietada que se rompe con una habilidad de daño (como las coberturas de Dunas, `breakCovers`), de una baldosa que suena hueca o de un hueco al que solo se llega saltando desde un sitio concreto.
- Dentro hay una **llave de la Calavera** y una **nota del laboratorio** (lore del Proyecto PRIMAL, que se guarda en la bitácora del Lobby).
- Las llaves abren el **cofre de la Calavera** que aparece después del jefe final (§5).

### 3.3 Los jefes

Tres especies **nuevas**, voxel, con aspecto propio en cada fase (como los 4 jefes de la Isla) y que se distinguen a primera vista también por detrás. Todos sus golpes llevan preparación (`EnemyAttack.windup`) y sus ataques de área, marca de aviso.

- **El Narigudo Carcelero** (piso 1). Un mono narigudo enorme con un aro de llaves y cadenas. Fase 1: barre con la cadena en arco. Fase 2 (al 50 %): abre celdas y suelta monos pequeños; hay que cerrarlas con las palancas de la sala mientras se pelea.
- **El Dril del Suero** (piso 2). Un dril con la cara de colores y tanques de suero a la espalda. Fase 1: carga en línea recta y deja charcos de suero (veneno **morado**). Fase 2: se inyecta suero y crece; sus cargas rompen los pilares de la sala. Si chocas su carga contra un pilar, queda aturdido unos segundos.
- **El Gelada Rey Calavera** (piso 3, final). Un gelada con melena y el pecho al rojo vivo (lava), con una corona hecha de un cráneo. Tres fases: 1) golpes y rugidos que empujan; 2) los ojos de la calavera disparan rayos de lava que barren la sala y hay que esconderse tras los cristales de ámbar; 3) al 30 %, la sala se inunda poco a poco de lava desde los bordes y llama a los dos jefes intermedios en versión menor.

Duración objetivo con 4 jugadores en Normal: **60–90 s** cada jefe intermedio y **2,5–4 min** el final. Se medirá con `Equilibrio` (`jugadoresJefe`, las armas de la forja de `bestGear`) antes de escribir sus números.

## 4. Muerte

- **Caído y reanimación**, como en la Isla: un aliado te levanta.
- Si nadie lo hace, **vuelves en el siguiente punto de control**: el pasillo entre salas por el que ya pasó el grupo (en Pesadilla, solo al empezar cada piso).
- Si **caen todos a la vez**, se pierde la partida: vuelven al Lobby con lo que hubieran cobrado hasta el último jefe vencido (sin el cofre del final).

## 5. Botín propio

Lo que solo sale aquí. Nada se vende con Robux (lo comprueba la sección "Reglas de pago" de `Economia`).

| Botín | De dónde sale | Qué es |
|---|---|---|
| **Huevo mítico** | Jefe final, con probabilidad baja (§6) | Al abrirse da el **Quetzalcóatl** (la montura mítica) o una **mascota mítica nueva** (por diseñar, voxel, en la fase de código). Si ya tienes lo que sale, se cambia por Ámbar (la regla de las repetidas: 1.000) |
| **Set de armadura de la Calavera** | Piezas de los 3 jefes | Un set por rol, de huesos tallados, ámbar y metal oxidado del laboratorio, en **grados I, II y III** (Normal, Difícil, Pesadilla) que comparten materiales, paleta y motivos. Es tan bueno como lo mejor de la forja, nunca mejor: cambia el estilo y una ventaja horizontal |
| **Armas de la Calavera** | Jefes (sobre todo el final) | Un arma por rol con forma propia (p. ej. un garrote de colmillo, un arco de costilla), con las mismas reglas que el set |
| **Skins de arma y atuendo** | El cofre de la Calavera | Cosméticos de la Calavera (rareza épica y legendaria) que no salen en ninguna tienda |
| **Llaves y cofre** | Salas secretas | Cada llave abre una cerradura del cofre del final: más llaves, más Ámbar y más probabilidad de un cosmético |

**Cómo se usa el equipo de la Calavera fuera de la mazmorra:** el inventario de la Isla es por partida, así que el set y las armas se guardan en el perfil como **planos**. En la mazmorra se llevan puestos. En la Isla, el plano deja forjarlos en la forja del nivel más alto con los mismos materiales que el equipo de ese nivel. En el Lobby y en Dunas se ven como el `bestGear` (solo el aspecto).

## 6. Números de la economía (medidos)

Línea base de `Economia` del 27-10-2026: la Isla da unos 6,4 de Ámbar por minuto (perfil intenso) y Dunas unos 7,2. La mazmorra queda igual o por debajo de la Isla:

| Dificultad | Ámbar al vencer al jefe final | Con 3 llaves (+20 cada una) | Por minuto (30 min) | Probabilidad del huevo mítico | Partidas medianas hasta el huevo |
|---|---|---|---|---|---|
| Normal | 80 | 140 | 4,7 | 0 % | — |
| Difícil | 110 | 170 | 5,7 | 0,5 % | 139 |
| Pesadilla | 140 | 200 | 6,7 | 1,5 % | 46 |

- **Tope semanal de botín:** las **10 primeras partidas ganadas** de la semana dan todo el botín (Ámbar entero, piezas, tirada del huevo). Las demás dan la mitad del Ámbar y nada más. Así nadie agota la mazmorra en tres días, y como mucho entran unos 2.000 de Ámbar a la semana.
- **Ritmo del huevo mítico:** con 3 partidas de Pesadilla a la semana, la mitad de los jugadores lo tiene en unas 15 semanas; con 10 a la semana (el tope), en unas 5. Es más lento que la tirada de pioneros para el Quetzalcóatl (7 % por ciclo de 7 días), que es la forma de tenerlo para quien juega todos los días.
- **XP del pase:** 300 al vencer al jefe final (lo mismo que un rescate de la Isla), dentro del tope diario.
- La calculadora `Economia` tendrá una sección de la mazmorra en la fase de código (Ámbar por perfil con el tope semanal y partidas hasta el huevo).

## 7. Rejugabilidad

- **Tres dificultades:** **Normal**, **Difícil** (se abre al vencer Normal) y **Pesadilla** (se abre al vencer Difícil). Cada una con más vida y daño de los enemigos, trampas más rápidas, menos puntos de control en Pesadilla y mejor botín (grados del set y probabilidad del huevo). Se abren por jugador; el grupo puede entrar en la más alta que tenga abierta su líder.
- **Ranking de tiempo:** el mejor tiempo de cada dificultad, con los nombres del grupo y su tamaño, en un bloque nuevo del cartel del Ranking del Lobby.
- Las variantes de las salas (§3) y las salas secretas hacen que cada partida sea algo distinta sin dejar de ser aprendible.

## 8. Qué se reutiliza y qué es nuevo

| Se reutiliza | Es nuevo |
|---|---|
| Combate completo de la Isla (`src/combat`: roles, habilidades, combos, estados, caído y reanimación) | Reglas del place (`DungeonCombatRules`) |
| Monos (`Data/Monkeys`, `MonkeyService`) y la estructura de los jefes por fases (`Data/Bosses`, `BossService`) | Los 3 jefes nuevos y sus modelos voxel por fase |
| `Combat/Hazards` (avisos), coberturas que se rompen (`breakCovers`) | Trampas, acertijos, puertas y puntos de control |
| `Config.Difficulty` (escala por jugadores), `bestGear` | Generador de los pisos y las variantes de sala (`World/DungeonBuilder`) |
| Cola de Dunas, `Leaderboards`, `SeasonPass`, `Eggs` y `PetRoll` (huevo mítico, repetidas) | Set y armas de la Calavera, planos en el perfil, cofre de llaves |

Place nuevo con su ID en `Config.PlaceIds.Calavera` y su proyecto de Rojo (`calavera.project.json`, puerto 34876).

## 9. Para más adelante y riesgos

- **Más adelante:** modificadores semanales (niebla, monos explosivos, sin curación) con botín extra, un cuarto piso de temporada, jefes que rotan.
- **Alcance:** es el place con más contenido hecho a mano (17 salas, sus variantes y 3 jefes). En la fase de código se empieza por un piso entero jugable antes de hacer los otros dos.
- **Rendimiento en el móvil:** un piso cargado cada vez (StreamingEnabled) y los monos de la sala activa solamente.
- **Jugar solo:** todos los acertijos y trampas tienen que poder hacerse con 1 jugador; se prueba así antes de cerrar cada piso.
