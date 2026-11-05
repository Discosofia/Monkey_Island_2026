--!strict
-- Dónde aparece cada jefe en la Isla y hacia dónde mira (Fase 25). Son coordenadas del mapa generado con
-- islandRadius = 950 (medidas con raycast en Studio, 05-11-2026); la altura sale del suelo (groundBelow).
-- "facing" es la dirección horizontal en que mira el jefe: la cinemática de aparición cuelga de ese giro.
--   Orangután: orilla del río del manglar, mirando al Basecamp.
--   Caudillo: la cima de la montaña (y ≈ 156), mirando al Basecamp.
--   Albino: centro de la sala de la cueva (redonda, radio ≈21, techo a 42), mirando a la boca del túnel.
--   Ceniza: el borde del cráter por el lado del Basecamp (suelo del cráter y = 129, borde y ≈ 162),
--           mirando hacia fuera del cráter; el cráter queda a su espalda.

export type Stage = {
	position: Vector3, -- solo X y Z cuentan; Y es una pista (el servidor busca el suelo)
	facing: Vector3, -- horizontal y unitario
}

local function horizontal(x: number, z: number): Vector3
	return Vector3.new(x, 0, z).Unit
end

local BossStages: { [string]: Stage } = {
	OrangutanDelManglar = { position = Vector3.new(404, 16, 533), facing = horizontal(-0.6, -0.8) },
	ChimpanceCaudillo = { position = Vector3.new(-474, 156, -412), facing = horizontal(0.76, 0.65) },
	GorilaAlbino = { position = Vector3.new(-393, 15, -349), facing = horizontal(0.75, 0.66) },
	GorilaDeCeniza = { position = Vector3.new(376, 161, -377), facing = horizontal(-0.707, 0.707) },
}

return BossStages
