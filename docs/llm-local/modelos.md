# Modelos 3D voxel (resumen de la skill modelos-3d-roblox)

<!-- Fuente: .claude/skills/modelos-3d-roblox/SKILL.md, 26-10-2026. Detalles: references/estilo-del-proyecto.md (§1 dónde vive cada modelo, §4 paleta, §5 tamaños, §6 presupuesto de piezas, §8 voxel). -->

## Antes de empezar

1. `list_roblox_studios` y `get_studio_state`: tiene que estar en **Edit**.
2. Lee `.claude/skills/modelos-3d-roblox/references/estilo-del-proyecto.md`, la sección que toque.
3. Escribe una **ficha**:
   - qué es y para qué se usa;
   - dónde vive (módulo del repo: `Shared/PetModels`, `Shared/MountModels`, `island/server/Monkeys/VoxelSpecs/<Especie>.luau`, `Combat/ArmorModels`…);
   - tamaño en studs comparado con un personaje de 5;
   - las 3–6 masas que lo hacen reconocible;
   - paleta de 3–6 colores;
   - el frente mira a **-Z**;
   - presupuesto de piezas.

## Técnicas

- **Voxel (por defecto para animales):** un archivo de datos `VoxelSpecs/<Especie>.luau` con cajas, que lee un constructor genérico. Es lo más barato y lo que pide el estilo.
- **Primitivas por código:** un constructor Luau en el módulo, con medidas derivadas de pocas variables (`height`, `width`) y simetría con `for side = -1, 1, 2`.
- Las mallas, `generate_mesh` y Blender, solo si el usuario lo pide.
- Con una foto de referencia: copia la silueta, las proporciones y los colores, **no la pose**. Los monos van a cuatro patas porque así parten sus animaciones.

## Ciclo de revisión (sin ver imágenes)

1. Manda con `execute_luau` el contenido de `.claude/skills/modelos-3d-roblox/scripts/vista_previa.luau` más tu llamada. La primera vez termina con `_G.Preview = Preview`; después basta `local Preview = _G.Preview`.
   ```lua
   local model = Preview.freshRequire("ReplicatedStorage.Shared.PetModels").build("Tucan")
   return Preview.show(model)
   ```
2. `Preview.show` devuelve el tamaño, el número de piezas y las cámaras. **Revisa los números:**
   - ¿El tamaño es el de la ficha frente al maniquí de 5 studs?
   - ¿Las piezas están dentro del presupuesto?
   - ¿Hay piezas flotando? Compara las posiciones con `GetBoundingBox` de cada parte.
   - ¿Es simétrico?
3. Pide al usuario que mire `Workspace._VistaPrevia` en su Studio. Deja la cámara apuntando con `Preview.look(posicion, objetivo)`, y al terminar ponla en `Fixed`.
4. Corrige lo más gordo primero: silueta y proporciones antes que detalles. Haz como mucho 5 vueltas antes de enseñarlo.

## Reglas del estilo

- Bloques visibles en rejilla, pocos tonos planos y ligeras variaciones de tono por zonas.
- Las variantes (alfa, rareza, skin) necesitan colores **y** rasgos nuevos, no un tinte suave. Se tienen que reconocer por detrás.
- Lo que se lleva puesto necesita una espalda llamativa: el jugador lo ve desde atrás todo el rato.
- Hombreras: losas cuadradas, estrellas, círculos u óvalos planos como monedas. Nunca óvalos como almohadas.
- Los grados de un mismo set comparten materiales, paleta y motivos.

## Animales grandes y monturas (lo aprendido con el Jaguar, octubre de 2026)

- Busca las proporciones reales del animal: el jaguar tiene la cruz a la mitad del largo y la cola en un 41 %. Si no, sale chaparro.
- El tronco nunca es una sola caja: tramos (pecho, cintura, grupa) con los cantos achaflanados y musculatura en escalones de tono.
- La cara sube en escalones de la nariz a la frente. El hocico tiene que estar marcado. Los ojos van pequeños y con párpado. Los orificios de la nariz, pequeños y en las esquinas de abajo.
- Las rosetas son un anillo de manchas sueltas: con barras parecen letras.
- El arnés o la silla no puede ser del color de las manchas.
- No dejes rendijas entre tramos: revisa con una cámara baja.
- El cuello no es más alto que la cabeza.

## Cerrar

- El constructor final va al archivo del repo. `stylua src` y `selene src`.
- Si cambias colores en `Data/...`, comprueba con `git diff` que solo cambió la entrada que querías.
- Deja la vista previa montada para que el usuario la apruebe. Solo cuando la apruebe, `Preview.clear()`.
- No toques `Workspace.Mapa` ni `Workspace.Naufragio` a mano: los generadores los rehacen.
