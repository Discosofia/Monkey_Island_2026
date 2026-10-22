--!strict
-- Preparación de los ataques de los monos, los jefes y el muñeco de sparring (Fase 10, C6). Un ataque
-- ya no entra en el instante en que empieza: quien pega se para, se gira hacia su presa y avisa durante
-- unos segundos (Config.Windup); al acabar, el golpe solo entra si la presa sigue en la caja de delante
-- y se ve (Combat/Hitbox.visible). Así se puede esquivar, apartarse, ponerse detrás de algo, bloquear o
-- hacer parry.
--   - Atributos del modelo que dibuja cada cliente (EnemyWindupController): "WindupUntil" (hora del
--     servidor en que golpea) y "WindupKind": "Strike" ("!" y ojos que brillan) o "Unblockable" ("‼"
--     naranja: no se puede bloquear, hay que apartarse o esquivar).
--   - Un control (Status.stun: aturdir, congelar, el parry, el remate de la cadena…) durante la
--     preparación la corta: el ataque se pierde.
--   - Margen a favor del defensor (strike): al acabar espera Guard.grace(presa) (su ping, con tope) y
--     mira entonces si sigue en la caja; la guardia se resuelve con la hora del golpe (Guard.Hit.at),
--     como los golpes de arma en PvP.
-- La preparación cabe dentro de la recarga de cada ataque (quien llama la cuenta desde que empieza): el
-- daño por segundo no cambia, lo mide la sección 10 de la calculadora (Equilibrio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(script.Parent.Guard)
local Hitbox = require(script.Parent.Hitbox)

export type Kind = "Strike" | "Unblockable"

local UNTIL_ATTRIBUTE = "WindupUntil"
local KIND_ATTRIBUTE = "WindupKind"

type Pending = { ticket: number, connection: RBXScriptConnection }

local EnemyAttack = {}

local pending: { [Model]: Pending } = {}
local tickets = 0

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(model: Model?): BasePart?
	local root = if model then model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function clear(model: Model)
	local entry = pending[model]
	if entry then
		entry.connection:Disconnect()
		pending[model] = nil
	end
	model:SetAttribute(UNTIL_ATTRIBUTE, nil)
	model:SetAttribute(KIND_ATTRIBUTE, nil)
end

-- true mientras "model" se prepara para golpear: quien llama lo deja quieto y no empieza otro ataque.
function EnemyAttack.busy(model: Model): boolean
	return pending[model] ~= nil
end

-- Corta la preparación en curso (el ataque se pierde).
function EnemyAttack.cancel(model: Model)
	if pending[model] then
		clear(model)
	end
end

-- Gira "model" hacia "position" (en horizontal). Los anclados (el muñeco) giran con PivotTo.
function EnemyAttack.face(model: Model, position: Vector3)
	local root = rootOf(model)
	if not root then
		return
	end
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude < 0.1 then
		return
	end
	local facing = CFrame.lookAt(root.Position, flat)
	if root.Anchored then
		model:PivotTo(facing * root.CFrame:ToObjectSpace(model:GetPivot()))
	else
		root.CFrame = facing
	end
end

-- Empieza la preparación de "model": avisa "seconds" segundos y después llama a "strike". No empieza si
-- ya se está preparando (devuelve false). Un control mientras tanto la corta, y si muere no golpea.
function EnemyAttack.windup(model: Model, seconds: number, kind: Kind, strike: () -> ()): boolean
	if pending[model] then
		return false
	end
	tickets += 1
	local ticket = tickets
	pending[model] = {
		ticket = ticket,
		connection = model:GetAttributeChangedSignal("StunnedUntil"):Connect(function()
			EnemyAttack.cancel(model)
		end),
	}
	model:SetAttribute(KIND_ATTRIBUTE, kind)
	model:SetAttribute(UNTIL_ATTRIBUTE, now() + seconds)
	task.delay(seconds, function()
		local entry = pending[model]
		if not entry or entry.ticket ~= ticket then
			return
		end
		clear(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if model.Parent and humanoid and humanoid.Health > 0 then
			strike()
		end
	end)
	return true
end

-- true si "player" está en la caja del golpe de "model" (delante, Config.Windup) y se le ve desde su raíz.
-- "range": su alcance en studs.
function EnemyAttack.reaches(model: Model, player: Player, range: number): boolean
	local settings = Config.Windup
	local root = rootOf(model)
	local character = player.Character
	if not (root and character) then
		return false
	end
	local length = range + settings.ReachMargin
	local size = Vector3.new(range * settings.HitWidthFactor, math.max(settings.HitHeight, range), length)
	local box = root.CFrame * CFrame.new(0, 0, -length / 2)
	overlapParams.FilterDescendantsInstances = { character }
	if #Workspace:GetPartBoundsInBox(box, size, overlapParams) == 0 then
		return false
	end
	return Hitbox.visible(root.Position, character)
end

-- El golpe de "model" a "player" al acabar la preparación: espera el margen del defensor y, si sigue a
-- su alcance ("range"), llama a "land" con el golpe listo para la guardia ("hit": Guard.enemyHit con la
-- hora del golpe; "unblockable" lo marca como imbloqueable). Si se ha apartado, llama a "miss".
function EnemyAttack.strike(
	model: Model,
	player: Player,
	range: number,
	land: (hit: Guard.Hit) -> (),
	miss: (() -> ())?,
	unblockable: boolean?
)
	local hit = Guard.enemyHit(model)
	hit.at = now()
	hit.unblockable = unblockable
	local function resolve()
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if model.Parent and humanoid and humanoid.Health > 0 and EnemyAttack.reaches(model, player, range) then
			land(hit)
		elseif miss then
			miss()
		end
	end
	local wait = Guard.grace(player)
	if wait > 0 then
		task.delay(wait, resolve)
	else
		resolve()
	end
end

return EnemyAttack
