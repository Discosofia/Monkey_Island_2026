# Interfaz (resumen de la skill interfaz-roblox)

<!-- Fuente: .claude/skills/interfaz-roblox/SKILL.md, 26-10-2026. Detalles: references/estilo-ui.md (§1 dónde se crea cada pieza, paleta, capas, §6 mapa de la pantalla, §7 dependencias, §8 opciones en Ajustes). -->

Toda la interfaz se hace **por código**: no hay nada a mano en `StarterGui`. Los cambios van al repo. Studio sirve para medir.

## Ficha

- Qué pieza es y para qué: se mira de reojo, se pulsa a menudo o es un aviso de un momento.
- Dónde se crea: busca con grep por su texto. Está en `src/<place>/client/Controllers/` o en `src/shared/UI/`.
- En qué place va: Isla, Lobby o ambos.
- Su sitio en el **teléfono apaisado (844 x 390)** y en el PC. Abajo a la derecha, en el móvil, están el salto y los botones táctiles.
- Sus estados: vacío, texto largo, día y noche, con jefe.
- Qué piezas dependen de ella (por ejemplo, el ⚙️ va pegado a "Volver al Lobby").
- Si hay varias formas razonables, el usuario prefiere ofrecerlas como **opciones del jugador en Ajustes**.

## Reglas de coherencia

1. Usa `Widgets.screen`, `Widgets.label` y `Widgets.button` (`src/shared/UI/Widgets`).
2. Paleta: dorado para las acciones, madera oscura para los fondos, y verde, naranja y rojo para bien, aviso y peligro.
3. Fuente BuilderSans; texto blanco con borde sobre el mundo; emojis como iconos (salvo en la ventana del pase).
4. Esquinas de 12–14 px, botones de al menos 44 px (mejor 48) en el móvil, margen del 2 % y `UISizeConstraint`.
5. Posiciones con `fromScale` y `AnchorPoint` en la esquina a la que se pega la pieza.
6. Lo que va junto, en un `Frame` con `UIListLayout`.
7. Lo que sale en el centro de la pantalla dura poco y no bloquea los toques (`Active = false`).
8. En el PC, las ventanas se ven **enteras sin desplazamiento** (salvo el pase y los Estilos del Armario).

## Medir en Studio

- **Maqueta (Edit):** manda `.claude/skills/interfaz-roblox/scripts/maqueta_ui.luau` más tu código. Devuelve `UI.informe()` con solapes, piezas fuera de la pantalla, botones pequeños y textos de menos de 11 px. Lee el informe: es tu forma de "ver". Usa textos del caso peor.
  ```lua
  _G.UI = UI
  local Widgets = UI.freshRequire("ReplicatedStorage.Shared.UI.Widgets")
  UI.montar({ "telefono", "pc" })
  UI.cada(function(pantalla)
  	local reloj = Widgets.label("Día 12 · 🌙 10:00", pantalla.normal)
  	reloj.AnchorPoint = Vector2.new(1, 1)
  	reloj.Position = UDim2.fromScale(0.98, 0.98)
  	reloj.Size = UDim2.fromScale(0.3, 0.06)
  end)
  return UI.informe()
  ```
- **Antes de dar a Play, `UI.limpiar()`**: si no, la maqueta sale en el juego.
- **HUD real (Play, `datamodel_type = "Client"`):** `scripts/volcar_hud.luau` y `return Hud.volcar()` dan el rectángulo de cada pieza y los solapes.
- El emulador de teléfono no se activa desde el MCP: pídeselo al usuario.

## Cerrar

`stylua src` y `selene src`. Comprueba que no queda `StarterGui._VistaPreviaUI`. Di qué no has podido comprobar.
