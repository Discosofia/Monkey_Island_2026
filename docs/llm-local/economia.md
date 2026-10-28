# Economía, retención y monetización (resumen de la skill economia-retencion)

<!-- Fuente: .claude/skills/economia-retencion/SKILL.md, 28-10-2026. Detalles: references/modelo-economico.md (principios, línea base), limites.md, politicas-roblox.md (léelo antes de vender algo), nueva-temporada.md. -->

**Regla: se mide antes de escribir.** Las reglas de pago no se negocian:

- Lo de Robux es **solo cosmético** (o el pase premium).
- Nunca se venden Ámbar, tiempo de huevo, provisiones ni nada aleatorio.

## Calculadora (place de la Isla, Edit)

```lua
local m = game.ServerStorage.Tools.Economia:Clone()
_G.Economia = require(m); m:Destroy()
return _G.Economia.informe()
```

- **Opciones:** `dias = 45`, `perfiles = { habitual = { minutosIsla = 90, diasPorSemana = 4 } }`, `ritmos = { Kill = 1.5 }` y `secciones = { partida = false }`.
- **Parcela** (sección 2b): costes de las 7 estructuras, lo que dan en la partida y el día en que cada perfil las tiene al III; `parcela = { dias = 180 }` cambia la simulación larga.
- **Propuesta:**
  ```lua
  return _G.Economia.informe({ secciones = { partida = false } }, {
  	config = { Daily = { WeeklyMissions = 4 }, Match = { AmberPerDay = 15 } },
  	datos = { Missions = { Kills = { target = 40, difficulty = "Media" } } },
  })
  ```
- El informe termina en **"Alertas"**. Una alerta de **pago** nunca se acepta con una razón: se rediseña.
- Si el Studio de la Isla no está abierto, la calculadora también funciona en el Lobby con una copia temporal en `ServerStorage._EconomiaTemporal`. Bórrala al terminar.

## Ficha del cambio

- **Qué:** misión, premio, producto, precio, cosmético o evento. Si sustituye a algo, a qué.
- **Para quién y cuándo:** casual, habitual, intenso o amigos; primera sesión, día 7 o semana 3.
- **Qué problema resuelve:** falta de metas, Ámbar sin uso o un pase demasiado largo.
- **Regla de pago:** ¿alguien que paga lo consigue? Entonces solo puede ser cosmético.

## Dónde se implementa

- **Misión:** `src/shared/Data/Missions.luau` (`icon`, `text`, `event`, `target`, `role?`, `difficulty?`, `weekly?` y `reward`). Solo cosas que se puedan hacer jugando solo. Si el evento es nuevo, añade `Retention.progress(player, "<Evento>", n)` en el servicio que lo detecta.
- **Premio:** con el formato de `Config.Reward` (`amber`, `items`, `eggSeconds`, `egg` y `cosmetic` en el pase). Lo entrega `ServerShared/Retention.grant`.
- **Cosmético:** `src/shared/Data/Cosmetics.luau`, con `kind`, `name`, `icon`, `description`, `order` y su fuente (`gamePassId`, `productId`, `amber`, `season` o `earned`).
- **Producto de Robux:** el id va con `0` = "Próximamente" y lo crea el usuario en el Creator Hub. Se registra con `Purchases.register(clave, productId, { name, grant })`.
- Los números siempre en `Config` o `Data`.

## Verificar y cerrar

- `stylua src`, `selene src` y los tres `rojo build`. Repite el informe sin propuesta.
- Si cambia el perfil, se publican los tres places a la vez.
- Si cambia lo que ve el jugador, actualiza `docs/GDD.md` §4, §11 o §14.
