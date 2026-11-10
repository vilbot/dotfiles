-- The active colorscheme is colors/custom.lua, set in init.lua.
-- These stay installed so they can be switched to with :colorscheme.
return {
	{
		"blazkowolf/gruber-darker.nvim",
		priority = 1000,
		lazy = false,
		init = function()
			vim.api.nvim_create_autocmd("ColorScheme", {
				pattern = "gruber-darker",
				callback = function()
					-- local highlight_color = '#abbce5'
					local highlight_color = '#ffffff'
					vim.api.nvim_set_hl(0, 'GruberDarkerDarkNiagara', { fg = highlight_color })
					vim.api.nvim_set_hl(0, 'MatchParen', { link = 'Visual' })
					vim.api.nvim_set_hl(0, 'NormalFloat', {fg = '#dadada', bg = '#181818'})
					vim.api.nvim_set_hl(0, 'FloatBorder', {fg = '#dadada', bg = '#181818'})
					vim.api.nvim_set_hl(0, 'BlinkCmpGhostText', {fg = '#787878', bg = '#282828'})
				end,
			})
		end,
		opts = {
			bold = false,
			italic = {
				comments = false,
				strings = false,
				keywords = false,
				operators = false
			},
		}
	},
	{
		"https://github.com/luisiacc/handmade-hero-theme"
	},
	{
		"ellisonleao/gruvbox.nvim",
		config = true,
		priority = 1000,
		lazy = false,

		opts = {
			bold = false,
			italic = {
				comments = false,
				strings = false,
				keywords = false,
				operators = false
			},
		}
	},
	{
		"rebelot/kanagawa.nvim",
		opts = {
			commentStyle = { italic = false },
			keywordStyle = { bold = false},
			statementStyle = { bold = false },
		}
	},
	{ "Mofiqul/vscode.nvim" },
	{
		"shaunsingh/nord.nvim",
		init = function()
			vim.g.nord_italic = false
			vim.g.nord_bold = false
		end,
	},
	{
		"AlexvZyl/nordic.nvim",
		init = function()
			vim.api.nvim_create_autocmd("ColorScheme", {
				pattern = "nordic",
				callback = function()
					vim.api.nvim_set_hl(0, 'Visual', { bg = '#60728a', fg = '#242933' })
				end,
			})
		end,
	},
	{ "jacoborus/tender.vim" },
	{ "savq/melange-nvim" },
	{ "tanvirtin/monokai.nvim" },
	{
		'datsfilipe/vesper.nvim',
		priority = 1000,
		opts = {
			transparent = true, -- Boolean: Sets the background to transparent
			italics = {
				comments = false, -- Boolean: Italicizes comments
				keywords = false, -- Boolean: Italicizes keywords
				functions = false, -- Boolean: Italicizes functions
				strings = false, -- Boolean: Italicizes strings
				variables = false, -- Boolean: Italicizes variables
			},
			bold = false
		}
	},
	{
		"srcery-colors/srcery-vim",
		lazy = false,
		priority = 1000,
	},
}
