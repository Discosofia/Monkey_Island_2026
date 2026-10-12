# Primal Banana Island: Monkey Survival 🍌🐒🏝️

Juego de supervivencia **PvE + PvP opt-in** para **Roblox** (móvil + PC), para hasta **20 jugadores** por servidor.

Naufragas en una isla tropical sin salida, antiguo santuario-laboratorio del **Proyecto PRIMAL**, infestada de monos carnívoros de distintas especies y categorías. Desde el **Basecamp** del centro de la isla los jugadores salen a explorar y recolectar, craftean y construyen, resisten los asedios nocturnos, rescatan huevos que se convierten en mascotas y derrotan a los jefes de cada bioma para encender la **baliza de rescate**.

## Documentación

- 📘 [Documento de Diseño (GDD)](docs/GDD.md): visión, mecánicas, bestiario, diagramas y decisiones.
- 🗺️ [Plan de trabajo por fases](docs/PLAN.md): fases, tareas, arquitectura técnica y cronograma.
- 🛠️ [Guía de instalación (SETUP)](docs/SETUP.md): cómo preparar Studio, Rojo y VS Code paso a paso.

## Estado

**Fase 1, Bucle núcleo:** la entrega 1.1 (ciclo día/noche + Basecamp) está lista para probar. Ver el [plan](docs/PLAN.md#fase-1-prototipo-del-bucle-núcleo-sobrevivir-el-día-1-46-semanas).

## Comandos rápidos

```bash
rokit install                      # instala Rojo, StyLua y Selene
rojo serve lobby.project.json      # sincroniza el Lobby con Studio (puerto 34872)
rojo serve island.project.json     # sincroniza la Isla con Studio (puerto 34873)
stylua src                         # formatea el código
selene src                         # revisa el código
```
