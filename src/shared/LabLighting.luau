--!strict
-- Iluminación de los mapas del Laboratorio en ruinas (Fase 13 y Fase 25 G12): los presets de Central,
-- Alcantarillas y Azotea y la función que los aplica. Vive en Shared para que la use el servidor al montar
-- el mapa (World/LabParts, World/Maps/*) y el cliente en las cinemáticas (Cinematics/LabActor, evento
-- labLight). No requiere nada del servidor.
--
-- apply pone todas las propiedades (la iluminación es global, así que cada mapa tiene que dejar las suyas) y
-- apaga los efectos que el preset no trae. Sin bloom, desenfoque o rayos de sol, esos efectos se apagan.

local Lighting = game:GetService("Lighting")

export type LightingPreset = {
	clockTime: number,
	latitude: number,
	brightness: number,
	exposure: number?,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmosphere: {
		density: number,
		offset: number,
		color: Color3,
		decay: Color3,
		glare: number,
		haze: number,
	},
	colorCorrection: { brightness: number?, contrast: number, saturation: number, tint: Color3 },
	bloom: { intensity: number, size: number, threshold: number }?,
	depthOfField: { farIntensity: number, focusDistance: number, inFocusRadius: number, nearIntensity: number }?,
	sunRays: { intensity: number, spread: number }?,
}

local LabLighting = {}

local presets: { [string]: LightingPreset } = {
	-- Mediodía nublado en la ciudad en ruinas: luz fría, sombras suaves y bruma azulada entre las torres.
	Central = {
		clockTime = 13.5,
		latitude = 10,
		brightness = 2,
		ambient = Color3.fromRGB(84, 90, 100),
		outdoorAmbient = Color3.fromRGB(128, 136, 148),
		atmosphere = {
			density = 0.36,
			offset = 0.1,
			color = Color3.fromRGB(176, 190, 204),
			decay = Color3.fromRGB(96, 110, 124),
			glare = 0,
			haze = 2,
		},
		colorCorrection = { contrast = 0.08, saturation = -0.06, tint = Color3.fromRGB(236, 242, 250) },
	},
	-- Sótano cerrado: poca luz de ambiente (los focos enjaulados hacen el resto), sin bruma verde y con la
	-- corrección de color un punto más clara para que se vea en el teléfono. Sin verdes en la corrección.
	Alcantarillas = {
		clockTime = 14,
		latitude = 10,
		brightness = 1,
		ambient = Color3.fromRGB(70, 76, 86),
		outdoorAmbient = Color3.fromRGB(40, 44, 50),
		atmosphere = {
			density = 0.45,
			offset = 0,
			color = Color3.fromRGB(108, 116, 130),
			decay = Color3.fromRGB(64, 70, 82),
			glare = 0,
			haze = 1,
		},
		colorCorrection = {
			brightness = 0.03,
			contrast = 0.06,
			saturation = -0.05,
			tint = Color3.fromRGB(238, 242, 250),
		},
	},
	-- Última hora de la tarde sobre la ciudad en ruinas: luz cálida, sombras largas y poca bruma, para ver a
	-- 120 studs. Sin verdes en la corrección de color.
	Azotea = {
		clockTime = 16,
		latitude = 10,
		brightness = 2.2,
		ambient = Color3.fromRGB(92, 98, 112),
		outdoorAmbient = Color3.fromRGB(136, 142, 158),
		atmosphere = {
			density = 0.28,
			offset = 0.1,
			color = Color3.fromRGB(190, 198, 216),
			decay = Color3.fromRGB(120, 124, 142),
			glare = 0,
			haze = 1,
		},
		colorCorrection = { contrast = 0.08, saturation = -0.04, tint = Color3.fromRGB(250, 244, 236) },
		sunRays = { intensity = 0.05, spread = 0.6 },
	},
}

LabLighting.presets = presets

-- Pone la iluminación de un preset (todas las propiedades) y apaga los efectos que no trae.
function LabLighting.apply(preset: LightingPreset)
	Lighting.ClockTime = preset.clockTime
	Lighting.GeographicLatitude = preset.latitude
	Lighting.Brightness = preset.brightness
	Lighting.ExposureCompensation = preset.exposure or 0
	Lighting.Ambient = preset.ambient
	Lighting.OutdoorAmbient = preset.outdoorAmbient

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = preset.atmosphere.density
	atmosphere.Offset = preset.atmosphere.offset
	atmosphere.Color = preset.atmosphere.color
	atmosphere.Decay = preset.atmosphere.decay
	atmosphere.Glare = preset.atmosphere.glare
	atmosphere.Haze = preset.atmosphere.haze
	atmosphere.Parent = Lighting

	local grade = (Lighting:FindFirstChild("ColorLaboratorio") :: ColorCorrectionEffect?)
		or Instance.new("ColorCorrectionEffect")
	grade.Name = "ColorLaboratorio"
	grade.Parent = Lighting
	grade.Brightness = preset.colorCorrection.brightness or 0
	grade.Contrast = preset.colorCorrection.contrast
	grade.Saturation = preset.colorCorrection.saturation
	grade.TintColor = preset.colorCorrection.tint

	local bloom = Lighting:FindFirstChild("BloomLaboratorio") :: BloomEffect?
	if preset.bloom then
		bloom = bloom or Instance.new("BloomEffect")
		local effect = bloom :: BloomEffect
		effect.Name = "BloomLaboratorio"
		effect.Intensity = preset.bloom.intensity
		effect.Size = preset.bloom.size
		effect.Threshold = preset.bloom.threshold
		effect.Enabled = true
		effect.Parent = Lighting
	elseif bloom then
		bloom.Enabled = false
	end

	local depth = Lighting:FindFirstChild("DesenfoqueLaboratorio") :: DepthOfFieldEffect?
	if preset.depthOfField then
		depth = depth or Instance.new("DepthOfFieldEffect")
		local effect = depth :: DepthOfFieldEffect
		effect.Name = "DesenfoqueLaboratorio"
		effect.FarIntensity = preset.depthOfField.farIntensity
		effect.FocusDistance = preset.depthOfField.focusDistance
		effect.InFocusRadius = preset.depthOfField.inFocusRadius
		effect.NearIntensity = preset.depthOfField.nearIntensity
		effect.Enabled = true
		effect.Parent = Lighting
	elseif depth then
		depth.Enabled = false
	end

	local rays = Lighting:FindFirstChild("RayosLaboratorio") :: SunRaysEffect?
	if preset.sunRays then
		rays = rays or Instance.new("SunRaysEffect")
		local effect = rays :: SunRaysEffect
		effect.Name = "RayosLaboratorio"
		effect.Intensity = preset.sunRays.intensity
		effect.Spread = preset.sunRays.spread
		effect.Enabled = true
		effect.Parent = Lighting
	elseif rays then
		rays.Enabled = false
	end
end

return LabLighting
