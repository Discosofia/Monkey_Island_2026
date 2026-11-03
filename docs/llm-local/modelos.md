# Modelos 3D voxel (resumen de la skill modelos-3d-roblox)

<!-- Fuente: .claude/skills/modelos-3d-roblox/SKILL.md, 03-11-2026. Detalles: references/estilo-del-proyecto.md (§1 dónde vive cada modelo, §4 paleta, §5 tamaños, §6 presupuesto de piezas, bloques de diseño, triángulos y técnicas de calidad, §8 voxel). -->

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
   - presupuesto de piezas (los topes están en `Config.Budgets`); en monos y jefes, también bloques de diseño y triángulos.

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
- Serpiente (Quetzalcóatl): secciones achaflanadas que se solapan entre tramos; la S de reposo va en las articulaciones (`rest`).
- Plumas en hoja de tres cajas gruesas (no palos finos); el penacho, en capas con inclinaciones distintas para que tenga volumen.
- Si el usuario pide añadir una pieza, no muevas nada más.

## Monos y jefes: más calidad sin más piezas (Fase 20)

- Topes en juego: mono 14 piezas, jefe 40. Son las piezas después de unir (`UnionAsync`).
- Tienen también topes de **bloques de diseño** (antes de unir, `Config.Budgets.Models.MonkeyDesign`) y de **triángulos** (`MonkeyTriangles`), por tier de `Data/Monkeys`, más `Alpha` y `Boss`.
- **Prioridad de la calidad:** jefes, monturas, mascotas, armaduras y armas, en ese orden. Los monos y los construibles usan el margen que sobre.
- **Monos congelados:** no suben. Hoy, bloques de diseño 106 / 127 / 75 por tier y triángulos 1.796 / 2.076 / 1.090; las alfas, 140 bloques y 2.352 triángulos. Solo reciben técnicas que no cuestan triángulos.
- **Jefes:** tope de 2.000 bloques de diseño y 15.000 triángulos (el Gorila de Ceniza, ya hecho: 744 bloques y ~11.000 triángulos; los otros 3, ~430 bloques y ~4.000 triángulos). Se construyen la primera vez que aparecen, sin precalentar: unir cuesta ~1 ms por bloque, ~2 s con 2.000, una vez por jefe y servidor.
- **Triángulos del equipo:** cada pieza de equipo tiene su tope (`MountTriangles`, `PetTriangles`, `ArmorTriangles`, `OutfitTriangles`, `WeaponTriangles`, `WeaponSkinTriangles`, `LabWeaponTriangles`): el máximo medido × lo concedido (monturas y armas +100 %, mascotas +50 % y +100 % las especiales, armaduras y trajes +60 %). Una esfera, un cilindro o una cuña cuestan más triángulos que un bloque (224, 64 y 8 frente a 12): para ganar redondez, mejor cuñas.
- **Escena:** el tope es 650.000 triángulos por escena. Dunas con 10 jugadores es el límite real (487.493 hoy, ~810.000 con los topes concedidos).
- Cuatro técnicas para más calidad sin subir las piezas en juego:
  1. Sombreado pintado: 2 o 3 tonos por color (claro arriba, oscuro abajo y en las uniones).
  2. Rejilla más fina en cara, manos y ojos: sube bloques y triángulos, no piezas.
  3. Biseles con cuñas en orejas y hombros: las cuñas no se fusionan, así que cuestan piezas; en monos y jefes el spec solo admite bloques, y ahí se hacen con escalones.
  4. Acentos de material (Neon, Glass, Foil) en piezas sueltas (`VOXEL_LOOSE` en `MonkeyModels`). Sin transparencia parcial ni texturas.
- Mide con `informe({ foto = true })`: la columna «Δ tris» compara con `RendimientoBase`.
- **Mallas con textura (Fase 21, jefes):** si una parte está en `Data/BossMeshes`, `MonkeyModels` usa una `MeshPart` (silueta con los bloques ≥ 0,2 studs; los finos, pintados en la textura) en lugar de la unión; se genera con `tools/mallas.py` y se importa con Import 3D. Lo de otro material o por fase sigue siendo unión. El spec en bloques sigue siendo la fuente.
- Los monos se copian de una plantilla que `MonkeyModels.prewarm` llena al arrancar el servidor; los jefes no se precalientan.
- **Receta de jefe (Gorila de Ceniza, Fase 20 Q2):** 744 bloques de diseño, 30 piezas, ~11.000 triángulos y 0,49 s de unión. Todo lo nuevo va dentro de la unión de su parte; lo de otro material, en grupos.
  - Ayudantes de `VoxelSpecs/Gorila.luau`: `tower` (escalones: volcán, espinas, cuernos), `vein` (venas de lava sobre una superficie), `frame` (marco de lava en el borde de una losa) y `mottle(..., thick)` (manchas finas o matas de pelo con relieve).
  - `phaseColors` por fase en un grupo: cambia de color sin piezas extra (`MonkeyModels.showPhase` lo cambia con `BossPhase`).
  - Piel y ojos por fase: `phaseFaces` pone una capa de piel por fase y ojos de neón con expresión.
  - La fase 3 se distingue por detrás (erupción, llamaradas, puntas al rojo), no solo de frente.
  - Con la caché de `require` de Studio, para ver un cambio del spec clona la carpeta `Combat.Monkeys` entera.

## Cerrar

- El constructor final va al archivo del repo. `stylua src` y `selene src`.
- Antes del commit, mide el modelo con la calculadora `Rendimiento` (`ServerStorage.Tools`, en el Studio de la Isla) y revisa que no pase del tope de `Config.Budgets`. En un mono o jefe, mira también los bloques de diseño, los triángulos y la escena de la Isla.
- Si cambias colores en `Data/...`, comprueba con `git diff` que solo cambió la entrada que querías.
- Deja la vista previa montada para que el usuario la apruebe. Solo cuando la apruebe, `Preview.clear()`.
- No toques `Workspace.Mapa` ni `Workspace.Naufragio` a mano: los generadores los rehacen.
