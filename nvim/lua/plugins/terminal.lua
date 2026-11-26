return {
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		lazy = false,
		opts = {
			direction = "horizontal",
			size = 15,
			shade_terminals = false,
			persist_size = true,
			persist_mode = true,
			start_in_insert = true,
		},
	},
	{
		"stevearc/overseer.nvim",
		cmd = {
			"OverseerToggle",
			"OverseerOpen",
			"OverseerClose",
			"OverseerRun",
			"OverseerShell",
			"OverseerTaskAction",
		},
		init = function()
			-- Neovim user commands must start with an uppercase letter, so use
			-- command-line abbreviations to support lowercase :runtask and :tasks.
			vim.cmd([[
				cnoreabbrev <expr> runtask getcmdtype() == ':' && getcmdline() ==# 'runtask' ? 'OverseerRun' : 'runtask'
				cnoreabbrev <expr> tasks   getcmdtype() == ':' && getcmdline() ==# 'tasks'   ? 'OverseerToggle' : 'tasks'
			]])
		end,
		opts = {
			task_list = {
				-- "bottom" automatically opens a second output pane on the right;
				-- "right" (or "left") shows only the task list.
				direction = "right",
				keymaps = {
					["o"] = { "keymap.open", opts = { dir = "float" }, desc = "Open task output in float" },
				},
			},
			task_win = {
				padding = 2,
				border = "rounded",
			},
			form = { border = "rounded" },
			confirm = { border = "rounded" },
			task_launcher = { border = "rounded" },
			task_editor = { border = "rounded" },
		},
	},
}
