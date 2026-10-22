--!strict
-- Rol del jugador local en la Isla (Fase 3):
--   - 5 habilidades (Data/Roles): Z, X, C y R las activas y V la definitiva. Con mando, mantén R1 y
--     pulsa A, B, X, Y o L1. En móvil, un bloque de 5 botones junto al salto. Bajo las barras de
--     supervivencia, una casilla por habilidad (en el orden Z X C R V) dice cuándo vuelve a estar lista.
--     La R no es la E porque la E es la de los avisos (recoger, reanimar, fabricar…).
--   - Los movimientos los hace este cliente (es quien mueve al personaje): la Embestida empuja hacia
--     delante, el Parpadeo teletransporta, el Torbellino hace girar al guerrero y el Rompehuesos lo
--     vuelve hacia donde apuntas. El resto lo aplica
--     el servidor (AbilityService). Sus efectos (rastro rojo, estelas de viento, punto negro y chispa)
--     se dibujan aquí al momento con AbilityFxController; a los demás se los manda el servidor.
--   - Avisos más rápidos según sus ventajas: "Reanimar" (médico) y recolectar (mejora de la tienda).
--   - Médico: ve una barra de vida sobre la cabeza de cada aliado.
--   - La casilla del siguiente paso del combo (Data/Combos) se resalta en azul.
--   - Con el atributo "MovementLocked" (en la arena, quien lleva la bandera rival) no se pueden usar
--     la Embestida ni el Parpadeo.
--   - Preparación (Fase 10, C8): el gesto sale al pulsar y la habilidad al acabar su "castSeconds"
--     (Data/Roles); el movimiento propio (la Embestida, el giro del Torbellino) también espera a ese
--     momento, como el servidor. Pulsar la guardia mientras tanto es un amago (CombatClient/Feint): se
--     para el gesto y no sale. Si le aturden antes, tampoco. El Parpadeo no lleva preparación: se
--     teletransporta al pulsar y manda desde dónde y hasta dónde.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local AbilityFxController = require(script.Parent.AbilityFxController)
local ComboController = require(script.Parent.ComboController)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local Aim = require(script.Parent.Parent.Aim)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)
local Dash = require(script.Parent.Parent.Dash)
local Feint = require(script.Parent.Parent.Feint)

-- Una por hueco de Data/Roles (el 4 es la definitiva; el 5, la cuarta activa).
local KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V, Enum.KeyCode.R }
local KEY_NAMES = { "Z", "X", "C", "V", "R" }
-- Orden de las casillas: las activas seguidas y la definitiva al final (Z X C R V).
local HUD_ORDER = { 1, 2, 3, 5, 4 }
-- Con mando: mantener R1 cambia A, B, X, Y y L1 por las 5 habilidades.
local PAD_BUTTONS = {
	Enum.KeyCode.ButtonA,
	Enum.KeyCode.ButtonB,
	Enum.KeyCode.ButtonX,
	Enum.KeyCode.ButtonY,
	Enum.KeyCode.ButtonL1,
}
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
	-- Con un kit de reanimación (del médico) basta con pulsar; el servidor lo gasta (LifeService).
	if prompt.Name == "RevivePrompt" then
		local kit = Inventory.count(player, "ReviveKit") > 0
		if kit then
			prompt.HoldDuration = Config.Life.ReviveKitHoldSeconds
		end
		prompt.ActionText = if kit then "Reanimar con kit" else "Reanimar"
	end
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
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	local settings = Config.Abilities
	Dash.push(root, direction, settings.ChargeDistance / settings.ChargeSeconds, settings.ChargeSeconds)
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

-- Torbellino: el personaje gira sobre sí mismo mientras dura, agachado y con los brazos abiertos
-- (animación "Whirlwind" en bucle, Data/PlayerAnimations).
local function spin(humanoid: Humanoid, root: BasePart, seconds: number)
	humanoid.AutoRotate = false
	BodyAnimations.play("Whirlwind")
	local finish = os.clock() + seconds
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if os.clock() >= finish or not root.Parent then
			connection:Disconnect()
			humanoid.AutoRotate = true
			BodyAnimations.stop("Whirlwind")
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
	-- Aturdido no se usan habilidades (Shared/CombatState; el servidor lo comprueba otra vez), ni
	-- mientras se prepara otra.
	if not CombatState.canAct(player, "Ability") or Feint.casting() then
		return
	end
	if os.clock() - (lastSentAt[slot] or -math.huge) < 0.5 then
		return
	end
	if (ability.id == "Charge" or ability.id == "Blink") and player:GetAttribute("MovementLocked") == true then
		Toast.show(`🚩 Con la bandera no puedes usar {ability.name}`)
		return
	end
	local aim = Aim.direction(character)
	local castSeconds = ability.castSeconds or Config.Windup.AbilityDefaultSeconds
	-- Desde dónde y hasta dónde va el Parpadeo, para que los demás vean su efecto.
	local from, to = nil, nil
	-- Lo que mueve al personaje: sale a la vez que la habilidad en el servidor.
	local release: (() -> ())? = nil
	if ability.id == "Charge" then
		release = function()
			charge(root, flat(aim))
			AbilityFxController.play("Charge", character, Config.Abilities.ChargeSeconds)
		end
	elseif ability.id == "Blink" then
		from = root.Position
		if not blink(character, root, flat(aim), Progression.perk(player, "BlinkDistance")) then
			return
		end
		to = root.Position
		AbilityFxController.play("Blink", from, to)
	elseif ability.id == "Whirlwind" then
		local seconds = Progression.perk(player, "WhirlwindSeconds")
		-- Si cierra el combo del guerrero, gira más rato (lo mismo que decide AbilityService).
		if ComboController.nextStep(player) == "Whirlwind" then
			seconds += Config.Combo.WhirlwindExtraSeconds
		end
		-- Agachado y con los brazos abiertos desde que se pulsa; gira al salir.
		BodyAnimations.play("Whirlwind")
		release = function()
			spin(humanoid, root, seconds)
			AbilityFxController.play("Whirlwind", character, seconds)
		end
	elseif ability.id == "Smash" then
		-- El golpe va al cono de delante: se vuelve hacia donde apunta.
		local facing = flat(aim)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
	end
	-- Gesto del cuerpo (pisotón, lanzar, agacharse…), si la habilidad tiene (Data/PlayerAnimations),
	-- con su golpe al acabar la preparación.
	BodyAnimations.playAbility(ability.id, castSeconds)
	lastSentAt[slot] = os.clock()
	Remotes.UseAbility:FireServer(slot, aim, from, to)
	if castSeconds <= 0 then
		if release then
			release()
		end
		return
	end
	local feinted = false
	local mark = Feint.begin("Ability", castSeconds, function()
		feinted = true
		BodyAnimations.stopAbility(ability.id)
		if ability.id == "Whirlwind" then
			BodyAnimations.stop("Whirlwind")
		end
	end)
	task.delay(castSeconds, function()
		Feint.finish(mark)
		-- Amagada, o le han aturdido o tambaleado mientras: en el servidor tampoco sale.
		local state = CombatState.get(player)
		local cut = feinted
			or not LifeState.isAlive(player)
			or not (state == "Casting" or state == "Idle" or state == "Attacking")
		if cut then
			if ability.id == "Whirlwind" and not feinted then
				BodyAnimations.stop("Whirlwind")
			end
			return
		end
		if release then
			release()
		end
	end)
end

-- Casillas de las habilidades bajo las barras de supervivencia.
local function buildHud(player: Player): { { frame: Frame, name: TextLabel, timer: TextLabel, stroke: UIStroke } }
	local gui = Widgets.screen("RoleHUD", player:WaitForChild("PlayerGui"))
	local row = Instance.new("Frame")
	row.Name = "Abilities"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(12, 118)
	row.Size = UDim2.fromOffset(#KEYS * 66, 46)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local slots = {}
	for slot = 1, #KEYS do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = HUD_ORDER[slot]
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
			hud[slot].name.Text = ability.short
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
			-- El siguiente paso del combo en marcha (ComboController) se resalta en azul.
			local comboNext = ComboController.nextStep(player)
			for slot, ability in role.abilities do
				local remaining = readyIn(player, slot)
				local cell = hud[slot]
				local ready = remaining <= 0
				local isNext = ability.id == comboNext
				cell.stroke.Color = if isNext
					then Color3.fromRGB(120, 230, 255)
					elseif ability.ultimate then Color3.fromRGB(255, 200, 60)
					else Color3.fromRGB(200, 200, 200)
				cell.stroke.Thickness = if isNext then 3 else 2
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
