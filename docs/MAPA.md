# Guía del mapa: cómo conectar tu isla con el código

El mapa lo construyes tú en Roblox Studio (place **Isla**). El código encuentra las piezas importantes por su **nombre** o por un **atributo**. Esta guía dice qué tiene que tener el mapa para que todo funcione.

> 💡 Mientras el mapa no tenga estas piezas, el juego crea versiones **de prueba** automáticamente (una zona verde en el centro y árboles, rocas y arbustos alrededor), y lo avisa en la Salida.

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
| `ResourceNode` | string | `Tree` | 🪵 Madera |
| `ResourceNode` | string | `Rock` | 🪨 Piedra |
| `ResourceNode` | string | `Bush` | 🌿 Fibra |

- En un **Model**, el aviso de recolección aparece sobre su `PrimaryPart` (o sobre su primera pieza si no tiene).
- Pon los puntos **fuera** del Basecamp: dentro no debe haber recursos (GDD §10).
- Los tiempos, cantidades y usos se ajustan en `src/shared/Data/ResourceNodes.luau`.
- Si el valor está mal escrito (por ejemplo `tree` en minúsculas), la Salida avisa: *"ResourceNode = … no es un tipo válido"*.

**Consejo:** busca árboles y rocas low-poly en la **Caja de herramientas** (Creator Store), ponles el atributo y duplícalos (`Ctrl+D`). El atributo se copia con ellos.
