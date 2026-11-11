---
name: ship
description: Cierra un grupo de docs/PLAN.md cuando el usuario ya ha dicho «aprobado»: commit solo de los archivos de la tarea, push, hash y estado en PLAN.md en un commit aparte, frases nuevas para Creator Hub y Handoff del grupo siguiente. Úsala con /ship <id del grupo> (por ejemplo /ship G14d). No la uses sin la aprobación explícita del usuario.
---

Requisito: el usuario ya ha escrito «aprobado» para este grupo. Si no, para y pídelo.

1. Ejecuta `git status`. Lista **solo** los archivos que cambiaste en esta tarea y enséñaselos al usuario. Los cambios sin confirmar que no son tuyos se quedan fuera.
2. Comprueba si hay commits anteriores sin subir (`git log @{u}..HEAD`). Si son de otra fase, pregunta antes de subirlos.
3. Añade al índice solo esos archivos (nunca `git add -A` ni `git add .`). Haz el commit con el mensaje `<grupo>: <resumen>` en español, con la línea de atribución que pide la sesión, y después `git push`.
4. Con la herramienta Edit (no `sed` ni heredocs), marca la fila del grupo en `docs/PLAN.md` con el hash del commit y su estado. Va en un commit aparte; después `git push`.
5. Si hay frases nuevas con `T()`: `python tools/strings.py` y `python tools/strings.py --csv-nuevas build/localization_nuevas.csv`. Dile al usuario qué archivo(s) subir a Creator Hub (el CSV admite 90 filas; si pasa, `_1`, `_2`…). Cuando confirme la subida, `python tools/strings.py --marcar-subidas` y se incluye `tools/strings_subidas.txt` en un commit.
6. Lo que no se pudo probar ya está en `docs/VERIFICACION.md` (mismo commit que el cambio). Comprueba que está y remite a esa sección; no lo repitas.
7. Escribe el Handoff del grupo siguiente en `docs/PLAN.md`: objetivo, archivos tocados, problemas abiertos, trampas conocidas y primeros pasos. Dale al usuario el prompt para la pestaña nueva.

Uso: `/ship G14d`
