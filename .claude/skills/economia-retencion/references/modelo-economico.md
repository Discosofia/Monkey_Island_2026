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
| Contrato de expedición (G6) | `Config.Contracts.StepRewards`, `Data/Contracts`, `ContractService` | 20 · 20 · 25 · 25 · 50 por paso, a todos los de la partida (media por partida: casual 27, habitual 40, intenso 140) |
| Dunas | `Config.Arena.Amber`, `ArenaRewardService` | 60/30/20 (gana/empata/pierde), 15/captura, 2/baja (máx. 20), tope 400/día |
| Calendario de 7 días | `Config.Daily.Calendar`, `Retention.claimLogin` | 100 · — · — · 100 · 250 · — · 500 (+ huevo Raro+) |
| Misiones diarias | `Data/Missions`, `Config.Daily.MissionRewards`, `Retention` | fácil 40 · media (rol) 70 · difícil 120 (+15/25/40 min de huevo) |
| Misiones semanales | ídem | 150 cada una; 250 (+1 h de huevo) por cumplir las 5 |
| Descartar huevo | `Config.Egg.DiscardAmber` | 15/30/60/120/250 por rareza |
| Tiempo de huevo sin huevo en el nido | `Config.Daily.AmberPerUnusedEggHour` | 30/h |
| Pase de temporada, pista gratis (nivel ganado jugando) | `Data/Seasons`, `ServerShared/SeasonPass` | T1 provisional: 1.625 en 30 niveles (+ 7 h de huevo, provisiones y un huevo Raro en el N20); en bucle, 50 cada 3.000 XP |

| Sumidero de Ámbar | Dónde | Total |
|---|---|---|
| Mejoras permanentes | `Data/Upgrades`, `ProgressionService` | 19 rangos, **1.930** |
| Equipo de Dunas | `Data/ArenaGear`, `ArenaShop` | 200/150/100 por ranura (24 piezas) |
| Tienda de cosméticos en Ámbar (G10) | `Data/Cosmetics` (`source.amber`), `Shared/CosmeticShop`, `CosmeticShopService` | 4 al día de lo que aún no tienes; 400 común · 600 poco común · 900 raro · 1.200 épico · 1.500 legendario |

**XP del pase** (`Config.Season`, desde G3; G4 sube la de la Isla): 30 niveles × 1.000. Isla 60/día
sobrevivido, 150/jefe, 50/huevo salvado, 300 por rescate; Dunas 80/40/30 + 15/captura (las de prueba
no dan); tope de partidas 1.200/día (Isla y Dunas juntas); +10 % si hay un amigo de Roblox en el
servidor; misiones diarias fácil 200, media 200, difícil 300 y semanales 500 + 500 por las 5 (sin
tope); ×2 los últimos 7 días. Contratos de expedición (G6): 50 · 50 · 75 · 75 · 125 por paso, como XP
de partida (con el tope y el extra de amigos).

**Misiones v2** (G4): cada día una fácil (general, 3–15 min), una media (del rol, 15–35 min) y una
difícil (avanzar en la partida, 35–90 min); cada lunes 5 semanales de 13, sin dos de la misma
`family` (como mucho una de Dunas; rescate o llegar al día 6, una). Un cambio gratis al día en las
diarias y uno a la semana en las semanales. La calculadora simula las semanales con lo que hace cada
perfil en la semana (valor esperado de las 5 que tocan, con el cambio).

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
0,12 piezas construidas, 2,5 habilidades, 0,35 combos, 300 de daño, 0,03 huevos salvados, 0,04
alfas; especies distintas en una partida que llega al día d: 4 + 1,5 × (d − 1). Cuando haya
telemetría, cámbialos en la calculadora y apunta aquí de dónde salen.

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

**Con las misiones v2 (G4, 21-10-2026)**: diarias en sus rangos (fáciles 8–13 min, medias 17–20,
difíciles 50–67); el casual cumple el 67 % (las difíciles no le caben en 40 min). Semanales por
semana (con el cambio): casual 0,5 (nunca el extra), habitual 3,7 (45 % con el extra), intenso 5
(100 %), amigos 4,2 (80 %). Ámbar ganado en 30 días: casual 5.582, habitual 21.195 (gasta el 11 %),
intenso 52.743, amigos 23.425. Pase, nivel el día 7 · 14 · 21 · 30:

| Perfil | Nivel | Último nivel | Misiones (con semanales) |
|---|---|---|---|
| Casual | 2 · 4 · 7 · 12 | no | 59 % |
| Habitual | 9 · 18 · 27 · 30 | día 24 | 65 % |
| Intenso | 16 · 30 · 30 · 30 | día 13 | 50 % |
| Amigos | 10 · 20 · 30 · 30 | día 21 | 56 % |

**Con el equipo ligado a los jefes (G5, 21-10-2026)**: el nivel 2 de la forja sigue el día 1, el
nivel 3 (armas de rol y armadura de plata) el **día 4** (Corona del caudillo) y el nivel 4 de la forja
volcánica el **día 6** (obsidiana y Cristal de cueva). Cada jefe da 2 de su tesoro a cada participante;
la perla (día 2) y el núcleo de magma (día 8) siguen sin receta.

**Con los contratos de expedición (G6, 21-10-2026)**: 3 contratos (Campamento del náufrago, Diario del
naturalista, Ruta del volcán) de 5 pasos que se abren los días 1, 3, 5, 7 y 8 y se pierden al abrir el
siguiente. Jugando solo con los ritmos, pasos por partida: casual 1,3 · habitual 2 · intenso 5 · amigos
2,3. Pase, nivel el día 7 · 14 · 21 · 30: casual 2 · 5 · 7 · **13** (antes 12), habitual 9 · 19 · 29 · 30
(termina el **día 23**, antes 24; misiones 62 %), intenso día 13, amigos día 20. Ámbar del habitual en
30 días: 22.085 (gasta el 11 %).

**Con las tiendas de cosméticos (G10a, 21-10-2026)**: la calculadora compra, con las mejoras completas,
lo que puede pagar de la oferta de cada día (es optimista: un jugador de verdad no lo compra todo). Con
los 5 de prueba (3.200 Ámbar) el habitual pasa de gastar el 11 % al **25 %** y tiene la tienda entera el
día 9. Midiendo un catálogo de prueba: con 17 cosméticos (13.400 Ámbar) gasta el 71 % pero lo acaba el
día 23; con **23 (18.900)** gasta el 96 % y lo acaba el día 30; con 29, el 99 % y no lo acaba. El casual
compra 6–7 (gana poco). Meta de G10b: 20–24 cosméticos en Ámbar y unos 6 sueltos de Robux.

**Con el catálogo (G10b, 21-10-2026)**: tema "selva y mar" (no el volcán de la temporada). En Ámbar,
22 cosméticos que suman **19.000**: 6 títulos, 3 estelas, 3 auras, 3 marcos, 3 números, 2 estallidos,
1 nido y 1 skin de familia (Perro pirata, 1.500). En Robux, 11 sueltos: 6 nuevos de 99–249 R$ (título,
estallido, aura, marco, estela y nido), los Números Escarcha y las 4 armas míticas. Gastado en 30 días:
casual 5.730 de 6.002 (compra 6 de 22), habitual **21.380 de 22.085** (97 %, tiene la tienda entera el
**día 30**), intenso 21.380 (todo el día 12), amigos 21.380 (día 27). Sin alertas.

## 5. Hallazgos pendientes (plan de la Fase 9, `docs/PLAN.md`)

- El intenso y los grupos tienen la tienda en Ámbar entera antes del día 30 (días 12 y 27) y el intenso
  acumula 35.000 Ámbar sin uso: cada temporada tiene que traer cosméticos nuevos a la tienda (unos
  4.000–5.000 Ámbar al mes) o el Ámbar vuelve a sobrar al segundo mes.
- La Perla del río (día 2) y el Núcleo de magma (día 8) no los pide ninguna receta: candidatos para
  los eventos (G7) o un paso de contrato que pida entregarlos.
- Los pasos 3–5 de los contratos (días 5–8) solo los ve quien juega partidas largas (intenso, grupos):
  es lo buscado (metas para la mitad de la partida), pero si la telemetría dice que casi nadie pasa
  del día 4, son los que hay que mirar.
- El intenso descarta muchos huevos (bolsa de 3 llena): vigilar al cambiar ritmos o premios de huevo.
- El casual llega justo al nivel 12 del pase (el mínimo) y casi no cumple semanales (0,5 por semana
  con 2 h de juego): si se suben objetivos semanales o se baja la XP, mira primero su fila.
- El intenso tira 15.000 XP sobre el tope de partidas en el mes: el tope hace su trabajo (no termina
  antes del día 13), pero si se baja la XP de misiones terminaría antes.

## 6. Dónde se enganchan los eventos de misión

`Retention.progress(player, evento, n, clave?)`: Kill, Species (clave: la especie) y Alpha
(`MonkeyService.onKilled`), Damage, Night y ReachDay (el día al que llega quien estaba al empezar la
noche), Boss (`BossService.onDefeated`) y Rescue (victoria que no sea de prueba) en `MissionService`;
Gather (`ResourceService`), Craft (`CraftingService`), Build (`BuildingService`), Egg (`EggService`),
Ability y Combo (`IslandCombatRules`); ArenaWin y ArenaCapture (`ArenaRewardService`, Dunas, salvo
las de prueba); Supply (`SupplyService`, abrir una caja) y Beacon (`BeaconService`, encender la
baliza) solo los usan los contratos. Llevan clave para los contratos: Gather (el recurso), Build (la
pieza) y Boss (el jefe). `Retention.onProgress` reparte cada aviso a `ContractService`, que además
cuenta "Visit" (llegar a una guarida). Al terminar una partida se apunta ya (`Retention.flushNow`): luego viene el
teletransporte. Los muñecos del Lobby no cuentan. Reanimar y "jugar con amigos" no son misiones (no
se pueden hacer solo).

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
