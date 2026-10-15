--!strict
-- Al llegar al Lobby después de jugar, pide una sola cosa por visita (unos segundos después de llegar):
--   - Marcar el juego como favorito, tras las partidas de Config.Social.FavoritePromptMatches y solo si
--     aún no lo es (los favoritos ayudan a que Roblox recomiende el juego).
--   - Si no, activar las notificaciones del juego (desde NotificationPromptMinMatches partidas). Roblox
--     decide si se puede mostrar: solo a mayores de 13, una vez cada 30 días y si aún no las tiene.
-- Ninguna de las dos es obligatoria para jugar.

local AvatarEditorService = game:GetService("AvatarEditorService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local SocialPromptsController = {}

local function isFavorite(): boolean?
	local ok, favorite = pcall(function()
		return AvatarEditorService:GetFavoriteAsync(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	return if ok then favorite == true else nil
end

local function promptFavorite(matches: number): boolean
	if not table.find(Config.Social.FavoritePromptMatches, matches) then
		return false
	end
	-- Si no se puede saber (falla la consulta), mejor no molestar.
	if isFavorite() ~= false then
		return false
	end
	local ok = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	return ok
end

local function promptNotifications(matches: number)
	if matches < Config.Social.NotificationPromptMinMatches then
		return
	end
	local ok, canPrompt = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if ok and canPrompt then
		ExperienceNotificationService:PromptOptIn()
	end
end

function SocialPromptsController:Start()
	if RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	-- Espera a que lleguen los datos guardados (el atributo "Progress" lo pone el servidor).
	while player:GetAttribute("Progress") == nil do
		player:GetAttributeChangedSignal("Progress"):Wait()
	end
	local matches = Progression.read(player).matches
	if matches < 1 then
		return
	end
	task.wait(Config.Social.PromptDelaySeconds)
	if not promptFavorite(matches) then
		promptNotifications(matches)
	end
end

return SocialPromptsController
