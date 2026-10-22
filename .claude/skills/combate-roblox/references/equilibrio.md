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
| Marca (mascotas) | `MarkBonus` × el DPS del arma del dueño solo y del equipo (`aliados` × `focoMarca`, la parte de su daño que va al marcado); a un jefe, lo que le deja a "Marcar presas" | que el pointer ayude al grupo sin quitarle su papel al cazador |
| Cadena de golpes (sección 7) | DPS de la cadena ÷ el del golpe suelto; tambaleo y hueco entre golpes frente a `Config.Reaction`; daño de una cadena en la arena (con el escalado del combo); guardia que gasta. Disparo de remate (C9b): por arma a distancia, DPS del ciclo ÷ el disparo suelto contra uno, contra el grupo y en la arena, el control del tambaleo y la cura | que la cadena no cambie el DPS, que siempre deje responder y que todas las armas rompan la guardia en el mismo tiempo; que el remate a distancia no cambie el DPS contra uno ni dispare el de grupo |
| Defensa (sección 8) | golpes y segundos para romper la guardia por arma (con su recuperación); duelo espejo de la arena con `defensa` (bloqueo y parry) | que quedarse en guardia no sea gratis y que defender alargue el duelo sin eternizarlo |
| Control y escape (sección 9) | control del equipo sobre un jefe y de cada rol sobre un mono con y sin `Config.ControlDR` (controles solapados contados una vez); en la arena, lo que entra mientras no puedes actuar (golpe de apertura + arma y una habilidad durante el aturdimiento), con el Evasivo en recarga | que nadie se quede sin salida y que el control no se apile |
| Preparación (sección 10) | monos: aviso de cada mono frente a la reacción; DPS para un jugador atento (`esquivaMonos`); golpes y segundos para romper la guardia. Habilidades (C8): su preparación, recarga, la de un amago y la guardia que gasta por uso. La simulación (secciones 2 y 6) saca cada habilidad al acabar su preparación y no pega con el arma mientras dura | que todo ataque se vea venir y que bloquear contra un alfa no sea un muro ni un papel; que la preparación no se note lenta ni quite valor al combo |

Las secciones 7 a 10 son de la Fase 10 ("Combate v2"). Hasta que se haga el grupo de cada mecánica,
miden los números **propuestos** de `Config` (`Reaction`, `Chain`, `Guard`, `Net`, `Evasive`,
`ComboScaling`, `ControlDR`, `Feint`, `Windup`, `WallBang`). Cuando el grupo se haga, su sección
tiene que medir lo que hace el juego. La arena de la sección 9 necesita `secciones.arena = true` para
el duelo con defensa de la sección 8.

Supuestos (los que más cambian el resultado): monos repartidos (un radio 10 alcanza 2,5 de media,
un radio 14 3,5, más de 14, 4,5); del abanico de flechas entran 2 en un solo mono y el 70 % en un
grupo; el cepo salta a los 2 s; los monos no salen de la lluvia; 0,3 s sin pegar al lanzar; la
simulación pega el 100 % del tiempo y la sección 3 el 60 % (`actividad`). Los proyectiles (C9: las armas
a distancia y los golpes con `velocidad` en la ficha) aciertan `acierto` = 1 − falla × distancia ÷
velocidad: contra monos 30 studs y 0,25 por segundo de vuelo (la ayuda adelanta el tiro: arco 96 %,
bastón 94 %), contra jugadores 35 studs y 0,9 (arco 84 %, cerbatana 81 %, honda 77 %, bastón 74 %);
son supuestos hasta que la telemetría (`ShotsHit`/`ShotsMissed`) dé los reales. El veneno de las cerbatanas
cuenta en el DPS del arma, sin críticos y redondeado como en el juego, en el mono al que dispara (si el
médico reparte los dardos envenena a más, hasta 5 con su cadencia); el de una habilidad (`veneno` en la
ficha) no se suma al de la cerbatana en ese mono: gana el más fuerte. El disparo de remate (C9b): el
golpe del arma es la media del ciclo (3 normales y el remate); en un grupo el del arco da siempre a un
segundo y el del bastón alcanza a `tipicosEnRadio(6)` − 1 = 1 más; la cura doble solo cuenta para
los aliados (la del médico a sí mismo, en la arena, es la normal). Cámbialos en `OPCIONES`
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
| Marca de una mascota | con su dueño solo y con el equipo, ≤ 40 % del DPS de un arma de rol (como las de combate); sobre un jefe, "Marcar presas" sigue sumando ≥ 50 % de lo que suma sin ella | las dos marcas no se suman (gana la mayor): si la de la mascota tapa la del cazador, "Marcar presas" deja de valer |
| Duración de un jefe (4 jugadores, 60 % de actividad) | 90–240 s | que dé tiempo a ver sus 3 fases; objetivo 2 min el primero y 3 min el último |
| Un jefe con un jugador solo | ≤ 360 s | solo es más difícil, pero no eterno |
| Curación sostenida del médico | ≤ 8 por segundo por aliado | un grupo de monos tiene que seguir siendo peligroso |
| Arena: duelo entre dos jugadores del mismo rol (Guerrero, Cazador, Mago), 60 % de actividad | 8–10 s | da tiempo a esquivar, cerrar un combo y que el médico cure; el médico (apoyo) puede durar más |
| Arena: el mismo duelo con defensa (bloquea el 25 % y para el 5 % del daño) | 8–12 s | defender bien alarga el duelo, pero no lo eterniza |
| DPS de la cadena de golpes frente al golpe suelto | ×0,95–1,05 | la cadena cambia el ritmo y el remate, no el daño |
| Disparo de remate a distancia (C9b): DPS del ciclo frente al disparo suelto | ×0,95–1,05 contra uno y en la arena; ≤ ×1,15 contra el grupo | el remate premia el ritmo, no sube el daño; el que atraviesa o estalla alcanza a más, pero no convierte el arma en un área |
| Lo que entra mientras no puedes actuar, después del golpe que te aturde (arena, Evasivo en recarga) | ≤ 35 % de 100 de vida | un combo sin escape no puede decidir un duelo |
| Golpe más fuerte de una habilidad (definitivas incluidas) a un jugador | ≤ 40 de 100 | como los monos el día 1: nada te tumba de uno o dos golpes; las definitivas llevan su propio multiplicador contra jugadores |
| Hueco entre dos golpes de una cadena | ≥ `Config.Reaction` (0,25 s) | la cadena siempre deja bloquear, hacer parry o esquivar |
| Golpes para romper la guardia (un golpe suelto: remate, habilidad, jefe, mono) | ≥ 4 | ningún golpe solo te deja sin guardia |
| Segundos que aguanta en guardia quien recibe cadenas seguidas | 4–6 s | quedarse en guardia se paga, pero da tiempo a responder |
| Preparación de una habilidad | 0–0,35 s; una imbloqueable se ve venir (preparación + lo que tarda su golpe) ≥ `Config.Reaction` (0,25 s) | más larga se nota lenta; una imbloqueable que no se ve venir no tiene respuesta |

## 4. Línea base (octubre de 2026, sin talentos, grupo de 4)

**21 de octubre de 2026, nivel 4 de la forja volcánica** (G5). Mejoras por día (`armasPorDia`): nivel 2
desde el día 3, nivel 3 desde el 5 (pide la corona del jefe del día 4) y nivel 4 desde el 7 (cristal del
jefe del día 6). El nivel 4 sube el DPS del arma ~+30 % (Mazo volcánico 68 cada 0,9 s; Arco de brasa
44 cada 0,65 s; Bastón de lava 34 cada 0,75 s; Cerbatana de azufre 26 cada 0,55 s con veneno 11/s; todos
con 20 % de crítico): DPS 60 s con combos, 1 obj · grupo: Guerrero 59 · 84, Cazador 73 · 92, Mago 52 ·
75, Médico 42 · 47 (con el nivel 3: 48 · 73, 58 · 77, 43 · 66, 32 · 38). Con el nivel 3 o 4 las
habilidades valen menos segundos de arma (Pisotón 7,9, Lluvia 8,3, Rayo 7,2, Múltiple y Cepo 0,35): sus
daños no suben con la forja; los límites se miden con las armas básicas. El Gorila de Ceniza pasa de
5.600 a 7.000 de vida para seguir en ~3 min con el nivel 4 (168 s con 4 jugadores; 207 s solo).
Armadura volcánica: −65 % de daño (vida efectiva +29 % sobre la de plata); el gorila alfa del día 20
pasa de 45 a 35 por golpe. Con el Grito de guerra (−40 %) se queda en −79 %.

**20 de octubre de 2026, arena de Dunas** (sección 6 de la calculadora, `secciones = { arena = true }`;
el equipamiento se mide con `equipo = { Guerrero = { "BoneMaul" } }` y los números con
`Equilibrio.ultimaArena()`). Contra jugadores: armas ×0,55 (el arco ×0,7 encima), habilidades ×0,45,
control ×0,5, curaciones ×0,6 (`Config.Arena`). Duelo espejo: Guerrero 9,4 s, Cazador 8,6 s, Mago 8,7 s (9,8 · 9,1 · 9,3 s
desde el 22-10-2026, con las definitivas ×0,45 más: `UltimateDamageMultiplier`),
Médico 30 s (con armas ×1 eran 4,5–6 s). El guerrero tumba a cazador y mago en 6,8 s si les alcanza
(cuerpo a cuerpo); al médico, 11–16 s. Las 24 variantes de `Data/ArenaGear` cambian el duelo de su
rol menos de un ±12 % (ataque o aguante), y su espejo queda en 7,6–10,6 s: las de −10 de vida a ~7,7 s
a cambio de movilidad, la Coraza de jaguar a 10,6 s a cambio de −8 % de velocidad. Lo que ganan las de
"área" (Garrote ligero, Arco corto) no sale en un duelo.

Para comparar las propuestas. Vuelve a sacarla con la calculadora si cambian los números del juego.

**19 de octubre de 2026, sabuesos** (Grupo 14). El pointer inglés (épico) marca en cada tick (2 s) al
mono más cercano a su dueño durante 3 s: +15 % de daño de todos (a los jefes, ×0,5). Equivale a 3,1
DPS con su dueño solo (15 % del arma; el Ocelote, el otro épico, 35 %) y 6,2 con 4 jugadores que meten
al marcado la mitad de su daño (30 %): el Ocelote es la mascota de quien juega solo y el pointer, la
del grupo. A un jefe da +7,5 % del daño del equipo; "Marcar presas" suma +6,7 % sola y +4,2 % con el
pointer en el equipo (+14,7 % y +9,2 % con talentos). Medido en Play: el garrote de piedra pasa de 27
a 31 contra el marcado. El beagle (común) rastrea y huele el huevo; el labrador (raro, `LootBonus`
0,3) trae un objeto más en el 30 % de las muertes que sueltan algo (~14 extras en 50 muertes en Play).
Ninguno cambia los roles ni los jefes.

**19 de octubre de 2026, médico en combate** (cerbatanas con veneno, pasiva con +15 de vida y Savia
protectora, remates que envenenan y exponen). Guerrero, Cazador y Mago no cambian:

| Médico | Antes | Ahora |
|---|---|---|
| Cerbatana (DPS real; básica · hueso · chamán) | 12,2 · 20,1 · 30,7 | 18,2 · 24 · 33 (veneno real 4 · 5 · 6 por segundo) |
| DPS 60 s, 1 obj (combos), básica · mejora 1 · mejora 2 | 11,2 · 21,3 · 31,4 | 18,4 · 23,7 · 32,4 |
| Frente a la media de Guerrero, Cazador y Mago (1 obj) | 36 % · 54 % · 63 % | 59 % · 60 % · 65 % |
| DPS 60 s, grupo (sin → con combos) | 11,9 → 11,8 | 18,1 → 24,3 (el remate de "Cura de urgencia" envenena a todo el grupo) |
| Polvo somnífero (segundos de arma) | 0,73 | 0,8 (daño 5 → 8: con la cerbatana nueva se quedaba en 0,49) |
| Tiempo para matar un mandril el día 1 | 20,8 s | 12,7 s |

Con los dardos venenosos del taller (munición opcional, veneno ×1,6; opción `dardosVenenosos` de la
calculadora) sube a 20,5 · 26,8 · 36,6 contra un mono (65 % · 68 % · 74 %) mientras le queden.
Curación igual (14,6 → 20,7/s al equipo; 34,4/s con talentos al máximo, hallazgo 3). Jefes con 4
jugadores: 101 / 118 / 141 / 167 s. El Mono X-7 baja al 45 % del DPS medio de un arma de rol (sube la
media). La Savia protectora (10 cada 8 s como mucho, ~1,2/s) y el +30 % de los dormidos de la Nana
(lo aprovecha todo el equipo) no se suman al daño ni a la curación del médico.

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

1. ~~Sin rendimientos decrecientes de control sobre los enemigos~~ (equipo de 4 sobre un jefe 25 %, 39 % con
   talentos al máximo; el cazador 43 % por mono). **Resuelto en C6 (22-10-2026)**: `Config.ControlDR`
   en `Status.stun` (equipo 25 → 12 %, con talentos 35 → 17 %).
2. **El Mono X-7 (legendario)** hace el 45 % del DPS medio de un arma de rol (48 % antes de las
   cerbatanas con veneno del 19-10-2026); las mascotas no pasan por el ×0,7.
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
10. **Alfas del orangután y el gorila** (18-10-2026, pedido del usuario): sus tropas son de 1–3, así
   que casi cada encuentro trae un alfa (×2,5 de vida y ×1,5 de daño: gorila alfa 800 de vida y 30
   de daño, orangután alfa 550). Los cinco simios con alfa también son más grandes (GDD §8.2). Sin
   medir con la calculadora.
11. **Duelo de médicos en la arena de Dunas: 30 s** (objetivo 8–10 s, `Config.Arena.HealingMultiplier`
   0,6). El usuario decidió el 20-10-2026 dejarlo así por ahora (el médico apoya, no duela) y
   revisarlo cuando haya más jugadores, con datos de partidas reales.

12. ~~El Pisotón quitaba 84 de 100 de un golpe en la arena~~ (y el Rayo encadenado 68; en el PvP de la
   Isla, 94 y 75). **Resuelto el 22-10-2026** a petición del usuario: las definitivas llevan un
   multiplicador propio contra jugadores (`Config.Arena.UltimateDamageMultiplier` 0,45 y
   `Config.Abilities.PvPUltimateMultiplier` 0,4, por `CombatRules.pvpUltimateMultiplier` en
   `AbilityService.hurt`). Arena: Pisotón 38 y Rayo 30; duelos espejo 9,8 · 9,1 · 9,3 s. Límite nuevo
   `golpeJugador` (40). Con defensa, el duelo de guerreros sale en 12,2 s (límite 12): se ajusta en C5
   con los números de la guardia. **Ajustado en C5:** bloqueo −50 % contra jugadores → 11,8 s.

**Fase 10 (22-10-2026), números propuestos medidos** (secciones 7 a 10, se aplican en sus grupos):
- Cadena: 4 golpes (×0,9 · ×0,9 · ×1 · ×1,4 en 0,9 · 0,9 · 1 · 1,4 golpes del arma) con el mismo DPS
  que el golpe suelto. El tambaleo (0,35 s) se recorta para dejar siempre 0,25 s de hueco: sin eso,
  la cadena del machete no dejaba responder y quitaba un 45 % en la arena.
- Guardia: la de la cadena se escala con la velocidad del arma (garrote y machete la rompen en
  5,7 s; sin escalar, el machete en 3,8 s). Jefes y habilidades gastan 25 (4 golpes) y los monos 12 ·
  18 · 22 por categoría (×1,5 los alfas): con 40 y 50, un alfa o un jefe la rompían en 2 golpes.
- Duelo espejo con defensa: Guerrero 11,8 s, Cazador 10,7 s, Mago 10,8 s (sin defensa 9,4 · 8,6 · 8,7).
  **C5 ✅ (22-10-2026):** con las definitivas contra jugadores (hallazgo 12) el de guerreros salía en
  12,2 s con bloqueo −60 %; `BlockReduction` pasa a **0,5** (contra monos sigue 0,7): 11,8 · 11 ·
  11,2 s (sin defensa 9,8 · 9,1 · 9,3). Con talentos al máximo, el de guerreros con defensa da 13 s
  (13,4 con −60 %): viene de que el duelo sin defensa ya da 10,7 s con talentos (alerta de antes,
  junto al cazador en 7,5 s y el Pisotón con 65 % tras aturdir), no de la guardia.
- Rendimientos decrecientes `1 → 0,8 → 0,6 → 0,4` con reinicio a los 6 s. El equipo de 4 sobre un
  jefe pasa del 25 % al 12 % (con talentos al máximo, del 35 % al 17 %; resuelve el hallazgo 1).
  Un rol solo casi no lo nota: el cazador sobre un mono pasa del 27 % al 25 %.
  Con `1 → 0,5 → 0,25` y 10 s el control casi desaparecía (equipo 7 %, cazador 11 %).
  **C6 ✅ (22-10-2026):** aplicado en `Status.stun` para todo control a un enemigo; medido en Play.
- Preparación de monos y jefes (C6 ✅): cabe en la recarga de cada ataque, así que el DPS y el tiempo
  para matar de la sección 4 no cambian (la sección 10 avisa si un aviso no cabe en su recarga). Para
  un jugador atento (30 % esquivados) el DPS baja ~30 %: es el premio de defenderse, no se compensa.
- **C7 ✅ (22-10-2026):** Evasivo (recarga 25 s, 0,5 s invulnerable) y escalado del combo en PvP
  (−8 % de daño y −15 % de tambaleo por golpe desde el 4.º, mínimos 0,5 y 0,4) con los números
  propuestos: las secciones 7 y 9 no cambian (ya los medían). Nuevo en la sección 9: los controles de
  jugadores llevan los rendimientos decrecientes de los monos; 4 rivales controlándote con todo te
  tienen sujeto el 16 % del tiempo solo con la inmunidad de 2 s y el **11 %** con ellos (talentos al
  máximo 22 → 14 %). La alerta del Pisotón con talentos al máximo (65 % tras aturdir 1,75 s) sigue: la
  respuesta es el Evasivo (con él entra solo el golpe de apertura, 38); se revisa en C13.
- **C8 ✅ (22-10-2026):** preparación de las habilidades (`castSeconds`, 0,15–0,35 s; al momento
  Grito, Parpadeo y Escudo) y amagos (`Config.Feint`). Valor del combo en 180 s casi igual (grupo /
  1 objetivo: guerrero +30/+14 → +33/+15 %, cazador +31/+17 → +29/+14 %, mago +34/+15 → +32/+15 %).
  DPS en grupo sin combos: guerrero 47,3 → 45,4 (−4 %: la preparación del Torbellino y la Embestida
  se suma al giro y a la carga y le quita garrotazos), los demás ±1 %. Duelos espejo de la arena 9,8 ·
  9,1 · 9,3 → **10,4** · 9,3 · 9,6 s, y el de guerreros con defensa 11,8 → **12,6** s: dos alertas
  nuevas, a propósito (la preparación da tiempo a responder) y se recalibran en C13, cuando los
  proyectiles reales (C9) cambien más los duelos. Compensarlo ahora no cuadra: el garrote ×1,1 en la
  arena devuelve 9,8 s pero sube el combo del Pisotón a 36 % (límite 35 %), y la Embestida 27 y el
  Rompehuesos 27 con el garrote ×1,04 lo arreglan sin talentos pero dejan al mago −20 % con talentos.
  El efecto es escalonado (un garrotazo más o menos): 0,05 s de preparación más o menos lo cambia
  todo o nada. La alerta nueva "imbloqueable que no se ve venir" la tenía el Pisotón antes de C8
  (0,2 s): ahora 0,55 s.
- **C9 ✅ (22-10-2026):** proyectiles reales. Con la tasa de acierto (`acierto`), sin compensar,
  la Isla perdía un 3–6 % de DPS a distancia y la arena se iba (duelo de cazadores 9,3 → 10,8 s, de
  magos 9,6 → 11,9 s). Compensado: cada arma a distancia +1 de daño (= 1 ÷ su acierto, redondeado;
  todas a ±2,5 % del DPS real de antes), Flecha perforante 16 → 17, Bola de fuego 27 → 29 y en la
  arena `WeaponMultipliers` arco 0,7 → 0,85, bastón 1,35, cerbatana 1,1, honda 1,2. Resultado: DPS
  60 s con combos ±1 % en todos los roles, valor del combo igual, duelos espejo 10,4 · 9,3 · 9,7 s
  (antes 10,4 · 9,3 · 9,6) y las mismas alertas sin talentos y con talentos al máximo. El Disparo
  múltiple queda a −4 % (7 por flecha: el siguiente entero se pasa). Los supuestos contra jugadores
  se revisan en C13 con la telemetría de aciertos.
- **C9b ✅ (22-10-2026):** disparo de remate (cada 4.º seguido, normales ×0,9 y remate ×1,3). Por
  arma: contra uno ×0,99–1,03 (redondeo), contra el grupo arco ×1,10–1,13 y bastón ×1,11–1,15 (35 %
  del remate a uno más), honda 17–19 % de control sobre un mono. Primera propuesta con el 50 % a los
  demás: ×1,16–1,20 en grupo. Veneno doble de la cerbatana: ×1,16–1,23 contra uno (el remate llega
  antes de que se acabe), cambiado por la cura doble al aliado (2,7 → 3,4/s con la cerbatana; al
  médico mismo, no: con ella los duelos contra él se alargaban un 9 %). Resultado: DPS en grupo sin
  combos cazador 40,7 → 42,5 y mago 36,1 → 37,3 (el resto igual), valor del combo 29 → 28 % y 32 → 31 %
  (grupo), duelos espejo 10,4 · 9,4 · 9,8 s (el médico 30,5 → 28,9), las mismas 9 alertas sin
  talentos y con talentos al máximo 18 → 17 (el combo del cazador 36 → 35 %).

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
| ¿Cuánto aciertan los disparos? | `ShotsHit` ÷ (`ShotsHit` + `ShotsMissed`), por rol y place (Isla / Dunas) | `OPCIONES.acierto` (contra monos en la Isla, contra jugadores en Dunas) |
| ¿Se dispara al ritmo? | `ShotFinishers` × 4 ÷ (`ShotsHit` + `ShotsMissed`), por rol y place (1 = siempre al ritmo) | el remate de la sección 7 (que supone que siempre) |

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
