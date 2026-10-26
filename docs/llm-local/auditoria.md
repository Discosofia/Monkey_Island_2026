# Auditoría de código: archivo por archivo

<!-- Método para gpt-oss-20b, 26-10-2026 (v3). La v1 (vista general por carpeta) inventó funciones y líneas. La v2 citaba bien, pero sus tres riesgos eran falsos: no miraba de dónde venían los valores ni leía bien la línea que citaba. Por eso la v3 añade el origen y la contraprueba. -->

**Objetivo:** saber qué riesgos reales tiene un archivo, con pruebas. **No se cambia código durante la auditoría.**

> **Límite comprobado (26-10-2026):** en una prueba con dos fallos graves puestos a propósito en una copia de `Eggs.luau`, gpt-oss-20b no encontró ninguno: había Ámbar infinito al descartar y un huevo que pisaba al del nido. En cambio, apuntó cinco riesgos que no existían. Su informe sirve como **resumen** del archivo, pero un "Ninguno encontrado" suyo no demuestra que el archivo esté bien. La búsqueda de riesgos la hace Claude.

## Las tres reglas

1. **Un solo archivo por conversación.** Solo opinas del archivo que estás auditando. Si algo depende de otro archivo, va a "Preguntas", no a "Riesgos".
2. **Cada afirmación lleva su línea copiada tal cual.** Copia el texto exacto del archivo (con el número de línea que da la herramienta de lectura) en un bloque de código. Si no puedes copiar una línea que lo demuestre, no lo escribas.
3. **Solo existen las funciones que has visto.** Antes de escribir, haz la lista de funciones del archivo (paso 2). Si vas a nombrar una función que no está en esa lista, estás inventando: bórralo.

## Pasos

1. **Lee el archivo entero.** Si tiene más de 300 líneas, léelo en trozos de 300 (1–300, 301–600…) hasta el final. No te saltes trozos.
2. **Haz la lista de funciones** con grep de `function` sobre ese archivo. En el informe pon una por línea: número y la línea entera (`65: local function grantReceipt(player: Player, key: string, purchaseId: string)`). Si tu grep solo da números, léelos en el archivo y copia el texto.
3. **Busca los patrones** con grep **solo en ese archivo**:
   - `OnServerEvent`: lo que llega del cliente. ¿Comprueba el tipo (`typeof`), que exista lo pedido, que el jugador lo tenga y la recarga antes de actuar?
   - `:Connect(`: ¿se desconecta o se destruye su dueño? Las conexiones a `Players.PlayerAdded` o `PlayerRemoving` que viven todo el servidor están bien.
   - `while true do`, `Heartbeat`, `RenderStepped`: ¿cuánto trabajo hace cada vuelta?
   - `wait(`, `spawn(`, `delay(` sin `task.`: API vieja.
   - `.Touched`: prohibido en el combate (se usa `Combat/Hitbox`).
   - `GetAsync`, `SetAsync`, `UpdateAsync`, `MarketplaceService`: ¿van dentro de `pcall`?
   - Números sueltos en la lógica: deberían estar en `Config` o en `Data`.
4. **Comprueba cada hallazgo antes de apuntarlo:** haz grep del texto que vas a citar y confirma que sale en ese archivo y en esa línea. Si no sale, bórralo.
5. **Sigue el origen del valor.** Antes de decir que un parámetro es peligroso, averigua de dónde viene:
   - Dentro del archivo: busca dónde se llama la función y qué se le pasa (por ejemplo `tostring(receipt.PurchaseId)`).
   - Fuera del archivo: haz grep del nombre de la función en `src/` para ver quién la llama.
   - Solo es un riesgo de trampa si el valor llega del cliente: un parámetro de `OnServerEvent` o `OnServerInvoke`. Si lo crea el servidor o lo da Roblox (`ProcessReceipt`, `PlayerAdded`), no lo es.
   - Escribe el origen en el riesgo (línea "Origen").
6. **Haz la contraprueba.** Para cada riesgo, escribe en una frase por qué podría **no** ser un riesgo, mirando la línea citada y las 10 de alrededor:
   - un bucle o un `if` que ya lo limita (`while #lista > Config.X do table.remove`);
   - un `pcall`;
   - una comprobación previa (`typeof`, `if not … then return`);
   - código que solo corre en Studio (`RunService:IsStudio()`);
   - comportamiento de Roblox: un error dentro de `task.spawn` sale en la consola, no se pierde.

   Si la contraprueba lo desmiente, **borra el riesgo**. Si dudas, pásalo a "Preguntas".
7. **Escribe el informe.**

## Formato del informe

Guárdalo en `docs/llm-local/informes/AAAA-MM-DD-<Archivo>.md` (por ejemplo `2026-10-27-Purchases.md`):

````markdown
# Auditoría: src/serverShared/Purchases.luau (2026-10-27)

Líneas leídas: 1–161 de 161.

## Funciones del archivo
(una por línea: número y la línea entera)

## Qué hace
Dos o tres frases, sacadas de la cabecera del archivo.

## Riesgos (de mayor a menor)

### 1. <Gravedad>: <una frase>
Línea <n>:
```lua
<la línea copiada tal cual, y las 2 o 3 de alrededor si hacen falta>
```
Origen: <de dónde viene el valor: cliente, servidor o Roblox, con la línea que lo muestra>
Qué pasa: …
Contraprueba: <por qué podría no ser un riesgo, y por qué aun así lo es>
Cuándo se nota: …

(Si no hay riesgos, escribe "Ninguno encontrado" y qué has buscado.)

## Bien
- <una frase>. Línea <n>: `<línea copiada>`

## Preguntas
- Lo que depende de otros archivos o que no se puede comprobar sin Studio o sin dos jugadores.
````

**Gravedad:**
- **Alta:** se pierde progreso, se duplican compras o un cliente puede hacer trampa.
- **Media:** fugas, rendimiento o errores en casos raros.
- **Baja:** estilo y orden.

Mejor un informe con un solo riesgo verdadero que con cinco dudosos. "Ninguno encontrado" es una respuesta válida.

## Orden para `src/serverShared`

De más delicado a menos. Los números son líneas.

| # | Archivo | Líneas | Qué mirar sobre todo |
|---|---|---|---|
| 1 | `Purchases.luau` | 161 | Recibo idempotente, `ProcessReceipt`, qué pasa si falla la entrega |
| 2 | `PlayerData.luau` | 437 | Bloqueo de sesión, `pcall` en el DataStore, guardado al salir y en `BindToClose` |
| 3 | `SeasonPass.luau` | 422 | Que no se pueda reclamar dos veces ni reclamar un nivel no alcanzado |
| 4 | `Retention.luau` | 492 | Misiones y calendario: premios repetidos, cambio de día |
| 5 | `Eggs.luau` | 197 | Tiempos de huevo decididos por el servidor |
| 6 | `CosmeticsServer.luau` | 769 | Que solo se equipe lo que se tiene |
| 7 | `MountServer.luau` | 170 | Lo que llega del cliente |
| 8 | `Admin.luau` | 177 | Quién puede usarlo |
| 9 | `ArenaShop.luau`, `Supplies.luau`, `Teleporter.luau` | 120, 43, 131 | Precios y teletransportes pedidos por el cliente |
| 10 | El resto | | Solo si sobra tiempo |

`NodeModels.luau` (1.074 líneas) solo construye modelos: no hace falta auditarlo.

## Cómo pedirlo

En un chat nuevo de CodeGPT:

> Lee docs/llm-local/auditoria.md y audita solo src/serverShared/Purchases.luau siguiendo sus pasos.

Las alertas de gravedad alta se revisan con Claude antes de cambiar nada.
