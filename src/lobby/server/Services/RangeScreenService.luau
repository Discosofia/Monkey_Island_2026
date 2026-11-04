--!strict
-- Marcas de las pantallas de ajuste del campo de tiro (Fase 23, World/RangeBuilder). Cuando un proyectil
-- acaba contra una pantalla (pieza con el atributo RangeScreen), el servidor calcula dónde: en studs desde
-- el centro, hacia la derecha de quien mira (dx) y hacia arriba (dy), y la distancia del tirador al
-- centro. Se lo manda solo al tirador (Remotes.RangeShot); su cliente dibuja la marca y la media
-- (RangeScreenController). Las marcas son locales de cada jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Projectiles = require(ServerScriptService.Combat.Projectiles)

-- El impacto tiene que caer en la cara que se ve: a más de esto por delante del centro de la pieza.
local FACE_DEPTH = 0.3
-- Margen sobre el borde de la pantalla (el rayo toca justo en el canto).
local EDGE_SLACK = 0.05
-- Lo más lejos del centro de la pantalla a lo que se acepta a un tirador (el recinto mide 182 studs).
local MAX_SHOOTER_DISTANCE = 300

local RangeScreenService = {}

local lastSent: { [Player]: number } = {}

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function onImpact(shooter: Player, position: Vector3, instance: Instance?, _model: Model?)
	if not (instance and instance:IsA("BasePart")) then
		return
	end
	local screenId = instance:GetAttribute("RangeScreen")
	local gui = instance:FindFirstChild("Pantalla")
	if not (typeof(screenId) == "string" and gui and gui:IsA("SurfaceGui")) then
		return
	end
	local root = livingRoot(shooter)
	if not root or (root.Position - instance.Position).Magnitude > MAX_SHOOTER_DISTANCE then
		return
	end
	local now = os.clock()
	if now - (lastSent[shooter] or -math.huge) < Config.Range.MarkMinInterval then
		return
	end

	-- Ejes de la pantalla vista de frente: "right" es la derecha de quien la mira y arriba, el eje y.
	local normal = instance.CFrame:VectorToWorldSpace(Vector3.FromNormalId(gui.Face))
	local right = (-normal):Cross(Vector3.yAxis)
	if right.Magnitude < 1e-3 then
		return
	end
	right = right.Unit
	local relative = position - instance.Position
	local dx = relative:Dot(right)
	local dy = relative.Y
	local width = instance:GetAttribute("ScreenWidth")
	local height = instance:GetAttribute("ScreenHeight")
	if not (typeof(width) == "number" and typeof(height) == "number") then
		return
	end
	if
		relative:Dot(normal) < FACE_DEPTH
		or math.abs(dx) > width / 2 + EDGE_SLACK
		or math.abs(dy) > height / 2 + EDGE_SLACK
	then
		return
	end
	lastSent[shooter] = now
	local distance = (root.Position - instance.Position).Magnitude
	Remotes.RangeShot:FireClient(shooter, screenId, dx, dy, distance)
end

function RangeScreenService:Start()
	Projectiles.onImpact(onImpact)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSent[player] = nil
	end)
end

return RangeScreenService
