# Rendimiento y pruebas en móvil (Fase 4)

El objetivo de la Fase 4 es un servidor de **20 jugadores estable en móvil**. El código ya incluye:

- **Monos que duermen:** sin jugadores a menos de `Config.Monkeys.SleepDistance` (300 studs), un mono no piensa.
- **Límite de monos activos:** como mucho `Config.Monkeys.MaxActive` (160) a la vez. Los del asedio nocturno no cuentan para el límite.
- **IA cada 0,25 s**, no en cada fotograma (`Config.Monkeys.ThinkIntervalSeconds`).
- **Registro de rendimiento:** cada 2 minutos la Salida del servidor muestra jugadores, enemigos, piezas construidas y FPS del servidor (`[Rendimiento] …`).

## Paso 1: activar StreamingEnabled (tú, una vez)

Con *streaming*, cada móvil solo carga la parte de la isla que tiene cerca. Es lo que más ayuda en móviles de gama baja.

1. Abre el place **Isla** en Studio.
2. En el **Explorador**, selecciona **Workspace**.
3. En **Propiedades**, busca **StreamingEnabled** y márcalo.
4. Deja **StreamingTargetRadius** en 1024 y **StreamingMinRadius** en 128 (o súbelo a 192 si en las pruebas aparecen "huecos" cerca del jugador).
5. **Archivo → Publicar en Roblox**.

El registro `[Rendimiento]` dice *"streaming activado"* cuando está bien.

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
