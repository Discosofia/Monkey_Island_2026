--!strict
-- Rol del jugador local en la Isla (Fase 3):
--   - 4 habilidades (Data/Roles): Z, X y C las activas y V la definitiva. Con mando, mantén R1 y pulsa
--     A, B, X o Y. En móvil, un bloque de 4 botones junto al salto. Bajo las barras de supervivencia,
--     una casilla por habilidad dice cuándo vuelve a estar lista.
--   - Los movimientos los hace este cliente (es quien mueve al personaje): la Embestida empuja hacia
--     delante, el Parpadeo teletransporta y el Torbellino hace girar al guerrero. El resto lo aplica
--     el servidor (AbilityService).
--   - Avisos más rápidos según sus ventajas: "Reanimar" (médico) y recolectar (mejora de la tienda).
--   - Médico: ve una barra de vida sobre la cabeza de cada aliado.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local Aim = require(script.Parent.Parent.Aim)

local KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local KEY_NAMES = { "Z", "X", "C", "V" }
-- Con mando: mantener R1 cambia A, B, X e Y por las 4 habilidades.
local PAD_BUTTONS = { Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY }
local PAD_MODIFIER = "AbilityModifier"
local PAD_ACTION = "AbilityPad"
-- Avisos cuyo tiempo de mantener depende de una ventaja del jugador.
local PROMPT_PERKS: { [string]: string } = {
	RevivePrompt = "ReviveSpeed",
	HarvestPrompt = "HarvestSpeed",
}

local RoleController = {}

-- Último envío de cada hueco: evita mandar dos veces antes de que llegue el tiempo de espera.
local lastSentAt: { [number]: number } = {}

local function adjustPrompt(player: Player, prompt: ProximityPrompt)
	local perk = PROMPT_PERKS[prompt.Name]
	if not perk then
		return
	end
	local base = prompt:GetAttribute("BaseHold")
	if typeof(base) ~= "number" then
		base = prompt.HoldDuration
		prompt:SetAttribute("BaseHold", base)
	end
	prompt.HoldDuration = (base :: number) * Progression.perk(player, perk)
end

-- Barras de vida de los aliados (solo el médico).
local function healthBars(player: Player)
	local bars: { [Player]: BillboardGui } = {}
	while true do
		local show = Progression.perk(player, "SeeHealth") > 0
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local head = if character then character:FindFirstChild("Head") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local bar = bars[other]
			if other == player or not show or not (head and humanoid) then
				if bar then
					bar:Destroy()
					bars[other] = nil
				end
			else
				if not bar or bar.Parent ~= head then
					if bar then
						bar:Destroy()
					end
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "AllyHealth"
					billboard.Size = UDim2.fromOffset(70, 8)
					billboard.StudsOffset = Vector3.new(0, 2.6, 0)
					billboard.AlwaysOnTop = true
					billboard.MaxDistance = 120
					local back = Instance.new("Frame")
					back.Size = UDim2.fromScale(1, 1)
					back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					back.Parent = billboard
					local fill = Instance.new("Frame")
					fill.Name = "Fill"
					fill.BackgroundColor3 = Color3.fromRGB(110, 230, 120)
					fill.BorderSizePixel = 0
					fill.Parent = back
					billboard.Parent = head
					bars[other] = billboard
					bar = billboard
				end
				local fill = (bar :: any).Frame.Fill :: Frame
				fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
			end
		end
		for other, bar in bars do
			if not other.Parent then
				bar:Destroy()
				bars[other] = nil
			end
		end
		task.wait(0.25)
	end
end

local function flat(vector: Vector3): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 0.01 then horizontal.Unit else Vector3.zAxis
end

-- Embestida: empuje horizontal hacia donde apuntas durante un instante.
local function charge(root: BasePart, direction: Vector3)
	local attachment = root:FindFirstChild("RootAttachment")
	if not (attachment and attachment:IsA("Attachment")) then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	local settings = Config.Abilities
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = math.huge
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(direction.X, direction.Z) * (settings.ChargeDistance / settings.ChargeSeconds)
	push.Parent = root
	task.delay(settings.ChargeSeconds, function()
		push:Destroy()
	end)
end

-- Parpadeo: salta hasta "distance" studs, parando antes de una pared y solo si hay suelo debajo.
-- Devuelve false si no hay adónde ir (y entonces no se gasta la habilidad).
local function blink(character: Model, root: BasePart, direction: Vector3, distance: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local wall = Workspace:Raycast(root.Position, direction * distance, params)
	local reach = if wall then math.max(0, (wall.Position - root.Position).Magnitude - 2) else distance
	if reach < 3 then
		return false
	end
	local destination = root.Position + direction * reach
	local startGround = Workspace:Raycast(root.Position, Vector3.new(0, -50, 0), params)
	local endGround = Workspace:Raycast(destination + Vector3.new(0, 8, 0), Vector3.new(0, -60, 0), params)
	if not (startGround and endGround) then
		return false
	end
	local height = root.Position.Y - startGround.Position.Y
	local target = Vector3.new(destination.X, endGround.Position.Y + height, destination.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(target, target + direction)
	return true
end

-- Torbellino: el personaje gira sobre sí mismo mientras dura.
local function spin(humanoid: Humanoid, root: BasePart, seconds: number)
	humanoid.AutoRotate = false
	local finish = os.clock() + seconds
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if os.clock() >= finish or not root.Parent then
			connection:Disconnect()
			humanoid.AutoRotate = true
			return
		end
		root.CFrame *= CFrame.Angles(0, deltaTime * math.rad(900), 0)
	end)
end

local function readyIn(player: Player, slot: number): number
	local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
	return if typeof(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
end

local function useAbility(player: Player, slot: number)
	local roleId = player:GetAttribute("Role")
	local role = if typeof(roleId) == "string" then Roles[roleId] else nil
	local ability = if role then role.abilities[slot] else nil
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (ability and character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if not LifeState.isAlive(player) or readyIn(player, slot) > 0 then
		return
	end
	if os.clock() - (lastSentAt[slot] or -math.huge) < 0.5 then
		return
	end
	local aim = Aim.direction(character)
	if ability.id == "Charge" then
		charge(root, flat(aim))
	elseif ability.id == "Blink" then
		if not blink(character, root, flat(aim), Progression.perk(player, "BlinkDistance")) then
			return
		end
	elseif ability.id == "Whirlwind" then
		spin(humanoid, root, Progression.perk(player, "WhirlwindSeconds"))
	end
	lastSentAt[slot] = os.clock()
	Remotes.UseAbility:FireServer(slot, aim)
end

-- Casillas de las habilidades bajo las barras de supervivencia.
local function buildHud(player: Player): { { frame: Frame, name: TextLabel, timer: TextLabel, stroke: UIStroke } }
	local gui = Widgets.screen("RoleHUD", player:WaitForChild("PlayerGui"))
	local row = Instance.new("Frame")
	row.Name = "Abilities"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(12, 118)
	row.Size = UDim2.fromOffset(4 * 66, 46)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local slots = {}
	for slot = 1, 4 do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = slot
		frame.Size = UDim2.fromOffset(60, 46)
		frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		frame.BackgroundTransparency = 0.35
		frame.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = frame

		local key = Widgets.label(KEY_NAMES[slot], frame)
		key.Position = UDim2.fromOffset(4, 2)
		key.Size = UDim2.fromOffset(14, 14)
		key.TextXAlignment = Enum.TextXAlignment.Left
		key.TextColor3 = Color3.fromRGB(255, 220, 120)
		local name = Widgets.label("", frame)
		name.Position = UDim2.fromOffset(3, 16)
		name.Size = UDim2.new(1, -6, 0, 14)
		local timer = Widgets.label("", frame)
		timer.Position = UDim2.fromOffset(3, 30)
		timer.Size = UDim2.new(1, -6, 0, 13)
		table.insert(slots, { frame = frame, name = name, timer = timer, stroke = stroke })
	end
	return slots
end

local function bindPad(player: Player)
	ContextActionService:BindAction(PAD_MODIFIER, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			-- Prioridad alta: mientras se mantiene R1, A no salta y B no esquiva.
			ContextActionService:BindActionAtPriority(PAD_ACTION, function(_, padState, input: InputObject)
				local slot = table.find(PAD_BUTTONS, input.KeyCode)
				if padState == Enum.UserInputState.Begin and slot then
					useAbility(player, slot)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, table.unpack(PAD_BUTTONS))
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			ContextActionService:UnbindAction(PAD_ACTION)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonR1)
end

function RoleController:Start()
	local player = Players.LocalPlayer

	ProximityPromptService.PromptShown:Connect(function(prompt)
		adjustPrompt(player, prompt)
	end)

	local hud = buildHud(player)
	local shownRole: string? = nil
	local function bindRole(role: Roles.Role)
		for slot, ability in role.abilities do
			ActionButtons.bind(`Ability{slot}`, ability.short, function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					useAbility(player, slot)
				end
				return Enum.ContextActionResult.Sink
			end, KEYS[slot])
			local cell = hud[slot]
			cell.name.Text = ability.short
			cell.stroke.Color = if ability.ultimate then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(200, 200, 200)
		end
	end
	bindPad(player)

	task.spawn(healthBars, player)
	while true do
		local roleId = player:GetAttribute("Role")
		local role = if typeof(roleId) == "string" then Roles[roleId] else nil
		if role and roleId ~= shownRole then
			shownRole = roleId :: string
			bindRole(role)
		end
		if role then
			for slot, ability in role.abilities do
				local remaining = readyIn(player, slot)
				local cell = hud[slot]
				local ready = remaining <= 0
				cell.timer.Text = if ready then "lista" else `{math.ceil(remaining)} s`
				cell.timer.TextColor3 = if ready then Color3.fromRGB(140, 240, 140) else Color3.fromRGB(180, 180, 180)
				cell.frame.BackgroundTransparency = if ready then 0.35 else 0.6
				ActionButtons.setTitle(`Ability{slot}`, if ready then ability.short else `{math.ceil(remaining)}`)
			end
		end
		task.wait(0.2)
	end
end

return RoleController
