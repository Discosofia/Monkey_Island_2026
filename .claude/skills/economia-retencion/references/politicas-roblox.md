# Políticas y herramientas de Roblox para vender y retener

## Game Passes y Developer Products

- **Game Pass**: se compra una vez y es para siempre (`MarketplaceService:UserOwnsGamePassAsync`,
  `PromptGamePassPurchase`, `PromptGamePassPurchaseFinished`). Sirve para cosméticos permanentes (los
  4 actuales en `Data/Cosmetics`).
- **Developer Product**: se puede comprar muchas veces (`PromptProductPurchase`). Es lo que se usa
  para el pase de temporada (un mismo producto vale para la temporada en curso), los niveles del pase
  y los cosméticos sueltos de la tienda rotativa. Roblox solo cobra: **el juego entrega** lo comprado.
- Los ids y los precios se crean en el Creator Hub; en el código el id va en Data/Config con `0` =
  "Próximamente". Roblox se queda el 30 % (el creador recibe el 70 %). El Creator Hub tiene un
  optimizador de precios para pases y productos.

### ProcessReceipt sin perder ni duplicar compras

- `MarketplaceService.ProcessReceipt` se pone **en cada place** donde un jugador pueda estar (Lobby,
  Isla, Dunas): Roblox reintenta el recibo hasta que algún servidor devuelve `PurchaseGranted`.
- Orden seguro: si el perfil no está cargado o no se puede guardar → `NotYetProcessed`. Si el
  `PurchaseId` ya está en el perfil → `PurchaseGranted` (ya se entregó). Si no: entregar dentro de
  `PlayerData.update`, apuntar el `PurchaseId` (anillo de los últimos ~50), guardar (`saveNow`) y
  solo entonces devolver `PurchaseGranted`. Si algo falla, `NotYetProcessed`.
- En Studio las compras son de prueba y también llaman a `ProcessReceipt`.

## Objetos aleatorios de pago (loot boxes, huevos, ruletas)

- Cuenta como aleatorio de pago todo lo aleatorio que se consigue directa o indirectamente con
  Robux, incluida una moneda comprada con Robux: huevos, cofres, ruletas, mejoras con probabilidad,
  combinaciones y modificadores de suerte.
- Obligatorio: enseñar **todos los resultados con su probabilidad en %** (que sumen 100 %) antes de
  pagar, en la pantalla o en una ventana "Detalles"/"Info" (un icono (i) solo no vale).
- `PolicyService:GetPolicyInfoForPlayerAsync(player)`: si `ArePaidRandomItemsRestricted` es true, ese
  jugador no puede usar generadores aleatorios de pago (dar una vía gratis, orden fijo, venta directa,
  quitarlo o bloquear la compra). Si `IsPaidItemTradingAllowed` es false, no puede intercambiar objetos
  de pago.
- Lo aleatorio que se gana jugando (sin Robux) no necesita probabilidades. **Regla del juego**: nada
  aleatorio se vende, así que nada de esto aplica mientras se respete.

## Pases de temporada (guía de Roblox)

- Temporada de ~1 mes, con al menos **1 semana de descanso** entre temporadas.
- Todos entran solos; misiones diarias que se renuevan cada día y una semanal más difícil; al menos 3
  categorías (exploración, combate, colección, social, supervivencia…); mezcla de fácil, media y
  difícil; nunca exigir moneda de pago para una misión.
- Premios de nivel útiles pero no demasiado valiosos; el **premio final**, nuevo y exclusivo de la
  temporada (se retira después). Enseñar el modelo 3D cuando se pueda.
- Reclamar con un botón (icono cuando hay algo pendiente); al acabar la temporada, entregar solo lo no
  reclamado.
- Quien compra la premium a mitad recibe todo lo ya alcanzado. No castigar al que compra tarde.
- Considerar **doble XP la última semana** para quien va atrasado.
- Botón grande y con color, cuenta atrás visible, menús con el tema de la temporada y un aviso o
  tutorial la primera vez que algo cambia.

## Creator Rewards

- Roblox paga 5 Robux al día por cada usuario "Active Spender" (≥ 9,99 $ gastados en 60 días) que
  pasa **≥ 10 minutos** en la experiencia y la tiene entre las 3 primeras que visita ese día. Más
  minutos no suman. Por eso una diaria fácil debe caber en ~15 min y el calendario premia entrar.

## Fuentes

- create.roblox.com/docs/production/monetization (passes, developer products, subscriptions)
- create.roblox.com/docs/production/monetization/paid-random-items
- create.roblox.com/docs/reference/engine/classes/PolicyService
- create.roblox.com/docs/production/game-design/season-pass-design
- create.roblox.com/docs/creator-rewards
