# Equilibrio de habilidades

Qué buscamos cuando creamos o retocamos una habilidad, cómo lo medimos y los límites que vigila la
calculadora (`src/island/tools/Equilibrio.luau`, en Studio `ServerStorage.Tools.Equilibrio`). Los límites son **puntos de partida razonados**, no leyes:
si una habilidad tiene buenas razones para salirse, se dice en la propuesta y se deja anotado aquí.

## 1. Principios (de la investigación, aplicados a este juego)

**Por qué la gente sigue jugando.** La teoría de la autodeterminación aplicada a los videojuegos
(Ryan, Rigby y Przybylski, 2006) encontró que sentirse **competente**, **autónomo** y **conectado con
otros** predice la diversión y las ganas de volver a jugar, y que unos controles intuitivos refuerzan
la competencia. En este juego eso se traduce en:
- *Competencia*: cada habilidad tiene que **leerse** (efecto, sonido, número, cómic) y el jugador
  tiene que notar que la ha usado bien. Los combos son la forma de demostrar que dominas tu rol.
- *Autonomía*: varias formas viables de jugar cada rol (con y sin combos, talentos distintos). Una
  habilidad que todo el mundo ignora o que es obligatoria es un fallo de diseño. El usuario prefiere
  ofrecer alternativas como **opciones del jugador** antes que imponer una.
- *Relación*: los roles se necesitan (el guerrero agrupa, cazador y mago castigan en área, el médico
  sostiene). Una habilidad nueva debería reforzar esa dependencia, no borrarla.

**Retención en Roblox.** Roblox no publica una cifra objetivo: pide comparar la retención del día 1,
del día 7 y la duración de sesión con experiencias parecidas en el panel de analítica (los
indicadores de referencia se desbloquean con 100+ usuarios diarios). Lo que más pesa al principio es
el día 1, así que las primeras partidas tienen que dar momentos de poder pronto (definitiva lista al
empezar, combos que se entienden en la primera noche) y el dominio tiene que seguir creciendo después
(talentos, racha, mejores armas). Ojo con el móvil: 4 botones junto al salto, puntería hacia donde
mira la cámara.

**Daño en el tiempo: pico frente a sostenido.** El DPS de una habilidad con recarga es su daño por uso
entre su ciclo (recarga + tiempo de lanzamiento). Pero el jugador no lo vive como una media: vive el
**pico de apertura** (todo listo al empezar la pelea) y el **ritmo sostenido** (entre recargas). La
calculadora enseña las dos cosas con la curva de daño acumulado a 2, 5, 10, 30 y 60 s. Un modelo de
equilibrio de ARPG (Beyerl) pondera el DPS de cada habilidad por su **tiempo de uso** (la fracción
del tiempo en que se puede usar) y exige que el total alcance la vida del enemigo en el tiempo
deseado: es lo que hace la sección 3.

**Tiempo para matar y golpes para matar.** El daño solo tiene sentido frente a la vida (Champions
Online fijaba primero cuánto debía aguantar un jugador). Y bajo presión nadie distingue 100 de 101
de vida, pero sí "lo mato de un golpe o de dos" (Obsidian, *The Outer Worlds 2*): diseña en **golpes
para matar** y en segundos, no en puntos sueltos.

**Control de masas.** Los juegos grandes limitan el control encadenado: rendimientos decrecientes que
acaban en inmunidad (WoW, contados **por criatura**, compartidos por todo el grupo), o resistencia que
sube con cada segundo de control y baja sola (Diablo III 1.0.5), y jefes inmunes o con "armadura de
control". Aquí los jefes solo se quedan la mitad y **no hay rendimientos decrecientes** sobre los
enemigos, así que el límite se pone en el tiempo de uso del control. Sobre los **jugadores** sí hay
una regla (`Status.holdPlayer`): un control no se alarga mientras dura y al acabar hay 2 s de
inmunidad (`Config.Combat.PlayerControlImmunitySeconds`).

**Daño explosivo frente a aguante.** Riot rebajó el daño de *League of Legends* porque los combates
eran tan rápidos que se perdía claridad y margen de reacción, y bajó a la vez la curación porque
aguantar demasiado también impide reaccionar. Para nosotros: los jefes no deberían caer antes de
enseñar sus fases, y el médico no debería poder anular el daño de un grupo de monos (si no, no hay
tensión).

**Enemigos justos.** Todo ataque fuerte de un mono o un jefe se avisa antes (marca en el suelo,
burbuja, animación de carga) y tiene respuesta (esquivar, apartarse, interrumpir aturdiendo). Ningún
enemigo solo debería dejarte sin control de tu personaje la mayor parte del tiempo.

**Recompensas.** Las recompensas variables (críticos, botín) enganchan, pero abusar de ellas genera
compulsión y críticas éticas, sobre todo con público joven. Aquí la aleatoriedad está en el
crítico (+35 %) y el botín; las recompensas de habilidad (combo, racha) son **deterministas**: si lo
haces bien, funciona. Mantenlo así.

## 2. Qué mide la calculadora

Todo contra monos y en daño **real** (× `PlayerDamageMultiplier` y × el crítico esperado del arma),
salvo "segundos de arma", que compara dos números base y no depende de esos multiplicadores.

| Medida | Qué es | Para qué |
|---|---|---|
| Daño 1 obj / grupo | daño de un uso a un mono / a un grupo de `grupo` monos (el área alcanza a los típicos de su radio) | tamaño del golpe |
| DPS grupo | daño de un uso al grupo ÷ recarga efectiva | cuánto aporta sostenida |
| **Segundos de arma** | daño de un uso al grupo ÷ DPS del arma del rol | "esta habilidad vale X segundos pegando con tu arma": compara roles con armas muy distintas |
| Pico 2 s | daño que entrega en sus 2 primeros segundos | explosivo frente a continuo |
| Control | segundos de aturdir/congelar/inmovilizar ÷ recarga | fracción del tiempo que tiene quieto a un mono |
| Curva 2…60 s | daño acumulado de un jugador que pega con su arma y lanza habilidades | daño en el tiempo; apertura frente a ritmo |
| Sin combos / combos | un jugador que pulsa lo que está listo frente a otro que enlaza | cuánto premia el combo; el límite se mide en `segundosCombo` (180 s), más que una recarga de la V, porque parte del premio es acercarla |
| Tiempo para matar | vida del mono (con la dificultad del día) ÷ DPS de 1 objetivo × actividad | golpes/segundos para matar |
| Duración de un jefe | vida × `Config.Bosses` ÷ (jugadores × DPS medio de los 4 roles × actividad), con las mejoras de la forja que se suelen tener el día en que aparece (`armasPorDia`) | que dé tiempo a ver sus fases |
| Golpe máx. enemigo | el golpe más fuerte posible de un mono o jefe (salto, alfa, crítico) | que nada te tumbe de un golpe |
| Te deja quieto | fracción del tiempo que un mono solo te inmoviliza si todos sus golpes entran, con la inmunidad tras soltarte | bloqueo |
| % del arma (mascotas) | DPS de la mascota ÷ DPS medio de las armas de rol | que la mascota ayude sin jugar por ti |

Supuestos (los que más cambian el resultado): monos repartidos (un radio 10 alcanza 2,5 de media,
un radio 14 3,5, más de 14, 4,5); del abanico de flechas entran 2 en un solo mono y el 70 % en un
grupo; el cepo salta a los 2 s; los monos no salen de la lluvia; 0,3 s sin pegar al lanzar; la
simulación pega el 100 % del tiempo y la sección 3 el 60 % (`actividad`). Cámbialos en `OPCIONES`
si una pregunta concreta lo necesita.

## 3. Límites

Los mismos que la tabla `LIMITES` de la calculadora. Si cambias uno, cambia los dos.

| Límite | Valor | Por qué |
|---|---|---|
| Recarga de una activa (Z, X, C, R) | 4–25 s | por debajo es otro ataque básico; por encima se olvida y no entra en combos (ventana de 6 s) |
| Recarga de una definitiva (V) | 60–120 s | una o dos por pelea larga; la definitiva es un momento |
| Activa: segundos de arma por uso | 0,5–4 | por debajo no se nota; por encima el arma deja de importar |
| Definitiva: segundos de arma | 12–30 | las tres actuales están en 18–24 |
| DPS de una activa en grupo | ≤ 80 % del DPS del arma | el arma (y la forja) siguen siendo la base del daño |
| Control por habilidad | ≤ 35 % del tiempo | sin rendimientos decrecientes, más es tener monos congelados siempre |
| Control de todo un rol | ≤ 45 % | con los remates del combo |
| Control de un equipo de 4 roles sobre un jefe | ≤ 30 % | ya contando que el jefe se queda la mitad; el jefe tiene que poder enseñar sus fases |
| Daño extra por enlazar el combo (grupo, 180 s) | +5 % a +35 % | menos: no compensa aprenderlo; más: quien no hace combos (móvil, principiantes) se queda atrás |
| Reparto entre Guerrero, Cazador y Mago | ±20 % en grupo, ±30 % a 1 objetivo | cada rol puede ser mejor en un escenario, ninguno en todos |
| Golpe más fuerte de un mono (sin armadura) | ≤ 40 el día 1, ≤ 60 con la dificultad al máximo | la vida base es 100: nada te tumba de uno o dos golpes sin aviso |
| Golpe más fuerte de un jefe en furia | ≤ 65 | dos golpes seguidos deben poder esquivarse o curarse |
| Un mono te deja quieto | < 60 % del tiempo | si no, es un bloqueo sin salida |
| Mascota de combate | ≤ 40 % del DPS de un arma de rol | ayuda, no juega por ti (y salen de huevos aleatorios) |
| Duración de un jefe (4 jugadores, 60 % de actividad) | 90–240 s | que dé tiempo a ver sus 3 fases; objetivo 2 min el primero y 3 min el último |
| Un jefe con un jugador solo | ≤ 360 s | solo es más difícil, pero no eterno |
| Curación sostenida del médico | ≤ 8 por segundo por aliado | un grupo de monos tiene que seguir siendo peligroso |

## 4. Línea base (octubre de 2026, sin talentos, grupo de 4)

Para comparar las propuestas. Vuelve a sacarla con la calculadora si cambian los números del juego.

**16 de octubre de 2026, cuarta activa (R), segundo combo y conexiones** (la tabla de abajo es la de
antes, para ver de dónde venimos):

| Rol | Nueva activa (seg. de arma) | DPS 60 s, 1 obj (combos) | DPS 60 s, grupo (sin → con combos) | Combos en 60 s (🔗 conectados) | Combo en 180 s (grupo / 1 obj) | Control del rol |
|---|---|---|---|---|---|---|
| Guerrero | Rompehuesos 1,42 | 33,9 | 47,8 → 58,6 | 12 (11) | +29 % / +12 % | 17 % |
| Cazador | Flecha perforante 1,39 | 33,0 | 41,5 → 51,3 | 10 (9) | +31 % / +17 % | 30 % |
| Mago | Meteoro 3,75 | 27,3 | 36,3 → 50,2 | 15 (14) | +34 % / +15 % | 13 % |
| Médico | Polvo somnífero 0,73 (duerme 21 % con remate; no a jefes) | 11,2 | cura 14,6 → 20,7/s al equipo | 10 (9) | | 21 % |

Equipo de 4 roles sobre un jefe: 30 % (justo en el límite; el sueño no cuenta). Jefes con 4 jugadores:
108 / 124 / 146 / 172 s (Orangután, Chimpancé, Gorila Albino, Gorila de Ceniza).
Incluye el retoque de combos y jefes del 16 de octubre de 2026 y el Grito de guerra (12 s / 4 s), Marcar presas (15 s / 5 s) y el Ungüento (15 s / 11) con la ventana del combo que espera al paso siguiente (la
simulación de combos ya no deja de usar sueltas las habilidades del combo mientras espera un paso).

| Rol | Arma (DPS real) | Activas: segundos de arma por uso | Definitiva | DPS 60 s, 1 obj (combos) | DPS 60 s, grupo (sin → con combos) | Combo en 180 s (grupo / 1 obj) | Control del rol |
|---|---|---|---|---|---|---|---|
| Guerrero | Garrote 30,1 | Torbellino 2,07 · Embestida 1,24 · Grito 0 | Pisotón 17,8 | 29,6 | 43,7 → 47,7 | +30 % / +10 % | 11 % |
| Cazador | Arco 20,5 | Múltiple 1,07 · Marcar 0 · Cepo 1,04 | Lluvia 24,4 | 27,6 | 37,3 → 40,1 | +28 % / +11 % | 30 % |
| Mago | Bastón 14,2 | Fuego 2,81 · Nova 2,62 · Parpadeo 0 | Rayo 20,5 | 22,9 | 30,3 → 38,0 | +29 % / +13 % | 13 % |
| Médico | Cerbatana 12,2 | curación: Ungüento 44 (2,9/s), Dardo 21 (3,5/s), Escudo 24 (2/s) | Tótem 240 | 11,3 | cura 14,6 → 18,0/s al equipo | | 0 % |

Jefes (60 % de actividad; DPS por jugador 13,9 con las armas básicas, 18,9 con la 1.ª mejora de la
forja desde el día 3 y 25,3 con la 2.ª desde el día 6):

| Jefe | Día | Vida base | 1 jugador | 4 jugadores | 20 jugadores |
|---|---|---|---|---|---|
| Orangután del Manglar | 2 | 2100 | 152 s | 123 s | 116 s |
| Chimpancé Caudillo | 4 | 3100 | 164 s | 133 s | 125 s |
| Gorila Albino | 6 | 4700 | 186 s | 151 s | 142 s |
| Gorila de Ceniza | 8 | 5600 | 222 s | 180 s | 169 s |

Monos: el día 1 nadie pega más de 28 de una vez (chimpancé alfa con crítico); el día 20 la
categoría 2–3 llega a 61–71. Te dejan quieto: orangután 46 % (agarre 2,5 s; antes de la inmunidad,
100 %), gorila 19 %. Tiempo para matar con combos (100 % de actividad): mono ardilla ~1 s,
mandril 4–6 s, gorila 10–13 s el día 1; casi el doble el día 8. Mascotas: Jaguarundí 22 %, Ocelote
38 %, Mono X-7 48 % del DPS medio de un arma de rol.

## 5. Hallazgos pendientes (para decidir, no aplicados)

1. **Sin rendimientos decrecientes de control sobre los enemigos.** Hoy está en límites (equipo de 4 sobre un jefe:
   25 %), pero con talentos al máximo sube al 39 % y el Cazador llega al 43 % por mono.
2. **El Mono X-7 (legendario)** hace el 48 % del DPS medio de un arma de rol, y como las mascotas no
   pasan por el ×0,7, es casi lo mismo que la cerbatana del médico.
3. **Con talentos al máximo** la Lluvia de proyectiles vale 39 s de arma y la Bola de fuego supera el
   80 % del DPS del bastón; el médico cura 36/s al equipo.
4. **El cazador hace poco daño propio** con sus activas (Múltiple y Cepo ~1 s de arma); su aporte es
   Marcar (+20 % al daño de **todo el equipo** el 33 % del tiempo), que la calculadora no suma al
   daño del cazador. Por lo mismo, su combo apenas suma daño en peleas cortas (+3 % en 60 s): vale
   por volver a sujetar a los atrapados. Tenlo en cuenta antes de "arreglarlo".
5. **El daño de los jefes no sube con los días** (sí su vida, con los jugadores que pelean).
6. **Sin probar en Play**: el recálculo de la vida del jefe cuando entra o sale un segundo jugador
   (por MCP solo hay uno; hace falta Test → Clientes y servidores con 2).
7. **Golpes máximos el día 20**: gibón, mandril, chimpancé y gorila pasan de 60 de 100 sin armadura.

8. **Con talentos al máximo y la cuarta activa**: el control del equipo sobre un jefe llega al 42 % y
   enlazar combos da +36–39 % (límite 35 %); el resto de alertas con talentos ya estaban (punto 3).
9. **La racha con conexiones**: en la simulación se queda en x5; un jugador real que espera a que se
   recargue el paso 2 (Marcar 15 s, Nova 9 s) sin pegar con el arma la pierde a los 8 s. Mirar en la
   telemetría `ComboBestStreak` antes de tocarla.

Resueltos el 16 de octubre de 2026: el orangután te dejaba quieto el 100 % del tiempo (su agarre de
2,5 s duraba más que su ataque de 1,8 s y cada golpe lo renovaba); ahora todo control sobre un
jugador pasa por `Status.holdPlayer` (no se alarga mientras dura y deja 2 s de inmunidad) y se queda
en el 46 %, ~50 % medido en Play. Ya hay telemetría de habilidades (§7). También ese día: el combo valía casi solo por acercar la definitiva sin tope (el
mago la lanzaba casi el triple, +60 %; ahora tope de 20 s por recarga y daño extra por rol en
`Data/Combos`) y los jefes caían en 39–57 s con 4 jugadores y contaban a todo el servidor (ahora
cuentan a los que pelean, `Config.Bosses`, y duran 2–3 min).

## 6. Recetas: qué palanca mover según el síntoma

Cambia **una cosa cada vez**, en pasos del 10–20 %, y mira el informe antes y después.

| Síntoma | Palanca | Evita |
|---|---|---|
| "Es demasiado fuerte" pero se siente bien | baja el daño por uso un 10–15 % y deja la recarga | quitarle su momento (más recarga) |
| "No se siente nada" | más claridad: efecto, sonido, cómic, número; luego daño por uso | subir números de algo que no se entiende |
| Se usa siempre sin pensar | sube la recarga y el daño por uso en la misma proporción (mismo DPS) | |
| Nunca se usa | baja la recarga, añade un uso táctico (control, movilidad) o dale papel en el combo | |
| Explosivo de más (todo en la apertura) | reparte el daño en el tiempo (ticks) o retrasa parte | bajar el DPS sostenido |
| Control excesivo | acorta la duración o añade rendimientos decrecientes por objetivo | quitarlo del todo |
| El combo no compensa | sube el efecto propio del remate | subir todo el daño del rol |
| El combo es obligatorio | baja la devolución a la V o la racha | castigar a quien no los hace |
| Un mono es injusto | aviso más largo, menos daño por golpe, más tiempo entre especiales | más vida sin más avisos |
| Jefe demasiado corto | más vida o más fases con inmunidad breve al cambiar de fase | más daño del jefe |

## 7. Telemetría

La calculadora es teoría; los jugadores dicen la verdad. `Services/TelemetryService` cuenta durante
la partida y lo manda junto al terminarla (o al salir el jugador) con `Analytics.event(player,
nombre, valor, campos)`, en el Creator Hub → Analítica → Eventos propios. La lista de eventos y sus
campos está en la cabecera del servicio. Cómo leerlo frente a la calculadora:

| Pregunta | Eventos | Compara con |
|---|---|---|
| ¿Qué habilidad se ignora? | `AbilityUses` ÷ `MinutesPlayed`, por rol | usos posibles por minuto (60 ÷ recarga) |
| ¿Se hacen combos? | `AbilityLinked` ÷ `AbilityUses`, `ComboCompleted`, `ComboBestStreak` | sección 2 (combo en 180 s) |
| ¿Cuánto aporta cada cosa? | `DamageBySource` y `HealingBySource` por rol y fuente | "segundos de arma" y la curva de la sección 2 |
| ¿Qué tumba a la gente? | `PlayerDowned` por causa y día | golpe máximo y "caído en" de la sección 4 |
| ¿Te tienen quieto? | `TimeHeld` por causa ÷ `MinutesPlayed` | "te deja quieto" de la sección 4 |
| ¿Cuánto dura un jefe? | `BossDefeated` (segundos, por jefe y jugadores) | duración de la sección 3 (90–240 s) |

Para una habilidad nueva no hay que tocar nada: sus usos y su daño salen solos por su id (si hace
daño con `hurt` y cura con `heal`). Un mono o jefe nuevo sale por su especie o `Jefe <id>`; un
peligro nuevo, con su último argumento `cause`.

## Fuentes

- Ryan, Rigby y Przybylski (2006), *The Motivational Pull of Video Games: A Self-Determination Theory
  Approach*: https://www.doi.org/10.1007/S11031-006-9051-8 ·
  https://selfdeterminationtheory.org/player-experience-of-needs-satisfaction-pens/
- Roblox, analítica y referencias de retención: https://create.roblox.com/docs/production/analytics
- GameAnalytics, informe de Roblox 2025: https://www.gameanalytics.com/cn/reports/2025-roblox-report
- Beyerl, *ARPG Balance* (uso y DPS frente a vida): https://faculty.uca.edu/jbeyerl/Papers/ARPG_Balance.pdf
- Champions Online, diario de equilibrio (daño frente a aguante):
  https://www.tentonhammer.com/articles/champions-online-developer-diary-systems-balancing-pt-2.amp
- Obsidian, combate de *The Outer Worlds 2* (golpes para matar):
  https://www.thumbsticks.com/how-obsidian-fixed-combat-in-the-outer-worlds-2/
- Respawn, *Titanfall 2* (tiempo para matar como ritmo):
  https://www.invenglobal.com/articles/1230/redesigning-titan-combat-strategical-decisions-that-made-titanfall-great-again
- Rendimientos decrecientes de control: https://warcraft.wiki.gg/wiki/Diminishing_returns ·
  Diablo III 1.0.5: https://www.gamebanshee.com/news/109393-diablo-iii-v105-patch-crowd-control-changes.html
- Riot, daño explosivo y aguante: https://www.leagueoflegends.com/en-us/news/dev/quick-gameplay-thoughts-5-6/ ·
  https://www.nme.com/news/league-of-legends-12-10-will-reduce-overall-damage-and-increase-champion-durability-3220009
