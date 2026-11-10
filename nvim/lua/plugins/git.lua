return {
	{
		"NeogitOrg/neogit",
		lazy = true,
		dependencies = {
			-- Only one of these is needed.
			"sindrets/diffview.nvim",        -- optional
			"esmuellert/codediff.nvim",      -- optional

			-- For a custom log pager
			"m00qek/baleia.nvim",            -- optional

			-- Only one of these is needed.
			"nvim-telescope/telescope.nvim", -- optional
			"ibhagwan/fzf-lua",              -- optional
			"nvim-mini/mini.pick",           -- optional
			"folke/snacks.nvim",             -- optional
		},
		cmd = "Neogit",
		keys = {
			{ "<leader>gg", "<cmd>Neogit<cr>", desc = "Show Neogit UI" }
		}
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gitsigns").setup({
				-- Define the conventional text icons for the sidebar
				signs = {
					add          = { text = "┃" }, -- Green bar
					change       = { text = "┃" }, -- Yellow bar
					delete       = { text = "_" }, -- Red floor bar
					topdelete    = { text = "‾" }, -- Red ceiling bar
					changedelete = { text = "~" }, -- Yellow/Red mixed bar
					untracked    = { text = "┆" },
				},
				signs_staged = {
					add          = { text = "┃" }, -- Green bar
					change       = { text = "┃" }, -- Yellow bar
					delete       = { text = "_" }, -- Red floor bar
					topdelete    = { text = "‾" }, -- Red ceiling bar
					changedelete = { text = "~" }, -- Yellow/Red mixed bar
					untracked    = { text = "┆" },
				},
				-- Map them to the conventional colors (if your theme doesn't do it automatically)
				signcolumn = true,

				on_attach = function(bufnr)
					vim.schedule(function()
						if vim.api.nvim_buf_is_valid(bufnr) then
							vim.cmd("redrawstatus")
						end
					end)
				end
			})
		end,
	},
}
