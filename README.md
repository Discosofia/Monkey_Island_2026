# Primal Banana Islands: Monkey Survival 🍌🐒🏝️

Juego de supervivencia y combate para **Roblox** (móvil + PC), para jugar con **tus amigos**. Es una sola experiencia con cuatro places que comparten código y perfil:

- **Lobby** (Islas de plátano primitivas): la plaza desde donde eliges modo, equipas a tu mono y revisas el pase, los huevos y las misiones.
- **Isla**: supervivencia PvE para hasta **5** amigos, con Basecamp, bestiario, jefes y monturas.
- **Isla de Dunas**: arena PvP de captura la bandera.
- **Laboratorio en ruinas**: shooter por equipos, sin roles.

Naufragas en una isla tropical sin salida, antiguo santuario-laboratorio del **Proyecto PRIMAL**, infestada de monos carnívoros de distintas especies y categorías. Desde el **Basecamp** del centro de la isla los jugadores salen a explorar y recolectar, craftean y construyen, resisten los asedios nocturnos, rescatan huevos que se convierten en mascotas y derrotan a los jefes de cada bioma para encender la **baliza de rescate**.

## Documentación

- 📘 [Documento de Diseño (GDD)](docs/GDD.md): visión, mecánicas, bestiario, diagramas y decisiones.
- 🗺️ [Plan de trabajo por fases](docs/PLAN.md): fases, tareas, handoffs y cronograma.
- ✅ [Verificación](docs/VERIFICACION.md): pruebas pendientes en Studio, con dos jugadores y en el juego publicado.
- 🛠️ [Guía de instalación (SETUP)](docs/SETUP.md): cómo preparar Studio, Rojo y VS Code paso a paso.
- 🏝️ [Guía del mapa](docs/MAPA.md): qué piezas y atributos necesita la isla para conectarse con el código.
- 🔥 [Laboratorio en ruinas](docs/LABORATORIO.md): diseño del cuarto place, su shooter y sus armas.
- 🧭 [Isla Calavera](docs/AVENTURAS.md): diseño de la mazmorra PvE de 1 a 5 jugadores.
- 🎬 [Animaciones](docs/ANIMACIONES.md): poses, clips y cómo se publican.
- 📱 [Rendimiento y móvil](docs/RENDIMIENTO.md): StreamingEnabled y pruebas con muchos jugadores.
- 🚀 [Lanzamiento](docs/LANZAMIENTO.md): música, pases cosméticos, página del juego, beta y lanzamiento.

## Estado

Fases 0 a 13, 15, 17 y 18 cerradas. La 16 (presupuesto de piezas) y la 19 (combate a distancia, grupo W11) están en curso. La 14 (Isla Calavera) sigue pendiente. Los 4 places están publicados, con textos en español, inglés, francés, portugués y alemán; la Temporada 1 es la de los pioneros.

El detalle de cada fase, sus handoffs y el siguiente número libre de verificación está en [PLAN.md](docs/PLAN.md).

## Comandos rápidos

```bash
rokit install                                                # Rojo 7.7.1, StyLua 2.3.1 y Selene 0.30.0
rojo serve lobby.project.json                                # Lobby: sincroniza con Studio (puerto 34872)
rojo serve island.project.json                               # Isla (puerto 34873)
rojo serve dunas.project.json                                # Isla de Dunas (puerto 34874)
rojo serve laboratorio.project.json                          # Laboratorio en ruinas (puerto 34875)
stylua src                                                   # formatea el código (tabs, 120 columnas)
selene src                                                   # lint
python tools/strings.py                                      # avisa de las frases sin traducir al inglés
rojo build island.project.json --output build/island.rbxl    # build de un place
```

El CI (`.github/workflows/ci.yml`) ejecuta en cada push `stylua --check`, `selene`, `tools/strings.py`, `tools/icons.py` y `rojo build` de los cuatro places.
