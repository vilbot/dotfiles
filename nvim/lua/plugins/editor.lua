return {
	{ "echasnovski/mini.surround", config = function () require("mini.surround").setup({}) end },
	{
		"mrjones2014/smart-splits.nvim",
		-- `keys` alone would lazy-load this, but the terminal multiplexer integration needs it at startup
		lazy = false,
		keys = {
			{ "<A-h>", function() require("smart-splits").resize_left() end },
			{ "<A-j>", function() require("smart-splits").resize_down() end },
			{ "<A-k>", function() require("smart-splits").resize_up() end },
			{ "<A-l>", function() require("smart-splits").resize_right() end },
		},
		config = function () require("smart-splits").setup({}) end,
	},
}
