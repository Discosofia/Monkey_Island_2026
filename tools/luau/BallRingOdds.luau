-- ¿Con qué probabilidad entra por el aro un golpe al azar? (Fase 27a). No es parte del juego: Rojo no sincroniza esta
-- carpeta. Se pega en execute_luau del Studio de Dunas, en modo edición, con la misma preparación que
-- BallSimTests.luau (renombrar Shared a Shared_old y clonarlo como «Shared», por la caché de require; restaurarlo
-- al acabar). Sirve para comparar geometrías: con el CourtGeometry del repo, con el de un commit anterior (pega su
-- Source en el clon antes de ejecutar) o con otro radio del hueco (OPTIONS.innerRadius).
--
-- Cada golpe: zona, calidad y yugo al azar; yaw al azar de ±70° respecto a +X (no apunta al aro: es una cifra de
-- comparación, no de habilidad); cabeceo ±8° sobre el de la zona; pelota en x ∈ [-30,-3], z ∈ [-15,15],
-- y ∈ [3,8]; 6 s simulados. Devuelve el porcentaje de pases (`ringPass`) y de roces del borde.

local OPTIONS = {
	N = 12000,
	seed = 27,
	innerRadius = nil, -- radio del hueco; nil = el del repo. El exterior se sube con él (grosor de piedra 2)
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared_test") or ReplicatedStorage.Shared
local G = require(Shared.CourtGeometry)
local BallSim = require(Shared.BallSim)
local BallHit = require(Shared.BallHit)
local Data = require(Shared.Data.Ballgame)

local ring = G.ring :: any
local original = { inner = ring.innerRadius, outer = ring.outerRadius }
if OPTIONS.innerRadius then
	local stone = ring.outerRadius - ring.innerRadius
	ring.innerRadius = OPTIONS.innerRadius
	ring.outerRadius = OPTIONS.innerRadius + stone
end

local layout = G.forFormat(5)
local STEP = BallSim.STEP
local yokeBoost = (Data.Yoke and Data.Yoke.SpeedMultiplier) or 1.4
local rng = Random.new(OPTIONS.seed)
local zones = { "Knee", "Hip", "Elbow" }
local qualities = { "Perfect", "Good" }

local passes, rims = 0, 0
for index = 1, OPTIONS.N do
	local zone = zones[rng:NextInteger(1, #zones)]
	local quality = qualities[rng:NextInteger(1, #qualities)]
	local yoke = rng:NextNumber() < 0.5
	local yaw = math.rad(rng:NextNumber(-70, 70))
	local look = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local v = BallHit.velocity(zone, quality, look, 1, if yoke then yokeBoost else nil)
	local speed = v.Magnitude
	local pitch = math.asin(v.Y / speed) + math.rad(rng:NextNumber(-8, 8))
	local flat = Vector3.new(v.X, 0, v.Z).Unit
	v = Vector3.new(flat.X * math.cos(pitch), math.sin(pitch), flat.Z * math.cos(pitch)) * speed
	local pos = Vector3.new(rng:NextNumber(-30, -3), rng:NextNumber(3, 8), rng:NextNumber(-15, 15))
	local s = BallSim.new(pos, v)
	local passed, rimmed = false, false
	for _ = 1, math.ceil(6 / STEP) do
		for _, e in BallSim.step(s, layout, STEP) do
			if e.kind == "ringPass" then
				passed = true
			elseif e.kind == "ringRim" then
				rimmed = true
			end
		end
		if s.dead or s.resting then
			break
		end
	end
	if passed then
		passes += 1
	end
	if rimmed then
		rims += 1
	end
	if index % 400 == 0 then
		task.wait()
	end
end

local result = string.format(
	"aro z=%.1f y=%.1f radio interior %.2f (repo %.2f): N=%d pasa %d = %.3f%%, toca el borde %.2f%%",
	ring.centerZ,
	ring.centerY,
	ring.innerRadius,
	original.inner,
	OPTIONS.N,
	passes,
	100 * passes / OPTIONS.N,
	100 * rims / OPTIONS.N
)
-- Deja el radio como estaba (la tabla es del módulo cacheado).
ring.innerRadius, ring.outerRadius = original.inner, original.outer
return result
