# Lanzamiento (Fases 6 y 9)

Todo el código del lanzamiento está hecho. Lo que queda son **ajustes en el Creator Hub y en Studio**, que solo puedes hacer tú con tu cuenta. Sigue esta lista en orden.

## 1. Antes de nada: probar

1. Repasa la lista de pruebas de las Fases 2 a 6 (está en el mensaje de entrega de Claude y en [PLAN.md](PLAN.md)).
2. La lista de la Fase 9 (pase, misiones, contratos, eventos, cosméticos y tiendas): [VERIFICACION.md §10](VERIFICACION.md#10-fase-9-pase-misiones-v2-mitad-de-partida-y-cosméticos-21-10-2026).
3. Activa **StreamingEnabled** en la Isla y prueba en un móvil ([RENDIMIENTO.md](RENDIMIENTO.md)).
4. Activa el acceso a las API en Studio para probar el guardado ([SETUP.md](SETUP.md#guardado-de-datos-fase-28)).

## 2. Sonido

1. En Studio, abre la **Caja de herramientas → Audio** (o el Creator Store en el navegador).
2. Busca música con licencia de Roblox (por ejemplo, de **APM Music**: es gratis usarla en tus juegos). Ideas:
   - **Lobby y día:** algo tropical y tranquilo (marimbas, percusión suave).
   - **Noche:** ambiente tenso, selva nocturna.
   - **Asedio y La Gran Tropa:** tambores rápidos.
   - **Jefes:** épica. Cada jefe puede tener su tema en `BossMusic` (suena cuando el jefe pelea y estás cerca); los que queden en `""` usan `Music.Boss`.
3. Copia el ID de cada pista (botón derecho → *Copiar ID del recurso*) y pégalo en `src/shared/Data/Sounds.luau` con el formato `"rbxassetid://123456789"`. Basta con dos: `Lobby` y `Day` (la de la Isla); las situaciones que dejes en `""` usan la más parecida (`FinalNight` → `Siege` → `Night` → `Day`; `Boss` → `Day`).
4. La tecla **M** silencia la música.

### Efectos de sonido

Los efectos están en `Effects`, en el mismo archivo. Roblox ya solo trae 11 sonidos de serie, así que de momento usan esos con distintos tonos: todo suena, pero los marcados como **Provisional** (sobre todo los animales) quedan mucho mejor con un audio de verdad. Para cambiar uno:

1. En la **Caja de herramientas → Audio**, busca lo que sugiere el comentario: por ejemplo `monkey chatter` (MonkeySteal), `wood chop` (Chop), `pickaxe stone` (Mine), `tree falling` (TreeFall), `sword swing` (Swing), `slingshot` (Shoot), `thunder` (Thunder), `lava` o `explosion` (LavaImpact).
2. Escúchalo y copia su ID (botón derecho → *Copiar ID del recurso*).
3. Pega el ID en `id = "rbxassetid://123456789"` y pon `pitch = 1` (el tono distinto solo era para disimular los provisionales).
4. En Studio, el botón **🔊 Probar todos los sonidos** del panel de pruebas los reproduce uno a uno.

### Voces de los monos

Las voces están en `MonkeyVoices`, en el mismo archivo, divididas por tamaño. Cada especie elige su grupo con `voice` en `src/shared/Data/Monkeys.luau`:

| Grupo | Especies | Qué buscar |
|---|---|---|
| `Small` | Tití, capuchino, mono ardilla, marteja | `tamarin`, `squirrel monkey`, `monkey squeak` |
| `Medium` | Cola larga, marimonda, gibón, aullador, macaco, babuino | `howler monkey`, `macaque`, `baboon`, `monkey scream` |
| `Large` | Chimpancé, mandril, orangután, gorila | `chimpanzee`, `gorilla roar`, `ape grunt` |

Cada grupo tiene cuatro sonidos: `Attack` (muerde o salta), `Call` (aúlla o ruge), `Hurt` (recibe un golpe) y `Death` (ya no suena: al derrotarlos suena `Hurt` y el "¡puf!"). Los jefes usan los de `Large` más graves (`BOSS_PITCH`), así que no hace falta subir sonidos aparte para ellos. En el botón de prueba aparecen como `MonkeySmallAttack`, `MonkeyLargeCall`, `BossRoar`…

## 3. Tienda cosmética y pase de temporada (Robux)

### Game Passes (ya creados)

Estela dorada, Estela de la selva, Título "Rey de la selva" y Aura de banana ya tienen su `gamePassId` en `src/shared/Data/Cosmetics.luau`. Para uno nuevo: **Creator Hub → tu experiencia → Monetización → Pases → Crear pase**, con imagen (512×512) y precio, y su ID en `gamePassId` (con `0` sale como "Próximamente").

### Developer Products (Fase 9, ya creados)

Todo lo que se compra más de una vez o rota en la tienda es un **Developer Product**. Hasta que tenga su id sale como "Próximamente" y no se puede comprar. Los 14 de la tabla se crearon el 22-10-2026 y sus ids ya están en el repo; para uno nuevo, sigue estos pasos.

1. **Creator Hub → tu experiencia → Monetización → Productos para desarrolladores → Crear**. Nombre, imagen (512×512, la imagen voxel del premio sirve) y el precio de la tabla.
2. Copia el **ID** del producto y ponlo en su `productId` (cambia el `0`).
3. Calculadora (`Economia`, sección 5): la columna **Id** pasa de "falta" a ✅ y todos siguen siendo ✅ cosméticos.

| Producto | Dónde va el id | Precio |
|---|---|---|
| 🌋 Pase de temporada premium (vale para la temporada en curso; el mismo producto sirve para las siguientes) | `Config.Shop.Products.SeasonPremium` | 399 |
| 🌋 Pase premium + 10 niveles | `Config.Shop.Products.SeasonPack` | 799 |
| ⭐ Un nivel del pase | `Config.Shop.Products.SeasonLevel` | 79 |
| Título: Capitán pirata | `Data/Cosmetics` → `TitlePirateCaptain` | 99 |
| Números: Escarcha | `FrostNumbers` | 149 |
| Estallido: Neón | `NeonBurst` | 149 |
| Aura: Lluvia de pétalos | `PetalAura` | 199 |
| Marco de diamante | `DiamondFrame` | 199 |
| Estela: Polvo de estrellas | `StardustTrail` | 249 |
| Nido: Templo dorado | `GoldenTempleNest` | 249 |
| Arma: Maza del Rey Gorila (mítico) | `TitanKingMace` | 449 |
| Arma: Arco del Jaguar Espectral (mítico) | `SpectralJaguarBow` | 449 |
| Arma: Báculo de la Serpiente Emplumada (mítico) | `FeatheredSerpentStaff` | 449 |
| Arma: Cerbatana de la Ceiba (mítico) | `CeibaBlowgun` | 449 |

**Regalos** (T3, 26-10-2026): un producto por precio, con el mismo precio que el cosmético que se regala. Se crearon el 26-10-2026 y sus ids ya están en `Config.Shop.GiftProducts`. El filtro de texto de Roblox tapa los nombres con "R$" o con precios, así que se llaman por la rareza de lo que se regala (la ventana de compra ya enseña el precio).

| Producto | Dónde va el id | Precio |
|---|---|---|
| Regalo de cosmético común | `Config.Shop.GiftProducts.Gift99` | 99 |
| Regalo de cosmético poco común | `Gift149` | 149 |
| Regalo de cosmético raro | `Gift199` | 199 |
| Regalo de cosmético épico | `Gift249` | 249 |
| Regalo de cosmético mítico | `Gift449` | 449 |

Si añades un cosmético de Robux con un precio nuevo, crea también su regalo de ese precio (con los precios regionales apagados).

Los precios que se enseñan en el juego salen de `price`: si cambias el precio en el Creator Hub, cámbialo también allí. Deja **apagados los precios regionales** de cada producto: con ellos Roblox cobra otro precio según el país (en el tuyo, ~57 % del base) y no coincidiría con el que enseña el juego. Para comprobarlo, en Studio: `game:GetService("MarketplaceService"):GetProductInfo(id, Enum.InfoType.Product).PriceInRobux` tiene que dar lo mismo que `price`. Las compras se entregan con recibo (`ServerShared/Purchases`): una compra repetida por Roblox no se entrega dos veces. En Studio las compras son de prueba (no cobran).

**Nunca con Robux:** Ámbar, huevos, tiempo de incubación, provisiones ni nada que dé ventaja. Los huevos y las mascotas **no se venden** (solo se consiguen jugando): es una decisión del GDD (§14) para cumplir las normas de Roblox sobre objetos aleatorios de pago. No lo cambies.

### Fecha de la Temporada 1

La Temporada 1 ("El Despertar del Volcán") empieza en `startsAt` de `src/shared/Data/Seasons.luau`. Hoy es **provisional** (lunes 19-10-2026). Antes de publicar:

1. Elige un **lunes** igual o posterior al día en que publiques (las semanales y el calendario cambian el lunes a las 00:00 UTC).
2. Cambia `startsAt = utc(2026, 10, 19)` por esa fecha. La temporada dura 30 días, con ×2 de XP los 7 últimos, y después hay 7 de descanso.
3. Vuelve a pasar la calculadora: no cambia nada salvo la fecha.
4. Prepara la Temporada 2 antes de que acabe el descanso (`.claude/skills/economia-retencion/references/nueva-temporada.md`).

## 4. Servidores privados

**Creator Hub → tu experiencia → Monetización → Servidores privados → Activar** (gratis o con precio). El código ya lo soporta: quien entra al Lobby privado viaja a una Isla reservada solo para su grupo.

## 5. Página del juego

| Qué | Dónde | Recomendación |
|---|---|---|
| Nombre | Configuración de la experiencia → Información básica | **Primal Banana Islands: Monkey Survival** (si cambias el nombre, cámbialo también en `Config.GameName`). **Pendiente:** el juego pasó a llamarse así en plural (antes *Primal Banana Island*); cambia aquí el nombre de la experiencia y el del place del Lobby |
| Descripción | Igual | Pega el texto en inglés de [GDD §18](GDD.md) (invita a entrar como pionero y a jugar con amigos; no pasa de 1.000 caracteres), **sin** "comen carne humana" ni nada de gore. Menciona: amigos (hasta 5), roles, jefes, mascotas y monturas, PvP en Dunas y el Laboratorio, pase y eventos |
| Icono | Igual | **Ya hecho:** [`art/portada/icono-512.png`](../art/portada/icono-512.png) (512×512) |
| Miniaturas | Igual | **Portada ya hecha:** [`art/portada/portada-1920x1080.png`](../art/portada/portada-1920x1080.png), ponla la **primera**. Añade 2–4 capturas a 1920×1080: asedio nocturno, un jefe, el Basecamp construido, el naufragio del Lobby |
| Género | Igual | Supervivencia |
| Dispositivos | Igual | Ordenador, móvil, tableta (y consola si lo pruebas con mando) |
| Cuestionario de madurez | Configuración → Cuestionario | Respóndelo **entero** (no solo la primera pregunta) para llegar a menores de 16. Ver [§9](#9-menores-de-16-roblox-kids-y-select). Repásalo si añades contenido nuevo |

## 6. Analítica

**Creator Hub → tu experiencia → Analítica**. El juego ya envía:

- **Incorporación (embudo):** cada paso del tutorial y "Completado". Si mucha gente abandona en un paso, ese paso se explica mal.
- **Economía:** Ámbar ganado (al terminar cada partida) y gastado (tienda del Lobby).
- **Eventos propios:** `MatchVictory` y `MatchDefeat`, con los días sobrevividos, y `SeasonLevel` (cada nivel del pase que se alcanza, con la temporada): sirve de embudo del pase.
- **Compras:** el Creator Dashboard (Monetización) da el ingreso por producto; mira la conversión del pase premium y si alguien compra niveles sueltos.
- **Retención** (D1, D7) y sesiones: Roblox las calcula solo.

## 7. Beta cerrada

1. Deja la experiencia en **Privada** o limita el acceso a **Amigos** (Configuración → Permisos), o usa un servidor privado.
2. Invita a 10–20 personas. Pídeles que jueguen al menos una partida completa (hasta perder o ganar).
3. Revisa la Salida de los servidores (F9 → Server) buscando errores en rojo, y la analítica.
4. Ajusta números en `src/shared/Config.luau` y en `src/shared/Data/`.
5. Cuando una partida típica dure 3 o más días y la gente quiera repetir: pasa al punto 8.

## 8. Lanzamiento

1. **Publica los cuatro places a la vez** (Lobby, Isla, Isla de Dunas y Laboratorio en ruinas): comparten el perfil (`PlayerData_v1`, ahora en la versión 6) y un place viejo no entiende un perfil nuevo. Antes, guarda el Lobby con la plaza v14 (el cartel volcánico del pase) y la Isla con lo generado.
2. Comprueba la fecha de la Temporada 1 (§3) y los ids de los Developer Products.
3. Pon la experiencia en **Pública**.
4. Opcional: **Anuncios patrocinados** en el Creator Hub con un presupuesto pequeño los primeros días, para que el algoritmo tenga datos.
5. Vigila la Salida, la analítica y los comentarios la primera semana: D1/D7, el nivel del pase al que llega la gente (`SeasonLevel`) y la conversión del pase. Con datos de verdad, cambia los ritmos supuestos de la calculadora (`OPCIONES.ritmos`).

## 9. Menores de 16 (Roblox Kids y Select)

Desde junio de 2026, todos los juegos empiezan solo para jugadores de **16+ con la edad comprobada**. Por eso la página muestra "Madurez: Mínima · Edades 16+": el 16+ no viene del contenido. Para llegar a **Select (9–15)** y **Kids (5–8)** hace falta todo esto. El estado se ve en **Creator Hub → tu experiencia → Audience Reach**.

1. **Cuenta del dueño** (o del dueño del grupo): en buen estado, verificada con **documento de identidad** si tienes 18 o más (estimación facial si eres menor) y con la **verificación en 2 pasos** activada.
2. **Tarifa o suscripción:** **1.000 Robux** por juego (se devuelven a los 90 días de ser apto) o Roblox Plus o Premium durante 2 meses seguidos.
3. **Cuestionario de madurez entero.** Respuestas que encajan con el juego:
   - **Violencia:** sí, **Leve** (irreal: los monos desaparecen con un "¡puf!", sin sangre) y **Repetida**. La etiqueta queda en **Leve**, que llega a Kids y a Select. No la pongas más baja: lo revisan personas jugando.
   - **Sangre:** no. **Miedo:** leve y ocasional (rugidos de los jefes, ojos que brillan).
   - **Humor grosero, lenguaje fuerte, romance, alcohol y drogas, temas sensibles:** no.
   - **Creación libre:** no. Construir con piezas predefinidas no cuenta.
   - **Lugar de reunión social:** no.
   - **Objetos aleatorios de pago:** no. Los huevos solo se ganan jugando. Si algún día se venden huevos o cajas con Robux, hay que ocultarlos a quien tenga `ArePaidRandomItemsRestricted` (`PolicyService:GetPolicyInfoForPlayerAsync`).
4. **Evaluación:**
   - Hacen falta unas **250 partidas de jugadores "muy activos"** (con la edad comprobada y alguna compra en Roblox en los últimos 60 días) en **60 días**. El juego pierde la aptitud si baja de unos 100.
   - También existe la **revisión acelerada por 50.000 Robux** (reembolsable).
   - Para conseguir esos jugadores: anuncios patrocinados para 16+, buena miniatura y descripción, y amigos y comunidades.
5. Después de enviar el cuestionario, la revisión ("Pending final review") tarda entre unas horas y un día.

El juego ya se puede jugar sin chat, y eso importa porque en Kids viene apagado: los grupos se forman desde el menú del Lobby.

### Para que llegue más gente (ya está en el juego)

- **📨 Invitar amigos:** un botón en el Lobby (encima de "Ocultar menú") y otro en la pestaña **Grupo**. Abre la invitación de Roblox; el amigo entra en tu mismo Lobby. Texto en `Config.Social.InviteMessage`.
- **Favorito:** al volver al Lobby después de tu partida 1, 3, 6 o 10, se pide marcar el juego como favorito si no lo es.
- **Notificaciones:**
  - En las demás visitas al Lobby (desde la partida 2) se ofrece activar las notificaciones. Roblox solo muestra ese aviso a mayores de 13, una vez cada 30 días.
  - Al entrar al Lobby se avisa a tus amigos con "{amigo} está jugando… ¡Únete a su tropa!". Solo les llega a los que activaron las notificaciones. Como mucho sale un aviso cada 6 horas por jugador, y Roblox limita cada notificación a 1 al día por amigo.
- En Studio no sale ninguno de estos avisos: pruébalos en el juego publicado.

**Para activar el aviso a los amigos** (sin esto, el resto funciona igual):

1. **Creator Hub → tu experiencia → Interacción → Notificaciones → Crear una cadena de notificación.** Texto: `{userId-friend} está jugando {experienceName}. ¡Únete a su tropa!` (máximo 99 caracteres).
2. En la fila de la cadena: **⋯ → Copiar ID del recurso**, y pégalo en `Config.Social.FriendJoinedMessageId`.
3. En **Studio, en el place del Lobby:** Caja de herramientas → busca el paquete oficial **"Open Cloud"** de Roblox → arrástralo a **ServerScriptService**, al lado de `Server` y `ServerShared` (no dentro). Rojo no lo borra al sincronizar. Publica el place.
4. Roblox solo envía notificaciones de juegos con **100 visitas o más**.

Los requisitos cambian a menudo; consúltalos en la [documentación oficial de Roblox Kids y Select](https://create.roblox.com/docs/production/publishing/kids-and-select).

## Después del lanzamiento (Fase 7)

Temporadas del pase con lore (tarjetas del laboratorio; cada una trae cosméticos nuevos a la tienda en Ámbar, unos 4.000–5.000 de Ámbar al mes, para que no vuelva a sobrar), jefes y eventos nuevos, mutadores de partida ("Luna roja", "Temporada de lluvias") y balance según los datos.
