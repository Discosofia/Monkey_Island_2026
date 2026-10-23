# Primal Banana Islands: Monkey Survival — Documento de Diseño del Juego (GDD) v0.3

> **Estado:** diseño base confirmado tras la entrevista (v0.2: todas las propuestas de la v0.1 confirmadas). v0.3 (21-10-2026): pase de temporada, misiones v2, contratos, eventos de mitad de partida, cosméticos y tiendas (Fase 9 de `docs/PLAN.md`; §4, §5.4, §11 y §14).
> **Nombre:** **Primal Banana Islands: Monkey Survival** (ver [§15](#15-nombre)). El repositorio conserva el nombre `monkey_island_2026`.

---

## 1. Visión

**Pitch:** *Naufragas en una isla tropical llena de monos salvajes y traviesos que te roban la comida. Con hasta 19 jugadores más, especialízate como guerrero, cazador, mago o médico, fortifica el Basecamp, sobrevive noches cada vez más feroces y derrota a los jefes de la isla para encender la baliza de rescate.*

### Pilares de diseño

1. **Cooperar por necesidad.** Los roles se complementan, un compañero te puede reanimar y el núcleo del Basecamp es de todos.
2. **La isla está viva.** Los monos tienen comportamiento social (tropas, alfas, ladrones). Hay ciclo día/noche, clima y eventos.
3. **Tú eliges el riesgo.** Cuanto más lejos del Basecamp, mejor botín. El PvP es *opt-in*.
4. **Siempre progresas.** Moneda, talentos de rol, mascotas, bestiario y récords. Incluso una mala partida deja algo.

### Público y plataformas

- **Público:** jugadores de Roblox (≈10–16+ años) a los que les gustan los juegos de supervivencia, exploración y coleccionables.
- **Plataformas:** **Móvil + PC** desde el día 1 (controles táctiles, UI escalable y rendimiento en gama baja). Consola más adelante.
- **Estilo visual:** **low-poly estilizado** y colorido. El tono es de aventura con tensión. La violencia es estilizada, **sin sangre ni gore**.
- **Referentes del género en Roblox:** juegos de supervivencia de día/noche como *99 Nights in the Forest*. Nuestros diferenciadores son el **ecosistema de monos con bestiario**, el **huevo y las mascotas coleccionables**, el **objetivo de rescate**, el **Basecamp compartido entre amigos (hasta 5)** y el **PvP por eventos**.

---

## 2. Decisiones tomadas en la entrevista

| Tema | Decisión |
|---|---|
| Muerte | **Caído + reanimación.** Si nadie te reanima en 1 minuto (o te rindes), reapareces en tu cama o en el Basecamp y pierdes parte del inventario, que queda en una mochila donde caíste. |
| Fin de partida | **Infinita + objetivo de rescate.** Se sobrevive el máximo de días posible, pero se puede **ganar** construyendo la baliza de rescate. |
| PvP | **Opt-in en eventos y zonas.** El Basecamp es seguro. El PvP ocurre en cajas de suministro, el huevo y jefes disputados. |
| Monetización | **Moneda del juego** para las mejoras. **Robux solo para cosméticos y comodidad.** Nada de pay-to-win. |
| Equipo | Desarrollador en solitario (experiencia **básica** en Studio/Luau). **Claude escribe el código** en el repo. |
| Plataforma | **Móvil + PC.** |
| Combate | **3ª persona**, cuerpo a cuerpo + distancia (machete, lanza, honda, arco) con esquiva. |
| Arte | **Low-poly estilizado.** |
| Basecamp | **Núcleo compartido** (nido, baliza, defensas, estaciones grandes) **+ parcela personal** por jugador. |
| Ciclo día/noche | **Configurable.** Se empieza con **10 min de día + 7 min de noche** y se ajusta con playtests. |
| Roles | **Fijo por partida** (se elige en el lobby) + **árbol de talentos** que progresa entre partidas. |
| Mascotas | **Persistentes.** Cada participante del rescate del huevo recibe una tirada. Se coleccionan y se lleva 1 activa. |
| Huevo | **Evento PvP opt-in.** El portador queda marcado y los jugadores con PvP activo pueden robárselo. |
| Servidor | **Lobby hasta 20**, **Isla de monos hasta 5** y **Isla de dunas hasta 10** (5v5); se configura en Roblox por place ([SETUP.md](SETUP.md) paso 7). Una partida de la Isla de monos es para **un grupo de amigos** (hasta 5, que viajan juntos desde el Lobby). Si sobran plazas, se puede entrar a una partida en curso. *(Cambio del 20-10-2026: al principio eran 20 jugadores que no se conocían; ahora el juego está pensado para jugar con tus amigos.)* |
| Asedio nocturno | **Sí.** El Basecamp es seguro **mientras resistan las defensas**. |
| Fiebre del mono | **Sí.** Infección por mordiscos que cura el médico. |
| Lore | **Santuario-laboratorio** abandonado (Proyecto PRIMAL). |
| Jefes | **Uno cada 2 días**, rotando por los 4 biomas. |
| Baliza de rescate | Se puede encender desde el **día 8**, cuando ya es posible tener las 4 piezas. |
| Especies | Se añade la **marteja** (mono nocturno) a la categoría 1. |
| PvP en playas | **Cajas de suministro** que llegan por mar = zonas de PvP. |
| Nombre | **Primal Banana Islands: Monkey Survival.** |
| Arena PvP (20-10-2026) | **Isla de Dunas: captura la bandera por equipos**, de 1v1 a 5v5, con cola desde el Lobby y equipamiento propio comprado con Ámbar (§12.2). |

---

## 3. Flujo del jugador

```mermaid
flowchart TD
  L["Lobby: socializar, elegir rol, probar sus habilidades, tienda, mascota activa"] --> Q["Matchmaking: solo o con amigos"]
  Q --> T["Teleport a la Isla (servidor de hasta 5)"]
  T --> B["Aparece en el BASECAMP"]
  B --> P["Partida: ciclo día/noche"]
  P --> C{"¿Caído?"}
  C -->|"Un aliado te reanima"| P
  C -->|"Se agota el tiempo o te rindes"| B
  P --> R{"¿Fin?"}
  R -->|"Todos caídos a la vez"| D["Derrota del servidor"]
  R -->|"Baliza encendida + noche final superada"| V["Victoria: rescate"]
  R -->|"El jugador sale"| X["Salida voluntaria"]
  D --> RW["Recompensas: moneda, XP de rol, récords, bestiario"]
  V --> RW
  X --> RW
  RW --> L
```

**Probar el rol en el Lobby (20-10-2026).** En la plaza del Lobby cada jugador lleva las armas y las 5 habilidades de su rol elegido, con sus talentos, mejoras y mascota, y las prueba contra tres muñecos de práctica (los del Basecamp) antes de zarpar a la Isla de monos o a la Isla de dunas. Nunca afectan a otros jugadores: no les hacen daño, ni los curan, ni los protegen, ni les ponen estados (las curaciones y escudos solo van a uno mismo), y practicar no cuenta para las misiones del día. Lo deciden las reglas del combate del Lobby (`LobbyCombatRules`).

**Menú del Lobby por estaciones (20-10-2026).** El menú tenía 11 pestañas y estaba saturado. Ahora lo que tiene un sitio en la plaza se usa allí: el jugador se acerca, pulsa el aviso (E o tocar) y se abre una **ventana propia** con solo eso, que se cierra sola al alejarse.

| Estación (en la plaza) | Qué abre |
|---|---|
| Cartel **Elige tu rol** | Los cuatro roles y un atajo a los talentos del rol elegido, que palpita con un aura roja si hay puntos por gastar o se acaba de cambiar de rol |
| **Nido de huevos**, delante del cartel **🐾 Mascotas** | El nido, la mochila, los pendientes y la colección. El cartel enseña el huevo que se incuba, la mochila y la mascota que te acompaña; se interactúa con el nido |
| Cartel **🎖️Isla de dunas☠️(PvP)** (y su velero) | La arena: formato, cola y equipamiento por rol. El cartel enseña tus números, el Ámbar de hoy y cuántos esperan en cada formato |
| Cartel **🏆 Ranking** | Las cuatro clasificaciones (días, rescates, victorias y banderas en la arena), con el top 10 y tu número. El cartel enseña el top 5 en dos bloques, supervivencia y arena |
| Cartel volcánico del **🌋 Pase** (Fase 9) | El pase de temporada (§14.1). El cartel enseña la temporada, la cuenta atrás, tu nivel y los próximos premios, con "!" si hay algo que reclamar |

El resto (Talentos, Tienda, Misiones, Pase, Armario, Emotes, Grupo, Diario y Ajustes) va en una **barra de iconos**: en columna a la izquierda en PC y en fila arriba en el móvil, con un **punto rojo** cuando hay algo pendiente (talentos por gastar, premio del calendario). Arriba, una pastilla con el Ámbar y el récord; el título del juego se va a los pocos segundos. Las ventanas se ajustan a su contenido para verlo todo sin desplazarse (las listas largas, en columnas). Para que se encuentren las estaciones: un **icono flotante** sobre cada una con "!" cuando hay algo para ti, un **contorno dorado** al acercarse y una **guía la primera vez** (un rastro dorado al cartel de roles y después al nido).

---

## 4. Bucles de juego

### Bucle principal (dentro de la partida)

```mermaid
flowchart TD
  A["Explorar la isla"] --> B["Recolectar recursos y cazar monos"]
  B --> C["Volver al Basecamp con el botín"]
  C --> D["Craftear equipo y construir"]
  D --> E["Resistir la noche"]
  E --> F["Mejor equipo = zonas más peligrosas"]
  F --> A
  B -.->|"evento"| G["Huevo / Jefe / Caja de suministro"]
  G --> C
```

### Bucle meta (entre partidas)

```mermaid
flowchart LR
  P["Jugar partida"] --> M["Ganar Ámbar + XP de rol"]
  M --> U["Comprar mejoras en el lobby"]
  M --> T["Desbloquear talentos del rol"]
  P --> H["Salvar huevos"]
  H --> N["Incubar en el nido del lobby"]
  N --> PE["Nace una mascota"]
  P --> BE["Completar el bestiario"]
  P --> XP["XP del pase de temporada"]
  XP --> PA["Niveles del pase: Ámbar, huevo y cosméticos"]
  M --> CS["Tienda de cosméticos en Ámbar"]
  U --> P
  T --> P
  PE --> P
  BE --> P
  PA --> P
  CS --> P
```

### Bucle de retención (entre días, octubre de 2026)

El núcleo son los **huevos y las mascotas** (§11): el huevo se gana en la isla, se incuba con horas reales en el nido del lobby y jugar lo acelera. Alrededor van tres cosas que dan un motivo para volver cada día:

- **Calendario de 7 días:** basta con entrar al lobby para cobrar el premio del día (una ventana al llegar y la ventana **Misiones** del menú). **Faltar un día no lo reinicia**: al volver se cobra el siguiente. Tras el día 7 vuelve al 1. El día cambia a las **00:00 UTC**.

  | Día | Premio |
  |---|---|
  | 1 | 100 de Ámbar + 5 bananos |
  | 2 | Antorcha + 10 de fibra |
  | 3 | 2 vendas + 1 h para el huevo del nido |
  | 4 | 100 de Ámbar + 2 antídotos |
  | 5 | 250 de Ámbar |
  | 6 | Kit de reanimación + 2 super vendas + 2 h para el huevo |
  | 7 | **Huevo raro o mejor** (raro 13 · épico 6 · legendario 1) + 500 de Ámbar |

- **Misiones diarias (v2, Fase 9):** cada día tocan **3, una de cada dificultad**: una **fácil** general (derrotar 10 monos, recolectar 40 recursos, fabricar 2 objetos o construir 1 pieza; unos 8–13 min), una **media** del rol elegido (cerrar combos, hacer daño o usar habilidades del rol; 17–20 min; si cambias de rol, cambia esa, salvo que ya estuviera cumplida) y una **difícil** que pide avanzar en la partida (llegar al día 4, superar 3 noches, derrotar 2 jefes o 2 alfas, salvar 2 huevos; 50–67 min, casi la mitad de una partida). **Un cambio gratis al día** da otra de la misma dificultad. Solo cosas que se pueden hacer **jugando solo** (nada de reanimar o curar aliados) y el daño al muñeco de práctica no cuenta. Premio: fácil 40 de Ámbar, −15 min de huevo y 200 de XP del pase; media 70, −25 min y 200; difícil 120, −40 min y 300.
- **Misiones semanales:** cada lunes (00:00 UTC) tocan **5 de 13** (alfas, jefes, construir, fabricar, huevos, llegar al día 6, recolectar, monos, noches, rescate, especies distintas del bestiario y, como mucho una, ganar o capturar en Dunas), sin dos de la misma familia, con **un cambio gratis a la semana**. Cada una da 150 de Ámbar y 500 de XP; las 5 juntas, 250 de Ámbar, −1 h de huevo y 500 de XP más. Las de Dunas avanzan jugando en la arena.
- **Dónde se ven:** en la isla, en un rastreador bajo los combos con las diarias y las semanales, que se pliega (en el móvil, fichas en la franja de la barra de Roblox); en el lobby, en la ventana **Misiones** (pestañas Hoy y Semana).
- **Provisiones de partida:** el inventario de la isla no se guarda entre partidas, así que los objetos del calendario, las misiones y el pase se guardan en el perfil y **llegan a la mochila al empezar la siguiente partida**. En el lobby se ven encima de "Ir a la Isla".
- **Pase de temporada** (§14.1): las partidas, Dunas y las misiones dan XP; cada nivel trae un premio gratis y uno premium cosmético. Es la meta del mes; las misiones, la del día y la semana; los contratos (§5.4), la de cada partida.
- **Título "Superviviente de la Isla":** gratis, sin Game Pass, **solo para quien gana una partida** (rescate con la baliza). Se anuncia en los resultados y se equipa en el Armario. Ningún pase, calendario ni tienda lo da.

Todo se ajusta en `Config.Daily` (calendario, misiones), `Config.Season` (pase) y `Config.Egg` (huevos); las misiones están en `Data/Missions`. Los números se miden con la calculadora `Economia` (skill `economia-retencion`).

---

## 5. La partida

### 5.1 Ciclo día/noche

- Duración **configurable** (`Config.DayLength`, `Config.NightLength`). Valor inicial: **10 min de día + 7 min de noche**.
- **Amanecer:** los monos **reaparecen** (respawn diario), y el contador de días sube.
- **Día:** especies diurnas. Es el momento de explorar y recolectar.
- **Atardecer:** aviso un minuto antes de la noche para volver a la base.
- **Noche:** especies nocturnas, menos visibilidad (antorchas) y **asedio al Basecamp** (§10).

```mermaid
stateDiagram-v2
  state "Amanecer" as Amanecer
  state "Día" as Dia
  state "Atardecer" as Atardecer
  state "Noche" as Noche
  state "Derrota" as Derrota
  state "Victoria" as Victoria
  [*] --> Amanecer
  Amanecer --> Dia: respawn de monos
  Dia --> Atardecer: aviso de 1 minuto
  Atardecer --> Noche
  Noche --> Amanecer: día +1, sube la dificultad
  Noche --> Derrota: todos caídos
  Noche --> Victoria: noche final con la baliza encendida superada
  Derrota --> [*]
  Victoria --> [*]
```

### 5.2 Escalado de dificultad

Cada día aumentan la cantidad de monos, la proporción de especies de categoría alta y la fuerza del asedio nocturno. Así una partida infinita tiene un final natural y el récord de días tiene valor.

### 5.3 Condiciones de fin

- **Derrota:** todos los jugadores del servidor están caídos a la vez (10 s seguidos de noche). Se muestran los resultados y se vuelve al lobby.
- **Victoria (rescate):** se construye la **baliza de rescate** con piezas de los 4 jefes de bioma. Al encenderla empieza la **noche final** ("La Gran Tropa"). Si alguien sigue en pie al amanecer, llega el rescate.
  - La baliza solo se puede encender desde el **día 8** (configurable). Como aparece un jefe cada 2 días (días 2, 4, 6 y 8), antes no se pueden tener las 4 piezas.
- **Entrar a mitad de partida:** se permite mientras haya hueco y no esté en curso la noche final. Las recompensas dependen de la **contribución** mientras estuviste presente.

### 5.4 Metas de mitad de partida (Fase 9)

La partida dura unas 2 h 16 min (8 días de 17 min) y antes había un hueco entre el día 4 y el 8 sin nada nuevo. Ahora cada tramo tiene su meta:

- **Equipo ligado a los jefes** (§9.3): el nivel 3 pide la Corona del caudillo (jefe del día 4) y el nivel 4 de la Forja volcánica, obsidiana y el Cristal de cueva (día 6). Cada jefe da 2 de su tesoro a **cada** participante.
- **Contratos de expedición:** uno por partida, compartido por todo el grupo, de 5 pasos que se abren los días 1, 3, 5, 7 y 8; un paso que no se cumple antes de que se abra el siguiente se pierde. Los objetivos de cantidad crecen con el grupo (+50 % por cada jugador más). Cada paso da a todos los de la partida Ámbar (20 · 20 · 25 · 25 · 50), XP del pase (50 · 50 · 75 · 75 · 125, como XP de partida) y algún objeto. Se ven en una tarjeta bajo el rastreador de misiones (ficha "📜" en el móvil) y en los resultados.

  | Contrato | Día 1 | Día 3 | Día 5 | Día 7 | Día 8 |
  |---|---|---|---|---|---|
  | 🏕️ Campamento del náufrago | Construir 3 piezas | Llegar a la cueva del Gorila Albino | Levantar 4 defensas o el tótem | Abrir una caja militar | Encender la baliza |
  | 📖 Diario del naturalista | Recolectar 80 recursos | Monos de 8 especies | Un alfa | 12 monos | Encender la baliza |
  | 🌋 Ruta del volcán | Fabricar 3 objetos | Derrotar al Chimpancé Caudillo | 6 de obsidiana | Abrir una caja militar | Encender la baliza |

- **Eventos de mitad de partida**, cada uno en un día al azar de los suyos, con aviso la víspera al anochecer y una línea de estado en el HUD:
  - **Lluvia tóxica** (día 3 o 4, 6 min): el agua del río y los mordiscos dan fiebre. Se combate con agua hervida en la hoguera, antídotos (el médico recibe 2) y el Ungüento del médico, que baja la fiebre a quien cura.
  - **Noche de macacos saboteadores** (noche 5): parte de cada oleada son macacos que van a por trampas, muros, barricadas y las estaciones del núcleo (no a por la baliza ni las camas).
  - **Erupción preliminar** (día 7, 150 s): lluvia de piroclastos en las zonas altas y **2 cajas militares** guardadas por babuinos, con obsidiana, vendas, antídoto, comida y una esquirla de jefe al azar. Abrirlas (8 s) activa el PvP durante 4 min.
- **Preparar la Gran Tropa** (noche final): la mitad de los mandriles, orangutanes y gorilas de cada oleada va a por la **baliza** (16.000 de vida; solo la rompen ellos). Si cae, se corta la señal, esa noche no hay rescate y al amanecer se repara y se puede volver a encender. Ayudan el **tótem guardián** (uno por campamento, pide una Perla del río: a 25 studs, −35 % de daño a las piezas y reparación nocturna, −10 % de daño a los jugadores) y las **antorchas de pie**, que espantan a los aulladores del asedio y se gastan. Sin defenderla, la baliza cae al poco de llegar la 5.ª oleada.

---

## 6. El jugador

### 6.1 Estadísticas

| Estadística | Función |
|---|---|
| Vida | Al llegar a 0 quedas **Caído**. |
| Hambre | Baja con el tiempo (unos 20 min de lleno a vacío). Se recupera comiendo: carne cruda (poco), bananos de los arbustos y de los cultivos, plátanos (mejor asados), carne asada y brochetas de la hoguera. |
| Sed | Baja más rápido (unos 14 min). Se recupera bebiendo agua del río. *Más adelante: hervirla, cocos o lluvia.* |
| Estamina | Se gasta al correr y esquivar. Con hambre o sed bajas se recupera más despacio. La lleva el servidor (el cliente la predice), así que no se puede esquivar sin ella. |

A 0 de hambre o de sed se pierde vida y se puede acabar **caído**. La vida solo se regenera con hambre y sed por encima de la mitad.
| Fiebre del mono | Sube con los **mordiscos** de los monos según el daño que entra tras la armadura (+20 por cada barra de vida entera perdida a mordiscos; un mono básico, +1) y con la carne cruda (+12). Piedras, pisotones, jefes y peligros no la suben. Desde 60, tinte morado y **oleadas** cortas de vista borrosa (cada 16 s a 60, cada 7 s a 100); entre oleadas se ve bien. A 100 además quita vida poco a poco. Baja sola 4 por minuto (15 por minuto descansando en el Basecamp); el **antídoto** del taller del curandero la quita de golpe y el remate del combo del médico la baja 9. Ritmo buscado: síntomas tras unos 10 minutos de pelea continua sin curarse. |

### 6.2 Muerte: caído y reaparición

1. **Caído (1 minuto):** te arrastras lento. Cualquier aliado puede reanimarte; el médico lo hace mucho más rápido.
2. **Rendirse:** si nadie va a llegar (jugando solo, por ejemplo), mantén pulsado **Rendirse** (F, X en mando o el botón táctil) para no esperar el minuto entero. Vale a partir de los 3 s de caer.
3. **Reaparición:** si se acaba el tiempo o te rindes, dejas una **mochila** con la mitad de cada material en el sitio donde caíste (solo tú puedes recuperarla; el equipo, como la antorcha, no se pierde) y reapareces al momento en tu cama o en el Basecamp, con toda la vida. *(Antes había una fase de Espíritu de 45 s a 3 min; se quitó el 19-10-2026.)*

### 6.3 Roles

El rol se elige en el lobby y es **fijo durante la partida**. Cada rol tiene su propia **XP** que desbloquea talentos de forma permanente.

Cada rol tiene una **pasiva**, sus **armas iniciales** (además del hacha y el pico) y **5 habilidades**: 4 activas (**Z, X, C, R**) y una **definitiva** (**V**) con un tiempo de espera largo. Con mando se mantiene **R1** y se pulsa **A, B, X, Y o L1**; en móvil son 5 botones junto al salto. La cuarta activa va en la **R** y no en la E porque la E es la tecla de los avisos (recoger, reanimar, fabricar…). Solo gastan tiempo de espera. Con el PvP activo también afectan a otros jugadores, con la mitad de daño y aturdimientos de la mitad de tiempo; las definitivas, con un 40 % de esa mitad (ningún golpe de una habilidad pasa de 40 de 100: el Pisotón quitaba 94). Los números están en `Config.Abilities`.

| Rol | Pasiva | Armas iniciales | Activas (Z · X · C · R) | Definitiva (V) |
|---|---|---|---|---|
| ⚔️ **Guerrero** | +25 % daño cuerpo a cuerpo, +20 de vida. Lleva mejor el huevo. | Garrote de piedra, honda | **Torbellino** (golpes alrededor 2 s) · **Embestida** (carga de 20 studs que empuja; contra un muro, rebote) · **Grito de guerra** (atrae a los monos y −40 % de daño 4 s) · **Rompehuesos** (golpe de 24 al cono de delante que tumba 0,5 s y aparta ~4,5 studs; contra un muro, rebote; 8 s) | **Pisotón:** 150 de daño en área y aturde 2 s |
| 🏹 **Cazador** | +25 % daño a distancia. | Arco (gasta flechas), machete | **Disparo múltiple** (abanico de 5) · **Marcar presas** · **Cepo** (cuando un mono lo pisa, atrapa unos 2 s a todos los que estén a 8 studs) · **Flecha perforante** (17 a cada mono que atraviesa en línea; 8 s) | **Lluvia de proyectiles:** zona con 160 de daño en 4 s |
| 🔮 **Mago** | +25 % daño de hechizos, habilidades un 15 % más rápidas. | Bastón mágico (sin munición), machete | **Bola de fuego** (explota en área) · **Nova de hielo** (congela 1,2 s y ralentiza; el suelo se queda helado 3 s: lento y, a un rival, resbala) · **Parpadeo** (teletransporte de 25 studs) · **Meteoro** (cae donde apuntas tras 0,8 s de aviso: 24 en 9 studs; 10 s) | **Rayo encadenado:** salta entre 5 monos, −25 % por salto |
| ⛑️ **Médico** | Ve la vida de todos. Reanima 2× más rápido. +15 de vida máxima. **Savia protectora:** al curar a un aliado gana un escudo de 10 durante 5 s (como mucho uno cada 8 s; no pisa un escudo mayor). | Cerbatana (sin munición; cada dardo que acierta cura un poco al aliado más herido cerca y **envenena** al mono: 5 de daño por segundo durante 4 s, números morados y vapor morado; no se acumula, cada acierto lo renueva), machete | **Ungüento en área** · **Dardo curativo** (cura a distancia) · **Escudo de hojas** (absorbe 24) · **Polvo somnífero** (nube donde apuntas: 1 s de sueño lento y luego duermen 1,5 s; los jefes no se duermen; la nube se queda 3 s y quien entra va lento, sin dormirse; 12 s) | **Tótem sanador:** se planta donde apuntas (hasta 40 studs) y cura a quien esté cerca durante 10 s |

**Armas de rol y sus mejoras** (forja de piedra; solo las ve su rol): garrote de piedra → maza de hueso → mazo de hueso grueso (guerrero); arco → arco reforzado → arco de liana (cazador); bastón mágico → bastón dorado → bastón de plata (mago); cerbatana → cerbatana de hueso → cerbatana del chamán (médico: 14 → 17 → 22 de daño base, veneno de 5 → 7 → 9 por segundo durante 4 s y +2 → +3 → +5 de curación por acierto, a menos de 40 studs). Desde el 19-10-2026 el médico hace ~60 % del daño de un rol de daño contra un mono (antes ~36 % con la cerbatana básica), casi todo con la cerbatana y su veneno; medido con la calculadora `ServerStorage.Tools.Equilibrio`.

Los **talentos** (5 por rol) mejoran cada uno una habilidad: más duración, más daño, más proyectiles o más saltos. Los de las cuartas activas: **Mazazo** (+20 % de daño del Rompehuesos por rango), **Punta de obsidiana** (+20 % de la Flecha perforante), **Polvo de estrellas** (el Meteoro ralentiza 1 s por rango; con más daño valía demasiado) y **Sueño profundo** (+0,3 s de sueño). Las ventajas de recolección (recoger más rápido, +1 material, hacha y pico más fuertes) son **mejoras de la tienda** para cualquier rol.

**Armaduras por rol** (octubre de 2026): las tres armaduras (chaleco de pelaje 25 %, hueso 40 %, plata 55 %) tienen los mismos números y recetas para todos, pero cada rol las lleva con su propio aspecto y nombre (`Data/Armor` "roleNames", modelos en `Shared/ArmorModels`). Cazador: **capa de rastreador** (jubón de cuero claro y esclavina parda con un abanico de hojas en la espalda), **armadura de cazador** (cuero oscuro con botones y hombrera de hueso, manto de hojas y carcaj de hueso con flechas de plumas rojas) y **manto de cazador plateado** (capa de pelaje plateado con hojas oscuras, capucha con orejas, garras de hueso en los hombros y carcaj negro con aros de plata). Todas con la capucha bajada y el carcaj cruzado a la espalda. Mago (de chamán; brillan en azul, porque el morado es del veneno y el verde de las curaciones): **manto de amuletos** (poncho de fibra con flecos, collar de cuentas y un atrapasueños en la espalda), **túnica de runas** (túnica añil con cráneos de ojos encendidos en los hombros y un círculo de runas de neón en la espalda) y **manto de cristal** (capa de pelaje plateado con una corona de cristales que asoma por encima de los hombros). Médico (de curandero; lo que brilla, en verde, el color de las curaciones): **bandolera de curandero** (túnica de lino con bolsitas de hierbas y un manojo de hierbas en la espalda), **peto de curandero** (peto de hueso blanco con una cruz de hojas y una mochila con frascos de poción en la espalda) y **manto de sanador** (manto plateado con frascos que brillan y un tótem sanador pequeño en la espalda, como el de la definitiva).

**Equipo lucido en el Lobby y en Dunas** (22-10-2026): el perfil guarda, por rol, la mejor armadura y el nivel más alto del arma de rol fabricados en la Isla (`bestGear`). En el Lobby y en Dunas el personaje los lleva puestos, **solo como aspecto**: la armadura no reduce el daño y el arma sigue siendo la inicial (nombre, daño y tiempos), con el modelo del nivel fabricado. Así la arena sigue igualada y el equipo de la Isla se enseña fuera de ella. Con un traje equipado se ve el traje, como en la Isla.

Las sinergias son intencionadas: el guerrero **aguanta** y agrupa a los monos, el mago y el cazador los **castigan** en área y el médico **mantiene vivo** al grupo.

*Cambio de octubre de 2026:* el Recolector se sustituyó por el Mago. Su XP pasó al Mago y los puntos de sus talentos quedaron libres para repartirlos de nuevo.

*Cambio de octubre de 2026 (ritmo):* las activas (Z, X, C) se recargan un **40 % antes** y sus daños, curaciones, escudos y duraciones bajan un **40 %**: el daño por segundo es el mismo, pero se usan casi el doble y se enlazan en **combos** (§6.4). Las definitivas no cambian. "Golpe sísmico" pasa a llamarse **Pisotón**.

| Rol | Recargas Z · X · C (antes → ahora) |
|---|---|
| Guerrero | Torbellino 12 → 7 s · Embestida 10 → 6 s · Grito 25 → 15 s (→ 12 s, ver §6.4) |
| Cazador | Disparo múltiple 8 → 5 s · Marcar 30 → 18 s (→ 15 s, ver §6.4) · Cepo 15 → 9 s |
| Mago | Bola de fuego 10 → 6 s · Nova 18 → 11 s · Parpadeo 12 → 7 s |
| Médico | Ungüento 40 → 24 s (→ 15 s, ver §6.4) · Dardo 10 → 6 s · Escudo 20 → 12 s |

*Armas a distancia (animación):* con una honda, un arco, un bastón o una cerbatana en la mano, el brazo derecho cuelga junto al cuerpo; al disparar, el personaje hace el movimiento de su arma (estirar la goma, tensar y soltar la cuerda, alzar y lanzar el bastón con un destello, llevarse la cerbatana a la boca y soplar). Son animaciones de Roblox (R15) que genera `ServerStorage.Tools.WeaponAnimationBuilder` y se publican con sus ids en `Data/WeaponAnimations`.

### 6.4 Críticos, combos y números de combate

**Críticos** (`Config.Crit`, `Shared/Crit`): hacen **×1,35** (+35 %) y su número sale un **25 % más grande**, con "!" y un temblor.

| Quién | Probabilidad |
|---|---|
| Armas del jugador | 5 % el arma básica, 10 % la primera mejora de la forja, 15 % la segunda (`critChance` en `Data/Weapons`). Las habilidades usan la del arma de la mano o, si no es un arma, la de la mejor que lleves. |
| Curaciones del médico | 10 % + la del arma; +30 % si el aliado tiene menos del 35 % de vida ("salvada"). Vendas, ungüentos y reanimar nunca. |
| Mascotas | 10 % en sus golpes y curaciones. |
| Monos de categoría 2 / 3 | 15 % / 20 % (categoría 1: nunca). |
| Jefes | 25 % en las fases 1 y 2; 28 % en la fase 3 (furia). |

**Combos** (`Data/Combos`, `ComboService`): cada rol tiene **dos**, de tres habilidades **en orden**, con 6 s como mucho entre una y otra (si la siguiente aún se está recargando, los 6 s cuentan desde que esté lista). Cada combo empieza con una habilidad distinta: **la que usas primero decide cuál está en marcha**. La primera **marca** lo que toca; la segunda y la tercera hacen **críticos seguros con daño extra** a los marcados (+25 % el guerrero, +10 % el cazador, nada el mago) y el remate tiene un efecto extra.

**Conexiones:** al cerrar un combo, el otro queda **abierto en su paso 1**: lo marcado sigue marcado, lo que golpea el remate se marca y se sigue directamente por su **paso 2** (A → B → A…). Cada combo cerrado tras una conexión sube la racha **un nivel más** y sale "¡CONEXIÓN! N seguidos"; en el indicador, el paso saltado lleva "🔗". Ningún combo usa la definitiva (V): con 90 s de recarga casi nunca se podía cerrar. Cada paso enlazado la acerca **10 s**, como mucho **20 s por recarga**.

*Cambio de octubre de 2026 (valor de los combos):* antes casi todo el premio era acercar la definitiva sin límite, y el mago, que cierra un combo cada ~9 s, la lanzaba casi el triple. Ahora la devolución tiene tope, el daño extra va por rol y la explosión del remate del mago es un 25 % más grande (antes 50 %). Enlazar da +20–30 % de daño en una pelea larga contra un grupo a los tres roles de daño (medido con `ServerStorage.Tools.Equilibrio`).

*Cambio de octubre de 2026 (enlazar combos seguidos):* al guerrero le costaba encadenar un combo tras otro. La Embestida (6 s) se recargaba mucho antes que el Grito (15 s): si la usabas suelta, el combo nuevo empezaba sin Grito disponible y se perdía, y cuando el Grito volvía la Embestida estaba otra vez recargándose. Ahora la ventana espera a que el paso siguiente esté listo (vale para todos los roles) y el Grito se recarga en **12 s** con **4 s** de protección (el mismo tercio del tiempo protegido que antes): un combo completo cada 12 s en vez de cada 15 s. Enlazar le da al guerrero +30 % de daño en grupo en 180 s (el límite es 35 %).
El hueco entre combos lo marca la recarga más larga de sus pasos. Pasaba lo mismo, más acusado, con el cazador (Marcar presas, 18 s) y el médico (Ungüento, 24 s): ahora los dos pasos se recargan en **15 s**, con su efecto en la misma proporción para que den lo mismo por segundo. Marcar dura 5 s (el talento Rastreador, +2 s por rango) y el Ungüento cura 11 a cada aliado; su remate baja la fiebre 9 (al hacerse más a menudo, por minuto baja lo mismo que antes). Hueco entre combos: mago ~9 s, guerrero 12 s, cazador y médico 15 s; con racha, menos.

| Rol | Combo | Pasos | Remate |
|---|---|---|---|
| Cazador | Presa acorralada | Cepo ⛓️ → Marcar presas (vuelve a sujetar 1,5 s a los atrapados) → Disparo múltiple | Críticos y 2 proyectiles más |
| Cazador | Tiro de gracia | Marcar presas 🎯 → Cepo → Flecha perforante | 3 flechas perforantes en abanico |
| Mago | Fuego y hielo | Nova ❄️ → Parpadeo → Bola de fuego | Rompe el hielo: críticos y explosión un 25 % más grande |
| Mago | Lluvia de estrellas | Bola de fuego 🔥 → Nova → Meteoro | El suelo arde 3 s (6 por segundo) |
| Guerrero | Remolino de acero | Embestida 💫 → Grito (aturde 1 s a los desequilibrados) → Torbellino | Críticos y 1 s más de giro |
| Guerrero | Martillo y yunque | Grito 🔨 → Embestida → Rompehuesos | Golpea a todo lo de alrededor, no solo delante |
| Médico | Cura de urgencia | Dardo 💚 → Escudo (+50 % al revitalizado) → Ungüento | Curaciones críticas seguras, −9 de fiebre y envenena a los monos del radio (6 por segundo durante 5 s) |
| Médico | Nana de la selva | Escudo 🍃 → Dardo (cura crítica) → Polvo somnífero (8 de daño) | Duermen 1 s más, la nube cura 10 a los aliados que estén dentro y los dormidos reciben **+30 % de daño** hasta despertar ("💤 +30 %") |

Con las conexiones las cuatro activas de cada rol entran en el bucle (p. ej. guerrero: Grito → Torbellino → Embestida → Rompehuesos → Grito…), un combo cada dos habilidades.

**Racha:** cada combo completo seguido la sube (x1 … x5; un nivel más si vino de una conexión); desde x2, las recargas son un 4 % más rápidas por nivel. Se pierde tras 8 s sin hacer daño ni curar.

*Cambio de octubre de 2026 (cuarta activa, segundo combo y conexiones):* con las conexiones se cierran 2–3 veces más combos y la racha se quedaba en x5: enlazar valía +50–78 % de daño en grupo (el límite es +35 %). Por eso la racha pasa del 8 % al 4 % por nivel y el daño extra de los golpes enlazados baja (guerrero +25 %, cazador 50 → 10 %, mago 25 → 0 %: casi todos sus golpes de habilidad ya son críticos seguros). Queda en +29 % guerrero, +31 % cazador y +34 % mago; con una habilidad más, los roles hacen ~25 % más de daño con combos que antes y los jefes duran un 10 % menos (101–212 s), dentro de 90–240 s.

*Daño de los jugadores:* todo lo que hacen con armas y habilidades a monos, jefes y muñecos va ×0,7 (`Config.Combat.PlayerDamageMultiplier`); el PvP y las mascotas no cambian. La forja, las armas y los Ajustes enseñan el daño ya reducido.

**Números de combate** (cada cliente los dibuja; `CombatTextController`): columnas de 4 números; el nuevo entra abajo y empuja a los anteriores, que suben y se desvanecen. Duran 2,8 s; lo recogido, 4,5 s.
- **Rojo a la izquierda:** daño que recibes. **Verde a la derecha:** curaciones. **Amarillo sobre el enemigo:** daño que haces.
- Lo de la **mascota** sale al 70 % del tamaño; el daño de los **aliados**, al 70 % y tenue (solo cerca).
- **Lo que recoges** (recolección, botín de monos y jefes, cajas, tu mochila al caer) sale igual, en una columna propia **a la derecha, debajo de las curaciones**: "+2 🌲 Madera" con el color de su rareza. Lo mismo recogido seguido suma en la misma línea. Se puede quitar en Ajustes.
- En **Ajustes** (⚙️ en la Isla, icono del menú en el Lobby) cada jugador elige dónde salen sus números: **junto a la cabeza**, en una **columna del alto del jugador** o **fijos en la pantalla**; y ve su personaje con un ejemplo, el daño y el crítico de su arma, sus habilidades, su combo y su mascota.

### 6.5 Combate v2 (Fase 10, en curso)

*Borrador del 22-10-2026* (entrevista del mismo día; plan por grupos en `docs/PLAN.md`, Fase 10). Lo de esta sección **aún no está en el juego**: cada grupo lo añade y lo pasa a §6.1–§6.4 al cerrarse. Los números están medidos con la calculadora `Equilibrio` (secciones 7 a 10) y están en `Config` (`Chain`, `Guard`, `Net`, `Evasive`, `ComboScaling`, `ControlDR`, `Feint`, `Windup`, `WallBang`). La foto de cómo estaba el combate antes está en `docs/combate-v2/linea-base.md`.

**Principio: equidad.** Mismas ventanas y números en PC, móvil y mando. La compensación del lag favorece al defensor, con un tope de 0,15 s. Toda opción fuerte tiene respuesta. Ningún combo sin escape quita más del 35 % de la vida. Los avisos se ven también sin sonido. Isla y Dunas usan el mismo combate.

| Mecánica | Cómo funciona | Números |
|---|---|---|
| **Estados** ✅ C2 | **Aturdido**: no anda, no pega ni usa habilidades (golpes fuertes, guardia rota, parry recibido, rebote contra un muro). **Inmovilizado**: no anda, pero puede pegar (cepo, agarre, hielo). Todo pasa por una máquina de estados con prioridades. | |
| **Cadena de golpes** ✅ C4 | Las armas cuerpo a cuerpo encadenan **4 golpes**, cada uno con su tajo (vertical, barrido, revés ascendente y remate al suelo con las dos manos). El golpe cae tras una preparación corta. El 4.º remata: empuja, o lanza hacia arriba si saltas; tambalea a los monos de categoría 1–2 (no a los alfas ni a los jefes). Mismo DPS que el golpe suelto. Entre dos golpes siempre queda tiempo para responder. Pulsar un poco antes de tiempo no pierde el golpe (búfer). Si se deja de pegar, se cambia de arma o tras el remate, se vuelve al primero. Hacha, pico y hoz siguen con el golpe suelto. | ×0,9 · ×0,9 · ×1 · ×1,4, cada paso dura 0,9 · 0,9 · 1 · 1,4 golpes del arma y el golpe cae al 35 %; enlace 0,8 s; búfer 0,3 s; remate 35 studs/s (lanza a 45), tambalea 0,6 s; tambaleo en PvP de hasta 0,35 s, dejando siempre 0,25 s de hueco |
| **Guardia** ✅ C5 | **F / L2 / botón "Guardia"** (encima de "Esquivar"; caído, F sigue siendo Rendirse; Beber pasa a **E**). Pulsar = **parry** durante 0,3 s aunque se suelte: anula el golpe, devuelve guardia (destello y aro **dorados**) y, si el atacante pega de cerca, le tambalea (a un mono lo aturde; los jefes se resisten). Mantener = **bloqueo** de frente (cono de 120°): menos daño y sin el control de la habilidad, pero gasta la barra de guardia (a la derecha de la estamina). Vacía, **guardia rota**: aturdido (estallido **naranja con grietas**) y hay que volver a pulsar. En guardia no se pega, no se corre y se anda más despacio; esquivar la suelta. Si se pulsa mientras pegas o estás tambaleado, se pone al acabar. **Imbloqueables**: Rompehuesos, Pisotón y Meteoro rompen la guardia y entran enteros. De los monos y los jefes se defienden sus golpes normales (mordisco, robo del capuchino, piedra, golpe del jefe); sus imbloqueables están en **Preparación**. En PvP, el servidor espera el parry del defensor hasta su ping (máx. 0,12 s) antes de resolver un golpe de arma. | Guardia 100, se recupera 25/s tras 1 s sin recibir golpes. Bloqueo **−50 %** contra jugadores (con −60 % el duelo de guerreros con defensa duraba 12,2 s; ahora 11,8) y −70 % contra monos. Parry: ventana 0,3 s, se rearma a los 0,8 s, +20 de guardia, tambalea 0,6 s (mono 1 s) a menos de 12 studs. Guardia rota: 1,2 s (en PvP ×0,5). Cualquier arma rompe la guardia en ~5,7 s de cadenas seguidas; un golpe suelto necesita ≥ 4. En guardia, ×0,6 de velocidad. |
| **Evasivo** ✅ C7 | La **esquiva pulsada estando atrapado** (aturdido, con la guardia rota, inmovilizado por un agarre, el cepo o el hielo, o lanzado por un remate en el aire): te suelta, te aparta y te deja un momento invulnerable (ráfaga de aire **blanco y azul**). No gasta estamina. Atrapado y con el Evasivo en recarga, **no se puede esquivar** (la esquiva normal ya no saca de un agarre). Icono 💨 a la derecha de la guardia: aparece mientras recarga (una cortina que baja) y, si estás atrapado y lo tienes listo, late con la tecla. En el móvil, el botón "Esquivar" pasa a "¡Evasivo!" (o "Evasivo 12" mientras recarga). | Recarga 25 s, 0,5 s invulnerable, unos 12 studs (60 studs/s, 0,2 s), 2 s de inmunidad al control al salir |
| **Escalado del combo (PvP)** ✅ C7 | Por víctima: desde el **4.º golpe seguido** de otros jugadores, cada uno hace un 8 % menos (hasta la mitad) y su tambaleo dura un 15 % menos (hasta el 40 %). Cada habilidad cuenta como un golpe aunque pegue varias veces; el veneno no cuenta. Se reinicia tras 1 s sin recibir, al bloquear o parar y con el Evasivo. Los **controles de otros jugadores** (aturdir, inmovilizar) duran además 100 → 80 → 60 → 40 % si van seguidos, y luego no entran hasta 6 s sin ninguno (los de los monos no cambian). | 4 rivales controlándote con todo: sujeto el 16 % del tiempo solo con la inmunidad de 2 s → **11 %** (con talentos al máximo, 22 → 14 %) |
| **Control decreciente (monos y jefes)** ✅ C6 | Controles seguidos sobre el mismo enemigo duran 100 → 80 → 60 → 40 %, y luego es inmune hasta 6 s después del último que le entró (sale "INMUNE" sobre él). Cuenta todo: habilidades, el parry y el remate de la cadena. Los jefes, además, se quedan la mitad. | Equipo de 4 sobre un jefe: 25 % → 12 % del tiempo (con talentos al máximo, 35 % → 17 %) |
| **Amagos** ✅ C8 | Pulsar la guardia durante la preparación cancela el golpe de la cadena (gratis, uno por segundo; la cadena vuelve al primero) o la habilidad (15 de estamina y 1,5 s de recarga en vez de la entera). Sale una bocanada corta de **humo gris** delante del pecho, para que el rival aprenda a leerlo, y la guardia se pone en ese momento: amagar y hacer parry en la misma pulsación vale. Es la respuesta al parry: quien para por reflejo gasta su ventana. Si el amago no se puede (antes del segundo, sin estamina: "💨 Sin estamina para amagar"), la guardia espera a que acabe el golpe, como antes. | Golpe: 1 por segundo. Habilidad: 15 de estamina, 1,5 s de recarga. |
| **Preparación** (monos y jefes ✅ C6; habilidades ✅ C8) | Los monos y los jefes se paran, se giran hacia ti y avisan antes de cada ataque: un **"!"** blanco sobre la cabeza que crece hasta el golpe, los ojos encendidos y su chillido. El golpe solo entra si al acabar sigues delante y a su alcance, sin una pared en medio: si te apartas o esquivas, falla; si bloqueas o haces parry, como cualquier golpe. Los **imbloqueables** avisan con **"‼" naranja** (ojos naranjas): el pisotón del gorila, el agarre de los jefes (te agarra aunque estés en guardia), su embestida y todo lo que cae del cielo o sale del suelo (pisotón de jefe, rocas, lava, rayos, con su marca en el suelo); a quien está en guardia se la rompen. La preparación cabe dentro de la recarga de cada ataque: pegan igual de a menudo. **Muñeco de sparring** junto a los de práctica (Basecamp y plaza del Lobby): devuelve los golpes con un palo, sin hacer daño, para practicar el bloqueo y el parry. **Habilidades**: el gesto sale al pulsar y la habilidad al acabar su preparación (entonces cuenta el paso del combo y empieza la recarga); mientras tanto no se pega, ni se usa otra, ni se esquiva. Si te aturden o te tambalean antes, no sale y no gasta la recarga. Las de defensa y huida (Grito de guerra, Parpadeo, Escudo de hojas) salen al momento. Contra un jugador, cada habilidad gasta su guardia **una vez por uso** aunque pegue varias veces (el Torbellino bloqueado entero gasta lo que un golpe). | Aviso: monos 0,4 · 0,5 · 0,6 s por categoría, pisotón del gorila 0,8 s, jefes 0,7 s (golpe, agarre y embestida). Sparring: cada 1,8 s a menos de 6 studs, aviso 0,5 s, 18 de guardia. Habilidades: 0,15 s (Marcar, Cepo, Dardo) · 0,2 s (Torbellino, Embestida, Disparo múltiple, Bola de fuego, Meteoro, Ungüento) · 0,25 s (Nova, Polvo) · 0,3 s (Rompehuesos, Flecha perforante, Lluvia, Rayo, Tótem) · 0,35 s (Pisotón). Guardia por uso: 25 las fuertes, 20 las medias, 15 las de control, 10 el dardo. Duelos espejo de la arena 9,8 · 9,1 · 9,3 → 10,4 · 9,3 · 9,6 s. |
| **Proyectiles** ✅ C9 | Los disparos de las armas a distancia (honda, arco, bastón, cerbatanas) y las habilidades que viajan (Disparo múltiple, Flecha perforante, Bola de fuego, Dardo curativo) vuelan de verdad y dan a quien encuentran por el camino: si te apartas, fallan; una pared los para (el decorado que no choca, no). Se pueden bloquear y parar. Ya no persiguen al objetivo: la ayuda de puntería solo elige hacia dónde salen, y solo si ya apuntas casi encima del blanco (apuntando entre dos monos, el disparo pasa entre ellos). Contra monos apunta adonde estará el mono al llegar; contra jugadores, adonde está y más estrecha, para que se puedan apartar. Atraviesan a los aliados. El veneno y la cura de las cerbatanas entran al impactar. | Ayuda: monos a ≤ 2,5 studs de la línea de tiro (de lejos, 2°), jugadores a ≤ 1,5 studs (1°), igual para todas las armas; adelanto hasta 0,8 s. Para que el daño real no baje: cada arma a distancia +1 de daño, Flecha perforante 17, Bola de fuego 29; en la arena, arco ×0,85, bastón ×1,35, cerbatana ×1,1 y honda ×1,2. Duelos espejo 10,4 · 9,3 · 9,7 s. |
| **Disparo de remate** ✅ C9b | Con un arma a distancia, el **4.º disparo seguido** al mismo ritmo es un remate: un proyectil más grande y de color, que se ve venir y se puede esquivar, con una chispa del mismo color en el arma al dispararlo. Cada arma tiene el suyo: la flecha del **arco** atraviesa al primero y da también al siguiente; la bola del **bastón** estalla donde se para; el dardo de la **cerbatana** cura el doble a un aliado; la piedra de la **honda** tambalea a un mono pequeño (no a los alfas, los jefes ni los jugadores). Si se dispara tarde, se cambia de arma, te tambalean o te pones en guardia, la cuenta vuelve a empezar. | Normales ×0,9 y remate ×1,3: el mismo daño por segundo contra uno (±3 %). A los demás, el 35 % del remate (en un grupo, arco +10–13 % y bastón +11–15 %); la explosión, 6 studs. Tambaleo 0,6 s (17–19 % del tiempo de un mono). Ritmo: hasta 0,8 s después de poder disparar. |
| **Detección** ✅ C3 | Ningún golpe con arma ni ninguna área atraviesa paredes, rocas o árboles: un área solo alcanza lo que su centro "ve" (un mono no esconde a otro), y el golpe con arma, lo que ve quien pega. El golpe con arma cuenta también dónde estaba el objetivo cuando lo vio el atacante, por su ping. Los disparos que perseguían se arreglaron con los proyectiles (C9). | Rebobinado de hasta 0,15 s |
| **Entorno** (rebote y zonas ✅ C10) | **Rebote contra muros**: la Embestida, el Rompehuesos y el remate de la cadena que estampan a un mono o a un rival contra una pared, una roca o el terreno empinado le quitan 5 y le aturden 0,5 s (en PvP, como el control de una habilidad: ×0,5 en la arena, y no alarga un aturdido); grietas en la pared, polvo y un golpe sordo. Después, 1,5 s sin otro rebote. Los jefes no se empujan. **Zonas de peligro** (solo a los monos y a los rivales de quien las pone; todos las ven igual): **suelo ardiendo** del Meteoro que cierra "Lluvia de estrellas", **hielo** de cada Nova (su radio, 3 s: lento y el rival resbala) y **nube** de cada Polvo somnífero (3 s: quien entra va lento, sin dormirse). En Dunas, **coberturas que se rompen** y reaparecen, y un **altar** en la pirámide central que da a su equipo una ventaja pequeña de 30 s (C11). | Rebote: 5 de daño, aturdido 0,5 s, 1,5 s de inmunidad; en la arena aturde 0,25 s y lo peor que entra después es 0–12 de 100. Hielo: ×0,6 de velocidad, renovado cada 0,25 s; resbalar = la velocidad sigue a la que quieres en ~0,3 s. Nube: ×0,5. No cambia ninguna cifra de la calculadora ni sus alertas. |
| **Bloqueo de cámara** ✅ C2 | El shift lock de Roblox, en **Ctrl** (Mayús sigue siendo correr). Lo enciende cada jugador en el menú de Roblox ("Bloqueo de cámara" / Shift Lock Switch). | |

Lo que **no** se añade: fijar objetivo (lock-on). Los **estilos** de cada rol (guerrero de presión, cazador de control de distancia, mago de área y movilidad, médico de apoyo y desgaste) se documentan y se miden, sin contenido nuevo.

---

## 7. La isla

La isla no tiene salida. Su borde exterior es un anillo de **playas**, en el centro está el **Basecamp** y los biomas peligrosos se reparten entre ambos.

```mermaid
flowchart TB
  subgraph Playas["Anillo exterior: PLAYAS (límite, sin salida)"]
    subgraph Selva["SELVA (dificultad baja a media)"]
      BC(["BASECAMP (centro, zona segura)"])
      Rios["Ríos y manglar"]
      Mont["Montañas"]
      Cuev["Cuevas"]
      Volc["Volcán"]
    end
  end
  BC --- Rios
  BC --- Mont
  Rios --- Cuev
  Mont --- Volc
```

| Zona | Dificultad | Recursos destacados | Particularidad |
|---|---|---|---|
| **Basecamp** | Segura | Ninguno | Spawn, construcción y crafteo. |
| **Selva** | Baja a media | Madera, fibra, frutas y plantas medicinales | La zona más grande. Monos de categoría baja. |
| **Playas** | Media | Cocos, conchas, restos de naufragio (metal) | Llegan **cajas de suministro** por el mar, que son zonas de PvP (§12). |
| **Ríos y manglar** | Media a alta | Agua, arcilla, peces | Jefe: Orangután del Manglar. |
| **Montañas** | Alta | Piedra, hierro y cristal | Jefe: Chimpancé Caudillo. |
| **Cuevas** | Alta | Cristales y minerales raros | Oscuridad: se necesitan antorchas. Jefe: Gorila Albino. |
| **Volcán** | Muy alta | Obsidiana, azufre y núcleos de magma | Erupciones periódicas. Jefe: Gorila de Ceniza. |

### 7.1 El archipiélago

El juego es un **archipiélago de seis islas**. Se juega en dos: la del volcán (la de esta sección) y la de las Dunas, que es la arena PvP (§12.2). Las demás **solo se ven desde el Lobby**, alrededor del banco de arena del naufragio y a distancias distintas, como promesa de contenido futuro:

| Isla | Dónde (desde el Lobby) | Cómo se ve | Estado |
|---|---|---|---|
| **Lobby** (banco de arena del naufragio) | Centro | Una plaza ovalada libre con la hoguera, el nido y los muñecos de práctica, rodeada por los carteles (mascotas, bitácora, roles, ranking y arena); el carguero «Esperanza» encallado arriba a la izquierda y el campamento abajo a la izquierda | Lobby |
| **Isla del Volcán** | Noreste, ~870 studs | Selva y volcán humeante con ríos de lava | **Jugable**: place **🍌Isla de monos🐒(survival)** |
| **Isla Calavera** | Suroeste, ~520 studs (la más cercana) | Roca enorme con forma de cráneo de mono, ojos encendidos, colmillos, escalera y antorchas | Cerrada |
| **Ciudad Perdida** | Noroeste, ~600 studs | Rascacielos rotos, inclinados y tumbados, un paso elevado partido, todo comido por la selva | Cerrada |
| **Isla de las Dunas** | Sureste, ~940 studs | Dunas, mesetas de arenisca, arco de roca, obeliscos medio enterrados, cactus y polvo | **Jugable**: place **🎖️Isla de dunas☠️(PvP)**, la arena PvP (§12.2), con su embarcadero y su velero en el Lobby |
| **Picos de la Niebla** | Norte, ~1.300 studs (la más lejana) | Agujas de roca caliza con selva en la cima, cascada y bandas de niebla | Cerrada |

Las islas cerradas son decorado del Lobby (`World/LobbyBuilder`, carpeta `Naufragio/Archipielago`): no se puede llegar a ellas y todavía no tienen place propio. Abrir una isla nueva significa crear su place, añadir su ID a `Config.PlaceIds` y dar en el Lobby la forma de ir. Así se abrió la de las Dunas: un place propio, su ID en `Config.PlaceIds.Dunas` y su embarcadero en el Lobby.

---

## 8. Los monos

### 8.1 Comportamiento (IA)

Todos los monos comparten la misma máquina de estados. Cada especie cambia los parámetros y añade mecánicas propias.

```mermaid
stateDiagram-v2
  state "Inactivo (sin jugadores cerca)" as Inactivo
  state "Patrulla" as Patrulla
  state "Alerta" as Alerta
  state "Persecución" as Persecucion
  state "Ataque" as Ataque
  state "Robo" as Robo
  state "Huida" as Huida
  [*] --> Inactivo
  Inactivo --> Patrulla: un jugador entra en el radio
  Patrulla --> Alerta: ve u oye a un jugador
  Alerta --> Patrulla: pierde el rastro
  Alerta --> Persecucion: el grupo o el alfa decide atacar
  Persecucion --> Ataque: en rango
  Ataque --> Persecucion: fuera de rango
  Ataque --> Robo: especie ladrona con oportunidad
  Robo --> Huida
  Persecucion --> Huida: fuego, vida baja o muere el alfa
  Huida --> Patrulla
  Patrulla --> Inactivo: no hay jugadores cerca
```

- **Tropas:** muchas especies van en grupo con un **alfa**. Si muere el alfa, la tropa se dispersa.
- **Miedo al fuego:** antorchas y hogueras ahuyentan a las especies de categoría baja y media.
- **Repoblación:** cada amanecer se llenan todos los grupos y, durante el día y la noche, un grupo con bajas recupera un mono cada 45 s si no hay jugadores cerca de su zona. La selva nunca se vacía, pero un grupo recién barrido tarda en volver.
- **Rendimiento:** los monos lejos de cualquier jugador "duermen" (no calculan rutas) y hay un límite de monos activos por servidor.
- **Nadie te sujeta siempre:** agarres, pisotones y embestidas (de monos, jefes y en PvP) te dejan quieto un rato, pero mientras estás quieto otro no lo alarga y, al soltarte, durante `Config.Combat.PlayerControlImmunitySeconds` (2 s) no te pueden volver a sujetar. Así un orangután te tiene quieto como mucho la mitad del tiempo y siempre hay un hueco para huir.

### 8.2 Bestiario

El **diario de campo** (J en la Isla, icono "Diario" del menú en el Lobby) recoge las especies y, debajo, los **jefes** (§8.2, categoría 4): cada uno sale con "???" hasta que lo derrotas (o, en un jefe, hasta que le haces daño y cae), y entonces con su descripción, zona o guarida, botín y cuántas veces.

*Ajuste de octubre de 2026 (combos):* las tropas son un **50 % más grandes** (`Config.Monkeys.GroupSizeMultiplier`), los grupos diezmados se recuperan cada **25 s** (antes 45) y caben hasta **220** monos a la vez (antes 160), para que siempre haya con quién enlazar combos. *(18-10-2026: las tropas solo existen cerca de los jugadores y el límite, 200, cuenta solo esas; ver `docs/RENDIMIENTO.md`.)* A cambio, cada mono suelta botín con la **mitad de probabilidad** (`LootChanceMultiplier`).

*Botín compartido (18-10-2026):* el botín de un mono se **reparte al azar, unidad a unidad, entre todos los que pelearon contra él**: quienes le golpearon en los últimos **30 s** (`Config.Monkeys.LootShareSeconds`), los **médicos que curaron a alguno de ellos** en ese tiempo y siempre quien lo derrotó. Para recibir hay que estar vivo (no caído), salvo quien lo derrota. Lo robado por un capuchino y la baja (diario, estadísticas) siguen siendo de quien lo derrota.

#### Categoría 1: dificultad baja

| Especie | Horario | Zona | Mecánica propia | Botín de ejemplo |
|---|---|---|---|---|
| Mono aullador rojo | Día y noche | Selva | Su **grito atrae** a los monos cercanos; si no lo callas rápido llegan refuerzos | Pelaje rojo, colmillo pequeño |
| Marimonda del Chocó | Día | Copas de árboles, ríos | Se mueve por los árboles, **cae desde arriba** y vuelve a subir | Pelaje negro, liana resistente |
| Mono maicero capuchino (grupos) | Día | Selva, cerca del Basecamp | **Ladrón:** roba un ítem y huye. Lanza piedras. | Lo robado, semillas, piedra pulida |
| Tití del Chocó | Día | Selva densa | **Enjambre** de muchos individuos débiles y rápidos | Pelusa, diente diminuto |
| Mono ardilla | Día | Selva, ríos | Grupos grandes y veloces que **rodean** | Pelaje dorado |
| Marteja (mono nocturno) | **Noche** | Selva | Solo de noche, con ojos brillantes. Ataca a quien **no lleva antorcha**. Es una especie colombiana real. | Bigotes de marteja |

#### Categoría 2: dificultad media

| Especie | Horario | Zona | Mecánica propia | Botín de ejemplo |
|---|---|---|---|---|
| Mandril | Día | Selva profunda | Tanque. Su **rugido intimidante** reduce el daño de los jugadores cercanos. | Colmillo de mandril, pelaje colorido |
| Macaco | **Noche** | Alrededores del Basecamp | Inteligente: **abre cofres y desactiva trampas** simples | Pelaje gris, tarjeta de laboratorio (lore) |
| Gibón | Día | Copas de árboles, montañas | **Balanceo** muy rápido entre árboles y ataques en picada | Liana resistente, pelaje |
| Babuino | **Noche** | Montañas bajas | Tropas grandes con **alfa**: matarlo dispersa la tropa | Colmillo grande, cuero |
| Mono de cola larga | Día y noche | Playas y manglar | Nada y **roba comida**. Ronda las cajas de suministro. | Concha, pelaje |

#### Categoría 3: dificultad difícil

| Especie | Horario | Zona | Mecánica propia | Botín de ejemplo |
|---|---|---|---|---|
| Chimpancé | Día | Montañas, selva profunda | **Emboscadas coordinadas**: lanza piedras y usa palos | Hueso grueso, pelaje negro |
| Orangután | Día | Manglar, árboles altos | Lento, pero su **agarre te inmoviliza** 2,5 s (puedes pegar, usar habilidades y esquivar, no andar); al soltarte tienes 2 s para apartarte | Pelaje naranja, fibra resistente |
| Gorila | Día y noche | Montañas, volcán | Tanque: **carga** y golpe de pecho que **aturde en área** | Pelaje plateado, hueso de gorila |

#### Categoría 4: jefes (uno por bioma)

Son versiones **gigantes y con aspecto distinto** de las especies difíciles. Pegan más, tienen fases y sueltan botín especial. **Cada jefe suelta siempre una pieza de la baliza de rescate** (para el servidor) y **2 de su tesoro a cada jugador que le hizo daño** (`Config.Bosses.LootPerPlayer`: uno para el arma y otro para la armadura). Los tesoros no se pierden al caer ni los roban los monos. Desde la Fase 9 (G5) el equipo depende de ellos: la **Corona del caudillo** (día 4) pide el nivel 3 de las armas de rol y la armadura de plata, y el **Cristal de cueva** (día 6) el nivel 4 de la forja volcánica.

| Día de aparición | Jefe | Bioma | Mecánicas | Botín especial |
|---|---|---|---|---|
| 2, 10, 18… | **Orangután del Manglar** | Ríos | Atrapa jugadores en el agua y crece la marea en la arena | Perla del río |
| 4, 12, 20… | **Chimpancé Caudillo** | Montañas | Invoca tropas, lanza troncos y ataca desde posiciones elevadas | Corona del caudillo |
| 6, 14, 22… | **Gorila Albino** | Cuevas | Pelea en la oscuridad: apaga antorchas y su rugido hace eco y aturde | Cristal de cueva |
| 8, 16, 24… | **Gorila de Ceniza** | Volcán | Cargas, lluvia de rocas volcánicas. Se enfurece durante las erupciones. Vida base 7.000 (5.600 antes del nivel 4 de la forja) | Núcleo de magma |

**Reglas de aparición:**

- Aparece **un jefe cada 2 días**, rotando por los biomas de menor a mayor dificultad. El orden y el intervalo son configurables.
- El jefe se queda en su guarida **hasta que lo derrotan o hasta que aparece el siguiente**. Así el equipo tiene unos 2 días para prepararse.
- **Vida según quién pelea** (`Config.Bosses`): cuenta a los jugadores vivos que están en su zona (fuera del Basecamp). Con uno tiene su vida base y cada jugador más le suma un 75 %; al entrar o salir alguien se recalcula sin cambiar el % que le queda. Así dura parecido con 1, 3 o 5 jugadores: con 4, unos **2 minutos** el Orangután y **3 minutos** el Gorila de Ceniza (con las armas de la forja que se suelen tener ese día), tiempo para ver sus tres fases.
- Si un jefe se escapa, su pieza se puede conseguir en la **siguiente rotación** (8 días después).
- Las piezas de baliza van al **núcleo compartido**: pertenecen al servidor, no a un jugador.

#### Tamaño estándar de monos y jefes

El tamaño dice de un vistazo lo peligroso que es un mono: cuanto más alto, más difícil. Un mono o un jefe nuevo debe caer dentro de la franja de su categoría. Se mide el **alto del modelo de pie**, en studs, junto a un personaje de 5 studs (el maniquí de la vista previa). El tamaño se ajusta con `scale` en `Data/Monkeys` o `Data/Bosses`. El modelo de cada especie (`Monkeys/MonkeyModels`) está hecho para medir lo que le toca con `scale = 1`, y `scale` lo multiplica.

| Categoría | Alto | Frente a un jugador | `scale` habitual | Ahora (alto en studs) |
|---|---|---|---|---|
| 1 · baja | 1,3–3 | de la rodilla a la cintura | 0,45–1 | Tití 1,4 · Mono ardilla 1,5 · Marteja 1,5 · Capuchino 1,6 · Cola larga 1,6 · Marimonda 1,65 · Aullador 1,75 (voxel) |
| 2 · media | 2,4–4 | de la cintura al pecho | 0,85–1,25 | Macaco 1,75 · Gibón 2,4 · Mandril 2,9 · Babuino 3,4 (voxel) |
| 3 · difícil | 3,4–5,5 | como un jugador | 1,15–1,6 | Chimpancé 4,2 · Orangután 5 · Gorila 6 (voxel, hombros 4,8) |
| 4 · jefe | 9–11 | unos dos jugadores | 2,6–3,2 (de 1,9 a 2,3 veces el de su especie) | Caudillo 12,3 · Albino 10,8 · Manglar 10,8 · Ceniza 13,4 |

- **Se pasan de alto a propósito:** la **Marimonda** (2,4 con la cola en S levantada; 1,65 de cuerpo), el **Chimpancé Caudillo** (12,3 con el tocado de plumas; 9 de cuerpo) el **Gorila Albino** (12,7 de alto y 13,6 de ancho con los cristales de los hombros y los brazos; 10,8 x 9,8 de cuerpo) y el **Gorila de Ceniza**, que es un 25 % más grande que el Albino para ser el jefe más imponente (13,4 de alto, 12,8 de ancho y 17,5 de fondo; `scale` 3,625, 2,5 veces el de su especie). Su guarida está al aire libre, en el centro del volcán, y tiene más alcance de ataque (14) para llegar a los jugadores que tiene delante del hocico. Para ellos cuenta el alto del cuerpo, no el de la cola, los brazos o el tocado.
- **Ancho y fondo:** los jefes miden hasta unos 10 studs de ancho y 14 de fondo. Las guaridas y la cámara están pensadas para eso, así que un jefe más grande necesita revisar su guarida.
- **Piezas:** unas 15–30 por mono normal (hay muchos a la vez) y hasta 60 por jefe (solo hay uno).

#### Tamaño real con mínimo (modelos voxel, octubre de 2026)

Al pasar cada especie y cada mascota al estilo voxel, su tamaño sale de su **tamaño real frente al
jugador** (decidido el 18-10-2026). Hasta entonces, la tabla de franjas de arriba sigue valiendo para
los modelos de antes.

- **Escala:** 1 m real ≈ 3 studs (el avatar estándar, 5,3–5,5 studs, es una persona de 1,75 m).
- **Qué se mide:** el alto en la postura del juego (a cuatro patas, sentado o posado), no el largo
  del cuerpo de `docs/MONOS.md` y `docs/MASCOTAS.md`.
- **Mínimo, sin perder el orden de tamaños:** si el tamaño real en studs es menor que el umbral, se
  usa `mínimo + real / 2`. Así ningún mono baja de 1,2 studs ni ninguna mascota de 1,5, y el más
  pequeño sigue siendo el más pequeño.
  - Monos: umbral 2,4, mínimo 1,2.
  - Mascotas: umbral 3, mínimo 1,5.
- **Jefes:** siguen siendo versiones gigantes de su especie (9–11 studs, con las excepciones de arriba).

Los altos reales en postura son estimaciones a partir de las medidas de los documentos; se ajustan
al modelar cada animal.

**Simios y monos grandes agrandados (18-10-2026):** a cuatro patas a su tamaño real se quedaban
cortos junto al jugador, así que el Mandril, el Babuino, el Chimpancé, el Orangután y el Gorila son
más grandes que su tamaño real, en este orden de mayor a menor: Gorila 6, Orangután 5, Chimpancé 4,2,
Babuino 3,4 y Mandril 2,9 (con `scale` en `Data/Monkeys`). El Gorila (6) se pasa de la franja de la
categoría 3 a propósito. Sus jefes no cambian (tienen su propio `scale` en `Data/Bosses`).

**Alfas:** estas cinco especies llevan alfa (`alpha` en `Data/Monkeys`): el primero de cada tropa.
Es un 15 % más grande (`Config.Monkeys.AlphaScale`), más vida y más daño, y lleva su corona. Tiene
el aspecto de los machos dominantes de su especie (dimorfismo sexual; `alpha` en el spec voxel de
cada especie), con la cara normal algo más agresiva (ceño en V y ojos entornados) sin llegar a la
de ataque:

- **Mandril:** todos los colores mucho más vivos (nariz roja, crestas azul eléctrico, barba dorada
  más larga, lomo dorado, trasero violeta y rojo).
- **Babuino:** capa plateada como la del babuino sagrado, callosidades rojas y las puntas de los
  colmillos asomando.
- **Chimpancé:** negro intenso con el lomo canoso, barba canosa, cara más oscura y más músculo.
- **Orangután:** pelo castaño granate en vez de naranja, almohadillas más anchas, barba y melenas
  largas colgando de los brazos.
- **Gorila:** cuerpo negro intenso con el lomo plateado más claro, la cresta más alta (por eso el
  alfa mide 7,2 en vez de 6,9) y más músculo.

| Mono | Alto real en postura | Real (studs) | **Alto en juego** | Antes |
|---|---|---|---|---|
| Tití del Chocó | ~0,13 m | 0,4 | **1,4** (hecho) | 1,4 |
| Mono ardilla | ~0,18 m | 0,55 | **1,5** (hecho) | 1,9 |
| Marteja | ~0,2 m | 0,6 | **1,5** (hecho) | 2 |
| Capuchino ladrón | ~0,25 m | 0,75 | **1,6** (hecho) | 1,8 |
| Mono de cola larga | ~0,25 m | 0,75 | **1,6** (hecho) | 2,5 |
| Marimonda del Chocó | ~0,3 m | 0,9 | **1,65** (hecho; 2,4 con la cola en S) | 3,7 |
| Macaco | ~0,35 m | 1,05 | **1,75** (hecho) | 2,7 |
| Mono aullador rojo | ~0,35 m | 1,05 | **1,75** (hecho) | 2,5 |
| Mandril | ~0,55 m | 1,65 | **2,9** (agrandado; alfa 3,3) | 2 |
| Babuino | ~0,65 m | 1,95 | **3,4** (agrandado; alfa 3,9) | 2,2 |
| Gibón | ~0,8 m (erguido) | 2,4 | **2,4** (hecho; brazos colgando) | 4,4 |
| Chimpancé | ~0,9 m | 2,7 | **4,2** (agrandado; alfa 4,8) | 2,7 |
| Orangután | ~1 m | 3 | **5** (agrandado; alfa 5,75) | 3 |
| Gorila | ~1,5 m de hombros | 5,2 con la cresta | **6** (agrandado; alfa 7,2 con su cresta) | 5,2 |

| Mascota | Alto real en postura | Real (studs) | **Alto en juego** |
|---|---|---|---|
| Rana dardo | ~0,04 m | 0,12 | **0,53** (hecho; 1,1 de largo, por debajo del mínimo a propósito) |
| Colibrí | ~0,1 m (con las alas) | 0,3 | **1,4** (hecho; 2,1 de punta a punta de las alas) |
| Tucán | ~0,35 m posado | 1,05 | **2** (hecho) |
| Jaguarundí | ~0,35 m de hombros | 1,05 | **2** (hecho) |
| Tortuga verde | ~1 m de largo (0,25 m de alto) | 3 de largo | **0,9** (hecho; 3,6 de largo y 3,8 con las aletas: el usuario la quiso un 20 % más grande que el real) |
| Ocelote | ~0,45 m de hombros | 1,35 | **2,2** (hecho) |
| Papagayo (Guacamaya) | ~0,45 m posado | 1,35 | **2** (hecho; esbelta, 3,5 de punta a punta de las alas) |
| Beagle | ~0,5 m con la cabeza (0,37 de cruz) | 1,5 | **2,2** con la cola en bandera (hecho; 2,06 sin ella) |
| Perezoso | ~0,5 m a cuatro patas | 1,5 | **2,2** (hecho; 2,9 con la mochila de carga y 2,9 de largo) |
| Jaguar de cristal | ~0,7 m de hombros (jaguar) | 2,1 | **2,6** con los cristales (hecho) |
| Labrador | ~0,75 m con la cabeza (0,58 de cruz) | 2,25 | **2,6** (hecho; 4,6 de largo con la cola, y alforjas) |
| Pointer inglés | ~0,85 m con la cabeza (0,6 de cruz) | 2,55 | **2,7** (hecho; 4,3 de largo) |
| Mono X-7 | ~0,9 m (chimpancé) | 2,7 | **2,6** (hecho; 3,3 con la antena) |

Las mascotas pequeñas se ordenan por su **lado más largo**, no solo por el alto: la rana, plana, salía
la más grande con 1,55 de alto. Orden decidido por el usuario (18-10-2026): rana < colibrí < tucán. La
rana mide un 25 % menos que el mínimo de 1,5 studs, a propósito.

Consecuencias que hay que revisar al pasar cada uno a voxel:
- Casi todos los monos bajan de tamaño. El orden de peligro se mantiene (los pequeños de la
  categoría 1, Mandril y Babuino en medio, los simios arriba), pero las franjas por categoría
  cambian.
- Las mascotas quedan entre 1,5 y 2,25 studs (hoy 2–4,5).
- Los monos más pequeños necesitan un `attackRange` y una caja de golpe a su tamaño.

---

## 9. Botín y crafteo

### 9.1 Rarezas

| Rareza | Probabilidad orientativa | Origen típico |
|---|---|---|
| Común | 60–70 % | Cualquier mono y recurso |
| Poco común | 20–25 % | Categoría 1–2 |
| Raro | 5–10 % | Categoría 2–3 |
| Épico | 1–3 % | Categoría 3 y jefes |
| Legendario | < 1 % | Solo jefes |

Todas las tablas de botín, recetas y estadísticas son **datos en módulos de configuración**. Se pueden balancear sin tocar la lógica.

### 9.2 Progresión de equipo

`Madera y piedra` → `Hueso y colmillo` → `Metal de naufragio` → `Obsidiana y magma` → `Piezas de jefe`

### 9.3 Estaciones de crafteo (Basecamp)

| Estación | Desbloquea |
|---|---|
| Mesa de trabajo | Herramientas y armas básicas, antorchas |
| Hoguera y cocina | Comida cocinada, agua hervida |
| Taller del curandero | Vendas, super vendas, ungüentos y antídotos. Solo el médico: **kit de reanimación** (3 fibra, 1 pelaje dorado, 1 hueso: al reanimar se gasta, basta con pulsar y el aliado vuelve con el 70 % de su vida), **cataplasma de grupo** (4 fibra, 2 plátanos, 1 pelaje rojo: con Curar cura 35 a ti y a los aliados a 20 studs; va primero si alguno ha perdido 10 o más) y **dardos venenosos** ×20 (2 fibra, 1 diente diminuto: munición opcional de la cerbatana; mientras queden, cada disparo gasta uno y el veneno pega ×1,6, con su contador "🐸" encima de la barra) |
| Forja de piedra | Armas y armaduras de hueso y metal. El nivel 3 de las armas de rol (Mazo de hueso grueso, Arco de liana, Bastón de plata, Cerbatana del chamán) y la Armadura de plata piden además la **Corona del caudillo** (jefe del día 4) |
| Forja volcánica | Nivel 4 (Fase 9, G5): se construye con 25 piedra, 8 obsidiana y 2 huesos gruesos. **Mazo volcánico, Arco de brasa, Bastón de lava, Cerbatana de azufre** (~+30 % de DPS sobre el nivel 3) y **Armadura volcánica** (−65 % de daño; Manto de brasa, Túnica de lava y Manto de azufre en los otros roles). Piden obsidiana y el **Cristal de cueva** (jefe del día 6). La **obsidiana** sale de vetas negras con grietas de lava en las laderas del volcán (10) y en la sala de la cueva (5), que se pican (4 golpes con el pico de hueso, 9 por veta) |
| Nido | Incubar huevos |
| Baliza de rescate | Victoria (requiere las 4 piezas de jefe) |

---

## 10. El Basecamp

- **Núcleo compartido:** nido, baliza, defensas perimetrales y estaciones grandes. Cualquiera puede aportar recursos, pero solo se puede **desmontar con votación o por el constructor original** (evita el sabotaje).
- **Parcela personal:** una tienda o espacio pequeño para cofre, cama y estaciones propias. Solo la modifica su dueño.
- **Construcción:** por **cuadrícula** con el **martillo**, cómoda en móvil y en PC. Piezas en `Data/Buildables`: muros de madera y de piedra, antorcha de pie y cama (reapareces en ella si caes y no te reaniman). Cada jugador recibe una de las parcelas al entrar (hay 20: sobran para un grupo de 5); al salir se libera y se derriba lo que tenía en ella.
- **Sin recursos dentro**, como en el diseño original: hay que salir a buscarlos.
- **Asedio nocturno:** de noche, oleadas de monos intentan entrar desde varias direcciones. El interior es seguro **mientras resistan las defensas** (muros, trampas y antorchas). Esto da sentido a construir y une al grupo de amigos en un objetivo común cada noche.
  - Las oleadas crecen con el número de día y con el número de jugadores. *(v1: 3 oleadas por noche, por uno o dos portones al azar; ajustes en `Config.Siege`.)*
  - Las defensas se construyen en el **perímetro** (entre las parcelas y la empalizada, incluidos los portones): muros, **estacas** (hieren a los monos que las cruzan) y antorchas.
  - Las defensas dañadas se reparan de día con recursos.
  - Si los monos rompen el perímetro, atacan estructuras y jugadores dentro, pero **el nido y la baliza tienen su propia defensa**: es lo último que cae.
  - La noche del encendido de la baliza es la **noche final** ("La Gran Tropa"), el asedio más fuerte de la partida, en el que una parte de los monos va a por la baliza (§5.4).
  - La noche 5 llegan los **macacos saboteadores**, que van a por las defensas y las estaciones (§5.4).

---

## 11. El huevo y las mascotas

- **Aparición:** probabilidad baja cada cierto tiempo en un punto aleatorio de la isla. Hay un **aviso global** con ubicación aproximada y **su rareza**: se sortea al aparecer (común 55 · poco común 25 · raro 13 · épico 6 · legendario 1) y se ve en el color del huevo, cada rareza muy distinta (crema, verde, azul, lila y dorado).
- **Transporte:** el portador va **más lento**, atrae monos y queda **marcado para PvP**. Los jugadores con PvP activo pueden robarle el huevo; el guerrero lo carga mejor.
- **Nido del Basecamp:** hay que tenerlo construido en el núcleo. La defensa dura unos minutos (150 s, 2 oleadas).
- **Al terminar la defensa** no nace la mascota: cada jugador que **participó** se lleva **un huevo persistente de esa rareza**. Va directo a su nido del lobby si está vacío; si no, a su **mochila de huevos** (3 casillas); si está llena, queda **pendiente** y en el lobby elige cuál descartar (el descartado da Ámbar según su rareza).

### El nido del lobby

- En la plaza del Lobby, delante del cartel **🐾 Mascotas** (a la izquierda de la bitácora). **Cada jugador ve en el nido su propio huevo**, y en el cartel lo que le falta, qué puede salir, su mochila y la mascota que le acompaña; al tocar el nido se abre su ventana con el nido, la mochila, los pendientes y **las mascotas que pueden salir** de esa rareza, y al lado la colección.
- **Solo avanza el huevo del nido**, con las horas reales, también sin jugar. Los de la mochila esperan.
- **Tiempo de eclosión:** común 8 h · poco común 11 h · raro 14 h · épico 18 h · legendario 24 h.
- **Se abre solo en el nido del lobby**, con una pequeña ceremonia (tiembla, estalla y sale la mascota). La mascota es una de esa rareza al azar y, si es más rara que la que llevas, te acompaña.
- **Jugar lo acelera:** cada noche superada en la isla le quita **1 h**; las misiones diarias, 15–40 min, y las 5 semanales, 1 h; la pista gratis del pase, de 30 min a 1 h 30 min en algunos niveles; y al **ganar una partida** hay una tirada con ruleta en los resultados (40 % −2 h · 30 % −4 h · 20 % −6 h · 8 % −10 h · **2 % eclosión inmediata**). Lo ganado jugando tiene un **tope del 50 %** del tiempo total del huevo, para que siempre quede algo que esperar al día siguiente; el tiempo del calendario y la eclosión inmediata no cuentan para el tope.
- Si el huevo termina mientras juegas en la isla, se avisa: "¡Tu huevo está listo! Ábrelo en el nido del Lobby".

```mermaid
sequenceDiagram
  participant S as Servidor
  participant J as Jugadores
  participant P as Portador
  participant M as Monos
  S->>J: Aviso global con ubicación aproximada del huevo
  J->>S: Llegan al huevo
  P->>S: Recoge el huevo (va más lento y queda marcado PvP)
  S->>M: Los monos cercanos persiguen al portador
  Note over P,J: Jugadores con PvP activo pueden robar el huevo
  P->>S: Lo entrega en el Nido del Basecamp
  S->>S: Defensa de unos minutos
  S->>J: Un huevo de esa rareza para cada participante (al nido del lobby, la mochila o pendiente)
  Note over J: En el lobby: horas reales en el nido, acelerado jugando, y se abre con la ceremonia
```

### Mascotas

- **Colección persistente.** Se equipa **1 mascota activa** desde el lobby.
- **Tipos de ayuda:** combate, carga (más material o más botín), rastreo (detecta monos; el beagle también huele el huevo), marca (señala al mono más cercano: todos le hacen más daño), curación y apoyo.
- **Rarezas:** de común a legendaria. Fauna tropical (tucán, guacamaya, tortuga, jaguarundí…), tres sabuesos (beagle, labrador y pointer inglés) y criaturas "experimentales" legendarias del laboratorio (ver Lore).
- **Skins de mascota** (Fase 9, solo cosméticas): cambian los colores, los materiales y algunas piezas sin tocar la ayuda. Las mascotas que comparten modelo llevan **skins de familia** (los tres felinos, los tres perros). Ejemplos: Tortuga de Lava y Jaguar de Magma (pase), Perro pirata (tienda en Ámbar). Se eligen en el Armario.
- **Importante:** los huevos **solo se consiguen jugando**, nunca con Robux. Así se evitan las normas de Roblox sobre objetos aleatorios de pago. El huevo Raro del nivel 20 del pase está en la pista gratis y solo sale con nivel ganado jugando.

---

## 12. PvP

Hay dos formas de pelear contra otros jugadores: en la Isla, solo si los dos lo activan (§12.1), y en la arena de la Isla de Dunas, un modo aparte por equipos (§12.2).

### 12.1 En la Isla: PvP opt-in

- **Basecamp:** PvP desactivado siempre.
- **Activar PvP:** en un tótem del Basecamp. Los jugadores con PvP activo llevan un **indicador visible** y solo pueden atacar a otros jugadores con PvP activo.
- **Desactivar PvP:** hay una espera (por ejemplo 3 minutos) para evitar abusos.
- **Activación automática:** al **cargar el huevo** o al abrir una **caja de suministro** disputada.
- **Recompensa PvP:** quien acumula derribos PvP tiene una recompensa visible para los demás jugadores con PvP activo.

### 12.2 La arena (Isla de Dunas)

La Isla de las Dunas (§7.1) es el **tercer place** (ID 122593636654552): una arena de **captura la bandera** entre dos equipos, **Jaguar 🐆** y **Quetzal 🦜**, de **1v1 a 5v5**, en unas ruinas mayas dentro de un cañón del desierto. Es el sitio donde se gasta Ámbar en equipamiento que solo cuenta en la arena, y abre la primera isla del archipiélago que se veía desde el Lobby. Decidido en la entrevista del 20-10-2026.

**Cómo se entra.** Desde el Lobby, en el embarcadero propio con el velero **"Zarpar a la Isla de dunas"** (al pie del cartel de la arena) o en el propio cartel **🎖️Isla de dunas☠️(PvP)** de la plaza. Se elige formato y se entra en una **cola entre servidores** (MemoryStore), solo o en grupo: el grupo llega al mismo equipo y nunca se separa. Al juntarse las plazas de una partida se reserva un servidor de Dunas y viajan todos. No hay reemplazo de los que se van.

**Antes de la partida.** Cada jugador elige al llegar su **base** (con un tope de N por equipo), su **rol** y su equipamiento, y pulsa **Listo**. Si están todos listos, 10 s de cuenta atrás; si no, la partida arranca igual a los **60 s** de llegar el primero. Si un equipo sigue vacío, se cancela y vuelven todos al Lobby. Hasta que empieza, las puertas de las bases están cerradas.

| Regla | Cómo funciona |
|---|---|
| **Victoria** | **3 capturas** o, a los **8 min**, el que tenga más. Con empate, **muerte súbita**: la siguiente captura gana. |
| **Bandera** | Clásica: para puntuar con la rival, **tu bandera tiene que estar en casa**. Se lleva a la espalda. El portador va un **15 % más lento** y no puede usar **Parpadeo** ni **Embestida**. Si cae, la bandera se queda en el suelo: un aliado la devuelve al tocarla y, si nadie la toca, vuelve sola a los **15 s**. |
| **Muerte** | Sin estado de caído: reaparece en su base a los **5 s** (**8 s** si llevaba la bandera), con 2 s de protección. La vida se recupera sola tras 6 s sin recibir daño. |
| **Roles** | Libres de 1v1 a 3v3. En 4v4 y 5v5, **como mucho 2 iguales** por equipo. |
| **Abandono** | Si un equipo se queda vacío, gana el otro. Quien se va antes de acabar no cobra. |
| **Al terminar** | Resultados de 20 s con votación: **revancha** en el mismo servidor con quienes se queden o **volver al Lobby**. |

**Combate.** Es el mismo de la Isla (armas, habilidades, combos y estados, código compartido en `src/combat`) con reglas por equipos y números propios, para que **un duelo entre dos roles iguales dure 8–10 s**:

- Daño de las armas ×0,55 (el arco ×0,7), de las habilidades ×0,45 (las definitivas, ×0,45 más: el Pisotón quitaba 84 de 100 de un golpe y el Rayo encadenado 68; ahora 38 y 30), control ×0,5 y curación ×0,6. Duelos espejo medidos con la calculadora `Equilibrio`: Guerrero 9,8 s, Cazador 9,1 s, Mago 9,3 s y Médico 30 s (se deja así por ahora: el médico apoya más que pelea; se revisará con datos de partidas reales cuando haya más jugadores).
- Las curaciones y los escudos solo llegan a los aliados. El veneno, la ralentización, el sueño, las marcas y los combos funcionan contra los rivales.
- De la Isla solo llegan los **cosméticos** y la **mascota de adorno** (sin ayuda). Los talentos, las mejoras y la forja no cuentan: todos empiezan igual.

**Equipamiento.** Cada rol tiene tres ranuras, **arma, armadura y amuleto**. En cada una se lleva lo básico (gratis) o una de **dos variantes** que se compran con Ámbar (24 en total, `Data/ArenaGear`). Son **horizontales**: cambian cómo juegas el rol a cambio de algo, nunca son mejores sin más. Por ejemplo, la *Maza de hueso grueso* hace que Rompehuesos pegue un 40 % más y tarde un 40 % más en recargarse, y el *Peto de escamas de ámbar* hace que el Grito proteja también a los aliados. Precios: arma 200, armadura 150 y amuleto 100 de Ámbar. La tienda está en la base y en la ventana de la arena del Lobby, con el mismo inventario.

**Ámbar y ranking.** Al terminar: victoria 60, empate 30 y derrota 20, más 15 por captura y 2 por baja (como mucho 20 por bajas). Hay un **tope diario de 400** para que la arena no sea la forma más rápida de ganar Ámbar. Se guardan victorias, derrotas, capturas y bajas, y en el Lobby el cartel del **Ranking** tiene un bloque de la arena (**victorias y banderas capturadas**); el cartel de la Isla de dunas enseña tus números y la cola.

**El mapa** (`src/dunas/server/World/ArenaBuilder`). Mide 400 × 200 studs:

- **Bases**: cada una es el patio de un templo. Tiene la fachada con un arco maya, la máscara del equipo sobre la puerta y estandartes y fuego de su color. Al fondo, una pirámide con su santuario, que es decorado.
- **Centro**: un carril central con una pirámide escalonada que se sube por cuatro escalinatas. Junto a ella está el juego de pelota, con sus taludes y aros.
- **Pasillos laterales**: dos, entre muros en ruinas, que se **cierran con muros en 1v1 y 2v2**.
- **Coberturas y entorno**: estelas, altares y columnas rotas y caídas. Todo dentro de un cañón de arenisca a franjas, con luz de tarde.
- **Sin peligros del mapa** en esta versión.

**Para más adelante.** Más modos (combate abierto por equipos, todos contra todos, Dominio con 3 altares, Caza de Ámbar), runas pasivas (2–3 equipables de 10), trampas del templo (dardos y pinchos), tormenta de arena y arenas movedizas, ligas con emparejamiento por nivel (MMR), reemplazo desde la cola, penalización por abandono y salas privadas con código.

---

## 13. Lore

Hace décadas, un millonario excéntrico construyó en la isla un **santuario-laboratorio privado** con primates de todo el mundo. Eso explica que convivan especies de América, África y Asia. Para alimentarlos plantó enormes cultivos de banano, y la isla acabó conocida como **Banana Island**.

En secreto, el laboratorio desarrolló el **Proyecto PRIMAL**: un suero mezclado en bananas modificadas para hacer a los primates más fuertes e inteligentes. Salió mal. Los primates se volvieron agresivos y carnívoros, y los que comieron más **bananas primales** crecieron hasta tamaños imposibles (los jefes). El laboratorio quedó abandonado tras una erupción del volcán.

La isla es solo una de las **Banana Islands**, un archipiélago que el Proyecto PRIMAL usó entero: desde el naufragio se ven una ciudad tragada por la selva, un desierto de dunas, una roca con forma de calavera y unos picos entre la niebla (§7.1). Cada isla abierta en el futuro trae su bioma, sus monos y su parte de la historia.

Los jugadores son **náufragos**. La **baliza de rescate** es la antigua radio del laboratorio. Hay **notas, ruinas y tarjetas de acceso** repartidas por la isla, lo que da pie a **actualizaciones narrativas por temporadas**.

**Ganchos de lore para el juego:**
- Las **bananas primales** (brillantes) pueden ser un objeto raro: consumible con mejora temporal, ingrediente de crafteo o lo que "despierta" a los jefes.
- Los **macacos** sueltan tarjetas de laboratorio que abren puertas de ruinas con botín y notas.
- Las criaturas **experimentales** del laboratorio son las mascotas legendarias de los huevos.

---

## 14. Economía y monetización

- **Moneda del juego: Ámbar** (nombre provisional). Se gana por días sobrevividos, contribución (recolectar, reanimar, defender), jefes, rescates, contratos de expedición (§5.4), Dunas, el calendario, las misiones (§4) y la pista gratis del pase.
- **Se gasta en:** mejoras permanentes **moderadas** (19 rangos, 1.930 en total: vida, estómago, kit de náufrago, estamina…), el equipo de Dunas y la **tienda de cosméticos en Ámbar** (§14.2), que es el sumidero de quien ya tiene las mejoras.
- **Talentos:** se desbloquean con la **XP del rol**, no con dinero.
- **Robux (solo cosmético y comodidad):** la premium del pase y sus niveles (§14.1), cosméticos sueltos en la tienda de Robux, los Game Passes cosméticos (estelas, título, aura) y servidores privados.
- **Nunca con Robux:** poder, **Ámbar** (compra mejoras con ventaja), huevos, tiempo de incubación, provisiones y objetos aleatorios. Lo comprueba la sección "Reglas de pago" de la calculadora `Economia`.
- **Se gana jugando:** el título "Superviviente de la Isla" (solo al ganar una partida), los trajes míticos (§14.3), los premios del calendario, de las misiones y de la pista gratis del pase.

### 14.1 Pase de temporada (Fase 9)

- **Temporada de 30 días** con **30 niveles de 1.000 XP**; después, 7 días de descanso (sin XP; lo no reclamado se entrega solo) y empieza la siguiente. Los **últimos 7 días dan ×2 de XP**. Pasado el nivel 30, cada 1.500 XP da un nivel "en bucle" (50 de Ámbar o −15 min de huevo, por turnos).
- **XP:** Isla 60 por día sobrevivido, 150 por jefe, 50 por huevo salvado y 300 por rescate; Dunas 80/40/30 (gana/empata/pierde) y 15 por captura; contratos 50–125 por paso. Las partidas tienen un **tope de 1.200 XP al día**; las misiones no cuentan en él. **+10 %** si hay un amigo de Roblox en el servidor.
- **Dos pistas** con un premio en **cada nivel**:
  - **Gratis:** Ámbar (1.625 en total), tiempo de huevo (7 h), provisiones, un **huevo Raro** (N20) y 8 cosméticos (títulos Náufrago del Volcán en N1 y **Señor del Volcán** en N30, marcos de bronce y plata, el emote Saludo simio, el Machete de Azufre, la Tortuga de Lava y la Estela de ceniza). Lo que no es cosmético solo se desbloquea con nivel **ganado jugando**.
  - **Premium:** **solo cosméticos**, uno en cada uno de los 30 niveles: los 4 trajes del fuego azul por rol (N5, N10, N20, N25), las 4 armas de azufre (N3, N7, N13, N18), el aura **Llama primal** que evoluciona (I, II y III en N1, N15 y N30), el Jaguar de Magma (skin de los tres felinos, N23), 3 emotes con efectos, estelas, marcos, títulos, estilos de números y estallidos y dos nidos.
- **Compras** (Developer Products, `Config.Shop`): **premium 399 R$** (vale para la temporada en curso; si se compra a mitad, entrega lo ya alcanzado), **pack premium + 10 niveles 799 R$** (solo si aún no es premium) y **1 nivel 79 R$** (no en el nivel 30 ni en el descanso). Los niveles comprados nunca desbloquean el Ámbar, el huevo ni las provisiones de la pista gratis.
- **Ritmo medido** (calculadora, 30 días): el jugador habitual (5 días a la semana, 1 h) lo termina el **día 23**; el casual (3 días, 40 min) llega al nivel 13; el intenso, el día 13 (no antes, por el tope); un grupo de amigos, el día 20. Las misiones son el 50–62 % de la XP.
- **Temporada 1: "El Despertar del Volcán"** (🌋, fuego azul y azufre sobre piedra pómez; los premios naranjas son los de magma). Se abre en el cartel volcánico de la plaza o con 🌋 en la barra; la ventana tiene dos pistas sincronizadas que se desplazan (excepción a las ventanas sin desplazamiento) con la imagen voxel de cada premio y el sello premium. En la Isla, aviso "+XP de pase" y barra en los resultados.
- Preparar la siguiente: `.claude/skills/economia-retencion/references/nueva-temporada.md`.

### 14.2 Tiendas de cosméticos (Fase 9)

Pestaña **🎨 Cosméticos** de la Tienda del Lobby. Tema "selva y mar", para no competir con el volcán del pase. Nunca entran los premios de la temporada en curso.

- **En Ámbar:** 4 al día de un catálogo de 22 (19.000 de Ámbar en total), rotación común con la semilla del día de la que cada jugador ve primero lo que aún no tiene. Precio por rareza: común 400 · poco común 600 · raro 900 · épico 1.200 · legendario 1.500. El habitual gasta el 97 % de su Ámbar en 30 días y tiene la tienda entera el día 30.
- **En Robux:** 3 sueltos que rotan cada lunes de 11 (99–249 R$, y las 4 armas míticas a 449 R$), un Developer Product cada uno; debajo, los Game Passes, siempre a la venta.
- El Armario dice si algo está hoy en la tienda.

### 14.3 Cosméticos

- **Tipos:** trajes por rol, aspectos de arma por rol (y del machete), skins de mascota, estelas, auras, títulos, marcos (ranking, Grupo y resultados), emotes (rueda con la tecla "." o 😀), estilo de los números de daño, estilo de los estallidos de cómic y decoración del nido (solo la ve quien la lleva). Algunos tienen **grados I, II y III** que comparten línea: se ve el más alto que tienes.
- **Rarezas:** común, poco común, raro, épico, legendario y **mítico**. Cuanto más raro, más detalle; las variantes se distinguen de un vistazo, también de espaldas.
- **Míticos** (dioses de la selva): un traje por rol que **se gana** venciendo con el equipo de nivel 4 del rol (Rey Gorila Titán, Jaguar Espectral, Serpiente Emplumada, Ceiba de la Vida) y su arma, en la tienda de Robux. Crecen con el nivel de la armadura y del arma en la Isla y se ven enteros en el Lobby y en Dunas. Los trajes del pase también ganan piezas con el grado de la armadura.
- Todo se elige en el **Armario** del Lobby (avatar 3D que gira, pestañas Trajes, Armas, Efectos, Títulos, Mascotas, Marcos, Emotes y Estilos). En Dunas solo llegan los cosméticos (§12.2).

### 14.4 Correcciones a la investigación

`docs/Sistema de recompensas y retencion.txt` y `docs/battle_pass_30_days.xlsx`/`.pdf` (investigación previa) sirvieron de base, con estas correcciones (están también en la hoja "Correcciones" del Excel; el PDF es una exportación y no se toca):

| # | El Excel decía | En el juego |
|---|---|---|
| 7 | La premium vende aceleradores del nido y Ámbar | Premium 100 % cosmética: el Ámbar compra vida y daño, venderlo sería pagar para ganar |
| 8 | "Superviviente de la Isla" en el nivel 30 gratis | Ese título es solo para quien gana; el N30 gratis da "Señor del Volcán" |
| 9 | Skins de mascotas que no existen (Tití, Mandril, Gorila Albino); total premium 90 cuando suma 75; 1.000 XP al día justos | Skins solo de las 13 mascotas reales (y de familia); el pase se termina con ~20–24 días activos |
| 10 | Niveles comprados con los premios gratis incluidos | Los premios no cosméticos solo se desbloquean con nivel ganado jugando |

---

## 15. Nombre

**Primal Banana Islands: Monkey Survival**

- **Primal Banana Islands** es el título y conecta con el lore (Proyecto PRIMAL y las bananas primales). Va en plural porque el juego es un archipiélago (§7.1): se empieza con una isla y se abren más con las actualizaciones. Antes se llamaba *Primal Banana Island*.
- **Monkey Survival** es el subtítulo con palabras clave, para que el juego aparezca en las búsquedas de Roblox.
- Evita el riesgo de propiedad intelectual de "Monkey Island" (LucasArts/Disney).
- **Pendiente antes de publicar:** buscar el nombre en Roblox (que no haya otro juego igual) y en registros de marcas.

---

## 16. Riesgos y políticas de Roblox

| Riesgo | Mitigación |
|---|---|
| **Alcance enorme** para una sola persona | Construir por fases, con un *vertical slice* jugable antes de producir contenido. Datos de configuración en lugar de código duplicado. |
| **Rendimiento** (hasta 5 jugadores y muchos NPC, en móvil) | IA en servidor con "sueño" lejos de jugadores, límite de monos activos, StreamingEnabled y pruebas en móviles de gama baja. |
| **Moderación y edades** (llegar a menores de 16: Roblox Kids y Select) | Sin sangre ni gore. Los monos derrotados desaparecen con un "¡puf!" de humo y estrellas, sin animación ni grito de muerte (violencia leve, de caricatura). Cuestionario de madurez completo y requisitos de [LANZAMIENTO.md §9](LANZAMIENTO.md#9-menores-de-16-roblox-kids-y-select). |
| **Propiedad intelectual** del nombre | Nombre propio: *Primal Banana Islands* (§15). |
| **Objetos aleatorios de pago** | Huevos solo por juego. Si algún día se venden, mostrar probabilidades según las normas de Roblox. |
| **Exploits y trampas** | Servidor autoritativo: todo daño, botín y crafteo se valida en el servidor. |
| **Griefing** | PvP opt-in, Basecamp seguro, permisos de construcción y núcleo protegido. |

---

## 17. Preguntas abiertas

Las preguntas de la v0.1 están resueltas (ver §2). Quedan detalles para decidir con los playtests:

1. ¿El orden de los jefes es **fijo** (de menor a mayor dificultad, propuesta actual) o **aleatorio** en cada partida?
2. ¿Nombre final de la moneda? ("Ámbar" es provisional; ¿quizá **Bananas doradas**, por el nombre del juego?)
3. ¿Qué hacen exactamente las **bananas primales**: mejora temporal, ingrediente o las dos cosas?
4. Duraciones finales del día y de la noche (se empieza con 10+7 y se ajusta en la Fase 1).
