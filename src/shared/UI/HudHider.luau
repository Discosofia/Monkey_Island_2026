--!strict
-- Esconde la interfaz para grabar vídeos y para las cinemáticas (Fase 25): los ScreenGui del jugador (salvo
-- los que se excluyan), la CoreGui, el cursor del ratón y la interfaz del mundo: los avisos de los ProximityPrompt
-- (ProximityPromptService.Enabled), los BillboardGui que cuelgan del PlayerGui (los marcadores de estación del Lobby) o del
-- Workspace (los rótulos de las parcelas, «Free plot», «Parcela de …» y los de los tótems), y
-- los Highlight de la cámara (el contorno de las estaciones). Todo vuelve exacto al soltar la última llamada. Cuenta las llamadas: dos hide necesitan dos
-- restore, y la interfaz solo vuelve cuando se suelta la última. Sin dependencias del juego (no requiere
-- Remotes ni Settings). Solo cliente.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local HudHider = {}

local count = 0
local excluded: { [ScreenGui]: boolean } = {}
local savedGuis: { [ScreenGui]: boolean } = {}
local savedCore: { [Enum.CoreGuiType]: boolean } = {}
local savedMouseIcon = true
local savedPrompts = true
local savedBillboards: { [BillboardGui]: boolean } = {}
local savedHighlights: { [Highlight]: boolean } = {}
local connections: { RBXScriptConnection } = {}

local function hideGui(gui: ScreenGui)
	savedGuis[gui] = gui.Enabled
	gui.Enabled = false
	-- Si el juego vuelve a encender esa pantalla mientras está oculta, se apunta su estado y se vuelve a ocultar.
	table.insert(
		connections,
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if count > 0 and gui.Enabled then
				savedGuis[gui] = true
				gui.Enabled = false
			end
		end)
	)
end

-- Esconde un cartel del mundo (BillboardGui del PlayerGui) y lo vuelve a esconder si el juego lo enciende.
local function hideBillboard(gui: BillboardGui)
	if savedBillboards[gui] ~= nil then
		return
	end
	savedBillboards[gui] = gui.Enabled
	gui.Enabled = false
	table.insert(
		connections,
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if count > 0 and gui.Enabled then
				savedBillboards[gui] = true
				gui.Enabled = false
			end
		end)
	)
end

local function hideHighlight(highlight: Highlight)
	if savedHighlights[highlight] == nil then
		savedHighlights[highlight] = highlight.Enabled
		highlight.Enabled = false
	end
end

-- Oculta la interfaz. "except": pantallas que se quedan visibles (el panel de pruebas, el ScreenGui de la
-- cinemática). Las exclusiones de las llamadas anidadas se suman.
function HudHider.hide(except: { ScreenGui }?)
	for _, gui in except or {} do
		excluded[gui] = true
	end
	count += 1
	if count > 1 then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and not excluded[child] then
			hideGui(child)
		end
	end
	table.insert(
		connections,
		playerGui.ChildAdded:Connect(function(child)
			if count > 0 and child:IsA("ScreenGui") and not excluded[child] then
				hideGui(child)
			elseif count > 0 and child:IsA("BillboardGui") then
				hideBillboard(child)
			end
		end)
	)
	-- Interfaz del mundo: carteles de estación, contornos y avisos de los ProximityPrompt.
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") then
			hideBillboard(child)
		end
	end
	-- Rótulos colgados de piezas del mundo (parcelas, tótems): los que hay y los que lleguen por el streaming.
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BillboardGui") then
			hideBillboard(descendant)
		end
	end
	table.insert(
		connections,
		workspace.DescendantAdded:Connect(function(descendant)
			if count > 0 and descendant:IsA("BillboardGui") then
				hideBillboard(descendant)
			end
		end)
	)
	local camera = workspace.CurrentCamera
	if camera then
		for _, child in camera:GetChildren() do
			if child:IsA("Highlight") then
				hideHighlight(child)
			end
		end
		table.insert(
			connections,
			camera.ChildAdded:Connect(function(child)
				if count > 0 and child:IsA("Highlight") then
					hideHighlight(child)
				end
			end)
		)
	end
	savedPrompts = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	for _, item in Enum.CoreGuiType:GetEnumItems() do
		if item ~= Enum.CoreGuiType.All then
			savedCore[item] = StarterGui:GetCoreGuiEnabled(item)
		end
	end
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	savedMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = false
end

-- Suelta una llamada a hide. Con la última, deja cada cosa como estaba.
function HudHider.restore()
	if count == 0 then
		return
	end
	count -= 1
	if count > 0 then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}
	for gui, enabled in savedGuis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	savedGuis = {}
	for gui, enabled in savedBillboards do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	savedBillboards = {}
	for highlight, enabled in savedHighlights do
		if highlight.Parent then
			highlight.Enabled = enabled
		end
	end
	savedHighlights = {}
	ProximityPromptService.Enabled = savedPrompts
	for item, enabled in savedCore do
		StarterGui:SetCoreGuiEnabled(item, enabled)
	end
	savedCore = {}
	excluded = {}
	UserInputService.MouseIconEnabled = savedMouseIcon
end

function HudHider.isHidden(): boolean
	return count > 0
end

return HudHider
