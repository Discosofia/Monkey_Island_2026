--!strict
-- Jinete en su montura para las escenas (Fase 25, «Sobrevuelo»). MountedRider.build(mountId, character?, options?)
-- devuelve UN Model con la montura (Shared/MountModels.build, PrimaryPart = Root) y encima una copia del personaje
-- del jugador (sin personaje, un R15 de HumanoidDescription vacía) sentada en su asiento, como en el juego
-- (UI/MountRiders.sync): la raíz del avatar soldada con un Weld al attachment «Seat» del hueso Body, RIDER_LIFT sobre él, y
-- la pose «Ride» de Data/PlayerAnimations puesta en su Animator (en el juego la pone CombatClient/BodyAnimations; aquí se
-- carga directo, porque Shared/Cinematics no depende de CombatClient).
-- Todo sin colisión ni consulta; solo el Root de la montura va anclado, así que el modelo entero se mueve con
-- PivotTo / Tween (evento «move» de Actors). Una escena lo usa como actor «prop»: `build = function() return MountedRider.build(…) end`.
-- options.pose: «Glide» (por defecto; plano con las alas abiertas, si la montura tiene esa animación) o «Idle» (reposo).
-- Mientras el modelo exista, cada Heartbeat avisa a MountModels.animate (plumas, remolinos, aura; glide = 1 si planea). Se
-- desconecta cuando el modelo se destruye.
-- ¡MountModels.build espera a cargar las mallas! Quien llame no puede reentrar mientras tanto.
-- Solo cliente (las escenas corren en el cliente); sin Remotes, Settings ni CombatClient.

local RunService = game:GetService("RunService")

local Mounts = require(script.Parent.Parent.Data.Mounts)
local MountModels = require(script.Parent.Parent.MountModels)
local PlayerAnimations = require(script.Parent.Parent.Data.PlayerAnimations)
local RescueCrew = require(script.Parent.RescueCrew)

local MountedRider = {}

export type Options = { pose: string? }

-- Altura del centro del HumanoidRootPart del jinete sobre el asiento (studs); la misma que UI/MountRiders.
local RIDER_LIFT = 0.35
local DEFAULT_POSE = "Glide"

-- Pistas de la montura: solo «Glide» e «Idle», en bucle. Devuelve la de la pose pedida (o Idle si no hay esa).
local function playMountPose(model: Model, mountId: string, pose: string)
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = if controller then controller:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return
	end
	local tracks: { [string]: AnimationTrack } = {}
	for _, name in { "Glide", "Idle" } do
		local id = Mounts[mountId].animations[name]
		if id and id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok then
				track.Looped = true
				tracks[name] = track
			end
		end
	end
	local chosen = tracks[pose] or tracks.Idle
	if chosen then
		chosen:Play(0.2, 1)
	end
end

-- Pose «Ride» del jinete (a horcajadas, con las riendas). Sin id publicado (vacío) no hay pose y queda de pie.
local function playRiderPose(avatar: Model)
	local ride = PlayerAnimations.Animations.Ride
	if not (RunService:IsRunning() and ride.id ~= "") then
		return
	end
	pcall(function()
		local humanoid = avatar:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = ride.id
		local track = (animator :: Animator):LoadAnimation(animation)
		track.Looped = true
		track.Priority = ride.priority
		track:Play(0.1, 1)
	end)
end

local function setNoCollision(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

function MountedRider.build(mountId: string, character: Model?, options: Options?): Model?
	local pose = if options and options.pose then options.pose else DEFAULT_POSE
	local model = MountModels.build(mountId)
	if not model then
		return nil
	end
	local mountRoot = model.PrimaryPart
	if not mountRoot then
		model:Destroy()
		return nil
	end
	mountRoot.Anchored = true
	setNoCollision(model)

	local seat = model:FindFirstChild("Seat", true)
	if seat and seat:IsA("Attachment") then
		local avatar = RescueCrew.cloneCharacter(character)
		local avatarRoot = if avatar then avatar:FindFirstChild("HumanoidRootPart") else nil
		if avatar and avatarRoot and avatarRoot:IsA("BasePart") then
			avatar.Name = "Jinete"
			RescueCrew.toMotors(avatar)
			RescueCrew.freeze(avatar)
			avatar.PrimaryPart = avatarRoot
			-- El asiento, RIDER_LIFT bajo el centro del HumanoidRootPart; el jinete mira hacia donde la montura.
			local seatLocal = mountRoot.CFrame:PointToObjectSpace(seat.WorldPosition)
			local offset = CFrame.new(seatLocal + Vector3.new(0, RIDER_LIFT, 0))
			avatar:PivotTo(mountRoot.CFrame * offset)
			local weld = Instance.new("Weld")
			weld.Name = "SeatWeld"
			weld.Part0 = mountRoot
			weld.Part1 = avatarRoot
			weld.C0 = offset
			weld.Parent = avatarRoot
			setNoCollision(avatar)
			avatar.Parent = model
			playRiderPose(avatar)
		elseif avatar then
			avatar:Destroy()
		end
	else
		warn(`[MountedRider] La montura {mountId} no tiene el attachment Seat: sin jinete`)
	end

	playMountPose(model, mountId, pose)

	-- Plumas, remolinos y aura de la montura; el jinete no cuenta como suelo para su sombra.
	local glide = if pose == "Glide" then 1 else 0
	local ignore: { Instance } = { model }
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		MountModels.animate(model, deltaTime, 0, glide, ignore)
	end)
	model.Destroying:Connect(function()
		connection:Disconnect()
	end)
	return model
end

return MountedRider
