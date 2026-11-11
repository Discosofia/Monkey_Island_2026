--!nocheck
--!nolint
-- Arnés de revisión de cinemáticas (skill cinematicas-roblox). NO es código del juego: no está en src ni lo sincroniza
-- Rojo. La sesión principal lo lee y lo pega como `code` en execute_luau con datamodel_type "Client", en Play,
-- cambiando solo la tabla OPTS. Dos modos:
--
--   MODE = "start"  lanza la cinemática y muestrea cada INTERVAL s en un hilo; devuelve enseguida.
--   MODE = "read"   devuelve el informe cuando el hilo ha terminado (o el estado si aún corre).
--
-- Cada muestreo mide, para cada maniquí `Cinematic_*` del Workspace y para el ScreenGui «Cinematic»:
--   suelo        pies contra el suelo: hundido (-) o flotando (+) más de FLOOR_TOL studs
--   terreno      el cuerpo (cadera a pies) atravesado por el Terrain (hundido en una pendiente)
--   deslizando   el HumanoidRootPart avanza más de SLIDE_SPEED st/s sin pista de andar o correr con peso > 0
--   atraviesa    piezas con colisión (pilares, props) dentro del torso
--   fuera        el maniquí no está en pantalla (el revisor decide si era el sujeto del plano)
--   gui          textos o imágenes que se pisan entre sí, que tapan al maniquí o que tapan el botón «Saltar»
--   luz          aproximaciones de negro y quemado (ver abajo)
--
-- LÍMITES, dichos claros: (1) desde el motor no se leen los píxeles, así que «negro» es el velo `Fade` casi opaco y
-- «quemado» es Lighting/ColorCorrection/Bloom extremos; la luminancia real se juzga en las capturas. (2) El
-- deslizamiento, el suelo y «fuera» dan falsos positivos en saltos, barcos y monturas: son pistas con hora, las
-- confirma una captura. (3) No sabe cuál es el sujeto de cada plano.
--
-- El resultado queda en el atributo de texto `CineQA` del jugador local (JSON), así sobrevive entre llamadas.

local OPTS = {
	MODE = "start",
	-- Orden de DebugCommands que lanza la escena (CineTest, CineBallgame…). Con `id` en su lugar se usa el remoto
	-- CinematicPlayLocal solo si existe; lo normal es `command`.
	command = "CineTest",
	args = nil,
	-- Comprobación de que Rojo ya sincronizó: devuelve true o false, "motivo". Ejemplo:
	--   expect = function() return require(game.ReplicatedStorage.Shared.Data.Cinematics).Night.duration == 40 end
	expect = nil,
	interval = 0.5,
	maxSeconds = 90,
}

local FLOOR_TOL = 0.3
local SLIDE_SPEED = 1.0
local OFFSCREEN_MARGIN = 0
local SKIP_RECT = { w = 160, h = 48, margin = 24 }

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function save(state)
	player:SetAttribute("CineQA", HttpService:JSONEncode(state))
end

if OPTS.MODE == "read" then
	local raw = player:GetAttribute("CineQA")
	return raw or "sin datos: lanza antes MODE = 'start'"
end

-- 1. Rojo al día
if OPTS.expect then
	local ok, result, why = pcall(OPTS.expect)
	if not ok or not result then
		return "STOP: el código de Studio no es el último (" .. tostring(ok and why or result) .. "). Espera a Rojo."
	end
end
local remote = game:GetService("ReplicatedStorage"):FindFirstChild("DebugCommand", true)
if not remote then
	return "STOP: no hay remoto DebugCommand (¿Play de la Isla?)"
end

local state = { status = "running", scene = OPTS.command, samples = 0, flags = {}, marks = {} }
save(state)

local function flag(kind, subject, detail, t)
	local key = kind .. "|" .. subject
	local entry = state.flags[key]
	if entry then
		entry.t1 = t
		entry.n += 1
	else
		state.flags[key] = { kind = kind, subject = subject, detail = detail, t0 = t, t1 = t, n = 1 }
	end
end

local function actorsNow()
	local list = {}
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("Model") and inst.Name:sub(1, 10) == "Cinematic_" and inst:FindFirstChildOfClass("Humanoid") then
			table.insert(list, inst)
		end
	end
	return list
end

local function rectOf(gui)
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return { x0 = p.X, y0 = p.Y, x1 = p.X + s.X, y1 = p.Y + s.Y }
end

local function overlap(a, b)
	local w = math.min(a.x1, b.x1) - math.max(a.x0, b.x0)
	local h = math.min(a.y1, b.y1) - math.max(a.y0, b.y0)
	if w <= 0 or h <= 0 then
		return 0
	end
	local small = math.min((a.x1 - a.x0) * (a.y1 - a.y0), (b.x1 - b.x0) * (b.y1 - b.y0))
	return (w * h) / math.max(small, 1)
end

local function visibleChain(gui, root)
	local node = gui
	while node and node ~= root do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local previous = {}

local function sample(t)
	local actors = actorsNow()
	local excluded = { camera }
	for _, a in actors do
		table.insert(excluded, a)
	end
	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = excluded
	local terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excluded

	local avatarBoxes = {}
	for _, actor in actors do
		local who = actor.Name
		local root = actor:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = actor:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			-- suelo
			local airborne = humanoid:GetState() == Enum.HumanoidStateType.Jumping
				or humanoid:GetState() == Enum.HumanoidStateType.Freefall
			local feet = {}
			for _, n in { "LeftFoot", "RightFoot" } do
				local f = actor:FindFirstChild(n)
				if f and f:IsA("BasePart") then
					table.insert(feet, f)
				end
			end
			if #feet == 0 then
				table.insert(feet, root)
			end
			for _, foot in feet do
				local bottom = foot.Position.Y
					- (if foot == root then root.Size.Y / 2 + humanoid.HipHeight else foot.Size.Y / 2)
				local hit = workspace:Raycast(foot.Position + Vector3.new(0, 3, 0), Vector3.new(0, -9, 0), floorParams)
				if hit and not airborne then
					local delta = bottom - hit.Position.Y
					if math.abs(delta) > FLOOR_TOL then
						flag(
							"suelo",
							who,
							string.format(
								"%s %.2f st sobre %s",
								if delta < 0 then "hundido" else "flotando",
								delta,
								hit.Instance:GetFullName()
							),
							t
						)
					end
				end
				-- terreno: de la cadera al pie no puede haber Terrain
				local toFoot = foot.Position - root.Position
				if toFoot.Magnitude > 0.1 then
					local body = workspace:Raycast(root.Position, toFoot, terrainParams)
					if body then
						flag("terreno", who, "el cuerpo atraviesa el terreno cerca de " .. tostring(body.Position), t)
					end
				end
			end
			-- deslizamiento
			local last = previous[actor]
			if last then
				local flat = Vector3.new(root.Position.X - last.pos.X, 0, root.Position.Z - last.pos.Z).Magnitude
				local speed = flat / math.max(t - last.t, 0.01)
				if speed > SLIDE_SPEED then
					local animator = humanoid:FindFirstChildOfClass("Animator")
					local walking = false
					if animator then
						for _, track in animator:GetPlayingAnimationTracks() do
							local name =
								string.lower(track.Name .. " " .. (track.Animation and track.Animation.Name or ""))
							if
								track.WeightCurrent > 0
								and (
									name:find("walk")
									or name:find("run")
									or name:find("locom")
									or name:find("carrera")
									or name:find("andar")
								)
							then
								walking = true
							end
						end
					end
					if not walking and root.Anchored == false and humanoid.MoveDirection.Magnitude < 0.05 then
						flag("deslizando", who, string.format("%.1f st/s sin pista de andar", speed), t)
					elseif not walking and root.Anchored then
						flag("deslizando", who, string.format("%.1f st/s anclado sin pista de andar", speed), t)
					end
				end
			end
			previous[actor] = { pos = root.Position, t = t }
			-- piezas atravesadas
			local torso = actor:FindFirstChild("UpperTorso") or actor:FindFirstChild("Torso") or root
			for _, part in workspace:GetPartBoundsInRadius(torso.Position, 1.6, overlapParams) do
				if not part:IsA("Terrain") and part.CanCollide and part.Transparency < 1 then
					flag("atraviesa", who, part:GetFullName(), t)
				end
			end
			-- pantalla
			local head = actor:FindFirstChild("Head") :: BasePart?
			local top = (head or root).Position + Vector3.new(0, 1, 0)
			local pTop, onTop = camera:WorldToViewportPoint(top)
			local pLow, onLow = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
			if not (onTop or onLow) then
				flag("fuera", who, "ni la cabeza ni los pies están en pantalla", t)
			elseif pTop.Z > 0 then
				local halfW = math.abs(pLow.Y - pTop.Y) * 0.25
				table.insert(avatarBoxes, {
					who = who,
					x0 = pTop.X - halfW,
					x1 = pTop.X + halfW,
					y0 = math.min(pTop.Y, pLow.Y),
					y1 = math.max(pTop.Y, pLow.Y),
				})
			end
		end
	end

	-- interfaz
	local gui = player.PlayerGui:FindFirstChild("Cinematic")
	if gui then
		local items = {}
		for _, d in gui:GetDescendants() do
			if
				(d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("ImageLabel"))
				and d.AbsoluteSize.X > 4
				and d.AbsoluteSize.Y > 4
				and visibleChain(d, gui)
			then
				local see = if d:IsA("ImageLabel")
					then d.ImageTransparency < 0.9
					else (d.TextTransparency < 0.9 and d.Text ~= "")
				if see then
					table.insert(items, { gui = d, rect = rectOf(d) })
				end
			end
		end
		local skip = gui:FindFirstChild("Skip")
		for i, a in items do
			if a.gui ~= skip and not (skip and a.gui:IsDescendantOf(skip)) then
				if skip and skip.Visible and overlap(a.rect, rectOf(skip)) > 0.05 then
					flag("gui", a.gui.Name, "tapa el botón Saltar", t)
				end
				for _, box in avatarBoxes do
					if overlap(a.rect, box) > 0.15 then
						flag("gui", a.gui.Name, "tapa al maniquí " .. box.who, t)
					end
				end
				for j = i + 1, #items do
					local b = items[j]
					if
						b.gui ~= skip
						and not a.gui:IsDescendantOf(b.gui)
						and not b.gui:IsDescendantOf(a.gui)
						and overlap(a.rect, b.rect) > 0.25
					then
						flag("gui", a.gui.Name .. "+" .. b.gui.Name, "se pisan dos elementos", t)
					end
				end
			end
		end
		local fade = gui:FindFirstChild("Fade")
		if fade and fade:IsA("GuiObject") and fade.Visible and fade.BackgroundTransparency < 0.05 then
			flag("luz", "Fade", "velo casi opaco (negro): confirma con captura si es un fundido a propósito", t)
		end
	end
	-- quemado (aproximación)
	local burned = Lighting.ExposureCompensation > 1.5 or Lighting.Brightness > 6
	for _, e in Lighting:GetChildren() do
		if e:IsA("ColorCorrectionEffect") and e.Enabled and e.Brightness > 0.3 then
			burned = true
		elseif e:IsA("BloomEffect") and e.Enabled and e.Intensity > 2 then
			burned = true
		end
	end
	if burned then
		flag("luz", "Lighting", "exposición, brillo o bloom muy altos: posible quemado", t)
	end
end

task.spawn(function()
	remote:FireServer(OPTS.command, OPTS.args)
	local began = os.clock()
	-- espera a que arranque (maniquíes o ScreenGui) hasta 8 s
	while os.clock() - began < 8 and not (player.PlayerGui:FindFirstChild("Cinematic") or #actorsNow() > 0) do
		task.wait(0.1)
	end
	local t0 = os.clock()
	local quiet = 0
	while os.clock() - t0 < OPTS.maxSeconds do
		local t = os.clock() - t0
		local ok, err = pcall(sample, t)
		if not ok then
			state.error = tostring(err)
		end
		state.samples += 1
		local cam = camera.CFrame.Position
		table.insert(state.marks, { math.floor(t * 10) / 10, math.floor(cam.X), math.floor(cam.Y), math.floor(cam.Z) })
		if not player.PlayerGui:FindFirstChild("Cinematic") and #actorsNow() == 0 then
			quiet += OPTS.interval
			if quiet >= 1.5 then
				break
			end
		else
			quiet = 0
		end
		if state.samples % 4 == 0 then
			save(state)
		end
		task.wait(OPTS.interval)
	end
	state.status = "done"
	state.seconds = math.floor((os.clock() - t0) * 10) / 10
	save(state)
end)

return "lanzado: " .. OPTS.command .. " (lee con MODE = 'read' cuando acabe)"
