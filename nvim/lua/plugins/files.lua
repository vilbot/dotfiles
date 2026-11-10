return {
	{
		"stevearc/oil.nvim",
		-- `keys` alone would lazy-load this, but it has to be there to take over directory buffers
		lazy = false,
		keys = {
			{ '<leader>w', '<CMD>Oil<CR>' },
		},
		opts = {
			skip_confirm_for_simple_edits = true,
			view_options = {
				show_hidden = true
			},
		}
	},
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false,
		keys = {
			{ '<leader>q', '<cmd>NvimTreeOpen<cr>' },
		},
		config = function()
			require("nvim-tree").setup()
		end
	},
}
