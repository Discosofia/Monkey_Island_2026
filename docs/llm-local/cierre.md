# Cierre de grupo (resumen de la skill ship)

<!-- Fuente: .claude/skills/ship/SKILL.md, 11-11-2026. Detalles: docs/PLAN.md (filas y Handoff) y tools/strings.py. -->

Solo después de que el usuario diga «aprobado» para ese grupo. Si no lo ha dicho, para y pídelo. Uso: `/ship <grupo>`, por ejemplo `/ship G14d`.

1. `git status`: lista solo los archivos de esta tarea y enséñaselos. Lo que no es tuyo se queda fuera.
2. Mira `git log @{u}..HEAD`. Si hay commits de otra fase sin subir, pregunta antes.
3. Añade al índice solo esos archivos (nunca `git add -A` ni `git add .`). Commit `<grupo>: <resumen>` en español, y después `git push`.
4. Marca la fila del grupo en `docs/PLAN.md` con el hash y el estado, con la herramienta de edición. Va en un commit aparte y después `git push`.
5. Frases nuevas con `T()`: `python tools/strings.py` y `python tools/strings.py --csv-nuevas build/localization_nuevas.csv`. Dile al usuario qué archivo subir a Creator Hub (máximo 90 filas; si pasa, `_1`, `_2`…). Cuando confirme, `--marcar-subidas` e incluye `tools/strings_subidas.txt` en un commit.
6. Lo que no se pudo probar tiene que estar en `docs/VERIFICACION.md` en el mismo commit del cambio. Comprueba que está y remite a esa sección; no lo repitas.
7. Escribe el Handoff del grupo siguiente en `docs/PLAN.md` (objetivo, archivos, problemas abiertos, trampas y primeros pasos) y dale al usuario el prompt para la pestaña nueva.
