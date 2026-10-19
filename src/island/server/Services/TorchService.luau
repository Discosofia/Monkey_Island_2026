--!strict
-- Antorcha (receta "Torch"). Es un objeto de equipo de la Bolsa ("Torch" en Data/Items, no se roba ni
-- se pierde al caer): de día se queda guardada y no se ve; al caer la noche aparece sola, encendida,
-- en la mano izquierda, sin ocupar hueco ni equiparla, y la derecha sigue con el arma. Al amanecer
-- vuelve a la Bolsa. De noche también se vuelve a poner en cada reaparición.
--   - De noche se apaga mientras el jugador está caído y durante Config.Monkeys.TorchRoarOutSeconds
--     tras el rugido de un jefe ("TorchOutUntil", BossService).
--   - Publica "TorchLit" (true/false) en el Player: MonkeyService la usa para el miedo al fuego y
--     para las especies que no atacan a quien lleva una antorcha.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)

local TORCH_ITEM = "Torch"
local TORCH_NAME = "AntorchaEnMano"
local LIT_ATTRIBUTE = "TorchLit"
local OUT_ATTRIBUTE = "TorchOutUntil"
local CHECK_SECONDS = 0.5
-- Desde la mano colgando, la antorcha apunta hacia delante y arriba (35° sobre la horizontal), como
-- quien la lleva para alumbrar el camino. Ángulo negativo en X: la punta va hacia -Z (delante).
local HAND_OFFSET = CFrame.new(0, -0.25, -0.05) * CFrame.Angles(math.rad(-55), 0, 0)

local TorchService = {}

-- Si era de noche en la última comprobación de cada jugador: para avisar solo al anochecer.
local wasNight: { [Player]: boolean } = {}

local function handOf(character: Model): BasePart?
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

-- Suelda una antorcha nueva a la mano izquierda. nil si el personaje aún no tiene mano.
local function attach(character: Model): Model?
	local hand = handOf(character)
	if not hand then
		return nil
	end
	local torch = WeaponTools.buildTorch()
	torch.Name = TORCH_NAME
	local handle = torch.PrimaryPart :: BasePart
	-- La mano agarra la antorcha por TORCH_GRIP (la empuñadura de cuero). Se mueve el modelo entero:
	-- las piezas van soldadas al Handle y se quedarían atrás si solo se moviera él.
	local offset = HAND_OFFSET * WeaponTools.TORCH_GRIP:Inverse()
	torch:PivotTo(hand.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = offset
	weld.Parent = handle
	torch.Parent = character
	return torch
end

local function setFlame(torch: Model, lit: boolean)
	if torch:GetAttribute("Lit") == lit then
		return
	end
	torch:SetAttribute("Lit", lit)
	for _, descendant in torch:GetDescendants() do
		if descendant:IsA("Fire") or descendant:IsA("Light") then
			descendant.Enabled = lit
		end
	end
end

local function isNight(): boolean
	local state = MatchState.read()
	return state ~= nil and state.phase == "Night"
end

local function update(player: Player, night: boolean)
	local character = player.Character
	local owned = Inventory.count(player, TORCH_ITEM) > 0
	local found = if character then character:FindFirstChild(TORCH_NAME) else nil
	local torch: Model? = if found and found:IsA("Model") then found else nil
	-- En la mano solo de noche; de día vuelve a la Bolsa.
	local inHand = owned and night
	if inHand and character and not torch then
		torch = attach(character)
	elseif not inHand and torch then
		torch:Destroy()
		torch = nil
	end
	if inHand and not wasNight[player] then
		Remotes.Notify:FireClient(player, "🔥 Cae la noche: tu antorcha se enciende en tu mano izquierda")
	end
	wasNight[player] = night
	local outUntil = player:GetAttribute(OUT_ATTRIBUTE)
	local out = typeof(outUntil) == "number" and Workspace:GetServerTimeNow() < outUntil
	local lit = torch ~= nil and LifeState.isAlive(player) and not out
	if torch then
		setFlame(torch, lit)
	end
	if player:GetAttribute(LIT_ATTRIBUTE) ~= lit then
		player:SetAttribute(LIT_ATTRIBUTE, lit)
	end
end

-- El rugido de un jefe apaga la antorcha unos segundos. Devuelve true si estaba encendida.
function TorchService.douse(player: Player, seconds: number): boolean
	local wasLit = player:GetAttribute(LIT_ATTRIBUTE) == true
	player:SetAttribute(OUT_ATTRIBUTE, Workspace:GetServerTimeNow() + seconds)
	update(player, isNight())
	return wasLit
end

function TorchService:Start()
	Players.PlayerRemoving:Connect(function(player)
		wasNight[player] = nil
	end)
	while true do
		local night = isNight()
		for _, player in Players:GetPlayers() do
			update(player, night)
		end
		task.wait(CHECK_SECONDS)
	end
end

return TorchService
