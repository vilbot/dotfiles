local platform = require("config.platform")

local git_bash = "C:/Program Files/Git/usr/bin/bash.exe"

return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			-- a list, because snacks splits a shell string on spaces
			terminal = platform.is_win and vim.fn.executable(git_bash) == 1
				and { shell = { git_bash } }
				or nil,
		},
	},
	{
		"coder/claudecode.nvim",
		dependencies = { "folke/snacks.nvim" },
		opts = {
			terminal = {
				provider = "native",
			},
		},
	},
}
