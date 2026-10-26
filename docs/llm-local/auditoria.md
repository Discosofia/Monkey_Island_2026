# Auditoría de código: vista general del estado

<!-- Método para gpt-oss-20b, 26-10-2026. No cabe todo src/ en el contexto: se audita por carpetas, una por conversación. -->

**Objetivo:** un informe de qué está bien, qué falta y qué deuda técnica hay, para planificar. **No se cambia código durante la auditoría.**

## Orden de las pasadas (una por conversación)

| # | Carpeta | Qué mirar sobre todo |
|---|---|---|
| 1 | `src/serverShared` | Perfil (`PlayerData`: bloqueo de sesión, migraciones, guardado al salir), compras (`Purchases`: recibo idempotente), pase, cosméticos |
| 2 | `src/shared` (sin `Data/` ni los modelos grandes) | `Config`, `Loader`, `Remotes` y módulos compartidos: tipos, dependencias circulares |
| 3 | `src/combat` | Validación de lo que llega del cliente (`UseAbility`, `UseWeapon`, `Guard`), detección con `Hitbox`, estados |
| 4 | `src/island/server/Services` | Bucles por `Heartbeat` o `while true`, conexiones sin desconectar, monos y jefes que no se limpian |
| 5 | `src/lobby` y `src/dunas` | Igual que la 4, y la cola entre servidores |
| 6 | `src/*/client` y `src/combatClient` | Rendimiento en el móvil, interfaz que se crea en cada fotograma, conexiones al reaparecer |

## Cómo leer sin llenar el contexto

1. Lista los archivos de la carpeta con su tamaño.
2. Para cada módulo, lee la **cabecera** (los primeros comentarios) y las funciones públicas (`function M.`). Los archivos de más de 1.000 líneas se leen por partes, buscando lo de la tabla.
3. Busca patrones con grep en vez de leerlo todo:
   - `OnServerEvent` → ¿valida tipos, distancias y recargas antes de actuar?
   - `:Connect(` sin `Disconnect` o `Destroy` asociado → posible fuga.
   - `while true do`, `Heartbeat:Connect`, `RenderStepped` → ¿cuánto hace cada fotograma?
   - `wait(` (el viejo, no `task.wait`), `spawn(`, `delay(` → API obsoleta.
   - `.Touched` en el combate → prohibido; tiene que ser `Combat/Hitbox`.
   - números sueltos en la lógica → deberían estar en `Config` o `Data`.
   - `pcall` alrededor de los DataStore y de `MarketplaceService`.
4. Apunta solo lo que veas en el código, con archivo y línea. **No inventes**: si no has leído una función, no opines sobre ella.

## Formato del informe

Guárdalo en `docs/llm-local/informes/AAAA-MM-DD-<carpeta>.md`:

```markdown
# Auditoría: <carpeta> (<fecha>)

## Resumen
Tres o cuatro frases: qué hace la carpeta y en qué estado está.

## Bien
- …

## Riesgos (de mayor a menor)
| Gravedad | Archivo:línea | Qué pasa | Cuándo se nota |
|---|---|---|---|

## Deuda técnica
- …

## Preguntas
- Lo que no has podido comprobar sin Studio o sin dos jugadores.
```

**Gravedad:**
- **Alta:** se pierde progreso, se duplican compras o un cliente puede hacer trampa.
- **Media:** fugas, rendimiento o errores en casos raros.
- **Baja:** estilo y orden.

Las alertas de la gravedad alta, revísalas con Claude antes de cambiar nada.
