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

## 2. Fuentes y sumideros (octubre de 2026, Fase 9 cerrada)

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
| Pase de temporada, pista gratis (nivel ganado jugando) | `Data/Seasons`, `ServerShared/SeasonPass` | T1: 1.625 en 30 niveles (+ 7 h de huevo, provisiones, un huevo Raro en el N20 y 8 cosméticos); en bucle, 50 cada 3.000 XP |

| Sumidero de Ámbar | Dónde | Total |
|---|---|---|
| Mejoras permanentes | `Data/Upgrades`, `ProgressionService` | 19 rangos, **1.930** |
| Equipo de Dunas | `Data/ArenaGear`, `ArenaShop` | 200/150/100 por ranura (24 piezas) |
| Parcela permanente (Fase 12, P3; solo quien ha ganado) | `Data/PlotStructures`, `PlotService` (Isla) | 7 estructuras × 3 niveles: 600 · 2.400 · 6.000 cada una, 63.000 en total, más materiales de la Bolsa. **Precios de prueba**: los fija P6 con la sección "Parcela" de la calculadora |
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
0,12 piezas construidas, 2,5 habilidades, 0,35 combos, 300 de daño, 0,03 huevos salvados, 0,2
alfas; especies distintas en una partida que llega al día d: 4 + 1,5 × (d − 1). Cuando haya
telemetría, cámbialos en la calculadora y apunta aquí de dónde salen.

## 4. Línea base (22-10-2026, Fase 9 cerrada: Temporada 1 completa; 30 días)

Medida en el G12 con todo encendido (misiones v2, semanales, contratos, pase con sus 30 + 30 premios,
tiendas en Ámbar y Robux). Sin alertas.

| Perfil | Ámbar ganado (partidas · Dunas · calendario · misiones · descartes · pase) | Gastado | Sin usar | Mejoras completas | Cosméticos en Ámbar | Huevos eclosionados (descartados) | Diarias cumplidas | Semanales por semana (con el extra) |
|---|---|---|---|---|---|---|---|---|
| Casual | 6.002 (2.480 · 0 · 1.400 · 1.597 · 0 · 525) | 5.730 | 272 | día 12 | 6 de 22 | 11 (0) | 67 % | 0,5 (0 %) |
| Habitual | 22.085 (7.035 · 1.502 · 2.850 · 8.158 · 565 · 1.975) | 21.380 (97 %) | 705 | día 5 | 22, el día 30 | 20 (17) | 100 % | 3,7 (45 %) |
| Intenso | 56.943 (28.575 · 6.435 · 3.900 · 11.900 · 3.558 · 2.575) | 21.380 | 35.563 | día 1 | 22, el día 12 | 29 (107) | 100 % | 5 (100 %) |
| Amigos | 24.297 (8.812 · 2.431 · 2.000 · 8.048 · 931 · 2.075) | 21.380 | 2.917 | día 4 | 22, el día 27 | 16 (28) | 100 % | 4,2 (80 %) |

Pase (30 niveles × 1.000 XP; gratis: 1.625 Ámbar, 7 h de huevo, 8 cosméticos; premium: 30 cosméticos):

| Perfil | Nivel el día 7 · 14 · 21 · 30 | Último nivel | XP: Isla · Dunas · misiones · semanales · amigos · ×2 | Misiones (con semanales) | XP sobre el tope |
|---|---|---|---|---|---|
| Casual | 2 · 5 · 7 · 13 | no | 4.760 · 0 · 4.800 · 923 · 0 · 2.621 | 55 % | 0 |
| Habitual | 9 · 19 · 29 · 30 | día 23 | 14.070 · 1.596 · 14.700 · 10.343 · 0 · 9.758 | 62 % | 0 |
| Intenso | 16 · 30 · 30 · 30 | día 13 | 32.069 · 3.931 · 21.000 · 15.000 · 0 · 16.300 | 50 % | 26.640 |
| Amigos | 10 · 21 · 30 · 30 | día 20 | 17.170 · 2.584 · 11.900 · 12.462 · 1.975 · 10.913 | 53 % | 0 |

Mascotas repetidas (T3, 26-10-2026): se tiene una de cada y una repetida da `Config.Egg.DuplicateAmber`
(el doble del descarte). La calculadora las cuenta en la fuente "repetidas" (valor esperado según las
que ya tiene de cada rareza). En 30 días: casual 3,7 repetidas (+188), habitual 10,9 (+506), intenso
18,4 (+880). Es un +2–3 % de Ámbar: el casual compra un cosmético más en Ámbar y nada más cambia. Los
regalos (`Config.Shop.GiftProducts`, 5 productos por precio) salen en "Reglas de pago" como cosméticos.

Tirada de pioneros (T6, 27-10-2026):
- **Qué es:** al cobrar el día 7 del calendario, quien entró antes del fin de la T1 tiene una tirada de montura, `Config.Pioneer.Weights` Llama 75 · Jaguar 18 · Quetzalcóatl 7. No evita las repetidas, que dan `DuplicateAmber` (Mythic 1000).
- **Ritmo:** con la §5b de la calculadora (límite `pionerosTodasDiario`), las 3 se tienen al 50 % en 12 ciclos. Son el día 84 a diario, el 118 el habitual y el 196 el casual. El Quetzalcóatl solo, al 50 % en 10 ciclos.
- **Ámbar:** las repetidas dan unos 250 por ciclo a la larga, alrededor del 5 % de lo que gana el habitual. No entra en la simulación de perfiles de la §2 (que dura 30 días).
- **Lo que no cuenta:** la §5b solo mide la tirada. Los huevos también dan la Llama y el Jaguar.

Misiones diarias: fáciles 8–13 min, medias 17–20, difíciles 50–67. Partida: nivel 2 de la forja el
día 1, nivel 3 el día 4 (Corona del caudillo), nivel 4 el día 6 (obsidiana y Cristal de cueva).
Contratos, pasos por partida jugando solo: casual 1,3 · habitual 2 · intenso 5 · amigos 2,3. Reglas de
pago: 18 productos de Robux (3 del pase, 11 sueltos, 4 Game Passes), todos cosméticos o el pase; 14
siguen sin id ("Próximamente") hasta que se creen en el Creator Hub.

Monturas (Fase 11, M2, `Config.Mounts.EggChance` 0,5: la mitad de los huevos Raros dan la Llama Andina
mientras no la tienes). Probabilidad de tenerla el día 30 (día en que pasa del 50 %): casual 66 % (21) ·
habitual 74 % (17) · intenso 86 % (12) · amigos 66 % (21). Límite `monturaHabitualDia` 12–30.

**Robustez (G12)**, cambiando una cosa cada vez:

| Prueba | Qué salta |
|---|---|
| Ritmos ×0,7 (todo un 30 % más lento) | La diaria fácil de fabricar pide 19 min (rango 3–15) y la de huevos 95 (35–90); el paso 1 del Campamento sale en el minuto 36 y se cierra en el 34; los pasos 3–4 de Campamento y Naturalista no caben solo; el casual llega al nivel 11 del pase (mínimo 12) |
| Habitual de 4 días y 45 min | No termina el pase (nivel 26) |
| Casual de 2 días y 30 min | Nivel 7 del pase |

Con los ritmos supuestos todo cabe con poca holgura en el casual y en los primeros pasos de los
contratos: es lo primero que hay que mirar cuando haya telemetría.

**Cómo se llegó aquí** (Fase 9, 20–22 de octubre de 2026):

| Momento | Habitual: Ámbar gastado | Habitual: pase | Casual: pase | Equipo de nivel 3 |
|---|---|---|---|---|
| Antes del pase (línea base del G1) | 15 % (2.380 de 15.698) | — | — | día 1 |
| G3: pase sin semanales | 14 % | nivel 24, no lo termina | nivel 10 | día 1 |
| G4: misiones v2 y semanales (XP de la Isla 60/día, 150/jefe; diaria fácil 200) | 11 % | día 24 | nivel 12 | día 1 |
| G5: equipo ligado a los jefes | 11 % | día 24 | nivel 12 | **día 4** |
| G6: contratos | 11 % | **día 23** | **nivel 13** | día 4 |
| G10a/G10b: tiendas de cosméticos (22 en Ámbar, 19.000) | **97 %** | día 23 | nivel 13 | día 4 |
| G11/G12: Temporada 1 completa | 97 % | día 23 | nivel 13 | día 4 |

## 5. Hallazgos pendientes (plan de la Fase 9, `docs/PLAN.md`)

- El intenso y los grupos tienen la tienda en Ámbar entera antes del día 30 (días 12 y 27) y el intenso
  acumula 35.000 Ámbar sin uso: cada temporada tiene que traer cosméticos nuevos a la tienda (unos
  4.000–5.000 Ámbar al mes) o el Ámbar vuelve a sobrar al segundo mes.
- El Núcleo de magma (jefe del día 8) no lo pide ninguna receta (la Perla del río ya la pide el tótem
  guardián, G8): candidato para un paso de contrato o un construible de la próxima temporada.
- Los pasos 3–5 de los contratos (días 5–8) solo los ve quien juega partidas largas (intenso, grupos):
  es lo buscado (metas para la mitad de la partida), pero si la telemetría dice que casi nadie pasa
  del día 4, son los que hay que mirar.
- El intenso descarta muchos huevos (bolsa de 3 llena): vigilar al cambiar ritmos o premios de huevo.
- El casual llega justo al nivel 13 del pase (mínimo 12) y casi no cumple semanales (0,5 por semana
  con 2 h de juego); con ritmos un 30 % más lentos se queda en el 11. Si se suben objetivos semanales,
  se baja la XP o la telemetría da ritmos más lentos, mira primero su fila.
- Con ritmos un 30 % más lentos, la diaria fácil de fabricar (2 objetos) se sale de su rango y el paso 1
  del Campamento del náufrago (3 piezas) no cabe en los días 1–2 jugando solo: candidatos a bajar
  (1 objeto más fácil, 2 piezas) si los datos lo confirman.
- El intenso tira 26.000 XP sobre el tope de partidas en el mes: el tope hace su trabajo (no termina
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
