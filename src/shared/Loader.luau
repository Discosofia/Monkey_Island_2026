--!strict
-- Carga todos los módulos de una carpeta (Services en el servidor, Controllers en el cliente), o de
-- varias a la vez (los Services del place y los del combate compartido), en dos pasos:
--   1. Init(): preparar su propio estado. No debe esperar ni usar otros módulos.
--   2. Start(): empezar a funcionar. Aquí ya se puede usar a los demás módulos.
-- "skip": nombres de módulos que este place no carga (el Laboratorio no tiene habilidades, guardia ni
-- cadena de disparos: sin RoleController, GuardController…).

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local Loader = {}

function Loader.load(containers: Instance | { Instance }, skip: { [string]: boolean }?): { [string]: Module }
	local list: { Instance } = if typeof(containers) == "Instance" then { containers } else containers
	local modules: { [string]: Module } = {}
	for _, container in list do
		for _, child in container:GetChildren() do
			if child:IsA("ModuleScript") and not (skip and skip[child.Name]) then
				assert(modules[child.Name] == nil, `Loader: hay dos módulos llamados "{child.Name}"`)
				modules[child.Name] = (require :: any)(child)
			end
		end
	end

	for _, module in modules do
		local init = module.Init
		if init then
			init(module)
		end
	end

	for _, module in modules do
		local start = module.Start
		if start then
			-- Cada Start corre por separado: si uno falla, los demás siguen.
			task.spawn(start, module)
		end
	end

	return modules
end

return Loader
