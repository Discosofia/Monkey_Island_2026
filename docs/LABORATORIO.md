# Laboratorio en ruinas: diseño (cuarto place)

Diseño de la tanda T9 de los pedidos del 26-10-2026 (punto 13), decidido en la entrevista del 27-10-2026. Todavía no hay código: se construirá en su propia fase (`docs/PLAN.md`, "Fase 13"). Resumen en el GDD §12.3.

## 1. Qué es

Un **shooter por equipos** en el laboratorio del Proyecto PRIMAL, en ruinas entre los rascacielos comidos por la selva de la **Ciudad Perdida** (la isla del noroeste que se ve desde el Lobby, GDD §7.1). Se enfrentan dos bandos:

- **Piratas invasores** 🏴‍☠️: vienen a saquear el suero. Pañuelo, parche y armas con latón y madera. Color del bando: **dorado y negro**.
- **Guardianes del laboratorio** 🥼: el personal de seguridad que se quedó. Bata, casco y armas blancas con franja **azul**.

Los colores de los bandos no usan el verde (curación), el morado (veneno) ni el rojo (daño recibido). El icono de los Guardianes es 🥼 y no 🧪, que ya es de una mascota (un icono, una sola cosa); 🧪 se queda en el nombre del place.

Es el contrapunto de Dunas: allí pesan el rol, las habilidades y los combos, y una pelea dura 8–10 s; aquí **todos empiezan igual**, solo cuenta el arma y la puntería, y una pelea dura 1,5–2,5 s.

## 2. Cómo se pelea

- **Primera persona.** La cámara del Laboratorio va en primera persona (añadido el 27-10-2026): se apunta con el centro de la pantalla en todos los dispositivos (PC, móvil y mando), con una mira fija en el centro, y el arma se ve en la mano delante de la cámara. Es otra diferencia con Dunas y la Isla, que van en tercera persona.
- **Sin roles, habilidades ni talentos.** Tampoco cuentan las mejoras de la tienda, la forja ni las mascotas (la mascota de adorno sí se ve, sin ayudar). De fuera solo llegan los cosméticos.
- Al empezar (y en cada reaparición, entre partidas y entre rondas) se elige **1 de las 4 armas** del laboratorio. Las dos facciones tienen las mismas cuatro armas con los mismos números y cambia solo el aspecto (latón pirata o blanco y azul del laboratorio).
- **Vida 100**, que vuelve sola tras 4 s sin recibir daño. Sin estado de caído.
- Esquiva y salto como en el resto del juego, con una diferencia: la esquiva es un empujón **sin rodada** (estilo `Dash`), y la cámara se inclina un poco hacia el lado de la esquiva mientras el arma de la vista se aparta (V3). No hay guardia ni parry: en un shooter el bloqueo no tiene sentido.
- Los disparos son **proyectiles** (`Combat/Projectiles`, el mismo sistema de la Isla y de Dunas, con su compensación de lag y su tope). Nada de rayos instantáneos: así se ve el disparo y se puede esquivar a distancia.
- **Ayuda de puntería estrecha**, la misma de la Isla: solo corrige si la línea ya casi toca al blanco. El botón de disparo del móvil es grande y no dispara solo. Ningún dispositivo tiene ventaja.
- Sin disparos a la cabeza: un crítico por zona castigaría al jugador de móvil.

### 2.1 Las 4 armas

| Arma | Papel | Daño | Cadencia | Alcance | Proyectil | Efecto |
|---|---|---|---|---|---|---|
| **Lanzadardos tranquilizante** | Automática de media distancia | 10 | 0,15 s | 80 studs | Rápido (260 studs/s) | Cada dardo ralentiza un 4 % (hasta un 20 %) durante 1,5 s. Dardos y estela **azul claro** |
| **Rifle de bananas primales** | Precisión a larga distancia | 45 | 0,95 s | 200 studs | Muy rápido (450 studs/s) | Mira con zoom al mantener apuntado. Disparo **amarillo** brillante con estela |
| **Lanzarredes de arpón** | Corta distancia, castiga al que se acerca | 35 | 0,65 s | 35 studs | Lento (180 studs/s) | El impacto **enreda**: −35 % de velocidad durante 1 s, que no se renueva antes de 3 s (`Status`, con inmunidad al soltarse) |
| **Cañón de suero ácido** | Área y fuera de la línea de visión | 30 | 0,8 s | 70 studs | En arco (110 studs/s) | Estalla en un área de 6 studs y **envenena**: 6 de daño por segundo durante 3 s. Charco y números **morados** |

Ningún efecto deja quieto a nadie: el control más fuerte es el del arpón, corto y con inmunidad.

### 2.2 Tiempo para matar (medido)

Calculado el 27-10-2026 con un modelo propio (en la tanda de código pasará a `Equilibrio` como sección del Laboratorio, porque la sección 6 de la calculadora mide duelos entre roles con habilidades y aquí no hay roles). El modelo cuenta los disparos que hacen falta para quitar 100 de vida, el acierto esperado a cada distancia, la cadencia, el viaje del proyectil y el veneno que entra entre disparos. Acierto supuesto: lanzadardos 85 % / 60 % (corta / media), rifle 60 % / 85 % / 80 % (corta / media / larga), arpón 90 % en corta, suero 85 % / 80 % (corta / media).

| Arma | Corta (15 studs) | Media (50 studs) | Larga (120 studs) |
|---|---|---|---|
| Lanzadardos | 1,65 s | 2,44 s | fuera de alcance |
| Rifle primal | 3,20 s | **2,35 s** | **2,64 s** |
| Arpón de red | **1,53 s** | fuera de alcance | fuera de alcance |
| Suero ácido | 2,02 s | 2,45 s | fuera de alcance |

**Quién gana cada cruce** (el de menos tiempo para matar a esa distancia):

| Cruce | Corta | Media | Larga |
|---|---|---|---|
| Lanzadardos – Rifle | Lanzadardos | Rifle | Rifle |
| Lanzadardos – Arpón | Arpón | Lanzadardos | — |
| Lanzadardos – Suero | Lanzadardos | Lanzadardos | — |
| Rifle – Arpón | Arpón | Rifle | Rifle |
| Rifle – Suero | Suero | Rifle | Rifle |
| Arpón – Suero | Arpón | Suero | — |

- Cada arma tiene su distancia y nadie gana en todas. El suero pierde los duelos sueltos contra el lanzadardos, pero contra **dos rivales juntos** los mata a los dos en 2,45 s (las otras necesitan 4,7–4,9 s) y pasa por encima de las coberturas con su arco.
- Dentro de su alcance, todas quedan en **1,5–2,6 s**, el objetivo de la entrevista. El rifle a 120 studs se pasa por 0,14 s: se acepta, porque a esa distancia nadie más llega.
- La primera versión (lanzadardos de 12 de daño y 70 % de acierto en media, arpón de 34 cada 0,7 s, suero de 24 + 5/s) dejaba al lanzadardos ganando en corta y en media y al suero sin ningún cruce. Por eso los números de arriba.

## 3. Modos

Se eligen **en la cola**, junto con el formato. Todos duran como mucho **6 minutos** de juego.

| Modo | Jugadores | Cómo se gana | Reaparición |
|---|---|---|---|
| **Duelo por equipos** | 1v1 a 5v5 | El primer equipo en llegar a las bajas del formato (1v1: 10 · 2v2: 15 · 3v3: 20 · 4v4: 25 · 5v5: 30), o el que más tenga a los 6 min. Empate: la siguiente baja gana | A los 3 s en la zona de salida del bando, con 1,5 s de protección (se pierde al disparar) |
| **Todos contra todos** | 10, sin equipos | El primero en llegar a 15 bajas, o el que más tenga a los 6 min. Empate: la siguiente baja gana | A los 3 s en la zona de salida más alejada de los rivales |
| **Rondas** | 1v1 a 5v5 | Al mejor de 7 (gana el primero que llega a 4 rondas). Una ronda la gana el equipo que deja sin nadie en pie al otro | Sin reaparición dentro de la ronda. Entre rondas, 8 s para cambiar de arma y se cambia de lado a la mitad |

- **Rondas:** cada ronda dura como mucho 45 s. A los 30 s suena la **alarma del laboratorio** y todos se ven a través de las paredes; si se acaba el tiempo, la gana el equipo con más vida sumada. Así la partida entera dura 4–7 min.
- **Antes de la partida:** como en Dunas, cada jugador elige arma y pulsa **Listo** (cuenta atrás de 10 s; si no, arranca a los 60 s de llegar el primero). Mientras tanto se vota el mapa (§4).
- **Al terminar:** 20 s de resultados con votación de **revancha** o **volver al Lobby**, como en Dunas.
- **Abandono:** si un equipo se queda vacío, gana el otro. Quien se va antes de acabar no cobra.

## 4. Mapas

**Tres mapas pequeños.** Al llegar y en cada revancha se vota uno de los tres, antes de elegir arma. La votación dura 10 s o hasta que han votado todos; con empate sale al azar entre los más votados, y sin votos, al azar entre los tres. Cada uno favorece una distancia, para que todas las armas tengan su sitio:

| Mapa | Tamaño | Cómo es | Favorece |
|---|---|---|---|
| **Laboratorio central** | 160 × 120 studs | Tres carriles entre las dos zonas de salida (el muelle pirata al oeste y la puerta de seguridad de los guardianes al este): al norte, el **pasillo de las jaulas** (corto, con esquinas); en el centro, la **sala del reactor** (abierta, con tanques de suero rotos como cobertura y una pasarela alta); al sur, el **invernadero de bananas primales** (plantas que tapan la vista pero no paran disparos). | Media distancia: el mapa de todas las armas |
| **Azotea de la torre** | 120 × 120 studs, en dos alturas | La azotea de un rascacielos inclinado, con el helipuerto, antenas caídas, una grúa que une los dos niveles y la selva que asoma por los bordes. Tiene cuatro huecos al vacío (dos al norte y dos al sur) y cuatro tramos laterales de 20 studs detrás de las zonas de salida, por los que se cae (ver Caídas más abajo). | Larga distancia: el rifle |
| **Alcantarillas** | 140 × 100 studs | Túneles estrechos bajo el laboratorio, con agua hasta los tobillos (no ralentiza), compuertas oxidadas, tuberías que gotean suero y una sala de bombas en el centro. | Corta distancia: el arpón y el suero |

- Los tres están construidos a la vez en el mismo place, cada uno en su sitio: el Central en (0, 0, 0), la Azotea en (2000, 160, 0), con su propia selva abajo (≈ y 0 del mundo), y las Alcantarillas en (−2000, 0, 0). El mapa que se juega es el del atributo `Map` de `LabMap`.
- En **1v1 y 2v2** se cierra una parte de cada mapa con un derrumbe, como los pasillos de Dunas: el invernadero del central, las escaleras y la rampa que bajan de la azotea, y el túnel sur de las Alcantarillas. En los formatos mayores quedan abiertos.
- **Caídas.** Donde hay huecos o tramos de caída, bajar por debajo del mapa (`Config.Lab.FallDepth`) mata. Si el último que hirió a quien cae lo hizo en los 10 s anteriores (`Config.Lab.FallCreditSeconds`), esa es su baja y sale el aviso «🪂 … tira a … al vacío». Si nadie le hirió en ese tiempo, es una muerte sin baja.
- Cada bando tiene una **zona de salida** cerrada por una barrera que solo deja salir: nadie puede entrar en la del rival. Dentro de una zona nadie hace ni recibe daño: ni se dispara a quien está dentro ni desde dentro (así no se puede disparar a cubierto desde la propia zona). Antes de la partida, una compuerta la cierra para todos.
- Coberturas que **no se rompen** (en un shooter rápido, una cobertura que desaparece deja a todos al descubierto). Barreras invisibles en los bordes y en los techos. Los muros invisibles van en el grupo de colisión `LabMuro`: chocan con los personajes, pero los disparos los cruzan. Las barreras de las zonas de salida sí frenan los disparos.
- Los tres son **voxel** y comparten paleta: hormigón gris, metal oxidado, cristal azulado roto (nunca verde brillante, que es el color de la curación), cables y la selva entrando por las grietas. Se generan con `World/LabBuilder` (versión 3, con un Model por mapa en `World/Maps`) y cada uno tiene su maqueta voxel para la ventana de votación (`src/shared/LabMapModels`).

## 5. Recompensas

Nada que dé poder fuera del Laboratorio, y nada de pago que dé poder dentro.

**Reparto en dos grupos** (plan del 28-10-2026). La L5a (`3364413`) da el Ámbar, la XP del pase, el ranking, la misión semanal y los títulos, y empieza ya a contar las bajas por arma en el perfil (`lab.weaponKills`). La L5b (hecha, a la espera de aprobado; VERIFICACION §30) trae los 12 modelos de las skins, su dibujo combinado con el bando y la entrega de los grados ganados.

**Alerta aceptada de `Economia` (28-10-2026).** Con el Laboratorio, el habitual completa la tienda de Ámbar el día 28 (el mínimo es 30). Sin el Laboratorio ya la completaba justo el día 30, en el límite, así que cualquier fuente nueva de Ámbar la dispara. Decisión del usuario: se acepta y no se tocan los números del Laboratorio; la razón es que a la tienda de Ámbar le faltan cosméticos (otra tarea).

**Ámbar.** Medido contra la línea base de `Economia` (27-10-2026): la Isla da unos 6,4 de Ámbar por minuto (perfil intenso) y Dunas unos 7,2 (con su tope de 400 al día). El Laboratorio da algo menos por minuto, para que la Isla siga siendo el sitio principal:

| Concepto | Ámbar |
|---|---|
| Victoria · empate · derrota (por equipos y rondas) | 45 · 25 · 15 |
| Todos contra todos: 1.º · 2.º–3.º · resto | 45 · 30 · 15 |
| Por baja | 1 (como mucho 15 por partida) |
| **Tope diario propio** | **300** |

Con las suposiciones de Dunas (45 % de victorias, 10 % de empates) y unas 8 bajas por partida, salen unos **37 por partida**; con 6 min de juego y ~1,5 min de cola y resultados, unos **5 por minuto**. El tope se alcanza con unas 8 partidas (~1 h). Con Dunas y el Laboratorio juntos, el máximo de los dos modos PvP es 700 al día.

**XP del pase.** 60 · 30 · 20 (gana · empata · pierde), dentro del tope de 1.200 XP de partidas al día.

**Cosméticos por hitos** (solo se ganan jugando):

- **Skins de las 4 armas del Lab** en grados I (Raro), II (Épico) y III (Legendario), por bajas con esa arma: 50, 250 y 1.000 (`Config.Lab.SkinKills`; las bajas se cuentan desde la L5a). Cada arma tiene su bestia: el lanzadardos, la Avispa 🐝; el rifle, el Escorpión 🦂; el lanzarredes, el Kraken 🐙; el cañón, el Dragón 🐉. Cada grado se distingue a primera vista: el III añade piezas nuevas que se ven también por detrás, no solo otro color.
  - **Bando:** el cuerpo y el acento son del bando (luz azul en los Guardianes, remache de oro en los Piratas). Las piezas de la skin son iguales en los dos.
  - **Solo se gana jugando:** no da Ámbar ni XP y no se vende.
  - **Entrega:** al cerrar la partida, y de forma retroactiva (`checkEarned`) para quien ya tenga bajas. Si el hueco de la línea está vacío, la skin se pone sola. El Armario tiene el chip «🧪 Laboratorio» en la pestaña de armas, con el progreso, para ponerla o quitarla.
  - **Umbrales:** bajaron el 28-10-2026 de 100/500/2.000 a 50/250/1.000 por decisión del usuario. Con una sola arma, el III tarda unos 42 días de calendario en el perfil intenso y unos 175 en el habitual (`Economia`).
- **Títulos:** "Saqueador del PRIMAL" (50 victorias con los piratas) y "Guardián del Suero" (50 con los guardianes).
- **Ranking:** un bloque del Laboratorio en el cartel del Ranking del Lobby (victorias y bajas), como el de la arena.
- **Misiones:** una semanal nueva, "Gana 3 partidas en el Laboratorio", que entra en la rotación de las semanales.

## 6. Emparejamiento y entrada

- Desde el Lobby, con un **embarcadero y un velero nuevos** hacia la Ciudad Perdida y un cartel **🧪Laboratorio en ruinas🏴‍☠️(PvP)** en la plaza.
- **Cola entre servidores** reutilizando lo de Dunas: `ArenaQueueService` (MemoryStore), `Arena` y `TeamService`, con dos claves más (modo y formato). El grupo llega junto y al mismo bando; en todos contra todos, el grupo entra en el mismo servidor, cada uno por su cuenta.
- El bando se reparte al azar en cada partida (y se cambia en las rondas a la mitad).
- Un place nuevo con su ID en `Config.PlaceIds.Laboratorio` y su proyecto de Rojo (`laboratorio.project.json`, puerto 34875).

## 7. Qué se reutiliza y qué es nuevo

| Se reutiliza | Es nuevo |
|---|---|
| Cola, equipos y resultados de Dunas (`ArenaQueueService`, `Arena`, `TeamService`, la ventana de resultados con votación) | Las 4 armas (`Data/LabWeapons`) con sus modelos voxel por bando y sus efectos |
| Proyectiles, `Hitbox` con compensación de lag, `Status` (ralentización y enredo con inmunidad), veneno y su color | Reglas del place (`LabCombatRules`: sin roles, vida 100, reaparición, protección, caídas al vacío con el último atacante) |
| Ayuda de puntería estrecha y el botón de disparo del móvil | Los 3 modos, la votación de mapa y la alarma de las rondas |
| `CosmeticsServer` (los cosméticos llegan como en Dunas) | `World/LabBuilder`, `World/LabParts` y `World/Maps/*` con los 3 mapas |
| `Leaderboards`, `Retention` (misión semanal), `SeasonPass` (XP) | Skins de las armas del Lab por hitos y los títulos |

## 8. Para más adelante y riesgos

- **Más adelante:** granadas o un objeto de apoyo por jugador, un cuarto mapa, rondas competitivas con emparejamiento por nivel (MMR), salas privadas con código.
- **Lag:** en un shooter rápido se nota más que en Dunas. La compensación favorece al que recibe el disparo y tiene tope (`Config.Net`); los proyectiles visibles ayudan a que los fallos se entiendan.
- **PC frente a móvil:** se prueba con el emulador de teléfono antes de cerrar la fase. Si el móvil pierde claramente, se ensanchan las cosas para todos (tamaño de los proyectiles, ayuda de puntería), nunca solo para un dispositivo.
- **Pocos jugadores:** tres modos y cinco formatos parten la cola. Si las colas tardan, se juntan formatos (3v3–5v5 en una sola cola) antes que quitar modos.
