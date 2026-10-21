# Modelo económico y de retención

## 1. Principios (no se negocian)

1. **Nada de pago da poder.** Con Robux solo se compran cosméticos (estelas, auras, títulos, trajes,
   skins de arma y de mascota, emotes, marcos) y el pase de temporada (premium y niveles). El Ámbar
   compra mejoras con ventaja (vida, estamina…), así que **nunca** se vende ni sale de algo pagado.
2. **Huevos y tiempo de incubación nunca se venden** (GDD §14, `docs/LANZAMIENTO.md`). Los premios
   no cosméticos del pase (Ámbar, tiempo de huevo, provisiones, huevos) solo se desbloquean con el
   nivel **ganado jugando**, nunca con niveles comprados.
3. **Nada aleatorio de pago.** Si algún día se vende algo aleatorio: probabilidades a la vista antes
   de pagar y `PolicyService.ArePaidRandomItemsRestricted` (ver `politicas-roblox.md`).
4. **El título "Superviviente de la Isla" solo lo tiene quien gana** (rescate); ningún calendario,
   pase ni tienda lo da.
5. **Faltar no castiga**: el calendario se pausa (no se reinicia), el pase se completa con holgura
   (~20–24 días activos de 30) y lo no reclamado al cerrar una temporada se entrega solo.
6. **Retención antes que ingreso**: un muro de progreso para vender rompe el D1/D7 y el valor a
   largo plazo. El precio se justifica con lo que se recibe (intercambio justo).
7. **Se juega en grupos de amigos** (partida de hasta 5): lo social es lo que retiene al jugador que
   ya lo tiene todo; premiar jugar juntos, nunca obligar a jugar con desconocidos.

## 2. Fuentes y sumideros (octubre de 2026)

| Fuente de Ámbar | Dónde | Números |
|---|---|---|
| Final de partida en la Isla | `Config.Match`, `MatchService.summaryFor`, `DataService` | 10/día sobrevivido, 2/mono, 5/reanimación, 50/jefe, 15/recompensa PvP, 25/huevo, 200 por rescate |
| Dunas | `Config.Arena.Amber`, `ArenaRewardService` | 60/30/20 (gana/empata/pierde), 15/captura, 2/baja (máx. 20), tope 400/día |
| Calendario de 7 días | `Config.Daily.Calendar`, `Retention.claimLogin` | 100 · — · — · 100 · 250 · — · 500 (+ huevo Raro+) |
| Misiones diarias | `Data/Missions`, `Retention` | 60 la general, 100 la de rol (+20/30 min de huevo) |
| Descartar huevo | `Config.Egg.DiscardAmber` | 15/30/60/120/250 por rareza |
| Tiempo de huevo sin huevo en el nido | `Config.Daily.AmberPerUnusedEggHour` | 30/h |
| Pase de temporada, pista gratis (nivel ganado jugando) | `Data/Seasons`, `ServerShared/SeasonPass` | T1 provisional: 1.625 en 30 niveles (+ 7 h de huevo, provisiones y un huevo Raro en el N20); en bucle, 50 cada 3.000 XP |

| Sumidero de Ámbar | Dónde | Total |
|---|---|---|
| Mejoras permanentes | `Data/Upgrades`, `ProgressionService` | 19 rangos, **1.930** |
| Equipo de Dunas | `Data/ArenaGear`, `ArenaShop` | 200/150/100 por ranura (24 piezas) |

**XP del pase** (`Config.Season`, desde G3): 30 niveles × 1.000. Isla 30/día sobrevivido, 100/jefe,
50/huevo salvado, 300 por rescate; Dunas 80/40/30 + 15/captura (las de prueba no dan); tope de
partidas 1.200/día (Isla y Dunas juntas); +10 % si hay un amigo de Roblox en el servidor; misiones
diarias 150 la general y 200 la de rol (sin tope); ×2 los últimos 7 días. Las semanales (G4) aún no
existen: la calculadora las simula con `OPCIONES.pase.xpSemanalSupuesta`.

Otras progresiones: XP de rol (20/día sobrevivido, 2/mono; nivel = 1 + XP/100; talentos llenos con
14–15 puntos), huevos (8–24 h en el nido, 1 h menos por día sobrevivido, tope del 50 % de lo ganado
jugando), mascotas (13), bestiario, ranking (días, rescates, victorias y capturas de Dunas).

## 3. Perfiles de jugador (calculadora, `OPCIONES.perfiles`)

| Perfil | Días/semana | Min. en la Isla | Dunas/día | Gana | Con amigos |
|---|---|---|---|---|---|
| Casual | 3 | 40 | 0 | — | no |
| Habitual | 5 | 60 | 1 | — | no |
| Intenso | 7 | 150 | 3 | 60 % | no |
| Grupo de amigos | 4 | 90 | 2 | 30 % | sí |

Cada día de juego es una partida nueva desde el día 1 (un día de partida = 17 min). Los **ritmos**
(lo que se hace por minuto en la Isla) son supuestos: 1 mono, 5 recursos, 0,15 objetos fabricados,
0,12 piezas construidas, 2,5 habilidades, 0,35 combos, 300 de daño, 0,03 huevos salvados. Cuando
haya telemetría, cámbialos en la calculadora y apunta aquí de dónde salen.

## 4. Línea base (20-10-2026, antes del pase; 30 días)

| Perfil | Ámbar ganado | Gastado | Sin usar | Mejoras completas | Huevos eclosionados (descartados) | Misiones cumplidas | Talentos llenos |
|---|---|---|---|---|---|---|---|
| Casual | 6.200 | 1.930 | 4.270 | día 12 | 11 (0) | 100 % | no |
| Habitual | 15.698 | 2.380 | 13.318 | día 6 | 20 (16) | 100 % | día 12 |
| Intenso | 44.834 | 2.380 | 42.454 | día 2 | 29 (106) | 100 % | día 4 |
| Amigos | 17.059 | 2.380 | 14.679 | día 6 | 16 (27) | 100 % | día 11 |

Con el pase (G3, sin semanales): el Ámbar del habitual pasa de 15.698 a 16.657 (925 del pase) y
sigue gastando el 14 %. Nivel del pase el día 7 · 14 · 21 · 30:

| Perfil | Sin semanales | Último nivel | Con 4.200 XP/semana supuestas | Último nivel | Misiones (con semanales) |
|---|---|---|---|---|---|
| Casual | 2 · 4 · 6 · 10 | no | 6 · 12 · 19 · 30 | día 26 | 90 % |
| Habitual | 4 · 9 · 14 · 24 | no | 8 · 17 · 26 · 30 | día 23 | 77 % |
| Intenso | 11 · 23 · 30 · 30 | día 18 | 16 · 30 · 30 · 30 | día 13 | 50 % |
| Amigos | 5 · 10 · 15 · 27 | no | 9 · 18 · 28 · 30 | día 23 | 68 % |

Misiones: la más larga pide 33 min (salvar un huevo); las de rol, 4–11 min. Todo el equipo de la
forja (nivel 3 de armas y armadura) se puede tener el **día 1** de la partida, y el botín de los
4 jefes no lo pide ninguna receta.

## 5. Hallazgos pendientes (plan de la Fase 9, `docs/PLAN.md`)

- Las 3 diarias se cumplen en la primera hora de una partida (todas al 100 %): misiones v2 con
  dificultad, semanales y contratos de partida (G4, G6).
- El habitual gasta el 15 % del Ámbar que gana; tras el día 6 no tiene en qué gastarlo: tienda de
  cosméticos en Ámbar (G10).
- Equipo al máximo el día 1–3: el nivel 3 pedirá el botín del jefe del día 4 y habrá un nivel 4 en la
  Forja volcánica con el del día 6 (G5). Los tesoros de jefe ya se dan a cada participante
  (`BossService`), separados de la pieza de la baliza.
- El intenso descarta muchos huevos (bolsa de 3 llena): vigilar al cambiar ritmos o premios de huevo.
- El rastreador de misiones de la Isla no se ve en móvil (G4).
- Pase sin semanales: el habitual no lo termina (nivel 24) y el casual llega al 10. Con 4.200 XP de
  semanales por semana se cumplen las metas, pero las misiones pasan a dar el 77 % de la XP del
  habitual (meta ≤ 70 %): en G4, semanales algo más bajas (~3.000) o más XP de partida.

## 6. Dónde se enganchan los eventos de misión

`Retention.progress(player, evento, n)`: Kill y Damage y Night (`MissionService`), Gather
(`ResourceService`), Craft (`CraftingService`), Build (`BuildingService`), Egg (`EggService`),
Ability y Combo (`IslandCombatRules`). Las misiones solo cuentan en la Isla (no los muñecos del Lobby
ni Dunas, hasta G4).

XP del pase: `SeasonPass.addXp(player, "Match", n)` en `MatchService.summaryFor` (Isla) y
`ArenaRewardService` (Dunas); las misiones la dan con `reward.xp` por `Retention.grant` (que llama a
`ServerShared/SeasonPass` con `setXpHandler`).

## 7. Telemetría y métricas

- `Analytics.amber(player, "Source"|"Sink", cantidad, saldo, motivo)` registra cada movimiento de
  Ámbar; `LoginCalendarDay` el día del calendario.
- En el Creator Dashboard: D1/D7/D30, sesiones por usuario, ingreso por usuario que paga, y los
  embudos que se añadan (niveles del pase, compras).
- Creator Rewards paga por los usuarios que gastan y juegan ≥ 10 min al día entre sus 3 primeras
  experiencias: una diaria fácil debe caber en ~15 min.

## Fuentes

- Roblox Creator Hub, "Season pass design" (create.roblox.com/docs/production/game-design/season-pass-design).
- Roblox Creator Hub, "Paid random items" (create.roblox.com/docs/production/monetization/paid-random-items).
- Roblox Creator Hub, "Creator Rewards" (create.roblox.com/docs/creator-rewards).
- `docs/Sistema de recompensas y retencion.txt` (investigación del usuario: retención por etapa,
  recompensas diarias, pases y tipología de recompensas) y `docs/battle_pass_30_days.pdf`.
