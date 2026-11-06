--!strict
-- Deslizamiento del talud del Juego de pelota (Fase 27a). El talud de la cancha es de ~25° y el jugador local que lo
-- pisa, o salta sobre él, resbala hacia el pasillo a Data.Talud.SlideSpeed (a lo largo de la pendiente). Lo mueve
-- una LinearVelocity de fuerza limitada (como el hielo de ZoneController y Dash): la velocidad que quiere el
-- jugador (MoveDirection x WalkSpeed) más el empuje cuesta abajo, así que quedarse parado nunca es posible, andar
-- no sube y correr sube despacio.
--   - En el suelo: modo Vector, con la Y de lo que anda proyectada sobre la pendiente (así andar hacia arriba sube
--     y la bajada no despega al personaje del suelo).
--   - En el aire (salto, esquiva aérea, Salto de jaguar): modo Plane en horizontal, con la Y libre (la gravedad y
--     el salto no se tocan); sobre el talud también empuja hacia el pasillo.
-- Solo actúa con el modo Juego de pelota en marcha y el jugador vivo. Si hay otro empuje (esquiva, deslizamiento
-- de carrera, hielo) lo deja hacer. Sin Remotes ni servidor: el cliente manda en el movimiento de su personaje.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)

local TaludSlideController = {}

-- Cuánto por encima de la velocidad vertical que el controlador pide (studs/s) tiene que subir el personaje para
-- que se le deje el aire libre. Correr cuesta arriba pide como mucho ~12 de subida, muy por debajo de un salto.
local UPWARD_MARGIN = 8

local slide: LinearVelocity? = nil
local layoutFormat = 0
local layout: CourtGeometry.Layout? = nil
local lastActive = false
local lastGrounded = false
local lastSpeed = 0

-- La cancha del formato en curso (cacheada).
local function currentLayout(): CourtGeometry.Layout
	local format = Arena.format()
	if not layout or layoutFormat ~= format then
		layout = CourtGeometry.forFormat(format)
		layoutFormat = format
	end
	return layout :: CourtGeometry.Layout
end

local function stop()
	if slide then
		slide:Destroy()
		slide = nil
	end
	lastActive = false
	lastSpeed = 0
end

-- true si otro empuje (esquiva, deslizamiento de carrera, hielo) mueve ahora a "root".
local function pushed(root: BasePart): boolean
	for _, child in root:GetChildren() do
		if child:IsA("LinearVelocity") and child ~= slide then
			return true
		end
	end
	return false
end

local function update()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local attachment = if root then root:FindFirstChild("RootAttachment") else nil
	if
		not (character and root and root:IsA("BasePart") and humanoid and attachment and attachment:IsA("Attachment"))
		or humanoid.Health <= 0
		or ArenaModes.current() ~= "Ballgame"
	then
		stop()
		return
	end

	-- Pies en coordenadas locales de la cancha.
	local feetY = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
	local feet = Vector3.new(root.Position.X, feetY, root.Position.Z) - CourtGeometry.CENTER
	local info = CourtGeometry.taludAt(currentLayout(), feet)
	if not info or pushed(root) then
		if slide then
			slide.Enabled = false
		end
		lastActive = false
		lastSpeed = 0
		return
	end

	local current = slide
	if not current or current.Parent ~= root then
		stop()
		local created = Instance.new("LinearVelocity")
		created.Name = "TaludSlide"
		created.Attachment0 = attachment
		created.PrimaryTangentAxis = Vector3.xAxis
		created.SecondaryTangentAxis = Vector3.zAxis
		created.Parent = root
		slide = created
		current = created
	end
	local constraint = current :: LinearVelocity
	constraint.Enabled = true
	constraint.MaxForce = root.AssemblyMass * Data.Talud.MaxForceFactor

	local walk = humanoid.MoveDirection * humanoid.WalkSpeed
	local push = info.downhill * Data.Talud.SlideSpeed
	local state = humanoid:GetState()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Freefall
	local target: Vector3? = nil
	if grounded then
		local n = info.normal
		local vy = -(n.X * walk.X + n.Z * walk.Z) / n.Y
		target = Vector3.new(walk.X, vy, walk.Z) + push
		-- Un impulso claro hacia arriba (Salto de jaguar, empuje) cuenta como aire aunque el Humanoid aún figure en
		-- el suelo ese fotograma: si no, el modo Vector le pisaría la velocidad vertical y el salto se perdería.
		if root.AssemblyLinearVelocity.Y > target.Y + UPWARD_MARGIN then
			grounded = false
		end
	end
	if grounded and target then
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		constraint.VectorVelocity = target
	else
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		constraint.PlaneVelocity = Vector2.new(walk.X + push.X, walk.Z + push.Z)
	end
	lastActive = true
	lastGrounded = grounded
	lastSpeed = root.AssemblyLinearVelocity.Magnitude
end

-- Para pruebas: si el empuje está en marcha, si el jugador pisa el suelo y su velocidad.
function TaludSlideController.debugState(): { active: boolean, grounded: boolean, speed: number }
	return { active = lastActive, grounded = lastGrounded, speed = lastSpeed }
end

function TaludSlideController:Start()
	RunService.Heartbeat:Connect(update)
	Players.LocalPlayer.CharacterRemoving:Connect(stop)
end

return TaludSlideController
