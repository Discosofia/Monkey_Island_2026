# Primal Banana Islands: plan de trabajo por fases

> Basado en el [GDD v0.2](GDD.md).
> **Contexto:** una sola persona con experiencia básica en Studio y **5–15 h/semana**. Claude escribe el código en el repo.
> **Principio:** cada fase termina con **algo jugable** y se prueba con gente real antes de pasar a la siguiente.

---

## 1. Cómo trabajamos

```mermaid
flowchart LR
  A["Issue en GitHub: una tarea concreta"] --> B["Claude programa en una rama"]
  B --> C["Pull Request + CI de formato y lint"]
  C --> D["Tú: rojo serve y pruebas en Studio"]
  D -->|"Funciona"| E["Merge a main"]
  D -->|"Bug o ajuste"| B
  E --> F["Publicar en Roblox"]
```

### Reparto de responsabilidades

| Claude (en el repo) | Tú (en Roblox Studio y la web de Roblox) |
|---|---|
| Todo el código Luau (servidor, cliente, UI) | Instalar herramientas y conectar Rojo |
| Datos de balance (especies, botín, recetas) | Esculpir el terreno y montar el mapa |
| Configuración de herramientas y CI | Colocar modelos del Creator Store |
| Documentación y guías paso a paso | Subir animaciones, sonidos e imágenes a tu cuenta |
| Revisar bugs a partir de tus reportes | **Probar** y decidir qué es divertido |
| | Publicar, y crear gamepasses y productos |

> **Código en Git, mapa en Roblox.** Los scripts viven en el repo y se sincronizan con Rojo. El terreno y el mapa viven en el archivo del *place* (con historial de versiones de Roblox). Los modelos clave se exportan de vez en cuando a `assets/` como `.rbxm`.

---

## 2. Stack técnico

| Herramienta | Para qué |
|---|---|
| **Roblox Studio** | Editor del juego, mapa y pruebas |
| **VS Code + Luau LSP** | Editar código con autocompletado |
| **Rojo** | Sincroniza el código del repo con Studio |
| **Rokit** | Instala versiones fijas de las herramientas (`rokit.toml`) |
| **Wally** | Gestor de paquetes de Roblox (se añade en la Fase 2, con ProfileStore) |
| **StyLua / Selene** | Formato automático y detección de errores (en CI) |
| **ProfileStore** | Guardado seguro de datos del jugador (moneda, XP, mascotas) |
| **GitHub Actions** | Comprueba formato y lint en cada Pull Request |

**Decisiones de arquitectura:**

- **Una experiencia con 2 places:** `Lobby` (inicio) e `Isla` (partida, máximo 20).
- **Servidor autoritativo:** el cliente solo pide ("quiero atacar"); el servidor valida y aplica.
- **Sin frameworks pesados.** Usamos un patrón simple de *Services* (servidor) y *Controllers* (cliente) con `Init` y `Start`.
- **Basado en datos:** especies, recetas, botín y tiempos están en módulos de `Config`. Para balancear basta con cambiar números.
- **Red centralizada:** un único módulo `Remotes` define todos los eventos cliente-servidor.

### Arquitectura

```mermaid
flowchart LR
  subgraph Exp["Experiencia Roblox"]
    subgraph Lobby["Place: Lobby"]
      LS["Servidor: Perfil, Tienda, Roles, Matchmaking"]
      LC["Cliente: UI del lobby, selección de rol"]
    end
    subgraph Isla["Place: Isla (máx. 20)"]
      IS["Servidor: Partida, Día/Noche, IA de monos, Combate, Botín, Crafteo, Construcción, Huevo, PvP"]
      IC["Cliente: HUD, inventario, cámara, controles táctiles"]
    end
  end
  DS[("DataStore vía ProfileStore")]
  MS[("MemoryStore: partidas abiertas")]
  LC <--> LS
  IC <--> IS
  LS -->|"TeleportService"| IS
  IS -->|"Fin de partida"| LS
  LS <--> DS
  IS <--> DS
  LS <--> MS
  IS <--> MS
```

### Estructura del repositorio

```
monkey_island_2026/
├─ docs/                      # GDD, plan y guía de instalación (SETUP.md)
├─ src/
│  ├─ shared/                 # → ReplicatedStorage.Shared (cliente y servidor)
│  │  ├─ Config.luau          #   Configuración central y balance
│  │  ├─ Remotes.luau         #   Todos los eventos de red
│  │  ├─ Loader.luau          #   Carga Services/Controllers (Init → Start)
│  │  └─ UI/                  #   Piezas de interfaz (botones, mensajes)
│  ├─ serverShared/           # → ServerScriptService.ServerShared (solo servidor, ambos places)
│  ├─ combat/                 # → ServerScriptService.Combat: armas, habilidades, combos y estados,
│  │                          #   compartidos por la Isla y la arena; CombatRules = reglas de cada place
│  ├─ combatClient/           # → ReplicatedStorage.CombatClient: controles y efectos del combate
│  │                          #   (armas, habilidades, esquiva, números, cómic), en la Isla y la arena
│  ├─ lobby/
│  │  ├─ server/Services/     # Lógica del servidor del Lobby
│  │  └─ client/Controllers/  # Interfaz y controles del Lobby
│  ├─ island/
│  │  ├─ server/Services/     # Lógica del servidor de la Isla
│  │  ├─ client/Controllers/  # HUD y controles de la Isla
│  │  └─ tools/               # → ServerStorage.Tools: MapBuilder (generador de la isla), Equilibrio
│  └─ dunas/
│     ├─ server/Services/     # Partida de la arena: equipos, banderas, reaparición, Ámbar
│     ├─ server/World/        # ArenaBuilder (mapa de la arena) y FlagModel
│     └─ client/Controllers/  # HUD, ventana previa y resultados de la arena
├─ lobby.project.json         # Proyecto Rojo del Lobby (puerto 34872)
├─ island.project.json        # Proyecto Rojo de la Isla (puerto 34873)
├─ dunas.project.json         # Proyecto Rojo de la Isla de Dunas (puerto 34874)
├─ sourcemap.project.json     # Solo para el autocompletado de VS Code
├─ rokit.toml                 # Versiones de herramientas
├─ selene.toml / stylua.toml  # Lint y formato
├─ .vscode/                   # Extensiones y ajustes recomendados
└─ .github/                   # CI: formato, lint y build en cada push
```

Más adelante se añadirán `wally.toml` (paquetes, Fase 2) y `assets/` (modelos exportados de referencia).

---

## 3. Fases

### Fase 0: Fundaciones (1–2 semanas)

**Objetivo:** que puedas cambiar código en el repo y verlo en Studio, y viajar del Lobby a la Isla.

**Tú** (sigue la guía [SETUP.md](SETUP.md)):
- [x] Instalar Roblox Studio, VS Code, GitHub Desktop y Rokit, y clonar el repo
- [x] Instalar las herramientas (`rokit install`) y el plugin de Rojo
- [x] Crear la experiencia en Roblox con 2 places: **Lobby** (inicio) e **Isla**
- [x] Copiar los IDs de los places a `Config.luau` y poner la Isla en 20 jugadores *(20-10-2026: el juego pasa a ser para grupos de amigos; hay que bajarla a **5**, ver [SETUP.md](SETUP.md) paso 7)*
- [x] Sincronizar con Rojo y publicar ambos places
- [x] Probar el viaje Lobby ↔ Isla en el juego publicado *(hizo falta poner la experiencia en Público y publicar la Isla)*

✅ **Fase 0 completada.**

**Claude:**
- [x] Estructura del repo: 2 proyectos Rojo + código compartido
- [x] `rokit.toml` (Rojo 7.7.1, StyLua 2.3.1, Selene 0.30.0)
- [x] CI en GitHub Actions: formato, lint y build en cada push
- [x] Módulo `Config` central (duración del día, jefes, baliza, viajes…)
- [x] Patrón *Services*/*Controllers* (`Loader`) y módulo `Remotes`
- [x] Botones de prueba "Ir a la Isla" y "Volver al Lobby" (TeleportService con reintentos y límite de peticiones)
- [x] Guía paso a paso en `docs/SETUP.md`, pensada para nivel básico

**Criterio de salida:** editas un número en `Config`, se ve en Studio y el botón del Lobby te lleva a la Isla publicada.

---

### Fase 1: Prototipo del bucle núcleo, "Sobrevivir el día 1" (4–6 semanas)

**Objetivo:** responder a la pregunta más importante: **¿es divertido salir, recolectar, pelear y volver?** Se hace con arte provisional (*greybox*).

Se entrega en partes pequeñas, cada una probable en Studio:

| Entrega | Contenido | Estado |
|---|---|---|
| **1.1** | Ciclo día/noche + Basecamp como zona segura | ✅ Probada en Studio |
| **1.2** | Recolección (árboles, rocas, arbustos) + HUD de inventario | ✅ Probada |
| **1.3** | Barra rápida + combate: machete, honda (gasta piedras) y esquiva, muñecos de práctica | ✅ Probada |
| **1.4** | IA de monos v1: mono ardilla y aullador rojo (aullido y refuerzos), botín, reaparición al amanecer | ✅ Probada |
| **1.5** | Caído → reanimación → Espíritu (mochila, marcas) → reaparición al amanecer | ✅ Probada |
| **1.6** | Mesa de trabajo con 7 recetas: antorcha, venda, hacha y pico de piedra, lanza, garrote y chaleco | ✅ Probada |

- [x] Generador de la isla provisional `MapBuilder`: terreno con colinas en todos los biomas, selva densa, palmeras, volcán activo, Basecamp de 170 studs con empalizada de estacas, portones y antorchas, recursos, guaridas y límites *(Claude)*
- [ ] Generar la isla en Studio, probarla y retocarla *(tú; ver [MAPA.md](MAPA.md))*
- [x] Ciclo día/noche configurable (10+7) con avisos de amanecer, atardecer y "anochece en 60 s" *(1.1)*
- [x] Basecamp como zona segura: pieza `BasecampZone` + indicador en el HUD *(1.1)*
- [x] Recolección: árboles, rocas y arbustos → madera, piedra, fibra (con regeneración) *(1.2)*
- [x] Inventario básico: materiales en el HUD *(1.2)*
- [x] Barra rápida para herramientas y armas: la mochila nativa de Roblox (teclas 1–9, táctil y mando) *(1.3)*
- [x] Combate en 3ª persona: machete (cuerpo a cuerpo), honda (distancia, gasta piedras, ayuda de puntería en móvil) y esquiva (Q / B / botón táctil), validados en el servidor *(1.3)*
- [x] IA de monos v1 (máquina de estados) con **2 especies**: mono ardilla (grupo rápido) y aullador rojo (grito que llama refuerzos) *(1.4)*
- [x] Tablas de botín basadas en datos (`Shared/Data/Monkeys.luau`) *(1.4)*
- [x] Caído → reanimación → Espíritu → reaparición al amanecer *(1.5)*
- [x] Mesa de trabajo con 5–8 recetas *(1.6: 7 recetas en `Shared/Data/Recipes.luau`)*

**Criterio de salida:** 4–6 amigos juegan 30 min seguidos. Se anota qué fue divertido y qué no, y se ajusta antes de seguir.

**Ajustes tras la primera prueba (2 jugadores):**

- [x] Cada jugador empieza con **hacha y pico de madera**. Árboles y rocas se trabajan **golpeándolos con la herramienta equipada** (la tecla E ya no tala ni pica). En la mesa de trabajo se **mejoran** a hacha y pico de piedra.
- [x] Más monos (18 grupos de mono ardilla y 14 de aulladores) y **repoblación continua**: un grupo con bajas recupera un mono cada 45 s si no hay jugadores cerca.
- [x] El Espíritu ya no espera al amanecer: reaparece a los **45 s**, +30 s por cada caída del mismo día (máximo 3 min).
- [x] Talar a golpes se siente bien. Cada árbol se tala de una vez (8 de potencia: 8 golpes con el hacha de madera, 4 con la de piedra), da 6 de madera (+2 con la de piedra) y **cae** antes de desaparecer.
- [x] El Espíritu solo marca enemigos (antes también árboles y rocas).
- [ ] Probar los ajustes *(tú)*

---

### Fase 2: Supervivencia y Basecamp (4–6 semanas)

Igual que la Fase 1, se entrega en partes pequeñas, cada una probable en Studio:

| Entrega | Contenido | Estado |
|---|---|---|
| **2.1** | Hambre, sed y estamina; correr; comer; cocinar en la hoguera; beber en el río | ✅ Código listo, falta tu prueba |
| **2.2** | Construcción por cuadrícula con martillo: núcleo compartido + 20 parcelas; muros, antorcha de pie y cama | ✅ Código listo, falta tu prueba |
| **2.3** | Estaciones construibles: taller del curandero (ungüento, vendas, antídoto) y forja de piedra (machete afilado, lanza, garrote, armadura de hueso) | ✅ Código listo, falta tu prueba |
| **2.4** | Capuchino ladrón (roba y huye; se recupera al derrotarlo) y miedo al fuego (antorchas) | ✅ Código listo, falta tu prueba |
| **2.5** | Asedio nocturno v1: 3 oleadas por noche por los portones, rompen piezas, estacas como trampa, zona de perímetro | ✅ Código listo, falta tu prueba |
| **2.6** | Fiebre del mono v1: mordiscos y carne cruda la suben, vista nublada, daño a 100, antídoto | ✅ Código listo, falta tu prueba |
| **2.7** | Dificultad por día (vida y daño de los monos), derrota (todos caídos de noche), resultados y Ámbar | ✅ Código listo, falta tu prueba |
| **2.8** | Guardado de datos con bloqueo de sesión (módulo propio, como ProfileStore): Ámbar, récord, partidas, XP por rol | ✅ Código listo, falta tu prueba |

- [x] Hambre, sed y estamina; cocinar en la hoguera; agua del río *(2.1)*
- [x] Construcción por cuadrícula (táctil y PC) con **núcleo compartido + parcelas personales** y permisos *(2.2)*
- [x] Estaciones: hoguera, taller del curandero, forja de piedra *(2.1 y 2.3)*
- [x] Monos ladrones (capuchinos) y miedo al fuego *(2.4)*
- [x] Asedio nocturno v1: oleadas hacia el Basecamp, muros, trampas y antorchas *(2.5)*
- [x] Fiebre del mono v1 (mordiscos → fiebre; antídoto básico) *(2.6)*
- [x] Escalado de dificultad por día *(2.7)*
- [x] Derrota del servidor → pantalla de resultados *(2.7)*
- [x] **Guardado de datos** (módulo propio con bloqueo de sesión, como ProfileStore): moneda, récord de días y XP de rol *(2.8)*

**Criterio de salida:** una partida dura 3 o más días con tensión creciente y el progreso se guarda entre sesiones.

---

### Fase 3: Lobby, roles y progresión (3–4 semanas)

| Entrega | Contenido | Estado |
|---|---|---|
| **3.1** | Lobby: cabecera con Ámbar y récord; pestañas Rol, Talentos, Tienda y Grupo | ✅ Código listo, falta tu prueba |
| **3.2** | Roles en la Isla: guerrero, cazador, mago y médico; pasiva, armas propias y 4 habilidades (Z, X, C, V / R1 + A, B, X, Y / botones) | ✅ Código listo, falta tu prueba |
| **3.3** | Talentos (4 por rol, uno por habilidad) y tienda de mejoras con Ámbar | ✅ Código listo, falta tu prueba |
| **3.4** | Grupos de amigos que viajan juntos; partidas en curso; recompensas y tutorial | ✅ Código listo, falta tu prueba |

- [x] Lobby: selector de rol y tienda de mejoras (Ámbar) *(la zona social 3D y la vitrina de mascotas llegan con las mascotas, Fase 5)*
- [x] Roles v1: pasiva + habilidad activa de médico, cazador y recolector
- [x] Árbol de talentos v1 (3 talentos por rol)
- [x] **Roles v2:** nuevo **Guerrero**; el Recolector pasa a **Mago** (su XP se conserva); 3 habilidades activas + 1 definitiva por rol, armas iniciales por rol (garrote de piedra, arco con flechas, bastón mágico) y 4 talentos por rol; las ventajas de recolección pasan a la tienda
- [x] Matchmaking: grupos con amigos al mismo servidor; Roblox mete a los jugadores sueltos en partidas en curso con hueco (y quien entra en una partida terminada vuelve al Lobby)
- [x] Recompensas al terminar la partida: Ámbar y XP del rol (2.7 y 2.8)
- [x] **Tutorial de los primeros minutos** (5 pasos, se puede saltar, solo la primera vez)

**Criterio de salida:** ciclo completo Lobby → Isla → resultados → Lobby, con progreso guardado.

> 💡 **Opción de alfa pública:** al terminar esta fase se puede publicar una alfa abierta para empezar a recoger datos reales de retención mientras se produce el contenido.

---

### Fase 4: La isla completa y el bestiario (6–8 semanas)

- [ ] Mapa completo: playas (límite), selva, ríos y manglar, montañas, cuevas y volcán *(tú, con kits low-poly del Creator Store; la isla generada por `MapBuilder` ya tiene todos los biomas)*
- [x] Todas las especies de categoría 1–3 con su mecánica propia, horario día/noche y respawn diario *(12 especies en `Shared/Data/Monkeys.luau`, cada una en su zona)*
- [x] Tropas con alfa, huida y comportamiento ladrón *(alfa con corona; si muere, la tropa huye)*
- [x] **Bestiario/diario de campo** (UI) que se completa cazando *(J en la Isla y pestaña "Diario" en el Lobby)*
- [x] Armas, armaduras y recetas por nivel; rarezas de botín *(nivel 3 en la forja; 5 rarezas con color)*
- [x] **Optimización (código):** límite de monos activos, "sueño" de la IA y registro de rendimiento
- [ ] **Optimización (tú):** activar StreamingEnabled y probar en móvil de gama baja *(ver [RENDIMIENTO.md](RENDIMIENTO.md))*

**Criterio de salida:** un servidor lleno (5 jugadores desde el 20-10-2026; antes 20) estable en móvil, y cada bioma tiene una razón para visitarlo.

---

### Fase 5: Jefes, huevo, mascotas y PvP (6–8 semanas)

| Entrega | Contenido | Estado |
|---|---|---|
| **5.1** | 4 jefes en sus guaridas, 3 fases, ataques especiales, pieza de baliza y botín legendario | ✅ Código listo, falta tu prueba |
| **5.2** | Huevo misterioso: aviso, portador lento y con PvP, nido, incubación defendida y eclosión | ✅ Código listo, falta tu prueba |
| **5.3** | Mascotas: 13, cinco rarezas, seis tipos de ayuda, 1 activa desde el Lobby | ✅ Código listo, falta tu prueba |
| **5.4** | PvP opt-in con tótem, indicador, recompensa por cabeza y cajas de suministro en las playas | ✅ Código listo, falta tu prueba |
| **5.5** | Clima (lluvia, tormenta con rayos) y erupción del volcán | ✅ Código listo, falta tu prueba |

- [x] 4 jefes de bioma con fases, patrones y botín especial (pieza de baliza garantizada)
- [x] Rotación de jefes: uno cada 2 días (días 2, 4, 6, 8…), y cada uno se queda hasta que lo derrotan o aparece el siguiente
- [x] Evento del huevo: aparición, aviso global, transporte, nido, incubación y eclosión
- [x] Mascotas persistentes: colección, rarezas, 1 activa, tipos de ayuda
- [x] PvP opt-in: tótem, indicador, espera para desactivar, cajas de suministro y recompensa por cabeza
- [x] Clima y eventos: lluvia, tormenta y erupción del volcán

**Criterio de salida:** las partidas generan **momentos memorables** (jefe, huevo, robo) que la gente quiere contar o grabar.

---

### Fase 6: Rescate, pulido y lanzamiento (4–6 semanas)

| Entrega | Contenido | Estado |
|---|---|---|
| **6.1** | Baliza de rescate (4 piezas, desde el día 8) → La Gran Tropa → victoria | ✅ Código listo, falta tu prueba |
| **6.2** | Clasificaciones globales (días y rescates) y pestaña "Ranking" | ✅ Código listo, falta tu prueba |
| **6.3** | Analítica: embudo del tutorial, economía del Ámbar, victorias y derrotas | ✅ Código listo |
| **6.4** | Tienda cosmética con Game Passes (pestaña "Estilo") y servidores privados | ✅ Código listo; faltan los pases *(tú)* |
| **6.5** | Música configurable por situación y sonido de avisos | ✅ Código listo; faltan las pistas *(tú)* |
| **6.6** | Guía de lanzamiento: [LANZAMIENTO.md](LANZAMIENTO.md) | ✅ |

- [x] Baliza de rescate (se puede encender desde el día 8) + noche final "La Gran Tropa" → victoria
- [x] Clasificaciones (días sobrevividos, rescates)
- [x] Sonido y música *(código; los IDs de audio los eliges tú)*; pulido de UI para móvil *(revisar en la beta)*
- [x] Analítica (embudo del tutorial, retención, economía)
- [x] Tienda cosmética (Robux), servidores privados *(código; los pases los creas tú)*
- [ ] Nombre final, icono, miniaturas *(tú; el cuestionario de madurez ya está hecho)*
- [ ] Beta cerrada → **lanzamiento** *(tú; ver [LANZAMIENTO.md](LANZAMIENTO.md))*

---

### Fase 6b: Bucle de retención (octubre de 2026)

Basado en [Bucle central de retencion.txt](Bucle%20central%20de%20retencion.txt) y en la entrevista del 19-oct-2026 (detalles en el GDD §4 "Bucle de retención" y §11). Probado en Studio por partes ([VERIFICACION.md](VERIFICACION.md) §5.2 y §7).

| Entrega | Contenido | Estado |
|---|---|---|
| **R1** | Huevos guardados: perfil v3, rareza al aparecer, mochila de 3 + pendientes | ✅ Probado en Studio |
| **R2** | Nido del Lobby: tu huevo con su temporizador, panel en Mascotas, ceremonia al abrirlo | ✅ Probado en Studio |
| **R3** | Acelerar jugando: −1 h por noche, ruleta del rescate, tope del 50 %, aviso de huevo listo | ✅ Probado en Studio |
| **R4** | Provisiones de partida (se guardan y llegan a la mochila al empezar) | ✅ Probado en Studio |
| **R5** | Calendario de 7 días (ventana al entrar, pestaña Misiones; faltar no reinicia) | ✅ Probado en Studio |
| **R6** | Título "Superviviente de la Isla" gratis, solo al ganar una partida | ✅ Probado en Studio; falta una victoria real |
| **R7** | Misiones diarias (2 generales + 1 del rol), rastreador en la Isla (PC) | ✅ Probado en Studio |

- [ ] Probar con 2 jugadores: los dos se llevan su huevo al defender uno juntos
- [ ] Medir en el juego publicado la retención D1/D7 y cuántos vuelven a abrir su huevo (Analítica: `LoginCalendarDay`, economía `EggDiscard`, `LoginCalendar`, `DailyMission`)

---

### Fase 7: Después del lanzamiento (continuo)

Temporadas con lore, nuevos jefes y eventos, mutadores de partida ("Luna roja", "Temporada de lluvias") y balance basado en datos.

---

### Menú del Lobby por estaciones (20-10-2026)

El menú de 11 pestañas pasa a estaciones en la plaza (roles, nido, Isla de dunas y ranking, cada una con su ventana) y una barra de iconos con el resto. Plan: `C:\Users\jose\.claude\plans\atomic-tumbling-duckling.md`. Comprobación: [VERIFICACION.md](VERIFICACION.md) §9.

| Paso | Qué | Commit | Estado |
|---|---|---|---|
| M0 | Arena del Lobby con la ventaja de cada clase, como en Dunas (`Shared/UI/ArenaRoleCards`) | `ba3db55` | ✅ Probado |
| M1 | Ventanas por estación y barra de iconos con avisos; pastilla del Ámbar; ventanas sin desplazarse y móvil a pantalla completa; aura en el atajo a talentos | `70685d0`, `30f6f66`, `6d1f80c` | ✅ Probado (PC y teléfono del emulador) |
| M2 | Lobby v12: cartel de mascotas con el nido delante, ranking ancho con la arena, cartel y aviso de la Isla de dunas | `c0a7043` | ✅ Probado; **falta guardar el place** |
| M3 | Carteles por jugador (mascotas e Isla de dunas) y recuento de la cola | `a6d3912` | ✅ Probado (la cola real, publicado) |
| M4 | Iconos de las estaciones, contorno al acercarse y guía de la primera vez | `12aa8f8` | ✅ Probado |
| M5 | Documentación | — | ✅ |

### Fase 8: Isla de Dunas, arena PvP (octubre de 2026)

Tercer place: captura la bandera por equipos, de 1v1 a 5v5, con equipamiento propio comprado con Ámbar (diseño en el GDD §12.2, entrevista del 20-10-2026). Probado en Studio con un jugador ([VERIFICACION.md](VERIFICACION.md) §8); falta probarlo con varios jugadores y publicado.

| Entrega | Contenido | Commit | Estado |
|---|---|---|---|
| **D1** | Combate compartido entre places: `src/combat` y `src/combatClient`, con reglas por place en `CombatRules`. La Isla juega igual | `804a2f8` | ✅ Probado en Studio |
| **D2** | Place de Dunas (Rojo 34874), equipos, rol por jugador, partida con espera, cuenta atrás, batalla, muerte súbita y resultados, reaparición, HUD, perfil v4 | `bb38ab1` | ✅ Probado en Studio |
| **D3** | Banderas (robar, capturar, soltar y devolver), portador más lento, Ámbar con tope diario, estadísticas, ranking y revancha | `556e2a9` | ✅ Probado en Studio (un jugador) |
| **D4** | Números de la arena (duelos de 8–10 s), veneno, lento, marcas y combos contra rivales, 24 variantes de equipamiento y su tienda | `3fd7559` | ✅ Probado en Studio (un jugador) |
| **D5** | Lobby: embarcadero con velero, pestaña Arena, cola entre servidores con MemoryStore, cartel de ranking de la arena | `eb18f6c` | ✅ Probado hasta `ReserveServer` (en Studio no se viaja) |
| **D6** | Mapa final de ruinas mayas e iluminación; esquiva y Embestida sin salir volando, efectos de cómic en la arena, cámara al aparecer | `dce4bd9` | ✅ Probado en Studio |
| **D7** | Documentación: GDD §12.2, esta fase y VERIFICACION §8 | — | ✅ |

- [ ] Probar con 2–4 jugadores (*Test → Local Server*): daño entre rivales, curación solo a aliados, devolver la bandera, no puntuar con la propia robada, victoria por abandono
- [ ] Probar publicado: cola y viaje Lobby → Dunas (1v1 con 2 cuentas, grupo de 2 en 2v2), "Volver al Lobby", cobro de Ámbar con tope y ranking
- [ ] Revisar con más jugadores (datos de partidas reales): el duelo de médicos dura 30 s (objetivo 8–10 s); por ahora se deja así (decidido el 20-10-2026)
- [x] Ventana de equipamiento en el teléfono: las tres ranuras en columnas con sus nueve opciones, y la ventana en dos columnas para verlo todo sin desplazarse
- [ ] Antes de publicar: guardar los places del Lobby y de Dunas y **publicar los tres a la vez** (perfil v4: un place con el código viejo borraría el campo `arena`)

---

### Fase 9: Pase de temporada, misiones v2, mitad de partida y cosméticos (octubre de 2026)

Basado en [Sistema de recompensas y retencion.txt](Sistema%20de%20recompensas%20y%20retencion.txt), [battle_pass_30_days.pdf](battle_pass_30_days.pdf), la guía de Roblox para pases de temporada y la entrevista del 20-10-2026. Plan: `C:\Users\jose\.claude\plans\serialized-soaring-biscuit.md`. Cada grupo es un commit y una sesión propia; la economía se mide con la skill `economia-retencion` (calculadora `src/island/tools/Economia.luau`).

Reglas de la entrevista: la premium del pase es **solo cosmética** (Developer Product de 399 R$ por temporada; pack +10 niveles 799; nivel 79); el Ámbar, el tiempo de huevo, las provisiones y los huevos solo salen de la pista gratis y del nivel **ganado jugando**; temporada de 30 días y 30 niveles que se completa con ~20–24 días activos, ×2 de XP la última semana y 7 días de descanso; el calendario de 7 días se queda; "Superviviente de la Isla" sigue siendo solo para quien gana. Temporada 1: "El Despertar del Volcán".

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **G1** | Skill `economia-retencion` y calculadora de la economía (línea base: misiones al 100 % en la primera hora, el habitual gasta el 15 % de su Ámbar, equipo de nivel 3 el día 1) | `857ef5e` | ✅ |
| **G2** | Fundaciones: perfil v5 (`season`, `weekly`, `purchases`, `ownedCosmetics`), compras con recibo (`ServerShared/Purchases`, `ProcessReceipt` en los 3 places), cosméticos con `source`, rareza y huecos por tipo/rol/mascota/rueda de emotes (`Shared/CosmeticSlots`), `Config.Season` y `Config.Shop` | `ca70019` | ✅ |
| **G3** | Pase de temporada: `Data/Seasons` (T1 con premios provisionales: 3 cosméticos gratis y 3 premium), `Shared/SeasonPass` y `ServerShared/SeasonPass` (XP de la Isla, Dunas y misiones con tope de partidas, +10 % con amigos y ×2 la última semana; reclamar; cierre de temporada que entrega lo no reclamado), compras (premium, pack +10, nivel), cartel volcánico del pase en la plaza (Lobby v14) con su "!", ventana sin desplazamiento (`UI/SeasonPassPanel`) y botón 🌋 en la barra, línea de XP en los resultados, sección "Pase" de la calculadora (sin semanales el habitual llega al nivel 24: se cierra con las semanales de G4) | `b0883b0`…`3ccf9f3` | ✅ |
| **G4** | Misiones v2: cada día una fácil, una media (la del rol) y una difícil (avanzar en la partida); 5 semanales de 13 (como mucho una de Dunas) con un extra por las 5; un cambio gratis al día y otro a la semana (`Remotes.RerollMission`); eventos nuevos (llegar a un día, jefe, alfa, especies distintas, rescate, ganar y capturar en Dunas, que empieza a contar); ventana Misiones con pestañas Hoy/Semana y rastreador de la Isla también en el teléfono (fichas en la franja de la barra de Roblox). Calculadora: semanales simuladas por perfil; XP de la Isla 60/día y 150/jefe y diaria fácil 200 para que el casual llegue al nivel 12 y las misiones sean el 65 % de la XP del habitual (termina el día 24); el rastreador de la Isla enseña también las semanales y se pliega | `1b9c370`…`f343d1d` | ✅ |
| **G5** | Equipo ligado a los jefes: cada jefe da 2 de su tesoro a cada participante (no se pierden); el nivel 3 de las armas de rol y la armadura de plata pide la Corona del caudillo (día 4); Forja volcánica con obsidiana (15 vetas en el volcán y la cueva) y nivel 4 (Mazo volcánico, Arco de brasa, Bastón de lava, Cerbatana de azufre, ~+30 % de DPS; Armadura volcánica −65 %) con el Cristal de cueva (día 6); modelos de nivel 4 con hombreras de obsidiana en lava y humo. Gorila de Ceniza 7.000 de vida (sigue en ~3 min). Calculadora: nivel 3 el día 4 y nivel 4 el día 6 (antes, todo el día 1) | `6782ec7` | ✅ |
| **G6** | Contratos de expedición por partida, compartidos por el grupo: 3 contratos (Campamento del náufrago, Diario del naturalista, Ruta del volcán) de 5 pasos que se abren los días 1, 3, 5, 7 y 8 y se pierden al abrir el siguiente; objetivos que crecen con el grupo; cada paso da Ámbar, XP del pase (de partida) y objetos a todos los de la partida; tarjeta bajo el rastreador de misiones (ficha "📜" en el teléfono) y línea en los resultados. Calculadora: el habitual termina el pase el día 23 (antes 24) y el casual llega al nivel 13 | `0adca52` | ✅ |
| **G7** | Eventos de mitad de partida (`MidEventService`, `Data/MidEvents`), cada uno en un día al azar de los suyos, con aviso la víspera al anochecer y línea de estado en el HUD: lluvia tóxica (día 3 o 4: el agua del río y los mordiscos dan fiebre, agua hervida en la hoguera, antídotos y Ungüento del médico), macacos saboteadores (noche 5: van a por trampas, muros y estaciones) y erupción preliminar (día 7: piroclastos en las zonas altas y 2 cajas militares con obsidiana, esquirla de jefe y provisiones que activan el PvP; el paso "Asegurar" del contrato pide abrir una) | `4d97a0d` | ✅ |
| **G8** | Preparar la Gran Tropa: en la noche final la mitad de los mandriles, orangutanes y gorilas de cada oleada va a por la baliza (16.000 de vida; solo la rompen ellos, los demás monos la rodean); si la derriban se corta la señal, no hay rescate esa noche y al amanecer se repara y se puede volver a encender. Tótem guardián (uno por campamento, pide una Perla del río): a 25 studs, −35 % de daño a las piezas y reparación nocturna, −10 % de daño a los jugadores. Las antorchas de pie espantan a los aulladores del asedio y se gastan. Medido en Studio: sin defenderla, la baliza cae al poco de llegar la 5.ª oleada | `908ef85` | ✅ |
| **G9a** | Rareza **Mítico** (por encima de Legendario, solo cosméticos) y regla "cuanto más raro, más detalle"; trajes por rol (`ArmorModels`, ahora en Shared, con `dress` y los atributos `Outfit`/`WeaponSkin` que publica `CosmeticsServer`) y aspectos de arma por rol (`WeaponTools`, en la misma Tool con el nivel 1–4 del arma); los míticos ganan piezas con el nivel de la armadura y del arma en la Isla y se ven enteros en el Lobby y en Dunas; ventana **Armario** (sustituye a Estilo, `UI/WardrobePanel`: avatar 3D que gira, pestañas, rol y tarjetas con borde de rareza); primer par mítico de los dioses de la selva: traje **Rey Gorila Titán** (se gana venciendo de guerrero con la Maza y la Armadura volcánicas, 69→238 piezas, con un motivo propio en la espalda en cada grado: sol, calavera de gorila dorada, ídolo e ídolo con aro solar) y **Maza del Rey Gorila** (Robux, 449 R$; 22→89 piezas) | `62028e6`…`b3f26e0` | ✅ |
| **G9b** | Los otros tres pares míticos, traje (se gana venciendo con el equipo de nivel 4 del rol) y arma (Robux, 449 R$), cada uno con su brillo y su motivo en la espalda en cada grado: **Jaguar Espectral** del cazador (pelaje de jaguar, luz blanca azulada; el espíritu del jaguar sale de la capucha y asoma por el hombro, luna creciente; arco con garras de oro), **Serpiente Emplumada** del mago (escamas turquesa y plumas de quetzal sobre añil, azul de runa; la serpiente enroscada que se alza de perfil, penacho de plumas; báculo con la serpiente que sujeta el cristal) y **Ceiba de la Vida** del médico (corteza con espinas, flores y algodón, verde de curación; el tronco con raíces de contrafuerte que se abre en ramas y copa con colibríes; cerbatana-rama con ramitas) | `f927e2e`, `53f8f4b`, `82b4ed6` | ✅ |
| **G9c** | Skins de mascota (`PetModels` SKINS: paleta que lee `tone`, materiales y piezas propias; las mascotas que comparten modelo llevan **skins de familia**, felinos y perros), con la **Tortuga de Lava** de ejemplo (basalto, placas de lava, volcancito con humo); **marcos** (`UI/PlayerFrames`: bronce y Obsidiana fundida) en el ranking, la ventana Grupo y los resultados de la Isla (fila nueva con el grupo) y de Dunas; **rueda de emotes** (`UI/EmoteWheel`, tecla "." o 😀, junto al ⚙️ en la Isla y en la barra del Lobby; se para al moverte y no deja en combate), con 5 emotes de serie gratis (animaciones de Roblox); el Armario gana las pestañas Mascotas, Marcos y Emotes, y su vista previa junta lo elegido en cada hueco (traje, arma y efectos a la vez) | `5b01fda`, `6ad89ca` | ✅ |
| **G9d** | Tipos baratos para llenar la premium, uno de cada: **estilo de los números** (`UI/NumberStyles`: letra, tres franjas de color y borde en el daño que haces, que también ven los aliados; ejemplo Números de Magma), **estilo de los estallidos** (`ComicBurst` STYLES: colores y palabras de tu golpe, crítico y K.O.; el "OUCH!" sigue rojo; ejemplo Erupción, estrella de basalto con lava dentro) y **decoración del nido** (`Shared/NestDecor`, solo la ve quien la lleva, apoyada en el suelo; ejemplo Nido volcánico); **grados I, II, III** (cosméticos con la misma `line`: se ve el más alto que tienes y el Armario enseña una tarjeta por línea; ejemplo Llama primal, con anillo de llamas desde los pies en el II y brasas, humo y luz en el III); imágenes en `RewardModels.cosmetic` (también las skins de mascota) y pestaña 🎨 Estilos del Armario con números y estallidos en vivo; en el pase provisional, N5, N8, N12, N15 y N30 | `c7d4853`, `7defe2a` | ✅ |
| **G10a** | Tiendas de cosméticos: pestaña **🎨 Cosméticos** en la Tienda del Lobby (`UI/CosmeticShopPanel`), con 4 en Ámbar que rotan cada día y 3 sueltos de Robux que rotan cada lunes (un Developer Product cada uno) y los Game Passes siempre a la venta; rotación común con semilla del día o la semana (`Shared/CosmeticShop`) de la que cada jugador ve lo que aún no tiene, fijada en su perfil (versión 6, `cosmeticShop`) por `CosmeticShopService`; nunca entran premios de la temporada en curso; el Armario dice si algo está hoy en la tienda; la calculadora mide el sumidero, el catálogo y los precios; 5 cosméticos de prueba en Ámbar y los Números Escarcha en Robux | `eec74f8` | ✅ |
| **G10b** | Catálogo de las tiendas, tema "selva y mar" (distinto del volcán de la temporada): 22 cosméticos en Ámbar (19.000 en total; el habitual gasta el 97 % y tiene la tienda entera el día 30) con títulos, estelas por franjas, auras con forma propia (arena, tormenta), marcos, números, estallidos, el nido **Playa de coral** y la skin de familia **Perro pirata** para los tres perros; 6 sueltos de Robux nuevos (99–249 R$, con el nido **Templo dorado**), 11 en la rotación semanal; la tarjeta de un marco enseña tu nombre con él | `81128c4` | ✅ |
| **G11** | Contenido de la Temporada 1: **un premio premium en cada uno de los 30 niveles** (~8 grandes en los niveles clave, el aura que evoluciona en N1/N15/N30 y ~20 pequeños de los tipos baratos) y ~8 cosméticos gratis (G11a trajes y armas ✅, G11b mascotas, marcos y efectos ✅, G11c emotes ✅, G11d los pequeños ✅) | G11a: `1305ccb`, `8c7883b`; G11b: `8f0e0a9`; G11c: `1c1337c`; G11d: `02a7b62` | ✅ |
| **G12** | Calibración final y documentación: la calculadora con todo encendido no da alertas (el habitual termina el pase el día 23 y gasta el 97 % de su Ámbar; el casual llega al nivel 13) y su sección "Reglas de pago" revisa ahora también lo que aún no tiene id (18 productos, todos cosméticos o el pase); prueba de robustez con ritmos más lentos y sesiones más cortas, con sus hallazgos en la skill; nueva línea base; GDD v0.3 (§4 misiones v2 y semanales, §5.4 contratos, eventos y Gran Tropa, §11, §14 con el pase, las tiendas, los cosméticos y las correcciones a la investigación), VERIFICACION §10 paso a paso, LANZAMIENTO (Developer Products a crear con sus precios, fecha de la T1, publicar los tres places a la vez) y hoja "Correcciones" en el Excel del pase | `d9c0a93` | ✅ |

- [x] Crear en el Creator Hub los Developer Products (pase, pack, nivel, cosméticos sueltos) y poner sus ids (G2/G3/G10; los 14, el 22-10-2026)
- [ ] Antes de publicar: **publicar los tres places a la vez** (perfil v5)
- [ ] Poner la fecha de verdad de la Temporada 1 en `Data/Seasons` (hoy, provisional: 19-10-2026) (G3/G12)
- [ ] Guardar y publicar el Lobby con la plaza v14 (cartel volcánico del pase) (G3)
- Decisión del 21-10-2026 (G11a): los trajes y las armas de la Temporada 1 son de **fuego azul y azufre** sobre piedra pómez (la armadura del nivel 4 ya es obsidiana negra con lava naranja) y **ganan piezas con el grado** de la armadura, como los míticos pero en cinco escalones; el machete de obsidiana gratis pasa a ser un aspecto del machete con su propio hueco (`WeaponSkin.Machete`); un par por aprobación. **G11a terminado y aprobado**: par del guerrero (Guardián del Fuego Azul en N5, Maza de Azufre en N3) y hombreras volcánicas de losa con llama en píxeles, `1305ccb`; cazador (Acechador del Fuego Azul en N10, Arco de Azufre en N7), mago (Invocador del Fuego Azul en N20, Bastón de Azufre en N13), médico (Sanador del Fuego Azul en N25, Cerbatana de Azufre en N18) y el Machete de Azufre gratis en N8, `8c7883b`. Sigue el G11b.
- Decisión del 21-10-2026 (G11b): el Jaguar de Magma es de **magma naranja** (basalto, obsidiana y lava, como la Tortuga de Lava), no de fuego azul. **G11b terminado y aprobado** (`8f0e0a9`): premium Estela de fuego azul en N16, Marco de fuego azul en N21, Jaguar de Magma (skin de los tres felinos) en N23 y Marco de Obsidiana fundida en N27; gratis, junto al premio de siempre, Marco de bronce en N4, Tortuga de Lava en N12 y Marco de plata en N22; la Pisada de magma (N11) deja huellas de lava. Quedan 10 niveles premium vacíos (2, 4, 9, 14, 17, 19, 22, 24, 26 y 28) para el G11c (emotes) y el G11d (premios pequeños).
- Decisión del 21-10-2026 (G11c): tres emotes premium con efectos pequeños y uno gratis sin efectos. **G11c terminado y aprobado** (`1c1337c`): premium Grito de gorila en N2 (polvo del pecho, onda de polvo y piedrecitas al rugir), Danza del fuego en N9 (en bucle, llamas azules de bloques en las manos y chispas de azufre al pisar) y Erupción en N17 (grietas de lava y chorro de ceniza y brasas); gratis, junto a las provisiones, Saludo simio en N6. Las animaciones están publicadas (ids en `Data/Cosmetics`) y su fuente es `Data/EmoteAnimations`. La rueda de emotes solo está abierta mientras se mantiene ".". Quedan 7 niveles premium vacíos (4, 14, 19, 22, 24, 26 y 28) para el G11d.
- Decisión del 21-10-2026 (G11d): los siete niveles premium que quedaban, cuatro títulos y tres estilos de fuego azul y azufre. **G11d terminado y aprobado** (`02a7b62`): títulos Hijo del Volcán (N4), Caminante de Ceniza (N19), Domador del Magma (N24) y Guardián de la Llama Azul (N26); Números de fuego azul (N14), Estallido de fuego azul (N22) y el nido Cráter de azufre (N28). Ya hay un premio premium en cada uno de los 30 niveles: **G11 terminado**. Sigue el G12.
- **Fase 9 terminada** (22-10-2026): G1–G12 aprobados y subidos. Queda fuera de Studio lo de las casillas de arriba (Developer Products, fecha de la T1, publicar los tres places a la vez) y medir D1/D7 y la conversión del pase con datos de verdad.
- Decisión del 22-10-2026 (G12): la fecha de la Temporada 1 se queda provisional hasta que se sepa el día de publicar (paso de `docs/LANZAMIENTO.md` §3); las correcciones del Excel van en una hoja nueva "Correcciones" (el PDF es una exportación y no se toca). Los números no cambian: con los ritmos supuestos todo está en sus límites, y lo que salta con ritmos un 30 % más lentos queda apuntado para cuando haya telemetría.
- Decisión del 21-10-2026 (G10): el G10 se reparte en G10a (las tiendas, la rotación y la calculadora) y G10b (el catálogo); en la tienda de Robux van los sueltos que rotan cada semana y, debajo, los Game Passes fijos.
- Decisión del 21-10-2026 (G9): rareza **Mítico** por encima de Legendario, con un traje y un aspecto de arma míticos por rol (tema "dioses de la selva"); el traje se gana (vencer con el equipo de nivel 4 del rol) y el arma se vende suelta en Robux; los míticos crecen con el nivel de la armadura y del arma. El G9 se reparte en 4 sesiones (G9a–G9d).
- Decisión del 21-10-2026: la pista premium lleva **un premio en cada nivel** (solo 3 de 30 se veía vacía y no animaba a comprar). Sin moneda cosmética por ahora ("Brasas" queda para otra temporada, cuando haya tienda y datos de compra).

---

### Fase 10: Combate v2 (octubre de 2026)

Revisión y mejora del combate buscando la **equidad**. Se basa en [Sistema de combate y combos.txt](Sistema%20de%20combate%20y%20combos.txt), el mapa [Sistemas de combate en roblox.png](Sistemas%20de%20combate%20en%20roblox.png), la investigación de referentes (The Strongest Battlegrounds, Deepwoken, juegos de lucha, accesibilidad en móvil, detección en Roblox) y la entrevista del 22-10-2026. Diseño en el GDD §6.5. Plan con los handoffs: `C:\Users\jose\.claude\plans\fizzy-snacking-quiche.md`. Cada grupo es un commit y una sesión. El combate se mide con la skill `combate-roblox` (antes `habilidades-roblox`), con la calculadora `src/island/tools/Equilibrio.luau` (secciones 7 a 10, nuevas). Al cerrar la fase, la comparativa contra la foto inicial (`docs/combate-v2/linea-base.md`) va en `docs/combate-v2/comparativa.md`.

Decisiones de la entrevista:
- Isla y Dunas con el mismo combate.
- Bloqueo + parry + barra de guardia (los imbloqueables la rompen).
- Cadena de 4 golpes en cuerpo a cuerpo y proyectiles reales.
- Evasivo + escalado en PvP + control decreciente sobre los enemigos.
- Una sola ventana de parry para todos, con compensación de ping a favor del defensor.
- Amagos en el golpe y en las habilidades.
- Rebote contra muros, zonas de peligro, coberturas que se rompen y altar en Dunas.
- Aturdido separado de inmovilizado.
- Guardia en F / L2 / botón; Evasivo = esquivar estando aturdido.
- Shift lock de Roblox en Ctrl.
- Sin lock-on; los estilos se documentan y se miden.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **C1** | Skill `combate-roblox` (renombrada y ampliada: mecánicas, detección, estilos y combos, equidad), números propuestos en `Config` y secciones 7 a 10 de la calculadora con sus límites, foto inicial y GDD §6.5 | `05d7697` | ✅ |
| **C2** | Fundaciones: máquina de estados, aturdido e inmovilizado, estamina del servidor, `Latency`, `Knockback` (la Embestida empuja también a jugadores) y shift lock en Ctrl | `fe480f8` | ✅ |
| **C3** | Detección de impactos unificada (`Combat/Hitbox`: rayos, esferas, cajas, áreas con línea de visión, posiciones rebobinadas). Ningún golpe atraviesa paredes. | `803d208` | ✅ |
| **C4** | Cadena de 4 golpes cuerpo a cuerpo con remate (`Shared/MeleeChain`, tajos `Slash1`–`Slash4`) | `c7cbfa5` | ✅ |
| **C5** | Guardia: bloqueo, parry y rotura; HUD y botón (`Combat/Guard`, `GuardController`, `CombatClient/GuardBar`) | `c4a5552` | ✅ |
| **C6** | Monos y jefes con preparación, control decreciente y muñecos que atacan para practicar (`Combat/EnemyAttack`, `EnemyWindupController`, `Config.ControlDR` en `Status.stun`, muñeco de sparring) | `fa01ab2` | ✅ |
| **C7** | Evasivo, escalado del combo en PvP y telemetría nueva (`Combat/Evasive`, `CombatClient/EvasiveIcon`, `Combat/ComboScaling`, controles PvP con `Config.ControlDR`, `telemetry.mechanic` en la Isla y en Dunas) | `b66465d` | ✅ |
| **C8** | Habilidades con preparación y amagos (`castSeconds` y estado `Casting`, `Combat/Feint` y `CombatClient/Feint`, guardia una vez por uso, sección 10 de `Equilibrio`) | `159671d` | ✅ |
| **C9** | Proyectiles reales (`Combat/Projectiles`, ayuda de puntería `CombatService.aimShot` en studs que adelanta contra monos, tasa de acierto en `Equilibrio` y daños compensados, telemetría `ShotsHit`/`ShotsMissed`) | `9c6b98c` | ✅ |
| **C9b** | Disparo de remate de las armas a distancia (`Shared/RangedChain`, `Config.RangedChain`: cada 4.º disparo seguido, mismo DPS contra uno; el arco atraviesa al primero y da al siguiente, el bastón estalla, la cerbatana cura el doble a un aliado y la honda tambalea a monos pequeños; telemetría `ShotFinishers`) | `1beeb86` | ✅ |
| **C10** | Rebote contra muros (`Combat/Knockback`, `Config.WallBang`: Embestida, Rompehuesos, que ahora aparta, y remate de la cadena; 5 de daño, aturdido 0,5 s, 1,5 s de inmunidad; telemetría `WallBangs`) y zonas de peligro (`Combat/Zones`, `Config.Zones`: hielo de la Nova que ralentiza y hace resbalar, nube del Polvo que se queda, fuego del Meteoro rematado; `ZoneController`) | `2e408bb` | ✅ |
| **C11** | Dunas: coberturas que se rompen (`Combat/Destructibles`, `CoverService`, `Config.Arena.Covers`: estelas y columnas de pie, 100 de piedra, habilidad 25, definitiva 100, remates 20, vuelven a los 45 s; grietas, trozos y polvo en `CoverController`) y altar de la pirámide (`AltarService`, `Config.Arena.Altar`: 6 s para tomarlo, 30 s de definitiva ×2, vuelve a los 75 s; HUD, cartel y resultados). `ArenaBuilder` v5 con barreras en los templos (se salía del mapa) | `ddcae1d` | ✅ |
| **C12** | Claridad, interfaz y aprendizaje: temblor de cámara común con su ajuste (`CombatClient/CameraShake`, `cameraShake`), estallidos ¡PARRY!, ¡GUARDIA ROTA! y ¡CONTRA!, rombos de la cadena a los pies (`ChainPipsController`), sonidos del Creator Store, cadena, guardia y "Controles del combate" en Ajustes, y paso de la guardia en la guía del Lobby (`combatGuideDone`) | `2976926` | ✅ |
| **C13** | Calibración final, documentación y comparativa antes → después: arena sin talentos en la calculadora, Grito de guerra −15 % contra jugadores (`PvPWarCryMultiplier`), daño enlazado del guerrero +15 %, `docs/combate-v2/comparativa.md`, GDD v0.4 y VERIFICACION §11 | `ba5961e` | ✅ |


### Fase 11: Monturas (octubre de 2026)

Una clase nueva de mascota que se monta. La primera es la **Llama Andina** (rara): modelo voxel en `Shared/MountModels` y sus animaciones en `MonkeyAnimationSpecs/Monturas` (galope, rumiar, escupir y saltar). Plan: `C:\Users\jose\.claude\plans\squishy-exploring-toucan.md`.

Decisiones del 23-10-2026:
- Se monta en el Lobby y en la Isla; en Dunas no.
- Se consiguen jugando (huevos), nunca con Robux.
- Viaje rápido: más rápida que correr a pie y sin gastar estamina. Montado no se ataca: atacar, recibir daño, cargar el huevo o caer te desmonta.
- Escupir es un gesto, sin daño.
- La montura es un modelo que cada cliente pega bajo el personaje (como las mascotas que siguen al jugador): el combate sigue apuntando al personaje.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **M1** | Montar y desmontar en el Lobby y la Isla: perfil (`mounts`, `activeMount`), `ServerShared/MountServer` y remoto `ToggleMount`, `Shared/UI/MountRiders` (montura pegada al jinete con sus animaciones), velocidad de montado, pose `Ride` del jinete, botón Montar (N / R3) y elegir la montura en el Lobby | `125119e` | ✅ |
| **M2** | Conseguirlas jugando: tirada de montura al abrir un huevo de su rareza, ceremonia y lista del nido, GDD y calculadora `Economia` (EggChance 0,5). Con él, el panel de administradores para dar todo a un jugador | `586edf8` | ✅ |
| **M3** | Gesto de escupir montado (remoto `MountSpit`, Y o el botón Escupir, cada 3 s; partículas en el marcador "Escupir") | `6cbf97f` | ✅ |

### Pedidos del 26-10-2026 (tandas)

Diecinueve pedidos agrupados en tandas; cada una es una sesión. Plan con el detalle: `C:\Users\jose\.claude\plans\fluffy-stirring-octopus.md`.

Decisiones: tras ganar, "Seguir sobreviviendo" en la Isla; la montura de los 7 días es una tirada con pesos que se repite en cada ciclo, y una repetida da Ámbar; el Quetzalcóatl planea, no vuela; solo se regalan cosméticos de Robux; el estilo nuevo de V es opcional, no sustituye al actual.

| Tanda | Contenido (puntos del pedido) | Commit | Estado |
|---|---|---|---|
| **T1** | Español latino en todos los textos (15), "pieza" → "estructura" (17), monos alfa: semanal 6 → 20 y diaria 2 → 8, con el ritmo de la calculadora corregido a 0,2/min (18) | `0c92957` | ✅ |
| **T2** | Trajes míticos (Rey Gorila, Jaguar Espectral, Serpiente Emplumada, Ceiba) por grado, hasta 543 piezas | 0b5c42f | ✅ Probado en Studio (sin probar: VERIFICACION §73) |
| **T2** | Menú del martillo compacto y confirmación al volver al Lobby (1), emotes de Dunas unificados (2), Armario en 3 columnas (3) | `e514e82` | ✅ (falta ver la ficha del martillo en el emulador de teléfono) |
| **T3** | No volver a comprar lo que ya tienes (5), mascotas únicas y Ámbar por repetida (12), regalar cosméticos (6) | `861d1d1` | ✅ (falta probar el regalo con 2 jugadores; perfil v9: publicar los 3 places a la vez) |
| **T4** | Panel de administración v2: eventos en vivo, anuncio global, dar a todos y más (4). En 5 sub-tandas: T4a base, T4b eventos, T4c moderación, T4d perfil y servidor, T4e admin jefe gigante | T4a `7070501` · T4b `064edae` · T4c `579f0a0` · T4d `32e0be8` · T4e `fb69ba0` | ✅ (falta probar "todos los servidores", un baneo real y el mantenimiento en el juego publicado, la franja de eventos en el teléfono y el gigante con 2 jugadores) |
| **T5** | Montura Jaguar Albino legendaria y patas del perro pirata (7, 11); montura Quetzalcóatl mítica (8). En 2 sub-tandas: T5a jaguar y perro, T5b Quetzalcóatl | T5a `d3cf7ac` · T5b `8053bb3` | ✅ (falta en el teléfono, con 2 jugadores, en el Lobby y publicado: VERIFICACION §14 y §15; remoto nuevo: publicar los 3 places a la vez) |
| **T6** | Bienvenida de pioneros con el calendario y la montura del ciclo de 7 días (9) | `dffa6f5` | ✅ (falta en el teléfono, sin ser pionero, una montura nueva y publicado: VERIFICACION §16; perfil v10: publicar los 3 places a la vez) |
| **T7** | Estilo nuevo para la V de cada rol, que el jugador elige (19) | `d02020f` | ✅ (faltan los efectos en pantalla, 2 jugadores, el teléfono y publicado: VERIFICACION §17; perfil v11: publicar los 3 places a la vez) |
| **T8** | Fase 12: seguir sobreviviendo y parcela permanente en el Basecamp (10); grupos P1–P6 (ver "Fase 12") | P1 `09bc809`, P2 `0757588`, P3 `509281c`, P4 `a648329`, P5 `d5ca5b9`, P6 `8f39c29` | ✅ (falta publicar los 3 places a la vez, perfil v12, y las pruebas de VERIFICACION §18) |
| **T9** | Diseño (solo documentos): Laboratorio en ruinas (13), isla de aventuras (14), juego en inglés (16). Ver "Diseños de T9" | `dcf513c` | ✅ (se construyen en las Fases 13 y 14 y la tanda I1) |

### Fase 12: Victoria y parcela permanente (octubre de 2026)

Tras ganar, la partida puede seguir, y el que gana por primera vez desbloquea una parcela permanente en el Basecamp que viaja con él a cualquier partida. Plan: `C:\Users\jose\.claude\plans\tender-beaming-planet.md`.

Decisiones del 27-10-2026:
- **Seguir sobreviviendo:** al amanecer del rescate se paga todo y se guarda. Cada jugador elige seguir o volver al Lobby (si no elige en 30 s, vuelve). El final de verdad solo paga los días, las bajas y los jefes extra, sin un segundo rescate. El récord de días cuenta el total. La dificultad sigue subiendo y los 4 jefes vuelven cada 2 días sin piezas de baliza. En cada vuelta salen más fuertes los que ya se derrotaron (con victoria o sin ella); uno que aún no se ha derrotado vuelve igual. Nadie nuevo entra en una partida ya ganada.
- **Parcela:** se desbloquea al ganar por primera vez (también para quien ya había ganado antes). Hay 5 huecos de unas 24×24 dentro de la empalizada, en lugar de los 20 pequeños. Al entrar, cada jugador ocupa uno y su parcela se reconstruye. Todos la ven, y solo el dueño la usa. Quien nunca ha ganado recibe un hueco vacío para su cama.
- **Estructuras:** forja, taller del curandero, huerto, cama, cofre, incubadora y nido, con 3 niveles (I/II/III) que se pagan con Ámbar y materiales del cofre. Dan ventajas pequeñas en la partida. El asedio las daña (dejan de funcionar hasta repararlas o hasta el amanecer), pero el nivel guardado nunca baja.
- **Cofre:** guarda materiales y consumibles, nunca equipo ni piezas de baliza. Se deposita en cualquier momento. La parte compartida la puede vaciar cualquiera de la partida, y lo que se coge va al inventario de la partida de quien lo coge. Retirar de la parte compartida guarda primero el perfil del dueño, para que no se pueda duplicar nada.
- Perfil v12 (`plot`): se introduce en P2, y los 3 places se publican a la vez.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **P1** | "Seguir sobreviviendo": cobro al ganar sin cobrar dos veces, botón y remoto `ChooseContinue`, jefes que vuelven y récord de días total | `09bc809` | ✅ (falta una victoria de verdad, 2 jugadores y publicado: VERIFICACION §18) |
| **P2** | Parcela: perfil v12 con migración, 5 huecos, desbloqueo al ganar con aviso y reconstrucción al entrar | `0757588` | ✅ (falta el asedio contra la parcela y 2 jugadores: VERIFICACION §18) |
| **P3** | Estructuras con 3 niveles (forja, taller, huerto, cama), sus efectos y la ventana "Parcela" | `509281c` | ✅ (precios de prueba, los fija P6; falta el asedio real, la cama al caer, 2 jugadores y el teléfono: VERIFICACION §18) |
| **P4** | Cofre privado y compartido, sin duplicar objetos | `a648329` | ✅ (falta coger de lo compartido con 2 jugadores, el juego publicado y el teléfono: VERIFICACION §18) |
| **P5** | Incubadora (acelera el nido del Lobby y en el nivel III da un segundo hueco) y nido de la parcela (vida y probabilidad de subir la rareza); los 4 fallos de los nidos y soltar el huevo | `d5ca5b9` | ✅ (falta que se vaya el dueño con 2 jugadores, la subida de rareza, el teléfono y el juego publicado: VERIFICACION §18) |
| **P6** | Costes y ritmo en `Economia` y el GDD | `8f39c29` | ✅ (precios 600 / 2.400 / 6.000: las 7 al III el día 46 el intenso y el 105 el grupo de amigos) |

### Diseños de T9 (27-10-2026): fases futuras

T9 dejó escritos tres diseños que se construirán más adelante, cada uno en su fase. Los grupos son tentativos: al empezar cada fase se hace una sesión de plan propia (`EnterPlanMode`) que los fija.

**Fase 13: Laboratorio en ruinas** (cuarto place, shooter por equipos sin roles). Diseño: [LABORATORIO.md](LABORATORIO.md), resumen en el GDD §12.3.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **L1** | Place nuevo (`laboratorio.project.json`, `Config.PlaceIds.Laboratorio`), `LabCombatRules`, las 4 armas (`Data/LabWeapons`) y la sección del Laboratorio en `Equilibrio`; primera persona (cámara fija, mira y arma en la cámara) | `93c848f` | ✅ (faltan el zoom con el clic derecho, 2 jugadores, el teléfono y publicar el place: VERIFICACION §24) |
| **L2** | Mapa Laboratorio central (`World/LabBuilder`) y el modo de duelo por equipos (con el selector de arma, que suelta el ratón de la primera persona) | `4da1592` | ✅ (faltan el ratón real, 2 jugadores, el teléfono, los resultados de Dunas y publicar el place: VERIFICACION §25) |
| **L3** | Cola con modo y formato (sobre `ArenaQueueService`), embarcadero y cartel del Lobby | `fdc3f7a` | ✅ (faltan 2 jugadores, el juego publicado y el teléfono real: VERIFICACION §26) |
| **L4a** | Todos contra todos y Rondas (cola del Lobby y Laboratorio central) | `bc72a45` | ✅ (faltan 2 jugadores, el cartel y el teléfono reales y el juego publicado: VERIFICACION §27) |
| **L4b** | Mapas Azotea de la torre y Alcantarillas; votación de mapa | `894f1c2` | ✅ (faltan 2 jugadores, el teléfono real, el juego publicado y las observaciones de diseño: VERIFICACION §28) |
| **L5a** | Recompensas: Ámbar con tope de 300, XP del pase, ranking, misión semanal y títulos; `Economia` y el GDD. Empieza a contar las bajas por arma | `3364413` | ✅ (faltan 2 jugadores, el perfil real y el teléfono: VERIFICACION §29) |
| **L5b** | Skins del Laboratorio por bajas: 12 modelos (4 armas × I/II/III), su dibujo combinado con el bando y la entrega de los grados ganados | `855a57e` | ✅ (faltan 2 jugadores, la vista, la calculadora y el juego publicado: VERIFICACION §30) |

**Handoff siguiente (28-10-2026)**

- **Estado:** la L5b está aprobada y hecha (`855a57e`, umbrales 50/250/1.000). La tabla de la Fase 13 no tiene L6: la L5b es el último grupo.
- **Sin probar:** VERIFICACION §30 (2 jugadores, la vista en el Studio y en el teléfono, la calculadora `Economia` y el juego publicado). Al publicar, los cuatro places a la vez, aunque el perfil siga en la versión 13.
- **Balance:** los umbrales de las skins por bajas bajaron el 28-10-2026 de 100/500/2.000 a 50/250/1.000 (decisión del usuario). Con una sola arma, el grado III tarda unos 42 días de calendario en el perfil intenso y unos 175 en el habitual (línea «Skins del Laboratorio» de `Economia`); repartidas entre las cuatro armas, cuatro veces más.
- **Qué sigue:** por decidir con el usuario. Candidatas del plan: la Fase 14 (Isla Calavera, grupo D1 con el place nuevo); la tanda I1 (inglés), con las pruebas pendientes de VERIFICACION §19 a §23; y las pruebas de la Fase 13 (VERIFICACION §24 a §30) con la publicación de los cuatro places.

**Fase 15: Movimiento y disparo** (plan aprobado el 28-10-2026, se hace antes de la Fase 14). Un solo sistema de movimiento para los cuatro places (andar 18, correr 26, deslizamiento, esquiva con efecto, animaciones propias), el shooter del Laboratorio completo (cargador, recarga, automático, dispersión, mira configurable, cabeza ×1,5), detección PvP con rebobinado, pantalla roja y espectador con killcam en Dunas y el Laboratorio. Cada grupo es una pestaña. Decisiones, arquitectura, orden y handoffs: `C:\Users\jose\.claude\plans\composed-tinkering-karp.md`.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **V1** | Movimiento unificado: `Movement` + `LocomotionController`, 18/26, modificadores, se borran las copias de Isla, Dunas y Laboratorio; Lobby sin gasto de stamina | 442e7a4 | ✅ Probado en los 4 places; pendiente VERIFICACION §31 |
| **V2** | Deslizamiento (C en el Laboratorio, Alt izquierdo en el resto, botón móvil) | 8873c3d | ✅ |
| **V3** | Esquiva con efecto: más recorrido, impulso, estela, FOV y primera persona | 87ea52f | ✅ |
| **V4** | Animaciones propias de andar, correr y deslizar | b5d9669 | ✅ |
| **V5** | Pantalla roja por crítico o golpe fuerte, pulso con salud baja y dirección del atacante | 317029a | ✅ Probado en la Isla; pendiente VERIFICACION §34 |
| **V6** | Ajustes en el Laboratorio y Dunas, y mira configurable | 2952f5c | ✅ (pendiente VERIFICACION §37) |
| **V7** | Detección PvP con rebobinado y críticos a la cabeza | f1bf8f7 | ✅ (pendiente VERIFICACION §36) |
| **V8** | Cargador, recarga, disparo automático y mira dinámica (Laboratorio) | 5dc4e36 | ✅ |
| **V9** | Animaciones, fogonazos y sonidos de disparo del Laboratorio | a3e5995 | ✅ |
| **V10** | Espectador y killcam en Dunas y el Laboratorio | e3903fa | ✅ |

**Fase 14: Isla Calavera** (quinto place, mazmorra PvE de 1 a 5). Diseño: [AVENTURAS.md](AVENTURAS.md), resumen en el GDD §7.2.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **D1** | Place nuevo (`calavera.project.json`, `Config.PlaceIds.Calavera`), `DungeonCombatRules`, entrada con grupo y cola, dificultades, caído y puntos de control | — | ⏳ |
| **D2** | Piso 1 entero: salas, variantes, trampas, acertijos, sala secreta y el Narigudo Carcelero | — | ⏳ |
| **D3** | Piso 2 y el Dril del Suero | — | ⏳ |
| **D4** | Piso 3 y el Gelada Rey Calavera | — | ⏳ |
| **D5** | Botín: huevo mítico (con el Quetzal y el Ajolote de la Fase 18, que llevan `origin = "HuevoMitico"` y no salen de huevos normales), set y armas de la Calavera como planos, cofre de llaves y tope semanal, en `Economia` | — | ⏳ |
| **D6** | Ranking de tiempo y la sección de la mazmorra en `Economia` y el GDD | — | ⏳ |

**Tanda "Idioma inglés"** (GDD §18, plan aprobado el 27-10-2026): `Shared/Strings` con el español como clave, el inglés revisado a mano en `Data/Strings/*` y todos los textos del código pasados a `T()` (también los que llevan números dentro). Al terminar la I1e, el usuario cambia el idioma de origen a inglés en Creator Hub, sube `build/localization_*.csv` uno a uno (90 filas cada uno: Creator Hub se corta hacia las 100) y activa la traducción automática. Cada parte cierra con una página de revisión es | en.

| Tanda | Contenido | Commit | Estado |
|---|---|---|---|
| **I1a** | Base: `Shared/Strings`, `UI/Localizer` (carteles, `ProximityPrompt`, herramientas), ajuste de idioma, `Notify` con argumentos, `tools/strings.py` en el CI; la UI de `src/shared` y `CombatClient` | cc56baa | ✅ |
| **I1b** | La Isla: `src/island/**` (HUD, Basecamp, crafteo, misiones, faro, sus `Notify`) | a8d38c8 | ✅ |
| **I1c** | El Lobby y `serverShared`: `src/lobby/**`, carteles de `LobbyBuilder`, pase, compras, retención, moderación | cec2cfd | ✅ |
| **I1d** | Dunas y el combate: `src/dunas/**`, `src/combat/**` (`ArenaBuilder` no tiene carteles con texto) | 63186da | ✅ (sin probar en Studio: `VERIFICACION.md` §22) |
| **I1e** | El contenido de `Data/*` (nombres y descripciones) y el CSV para Creator Hub | e849fd8 | ✅ (sin probar en la Isla, el teléfono ni publicado: `VERIFICACION.md` §23) |

### Fase 16: Presupuesto de piezas y rendimiento (28-10-2026)

Para que el pase y los cosméticos valgan la pena hay que subir la calidad de los modelos, y antes hay que saber hasta dónde. Hoy el presupuesto de piezas solo está escrito en la skill `modelos-3d-roblox` (§6) y ningún código lo cuenta. Plan: `C:\Users\jose\.claude\plans\polymorphic-sleeping-sifakis.md`.

Decisiones del 28-10-2026:
- Presupuestos en `Config.Budgets`, calculadora `Rendimiento` y medición en vivo en el panel de administración.
- Fusión greedy de bloques vecinos del mismo color (`Shared/VoxelMerge`), más topes ×1,5 para los cosméticos. Los monos y jefes siguen con su UnionAsync.
- Dispositivo de referencia: móvil de gama baja (3–4 GB) a 30 FPS estables en la peor escena.
- LOD de detalle para los cosméticos de los demás jugadores, y efectos de jefe escalados por calidad.
- Línea base (R1): la fusión ahorra poco en armas y armaduras (0–10 piezas, ≈5 %) y 8 piezas en Mono X-7. La calidad extra llegará con los topes ×1,5, y la fusión de R3 se conecta igualmente. R4 pasa a opcional: solo se hace si la calculadora ahorra más de ~10 %.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **R1** | `Config.Budgets` con sus excepciones por id (Mono X-7, Nido, Tótem de guerra, Orangután del Manglar; Laboratorio con skin hasta 200), `Shared/VoxelMerge` (aún sin conectar), calculadora `Rendimiento` con la línea base, §6 de la skill, `CLAUDE.md` y `docs/llm-local` | 175d1dd | ✅ Probado en Studio |
| **R2** | Medición en vivo: `Performance` y la pestaña "Rendimiento" del panel de administración, en los 4 places | 5feb41d | ✅ Probado en Studio (sin probar: VERIFICACION §41) |
| **R3** | Fusión de lo estático: armas de la forja y del Laboratorio, armaduras, `RewardModels`, construibles y parcela | 8cd2ae9 | ✅ Probado en Studio (sin probar: VERIFICACION §42) |
| **R4** (opcional) | Fusión de lo animado: mascotas por firma de articulación y monturas por hueso. Solo si la calculadora ahorra más de ~10 %; las tiras de poses se comparan con la skill `animaciones-roblox` | — | ✅ Medido el 28-10-2026, no compensa y no se conecta: mascotas 2.036→2.022 (0,7 %), monturas 830→829, y las piezas que se mueven por fotograma no bajan en ninguna. Riesgo alto para la animación (`PetModels.animate`, `rig.joints`, `bend`) |
| **R5** | LOD de detalle (`DetailLodController`) y su sección en la calculadora (Lobby con 20 jugadores) | fac26ff | ✅ Probado en Studio con la calculadora (sin probar: VERIFICACION §43) |
| **R6** | Efectos de los jefes: `combatClient/BossFx` con un pool en lugar de `Debris`, una firma visual para cada uno de los 4 jefes (mini-entrevista antes) y la lluvia de rocas y la bomba de lava dibujadas en el cliente | a7a5a3d | ✅ Probado en Studio (sin probar: VERIFICACION §44) |
| **R7** | Prueba en un teléfono con los places publicados (asedio, Dunas 5v5, Lobby con 20); después se ajustan los topes de `Config.Budgets` y `docs/RENDIMIENTO.md` | — | ⏳ |

**Handoff de R6 (28-10-2026)**

- **Estado:** R1, R2, R3 y R5 commiteadas y subidas (R5 `fac26ff`). R4 medido y descartado (no se conecta). Sin probar de R5: VERIFICACION §43 (2 jugadores, teléfono).
- **Antes de escribir código: mini-entrevista al usuario** sobre el estilo visual de cada uno de los 4 jefes (firma propia de cada uno). Con `AskUserQuestion`, y después se decide.
- **Objetivo:**
  - `combatClient/BossFx.luau` con funciones puras `(parent, quality, …)` para que la calculadora cuente el pico, y un pool de piezas en lugar de `Debris`.
  - Una firma visual propia para cada jefe, con mejor aspecto, escalada por calidad (Bajo 40, Medio 90, Alto 160 piezas de pico por cliente: `Config.Budgets.Vfx`).
  - La lluvia de rocas y la bomba de lava pasan a dibujarse en el cliente; el servidor se queda con el daño y los avisos.
  - `FxQuality`: lee `UserGameSettings.SavedQualityLevel` (1–3 Bajo, 4–7 Medio, 8–10 Alto); en Automático, Medio en PC y Bajo en táctil sin teclado. Opción nueva «Efectos» (Auto/Bajo/Medio/Alto) en `Settings`, que manda sobre la detección. Textos por `Strings.t` con su inglés.
  - Calculadora `Rendimiento`, sección 9: contar el pico de cada jefe en las tres calidades y alertar si pasa de `Config.Budgets.Vfx`.
- **Punto de partida:** hoy el pisotón de un jefe crea 190–250 piezas temporales por cliente, sin pool ni escala por calidad. Localiza con `search` dónde se crean (Isla: `AbilityFxController`, los módulos de jefes de `island/server/Monkeys`, `Debris`).
- **Riesgos:**
  - Los telegraphs y avisos de daño no pueden depender de la calidad: la calidad Baja tiene que seguir mostrando el área de peligro (regla de legibilidad del combate; skill `combate-roblox`).
  - Colores con significado: rojo daño recibido, verde solo curación, morado veneno.
  - Al pasar la lluvia de rocas y la bomba de lava al cliente, el servidor debe seguir mandando la posición y la hora para que todos vean lo mismo y el daño coincida con el dibujo.
  - Modelos y efectos voxel (bloques con pocos tonos planos); las 4 firmas tienen que distinguirse entre sí a primera vista.
- **Verificación:** `Rendimiento` (pico por jefe y calidad dentro de `Budgets.Vfx`, 0 alertas); Play con copia previa de `PlayerData_v1`: las 4 peleas de jefe en las 3 calidades, cambiar la opción «Efectos»; capturas pocas y pequeñas. Lo que no se pueda probar (teléfono, 2 jugadores), a `VERIFICACION.md` como sección nueva (siguiente: §44).
- **Flujo:** `search` localiza, `programador` escribe `BossFx` ya especificado, `probador-studio` mide y prueba, `documentador` hace el papeleo; capturas y juicio visual en la sesión principal. Commit solo con «aprobado».
- **Prompt para la pestaña nueva:** «Continúa la Fase 16 de Monkey_Island_2026 con el grupo R6 (efectos de los jefes). Lee CLAUDE.md, la sección "Fase 16" de docs/PLAN.md (su Handoff de R6) y C:\Users\jose\.claude\plans\polymorphic-sleeping-sifakis.md. Empieza con la mini-entrevista sobre el estilo de cada jefe y sigue el flujo del Handoff.»
- **Nota de cierre (28-10-2026, sin commit):** hecho `BossFx` con pool, `FxQuality` y la opción «Efectos de los jefes» en Ajustes, el remoto `BossFx`, y `Hazards` sin piezas de servidor (rocas, lava y onda se dibujan en el cliente). Picos medidos con `Rendimiento` (piezas por cliente en Bajo/Medio/Alto): Chimpancé 40/90/160, Ceniza 35/84/154, Albino y Orangután 16/50/100, 0 alertas. Prueba en Play: llegan el pisotón del Orangután real y 3 bombas de LavaBomb, con pico 36 en Medio, sin errores en la consola. El aspecto de las firmas solo se vio en el pisotón del Albino (las capturas caen en la fase de aviso y el jugador tapa el efecto); el resto, en VERIFICACION §44. R6 no está cerrada del todo: falta el «aprobado» y §44. R7 sigue pendiente.

**Pendiente para fases futuras:** subir la calidad de los cosméticos del pase (trajes, skins de arma y de mascota) y de las armas del Laboratorio con el nuevo presupuesto. Se planeará cuando la Fase 16 haya fijado los topes.

### Fase 17: Armas del Laboratorio y sus skins, con más calidad (28-10-2026)

Las armas del Laboratorio parecían de juguete, no se distinguían entre sí y las skins no impresionaban. Se rehace **un arma por grupo**: la base de los dos bandos y sus 3 skins juntas, porque las skins se apoyan en la geometría de la base. Plan completo en `C:\Users\jose\.claude\plans\federated-meandering-key.md`.

Reglas: voxel con pocos tonos planos; silueta propia de cada arma; base de hasta 45 piezas tras fusionar y skins de hasta 200 (`Config.Budgets.Models`); cada grado se distingue a primera vista; los rasgos del grado III tienen que verse también en primera persona, porque lo de la espalda (`LabBack`) se esconde ahí. Sin superficies en el mismo plano (parpadean al mover la cámara). Antes de pedir el «aprobado», la vista previa queda montada en el Studio del Laboratorio.

| Grupo | Arma y skins | Commit | Estado |
|---|---|---|---|
| **W1** | Lanzadardos tranquilizante (subfusil compacto) y Avispa I/II/III | 13decf9 | ✅ Probado en Studio (sin probar: VERIFICACION §45) |
| **W2** | Rifle de bananas primales (francotirador) y Escorpión I/II/III | dc0d298 | ✅ Probado en Studio (sin probar: VERIFICACION §46) |
| **W3** | Lanzarredes de arpón (escopeta corta) y Kraken I/II/III | 9e28871 | ✅ Probado en Studio (sin probar: VERIFICACION §47) |
| **W4** | Cañón de suero ácido (lanzagranadas) y Dragón I/II/III, y las 4 armas juntas | 184027a | ✅ Probado en Studio (sin probar: VERIFICACION §48) |

**Fase 17 cerrada (28-10-2026).** Las 4 armas del Laboratorio y sus 12 skins están rehechas. Lo que queda sin probar está en VERIFICACION §45–48.

- **Trampa de W4:** al clonar `Shared` para la vista previa, `LabWeaponModels` sigue cargando `LabWeaponSkins` por la ruta original y enseña skins viejas. Se evita renombrando `Shared` a `SharedOrig` y el clon a `Shared` mientras se construye, y devolviendo el nombre después.
- **Cañón de suero:** 35 (Guardianes) y 40 (Piratas) piezas; Dragón III 132 y 136. Las skins I y II quedaron algo por debajo de la escalera (+29 y +47), con margen hasta 200 si se quiere más detalle.
- **Pendiente:** `Rendimiento` sección 6 (Studio de la Isla) y las pruebas en Play de VERIFICACION §45–48.

### Fase 18: Pedidos del 28-10 (arreglos, admin, eventos globales, Laboratorio, ambiente, mascotas, armaduras) (29-10-2026)

Doce pedidos del usuario más el sentir del Laboratorio (dinamismo, puntería, deslizar y esquivar), agrupados en 16 tandas que se trabajan en pestañas distintas, cada una con su handoff. Plan completo en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`.

Decisiones del 28-10-2026:
- **Gigante:** el que falla es el gigante al golpear cuerpo a cuerpo (su caja de golpe no crece con su tamaño).
- **Globales:** el gigante y el jefe se invocan en los 4 places. Fuera de la Isla el jefe da Ámbar y XP del pase a quienes le hagan daño (cantidades medidas con `Economia`). Clima, fiesta y lluvia de huevos siguen como están.
- **Menús en combate:** se ocultan 4 s tras hacer o recibir daño. Reanimar sigue disponible.
- **Luna:** 4 fases, una cada 2 días de partida, efectos suaves (10–15 %). La luna roja es un evento en vivo global con horda y premio.
- **Mascotas:** capibara (Poco común), quetzal y ajolote (Míticos). Los míticos no salen de huevos normales: se dan desde el panel de admin y entran al sorteo con el huevo mítico de la Fase 14 (D5).
- **Armaduras:** una tanda por rango, con los 4 roles.
- **Laboratorio:** la estela del esquive solo la ve el rival (uno ve líneas blancas de movimiento en primera persona); deslizar con C sin tener que correr, con aviso de la tecla y animación visible para los demás; mira precisa y balas más visibles.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **A1** | Textos en latino de los contratos, menús bloqueados 4 s en combate, caja de golpe del gigante | 1887267 | ✅ Probado en Studio (sin probar: VERIFICACION §49) |
| **A2** | Panel de admin: premium en el perfil, jefe junto al admin con aviso global, tablero con activar/desactivar, mantenimiento único y cancelable | 72203eb | ✅ Probado en Studio (sin probar: VERIFICACION §50) |
| **A3** | Gigante en los 4 places, con vida según jugadores activos | 457e24a | ✅ Probado en Studio con 1 jugador (sin probar: VERIFICACION §51) |
| **A4** | Jefe en los 4 places, con premio fuera de la Isla (permitir elegir que jefe invocar)| 344963e | ✅ Probado en Studio (sin probar: VERIFICACION §52) |
| **L1** | Laboratorio: mira precisa, balas visibles, poses al apuntar y disparar | 3509ba1, fafd564 | ✅ Probado en Studio (sin probar: VERIFICACION §53) |
| **L2** | Laboratorio: deslizar con C, estela solo para el rival y líneas blancas de movimiento | 7fe633a | ✅ Probado en Studio (sin probar: VERIFICACION §54) |
| **B1** | Iluminación del amanecer y el atardecer, curva del día y la noche | 9a40a19 | ✅ Probado en Studio (sin probar: VERIFICACION §55) |
| **B2** | Ciclo lunar: fases, efectos y su icono | de653ef | ✅ Probado en Studio (sin probar: VERIFICACION §56) |
| **B3** | Evento de luna roja | a65adfe | ✅ Probado en Studio (sin probar: VERIFICACION §57) |
| **M1** | Capibara (Poco común) | 8e91b46 | ✅ Probado en Studio (sin probar: VERIFICACION §58) |
| **M2** | Quetzal (Mítico) | 8f7c4f0 | ✅ Probado en Studio (sin probar: VERIFICACION §59) |
| **M3** | Ajolote (Mítico), con clips de la capibara, el ajolote y el quetzal | 88779ff | ✅ Probado en Studio (sin probar: VERIFICACION §60) |
| **M4** | Clips propios para las mascotas antiguas (reposo, correr, andar) | 19ce22d | ✅ Probado en Studio y en Play por el usuario (VERIFICACION §61) |
| **R1** | Armaduras de Pelaje (rango I), 4 roles | 9eaed8a | ✅ Probado en Studio (sin probar: VERIFICACION §62) |
| **R2** | Armaduras de Hueso (rango II), 4 roles | f32b4db | ✅ Probado en Studio (sin probar: VERIFICACION §63) |
| **R3** | Armaduras de Plata (rango III), 4 roles | fb1ffa1 | ✅ Probado en Studio (sin probar: VERIFICACION §64) |
| **R4** | Armaduras Volcánicas (rango IV), 4 roles | 6c4425b | ✅ Probado en Studio (sin probar: VERIFICACION §65) |
| **S1** | Armas de la forja de rango I (Machete, Honda, Garrote, Arco, Cerbatana, Bastón), con tope `ForgeWeaponRank` | 343054f | ✅ Probado en Studio (sin probar: VERIFICACION §66) |
| **S2** | Armas de la forja de rango II (Machete afilado, Honda de liana, Maza de hueso, Arco reforzado, Cerbatana de hueso, Bastón dorado) | e8217ed | ✅ Probado en Studio (sin probar: VERIFICACION §67) |
| **S3** | Armas de la forja de rango III (Maza gruesa, Arco de liana, Cerbatana de chamán, Bastón de plata) | ec6435a | ✅ Probado en Studio (sin probar: VERIFICACION §68) |
| **S4** | Armas de la forja de rango IV (Maza volcánica, Arco de ascuas, Cerbatana de azufre, Bastón de lava) | 9f3a7c5 | ✅ Probado en Studio (sin probar: VERIFICACION §69) |
| **K1** | Skins de temporada Sulfur (Maza, Arco, Bastón, Cerbatana, Machete) por nivel, con topes `WeaponSkinEpic` 125 y `WeaponSkinRare` 70 | e93482a | ✅ Probado en Studio (sin probar: VERIFICACION §70) |
| **K2** | Skins míticas de arma (Rey Gorila, Jaguar Espectral, Serpiente Emplumada, Ceiba) por nivel, hasta 160 piezas | 41207ad | ✅ Probado en Studio (sin probar: VERIFICACION §71) |
| **T1** | Trajes legendarios del pase (Fuego Azul, 4 roles) por grado, hasta 345 piezas, con tope `OutfitLegendaryGrade4` 350 | f7be041 | ✅ Probado en Studio (sin probar: VERIFICACION §72) |

**Handoff de A1 (29-10-2026)**
- **Estado:** plan aprobado, nada escrito todavía. Las pruebas de la fase empiezan en VERIFICACION §49.
- **Objetivo:** (1) `Levantad`/`Recolectad` pasan a `Levanten`/`Recolecten` en `Data/Contracts.luau` (líneas 71, 97, 126) y en las claves de `Data/Strings/Content.luau` (148, 154, 159); luego `python tools/strings.py --csv-nuevas` y `--marcar-subidas`. (2) Atributo de jugador `CombatUntil` = ahora + `Config.Combat.InteractLockSeconds` (4), puesto al recibir daño (`SurvivalService`, junto a `lastDamagedAt`) y al hacerlo (`CombatService.damage` / `damagePvP`); un helper en `Shared` que lo lee y que usan los `ProximityPrompt` de estaciones (`CraftingController`, 303–332), cofres, parcela y beber; reanimar no se bloquea. (3) La caja de `CombatService.meleeAttack` (`MELEE_HITBOX`, líneas 70 y 588–604) y su copia en `combatClient/Controllers/WeaponController.luau` (62, 262–263) se escalan con el tamaño del personaje y el alcance empieza en el borde del cuerpo.
- **Riesgo:** a escala 1 nada debe cambiar; se comprueba con `Equilibrio`. El helper del cliente y el servidor tienen que usar el mismo reloj (`workspace:GetServerTimeNow()`).
- **Verificación:** pelear junto a la hoguera no abre el menú y 4 s después sí; el gigante acierta a un muñeco con la espada; stylua, selene, `strings.py` y `rojo build`. Lo que necesite 2 jugadores va a VERIFICACION §49.
- **Flujo:** probar en Studio, commit tras «aprobado», push y fila de `PLAN.md` en un commit aparte.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de A1, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo A1.»

**Handoff de A2 (29-10-2026)**
- **Estado:** A1 cerrada y subida (1887267). A2 sin empezar. Siguiente número libre de VERIFICACION: §50.
- **Antes de escribir código:** pide al agente `search` el mapa de `serverShared/Admin.luau`, `AdminEventsService`, `LiveEventsServer`, `ServerOps`, `AdminProfile`, `Data/IslandActions` y `UI/AdminPanel` (1077–1315). Este handoff se escribió con un mapa de otra sesión: comprueba las líneas.
- **Objetivo:**
  1. **Premium en el perfil:** `serverShared/AdminProfile.luau` (68–98 y 153–175) añade «Pase premium: sí/no» con `SeasonPass.normalize(data.season, temporada actual)`, no leyendo `season.premium` a pelo, para que no cuente el de una temporada vieja.
  2. **Jefe junto al admin:** `AdminEventsService` (77–81) pasa la posición del admin a `BossService` (318–320), que hoy lo saca en su guarida y borra el jefe que hubiera. El aviso llega a todos los servidores por `AdminNet` («Announce» con jefe, place y servidor).
  3. **Tablero «Ahora en la Isla» → «Ahora en el juego»** (`UI/AdminPanel.luau` 1284–1305, `Data/IslandActions`): cada acción activa/desactiva y se pinta resaltada si está en marcha (jefe vivo, clima, erupción, gigante). El servidor publica el estado en un atributo.
  4. **Mantenimiento** (`ServerOps.maintenance`, 84–103): rechaza uno nuevo si ya hay uno programado o en marcha; la pestaña Servidor enseña el programado (hora y mensaje) con un botón de cancelar que llama a `LiveEventsServer.stop` y manda un aviso global «Mantenimiento cancelado». `LiveEventsServer.start` (116–142) deduplica por id los eventos que no deben apilarse.
- **Riesgos:** el panel se queda en español, pero los avisos que ven los jugadores (jefe, mantenimiento) pasan por `Strings`. El mantenimiento echa a los jugadores: probar solo cancelándolo a tiempo y con los admins exentos. Nada de esto toca el combate.
- **Verificación:** en Play, un segundo mantenimiento se rechaza y el programado se cancela; el jefe aparece junto al admin; el perfil dice si hay premium. Lo que necesite 2 servidores o 2 jugadores (avisos entre servidores) va a VERIFICACION §50.
- **Flujo:** probar en Studio con `probador-studio` (copia de perfil antes), commit tras «aprobado», push y fila de `PLAN.md` en un commit aparte.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de A2, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo A2.»

**Handoff de A3 (29-10-2026)**
- **Estado:** A2 cerrada y subida (72203eb). A3 sin empezar. Siguiente número libre de VERIFICACION: §51. El tablero ya publica `Config.AdminTools.IslandStateAttribute` (JSON con `Giant`) y `Ser gigante` es un interruptor.
- **Antes de escribir código:** pide al agente `search` el mapa de `GiantAdminService` (y su controlador de cliente), `Admin.luau` (`onIslandAction`), `BossService` (vida según jugadores) y las reglas de zona segura de cada place (`CombatRules`: Lobby, Dunas, Laboratorio).
- **Objetivo:** ver la tanda A3 del plan (`GiantAdminService` a `src/combat/Services`, vida según jugadores activos, zona segura del Lobby suspendida, neutral en Dunas y Laboratorio, `Admin.luau` sin restringir a la Isla).
- **Riesgo:** `AdminEventsService` (solo Isla) llama a `GiantAdminService.toggle`; al moverlo, la acción «Giant» debe llegar en los 4 places. El atributo de jugador `AdminBoss` lo lee `publishState`.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de A3, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo A3.»

**Handoff de A4 (29-10-2026)**
- **Estado:** A3 cerrada y subida (457e24a). A4 sin empezar. Siguiente número libre de VERIFICACION: §52. `GiantAdminService` (ahora en `src/combat/Services`) es el patrón: reglas del place envueltas en `Start`, `setHooks` para lo que solo existe en la Isla, vida por jugadores activos (`countFighters`/`rescaleHealth`), `Hazards` ya en `src/combat`, `BossHUDController` ya en `combatClient`, y `AdminNet.on` admite varios manejadores.
- **Antes de escribir código:** pide al agente `search` el mapa de las dependencias de `BossService` con servicios de la Isla (biomas, guaridas, `BasecampService`, `MonkeyAnimator`, `Beacon`, telemetría, `MatchStats`, botín) y de `ACTIONS.Boss` en `AdminEventsService`.
- **Objetivo:** ver la tanda A4 del plan, más lo que anotó el usuario: poder elegir qué jefe invocar. Premio fuera de la Isla (Ámbar y XP del pase) medido con `Economia` y guardado en `Config`; zona segura del Lobby suspendida durante el combate.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de A4, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo A4.»

**Handoff de L1 (29-10-2026)**
- **Estado:** A4 cerrada en Studio, con el commit y la subida pendientes de «aprobado». Siguiente número libre de VERIFICACION: §53.
- **Antes de escribir código:** pide al agente `search` el mapa de `FirstPersonController` (406–481), la dispersión y el bloom, la ayuda de puntería, las trazadoras y las poses del Laboratorio. Comprueba las líneas: este handoff se escribe sin haber leído el código.
- **Objetivo:** ver la tanda L1 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección L1):
  1. **Mira precisa:** revisar la dispersión y su crecimiento al disparar seguido (bloom), la ayuda de puntería (estrecha, como pide la memoria) y el retroceso. El primer tiro va exacto al centro, y la dispersión solo aparece con ráfagas o al moverse. Se mide con `Equilibrio`. Mira dinámica que se abre y se cierra, y marca de impacto.
  2. **Balas visibles:** trazadoras más gruesas y brillantes, fogonazo en la boca del arma e impacto en la superficie, para el que dispara y para el rival.
  3. **Poses al apuntar y disparar:** `AnimationTrack` nuevas (skill `animaciones-roblox`). Las publica el usuario.
- **Verificación:** `stylua --check src`, `selene src`, `python tools/strings.py` y `rojo build` de los 4 places. En Play con `probador-studio`: el primer tiro sale al centro, las trazadoras y el fogonazo se ven. Lo que necesite 2 jugadores o el juego publicado va a VERIFICACION §53.
- **Flujo:** probar en Studio, commit tras «aprobado», push y fila de `PLAN.md` en un commit aparte.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de L1, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo L1.»

**Handoff de L2 (29-10-2026)**
- **Estado:** L1 cerrada y subida (3509ba1). L2 sin empezar. Siguiente número libre de VERIFICACION: §54. Las poses de L1 (rifle, arpón y cañón) ya están publicadas y enlazadas (fafd564); además se añadió la pista `HeadSteady` que deja la cabeza quieta al andar (967593d).
- **Antes de escribir código:** pide al agente `search` el mapa de `Slide` (`Slide.tryStart`, `Config.Movement.Slide`), `CombatService.onSlide` y el atributo `SlidingUntil`, `BodyAnimations` (la animación «Slide» en clientes remotos), `AbilityFxController` «DodgeFx» y el Laboratorio (`FirstPersonController`, `LabCombatRules`). Comprueba las líneas: este handoff se escribe sin haber leído el código.
- **Objetivo:** ver la tanda L2 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección L2):
  1. **Deslizarse con C sin correr:** `Slide.tryStart` funciona sin correr, con una versión más corta (`Config.Movement.Slide` o una regla del Laboratorio en `CombatRules`). Aviso de la tecla «C» en el HUD (texto por `T()`).
  2. **Que los demás vean la animación «Slide»:** averiguar por qué no la ven (`BodyAnimations` en el cliente o el atributo `SlidingUntil` que publica `CombatService.onSlide`). Si hace falta, reproducirla en los clientes remotos al leer el atributo.
  3. **Esquive:** la estela («DodgeFx») no se dibuja para uno mismo en primera persona; los rivales sí la ven.
  4. **Líneas blancas de movimiento** en pantalla (primera persona) al esquivar, al deslizarse y al correr rápido: un `ScreenGui` en el cliente, con la paleta de `interfaz-roblox`.
- **Riesgos:** el deslizamiento es combate compartido: lo nuevo solo para el Laboratorio, sin cambiar la Isla ni Dunas (comprobar con `Equilibrio` y a escala normal). En el Laboratorio el viewmodel no usa `AnimationTrack` (ver L1), así que la animación remota es la del personaje. Las líneas blancas no usan verde ni morado.
- **Verificación:** `stylua --check src`, `selene src`, `python tools/strings.py` y `rojo build` de los 4 places. En Play con `probador-studio` en el Laboratorio: deslizar con C sin correr, estela invisible en primera persona, líneas blancas. Que el rival vea el deslizamiento y la estela necesita 2 jugadores: va a VERIFICACION §54.
- **Flujo:** probar en Studio, commit tras «aprobado», push y fila de `PLAN.md` en un commit aparte.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de L2, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo L2.»

**Handoff de B1 (29-10-2026)**
- **Estado:** L2 cerrada y subida (7fe633a, PLAN 4f334a8). B1 sin empezar. Siguiente número libre de VERIFICACION: §55.
- **Antes de escribir código:** pide al agente `search` el mapa de `island/client/Controllers/LightingController`, `island/server/Services/DayNightService` (fases, `ClockTime`, salto de velocidad al cambiar de fase), `WeatherService` (lo que toca de la luz) y lo que haya de iluminación en `Config`. Comprueba las líneas: este handoff se escribe sin haber leído ese código.
- **Objetivo:** ver la tanda B1 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección B1):
  1. **`Config.Lighting`:** una curva en función de `ClockTime` de `Ambient`, `OutdoorAmbient`, `Brightness`, `ColorShift`, `Atmosphere` y un `ColorCorrection` base. La noche queda legible y en el amanecer y el atardecer no hay un apagón.
  2. **`LightingController`:** interpola la curva en cada fotograma y quita el salto de velocidad al cambiar de fase.
  3. Los pesos de la luna (B2) se enganchan después a esta curva: deja un sitio claro para ellos.
- **Riesgos:** el clima, la erupción y la luna roja (B3) también tocan la luz: la curva es la base y ellos se suman encima, sin pelearse. Los carteles y la linterna no pueden depender de la fase. Lo generado en el place (Lighting, Atmosphere) se guarda en el place, no en el repo.
- **Verificación:** `stylua --check src`, `selene src`, `python tools/strings.py` y `rojo build` de los 4 places. En el Studio de la Isla, con `SkipPhase` o fijando `ClockTime`, capturas a las 5:30, 6, 6:30, 17:30, 18, 18:30 y 0 (pocas y pequeñas; cámara de edición en `Fixed` al final). Lo que necesite el juego publicado o dos jugadores va a VERIFICACION §55.
- **Flujo:** probar en Studio, commit tras «aprobado», push y fila de `PLAN.md` en un commit aparte.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de B1, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo B1.»

**Handoff de B2 (29-10-2026)**
- **Estado:** B1 cerrada y subida (9a40a19, PLAN 75ab7ed). B2 sin empezar. Siguiente número libre de VERIFICACION: §56.
- **Antes de escribir código:** pide al agente `search` el mapa de `island/server/Services/DayNightService` (donde se escribe `MatchDay`), de dónde salen la detección de los monos, el daño y el botín de los monos, el crecimiento de las plantas y la bajada de hambre y sed, y cómo dibuja el cielo la luna (el `Sky` del place y `MoonAngularSize`). Comprueba las líneas: este handoff se escribe sin haber leído ese código.
- **Objetivo:** ver la tanda B2 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección B2):
  1. **Fase de la luna:** `fase = floor((MatchDay-1)/2) % 4` (Nueva, Creciente, Llena, Menguante), en el atributo `MoonPhase` de `ReplicatedStorage`, escrito por `DayNightService`.
  2. **Efectos** en `Config.Moon` (del 10 al 15 %), medidos con `Equilibrio` y `Economia`: Nueva = noche más oscura y monos que detectan desde menos distancia; Creciente = plantas un 15 % más rápidas; Llena = monos con +10 % de daño y un 15 % más de botín; Menguante = hambre y sed un 10 % más lentas.
  3. **Visual:** tamaño y textura de la luna según la fase, y su peso en la curva de luz: se engancha en `adjust` de `LightingController` (B1 dejó ahí el sitio).
  4. **Interfaz:** icono de la fase junto al reloj, con su descripción (skill `interfaz-roblox`). Un icono, una sola cosa: no repetir el emoji de otro objeto.
- **Riesgos:** la luna roja (B3) se sumará encima de la fase: deja un sitio claro. El botín extra de la fase Llena no puede dar Ámbar (regla de pago de `Economia`). Los textos nuevos pasan por `T()` y llevan su inglés; al cerrar, `strings.py --csv-nuevas` y `--marcar-subidas`.
- **Verificación:** `stylua --check src`, `selene src`, `python tools/strings.py` y `rojo build` de los 4 places. `Equilibrio` y `Economia` en el Studio de la Isla (modo edición, con `Clone`). En Play con `probador-studio`: fase de la luna con `SkipPhase` y capturas de la luz y del icono. Lo que necesite el juego publicado o dos jugadores va a VERIFICACION §56.
- **Flujo:** probar en Studio, commit tras «aprobado», push y fila de `PLAN.md` en un commit aparte.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de B2, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo B2.»

**Handoff de B3 (29-10-2026)**
- **Estado:** B2 cerrada y subida (de653ef). B3 sin empezar. Siguiente número libre de VERIFICACION: §57.
- **Antes de escribir código:** pide al agente `search` el mapa de `Data/LiveEvents` y `LiveEventsServer` (cómo se define y se activa un evento global), el tablero «Ahora en el juego» de A2 (`AdminPanel`, `IslandActions`, `AdminEventsService`), el asedio nocturno de `SiegeService` (hordas, vida y daño) y el reparto de Ámbar y botín de la partida. Comprueba las líneas: este handoff se escribe sin haber leído ese código.
- **Objetivo:** ver la tanda B3 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección B3): evento en vivo `RedMoon`, global, con botón de activar y desactivar en el tablero de A2. En la Isla: cielo rojo, horda nocturna (más monos, +X % de vida y daño) y doble botín y Ámbar de partida. En el Lobby, Dunas y el Laboratorio: solo cielo rojo y aviso. Los números se miden con `Equilibrio` y `Economia`.
- **Ya hecho en B2:** `Config.Moon.RedMoonTexture` tiene la imagen de la luna roja; `LightingController.adjust` es el sitio donde sumar el cielo rojo después de la fase; la fase de la luna sigue activa debajo de la roja.
- **Riesgos:** el Ámbar doble es una recompensa, no un producto: la regla de pago de `Economia` tiene que seguir en verde. El cielo rojo debe verse también en los places sin ciclo de día (no tienen el `LightingController` de la Isla).
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de B3, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo B3.»

**Handoff de M1 (29-10-2026)**
- **Estado:** B3 cerrada y subida (a65adfe). M1 sin empezar. Siguiente número libre de VERIFICACION: §58. B3 arregló los ids de la luna (eran de Decal, no de imagen): para cualquier imagen en un `Sky` o un `ImageLabel`, comprueba que el id es de imagen.
- **Antes de escribir código:** pide al agente `search` el mapa de `Data/Pets.luau` (campos de una mascota, emojis ya usados), `PetModels.voxelBuilders` y `CLIPS`, `PetRoll.petsOfRarity` y los topes `PetTotal`/`PetAnimated` de `Config.Budgets`. Comprueba las líneas.
- **Objetivo:** ver la tanda M1 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección M1): Capibara, mascota Poco común, con la skill `modelos-3d-roblox` y la referencia voxel «Capibara Voxel.jfif» de `docs/img`. Base: un cuadrúpedo nuevo. Entra solo al sorteo Uncommon.
- **Riesgos:** un icono, una sola cosa. Medir con `Rendimiento` (topes 240 y 110). Dejar el modelo de vista previa y la cámara en Studio antes de pedir el «aprobado».
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de M1, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo M1.»

**Handoff de M3 (29-10-2026)**
- **Estado:** M1 (8e91b46) y M2 (8f7c4f0) cerradas y subidas. M3 sin empezar. Siguiente número libre de VERIFICACION: §60. El CSV de textos nuevo está en `build/localization_nuevas.csv` (4 filas de M1 y M2): el usuario lo sube y después `strings.py --marcar-subidas`.
- **Antes de escribir código:** no hace falta mapa nuevo. Patrón: `Data/Pets.luau` (el Quetzal, con `origin = "HuevoMitico"`, y la Capibara), un constructor en `PetModels.voxelBuilders` (`voxelKit`; plantilla de cuadrúpedo: Capibara; de anfibio: Rana), `Data/Strings/Content.luau` (nombre y descripción con su inglés) y `PetRoll` (ya excluye lo que tiene `origin`).
- **Objetivo:** ver la tanda M3 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`): Ajolote, mascota Mítica, referencia «Axololt voxel.jfif» y las fotos de `docs/img` (ajolote). Base: la Rana. Con `origin = "HuevoMitico"`, solo desde el panel de admin.
- **Riesgos:** un icono, una sola cosa (el 🐸 es de la Rana; comprueba en `src` el que elijas y que sea anterior a 2020). Medir con `Rendimiento` (topes 240 y 110; el Quetzal usó 97 piezas con el permiso del usuario hasta 120). Dejar el modelo de vista previa y la cámara en `Fixed` antes de pedir el «aprobado». Pendiente de decidir: `AVENTURAS.md` y `GDD.md` dicen «una mascota mítica nueva»; el plan dice dos.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de M3, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo M3.»

**Handoff de M4 (29-10-2026)**
- **Estado:** M3 cerrada y subida (88779ff). M4 sin empezar, añadida a petición del usuario: las mascotas antiguas no tienen clips propios. Siguiente número libre de VERIFICACION: §61. El CSV de textos (`build/localization_nuevas.csv`, 6 filas de M1–M3) lo sube el usuario y después `strings.py --marcar-subidas`.
- **Antes de escribir código:** pide al agente `search` el mapa de `PetModels` (`CLIPS`, los huesos `bone` de cada constructor y qué mascotas ya tienen clips: Gato/Felino `Cat`, `Dog`, `Beagle`, `Labrador`, `Pointer`, `Jaguarundi`, `Ocelote`, `X7`, `Bird`, y las nuevas Capibara, Ajolote y Quetzal). Faltan por revisar: Tucán, Tortuga, Rana dardo, Guacamaya, Perezoso, Colibrí, Jaguar de cristal y lo que el mapa diga que no tiene `Idle*`, `Run` o `Walk`.
- **Objetivo:** que cada mascota tenga rutinas de reposo `Idle*` (varias), `Run` si es de suelo, `Attack` si ataca, y `Glide` o `Hover` con detalle si es un ave. Los clips usan los huesos que ya publican sus constructores (`bone`); si falta un hueso (patas, cola, orejas), se añade en el `v.swing` del constructor. Patrón: `CLIPS.Capibara`, `CLIPS.Ajolote` y `CLIPS.Quetzal`.
- **Riesgos:** cada mascota es una sesión corta; se puede dividir en M4a (aves), M4b (cuadrúpedos) y M4c (anfibios y reptiles). Los clips no cambian piezas, pero hay que medir con `Rendimiento` si se añade algún hueso. Las rutinas se ven en Play (`PetFollowers`), no en edición; en edición se prueban con `PetModels.animate(modelo, reloj, 0, { { clip = "...", time = t, weight = 1 } }, 0, 0)`.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de M4, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo M4.»

**Handoff de R1 (29-10-2026)**
- **Estado:** M1–M4 cerradas y subidas (último 19ce22d, PLAN ee490fb). R1 sin empezar. Siguiente número libre de VERIFICACION: §62. El Studio de la Isla tiene el Workspace limpio (sin modelos de vista previa) y la cámara en `Fixed`.
- **Antes de escribir código:** pide al agente `search` el mapa de `src/shared/ArmorModels.luau` (los 4 constructores de rango I y sus helpers: `Body`, `OUTFITS` en 2957, `BUILDERS` en 5808, `BY_GRADE` en 5816 y cómo se pone un traje mítico encima), `Data/Armor.luau` (`FurVest`, 17) y `Rendimiento.luau` (317: cómo mide cada rango, `fusionSoldada`) y cómo se ve la armadura en el cliente (`RewardModels`, `Armario`). Lee las memorias `armor-tier-congruence`, `back-view-matters`, `hombreras-formas`, `top-tier-gear-detail` y `vista-previa-antes-de-aprobar`. Comprueba las líneas: este handoff las toma de una búsqueda rápida.
- **Objetivo:** ver la tanda R1 del plan (`C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`, sección R1–R4): rehacer los 4 builders del **rango I (`FurVest`)**, uno por rol, en `ArmorModels.BUILDERS` (línea 5809):
  - Guerrero: `furVest` (321).
  - Cazador: `trackerCape` (945).
  - Mago: `amuletMantle` (1359).
  - Médico: `healerBandolier` (1733).
- **Reglas:** congruencia de grados (los grados de un set comparten materiales, paleta y motivos), la espalda vistosa (se ve casi siempre desde atrás), formas de hombrera (losas cuadradas, estrella, círculo, óvalos planos; nunca almohadas) y voxel con pocos tonos planos, con las referencias de `docs/img`. Los trajes míticos (`OUTFITS`) se ponen encima de cada grado: comprobar que siguen encajando.
- **Topes:** `Config.Budgets.Models.ArmorRank` = { 80, 115, 150, 210 } (línea 2184 de `Config.luau`; el rango I tiene 80 piezas por armadura). Mide con `Rendimiento` antes del commit; si hace falta subir un tope se cambia allí (y se avisa al usuario, como con el Quetzal y el Ajolote).
- **Verificación:** `stylua --check src`, `selene src`, `python tools/strings.py` (si hay textos) y `rojo build` de los 4 places. En Studio de la Isla (modo edición): construir cada armadura sobre un maniquí con `ArmorModels`, capturas de frente, de lado y de espaldas. **Antes de pedir el «aprobado», deja los 4 modelos de vista previa en el Workspace y la cámara en `Fixed`.** Lo que necesite Play o varios jugadores va a VERIFICACION §62.
- **Flujo:** commit solo tras «aprobado», push y fila de `PLAN.md` en un commit aparte; después, escribe el Handoff de R2 (Hueso) con su prompt.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de R1, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo R1.»


**Handoff de R2 (29-10-2026)**
- **Estado:** R1 cerrada y subida (9eaed8a). R2 en curso en la misma pestaña. Siguiente número libre de VERIFICACION: §63.
- **Objetivo:** rehacer los 4 builders del rango II (`BoneArmor`): `boneArmor`, `hunterLeather`, `runeTunic`, `healerPlastron`; tope `ArmorRank[2]` = 115. Mismo método que R1: `programador` escribe; la sesión principal mide con `Rendimiento` y captura sobre maniquíes (`HumanoidDescription` con color de piel y `ArmorModels.wear`); espalda vistosa, congruencia con el rango I y trajes míticos sin errores.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de R2, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo R2.»

**Handoff de R3 (29-10-2026)**
- **Estado:** R1 (9eaed8a) y R2 (f32b4db) cerradas y subidas. R3 en curso en la misma pestaña. Siguiente número libre de VERIFICACION: §64.
- **Objetivo:** rehacer los 4 builders del rango III (`SilverArmor`): `silverArmor`, `silverHunter`, `crystalMantle`, `silverHealer`; tope `ArmorRank[3]` = 150. Mismo método que R1 y R2: `programador` escribe; la sesión principal mide con `Rendimiento` y captura sobre maniquíes (`HumanoidDescription` con color de piel y `ArmorModels.wear`); espalda vistosa y distinta de la del rango II, congruencia con I y II, y trajes míticos sin errores. Reutiliza `slabPauldron`, `discPauldron`, `leafStar`, `blockLeafFan`, `blockHood` y `monkeySkull`.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de R3, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo R3.»

**Handoff de R4 (29-10-2026)**
- **Estado:** R1 (9eaed8a), R2 (f32b4db) y R3 (fb1ffa1) cerradas y subidas. R4 en curso en la misma pestaña. Siguiente número libre de VERIFICACION: §65.
- **Objetivo:** rehacer los 4 builders del rango IV (`VolcanicArmor`): `volcanicArmor`, `emberCloak`, `lavaRobe`, `sulfurMantle`; tope `ArmorRank[4]` = 210. Mismo método que R1–R3. Es el rango más rico (memoria `top-tier-gear-detail`): hombreras de losa con cristales de obsidiana en lava, gotas de lava, llama de píxeles y humo, y una espalda de exhibición por rol. Reutiliza los helpers de R1–R3 y revisa que ninguna punta atraviese otras piezas.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de R4, y el plan en `C:\Users\jose\.claude\plans\majestic-chasing-clarke.md`. Haz el grupo R4.»

**Handoff de S2 (29-10-2026)**
- **Estado:** S1 cerrada y subida (343054f). Siguiente número libre de VERIFICACION: §67. `Config.Budgets.Models.ForgeWeaponRank = { 40, 55, 70, 90 }` ya existe (los de II y III son provisionales: ajústalos al medir).
- **Objetivo:** rehacer las armas de rango II (Hueso): SharpMachete, LianaSling, BoneMace, ReinforcedBow, BoneBlowgun, GoldenStaff. Mismo método que S1: `programador` escribe con opciones nuevas por defecto neutras; la sesión principal mide con `Rendimiento`, captura de frente, lado y espalda y deja la vista previa en `workspace` con la cámara en `Fixed`. Congruencia con el rango I (mismos motivos, más hueso y riqueza) y claramente más simple que el III.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de S2. Haz el grupo S2.»

**Handoff de S3 (29-10-2026)**
- **Estado:** S1 (343054f) y S2 (e8217ed) cerradas y subidas. Siguiente número libre de VERIFICACION: §68. `ForgeWeaponRank = { 40, 55, 70, 90 }`.
- **Objetivo:** rehacer las armas de rango III (Plata/Liana): Club/BigFangClub no (son otra rama; solo las de rol): ThickBoneMaul, LianaBow, ShamanBlowgun, SilverStaff. Tope 70. Mismo método que S1/S2 (programador con opciones opcionales; la sesión principal mide, captura de frente, lado y espalda; vista previa en `workspace` y cámara `Fixed`). Congruencia con I y II, y claramente más simple que el IV. Ojo: el Machete no tiene rango III (el Guerrero sube por Maza).
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de S3. Haz el grupo S3.»

**Handoff de K1 (29-10-2026)**
- **Estado:** S1–S4 cerradas y subidas (S4 9f3a7c5). Siguiente número libre de VERIFICACION: §70. Rango IV al tope: Maza 87, Arco 82, Cerbatana 80, Bastón de lava 89 de 90 (ForgeWeaponRank[4]). Las skins (Sulfur* y míticas) usan builders propios y no cambiaron.
- **Objetivo:** `K1` skins de temporada (SulfurMace, SulfurBow, SulfurStaff, SulfurBlowgun, SulfurMachete) y después `K2` skins míticas (≤165 piezas), cada una distinta de su arma base rehecha a primera vista y desde atrás, con el nivel del arma como grado. Ahora las armas base de rango IV son más ricas: comprueba que las skins épicas siguen destacando (Sulfur* miden 63–74) y, si no, súbelas con el mismo método. Pregunta antes al usuario si prefiere subir el tope del rango IV.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de K1. Haz el grupo K1.»

**Handoff de armas y skins (29-10-2026)**
- **Estado:** la serie de armaduras R1–R4 está cerrada y subida (R4 6c4425b, PLAN 0a59e5a). Siguiente número libre de VERIFICACION: §66. Las armas no tienen tandas en la Fase 18: este handoff propone crearlas (nombres `S1`–`S4` y `K1`–`K2`, o los que decida el usuario) y añadirlas a la tabla de la Fase 18 o a una fase nueva. Pregunta al usuario qué quiere rehacer primero antes de escribir código.
- **Antes de escribir código:** pide al agente `search` que compruebe las líneas de este mapa (se tomó de una búsqueda rápida) y mide la línea base con `Rendimiento` (`informe()` en el Studio de la Isla). Lee las memorias `mythic-tier`, `visual-variants-clearly-distinct`, `top-tier-gear-detail`, `armor-tier-congruence`, `back-view-matters`, `voxel-style-pilot`, `models-default-voxel` y `vista-previa-antes-de-aprobar`, y la skill `modelos-3d-roblox`.
- **Mapa del código:**
  - Armas de la Isla: `src/shared/WeaponTools.luau`, `BUILDERS` (2750). Familias: Machete y SharpMachete; Honda y LianaSling; Spear, Sickle y las herramientas (hachas y picos); Club, BigFangClub, StoneClub, BoneMace, ThickBoneMaul y VolcanicMaul; Bow, ReinforcedBow, LianaBow y EmberBow; Blowgun, BoneBlowgun, ShamanBlowgun y SulfurBlowgun; MagicStaff, GoldenStaff, SilverStaff y LavaStaff. Roles en `Data/Roles.luau` (`weapons`); estadísticas en `Data/Weapons.luau`; cadenas de mejora en `Data/Recipes.luau`.
  - Skins de arma (aspectos, `(tool, level)`): `WeaponTools.luau` 3138–3148. De temporada: SulfurMace, SulfurBow, SulfurStaff, SulfurBlowgun y SulfurMachete (gratis). Míticas, una por rol y con el nivel del arma: TitanKingMace, SpectralJaguarBow, FeatheredSerpentStaff y CeibaBlowgun. Helpers: `FAMILY_LEVELS` 3154, `roleLevel` 3179, `skinOf` 3228, `build` 3283, `reskin` 3301, `preview` 3354. Datos en `Data/Cosmetics.luau` (kind `WeaponSkin`).
  - Laboratorio: `src/shared/LabWeaponModels.luau` (armas base LabDartGun, LabBananaRifle, LabNetHarpoon y LabAcidCannon, por bando Pirates o Guardians; `BUILDERS` 419) y `LabWeaponSkins.luau` (LabWasp, LabScorpion, LabKraken y LabDragon, con grados I, II y III por bajas 50/250/1.000; `BUILDERS` 677). Datos en `Data/LabWeapons`.
  - Topes (`Config.Budgets.Models`, `Config.luau` 2181): `ForgeWeaponLevel4` 90, `WeaponSkinMythic` 165, `LabWeaponBase` 45, `LabWeaponSkin3` 200. No hay tope por arma de rango I–III de la forja: decide cuáles poner (por ejemplo como `ArmorRank`) y escríbelos en `Config.Budgets`. El PLAN (594) deja pendiente subir la calidad de las skins de arma y de las armas del Laboratorio con el nuevo presupuesto.
- **Tandas propuestas** (una por sesión, el mismo método que las armaduras: `programador` escribe, la sesión principal mide, captura y juzga):
  - `S1`–`S4`: armas de la forja por rango (I: Machete, Honda, Bow, MagicStaff, Blowgun…; II; III; IV), cuatro roles en cada una, con la silueta propia por rol y la congruencia entre rangos.
  - `K1` skins de temporada (las cuatro Sulfur más el machete) y `K2` skins míticas (cuatro, 165 piezas como máximo), cada una distinta de la normal a primera vista y también desde atrás o en la mano, con el nivel del arma como grado.
- **Reglas:** voxel con pocos tonos planos y referencias de `docs/img`; las variantes (rarezas, estilos, grados) se distinguen de la normal con colores y rasgos nuevos, no con tintes; las poses de las armas son `AnimationTrack`, nunca articulaciones giradas; ningún icono repetido (si cambia algún emoji); cuida que ninguna punta atraviese otra pieza (error ya visto en R2).
- **Sin probar y relacionado:** VERIFICACION §42 (fusión de armas), §45–48 (armas y skins del Laboratorio, Fase 17) y §30 (skins por bajas del Laboratorio, 2 jugadores). Mide con `Rendimiento` antes del commit; si un tope sube, se cambia en `Config.Budgets` y se avisa.
- **Verificación:** `stylua --check src`, `selene src`, `python tools/strings.py` (si hay textos) y `rojo build` de los 4 places. Modelos montados sobre un maniquí o una mano en el Studio de la Isla, con capturas de frente, de lado y de espaldas; deja la vista previa y la cámara en `Fixed` antes de pedir el «aprobado».
- **Flujo:** commit solo tras «aprobado», push y fila de `PLAN.md` en un commit aparte; después, el Handoff de la tanda siguiente.
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 18 y el Handoff de armas y skins. Pregúntame con cuál de las tandas S1–S4 o K1–K2 empezamos y haz ese grupo.»

### Fase 19: Experiencia de combate a distancia (29-10-2026)

En el Laboratorio publicado solo se ve el deslizamiento. No se ven la pose de apuntar, los disparos, las líneas blancas, las balas ni dónde pegan. Plan completo (decisiones de la entrevista, archivos, números y riesgos) en `C:\Users\jose\.claude\plans\magical-stirring-puddle.md`; se basa en `docs/Combate a distancia.txt`. Siguiente número libre de VERIFICACION: §81. En los handoffs, escribir «Fase 19 W1…» (los nombres W1–W4 también existen en la Fase 17).

Decisiones del 29-10-2026:
- **Alcance:** Laboratorio, Dunas e Isla; las líneas blancas también en el Lobby.
- **Pose:** arma al frente siempre con un arma a distancia, salvo al correr; la ven todos (respaldo replicado como el del deslizamiento).
- **Puntería:** todas las armas se apuntan, cada una con su mira (rifle hueca, dardos y honda punto rojo, arpón/arco/cerbatana de hierro, cañón y bastón arco de caída). Sin ayuda de puntería en el Lab; en Isla y Dunas, hacia la zona más cercana. En tercera persona, cámara al hombro.
- **Zonas por piezas** en los 3 places y contra monos y jefes: cabeza ×1,5 (rifle ×2), torso ×1, extremidades ×0,8, puntos débiles en jefes; rebobinado de la pose.
- **Impactos:** bala inmediata en el cliente, marcas en paredes, pulpa de plátano, hitmarker inmediato (cabeza en amarillo-naranja; el punto rojo de la mira es excepción aceptada a la regla del rojo), «tac» y «dink», killfeed.
- **Primera persona del Lab:** rig de brazos voxel con `AnimationController`; el usuario publica las animaciones.
- **Líneas blancas, FOV y sacudida:** más fuertes, con su propio ajuste, en todos los places.

| Grupo | Contenido | Commit | Estado |
|---|---|---|---|
| **W1** | Líneas blancas, FOV y sacudida en los 4 places | f6b7fa1 | ✅ Probado en Studio, Laboratorio (sin probar: VERIFICACION §74) |
| **W2** | Pose de apuntar visible para todos (3P) | 015e9d3 | ✅ Probado en Studio (sin probar: VERIFICACION §75) |
| **W3** | Confirmación de impacto: `HitFeedback`, hitmarker y sonidos | f71ba2e | ✅ Probado en Studio y en el juego publicado con 2 jugadores (sin probar: VERIFICACION §76) |
| **W4** | Bala inmediata del tirador y dispersión sincronizada | da12de9 | ✅ Probado en Studio (sin probar: VERIFICACION §78) |
| **W5** | Marcas de impacto, chispas, polvo y pulpa | 8c075e6 | ✅ Probado en Studio (sin probar: VERIFICACION §79) |
| **W6** | Zonas por piezas, rebobinado de pose y ayuda de puntería | c7e07fd | ✅ Probado en Studio (sin probar: VERIFICACION §80) |
| **W7** | Apuntar de verdad (ADS) y cámara al hombro | 864414a | ✅ Probado en Studio (solo carga y Equilibrio) (sin probar: VERIFICACION §81) |
| **W8** | Miras por tipo de arma | 576ed76 | ✅ Probado en Studio solo la honda (sin probar: VERIFICACION §82) |
| **W9** | Killfeed | 4206652 | ✅ Probado en Studio en la Isla con FakeKill (sin probar: VERIFICACION §83) |
| **W10** | Rig de brazos en primera persona del Lab | 2306989 | ✅ Probado en Studio (rig, builder, Rendimiento; faltan publicar las 20 animaciones, VERIFICACION §84) |
| **W11** | Prueba publicada con 2 a 10 jugadores y ajuste | — | ⏳ |

**Handoff de la Fase 19 W7 (29-10-2026)**
- **Estado:** W1 (f6b7fa1), W2 (015e9d3 y 43d4eed, con los 16 ids ya publicados), W3 (f71ba2e), W4 (da12de9) y W5 (8c075e6) hechas y cerradas en este PLAN. W6 está hecha en el código y probada en Studio, pero **sin commit** hasta el «aprobado» del usuario. Sin probar de W6: VERIFICACION §80. Sin probar de W5: VERIFICACION §79. Sin probar de W4: VERIFICACION §78. Sin probar de W3: VERIFICACION §76. Siguiente número libre de VERIFICACION: §81. Plan completo y decisiones en `C:\Users\jose\.claude\plans\magical-stirring-puddle.md` (sección W7).
- **Nota sobre W6:** W7 se escribe sobre el código de W6, que aún no tiene commit. El commit de W6 va antes que el de W7.
- **Objetivo W7:** apuntar de verdad (ADS) y cámara al hombro.
  - `WeaponController`: `setZoom` y `bindZoom` (líneas 372-411) pasan a un estado de apuntado para todas las armas, con FOV por arma; nuevo `isAiming()`. `shake` (líneas 277-293) pasa a `CameraShake.play` para dejar libre `CameraOffset`.
  - Nuevo `ShoulderAimController.luau`, saltado en el Lab: al apuntar pone `CameraRelative`, `LockCenter` y `CameraOffset` al hombro derecho; al soltar, al morir, al desequipar o al abrir una ventana, vuelve al estado anterior. Se coordina con `CameraLockController`.
  - `Aim.luau`: en táctil y mando, rayo desde la cámara hasta `Aim.point` para evitar el paralaje.
  - `CombatRules.takeShot` en Isla y Dunas: dispersión de cadera o con mira. Lab: `adsSpreadFactor`.
  - Campos nuevos `aimFov` y `hipSpread` en `Data/Weapons` y `LabWeapons`.
- **Valores fijados:** Config `Aim`: `ShoulderOffset (1.75, 0.6, 0)`, `ShoulderFov 55`, `TransitionSeconds 0.15`, `HipSpreadDegrees 1.5`, `AdsSpreadDegrees 0`. Lab: `adsSpreadFactor 0.35` para dardos y arpón.
- **Mapa del código nuevo de W6:**
  - `src/shared/Zones.luau` (nuevo): las zonas de daño.
  - `Config.Combat.Zones`: `Head 1.5`, `Torso 1`, `Limb 0.8`, `Weak 1.5`, `PartPadding 0.15`, `PoseHistorySeconds 0.3`, `HitMix 0.15/0.6/0.25`, `HeadByProjectile` y `FilterExtraStuds`.
  - `zoneMultipliers` por arma en `Data/Weapons` y `Data/LabWeapons`.
  - `Hitbox.zoneOf(model, part)` y `Hitbox.sweepBodies`: la cápsula como filtro rápido y después un test segmento-OBB por pieza con su pose rebobinada.
  - `PositionHistory.poseAt` y `poseInto`: el anillo de poses de 0,3 s.
  - `CombatRules`: `zones` (verdadero en los 4 places) y `aimAssist` (falso en el Lab).
  - `CombatService`: `strike`, `zoneScale` y `aimShot`.
  - `TrainingDummies` con cabeza y brazos.
  - `Data/Bosses` con `weakPoints`, que `MonkeyModels` marca con el atributo `WeakPoint` (`markZones`).
- **Valores fijados de W6:** dardos, cabeza ×1,3; arpón, cabeza ×1,5 y extremidad ×1; rifle, cabeza ×2; monos, cabeza según el arma: honda 1,5, arco 1,75, bastón 1,25, cerbatana 1,3; extremidad ×0,8 (salvo el arpón); punto débil de jefe ×1,5. El daño toma el mayor entre crítico y cabeza; la extremidad siempre multiplica.
- **Trampas conocidas:**
  1. El cursor del ratón de Studio desvía el disparo del cliente en las pruebas: usa el remoto `UseWeapon` con una dirección, o `tool:Activate()`.
  2. Los proyectiles de arma usan una esfera de radio 0,6 contra monos y muñecos. Los brazos del muñeco están a 1,9 del torso, así que hay que tenerlo en cuenta al apuntar a los brazos.
  3. En el Studio de la Isla, la caché de `require` no muestra los VoxelSpecs nuevos: clona la carpeta `Combat.Monkeys` antes de probar.
  4. En Play, el `require` del MCP es otra copia: para remotos, usa los de `ReplicatedStorage.Remotes` desde el cliente.
  5. Play en Studio escribe el perfil real: haz copia en `PlayerData_v1_backups` y restáurala después.
  6. Deja la cámara de edición en `Fixed`, como último paso.
- **Riesgos:** el ratón puede quedar bloqueado: hay que restaurar el estado al morir y al abrir ventanas. La dispersión de cadera y la cabeza ×2 del rifle cambian los TTK: nada se escribe sin `Equilibrio` sin alertas.
- **Prueba:** Isla y Dunas en PC y en el emulador de teléfono (botón «Mira»), y `Equilibrio` con la dispersión de cadera.
- **Cómo trabajar:** `search` localiza lo que haga falta; el `programador` escribe con esta especificación (skills `combate-roblox` e `interfaz-roblox`); la sesión principal revisa el diff y las capturas; `probador-studio` hace `Equilibrio` y las pruebas en Studio; `documentador` hace la sección de VERIFICACION, la fila de W7 y el borrador del commit.
- **Flujo:** commit solo tras el «aprobado» del usuario; push y fila de `PLAN.md` en un commit aparte. Después, el Handoff de W8 (miras por tipo de arma).
- **Prompt para la pestaña nueva:** «Lee `docs/PLAN.md` Fase 19 y el Handoff de la Fase 19 W7, y el plan en `C:\Users\jose\.claude\plans\magical-stirring-puddle.md`. Haz el grupo W7.»

---

## 4. Cronograma estimado

Estimación con **5–15 h/semana**: unos **7–10 meses** hasta el lanzamiento. El diagrama usa el escenario medio.

```mermaid
gantt
  title Primal Banana Islands: plan estimado
  dateFormat YYYY-MM-DD
  axisFormat %b %Y
  section Base
  Fase 0 Fundaciones           :f0, 2026-10-12, 14d
  Fase 1 Bucle núcleo          :f1, after f0, 42d
  section Juego
  Fase 2 Supervivencia y base  :f2, after f1, 42d
  Fase 3 Lobby y progresión    :f3, after f2, 28d
  section Contenido
  Fase 4 Isla y bestiario      :f4, after f3, 56d
  Fase 5 Jefes, huevo y PvP    :f5, after f4, 56d
  section Lanzamiento
  Fase 6 Rescate y pulido      :f6, after f5, 42d
```

---

## 5. Métricas para cada playtest

| Pregunta | Cómo se mide |
|---|---|
| ¿Se entiende qué hacer? | % de jugadores que salen del Basecamp en los primeros 3 minutos |
| ¿Es divertido? | Tiempo medio de sesión y cuántos llegan a la primera noche |
| ¿Vuelven? | Retención al día siguiente (D1) y a la semana (D7) |
| ¿Es justo? | Causas de caída, PvP vs PvE, y qué monos derriban más |
| ¿Rinde bien? | FPS y memoria en móvil con el servidor lleno (5 jugadores) |

---

## 6. Siguiente paso inmediato

1. **Tú:** verificar las Fases 2 a 6 en Studio y en el juego publicado (lista de pruebas en el mensaje de entrega).
2. **Claude:** corregir lo que salga de esa verificación.
3. **Tú:** probar la arena de Dunas con varios jugadores y publicada ([VERIFICACION.md](VERIFICACION.md) §8, Fase 8).
4. **Tú:** pasos de [LANZAMIENTO.md](LANZAMIENTO.md): música, pases, página del juego, beta cerrada y lanzamiento.
