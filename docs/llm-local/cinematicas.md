# Cinemáticas (resumen de la skill cinematicas-roblox)

<!-- Fuente: .claude/skills/cinematicas-roblox/SKILL.md, 11-11-2026. Detalles: docs/PLAN.md (Fase 25, trampas de cada Handoff) y tools/cine_qa.luau. -->

Las escenas viven en `Shared/Data/Scenes/<Nombre>.luau`, con `CinematicKit`, y se registran con una línea en `Data/Cinematics`. Toda escena lleva `hour` (`DUSK_HOUR` 18,8) y no se escribe `Lighting` a mano. **No quites el `seek`**: alinea los eventos de servidor (`bossAct`, monos…).

1. Antes de pedir que grabe: el avatar y las monturas apoyados en el suelo con raycast; ningún terreno, árbol o prop los atraviesa; el avatar de escena lleva el vestuario de la escena, no el equipo del jugador; títulos y rótulos no tapan al sujeto (cámara a menos de 9–12 studs o hierba a menos de 8 studs tapa la imagen); cada jefe tiene su coreografía.
2. `waitTerrain` compara `anchor.Y + point.Y`: mide la altura real o se pierde la apertura sin aviso.
3. Cómic: el `ScreenGui` usa `ZIndexBehavior.Global`; cartel en y=0,70 y subtítulo en y=0,80; «Saltar» (abajo a la derecha) no lo tapa ningún texto.
4. Luz: a 19,5 h los actores salen negros; los tintes naranja apilados amarillean. Usa luz fría que siga a la cámara.
5. Probar: Play escribe el perfil real, así que copia `PlayerData_v1` antes y restaura después. Las escenas se prueban en Play; `require` de `Data/Cinematics` en edición se cuelga.
6. Revisión antes de grabar: `tools/cine_qa.luau` marca suelo, terreno, deslizamiento, atravesar, fuera de pantalla, textos encima y luz extrema, con hora. Son pistas, no sentencias. Las capturas se hacen una a una. Al terminar, la cámara de edición vuelve a `Fixed`.
