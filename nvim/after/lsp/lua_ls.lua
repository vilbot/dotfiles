return {
	settings = {
		Lua = {
			runtime = { version = 'LuaJIT' },
			workspace = {
				checkThirdParty = false,
				library = vim.api.nvim_get_runtime_file('', true),
			},
			diagnostics = {
				globals = { 'vim' },
				disable = { 'redundant-parameter', 'trailing-space' }
			}
		},
	},
}
