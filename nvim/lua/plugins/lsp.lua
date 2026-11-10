return {
	{
		"mason-org/mason.nvim",
		opts = {
			registries = {
				"github:mason-org/mason-registry",
				"github:Crashdummyy/mason-registry",
			},
		}
	},
	{ "neovim/nvim-lspconfig" },
	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
		-- other plugin files can add to this list with their own opts.ensure_installed
		opts_extend = { "ensure_installed" },
		opts = {
			-- Servers to install with Mason and enable. Settings go in after/lsp/<name>.lua.
			ensure_installed = { "html", "cssls", "jdtls", "clangd", "lua_ls", "ts_ls" },
		},
		config = function(_, opts)
			require("mason-lspconfig").setup(opts)
			vim.lsp.enable(opts.ensure_installed)
		end,
	},
	{
		-- enables its own "roslyn" server, settings are in after/lsp/roslyn.lua
		"seblyng/roslyn.nvim",
		---@module 'roslyn.config'
		---@type RoslynNvimConfig
		opts = {

		},
	},
}
