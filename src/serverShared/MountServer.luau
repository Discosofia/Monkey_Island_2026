--!strict
-- Monturas (Fase 11): montar y bajar en el Lobby y en la Isla (en Dunas no se arranca). El servidor
-- solo decide si va montado: pone en el Player el atributo "Mounted" con el id de la montura (o nil).
-- Cada cliente dibuja la montura bajo el personaje (Shared/UI/MountRiders) y el del jinete cambia su
-- velocidad y su pose. Montado no se pelea (Shared/CombatState.canAct).
-- Se monta la montura que lleva ("ActiveMount", ServerShared/PlayerData) si está vivo, no carga el
-- huevo, no está aturdido ni haciendo otra cosa y no le han hecho daño hace poco
-- (Config.Mounts.HurtCooldown). Lo bajan: pedirlo, recibir daño, coger el huevo, caer, morir o
-- reaparecer, y cambiar de montura.
-- Montado, la montura puede escupir (gesto sin daño, remoto MountSpit): el servidor mira la espera
-- (Config.Mounts.SpitCooldown) y avisa a todos los clientes, que la animan (UI/MountRiders).
-- Lo arrancan los MountService del Lobby y de la Isla.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestCooldown = require(script.Parent.RequestCooldown)

local SETTINGS = Config.Mounts
local ATTRIBUTE = CombatState.MOUNTED_ATTRIBUTE

local MountServer = {}

local canRequest = RequestCooldown.new(0.25)
-- Última vez (os.clock) que montó o bajó, y que recibió daño.
local lastToggle: { [Player]: number } = {}
local lastHurt: { [Player]: number } = {}
local lastSpit: { [Player]: number } = {}

function MountServer.isMounted(player: Player): boolean
	return CombatState.isMounted(player)
end

-- Lo baja de la montura (si iba montado). Lo pueden llamar otros sistemas del servidor.
function MountServer.dismount(player: Player)
	if CombatState.isMounted(player) then
		player:SetAttribute(ATTRIBUTE, nil)
		lastToggle[player] = os.clock()
	end
end

-- Por qué no puede montar ahora (nil si puede). "" = no hace falta avisar (pulsó muy seguido).
local function blockReason(player: Player): string?
	local mountId = player:GetAttribute("ActiveMount")
	if typeof(mountId) ~= "string" or not Mounts[mountId] then
		return "No llevas ninguna montura: elígela en el cartel de Mascotas del Lobby"
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or not LifeState.isAlive(player) then
		return ""
	end
	if player:GetAttribute("CarryingEgg") == true then
		return "Con el huevo a cuestas no puedes montar"
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		return "No puedes montar en el agua"
	end
	if CombatState.isTrapped(player) or CombatState.get(player) ~= "Idle" then
		return ""
	end
	if os.clock() - (lastHurt[player] or -math.huge) < SETTINGS.HurtCooldown then
		return "Te acaban de herir: espera un momento para montar"
	end
	if os.clock() - (lastToggle[player] or -math.huge) < SETTINGS.RemountCooldown then
		return ""
	end
	return nil
end

local function onToggle(player: Player, wanted: any)
	if typeof(wanted) ~= "boolean" or not canRequest(player) then
		return
	end
	if not wanted then
		MountServer.dismount(player)
		return
	end
	if CombatState.isMounted(player) then
		return
	end
	local reason = blockReason(player)
	if reason then
		if reason ~= "" then
			Remotes.Notify:FireClient(player, reason)
		end
		return
	end
	player:SetAttribute(ATTRIBUTE, player:GetAttribute("ActiveMount"))
	lastToggle[player] = os.clock()
end

local function onSpit(player: Player)
	local mountId = player:GetAttribute(ATTRIBUTE)
	local mount = if typeof(mountId) == "string" then Mounts[mountId] else nil
	if not (mount and mount.animations.Spit and mount.animations.Spit ~= "") then
		return
	end
	if os.clock() - (lastSpit[player] or -math.huge) < SETTINGS.SpitCooldown then
		return
	end
	lastSpit[player] = os.clock()
	Remotes.MountSpit:FireAllClients(player)
end

local function watchCharacter(player: Player, character: Model)
	-- Reaparecer lo deja a pie.
	MountServer.dismount(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(value)
		if value < health then
			lastHurt[player] = os.clock()
			MountServer.dismount(player)
		end
		health = value
	end)
	humanoid.Died:Connect(function()
		MountServer.dismount(player)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	player:GetAttributeChangedSignal("CarryingEgg"):Connect(function()
		if player:GetAttribute("CarryingEgg") == true then
			MountServer.dismount(player)
		end
	end)
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(function()
		if not LifeState.isAlive(player) then
			MountServer.dismount(player)
		end
	end)
	-- Si cambia de montura (o la quita) mientras va montado, baja.
	player:GetAttributeChangedSignal("ActiveMount"):Connect(function()
		if player:GetAttribute(ATTRIBUTE) ~= player:GetAttribute("ActiveMount") then
			MountServer.dismount(player)
		end
	end)
end

function MountServer.start()
	Remotes.ToggleMount.OnServerEvent:Connect(onToggle)
	Remotes.MountSpit.OnServerEvent:Connect(onSpit)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastToggle[player] = nil
		lastHurt[player] = nil
		lastSpit[player] = nil
	end)
end

return MountServer
