# Combate v2: antes → después

Cierre de la Fase 10 ("Combate v2", `docs/PLAN.md`), **22 de octubre de 2026**. Repite las medidas de la foto
inicial (`docs/combate-v2/linea-base.md`, código de `b633a76`) con el código final (grupos C1–C13), con las
mismas opciones de la calculadora y las mismas pruebas en Play.

**Cómo se midió.**
- La calculadora `Equilibrio` en modo edición, en el Studio de la **Isla**, con Rojo conectado; grupo de 4,
  actividad 60 %, días 1 y 8, sin talentos y con talentos al máximo, con la sección de la arena:
  `E.informe({ secciones = { arena = true } })` y `E.informe({ talentos = "max", secciones = { arena = true } })`.
- Pruebas en Play en la Isla por MCP, con un jugador guerrero. Perfil copiado antes en
  `PlayerData_v1_backups` (`u_<id>_antesC13`) y restaurado después.
- Desde C13 la calculadora mide la arena **sin talentos** aunque se le pidan (en Dunas no cuentan, como dice
  `ArenaRoleService`). Antes salían 2 alertas de la arena con talentos que en el juego no pasaban.

## Resumen

**Mejor:**
- Ya no se pega a través de paredes (0 golpes de 7 con el Torbellino y 0 de 4 con el garrote) y los disparos
  se pueden esquivar (la piedra que antes perseguía, ahora falla).
- Hay defensa activa (bloqueo, parry, guardia, amagos), escape de los combos (Evasivo), escalado del combo en
  PvP y control decreciente sobre los monos y los jefes. El equipo de 4 tiene quieto a un jefe el **12 %** del
  tiempo (antes 25–30 %; con talentos al máximo, 17 % frente a 35–42 %).
- En la arena, nada te tumba de un golpe (el Pisotón quitaba 84 de 100; ahora 38) y lo que entra mientras no
  puedes actuar es como mucho el 34 % de la vida, o solo el golpe que abre si tienes el Evasivo.
- Alertas de la calculadora con talentos al máximo: **17 → 11**. Las 7 que quedan sin talentos y las 11 con
  talentos ya estaban antes de la Fase 10 (abajo, con su razón).

**Peor (a propósito o con razón):**
- Los duelos de la arena duran un poco más (espejo 9,4 · 8,6 · 8,7 → **9,8 · 9,4 · 9,8 s**): la preparación de
  las habilidades y los proyectiles reales dan tiempo a responder. Siguen en 8–10 s; defendiendo bien, 11,4–11,9 s.
- El DPS con combos baja hasta un 9 %: el guerrero −7 a −9 % (por la preparación y por su daño enlazado, que
  pasa de +25 % a +15 %), el cazador y el mago −4 a −5 % contra uno y ±4 % en grupo (el médico sube un 4 %).
  Los jefes duran un 3–5 % más (105–174 s con 4 jugadores). El riesgo del plan permitía ±10 %.
- El servidor trabaja más peleando: heartbeat 0,31 → 0,71 ms y envío 40 → 78 kbps (proyectiles de verdad,
  historial de posiciones para el rebobinado, zonas y avisos). Muy lejos de los 16 ms de un fotograma, pero
  hay que mirarlo con 5 jugadores (no se pudo por MCP).

## 1. Mecánicas

| Mecánica | Antes | Después |
|---|---|---|
| Máquina de estados con prioridades | ✗ | ✓ C2 (`Combat/StateMachine`, `Shared/CombatState`) |
| Aturdido que no deja actuar | ✗ | ✓ C2 (`Status.stunPlayer`) |
| Inmovilizado (puede pegar) | ✓ | ✓ |
| Bloqueo, parry y guardia | ✗ | ✓ C5 (`Combat/Guard`) |
| Imbloqueables | ✗ | ✓ C5–C6 (Rompehuesos, Pisotón, Meteoro; pisotón del gorila, agarre y embestida de los jefes, peligros del suelo) |
| Cadena de golpes con el arma | ✗ | ✓ C4 (4 golpes, `Shared/MeleeChain`) y disparo de remate C9b (`Shared/RangedChain`) |
| Amagos | ✗ | ✓ C8 (`Combat/Feint`) |
| Evasivo (escape de un combo) | ✗ | ✓ C7 (`Combat/Evasive`) |
| Escalado del combo en PvP | ✗ | ✓ C7 (`Combat/ComboScaling`) |
| Rendimientos decrecientes de control sobre enemigos | ✗ | ✓ C6 (`Config.ControlDR`) |
| Proyectiles que se pueden esquivar | ✗ | ✓ C9 (`Combat/Projectiles`) |
| Rebote contra muros | ✗ | ✓ C10 (`Combat/Knockback`) |
| Zonas de peligro de las habilidades | Solo el suelo ardiendo del Meteoro rematado | ✓ C10: además, hielo de la Nova y nube del Polvo (`Combat/Zones`) |
| Coberturas que se rompen (Dunas) | ✗ | ✓ C11 (`Combat/Destructibles`, `CoverService`) |
| Altar disputado (Dunas) | ✗ | ✓ C11 (`AltarService`) |
| Bloqueo de cámara (shift lock) | ✗ | ✓ C2 (en Ctrl) |
| Estamina con autoridad del servidor | ✗ | ✓ C2 (`Combat/StaminaServer`) |
| Preparación visible en los mordiscos | ✗ | ✓ C6 ("!" y "‼", `Combat/EnemyAttack`) y en las habilidades C8 |
| Claridad (estallidos, rombos de la cadena, temblor, sonidos, controles en Ajustes, guía) | Parcial | ✓ C12 |
| Combos de 3 habilidades con conexiones y racha | ✓ | ✓ |
| Esquiva con invulnerabilidad (0,35 s) | ✓ | ✓ |

## 2. Detección

| Ataque | ¿Respeta paredes? | ¿Se puede esquivar? | ¿Compensa el lag? |
|---|---|---|---|
| Golpe con arma | ✗ → ✓ (línea de visión de quien pega) | — | ✗ → ✓ (rebobina hasta 0,15 s; en PvP espera el parry del defensor hasta su ping, máx. 0,12 s) |
| Disparo de arma contra monos | Al apuntar → ✓ siempre (proyectil) | ✗ → ✓ | ✗ → la ayuda adelanta al mono, el proyectil no rebobina (favorece al que esquiva) |
| Disparo de arma contra jugadores | ✓ | ✗ (instantáneo) → ✓ | ✗ → sin adelanto y con ayuda más estrecha |
| Habilidades que viajan | ✓ | ✗ → ✓ | ✗ → como los disparos |
| Áreas (Torbellino, Nova, Grito, Pisotón, Meteoro, Rompehuesos, Polvo, Ungüento, Cepo) | ✗ → ✓ (lo que ve su centro) | — | — |
| Mordisco de mono | ✗ → ✓ (y tiene que seguir delante al acabar el aviso) | Solo con la esquiva → apartándose, esquivando, bloqueando o con parry | — |

**Pruebas fijas en Play** (Isla, el mismo montaje que en la foto inicial):

| Prueba | Antes | Después |
|---|---|---|
| Torbellino con un muro de piedra (1 × 14 × 8) entre el guerrero y el muñeco, a 8 studs | Le pega 7 veces | **0 golpes**; sin el muro, 7 golpes de 6 |
| Garrote a 6,5 studs con el mismo muro | 4 de 4 | **0**; sin el muro, la cadena entera (24 · 24 · 27 · 37) |
| Honda a 40 studs; el muñeco se aparta 15 studs a los 0,09 s del disparo | Le pega igual (8) | **Falla**; quieto, le da (8) |

## 3. Equidad PvP (arena de Dunas)

Segundos que tarda la fila en tumbar a la columna (con combos; entre paréntesis, sin combos). Sin talentos.

| Atacante \ Defensor | ⚔️ Guerrero | 🏹 Cazador | 🔮 Mago | ⛑️ Médico |
|---|---|---|---|---|
| ⚔️ Guerrero | 9,4 → **9,8** | 6,8 → 7,7 | 6,8 → 7,7 | 11,4 → 13,6 |
| 🏹 Cazador | 11,9 → 11,9 | 8,6 → **9,4** | 8,6 → 9,4 | 16,2 → 18,7 |
| 🔮 Mago | 12 → 12,4 | 8,7 → 9,8 | 8,7 → **9,8** | 16,4 → 20,1 |
| ⛑️ Médico | 16,6 → 14,9 | 12 → 11,8 | 12 → 11,8 | 30,2 → **28,9** |

| Medida | Antes | Después | Límite | ¿Cumple? |
|---|---|---|---|---|
| Duelo espejo (Guerrero, Cazador, Mago) | 9,4 · 8,6 · 8,7 s | 9,8 · 9,4 · 9,8 s | 8–10 s | ✓ |
| El mismo con defensa (bloquea el 25 %, para el 5 %) | — | 11,8 · 11,4 · 11,9 s | 8–12 s | ✓ |
| Duelo espejo de médicos | 30,2 s | 28,9 s | (decidido dejarlo, hallazgo 11) | — |
| Tiempo sin poder actuar | 0 s (ningún control impedía pegar) | Pisotón 1 s, Polvo 1,25 s (con el Evasivo, 0,25 s) | — | — |
| Combo sin escape: lo que entra después del golpe que aturde (Evasivo en recarga) | — (no existía el aturdido real) | Pisotón 34 %, Polvo 20 %; con el Evasivo, solo el golpe que abre | ≤ 35 % | ✓ |
| Golpe más fuerte de una habilidad a un jugador | Pisotón 84 de 100 | Pisotón 38 · Rayo 30 · Flecha perforante 10 · Polvo 4 | ≤ 40 | ✓ |
| Rebote contra un muro en la arena | — | aturde 0,25 s; lo que entra después 0–12 % | ≤ 35 % | ✓ |
| 4 rivales controlándote con todo (180 s) | — | sujeto el 11 % del tiempo (16 % solo con la inmunidad de 2 s) | — | — |
| Variantes de equipo de Ámbar (24) | duelo de su rol ±12 %; espejo 7,6–10,6 s | ±15 % (la Cerbatana del chamán, −17 % de ataque a cambio de curar); espejo 8,3–11,3 s | horizontales | ✓ (revisar la del chamán con datos reales) |

**Por qué cambia:** la preparación de las habilidades (C8) le quitaba garrotazos al guerrero (10,4 s, y 12,6 s
con defensa); los proyectiles reales (C9) bajaban el acierto contra jugadores y se compensaron con el ajuste
por arma. En C13: el Grito de guerra protege **−15 %** del daño de otros jugadores (antes −40 %;
`Config.Abilities.PvPWarCryMultiplier` 0,375) y el daño enlazado del guerrero baja a +15 %. Así el guerrero
también tarda algo menos en caer ante el cazador y el mago (13 → 11,9 y 13,6 → 12,4 s), aunque los sigue
tumbando antes si les alcanza.

## 4. PvE (Isla)

Sin talentos, con las armas básicas (día 1) salvo los jefes, que se miden con la forja del día en que aparecen.

| Rol | DPS 60 s, 1 obj (sin → con combos) | DPS 60 s, grupo de 4 (sin → con combos) | Combo en 180 s (grupo / 1 obj) | Combos en 60 s |
|---|---|---|---|---|
| Guerrero | 30,2 → 33,9 **⇒** 28,1 → 31 | 47,8 → 58,6 **⇒** 45,4 → 54,3 | +29 / +12 % **⇒** +27 / +11 % | 12 (11 🔗) ⇒ 12 (11 🔗) |
| Cazador | 29,1 → 33 **⇒** 28,1 → 31,8 | 41,5 → 51,3 **⇒** 42,5 → 52 | +31 / +17 % **⇒** +28 / +15 % | 10 (9 🔗) ⇒ 10 (9 🔗) |
| Mago | 23,1 → 27,3 **⇒** 22,8 → 25,9 | 36,3 → 50,2 **⇒** 37,3 → 48,4 | +34 / +15 % **⇒** +31 / +15 % | 15 (14 🔗) ⇒ 13 (12 🔗) |
| Médico | 17,3 → 18,4 **⇒** 18,1 → 19,1 (cura 14,6 → 20,7/s **⇒** 15,1 → 21,2/s) | 18,1 → 24,3 **⇒** 18,8 → 25,2 | | 10 (9 🔗) ⇒ 10 (9 🔗) |

Con talentos al máximo, enlazar da +34 % (guerrero), +35 % (cazador) y +28 % (mago) en grupo; antes del
retoque de C13, el guerrero +41 % (límite 35 %). Reparto entre roles en grupo (con combos): el guerrero
54,3 frente a la media de los tres, 51,6 (+5 %); en la foto inicial, +10 %.

| Tiempo para matar (s, 60 % de actividad) | Mandril d1 | Mandril d8 | Gorila d1 | Gorila d8 |
|---|---|---|---|---|
| Guerrero | 6,9 → 7,5 | 12,7 → 13,8 | 15,7 → 17,2 | 29 → 31,6 |
| Cazador | 7,1 → 7,3 | 13 → 13,5 | 16,2 → 16,8 | 29,8 → 30,8 |
| Mago | 8,6 → 9 | 15,8 → 16,6 | 19,6 → 20,6 | 36 → 37,9 |
| Médico | 12,7 → 12,2 | 23,4 → 22,5 | 29 → 27,9 | 53,4 → 51,4 |

| Jefe | Día | 1 jugador | 4 jugadores | Límite (4 jugadores) |
|---|---|---|---|---|
| Orangután del Manglar | 2 | 124 → 130 s | 101 → 105 s | 90–240 s ✓ |
| Chimpancé Caudillo | 4 | 146 → 151 s | 118 → 123 s | ✓ |
| Gorila Albino | 6 | 173 → 178 s | 141 → 144 s | ✓ |
| Gorila de Ceniza | 8 | 207 → 214 s | 168 → 174 s | ✓ |

| Control | Antes | Después |
|---|---|---|
| Equipo de 4 roles sobre un jefe (controles solapados una vez) | 25 % (con talentos 35 %); sumados, 30 % y 42 % (límite 30 %) | **12 %** con los rendimientos decrecientes (con talentos **17 %**) |
| Control de cada rol sobre un mono | Guerrero 17 · Cazador 30 · Mago 13 · Médico 21 % (con talentos 18 · 43 · 22 · 28) | 11 · 25 · 13 · 21 % (con talentos 12 · 37 · 23 · 28); el guerrero con todos sus empujones contra un muro, 12 % |
| Te deja quieto un mono solo | Orangután 46 %, gorila 19 % | Igual (y el Evasivo te saca de uno cada 25 s) |
| Golpe más fuerte de un mono | Día 1: 40. Día 20: 61 · 61 · 71 · 81 · 101 | Igual (hallazgo 7, sin decidir) |
| Lo que te pega un mono si estás atento (esquivas o te apartas del 30 % de los avisados) | — | DPS −30 % (el premio de defenderse) |

## 5. Defensa

Antes no existía: la única defensa activa era la esquiva.

| Medida | Después |
|---|---|
| Bloqueo bien hecho | −50 % del daño de otro jugador (y sin el control de su habilidad), −70 % del de un mono. Fallido: el golpe entero. |
| Parry bien hecho (0,3 s) | Anula el golpe, +20 de guardia y tambalea al atacante (0,6 s un jugador, 1 s un mono, la mitad un jefe). |
| Golpes para romper la guardia (arma de cada rol, cadenas seguidas) | Garrote 7 (aguanta 5,7 s) · arco 10 (7,2 s) · bastón 10 (8,1 s) · cerbatana 10 (6,3 s). Un golpe suelto (remate, habilidad, jefe, mono) necesita ≥ 4. |
| Monos | Guardia por golpe 12 · 18 · 22 por categoría (×1,5 los alfas): un chimpancé alfa la rompe en 4 golpes (3,9 s), un mono ardilla en 9. |
| Amagos | Golpe gratis, uno por segundo; habilidad 15 de estamina y 1,5 s de recarga. |

## 6. Rendimiento

Play en la Isla, 1 jugador, medias de 10 s en cada `Heartbeat` del servidor. En Studio el servidor y el cliente
van en el mismo proceso: sirve para comparar, no como cifra absoluta. **Ojo:** en esta partida había más monos
en la isla que en la de la foto inicial (99 en reposo frente a 63), lo que infla el "después".

| Escenario | Antes (monos · heartbeat · física · envío) | Después | Fotogramas |
|---|---|---|---|
| En reposo, en el Basecamp | 63 · 0,17 ms · 1,11 ms · 14,7 kbps | 99 · 0,18 ms · 1,86 ms · 20,2 kbps | 60 → 60 |
| ~32 mandriles a menos de 60 studs | 93 · 0,18 ms · 1,73 ms · 17,9 kbps | 131 (35 cerca) · 0,35 ms · 3,08 ms · 44 kbps | 60 → 60 |
| Peleando en el grupo (Torbellino cada ~1,8 s y garrote seguido) | 97 · 0,31 ms · 2,21 ms · 40 kbps | 131 → 104 · 0,71 ms · 2,95 ms · 77,5 kbps | 60 → 60 |

Remotos peleando (nuevo): del cliente al servidor 1,7 por segundo (`UseAbility` y `UseWeapon`); del servidor
al cliente, 3,5 por segundo. Con 5 jugadores: queda para *Test → Clientes y servidores* (VERIFICACION §11.3).

## 7. Alertas de la calculadora

| | Antes | Después |
|---|---|---|
| Sin talentos | 7 | **7** (las mismas) |
| Con talentos al máximo | 17 | **11** |

**Las que quedan, con su razón** (ninguna es de la Fase 10):
- Golpe más fuerte de un mono el día 20 (gibón y mandril 61, chimpancé 71, orangután 81, gorila 101 de 100;
  máx. 60) y el gorila el día 1 (40, justo el límite): **hallazgo 7**, sin decidir. Ahora todos avisan antes y
  el golpe se bloquea (−70 %) o se para, así que el riesgo es menor que cuando se puso el límite.
- Mono X-7, 45 % del DPS de un arma (máx. 40 %): **hallazgo 2**, sin decidir.
- Con talentos al máximo: Lluvia de proyectiles 39,6 s de arma (máx. 30), Bola de fuego 4,57 s y más del 80 %
  del bastón en grupo, el médico cura 34,9/s al equipo (máx. 8 por aliado): **hallazgo 3**, sin decidir.

**Desaparecen:** el equipo de 4 sobre un jefe (42 %; ahora la calculadora mira el límite con los rendimientos
decrecientes: 17 %), enlazar combos del guerrero y del cazador (+37/+36 %; ahora +34/+35 %), las 3 alertas de
duelos de la arena con talentos (no aplicaban; desde C13 la arena se mide sin talentos) y el Pisotón tras
aturdir con talentos (65 %, tampoco aplicaba). Durante la fase salieron y se resolvieron el Pisotón de un
golpe (84 de 100, hallazgo 12) y el duelo de guerreros (10,4 s y 12,6 s con defensa, C8 → C13).

**Hallazgos de `equilibrio.md` §5:** resueltos el 1 (control sin rendimientos decrecientes, C6), el 8 (equipo
sobre un jefe y combos con talentos, C6 y C13) y el 12 (Pisotón, C1). Siguen el 2, 3, 4, 5, 6, 7, 9, 10 y 11.
No hay hallazgos nuevos.

## 8. Telemetría

| Antes | Después |
|---|---|
| `AbilityUses`, `AbilityLinked`, `ComboCompleted`, `ComboBestStreak`, `DamageBySource`, `HealingBySource`, `TimeHeld`, `MinutesPlayed`, `PlayerDowned`, `BossDefeated` | Los mismos, más las mecánicas (`CombatRules.Mechanic`, con el place en el segundo campo): `Parries`, `Blocks`, `GuardBreaks`, `Evasives`, `ChainFinishers`, `Feints`, `WallBangs`, `ShotsHit`, `ShotsMissed`, `ShotFinishers`, `CoversBroken` y `AltarCaptures` (Dunas también manda `ArenaMatchPlayed`) |

Los valores reales llegan al publicar. Lo primero que hay que mirar: `ShotsHit`/`ShotsMissed` contra jugadores
(la calculadora supone 0,9 de fallo por segundo de vuelo) y cuántos `Parries` y `Feints` hay por partida en
el móvil frente al PC.

## 9. Lo que no se ha podido medir

- Todo lo que necesita 2 jugadores o más (parry, amagos y guardia entre jugadores, Grito contra un rival,
  escalado, altar disputado, cura doble de la cerbatana, rendimiento con 5): pasos de VERIFICACION §11.3.
- Ping real (la ventana del parry del defensor, el rebote con aviso tardío, proyectiles en otros clientes).
- Un teléfono de verdad (botones "Guardia" y "¡Evasivo!", rombos de la cadena junto a los botones).
