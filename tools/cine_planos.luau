--!nocheck
--!nolint
-- Calculadora de planos de las batallas contra jefes (método z4 del Handoff del 18-11-2026). NO es código del juego: no
-- está en src ni lo sincroniza Rojo. Se pega como `code` en execute_luau (datamodel_type "Client") en Play, DESPUÉS de
-- grabar la escena con tools/cine_qa.luau (OPTS.track = true) y copiar su JSON al atributo `CineQA_<bossId>` del jugador.
-- El mapa sigue cargado, así que los rayos (suelo, tapones, tronco en primer término) son reales.
--
-- Qué hace:
--   1. Saca el marco del jefe en el mundo (giro Y + traslación) y el desfase de reloj del arnés comparando la cámara
--      grabada con la de la escena (Data/Cinematics.Battle_Boss_<jefe>.camera, en el marco del jefe).
--   2. Para cada plano de OPTS.shots prueba en rejilla cámaras (x, z en el marco del jefe; altura sobre el suelo real),
--      miradas (el sujeto, con desplazamientos) y FOV, con las posiciones grabadas de actores y jefe dentro del plano.
--   3. Devuelve los mejores candidatos listos para BossChoreo: cam = { x - centre.x, altura, z - centre.z },
--      look = { "abs", x, altura sobre el suelo, z } y fov, con sus medidas.
--
-- Metas (las del Caudillo, regla «encuadre de jefes»): borde de arriba del jefe ≥ OPTS.bossTop del cuadro, cabeceo ≤
-- OPTS.maxPitch, cámara ≥ 12 st de actores y jefe y ≥ 4,5 st sobre el suelo, sujeto entero, los demás enteros o fuera,
-- sin tapones en la línea de visión y sin tronco en primer término (z2).

local OPTS = {
	boss = "GorilaAlbino",
	centre = { 0, -18 }, -- BOSS_BATTLES[boss].centre (Data/Cinematics)
	bossTop = 0.24, -- 0,21 de la regla + margen (el arnés mide pieza a pieza)
	maxPitch = 4,
	minPitch = -20, -- grados: más picado que esto es casi cenital (en la ladera de Ceniza salían -25 a -51)
	camNear = 15, -- 12 de la regla + margen: aquí se mide al pivote, y el arnés a la caja (brazos, antorcha) con el empuje del 4 %
	camHeight = 4.5,
	fovs = { 46, 52, 58, 64 },
	heights = { 5, 7, 9, 12, 15, 19 },
	gridStep = 4,
	gridX = { -44, 44 },
	gridZ = { -56, 36 },
	top = 4, -- candidatos que se devuelven por plano
	-- Planos: t0, t1 (segundos de la escena), sujeto ("boss", nombre del maniquí: guerrero/cazador/mago/medico, o una lista
	-- {"cazador","mago"}), tamaño buscado del sujeto (fracción del alto del cuadro) y, opcional, `side` (+1 / -1: la cámara
	-- a la derecha o a la izquierda del eje jefe→tripulación), `xRange` ({ mín, máx } de la x de la cámara en el marco
	-- del jefe), `zRange` (igual con la z: el jefe mira a -Z, así que su cara pide z negativa) o `avoid` (lista de
	-- { x, z, r } del marco del jefe donde no puede ir la cámara).
	shots = {},
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local viewport = workspace.CurrentCamera.ViewportSize
local aspect = viewport.X / viewport.Y

local raw = player:GetAttribute("CineQA_" .. OPTS.boss)
if not raw then
	return "STOP: falta el atributo CineQA_" .. OPTS.boss .. " (graba antes con cine_qa, track = true)"
end
local data = HttpService:JSONDecode(raw)
local track = {}
local dropped = 0
for _, e in data.track or {} do
	-- las primeras entradas pueden no tener jefe ni actores (aún montándose)
	if e.boss and e.actors and e.cam then
		table.insert(track, e)
	else
		dropped += 1
	end
end
if #track < 20 then
	return "STOP: el track tiene " .. tostring(track and #track) .. " entradas"
end

local CameraPath = require(RS.Shared.Cinematics.CameraPath)
local scene = require(RS.Shared.Data.Cinematics)["Battle_Boss_" .. OPTS.boss]
local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

-- 1. Desfase de reloj: los cortes (saltos de cámara > 6 st) del track contra los de la escena.
local sceneCuts = {}
for i = 2, #scene.camera do
	local a, b = scene.camera[i - 1], scene.camera[i]
	if (a.pos - b.pos).Magnitude > 6 and b.t - a.t < 0.01 then
		table.insert(sceneCuts, b.t)
	end
end
-- 2. Marco del jefe en el mundo (giro Y + traslación, mínimos cuadrados) para un desfase dado, con pares (cámara de la
-- escena, cámara grabada) lejos de los cortes; el error es el máximo de los pares.
local function fit(offset)
	local pairs_ = {}
	for _, e in track do
		local st = e.t - offset
		local near = false
		for _, c in sceneCuts do
			if math.abs(st - c) < 0.25 then
				near = true
			end
		end
		if not near and st > 0.3 and st < scene.duration - 0.3 then
			table.insert(pairs_, { l = CameraPath.sampleTimed(scene.camera, st), w = v3(e.cam) })
		end
	end
	if #pairs_ < 5 then
		return nil
	end
	local sumS, sumC = 0, 0
	local lc, wc = Vector3.zero, Vector3.zero
	for _, p in pairs_ do
		lc += p.l
		wc += p.w
	end
	lc /= #pairs_
	wc /= #pairs_
	for _, p in pairs_ do
		local a, b = p.l - lc, p.w - wc
		sumS += a.Z * b.X - a.X * b.Z
		sumC += a.X * b.X + a.Z * b.Z
	end
	local yaw = math.atan2(sumS, sumC)
	local rot = CFrame.Angles(0, yaw, 0)
	local frame = CFrame.new(wc - rot:PointToWorldSpace(lc)) * rot
	local err = 0
	for _, p in pairs_ do
		err = math.max(err, (frame:PointToWorldSpace(p.l) - p.w).Magnitude)
	end
	return { frame = frame, err = err, yaw = yaw, n = #pairs_, offset = offset }
end
-- 1. Desfase de reloj del arnés: el que mejor ajusta el marco (de -1 a +0,4 s, en pasos de 0,05).
local best
for step = -20, 8 do
	local r = fit(step * 0.05)
	if r and (not best or r.err < best.err) then
		best = r
	end
end
local offset, frame, fitErr, yaw = best.offset, best.frame, best.err, best.yaw

-- Suelo real (solo Terrain) bajo un punto del marco del jefe, en el mundo.
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local groundCache = {}
local function groundW(x, z)
	local key = math.floor(x * 2) .. ":" .. math.floor(z * 2)
	if groundCache[key] ~= nil then
		return groundCache[key]
	end
	local w = frame:PointToWorldSpace(Vector3.new(x, 0, z))
	-- desde 25 st sobre el pie del jefe, no desde muy arriba: en la cueva del Albino el rayo pararía en el techo
	local hit = workspace:Raycast(Vector3.new(w.X, w.Y + 25, w.Z), Vector3.new(0, -100, 0), terrainOnly)
	local y = if hit then hit.Position.Y else w.Y
	groundCache[key] = y
	return y
end

-- Muestras del plano: actores (pivote) y jefe (centro y borde de arriba), cada 0,2 s.
local function samplesIn(t0, t1)
	local list, nextT = {}, -1
	for _, e in track do
		local st = e.t - offset
		if st >= t0 + 0.05 and st <= t1 - 0.05 and st >= nextT then
			nextT = st + 0.2
			table.insert(list, e)
		end
	end
	return list
end

local function project(camCF, fov, p)
	local rel = camCF:PointToObjectSpace(p)
	if rel.Z >= -0.1 then
		return nil
	end
	local tanY = math.tan(math.rad(fov) / 2)
	local x = (rel.X / -rel.Z) / (tanY * aspect)
	local y = (rel.Y / -rel.Z) / tanY
	return 0.5 + x / 2, 0.5 - y / 2
end

-- Caja de un maniquí: pies (pivote - 3) y cabeza (pivote + 2,6); de un jefe: del borde de abajo al de arriba.
local function spanOf(camCF, fov, lowP, highP, halfW)
	local x0, y0 = project(camCF, fov, highP)
	local x1, y1 = project(camCF, fov, lowP)
	if not x0 or not x1 then
		return nil
	end
	local right = camCF.RightVector * halfW
	local xa = project(camCF, fov, highP + right)
	local w = if xa then math.abs(xa - x0) else 0
	return { x0 = math.min(x0, x1) - w, x1 = math.max(x0, x1) + w, y0 = math.min(y0, y1), y1 = math.max(y0, y1) }
end

local function inside(b)
	return b.x0 >= 0.03 and b.x1 <= 0.97 and b.y0 >= 0.12 and b.y1 <= 0.88
end
local function outside(b)
	return b == nil or b.x1 < 0 or b.x0 > 1 or b.y1 < 0.12 or b.y0 > 0.88
end

local excluded = {}
for _, m in workspace:GetDescendants() do
	if m:IsA("Model") and (m.Name:sub(1, 10) == "Cinematic_" or m:GetAttribute("Boss") ~= nil) then
		table.insert(excluded, m)
	end
end
table.insert(excluded, player.Character)
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.FilterDescendantsInstances = excluded

local function isSubject(subject, name)
	if type(subject) == "table" then
		return table.find(subject, name) ~= nil
	end
	return subject == name
end

local function evaluate(shot, samples, camW, lookW, fov)
	local camCF = CFrame.lookAt(camW, lookW)
	local pitch = math.deg(math.asin(camCF.LookVector.Y))
	if pitch > OPTS.maxPitch or pitch < (shot.minPitch or OPTS.minPitch) then
		return nil
	end
	local score, worstTop, minDist, cutOthers, sizeErr, n = 0, 1, math.huge, 0, 0, 0
	for _, e in samples do
		n += 1
		local bc, btop = Vector3.new(e.boss[1], e.boss[2], e.boss[3]), e.boss[4]
		local half = btop - e.boss[2]
		-- El borde de arriba real (hombros, penacho) está más cerca de la cámara que el centro de la caja: se adelanta 0,4
		-- del semialto hacia ella (con el centro, la calculadora daba 0,23 donde el arnés medía 0,04).
		local toCam = Vector3.new(camW.X - bc.X, 0, camW.Z - bc.Z)
		toCam = if toCam.Magnitude > 0.01 then toCam.Unit else Vector3.zero
		local bossLow = Vector3.new(bc.X, bc.Y - half, bc.Z)
		local bossHigh = Vector3.new(bc.X, btop, bc.Z) + toCam * half * 0.4
		local dBoss = math.max((camW - bc).Magnitude - half * 0.8, 0)
		minDist = math.min(minDist, dBoss)
		local bb = spanOf(camCF, fov, bossLow, bossHigh, half * 0.8)
		local bossSubject = isSubject(shot.subject, "boss")
		if bossSubject then
			if not bb or not inside(bb) then
				return nil
			end
			worstTop = math.min(worstTop, bb.y0)
			sizeErr += math.abs((bb.y1 - bb.y0) - (shot.size or 0.5))
		elseif not outside(bb) then
			if not inside(bb) then
				cutOthers += 1
			end
			worstTop = math.min(worstTop, bb.y0)
		end
		for name, p in e.actors do
			local short = name:gsub("^Cinematic_", ""):lower()
			local pv = v3(p)
			minDist = math.min(minDist, (camW - pv).Magnitude)
			local ab = spanOf(camCF, fov, pv - Vector3.new(0, 3, 0), pv + Vector3.new(0, 2.6, 0), 0.9)
			local subj = false
			for _, key in (type(shot.subject) == "table" and shot.subject or { shot.subject }) do
				if short:find(key) then
					subj = true
				end
			end
			if subj then
				if not ab or not inside(ab) then
					return nil
				end
				sizeErr += math.abs((ab.y1 - ab.y0) - (shot.size or 0.4))
			elseif not outside(ab) and not inside(ab) then
				cutOthers += 1
			end
		end
	end
	if minDist < OPTS.camNear or worstTop < OPTS.bossTop then
		return nil
	end
	score = sizeErr / math.max(n, 1) + cutOthers * 0.15 / math.max(n, 1) + math.max(pitch, -12) * -0.002
	return { score = score, pitch = pitch, top = worstTop, minDist = minDist, cut = cutOthers }
end

-- Tapones y tronco en primer término (rayos reales), solo para los finalistas.
local function blocked(camW, lookW, fov, samples)
	local camCF = CFrame.lookAt(camW, lookW)
	local hit = workspace:Raycast(camW, Vector3.new(0, -60, 0), terrainOnly)
	local height = if hit then camW.Y - hit.Position.Y else 99
	if height < OPTS.camHeight then
		return "camalta " .. string.format("%.1f", height)
	end
	-- dentro del terreno (paredes de la cueva, la cresta) o de una pieza
	local region = Region3.new(camW - Vector3.new(2, 2, 2), camW + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local _, occ = workspace.Terrain:ReadVoxels(region, 4)
	if occ[1] and occ[1][1] and occ[1][1][1] and occ[1][1][1] > 0.05 then
		return "dentro del terreno"
	end
	local inPart = workspace:GetPartBoundsInRadius(camW, 1.5)
	for _, part in inPart do
		local char = player.Character
		if part.CanCollide and part.Transparency < 1 and not (char and part:IsDescendantOf(char)) then
			return "dentro de " .. part.Name
		end
	end
	local e = samples[math.ceil(#samples / 2)]
	local targets = { Vector3.new(e.boss[1], e.boss[4] - 1, e.boss[3]), Vector3.new(e.boss[1], e.boss[2], e.boss[3]) }
	for _, p in e.actors do
		table.insert(targets, v3(p))
	end
	for _, target in targets do
		local r = workspace:Raycast(camW, target - camW, losParams)
		if r and (r.Position - target).Magnitude > 2 then
			return "tapa " .. r.Instance.Name
		end
	end
	-- primer término: abanico de rayos dentro del cuadro, a menos de 18 st y por debajo de 0,15 del cuadro
	local tanY = math.tan(math.rad(fov) / 2)
	local covered = 0
	for gx = 0.1, 0.9, 0.1 do
		for gy = 0.3, 0.85, 0.11 do
			local dir = (camCF.LookVector + camCF.RightVector * ((gx - 0.5) * 2 * tanY * aspect) + camCF.UpVector * ((0.5 - gy) * 2 * tanY)).Unit
			local r = workspace:Raycast(camW, dir * 18, losParams)
			if r and not r.Instance:IsA("Terrain") then
				covered += 1
			end
		end
	end
	if covered >= 4 then
		return "primer término (" .. covered .. " rayos)"
	end
	return nil
end

local out = {
	string.format(
		"%s · desfase %.2f s · ajuste del marco: error máx %.2f st en %d pares · yaw %.1f° · %d entradas sin jefe descartadas",
		OPTS.boss,
		offset,
		fitErr,
		best.n,
		math.deg(yaw),
		dropped
	),
}
local cx, cz = OPTS.centre[1], OPTS.centre[2]
for index, shot in OPTS.shots do
	local samples = samplesIn(shot.t0, shot.t1)
	-- punto del sujeto en el marco del jefe (media del plano)
	local sum, count = Vector3.zero, 0
	for _, e in samples do
		if isSubject(shot.subject, "boss") then
			sum += Vector3.new(e.boss[1], (e.boss[2] + e.boss[4]) / 2, e.boss[3])
			count += 1
		end
		for name, p in e.actors do
			local short = name:gsub("^Cinematic_", ""):lower()
			for _, key in (type(shot.subject) == "table" and shot.subject or { shot.subject }) do
				if key ~= "boss" and short:find(key) then
					sum += v3(p)
					count += 1
				end
			end
		end
	end
	local subjW = if count > 0 then sum / count else frame.Position
	local subjL = frame:PointToObjectSpace(subjW)
	local cands = {}
	for x = OPTS.gridX[1], OPTS.gridX[2], OPTS.gridStep do
		task.wait() -- una columna por cuadro: Studio no se congela
		for z = OPTS.gridZ[1], OPTS.gridZ[2], OPTS.gridStep do
			local okSide = true
			if shot.side then
				-- lado respecto al eje jefe (0,0) → centro de la tripulación
				local cross = (cx * z - cz * x)
				okSide = (cross > 0) == (shot.side > 0)
			end
			if shot.xRange and (x < shot.xRange[1] or x > shot.xRange[2]) then
				okSide = false
			end
			if shot.zRange and (z < shot.zRange[1] or z > shot.zRange[2]) then
				okSide = false
			end
			for _, a in shot.avoid or {} do
				if (Vector2.new(x, z) - Vector2.new(a[1], a[2])).Magnitude < a[3] then
					okSide = false
				end
			end
			if okSide then
				local gy = groundW(x, z)
				for _, h in OPTS.heights do
					local camW = frame:PointToWorldSpace(Vector3.new(x, 0, z))
					camW = Vector3.new(camW.X, gy + h, camW.Z)
					for _, dy in { -1.5, 0, 1.5 } do
						local lookW = subjW + Vector3.new(0, dy, 0)
						for _, fov in OPTS.fovs do
							local r = evaluate(shot, samples, camW, lookW, fov)
							if r then
								r.x, r.z, r.h, r.fov, r.camW, r.lookW = x, z, h, fov, camW, lookW
								table.insert(cands, r)
							end
						end
					end
				end
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.score < b.score
	end)
	local lines, kept = {}, 0
	for _, c in cands do
		if kept >= OPTS.top then
			break
		end
		local why = blocked(c.camW, c.lookW, c.fov, samples)
		if not why then
			kept += 1
			local lookL = frame:PointToObjectSpace(c.lookW)
			local lookH = c.lookW.Y - groundW(lookL.X, lookL.Z)
			table.insert(
				lines,
				string.format(
					"  shot(%.1f, %.1f, { %g, %g, %g }, { \"abs\", %.1f, %.1f, %.1f }, %d) · top %.2f · cabeceo %.1f° · dist %.1f · cortados %d · nota %.3f",
					shot.t0,
					shot.t1,
					c.x - cx,
					c.h,
					c.z - cz,
					lookL.X,
					lookH,
					lookL.Z,
					c.fov,
					c.top,
					c.pitch,
					c.minDist,
					c.cut,
					c.score
				)
			)
		end
	end
	table.insert(
		out,
		string.format(
			"%d. %.1f–%.1f sujeto %s (%d muestras, %d candidatos; sujeto en %.1f, %.1f, %.1f)",
			index,
			shot.t0,
			shot.t1,
			type(shot.subject) == "table" and table.concat(shot.subject, "+") or shot.subject,
			#samples,
			#cands,
			subjL.X,
			subjL.Y,
			subjL.Z
		)
	)
	if #lines == 0 then
		table.insert(out, "  sin candidatos que cumplan: afloja tamaño, lado o rejilla")
	end
	for _, l in lines do
		table.insert(out, l)
	end
end
return table.concat(out, "\n")
