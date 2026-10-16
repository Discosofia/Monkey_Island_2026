# Primal Banana Islands: Monkey Survival 🍌🐒🏝️

Juego de supervivencia **PvE + PvP opt-in** para **Roblox** (móvil + PC), para hasta **20 jugadores** por servidor.

Naufragas en una isla tropical sin salida, antiguo santuario-laboratorio del **Proyecto PRIMAL**, infestada de monos carnívoros de distintas especies y categorías. Desde el **Basecamp** del centro de la isla los jugadores salen a explorar y recolectar, craftean y construyen, resisten los asedios nocturnos, rescatan huevos que se convierten en mascotas y derrotan a los jefes de cada bioma para encender la **baliza de rescate**.

## Documentación

- 📘 [Documento de Diseño (GDD)](docs/GDD.md): visión, mecánicas, bestiario, diagramas y decisiones.
- 🗺️ [Plan de trabajo por fases](docs/PLAN.md): fases, tareas, arquitectura técnica y cronograma.
- 🛠️ [Guía de instalación (SETUP)](docs/SETUP.md): cómo preparar Studio, Rojo y VS Code paso a paso.
- 🏝️ [Guía del mapa](docs/MAPA.md): qué piezas y atributos necesita la isla para conectarse con el código.
- 📱 [Rendimiento y móvil](docs/RENDIMIENTO.md): StreamingEnabled y pruebas con muchos jugadores.
- 🚀 [Lanzamiento](docs/LANZAMIENTO.md): música, pases cosméticos, página del juego, beta y lanzamiento.

## Estado

Fases 0 y 1 probadas. **Fases 2 a 6 programadas** (supervivencia y Basecamp, Lobby y roles, bestiario, jefes/huevo/mascotas/PvP, rescate y lanzamiento), pendientes de verificar en Studio. Ver el [plan](docs/PLAN.md).

## Comandos rápidos

```bash
rokit install                      # instala Rojo, StyLua y Selene
rojo serve lobby.project.json      # sincroniza el Lobby con Studio (puerto 34872)
rojo serve island.project.json     # sincroniza la Isla con Studio (puerto 34873)
stylua src                         # formatea el código
selene src                         # revisa el código
```
