# Rendimiento y pruebas en móvil (Fase 4)

El objetivo de la Fase 4 es un servidor de **20 jugadores estable en móvil**. El código ya incluye:

- **Tropas solo cerca de los jugadores:** una tropa lejos de todos se guarda como un número (sus monos no existen) y aparece cuando alguien se acerca a menos de `Config.Monkeys.WakeDistance` (350 studs); se vuelve a guardar sin nadie a menos de `DormantDistance` (450). Así hay monos por toda la isla sin que existan todos a la vez.
- **Monos que duermen:** sin jugadores a menos de `Config.Monkeys.SleepDistance` (300 studs), un mono no piensa.
- **Límite de monos activos:** como mucho `Config.Monkeys.MaxActive` (200) a la vez, contando solo los que existen (cerca de algún jugador); si se llega, aparecen primero las tropas más cercanas a un jugador. Los del asedio nocturno no cuentan para el límite.
- **IA cada 0,25 s**, no en cada fotograma (`Config.Monkeys.ThinkIntervalSeconds`).
- **Registro de rendimiento:** cada 2 minutos la Salida del servidor muestra jugadores, enemigos, piezas construidas y FPS del servidor (`[Rendimiento] …`).

### Cuántos monos aguanta (medido en Studio, PC, 18-10-2026)

Todos persiguiendo al jugador y amontonados a su alrededor (el peor caso):

| Monos | Física del servidor | Peor fotograma del servidor | FPS del cliente |
|---|---|---|---|
| 220 dormidos (antes, por toda la isla) | 3,0 ms | — | — |
| 50 | 2,1 ms | 20 ms | 60 |
| 75 | 3,4 ms | 21 ms | 60 |
| 100 | 4,0 ms | 21 ms | 39 |
| 200 | 9,3 ms | 35 ms | 15 |

- Lo que limita es el cliente: con más de ~75 monos **moviéndose** alrededor de un jugador baja de 60 FPS (en un móvil de gama baja, antes). Monos tranquilos cuestan poco: 125 cargados y quietos alrededor del Basecamp iban a 60 FPS.
- Un mono que existe aunque nadie lo vea cuesta ~14 µs de física por fotograma; persiguiendo, ~45 µs. Uno guardado, nada.
- Con las tropas solo cerca de los jugadores y repartidas por superficie, cada jugador tiene entre ~40 y ~110 monos a menos de 350 studs según la zona. En el punto más denso (92 monos, atacando al jugador): cliente a 60 FPS y 1,8 ms de física en el servidor.
- Si en móvil va justo: baja `WakeDistance` (300 = la distancia a la que piensan) o el tamaño de las tropas más numerosas (titís, monos ardilla). Si hay zonas vacías: sube `groups` de esa especie en `Data/Monkeys`, que ya no cuesta nada mientras no haya nadie cerca.

## Paso 1: activar StreamingEnabled (tú, una vez)

Con *streaming*, cada móvil solo carga la parte de la isla que tiene cerca. Es lo que más ayuda en móviles de gama baja.

1. Abre el place **Isla** en Studio.
2. En el **Explorador**, selecciona **Workspace**.
3. En **Propiedades**, busca **StreamingEnabled** y márcalo.
4. Deja **StreamingTargetRadius** en 1024 y **StreamingMinRadius** en 128 (o súbelo a 192 si en las pruebas aparecen "huecos" cerca del jugador).
5. **Archivo → Publicar en Roblox**.

El registro `[Rendimiento]` dice *"streaming activado"* cuando está bien.

**En el Lobby, al revés: StreamingEnabled desactivado.** Roblox lo activa de serie en los places nuevos, pero el Lobby es ligero y con *streaming* las islas del archipiélago que se ven en el horizonte (a 500-1.300 studs) no llegarían a los móviles. Abre el Lobby, desmarca **StreamingEnabled** en Workspace y publica. Si sigue activado, la Salida del servidor del Lobby lo avisa (`[LobbyWorldService]`).

## Paso 2: probar en móvil

En Studio, pestaña **Test → Device** (o el selector de dispositivo de la barra superior) para ver la interfaz en tamaños de móvil. Pero la prueba que cuenta es en un **móvil real** con el juego publicado:

| Qué mirar | Bien | Mal: qué ajustar |
|---|---|---|
| Fluidez caminando por la selva | Sin tirones | Baja `Config.Monkeys.MaxActive` o la densidad de árboles de `MapBuilder` |
| Noche de asedio con 3 oleadas | Sin tirones fuertes | Baja `Config.Siege.MaxWaveSize` |
| Botones táctiles | Se pueden pulsar sin tapar el juego | Avísame qué botón molesta |
| Memoria (F9 → Memory) | Por debajo de ~1,5 GB | Activa streaming (paso 1) |

## Paso 3: prueba con muchos jugadores

En Studio: **Test → Clients and Servers**, con 4–8 jugadores (cada uno consume mucha memoria del PC, no hace falta llegar a 20). Mira el registro `[Rendimiento]`: el servidor debería mantenerse cerca de 60 FPS.
