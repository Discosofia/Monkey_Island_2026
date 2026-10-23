--!strict
-- Monturas (Fase 11), en el Lobby y en la Isla. Cada cliente dibuja la montura de cada jugador que
-- va montado (atributo "Mounted" del Player, que pone ServerShared/MountServer): la construye con
-- Shared/MountModels y la suelda bajo su HumanoidRootPart, con el asiento en las caderas del jinete.
-- No colisiona ni se puede golpear (CanCollide y CanQuery apagados): el cuerpo sigue siendo el
-- personaje, así que el combate, el huevo y la zona segura no cambian.
-- Animaciones de la montura (Data/Mounts "animations"): "Idle" parada y "Run" al ir rápido (se
-- mezclan según la velocidad, Config.Mounts.RunFrom / RunFull) y "Jump" al saltar.
-- Para el jinete local, además: sube el HipHeight para que vaya sentado encima, pone la pose "Ride"
-- (Client/BodyAnimations) y lo baja si coge un arma o se mete en el agua. La velocidad la pone quien
-- la lleva en cada place (SurvivalController en la Isla, MountController en el Lobby) con speedOf.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BodyAnimations = require(ReplicatedStorage.CombatClient.BodyAnimations)
local CombatState = require(script.Parent.Parent.CombatState)
local Config = require(script.Parent.Parent.Config)
local MountModels = require(script.Parent.Parent.MountModels)
local Mounts = require(script.Parent.Parent.Data.Mounts)
local Remotes = require(script.Parent.Parent.Remotes)

local SETTINGS = Config.Mounts
-- Altura del centro del HumanoidRootPart del jinete sobre el asiento (studs).
local RIDER_LIFT = 0.35
-- Velocidad vertical (studs/s) a partir de la cual cuenta como un salto, y espera entre saltos.
local JUMP_SPEED, JUMP_GAP = 8, 0.8
-- Velocidad horizontal a la que la animación de galope va a su ritmo normal.
local RUN_REFERENCE = 24

type Rider = {
	mountId: string,
	model: Model,
	root: BasePart, -- HumanoidRootPart del jinete
	seatHeight: number, -- altura del asiento sobre el suelo de la montura
	tracks: { [string]: AnimationTrack },
	jumpedAt: number,
}

local MountRiders = {}

local riders: { [Player]: Rider } = {}
local folder: Folder? = nil
-- Cada cuánto se repasa a quién falta dibujarle la montura (su personaje llegó tarde por el streaming).
local RESYNC_SECONDS = 1
local resyncIn = RESYNC_SECONDS
-- HipHeight del jinete local antes de montar, para devolverlo al bajar.
local savedHipHeight: number? = nil

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Velocidad a la que va "player" montado (nil si va a pie).
function MountRiders.speedOf(player: Player): number?
	local mountId = player:GetAttribute(CombatState.MOUNTED_ATTRIBUTE)
	local mount = if typeof(mountId) == "string" then Mounts[mountId] else nil
	return if mount then SETTINGS.Speed * mount.speed else nil
end

local function loadTracks(model: Model, mountId: string): { [string]: AnimationTrack }
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = if controller then controller:FindFirstChildOfClass("Animator") else nil
	local tracks: { [string]: AnimationTrack } = {}
	if not animator then
		return tracks
	end
	for name, id in Mounts[mountId].animations do
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok then
				tracks[name] = track
			end
		end
	end
	if tracks.Idle then
		tracks.Idle.Looped = true
		tracks.Idle:Play(0.2, 1)
	end
	if tracks.Run then
		tracks.Run.Looped = true
		tracks.Run:Play(0.2, 0.001)
	end
	return tracks
end

-- Sube o baja al jinete local: altura de las caderas y pose.
local function setLocalRider(rider: Rider?)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end
	if rider then
		if savedHipHeight == nil then
			savedHipHeight = humanoid.HipHeight
		end
		humanoid.HipHeight = rider.seatHeight + RIDER_LIFT - rider.root.Size.Y / 2
		humanoid:UnequipTools()
		BodyAnimations.play("Ride")
	else
		if savedHipHeight ~= nil then
			humanoid.HipHeight = savedHipHeight
			savedHipHeight = nil
		end
		BodyAnimations.stop("Ride")
	end
end

local function remove(player: Player)
	local rider = riders[player]
	if not rider then
		return
	end
	riders[player] = nil
	rider.model:Destroy()
	if player == Players.LocalPlayer then
		setLocalRider(nil)
	end
end

local function sync(player: Player)
	local mountId = player:GetAttribute(CombatState.MOUNTED_ATTRIBUTE)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local current = riders[player]
	if current and current.mountId == mountId and current.root == root and current.model.Parent then
		return
	end
	remove(player)
	if typeof(mountId) ~= "string" or not Mounts[mountId] or not (root and root:IsA("BasePart")) then
		return
	end
	local model = MountModels.build(mountId)
	if not model then
		return
	end
	local mountRoot = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("Seat", true) :: Attachment
	local seatLocal = mountRoot.CFrame:PointToObjectSpace(seat.WorldPosition)
	mountRoot.Anchored = false
	-- El asiento, RIDER_LIFT bajo el centro del HumanoidRootPart; la montura mira hacia donde él.
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = mountRoot
	weld.C0 = CFrame.new(-seatLocal.X, -RIDER_LIFT - seatLocal.Y, -seatLocal.Z)
	weld.Parent = mountRoot
	model.Name = `Montura_{player.Name}`
	model.Parent = folder :: Folder
	local rider: Rider = {
		mountId = mountId,
		model = model,
		root = root,
		seatHeight = seatLocal.Y,
		tracks = loadTracks(model, mountId),
		jumpedAt = -math.huge,
	}
	riders[player] = rider
	if player == Players.LocalPlayer then
		setLocalRider(rider)
	end
end

local function update(deltaTime: number)
	resyncIn -= deltaTime
	if resyncIn <= 0 then
		resyncIn = RESYNC_SECONDS
		for _, player in Players:GetPlayers() do
			if CombatState.isMounted(player) ~= (riders[player] ~= nil) then
				sync(player)
			end
		end
	end
	for _, rider in riders do
		local velocity = rider.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local run = smoothstep(SETTINGS.RunFrom, SETTINGS.RunFull, speed)
		local tracks = rider.tracks
		if tracks.Run then
			tracks.Run:AdjustWeight(math.max(run, 0.001), 0.15)
			tracks.Run:AdjustSpeed(math.clamp(speed / RUN_REFERENCE, 0.6, 1.5))
		end
		if tracks.Idle then
			tracks.Idle:AdjustWeight(math.max(1 - run, 0.001), 0.15)
		end
		if tracks.Jump and velocity.Y > JUMP_SPEED and os.clock() - rider.jumpedAt > JUMP_GAP then
			rider.jumpedAt = os.clock()
			tracks.Jump:Play(0.1)
		end
	end
end

-- El jinete local baja si coge un arma (quiere pelear) o se mete en el agua.
local function watchLocal(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and CombatState.isMounted(Players.LocalPlayer) then
			Remotes.ToggleMount:FireServer(false)
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		savedHipHeight = nil
		humanoid.StateChanged:Connect(function(_, state)
			if state == Enum.HumanoidStateType.Swimming and CombatState.isMounted(Players.LocalPlayer) then
				Remotes.ToggleMount:FireServer(false)
			end
		end)
	end
end

-- Pide montar o bajar (el servidor decide).
function MountRiders.toggle()
	Remotes.ToggleMount:FireServer(not CombatState.isMounted(Players.LocalPlayer))
end

function MountRiders.start()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Monturas"
	newFolder.Parent = Workspace
	folder = newFolder

	local function track(player: Player)
		player:GetAttributeChangedSignal(CombatState.MOUNTED_ATTRIBUTE):Connect(function()
			sync(player)
		end)
		player.CharacterAdded:Connect(function(character)
			if player == Players.LocalPlayer then
				task.spawn(watchLocal, character)
			end
			character:WaitForChild("HumanoidRootPart", 10)
			sync(player)
		end)
		if player == Players.LocalPlayer and player.Character then
			task.spawn(watchLocal, player.Character)
		end
		sync(player)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(remove)
	RunService.RenderStepped:Connect(update)
end

return MountRiders
