# Cinemáticas (resumen de la skill cinematicas-roblox)

<!-- Fuente: .claude/skills/cinematicas-roblox/SKILL.md, 11-11-2026. Detalles: docs/PLAN.md (Fase 25, trampas de cada Handoff) y tools/cine_qa.luau. -->

Las escenas viven en `Shared/Data/Scenes/<Nombre>.luau`, con `CinematicKit`, y se registran con una línea en `Data/Cinematics`. Toda escena lleva `hour` (`DUSK_HOUR` 18,8) y no se escribe `Lighting` a mano. **No quites el `seek`**: alinea los eventos de servidor (`bossAct`, monos…). Jefe de plató: `stageShow` lo sube y `stageHide` lo esconde (nace enterrado, atributo `StageSpot`). Cada jefe de plató tiene su entrada en `Shared/Data/StageBosses` y se monta con `StageBoss.mount`; `IslandBossHooks` avisa con `[StageBosses]` si la tabla no cuadra con los eventos.

1. Antes de pedir que grabe: el avatar y las monturas apoyados en el suelo con raycast; ningún terreno, árbol o prop los atraviesa; el avatar de escena lleva el vestuario de la escena, no el equipo del jugador; títulos y rótulos no tapan al sujeto (cámara a menos de 9–12 studs tapa la imagen; con la cámara a menos de 3 studs de altura la hierba tapa al sujeto, así que usa 4,5 st o más); cada jefe tiene su coreografía; el cierre no pone actores sobre estructuras.
2. `waitTerrain` compara `anchor.Y + point.Y`: mide la altura real o se pierde la apertura sin aviso.
3. Cómic: el `ScreenGui` usa `ZIndexBehavior.Global`; cartel en y=0,70 y subtítulo en y=0,80; «Saltar» (abajo a la derecha) no lo tapa ningún texto.
4. Luz: a 19,5 h los actores salen negros; los tintes naranja apilados amarillean. Usa luz fría que siga a la cámara. El reloj: `clock seconds` son los segundos para recorrer 12 h, no la duración; usa seconds = 12·duración/|Δhora|.
5. Probar: Play escribe el perfil real, así que copia `PlayerData_v1` antes y restaura después. Las escenas se prueban en Play; `require` de `Data/Cinematics` en edición se cuelga.
6. Revisión antes de grabar: `tools/cine_qa.luau` marca suelo, terreno, deslizamiento, atravesar, fuera de pantalla, textos encima y luz extrema, con hora. Son pistas, no sentencias. Las capturas se hacen una a una. Al terminar, la cámara de edición vuelve a `Fixed`.
7. Barra del jefe y reloj: `dayClock` acepta `drop` (px). El cartel de la parcela se apaga con `plotSign {show}` y `plotMarker {sign=false}`; el título del cierre no puede caer sobre él.
