local platform = require("config.platform")

local git_bash = "C:/Program Files/Git/usr/bin/bash.exe"
local none_agent_dir = vim.fn.expand("~/.local/share/none/agent")

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
	{
		dir = none_agent_dir,
		name = "none-agent",
		main = "none.agent",
		lazy = false,
		cond = vim.fn.isdirectory(none_agent_dir) == 1,
		opts = {
			reload_ms = 500,
			keymaps = false, -- configured in lua/config/keymaps.lua
		},
	},
}
