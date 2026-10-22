# Combate v2: foto inicial (antes de cambiar el combate)

Tomada el **22 de octubre de 2026**, al empezar la Fase 10 ("Combate v2", `docs/PLAN.md`), con el código
del commit `b633a76`. Es el "antes" de la comparativa que se escribe al cerrar la fase
(`docs/combate-v2/comparativa.md`). No se toca: si una medida se rehace, se añade abajo con su fecha.

**Cómo se midió.**
- La calculadora `Equilibrio` (`src/island/tools/Equilibrio.luau`) en modo edición, en el Studio de la
  **Isla** ("🍌Isla de monos🐒(supervivencia)"), con Rojo conectado. Se repitió en el de Dunas, que
  tiene la misma `Shared` y la misma calculadora, y dio lo mismo.
- Opciones por defecto (grupo de 4, actividad 60 %, días 1 y 8), sin talentos y con talentos al máximo,
  y con la sección de la arena:

```lua
local m = game.ServerStorage.Tools.Equilibrio:Clone(); local E = require(m); m:Destroy()
print(E.informe({ secciones = { arena = true } }))
print(E.informe({ talentos = "max", secciones = { arena = true } }))
```

Las secciones 7 a 10 de la calculadora miden los números **propuestos** de la Fase 10. No forman
parte de la foto inicial.

**Pruebas en Play** (Isla, el mismo día, por MCP, con un jugador guerrero). El perfil se copió antes
en `PlayerData_v1_backups` (`u_<id>_antesC1`) y se restauró después. Resultados en §2 y §6.

## 1. Mecánicas

| Mecánica | Antes |
|---|---|
| Máquina de estados con prioridades | ✗ (atributos sueltos) |
| Aturdido que no deja actuar | ✗ (un jugador "aturdido" solo deja de andar: puede pegar, usar habilidades y esquivar) |
| Inmovilizado (puede pegar) | ✓ (es lo único que hay: `Status.holdPlayer`) |
| Bloqueo, parry y guardia | ✗ |
| Imbloqueables | ✗ |
| Cadena de golpes con el arma | ✗ (golpe suelto) |
| Amagos | ✗ |
| Evasivo (escape de un combo) | ✗ (solo la inmunidad de 2 s al soltarse) |
| Escalado del combo en PvP | ✗ |
| Rendimientos decrecientes de control sobre enemigos | ✗ |
| Proyectiles que se pueden esquivar | ✗ (contra monos, el daño llega aunque se aparten) |
| Rebote contra muros | ✗ |
| Zonas de peligro de las habilidades | Solo el suelo ardiendo del Meteoro rematado |
| Coberturas que se rompen (Dunas) | ✗ |
| Altar disputado (Dunas) | ✗ |
| Bloqueo de cámara (shift lock) | ✗ (desactivado en los tres places: Mayús es correr) |
| Estamina con autoridad del servidor | ✗ (solo en el cliente) |
| Preparación visible en los mordiscos | ✗ (el daño entra a la vez que la animación) |
| Combos de 3 habilidades con conexiones y racha | ✓ |
| Esquiva con invulnerabilidad (0,35 s) | ✓ |

## 2. Detección

| Ataque | Antes | ¿Respeta paredes? | ¿Se puede esquivar? | ¿Compensa el lag? |
|---|---|---|---|---|
| Golpe con arma | `GetPartBoundsInBox` en el instante | ✗ | — | ✗ |
| Disparo de arma contra monos | Ayuda de puntería + daño con retraso | Al apuntar sí, después no | ✗ (persigue) | ✗ |
| Disparo de arma contra jugadores | Rayo directo, sin ayuda | ✓ | ✗ (instantáneo al apuntar) | ✗ |
| Habilidades que viajan | `Spherecast` en el instante + daño con retraso | ✓ | ✗ | ✗ |
| Áreas (Torbellino, Nova, Grito, Pisotón, Meteoro, Rompehuesos, Polvo, Ungüento, Cepo) | Solo distancia | ✗ | — | ✗ |
| Mordisco de mono | Distancia al empezar | ✗ | Solo con la esquiva | — |
| Retroceso de la Embestida a un jugador | El servidor pone la velocidad | — | — | Probablemente no empuja (se comprueba en C2) |

**Pruebas fijas en Play** (se repiten igual en la comparativa final):

| Prueba | Montaje | Resultado antes |
|---|---|---|
| Área a través de un muro | Muro de piedra (1 × 14 × 8) entre el guerrero y el muñeco del centro, a 8 studs; Torbellino | **Le pega**: 7 golpes (6 y uno crítico de 8) |
| Golpe con arma a través de un muro | El mismo muro, garrote de piedra a 6,5 studs, 4 golpes | **Le pega**: 4 de 4 (27 cada uno) |
| Disparo que persigue | Honda a 40 studs; el muñeco se aparta 15 studs en cuanto sale la piedra | **Le pega igual**, 0,30 s después de apartarse (8 de daño) |

## 3. Equidad PvP (arena de Dunas)

Duelos (segundos que tarda la fila en tumbar a la columna, con combos; entre paréntesis, sin combos).
En la arena no cuentan los talentos.

| Atacante \ Defensor | ⚔️ Guerrero (120 vida, −13 %) | 🏹 Cazador (100) | 🔮 Mago (100) | ⛑️ Médico (115, +4,6/s) |
|---|---|---|---|---|
| ⚔️ Guerrero (DPS 24,4 / 22,1) | **9,4 (10,4)** | 6,8 (7,5) | 6,8 (7,5) | 11,4 (13,2) |
| 🏹 Cazador (DPS 19,4 / 16,8) | 11,9 (13,7) | **8,6 (9,9)** | 8,6 (9,9) | 16,2 (20,8) |
| 🔮 Mago (DPS 19,3 / 16,7) | 12 (13,8) | 8,7 (10) | **8,7 (10)** | 16,4 (21) |
| ⛑️ Médico (DPS 13,9 / 13,2) | 16,6 (17,5) | 12 (12,7) | 12 (12,7) | **30,2 (34,3)** |

| Medida | Antes |
|---|---|
| Duelo espejo (Guerrero, Cazador, Mago) | 9,4 · 8,6 · 8,7 s (objetivo 8–10) |
| Duelo espejo de médicos | 30,2 s (decidido dejarlo así el 20-10-2026) |
| Tiempo sin poder actuar | 0 s: ningún control impide pegar (solo quieto) |
| Golpe más fuerte de una habilidad contra un jugador | **Pisotón: 84 de 100** (150 × 1,25 × 0,45, en área de 16 studs). Hallazgo nuevo. |
| Variantes de equipo de Ámbar | Cambian el duelo de su rol menos del ±12 % (G. de la arena, 20-10-2026) |

## 4. PvE (Isla)

Sin talentos, con las armas básicas (día 1) salvo los jefes, que se miden con la forja del día en que
aparecen.

| Rol | DPS 60 s, 1 obj (sin → con combos) | DPS 60 s, grupo de 4 (sin → con combos) | Combo en 180 s (grupo / 1 obj) | Combos en 60 s |
|---|---|---|---|---|
| Guerrero | 30,2 → 33,9 | 47,8 → 58,6 | +29 % / +12 % | 12 (11 🔗) |
| Cazador | 29,1 → 33 | 41,5 → 51,3 | +31 % / +17 % | 10 (9 🔗) |
| Mago | 23,1 → 27,3 | 36,3 → 50,2 | +34 % / +15 % | 15 (14 🔗) |
| Médico | 17,3 → 18,4 (cura 14,6 → 20,7/s) | 18,1 → 24,3 | | 10 (9 🔗) |

| Tiempo para matar (s, 60 % de actividad) | Mandril d1 | Mandril d8 | Gorila d1 | Gorila d8 |
|---|---|---|---|---|
| Guerrero | 6,9 | 12,7 | 15,7 | 29 |
| Cazador | 7,1 | 13 | 16,2 | 29,8 |
| Mago | 8,6 | 15,8 | 19,6 | 36 |
| Médico | 12,7 | 23,4 | 29 | 53,4 |

| Jefe | Día | 1 jugador | 4 jugadores |
|---|---|---|---|
| Orangután del Manglar | 2 | 124 s | 101 s |
| Chimpancé Caudillo | 4 | 146 s | 118 s |
| Gorila Albino | 6 | 173 s | 141 s |
| Gorila de Ceniza | 8 | 207 s | 168 s |

| Control | Antes |
|---|---|
| Equipo de 4 roles sobre un jefe (suma, como la sección 1) | 30 % sin talentos · 42 % con talentos al máximo (límite 30 %) |
| Lo mismo contando una vez los controles que se solapan (sección 9) | 25 % · 35 % |
| Control de cada rol sobre un mono | Guerrero 17 % · Cazador 30 % · Mago 13 % · Médico 21 % (con talentos: 18 · 43 · 22 · 28 %) |
| Te deja quieto un mono solo | Orangután 46 % (agarre 2,5 s), Gorila 19 % (pisotón) |
| Golpe más fuerte de un mono | Día 1: 40 (gorila alfa con crítico). Día 20: gibón y mandril 61, chimpancé 71, orangután 81, gorila 101 |

## 5. Defensa

No existía: la única defensa activa era la esquiva (Q / B / "Esquivar", 1,2 s de recarga, 0,35 s
invulnerable, con estamina del cliente). Las defensas pasivas o de habilidad son la armadura (hasta
−65 %), el Grito de guerra (−40 % durante 4 s cada 12 s), el Escudo de hojas (absorbe 24) y el tótem
guardián (−10 %).

## 6. Rendimiento

Medido en Play en la Isla, 1 jugador. En Studio el servidor y el cliente van en el mismo proceso,
así que sirve para comparar antes y después, no como cifra absoluta. Medias de 10 s de
`Stats.HeartbeatTimeMs`, `PhysicsStepTimeMs` y `DataSendKbps`, tomadas en cada `Heartbeat` del servidor.

| Escenario | Monos en la isla | Heartbeat | Física | Envío | Fotogramas |
|---|---|---|---|---|---|
| En reposo, en el Basecamp | 63 (los de la isla) | 0,17 ms | 1,11 ms | 14,7 kbps | 60 |
| 32 mandriles a menos de 60 studs | 93 | 0,18 ms | 1,73 ms | 17,9 kbps | 60 |
| Peleando en el grupo: Torbellino cada ~1,8 s y garrote cada 0,6 s | 97 | 0,31 ms | 2,21 ms | 40 kbps | 60 |

No se pudo medir con 5 jugadores (por MCP solo hay uno): queda para la prueba de *Test → Clientes y
servidores* de la comparativa final.

## 7. Alertas de la calculadora

**Sin talentos (7):** gibón, mandril, chimpancé, gorila y orangután superan el golpe máximo el día 20
(61 · 61 · 71 · 101 · 81 de 100; máx. 60); el gorila llega a 40 el día 1 (máx. 40); el Mono X-7 hace
el 45 % del DPS de un arma de rol (máx. 40 %).

**Con talentos al máximo (17):** las 7 de arriba, y además:
- Lluvia de proyectiles: 39 s de arma (máx. 30).
- Bola de fuego: 4,5 s de arma (máx. 4), y su DPS en grupo pasa del 80 % del del bastón.
- Equipo de 4 sobre un jefe: 42 % (máx. 30 %).
- El médico cura 34,4/s al equipo (máx. 8 por aliado).
- Enlazar combos da +37 % (guerrero) y +36 % (cazador) (máx. 35 %).
- Tres alertas de duelos de la arena. No aplican, porque en la arena no cuentan los talentos.

Hallazgos pendientes de `equilibrio.md` §5 en ese momento: 1 a 11 (el 1 es el control sin
rendimientos decrecientes, que resuelve el grupo C6).

## 8. Telemetría

Eventos que se cuentan antes (`TelemetryService`): `AbilityUses`, `AbilityLinked`,
`ComboCompleted`, `ComboBestStreak`, `DamageBySource`, `HealingBySource`, `TimeHeld`,
`MinutesPlayed`, `PlayerDowned` y `BossDefeated`. Ninguno de guardia, parry, Evasivo, amagos, cadena
ni rebotes. Sin datos reales aún: el juego no está publicado.
