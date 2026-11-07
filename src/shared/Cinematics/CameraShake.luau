--!strict
-- Temblor de cámara de las cinemáticas (Fase 25). CameraShake.install(Sequencer) registra el evento
--   shake { amp, seconds, hz? }   sacude la cámara de la escena "seconds" segundos con hasta "amp" studs (ruido suave a "hz"
--                                 sacudidas por segundo, 14 por defecto) y una caída hasta cero.
-- Se aplica con una función por cuadro (ctx.frameHooks), que el Sequencer llama DESPUÉS de colocar la cámara en el cuadro:
-- el desplazamiento se suma al CFrame de ese cuadro y nunca se acumula, así que al acabar o saltar la escena no queda
-- nada descolocado. Es del reloj de la escena: con seek (ctx.seeking) el evento se ignora, y una sacudida a medias no
-- se dibuja si se salta hacia atrás.

local Workspace = game:GetService("Workspace")

local Sequencer = require(script.Parent.Sequencer)

local CameraShake = {}

local DEFAULT_HZ = 14
local DECAY_POWER = 2 -- la amplitud cae como (1 - u)^2: fuerte al principio y suave al final

type Shake = { t0: number, amp: number, seconds: number, hz: number, seed: number }

-- Desplazamiento (en el marco de la cámara) de las sacudidas vivas en el segundo t de la escena.
local function offsetAt(shakes: { Shake }, t: number): Vector3
	local total = Vector3.zero
	for _, shake in shakes do
		local u = (t - shake.t0) / shake.seconds
		if u >= 0 and u < 1 then
			local power = shake.amp * (1 - u) ^ DECAY_POWER * 2 -- math.noise da más o menos de -0,5 a 0,5
			local x = t * shake.hz
			total += Vector3.new(
				math.noise(x, shake.seed, 0) * power,
				math.noise(x, shake.seed, 10) * power,
				math.noise(x, shake.seed, 20) * power * 0.3
			)
		end
	end
	return total
end

function CameraShake.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("shake", function(event: Sequencer.Event, ctx: Sequencer.Context)
		if ctx.seeking then
			return
		end
		local amp: number = event.amp or 0
		local seconds: number = event.seconds or 0
		if amp <= 0 or seconds <= 0 then
			return
		end
		local shakes: { Shake }? = ctx._shakes
		if not shakes then
			-- La función por cuadro se añade una sola vez por escena (ctx es de cada escena).
			local list: { Shake } = {}
			shakes = list
			ctx._shakes = list
			local hooks = ctx.frameHooks or {}
			ctx.frameHooks = hooks
			table.insert(hooks, function(t: number)
				local camera = Workspace.CurrentCamera
				if not camera or camera.CameraType ~= Enum.CameraType.Scriptable then
					return
				end
				for i = #list, 1, -1 do
					local shake = list[i]
					if t >= shake.t0 + shake.seconds or t < shake.t0 then
						table.remove(list, i)
					end
				end
				if #list > 0 then
					camera.CFrame *= CFrame.new(offsetAt(list, t))
				end
			end)
		end
		table.insert(
			shakes :: { Shake },
			{ t0 = event.t, amp = amp, seconds = seconds, hz = event.hz or DEFAULT_HZ, seed = math.random() * 100 }
		)
	end)
end

return CameraShake
