--!strict
-- Idioma de la interfaz en el cliente (Shared/Strings, GDD §18). Lo arranca el init.client de cada place.
--   1. Quita la traducción automática de Roblox (AutoLocalize) de toda la interfaz propia y de los carteles
--      del mundo: la traducimos nosotros, y así la nube no captura frases españolas como si fueran del
--      idioma de origen (el inglés).
--   2. Traduce los carteles del mundo (BillboardGui y SurfaceGui de LobbyBuilder, ArenaBuilder…) cuyo
--      texto sea una frase de las tablas: guarda el español en el atributo "SourceText".
--   3. Traduce los ProximityPrompt (ActionText y ObjectText fijos del servidor) cuando salen, con el
--      español guardado en los atributos "SourceAction" y "SourceObject".
--   4. Traduce las herramientas de la mochila (las crea el servidor en español): su nombre, que enseña
--      la barra de Roblox, y lo que dicen al pasar por encima (las armas, con WeaponTools.tooltip).
--   5. Al cambiar de idioma, vuelve a traducir los textos fijos de la interfaz y los carteles. Los que
--      llevan números se rehacen solos la próxima vez que su módulo los actualiza.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Strings = require(script.Parent.Parent.Strings)

local Localizer = {}

local SOURCE_ATTRIBUTE = "SourceText"

local function isText(instance: Instance): boolean
	return instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")
end

local function quiet(instance: Instance)
	if instance:IsA("GuiBase2d") then
		instance.AutoLocalize = false
	end
end

-- Un texto del mundo: se recuerda su español y se pone en el idioma del jugador.
local function localizeWorldText(label: TextLabel | TextButton | TextBox)
	local source = label:GetAttribute(SOURCE_ATTRIBUTE)
	if typeof(source) ~= "string" then
		source = Strings.source(label.Text)
		if not source then
			return
		end
		label:SetAttribute(SOURCE_ATTRIBUTE, source)
	end
	label.Text = Strings.t(source :: string)
end

-- Un texto de un ProximityPrompt ("ActionText" u "ObjectText").
local function localizePrompt(prompt: ProximityPrompt, property: "ActionText" | "ObjectText")
	local attribute = if property == "ActionText" then "SourceAction" else "SourceObject"
	-- El texto de ahora manda (el servidor puede haberlo cambiado); el guardado sirve si ya está traducido
	-- por la nube y no se puede volver al español.
	local source = Strings.source((prompt :: any)[property]) or prompt:GetAttribute(attribute)
	if typeof(source) ~= "string" then
		return
	end
	prompt:SetAttribute(attribute, source);
	(prompt :: any)[property] = Strings.t(source)
end

-- Una herramienta de la mochila o de la mano. Su nombre español queda en el atributo "SourceName".
local function localizeTool(tool: Instance)
	if not tool:IsA("Tool") then
		return
	end
	local name = Strings.source(tool.Name) or tool:GetAttribute("SourceName")
	if typeof(name) == "string" then
		tool:SetAttribute("SourceName", name)
		tool.Name = Strings.t(name)
	end
	local weaponId = tool:GetAttribute("WeaponId")
	if typeof(weaponId) == "string" then
		-- Solo se carga si hace falta: es un módulo grande y el Lobby casi nunca da armas.
		local WeaponTools = require(script.Parent.Parent.WeaponTools) :: any
		tool.ToolTip = WeaponTools.tooltip(weaponId)
	else
		local tip = Strings.source(tool.ToolTip) or tool:GetAttribute("SourceTip")
		if typeof(tip) == "string" then
			tool:SetAttribute("SourceTip", tip)
			tool.ToolTip = Strings.t(tip)
		end
	end
end

local function watchTools(player: Player)
	local function watch(container: Instance)
		for _, child in container:GetChildren() do
			localizeTool(child)
		end
		container.ChildAdded:Connect(localizeTool)
	end
	watch(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	-- La mochila se rehace al reaparecer.
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
end

local function onWorldDescendant(instance: Instance)
	if instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
		quiet(instance)
	elseif isText(instance) and instance:FindFirstAncestorWhichIsA("LayerCollector") then
		quiet(instance)
		localizeWorldText(instance :: any)
	end
end

local function retranslate(root: Instance, world: boolean)
	for _, instance in root:GetDescendants() do
		if isText(instance) then
			local label = instance :: TextLabel
			if world then
				if label:FindFirstAncestorWhichIsA("LayerCollector") then
					localizeWorldText(label)
				end
			else
				local source = Strings.source(label.Text)
				if source then
					label.Text = Strings.t(source)
				end
			end
		end
	end
end

function Localizer.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, instance in playerGui:GetDescendants() do
		quiet(instance)
	end
	playerGui.DescendantAdded:Connect(quiet)

	for _, instance in workspace:GetDescendants() do
		onWorldDescendant(instance)
	end
	workspace.DescendantAdded:Connect(onWorldDescendant)

	task.spawn(watchTools, Players.LocalPlayer)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		prompt.AutoLocalize = false
		localizePrompt(prompt, "ActionText")
		localizePrompt(prompt, "ObjectText")
	end)

	Strings.onChanged(function()
		retranslate(playerGui, false)
		retranslate(workspace, true)
		local player = Players.LocalPlayer
		for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
			for _, child in (container :: Instance):GetChildren() do
				localizeTool(child)
			end
		end
	end)
end

return Localizer
