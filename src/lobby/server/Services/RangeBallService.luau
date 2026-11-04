--!strict
-- Cañón de pelotas del campo de tiro del Lobby (Fase 23d, World/RangeBuilder: CampoDeTiro/Canon). Al activar
-- "PelotasPrompt" se abre el panel de ese jugador (RangeBallController) con cuatro ajustes (Config.Range.Balls):
-- elasticidad, gravedad, tamaño y velocidad. "Fire" lanza una pelota física (pieza esférica sin anclar, con
-- CustomPhysicalProperties) desde la «Boca» del cañón. Los ajustes son de cada jugador y se guardan solo
-- mientras está en el servidor. La gravedad no toca Workspace.Gravity (sería la de todo el Lobby): la pelota
-- lleva una fuerza vertical que la sustituye por la pedida. Es solo práctica: las pelotas no dañan a nadie y
-- desaparecen solas (vida máxima y tope de pelotas vivas en todo el campo).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PROMPT_NAME = "PelotasPrompt"
-- Margen sobre el alcance del aviso por el retraso de la red.
local REACH_SLACK = 8
-- Lo que se separa la pelota de la boca del cañón al salir.
local MUZZLE_GAP = 0.3
local BALL_COLOR = Color3.fromRGB(255, 122, 26)
-- Peso de la elasticidad de la pelota frente a la del suelo y las paredes: gana la de la pelota.
local ELASTICITY_WEIGHT = 100
local BALL_DENSITY = 0.7

type Settings = { Elasticity: number, Gravity: number, Size: number, Speed: number }

local KEYS = { "Elasticity", "Gravity", "Size", "Speed" }

local RangeBallService = {}

local settingsOf: { [Player]: Settings } = {}
local lastFire: { [Player]: number } = {}
local alive: { BasePart } = {}
local cannonBase: BasePart? = nil
local ballFolder: Folder? = nil

local function defaults(): Settings
	local balls = Config.Range.Balls
	return {
		Elasticity = balls.Elasticity.default,
		Gravity = balls.Gravity.default,
		Size = balls.Size.default,
		Speed = balls.Speed.default,
	}
end

local function settingsFor(player: Player): Settings
	local settings = settingsOf[player]
	if not settings then
		settings = defaults()
		settingsOf[player] = settings
	end
	return settings
end

local function nearCannon(player: Player): boolean
	local base = cannonBase
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (base and root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - base.Position).Magnitude <= Config.Range.Balls.PanelReach + REACH_SLACK
end

local function send(player: Player, kind: string)
	Remotes.RangeBalls:FireClient(player, kind, table.clone(settingsFor(player)))
end

local function adjust(player: Player, key: any, direction: any)
	if not (typeof(key) == "string" and (direction == 1 or direction == -1) and table.find(KEYS, key)) then
		return
	end
	local range = (Config.Range.Balls :: any)[key]
	local settings = settingsFor(player) :: any
	-- Se redondea al paso para que +1 y -1 vuelvan al mismo valor sin errores de coma flotante.
	local steps = math.round((settings[key] - range.min) / range.step) + direction
	settings[key] = math.clamp(range.min + steps * range.step, range.min, range.max)
	send(player, "Settings")
end

local function removeBall(ball: BasePart)
	local index = table.find(alive, ball)
	if index then
		table.remove(alive, index)
	end
	ball:Destroy()
end

local function fire(player: Player)
	local base = cannonBase
	local mouth = if base and base.Parent then base.Parent:FindFirstChild("Boca") else nil
	if not (mouth and mouth:IsA("BasePart") and nearCannon(player)) then
		return
	end
	local now = os.clock()
	if now - (lastFire[player] or 0) < Config.Range.Balls.FireInterval then
		return
	end
	lastFire[player] = now

	local settings = settingsFor(player)
	while #alive >= Config.Range.Balls.MaxAlive do
		removeBall(alive[1])
	end

	local ball = Instance.new("Part")
	ball.Name = "Pelota"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * settings.Size
	ball.Color = BALL_COLOR
	ball.Material = Enum.Material.SmoothPlastic
	ball.CanTouch = false
	ball.CustomPhysicalProperties =
		PhysicalProperties.new(BALL_DENSITY, Config.Range.Balls.Friction, settings.Elasticity, 1, ELASTICITY_WEIGHT)
	ball:SetAttribute("Owner", player.UserId)
	local direction = mouth.CFrame.LookVector
	ball.CFrame = CFrame.new(mouth.Position + direction * (settings.Size / 2 + MUZZLE_GAP))
	ball.Parent = ballFolder or Workspace

	-- Gravedad propia: la fuerza suma o resta lo que falta para llegar a la pedida (pesos en studs/s²).
	local attachment = Instance.new("Attachment")
	attachment.Parent = ball
	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, ball.AssemblyMass * (Workspace.Gravity - settings.Gravity), 0)
	force.Parent = ball

	ball.AssemblyLinearVelocity = direction * settings.Speed
	ball:SetNetworkOwner(nil)
	table.insert(alive, ball)
	task.delay(Config.Range.Balls.Lifetime, function()
		if ball.Parent then
			removeBall(ball)
		end
	end)
end

local function hook(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == PROMPT_NAME then
		instance.Triggered:Connect(function(player: Player)
			if nearCannon(player) then
				send(player, "Open")
			end
		end)
	end
end

function RangeBallService:Start()
	local range = Workspace:WaitForChild("CampoDeTiro", 30)
	local cannon = if range then range:WaitForChild("Canon", 30) else nil
	local base = if cannon then cannon:WaitForChild("Base", 30) else nil
	if base and base:IsA("BasePart") then
		cannonBase = base
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pelotas"
	folder.Parent = Workspace
	ballFolder = folder

	for _, instance in Workspace:GetDescendants() do
		hook(instance)
	end
	Workspace.DescendantAdded:Connect(hook)

	Remotes.RangeBalls.OnServerEvent:Connect(function(player: Player, kind: any, key: any, direction: any)
		if kind == "Adjust" and nearCannon(player) then
			adjust(player, key, direction)
		elseif kind == "Fire" then
			fire(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		settingsOf[player] = nil
		lastFire[player] = nil
		for index = #alive, 1, -1 do
			if alive[index]:GetAttribute("Owner") == player.UserId then
				removeBall(alive[index])
			end
		end
	end)
end

return RangeBallService
