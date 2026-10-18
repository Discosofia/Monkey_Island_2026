--!strict
-- Mascotas que siguen a su dueño (Fase 5), en el Lobby y en la Isla. Cada cliente dibuja las de todos
-- los jugadores (atributo "ActivePet"), así se mueven suaves sin cargar al servidor. Las de rastreo,
-- además, resaltan a su dueño los monos cercanos cada pocos segundos. Las de combate, cuando el
-- servidor avisa de un ataque (Remotes.PetAttack), corren hasta el mono, hacen su ataque (el clip
-- "Attack" de PetModels, o un salto genérico) justo cuando llega el daño
-- (Config.Pets.StrikeDelaySeconds) y vuelven con su dueño.
-- Cómo se mueven según lo que hace el dueño:
--   - Las de suelo andan al paso de su dueño (o de lo que se desplazan ellas) y galopan ("Run") cuando
--     esprinta. Si el dueño se queda quieto un rato, las que tienen rutinas de reposo (clips "Idle…",
--     los felinos) hacen una al azar; "IdleRub" da una vuelta alrededor de sus piernas.
--   - Las aves baten y planean ("Glide"), se inclinan en los giros y, con el dueño quieto, vuelan en
--     círculos sobre él. El colibrí revolotea de un punto a otro a su alrededor.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local PetModels = require(script.Parent.Parent.PetModels)
local Pets = require(script.Parent.Parent.Data.Pets)
local Remotes = require(script.Parent.Parent.Remotes)

local TRACK_EVERY = 5
local TRACK_RADIUS = 60
-- Duración total de un ataque (ir, golpear y empezar a volver).
local ATTACK_SECONDS = 0.85
-- Segundos con el dueño quieto antes de la primera rutina de reposo, y pausa entre una y otra.
local IDLE_AFTER = 2.5
local IDLE_PAUSE = { 2.5, 5 }
-- Velocidad del dueño (studs/s) a la que empieza a galopar y a la que galopa del todo (correr = 24).
local RUN_FROM, RUN_FULL = 18, 23
-- Vuelta alrededor de las piernas del dueño ("IdleRub"), en radianes por segundo.
local RUB_TURN = 0.9
-- Aves: vuelta sobre el dueño quieto (radio, altura, rad/s) y ciclo de batir y planear (segundos).
local ORBIT_RADIUS, ORBIT_HEIGHT, ORBIT_TURN = 3.5, 2.6, 0.8
local FLAP_SECONDS, GLIDE_SECONDS = 2, 1.2
-- Cuerpo doblado al girar (felinos): radianes de curva por cada radián/s de giro, y el máximo.
local BEND_PER_TURN, BEND_MAX = 0.12, 0.45

local PetFollowers = {}

type Attack = { target: Model, startedAt: number, standOff: number }
-- Rutina de reposo en curso; "leaving" cuando el dueño se ha movido y se está deshaciendo.
type Idle = { clip: string, startedAt: number, length: number, leaving: boolean, angle: number }
type Follower = {
	petId: string,
	model: Model,
	attack: Attack?,
	clock: number, -- tiempo de su animación, que corre más deprisa mientras ataca
	stride: number, -- reloj de las patas: va al paso de lo que anda
	clips: { [string]: number }, -- clips de PetModels y lo que dura cada uno
	idles: { string }, -- sus rutinas de reposo
	still: number, -- segundos que lleva quieto el dueño
	idle: Idle?,
	idleWeight: number,
	nextIdle: number,
	lastIdle: string?,
	run: number, -- peso del galope
	glide: number, -- peso del planeo (aves)
	orbit: number?, -- ángulo de la vuelta sobre el dueño (aves); nil si no la está dando
	hoverAt: Vector3?, -- punto alrededor del dueño en el que revolotea (colibrí)
	hoverUntil: number,
	bend: number, -- cuánto dobla el cuerpo hacia la curva al girar (radianes, + a la izquierda)
}

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

function PetFollowers.start()
	local followers: { [Player]: Follower } = {}
	local localPlayer = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "Mascotas"
	folder.Parent = Workspace

	local function sync(player: Player)
		local petId = player:GetAttribute("ActivePet")
		local current = followers[player]
		if current and current.petId == petId then
			return
		end
		if current then
			current.model:Destroy()
			followers[player] = nil
		end
		if typeof(petId) == "string" then
			local model = PetModels.build(petId)
			if model then
				model.Parent = folder
				local clips = PetModels.clips(model)
				local idles = {}
				for name in clips do
					if string.sub(name, 1, 4) == "Idle" then
						table.insert(idles, name)
					end
				end
				table.sort(idles)
				followers[player] = {
					petId = petId,
					model = model,
					attack = nil,
					clock = 0,
					stride = 0,
					clips = clips,
					idles = idles,
					still = 0,
					idle = nil,
					idleWeight = 0,
					nextIdle = 0,
					lastIdle = nil,
					run = 0,
					glide = 0,
					orbit = nil,
					hoverAt = nil,
					hoverUntil = 0,
					bend = 0,
				}
			end
		end
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal("ActivePet"):Connect(function()
			sync(player)
		end)
		sync(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local current = followers[player]
		if current then
			current.model:Destroy()
			followers[player] = nil
		end
	end)

	-- Sigue al dueño, detrás y a un lado: las que andan o saltan van por el suelo, las que vuelan
	-- un poco por encima, y todas mueven sus partes (PetModels.animate).
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	local function groundBelow(position: Vector3, fallback: number, extra: Instance?): number
		local ignore: { Instance } = { folder }
		if extra then
			table.insert(ignore, extra)
		end
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		groundParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), groundParams)
		return if hit then hit.Position.Y else fallback
	end

	Remotes.PetAttack.OnClientEvent:Connect(function(player: Player, target: Model)
		local follower = followers[player]
		if follower and typeof(target) == "Instance" and target:IsA("Model") then
			local size = target:GetExtentsSize()
			follower.attack = {
				target = target,
				startedAt = os.clock(),
				standOff = math.max(size.X, size.Z) * 0.3 + 1.5,
			}
		end
	end)

	-- Ataque: delante del mono, de cara a él. Se echa atrás para coger impulso y se lanza sobre él. Sin
	-- clip de ataque propio ("ownClip"), además cabecea (morro arriba y luego abajo) y da un saltito.
	local function attackPose(model: Model, attack: Attack, now: number, lift: number, ownClip: boolean): CFrame
		local target = attack.target:GetPivot().Position
		local current = model:GetPivot().Position
		local flat = (current - target) * Vector3.new(1, 0, 1)
		local away = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
		local t = now - attack.startedAt
		local strikeAt = Config.Pets.StrikeDelaySeconds
		local windup = smoothstep(strikeAt - 0.2, strikeAt, t) * (1 - smoothstep(strikeAt, strikeAt + 0.08, t))
		local strike = smoothstep(strikeAt, strikeAt + 0.08, t) * (1 - smoothstep(strikeAt + 0.2, ATTACK_SECONDS, t))
		local stand = target + away * (attack.standOff + windup * 0.8 - strike * attack.standOff * 0.6)
		local motion = model:GetAttribute("Motion")
		local y = if motion == "Fly" or motion == "Hover"
			then target.Y + 1
			else groundBelow(stand, target.Y - 2, attack.target) + lift + (if ownClip then 0 else strike * 0.8)
		local position = Vector3.new(stand.X, y, stand.Z)
		local facing = CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
		if ownClip then
			return facing
		end
		return facing * CFrame.Angles(math.rad(25) * windup - math.rad(20) * strike, 0, 0)
	end

	-- Elige la siguiente rutina de reposo, sin repetir la última.
	local function pickIdle(follower: Follower): string
		local options = {}
		for _, name in follower.idles do
			if name ~= follower.lastIdle or #follower.idles == 1 then
				table.insert(options, name)
			end
		end
		return options[math.random(#options)]
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()
		for player, follower in followers do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				local model = follower.model
				local motion = model:GetAttribute("Motion")
				local height = model:GetAttribute("Height")
				local velocity = root.AssemblyLinearVelocity
				local ownerSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				local lift = if typeof(height) == "number" then height else 0.6
				local attack = follower.attack
				if attack and (now - attack.startedAt > ATTACK_SECONDS or not attack.target.Parent) then
					follower.attack = nil
					attack = nil
				end
				local clips = follower.clips
				follower.still = if ownerSpeed < 1 then follower.still + deltaTime else 0

				-- Rutina de reposo: empieza con el dueño quieto un rato y se deshace si se mueve o ataca.
				local idle = follower.idle
				if idle and now - idle.startedAt >= idle.length then
					follower.lastIdle = idle.clip
					follower.idle = nil
					follower.idleWeight = 0
					follower.nextIdle = now + IDLE_PAUSE[1] + math.random() * (IDLE_PAUSE[2] - IDLE_PAUSE[1])
					idle = nil
				end
				if idle and (attack or follower.still == 0) then
					idle.leaving = true
				end
				if
					not idle
					and not attack
					and #follower.idles > 0
					and follower.still > IDLE_AFTER
					and now >= follower.nextIdle
				then
					local clip = pickIdle(follower)
					local offset = root.CFrame:PointToObjectSpace(model:GetPivot().Position)
					idle = {
						clip = clip,
						startedAt = now,
						length = clips[clip],
						leaving = false,
						angle = math.atan2(offset.X, offset.Z),
					}
					follower.idle = idle
				end
				if idle then
					if idle.leaving then
						follower.idleWeight = math.max(0, follower.idleWeight - deltaTime * 5)
						if follower.idleWeight == 0 then
							follower.lastIdle = idle.clip
							follower.idle = nil
							follower.nextIdle = now + IDLE_PAUSE[1]
							idle = nil
						end
					else
						follower.idleWeight = math.min(1, follower.idleWeight + deltaTime * 4)
					end
				end

				local goal: CFrame
				local alphaRate = if attack then 14 else 6
				if attack then
					goal = attackPose(model, attack, now, lift, clips.Attack ~= nil)
				elseif motion == "Fly" then
					local roll = math.clamp(root.AssemblyAngularVelocity.Y * 0.15, -0.4, 0.4)
					if follower.still > 1.5 then
						-- Vuelta sobre el dueño quieto, inclinada hacia dentro (le queda a su izquierda).
						local angle = follower.orbit
						if not angle then
							local offset = model:GetPivot().Position - root.Position
							angle = math.atan2(offset.X, offset.Z)
						end
						angle += deltaTime * ORBIT_TURN
						follower.orbit = angle
						local position = root.Position
							+ Vector3.new(
								math.sin(angle) * ORBIT_RADIUS,
								ORBIT_HEIGHT + math.sin(now * 1.3) * 0.4,
								math.cos(angle) * ORBIT_RADIUS
							)
						local ahead = Vector3.new(math.cos(angle), 0, -math.sin(angle))
						goal = CFrame.lookAt(position, position + ahead) * CFrame.Angles(0, 0, 0.35)
						alphaRate = 4
					else
						follower.orbit = nil
						local moving = math.clamp(ownerSpeed / 12, 0, 1)
						goal = root.CFrame
							* CFrame.new(2.8, 2 + math.sin(now * 3) * 0.4, 2.2)
							* CFrame.Angles(-math.rad(12) * moving, 0, roll)
					end
				elseif motion == "Hover" then
					if follower.still > 1.5 then
						-- Revolotea de un punto a otro alrededor del dueño, mirándole.
						local spot = follower.hoverAt
						if not spot or now >= follower.hoverUntil then
							local angle = math.random() * math.pi * 2
							local radius = 1.8 + math.random() * 1.2
							spot = Vector3.new(
								math.sin(angle) * radius,
								1.2 + math.random() * 1.4,
								math.cos(angle) * radius
							)
							follower.hoverAt = spot
							follower.hoverUntil = now + 1 + math.random() * 1.2
						end
						local position = root.Position + spot + Vector3.new(0, math.sin(now * 5) * 0.12, 0)
						goal = CFrame.lookAt(position, Vector3.new(root.Position.X, position.Y, root.Position.Z))
						alphaRate = 8
					else
						follower.hoverAt = nil
						goal = root.CFrame * CFrame.new(1.8, 1.2 + math.sin(now * 5) * 0.25, 1.2)
					end
				elseif idle and idle.clip == "IdleRub" and not idle.leaving then
					-- Vuelta alrededor de las piernas del dueño, con él a su izquierda.
					local angle = idle.angle + (now - idle.startedAt) * RUB_TURN
					local radius = 1.5 + model:GetExtentsSize().X * 0.5
					local around = root.CFrame * CFrame.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
					local ahead = root.CFrame:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, -math.sin(angle)))
					local floor = groundBelow(around.Position, root.Position.Y - 3)
					local position = Vector3.new(around.X, floor + lift, around.Z)
					goal = CFrame.lookAt(position, position + ahead)
					alphaRate = 5
				else
					local beside = root.CFrame * CFrame.new(2.5, 0, 2.5)
					local floor = groundBelow(beside.Position, root.Position.Y - 3)
					-- Con el reloj de las patas, para que la rana patalee al compás de los saltos.
					local hop = if motion == "Hop"
						then math.abs(math.sin(follower.stride * 6)) * (0.15 + math.clamp(ownerSpeed / 12, 0, 1) * 0.8)
						else 0
					goal = beside.Rotation + Vector3.new(beside.X, floor + lift + hop, beside.Z)
				end
				local current = model:GetPivot()
				local nextPivot = current:Lerp(goal, math.clamp(deltaTime * alphaRate, 0, 1))
				model:PivotTo(nextPivot)

				-- Las patas andan al paso de lo que se mueve: el dueño o ella misma (al volver a su
				-- sitio, al dar la vuelta al dueño).
				local ownSpeed = ((nextPivot.Position - current.Position) * Vector3.new(1, 0, 1)).Magnitude
					/ math.max(deltaTime, 1 / 240)
				local speed = math.max(ownerSpeed, ownSpeed)
				local moving = if attack then 1 else math.clamp(speed / 12, 0, 1)
				local cadence = if attack then 2.2 else math.clamp(speed / 14, 0.7, 1.7)
				follower.stride += deltaTime * cadence

				-- Lo que gira en este fotograma (en Y, + a la izquierda): los felinos doblan el cuerpo
				-- hacia la curva. Con tope y suavizado, para que un giro brusco no lo parta.
				local before = current.LookVector * Vector3.new(1, 0, 1)
				local after = nextPivot.LookVector * Vector3.new(1, 0, 1)
				local turnRate = math.atan2(before:Cross(after).Y, before:Dot(after)) / math.max(deltaTime, 1 / 240)
				local bendGoal = math.clamp(turnRate * BEND_PER_TURN, -BEND_MAX, BEND_MAX)
				follower.bend += (bendGoal - follower.bend) * math.clamp(deltaTime * 8, 0, 1)
				follower.clock += deltaTime * (if attack then 2.2 elseif motion == "Fly" then 1 + moving * 0.4 else 1)

				-- Clips: ataque, rutina de reposo, galope y planeo.
				local layers: { PetModels.Layer } = {}
				if attack and clips.Attack then
					table.insert(layers, { clip = "Attack", time = now - attack.startedAt, weight = 1 })
				end
				if idle and follower.idleWeight > 0 then
					table.insert(
						layers,
						{ clip = idle.clip, time = now - idle.startedAt, weight = follower.idleWeight }
					)
				end
				if clips.Run then
					local running = if attack or idle
						then 0
						else math.clamp((ownerSpeed - RUN_FROM) / (RUN_FULL - RUN_FROM), 0, 1)
					follower.run += (running - follower.run) * math.clamp(deltaTime * 5, 0, 1)
					if follower.run > 0.01 then
						table.insert(layers, { clip = "Run", time = follower.stride, weight = follower.run })
					end
				end
				if clips.Glide then
					-- Bate un rato y planea otro; si el dueño esprinta, bate sin parar.
					local cycle = now % (FLAP_SECONDS + GLIDE_SECONDS)
					local gliding = if attack or ownerSpeed > RUN_FROM then 0 elseif cycle > FLAP_SECONDS then 1 else 0
					follower.glide += (gliding - follower.glide) * math.clamp(deltaTime * 5, 0, 1)
					if follower.glide > 0.01 then
						table.insert(layers, { clip = "Glide", time = now, weight = follower.glide })
					end
				end
				PetModels.animate(model, follower.clock, moving, layers, follower.stride, follower.bend)
			end
		end
	end)

	-- Rastreo: resalta los monos cercanos al dueño (solo él los ve).
	task.spawn(function()
		while true do
			task.wait(TRACK_EVERY)
			local petId = localPlayer:GetAttribute("ActivePet")
			local pet = if typeof(petId) == "string" then Pets[petId] else nil
			local character = localPlayer.Character
			if pet and pet.tracks and character then
				local position = character:GetPivot().Position
				for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
					if enemy:IsA("Model") and (enemy:GetPivot().Position - position).Magnitude <= TRACK_RADIUS then
						local highlight = Instance.new("Highlight")
						highlight.FillTransparency = 1
						highlight.OutlineColor = Color3.fromRGB(255, 220, 90)
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.Parent = enemy
						Debris:AddItem(highlight, 3)
					end
				end
			end
		end
	end)
end

return PetFollowers
