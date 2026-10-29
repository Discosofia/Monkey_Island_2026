--!strict
-- Confirmación de impacto (Fase 19, W3): avisa SOLO al tirador de que su disparo ha acertado, para que su
-- cliente dibuje el hitmarker y suene el golpe (CombatClient/HitFeedbackController). Sin agrupar y sin esperar
-- a los números de combate (Combat/CombatText), que van en lotes.
--   HitFeedback.send(tirador, kind, posición, idDelArma)
-- "kind": "Body" (cuerpo), "Head" (cabeza), "Limb" y "Weak" (zonas por piezas, W6), "Kill" (el golpe derriba)
-- o "Blocked" (la guardia o el parry lo anulan). Tope de un aviso cada Config.HitFeedback.MinIntervalSeconds
-- por tirador, salvo "Kill", que siempre pasa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Kind = "Body" | "Head" | "Limb" | "Weak" | "Kill" | "Blocked"

local HitFeedback = {}

-- Cuándo (os.clock) salió el último aviso de cada tirador.
local lastSentAt: { [Player]: number } = {}

function HitFeedback.send(attacker: Player, kind: Kind, position: Vector3, weaponId: string?)
	local now = os.clock()
	if kind ~= "Kill" then
		local last = lastSentAt[attacker]
		if last and now - last < Config.HitFeedback.MinIntervalSeconds then
			return
		end
	end
	lastSentAt[attacker] = now
	Remotes.HitFeedback:FireClient(attacker, kind, position, weaponId or "")
end

Players.PlayerRemoving:Connect(function(player)
	lastSentAt[player] = nil
end)

return HitFeedback
