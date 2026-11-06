-- Pruebas de la cancha y de la pelota del Juego de pelota (Fase 27a). No es parte del juego: Rojo no sincroniza
-- esta carpeta. Se pega entera en execute_luau (MCP) del Studio de Dunas, en modo edición, y devuelve un informe
-- de texto con PASA / FALLA por prueba y una tabla informativa de los golpes al final.
--
-- Cómo ejecutarlo:
--   1. Rojo conectado a dunas.project.json (que ReplicatedStorage.Shared tenga el código nuevo).
--   2. Por la caché de require, clona la carpeta y nómbrala Shared_test (el script la prefiere a Shared):
--        local c = game.ReplicatedStorage.Shared:Clone(); c.Name = "Shared_test"; c.Parent = game.ReplicatedStorage
--      OJO: BallSim, BallHit y compañía hacen require(ReplicatedStorage.Shared.X) con la ruta fija, así que ven
--      el Shared ORIGINAL (posiblemente cacheado con el código viejo). La prueba 0 lo avisa. Si falla, renombra
--      antes Shared a Shared_old y el clon a Shared (y borra Shared_test) o reabre el place.
--   3. Pega este archivo y ejecútalo. Borra Shared_test después.
-- Unidades: studs y segundos; coordenadas LOCALES de la cancha (origen en el centro del pasillo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared_test") or ReplicatedStorage.Shared

local G = require(Shared.CourtGeometry)
local BallSim = require(Shared.BallSim)
local BallHit = require(Shared.BallHit)
local Data = require(Shared.Data.Ballgame)

local layout = G.forFormat(5)
local HL = layout.halfLength
local STEP = BallSim.STEP

local lines = {}
local passed, failed = 0, 0

local function say(text)
	table.insert(lines, text)
end

local function check(name, ok, detail)
	if ok then
		passed += 1
		say(`PASA   {name}`)
	else
		failed += 1
		say(`FALLA  {name}{if detail then ` -> {detail}` else ""}`)
	end
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- Avanza "seconds" de a un paso fijo; "onStep(state, events)" se llama tras cada paso y puede devolver true para
-- parar. Devuelve todos los eventos.
local function run(state, seconds, onStep)
	local all = {}
	for _ = 1, math.ceil(seconds / STEP) do
		local events = BallSim.step(state, layout, STEP)
		for _, e in events do
			table.insert(all, e)
		end
		if onStep and onStep(state, events) then
			break
		end
		if state.dead or state.resting then
			break
		end
	end
	return all
end

local function has(events, kind, filter)
	for _, e in events do
		if e.kind == kind and (not filter or filter(e)) then
			return true
		end
	end
	return false
end

-- ============================================================ 0. Coherencia de módulos
do
	local live = require(ReplicatedStorage.Shared.CourtGeometry)
	check(
		"0 BallSim ve la misma CourtGeometry que la probada",
		live.WALL_TOP_Y == G.WALL_TOP_Y and live.ALLEY_HALF_WIDTH == G.ALLEY_HALF_WIDTH,
		`Shared.CourtGeometry: muro {live.WALL_TOP_Y}, pasillo {live.ALLEY_HALF_WIDTH * 2}; probada: {G.WALL_TOP_Y}, {G.ALLEY_HALF_WIDTH * 2}`
	)
end

-- ============================================================ a. Perfil
do
	local talud
	local wall
	for _, seg in layout.profile do
		if seg.kind == "Talud" then
			talud = seg
		elseif seg.kind == "Wall" then
			wall = seg
		end
	end
	local dz, dy = talud.z2 - talud.z1, talud.y2 - talud.y1
	check("a Talud de 30 de tramo y 14 de subida", near(dz, 30) and near(dy, 14), `dz {dz}, dy {dy}`)
	check("a Pasillo de 30", near(layout.halfWidth * 2, 30))
	check("a Muro en z = 48 hasta y = 30", wall.z1 == 48 and wall.y2 == 30, `z {wall.z1}, y {wall.y2}`)
	check("a TALUD_OUTER_Z coherente", near(G.TALUD_OUTER_Z, G.BENCH_OUTER_Z + G.TALUD_RUN) and G.TALUD_OUTER_Z == 48)
	check("a Plaza en z = 88", near(G.PLAZA_HALF_Z, G.TALUD_OUTER_Z + G.CORNICE_DEPTH) and G.PLAZA_HALF_Z == 88)
	check(
		"a Aro a y = 22, z = 43,4, hueco de 3,2 de radio y piedra 0,6 dentro del paramento",
		layout.ring.centerY == 22
			and near(layout.ring.centerZ, 43.4)
			and near(layout.ring.innerRadius, 3.2)
			and near(layout.ring.centerZ + layout.ring.outerRadius - G.TALUD_OUTER_Z, 0.6)
	)
	check(
		"a Cabeceras de ±66 por 30 de fondo, y la «I» se conserva",
		G.HEADER_HALF_WIDTH == 66
			and G.HEADER_DEPTH == 30
			and near(layout.endX, HL + 30)
			and G.HEADER_HALF_WIDTH - G.TALUD_OUTER_Z >= 15,
		`ancho {G.HEADER_HALF_WIDTH}, fondo {G.HEADER_DEPTH}, endX {layout.endX}`
	)
end

-- ============================================================ b. Botes decrecientes
do
	local state = BallSim.new(Vector3.new(-20, 12, 0))
	local apexes = {}
	local lastVy = 0
	run(state, 6, function(s)
		if lastVy > 0 and s.vel.Y <= 0 then
			table.insert(apexes, s.pos.Y)
		end
		lastVy = s.vel.Y
		return false
	end)
	local decreasing = #apexes >= 3
	for i = 2, #apexes do
		decreasing = decreasing and apexes[i] < apexes[i - 1]
	end
	check("b Botes con alturas decrecientes", decreasing, `picos: {table.concat(apexes, ", ")}`)
end

-- ============================================================ c. Rueda por el talud
for _, zSign in { -1, 1 } do
	local state = BallSim.new(Vector3.new(0, 14, zSign * 40))
	local events = run(state, 8)
	local pos = state.pos
	check(
		`c Rueda del talud al pasillo (z {zSign * 40})`,
		math.abs(pos.Z) < G.BENCH_INNER_Z
			and has(events, "bounce", function(e)
				return e.surface == "Talud" or e.surface == "Bench" or e.surface == "Floor"
			end),
		`final {pos}`
	)
end

-- ============================================================ d. Rebote en el paramento
-- (a x = 20: en x = 0 está el aro y la pelota lo tocaría antes de llegar al paramento)
for _, zSign in { -1, 1 } do
	local state = BallSim.new(Vector3.new(20, 28, zSign * 34), Vector3.new(0, 0, zSign * 30))
	local events = run(state, 1)
	local hitWall = has(events, "bounce", function(e)
		return e.surface == "Wall" and near(math.abs(e.pos.Z), 48, 0.01)
	end)
	check(`d Rebota en el paramento a z = 48 (lado {zSign})`, hitWall and state.vel.Z * zSign < 0)
end

-- ============================================================ e. Fuera por encima de la plaza
do
	local state = BallSim.new(Vector3.new(0, 32, 40), Vector3.new(0, 5, 40))
	local events = run(state, 2)
	check("e Sale fuera por encima de la plaza (y > 30)", has(events, "out") and state.dead)
	local low = BallSim.new(Vector3.new(0, 24, 40), Vector3.new(0, 0, 40))
	local lowEvents = run(low, 1)
	check("e Por debajo del muro NO sale", not has(lowEvents, "out"))
end

-- ============================================================ f. Aro
-- Se lanza desde 4 studs por debajo del aro, para que el centro llegue a su cara casi en el punto más alto del
-- arco (con el hueco de 3,2 y la pelota de 2 solo hay 0,6 de margen: una pelota que baja roza el borde).
local RING_START_Y = 18

-- Velocidad vertical con que el centro llega a x = 0 a la altura "target" (vuelo libre: son 10 studs a 30 studs/s).
-- No se usa una bisección: cerca del aro la pelota bota y el resultado deja de ser monótono.
local function solveVy(_zSign, _dir, target)
	local t = 10 / 30
	return (target - RING_START_Y + 0.5 * Data.Gravity * t * t) / t
end

for _, zSign in { -1, 1 } do
	for _, dir in { -1, 1 } do
		local vyPass = solveVy(zSign, dir, 22)
		local s = BallSim.new(Vector3.new(-dir * 10, RING_START_Y, zSign * layout.ring.centerZ), Vector3.new(dir * 30, vyPass, 0))
		local events = run(s, 1)
		check(`f Aro: tiro por el centro cruza (z {zSign}, dir {dir})`, has(events, "ringPass"))
		local vyLow = solveVy(zSign, dir, 22 - 4.4)
		local t = BallSim.new(Vector3.new(-dir * 10, RING_START_Y, zSign * layout.ring.centerZ), Vector3.new(dir * 30, vyLow, 0))
		local lowEvents = run(t, 1)
		check(
			`f Aro: tiro 4,4 studs más bajo no cruza (z {zSign}, dir {dir})`,
			not has(lowEvents, "ringPass"),
			if has(lowEvents, "ringRim") then "roza el aro" else "pasa de largo"
		)
	end
end

-- ============================================================ g. Línea de fondo y muro del fondo
for _, sign in { -1, 1 } do
	local state = BallSim.new(Vector3.new(sign * (HL - 5), 5, 0), Vector3.new(sign * 40, 10, 0))
	local events = run(state, 3)
	check(`g Cruza la línea de fondo y toca el muro del fondo (lado {sign})`, has(events, "crossEndLine", function(e)
		return e.sign == sign
	end) and has(events, "endWall", function(e)
		return e.sign == sign
	end))
end

-- ============================================================ h. Velocidad alta
do
	local bad = nil
	local cases = {
		{ "paramento", Vector3.new(0, 20, 10), Vector3.new(0, 0, 140) },
		{ "talud", Vector3.new(0, 12, 5), Vector3.new(0, -60, 126) },
		{ "muro del fondo", Vector3.new(0, 8, 0), Vector3.new(140, 0, 0) },
		{ "muro de la cabecera", Vector3.new(HL + 10, 8, 0), Vector3.new(0, 0, 140) },
	}
	for _, case in cases do
		local s = BallSim.new(case[2], case[3])
		run(s, 2, function(st)
			if not st.dead and not BallSim.inDomain(st, layout) then
				bad = bad or `{case[1]} en {st.pos}`
				return true
			end
			return false
		end)
	end
	check("h Velocidad 140 sin atravesar nada", bad == nil, bad)
end

-- ============================================================ i. Determinismo
do
	local function once()
		local rng = Random.new(7)
		local s = BallSim.new(
			Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(3, 20), rng:NextNumber(-10, 10)),
			Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(-20, 40), rng:NextNumber(-60, 60))
		)
		run(s, 5)
		return s
	end
	local a, b = once(), once()
	check("i Determinismo", a.pos == b.pos and a.vel == b.vel and a.dead == b.dead and a.resting == b.resting)
end

-- ============================================================ j. Fuzz
do
	local rng = Random.new(1)
	local failures, firstFailure, tested = 0, nil, 0
	while tested < 2000 do
		local pos = Vector3.new(rng:NextNumber(-80, 80), rng:NextNumber(1.5, 28), rng:NextNumber(-60, 60))
		local probe = BallSim.new(pos)
		-- Solo desde puntos libres: bajo el talud, dentro del sólido, inDomain no lo ve (solo mide las superficies).
		local surface = G.surfaceY(math.abs(pos.Z))
		local underground = math.abs(pos.X) <= HL and surface ~= nil and pos.Y < surface + 1.5
		if not underground and BallSim.inDomain(probe, layout) then
			tested += 1
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			if dir.Magnitude < 0.01 then
				dir = Vector3.xAxis
			end
			local s = BallSim.new(pos, dir.Unit * rng:NextNumber(0, 140))
			local start = s.pos
			local events = run(s, 6, function(st)
				if not st.dead and not BallSim.inDomain(st, layout) then
					failures += 1
					firstFailure = firstFailure or `desde {start} hasta {st.pos}`
					return true
				end
				return false
			end)
			if s.dead and not has(events, "out") then
				failures += 1
				firstFailure = firstFailure or `muerta sin evento out desde {start}`
			end
		end
	end
	check(
		"j Fuzz de 2000 pelotas, 6 s, sin salir del recinto",
		failures == 0,
		`{failures} fallos; el primero: {firstFailure}`
	)
end

-- ============================================================ k. taludAt
do
	local function at(x, y, z)
		return G.taludAt(layout, Vector3.new(x, y, z))
	end
	check("k taludAt nil en la banqueta", at(0, 2, 16.5) == nil)
	check("k taludAt nil en el pasillo", at(0, 0, 5) == nil)
	check("k taludAt nil pasada la línea de fondo", at(HL + 5, 8, 24) == nil)
	check("k taludAt nil en el paramento (z = 48)", at(0, 16, 48) == nil)
	local slope = math.atan(14 / 30)
	local info = at(0, 9, 33)
	check(
		"k taludAt en z = 33: superficie 9 y vectores a 25 grados",
		info ~= nil
			and near(info.surfaceY, 9)
			and info.zSign == 1
			and near(info.downhill.Magnitude, 1)
			and near(info.normal.Magnitude, 1)
			and near(info.downhill.Y, -math.sin(slope), 1e-4)
			and near(info.downhill.Z, -math.cos(slope), 1e-4)
			and near(info.normal.Y, math.cos(slope), 1e-4)
			and near(info.normal.Z, -math.sin(slope), 1e-4)
			and near(info.downhill:Dot(info.normal), 0, 1e-6)
	)
	check("k taludAt en el aire a +6 de la superficie", at(0, 15, 33) ~= nil)
	check("k taludAt en el aire de un salto alto (+25)", at(0, 34, 33) ~= nil)
	check("k taludAt nil a +46 de la superficie", at(0, 55, 33) == nil)
	check("k taludAt nil muy por debajo de la superficie", at(0, 4, 33) == nil)
	local mirror = at(0, 9, -33)
	check(
		"k taludAt simétrico en -z",
		mirror ~= nil
			and info ~= nil
			and mirror.zSign == -1
			and near(mirror.surfaceY, 9)
			and near(mirror.downhill.Z, math.cos(slope), 1e-4)
			and near(mirror.downhill.Y, info.downhill.Y, 1e-6)
			and near(mirror.normal.Z, math.sin(slope), 1e-4)
	)
end

-- ============================================================ Resumen y tabla informativa (l)
say("")
say(`Resultado: {passed} pasan, {failed} fallan`)
say("")
say("l (informativa) Pico de altura de cada golpe lanzado hacia +X; aro: centro y = 22, borde inferior 20,4")
say(`   gravedad = {Data.Gravity}`)
say("   zona    calidad  yugo   desde y=4          desde y=8")
local yokeBoost = if Data.Yoke then Data.Yoke.SpeedMultiplier else 1.4
for _, zone in { "Knee", "Hip", "Elbow" } do
	for _, quality in { "Perfect", "Good" } do
		for _, boost in { 1, yokeBoost } do
			local cells = {}
			for _, h in { 4, 8 } do
				local v = BallHit.velocity(zone, quality, Vector3.xAxis, 1, boost)
				local s = BallSim.new(Vector3.new(-30, h, 0), v)
				local apex = h
				local rising = false
				run(s, 4, function(st)
					apex = math.max(apex, st.pos.Y)
					if st.vel.Y > 0 then
						rising = true
					end
					return rising and st.vel.Y <= 0
				end)
				table.insert(cells, string.format("%5.1f %s", apex, if apex >= 20.4 then "LLEGA" else "no   "))
			end
			say(string.format("   %-7s %-8s x%.1f  %s     %s", zone, quality, boost, cells[1], cells[2]))
		end
	end
end

-- ============================================================ m. ¿Se puede embocar el aro? (informativa)
-- Pelotas golpeadas al azar desde el pasillo hacia +X, 6 s simulados cada una: cuántas cruzan un aro.
do
	local N = 4000
	local rng = Random.new(27)
	local zones = { "Knee", "Hip", "Elbow" }
	local qualities = { "Perfect", "Good" }
	local function bucket()
		return { n = 0, pass = 0, rim = 0, wall = 0 }
	end
	local total = bucket()
	local byZone = { Knee = bucket(), Hip = bucket(), Elbow = bucket() }
	local byYoke = { [false] = bucket(), [true] = bucket() }
	for _ = 1, N do
		local zone = zones[rng:NextInteger(1, #zones)]
		local quality = qualities[rng:NextInteger(1, #qualities)]
		local yoke = rng:NextNumber() < 0.5
		local yaw = math.rad(rng:NextNumber(-70, 70))
		local look = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		-- El yugo se aplica como hace BallHit (multiplicador con tope de MaxSpeed).
		local v = BallHit.velocity(zone, quality, look, 1, if yoke then yokeBoost else nil)
		-- Cabeceo al azar de ±8° sobre el de la zona.
		local speed = v.Magnitude
		local pitch = math.asin(v.Y / speed) + math.rad(rng:NextNumber(-8, 8))
		local flat = Vector3.new(v.X, 0, v.Z).Unit
		v = Vector3.new(flat.X * math.cos(pitch), math.sin(pitch), flat.Z * math.cos(pitch)) * speed
		local pos = Vector3.new(rng:NextNumber(-30, -3), rng:NextNumber(3, 8), rng:NextNumber(-15, 15))
		local s = BallSim.new(pos, v)
		local touchedWall = false
		local didPass, rim, wallThenPass = false, false, false
		run(s, 6, function(_, events)
			for _, e in events do
				if e.kind == "bounce" and e.surface == "Wall" then
					touchedWall = true
				elseif e.kind == "ringRim" then
					rim = true
				elseif e.kind == "ringPass" and not didPass then
					didPass = true
					wallThenPass = touchedWall
				end
			end
			return false
		end)
		for _, b in { total, byZone[zone], byYoke[yoke] } do
			b.n += 1
			if didPass then
				b.pass += 1
			end
			if rim then
				b.rim += 1
			end
			if wallThenPass then
				b.wall += 1
			end
		end
	end
	say("")
	say(`m (informativa) {N} golpes al azar desde el pasillo: pase por aro en 6 s (aro a z = {layout.ring.centerZ})`)
	local function row(name, b)
		say(
			string.format(
				"   %-10s n=%-5d pasa %5.2f%%  (tras tocar el paramento %d)  toca el borde %5.2f%%",
				name,
				b.n,
				100 * b.pass / math.max(b.n, 1),
				b.wall,
				100 * b.rim / math.max(b.n, 1)
			)
		)
	end
	row("total", total)
	for _, zone in zones do
		row(zone, byZone[zone])
	end
	row("sin yugo", byYoke[false])
	row("con yugo", byYoke[true])
end

return table.concat(lines, "\n")
