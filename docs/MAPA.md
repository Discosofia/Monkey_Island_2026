# Guía del mapa: cómo conectar tu isla con el código

El mapa vive en el place **Isla** de Roblox Studio. El código encuentra las piezas importantes por su **nombre** o por un **atributo**. Esta guía explica cómo **generar la isla provisional** y qué tiene que tener el mapa para que todo funcione.

> 💡 Mientras el mapa no tenga estas piezas, el juego crea versiones **de prueba** automáticamente (una zona verde en el centro y árboles, rocas y arbustos alrededor), y lo avisa en la Salida.

---

## Generar la isla provisional (MapBuilder)

El generador `MapBuilder` construye en un minuto la isla completa del GDD en versión *greybox*, lista para jugar y para retocar a mano.

![Vista previa aproximada de la isla generada](img/mapa-vista-previa.png)

*Vista previa aproximada, vista desde arriba con el norte (Z negativa) arriba. En Roblox el relieve fino cambia un poco, pero la distribución es la misma.*

| En la imagen | Qué es |
|---|---|
| Círculo marrón en el centro | **Basecamp:** meseta plana con empalizada de 4 entradas, hoguera y 4 puntos de aparición. El cuadrado verde es la `BasecampZone`. |
| Gris, noroeste | **Montañas.** La línea negra es la **cueva**: entrada en la falda que mira al Basecamp, túnel y sala al fondo. |
| Oscuro, noreste | **Volcán** con cráter de lava. |
| Azul | **Río:** nace al pie de las montañas, rodea el Basecamp por el sur y desemboca al sureste. |
| Marrón junto a la desembocadura | **Manglar** (barro). |
| Anillo claro | **Playas.** Más allá, el mar y un **muro invisible** (círculo blanco) para que nadie salga. |
| Puntos verdes, claros y blancos | **Árboles, arbustos y rocas** (unos 290), fuera del Basecamp, la playa y el río. |
| Cuadrados rosas | **Guaridas de los 4 jefes** (marcadores invisibles para la Fase 5). |

### Cómo ejecutarlo

1. **Guarda una copia** del place por si quieres volver atrás: **Archivo → Publicar en Roblox**. Luego podrás recuperarlo desde el historial de versiones.
2. Abre la **Isla** en Studio, lanza `rojo serve island.project.json` y conecta Rojo (puerto **34873**). Comprueba que en **ServerStorage** aparece la carpeta `Tools` con `MapBuilder`.
3. Sin pulsar Play, haz clic en la **barra de comandos**: la barra larga de la parte de abajo de Studio que dice *"Ejecutar un comando con Ctrl↵…"*. Si no la ves, ábrela desde el menú **Ventana**. Pega esto y pulsa **Ctrl+Enter** (o el botón **▷ Ejecutar**):
   ```lua
   require(game.ServerStorage.Tools.MapBuilder).build()
   ```
4. Espera alrededor de un minuto. La **Salida** muestra el progreso y termina con *"¡Isla lista!"*.
5. Pulsa **Play** para probarla y, si te gusta, **Archivo → Publicar en Roblox**.

**Opciones:**
- `build({ seed = 7 })`: otro reparto aleatorio de colinas, costa y recursos.
- `build({ islandRadius = 800 })`: una isla más grande. Por defecto el radio es 650 studs, unos 40 segundos a pie del centro a la playa.

> ⚠️ **El generador borra y rehace todo:** el terreno, la carpeta `Workspace.Mapa`, la Baseplate y los SpawnLocation sueltos. Úsalo para la versión inicial. Si después retocas el terreno a mano (**Editor de terreno**) o colocas modelos dentro de `Mapa`, **no lo vuelvas a ejecutar** o perderás esos cambios. Pon tus modelos propios **fuera** de la carpeta `Mapa`, por ejemplo en `Workspace/Decoracion`.

---

## Cómo añadir un atributo en Studio

1. Selecciona el objeto (Part o Model) en el **Explorador**.
2. En **Propiedades**, baja hasta **Atributos** y pulsa **+** (*Agregar atributo*).
3. Escribe el **nombre**, elige el **tipo** (*string* = texto) y pulsa **Guardar**.
4. Escribe el **valor** en la casilla que aparece.

---

## Basecamp: zona segura (entrega 1.1)

| Qué | Cómo |
|---|---|
| Pieza de la zona | Una **Part** llamada exactamente `BasecampZone` que cubra todo el Basecamp, incluida la altura donde caminan los jugadores. |
| Propiedades recomendadas | `Anchored` ✅, `CanCollide` ❌, `CanTouch` ❌, `CanQuery` ❌, `Transparency` = 1 (invisible). |
| Dónde | Puede estar dentro de carpetas (por ejemplo `Workspace/Mapa/BasecampZone`). |
| Aparición | Pon el **SpawnLocation** dentro de la zona: los jugadores aparecen en el Basecamp. |

Puedes rotarla y darle el tamaño que quieras. El código respeta su forma de caja.

---

## Puntos de recolección (entrega 1.2)

Cualquier **Model** o **Part** con este atributo se convierte en un punto de recolección:

| Atributo | Tipo | Valor | Da |
|---|---|---|---|
| `ResourceNode` | string | `Tree` | 🌲 Madera |
| `ResourceNode` | string | `Rock` | ⛰️ Piedra |
| `ResourceNode` | string | `Bush` | 🌿 Fibra |

- En un **Model**, el aviso de recolección aparece sobre su `PrimaryPart` (o sobre su primera pieza si no tiene).
- Pon los puntos **fuera** del Basecamp: dentro no debe haber recursos (GDD §10).
- Los tiempos, cantidades y usos se ajustan en `src/shared/Data/ResourceNodes.luau`.
- Si el valor está mal escrito (por ejemplo `tree` en minúsculas), la Salida avisa: *"ResourceNode = … no es un tipo válido"*.

**Consejo:** busca árboles y rocas low-poly en la **Caja de herramientas** (Creator Store), ponles el atributo y duplícalos (`Ctrl+D`). El atributo se copia con ellos.
