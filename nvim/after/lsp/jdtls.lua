local platform = require("config.platform")

-- jdtls needs JDK 21 or newer, and a JDK newer than the jdtls release crashes it (JDK 27
-- needs jdtls 1.63: "Unsupported class file major version 71"). So on Windows take the
-- oldest supported install, not the newest.
local function java()
	if platform.is_win then
		local jdks = vim.fn.glob("C:/Program Files/Java/jdk-2[1-9]*/bin/java.exe", true, true)
		table.sort(jdks)
		if #jdks > 0 then return jdks[1] end
	end
	local home = vim.env.JAVA_HOME
	if home and home ~= "" then
		return vim.fs.joinpath(home, "bin", platform.is_win and "java.exe" or "java")
	end
	return "java"
end

-- Mason ships one launcher config per OS and architecture.
local function config_dir()
	if platform.is_win then return "config_win" end
	local name = platform.is_mac and "config_mac" or "config_linux"
	return platform.is_arm and name .. "_arm" or name
end

local data = vim.fn.stdpath('data')
local package = vim.fs.joinpath(data, 'mason', 'packages', 'jdtls')

return {
	cmd = {
		java(),
		'-jar',
		vim.fn.glob(vim.fs.joinpath(package, 'plugins', 'org.eclipse.equinox.launcher_*.jar'), true, true)[1] or '',
		'-configuration',
		vim.fs.joinpath(package, config_dir()),
		'-data',
		vim.fs.joinpath(data, 'jdtls-workspace'),
	}
}
