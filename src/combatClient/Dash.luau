--!strict
-- Impulso horizontal de un instante (esquiva y Embestida) sin que el personaje salga dando vueltas.
--   - Fuerza limitada: con MaxForce = math.huge, al chocar contra una pared (sobre todo saltando)
--     la física separaba las piezas de golpe y el personaje salía volando y girando.
--   - El empuje se corta en cuanto hay una pared delante (pieza anclada o terreno; no monos ni
--     jugadores, que la Embestida tiene que alcanzar) y al terminar se le quita el giro que haya cogido.
--   - Dash.pushWithCarry (la esquiva y el Evasivo, Fase 15, V3): al terminar el empuje por tiempo sigue otro a
--     una fracción de la velocidad que baja a 0, con un solo manejador. Contra una pared no hay segundo.
--   - El Humanoid del jugador no puede caerse ni quedar como un muñeco (FallingDown y Ragdoll
--     desactivados): siempre se endereza.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Aceleración máxima del empuje (studs/s²): llega a su velocidad en un par de fotogramas.
local MAX_ACCELERATION = 3000
-- Distancia del centro del cuerpo a la pared a la que se corta el empuje.
local STOP_DISTANCE = 2.5

-- Lo que devuelve push: cancelarlo antes de tiempo, saber si sigue, y su velocidad de ahora.
export type Handle = {
	cancel: () -> (),
	active: () -> boolean,
	speed: () -> number,
}

local Dash = {}

local function isWall(instance: Instance): boolean
	return instance:IsA("Terrain") or (instance:IsA("BasePart") and instance.Anchored)
end

-- Empuja "root" hacia "direction" (se aplana) a "speed" studs/s durante "seconds". La gravedad sigue
-- actuando. Con "endSpeed" la velocidad baja (o sube) en línea recta hasta ella al terminar (el
-- deslizamiento); sin él es constante (la esquiva y la Embestida). Devuelve un manejador, o nil si no
-- se pudo empujar.
-- "onTimeout" se llama si el empuje acaba por tiempo (no por pared, cancel ni por perder el personaje).
local function start(
	root: BasePart,
	direction: Vector3,
	speed: number,
	seconds: number,
	endSpeed: number?,
	onTimeout: (() -> ())?
): Handle?
	local attachment = root:FindFirstChild("RootAttachment")
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if not (attachment and attachment:IsA("Attachment")) or horizontal.Magnitude < 0.01 then
		return nil
	end
	horizontal = horizontal.Unit
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = root.AssemblyMass * MAX_ACCELERATION
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(horizontal.X, horizontal.Z) * speed
	push.Parent = root

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	params.RespectCanCollide = true
	local startedAt = os.clock()
	local finish = startedAt + seconds
	local current = speed
	local running = true
	local connection: RBXScriptConnection
	local function stop(blocked: boolean)
		if not running then
			return
		end
		running = false
		connection:Disconnect()
		push:Destroy()
		if blocked then
			-- Contra la pared se queda la caída, no el empuje.
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		root.AssemblyAngularVelocity = Vector3.zero
	end
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if endSpeed then
			current = speed + (endSpeed - speed) * math.clamp((os.clock() - startedAt) / seconds, 0, 1)
			push.PlaneVelocity = Vector2.new(horizontal.X, horizontal.Z) * current
		end
		local hit = Workspace:Raycast(root.Position, horizontal * (STOP_DISTANCE + current * deltaTime), params)
		local blocked = hit ~= nil and isWall(hit.Instance)
		if blocked or os.clock() >= finish or root.Parent == nil then
			local wasRunning = running
			stop(blocked)
			if wasRunning and not blocked and root.Parent ~= nil and onTimeout then
				onTimeout()
			end
		end
	end)
	return {
		cancel = function()
			stop(false)
		end,
		active = function()
			return running
		end,
		speed = function()
			return current
		end,
	}
end

function Dash.push(root: BasePart, direction: Vector3, speed: number, seconds: number, endSpeed: number?): Handle?
	return start(root, direction, speed, seconds, endSpeed, nil)
end

-- Como push, pero al terminar el empuje por tiempo sigue un segundo empuje a speed × keep que baja en
-- línea recta hasta 0 en "carrySeconds" (la esquiva no frena en seco). Contra una pared se corta y no hay
-- segundo empuje. El manejador es uno solo: cancel corta las dos fases, active es true mientras dure
-- cualquiera y speed da la de ahora.
function Dash.pushWithCarry(
	root: BasePart,
	direction: Vector3,
	speed: number,
	seconds: number,
	keep: number,
	carrySeconds: number
): Handle?
	local current: Handle? = nil
	local cancelled = false
	local finished = false
	local first = start(root, direction, speed, seconds, nil, function()
		if cancelled then
			return
		end
		current = start(root, direction, speed * keep, carrySeconds, 0, nil)
		finished = current == nil
	end)
	if not first then
		return nil
	end
	current = first
	return {
		cancel = function()
			cancelled = true
			if current then
				current.cancel()
			end
		end,
		active = function()
			return not cancelled and not finished and current ~= nil and current.active()
		end,
		speed = function()
			return if current then current.speed() else 0
		end,
	}
end

local function keepUpright(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end
end

-- El personaje del jugador local siempre se endereza (lo llama DodgeController al arrancar).
function Dash.keepUpright()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(keepUpright, player.Character)
	end
	player.CharacterAdded:Connect(keepUpright)
end

return Dash
