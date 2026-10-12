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
| Círculo marrón en el centro | **Basecamp** (170 studs de diámetro): meseta plana con empalizada de estacas con punta, 4 portones con dintel y antorchas, hoguera con bancos y 4 puntos de aparición. El cuadrado verde es la `BasecampZone`. |
| Verde con sombras | **Selva** con colinas (hasta unos 35 studs) y manchas de hierba animada y hojarasca. Se aplana cerca de la playa, el río, el Basecamp y la entrada de la cueva. |
| Puntos verde oscuro | **Árboles de selva** (~380, se talan y dan 🌲 madera) y **helechos** (~380, dan 🌿 fibra), agrupados en bosques con claros entre medias. |
| Gris, noroeste | **Montañas.** La línea negra es la **cueva**: entrada en la falda que mira al Basecamp, túnel y sala al fondo. |
| Oscuro, noreste | **Volcán activo:** lago de lava brillante, llamas, luz naranja, humo y chispas. |
| Azul | **Río:** nace al pie de las montañas, rodea el Basecamp por el sur y desemboca al sureste. |
| Marrón junto a la desembocadura | **Manglar** (barro). |
| Anillo claro con puntos amarillos | **Playas con palmeras** (~70). Más allá, el mar y un **muro invisible** (círculo blanco) para que nadie salga. |
| Puntos claros y blancos | **Recolectables:** árboles, arbustos y rocas (~290), fuera del Basecamp, la playa y el río. |
| Cuadrados rosas | **Guaridas de los 4 jefes** (marcadores invisibles para la Fase 5). |

### Cómo ejecutarlo

1. **Abre la Isla correcta.** Es el paso más importante:
   - En la pantalla de inicio de Studio, entra en **Primal Banana Island**. Se abre el Lobby, que es el lugar de inicio.
   - En el **Gestor de recursos → Lugares en la experiencia**, haz **doble clic en "Isla"**.
   - Comprueba **dos cosas** antes de seguir: en el Gestor de recursos el proyecto se llama **Primal Banana Island** y tiene **2 lugares**, y la Isla tiene el ID **84163809226177**.
   - ⚠️ Si el proyecto se llama de otra forma (por ejemplo "Isla" con un solo lugar), estás en **otra experiencia**. Lo que publiques ahí no aparecerá en el juego.
2. Lanza `rojo serve island.project.json` y conecta Rojo (puerto **34873**). Comprueba que en **ServerStorage** aparece la carpeta `Tools` con `MapBuilder`.
3. Sin pulsar Play, haz clic en la **barra de comandos**: la barra larga de la parte de abajo de Studio que dice *"Ejecutar un comando con Ctrl↵…"*. Si no la ves, ábrela desde el menú **Ventana**. Pega esto y pulsa **Ctrl+Enter** (o el botón **▷ Ejecutar**):
   ```lua
   require(game.ServerStorage.Tools.MapBuilder).build()
   ```
   Si el place abierto no es la Isla del juego, el generador **no hace nada** y lo avisa en la Salida.
4. Espera unos segundos. La **Salida** termina con *"¡Isla lista!"*.
5. Pulsa **Play** para probarla. Si te gusta, **Archivo → Publicar en Roblox**. No uses "Publicar en Roblox como…": con esa opción es fácil crear una experiencia nueva sin querer.
6. Para verla en el juego publicado, entra a un **servidor nuevo**. Los servidores que ya estaban abiertos siguen con la versión anterior.

**Opciones:**
- `build({ seed = 7 })`: otro reparto aleatorio de colinas, costa y recursos.
- `build({ islandRadius = 950 })`: una isla más grande. Por defecto el radio es 650 studs, unos 40 segundos a pie del centro a la playa; con 950 son unos 60 segundos.
  - La vegetación y los recursos **escalan con el tamaño**, así que la densidad de la selva es la misma. Con 950 salen unos 800 árboles, 800 helechos, 100 palmeras y 600 recolectables, unas 8.000 piezas en total.
  - La cueva se alarga para que la sala siga bajo la montaña.
- Se pueden combinar: `build({ islandRadius = 950, seed = 7 })`.

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
| `ResourceNode` | string | `Fern` | 🌿 Fibra (menos que un arbusto) |

- En un **Model**, el aviso de recolección aparece sobre su `PrimaryPart` (o sobre su primera pieza si no tiene).
- Pon los puntos **fuera** del Basecamp: dentro no debe haber recursos (GDD §10).
- Los tiempos, cantidades y usos se ajustan en `src/shared/Data/ResourceNodes.luau`.
- Si el valor está mal escrito (por ejemplo `tree` en minúsculas), la Salida avisa: *"ResourceNode = … no es un tipo válido"*.

**Consejo:** busca árboles y rocas low-poly en la **Caja de herramientas** (Creator Store), ponles el atributo y duplícalos (`Ctrl+D`). El atributo se copia con ellos.
