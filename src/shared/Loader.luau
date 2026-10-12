--!strict
-- Carga todos los módulos de una carpeta (Services en el servidor, Controllers en el cliente)
-- en dos pasos:
--   1. Init(): preparar su propio estado. No debe esperar ni usar otros módulos.
--   2. Start(): empezar a funcionar. Aquí ya se puede usar a los demás módulos.

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local Loader = {}

function Loader.load(container: Instance): { [string]: Module }
	local modules: { [string]: Module } = {}
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			modules[child.Name] = (require :: any)(child)
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
