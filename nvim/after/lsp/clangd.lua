return {
	filetypes = { 'cpp' },
	cmd = {
		"clangd",
		"--header-insertion=never",
	},
	handlers = {
		["textDocument/publishDiagnostics"] = function() end,
	}
}
