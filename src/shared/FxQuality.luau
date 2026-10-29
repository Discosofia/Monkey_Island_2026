--!strict
-- Calidad de los efectos de los jefes (Fase 16, R6): "Low", "Medium" o "High". Decide cuántas piezas dibuja
-- combatClient/BossFx (Config.BossFx.Pieces y el tope Config.Budgets.Vfx). Es del cliente.
--   - El ajuste "fxQuality" (Shared/Settings) manda si es "Low", "Medium" o "High".
--   - En "Auto" se lee la calidad gráfica de Roblox (SavedQualityLevel): 1-3 bajo, 4-7 medio, 8-10 alto.
--   - Si Roblox la deja en automático (0) o no se puede leer: medio en PC y bajo en un táctil sin teclado.

local UserInputService = game:GetService("UserInputService")

export type Quality = "Low" | "Medium" | "High"

local FxQuality = {}

-- Función pura (sin Roblox), para poder probarla: "setting" es el valor de Settings.fxQuality, "savedLevel" el
-- número de SavedQualityLevel (0 = automático) y "isTouchOnly" si el dispositivo es táctil sin teclado.
function FxQuality.resolve(setting: string?, savedLevel: number?, isTouchOnly: boolean): Quality
	if setting == "Low" or setting == "Medium" or setting == "High" then
		return setting :: Quality
	end
	if savedLevel and savedLevel >= 1 then
		if savedLevel <= 3 then
			return "Low"
		elseif savedLevel <= 7 then
			return "Medium"
		end
		return "High"
	end
	return if isTouchOnly then "Low" else "Medium"
end

local function savedQualityLevel(): number?
	local ok, value = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return if ok and typeof(value) == "number" then value else nil
end

function FxQuality.get(): Quality
	-- Se pide aquí y no arriba para que resolve() se pueda usar sin esperar a los remotos de Settings.
	local Settings = require(script.Parent.Settings)
	local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return FxQuality.resolve(Settings.get().fxQuality, savedQualityLevel(), isTouchOnly)
end

return FxQuality
