return {
	{
		-- Indent guides. Base options for snacks live in plugins/ai.lua; lazy merges them.
		"folke/snacks.nvim",
		init = function()
			local function set_hl()
				vim.api.nvim_set_hl(0, "SnacksIndent", { fg = "#444444" })
				vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = "#575757" })
			end
			set_hl()
			-- Keep these colors when the colorscheme changes
			vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
		end,
		opts = {
			indent = {
				animate = { enabled = false },
				scope = {
					-- Like Zed: pick the scope from indentation and the cursor's line, not
					-- its column, so the guide under an `if` lights up from the `if` line.
					treesitter = { enabled = false },
					cursor = false,
				},
			},
		},
		config = function(_, opts)
			require("snacks").setup(opts)

			-- Snacks treats a blank line as part of the next line, so a blank line above
			-- a block lights that block up one row early, with no option to change it.
			-- Instead, give a blank line the deeper indent of its two neighbours.
			-- Only the indent guides' listener is affected (treesitter disabled above).
			local scope = require("snacks.scope")
			local get = scope.get
			scope.get = function(cb, get_opts)
				local o = get_opts or {}
				local is_guide_scope = o.pos and o.buf and o.edge ~= false
					and o.treesitter and o.treesitter.enabled == false
				if not is_guide_scope then
					return get(cb, get_opts)
				end
				if vim.api.nvim_get_current_buf() ~= o.buf then
					return vim.api.nvim_buf_call(o.buf, function() scope.get(cb, get_opts) end)
				end

				local line = o.pos[1]
				if vim.fn.prevnonblank(line) == line then
					return get(cb, get_opts)
				end
				local prev, next = vim.fn.prevnonblank(line), vim.fn.nextnonblank(line)
				if prev == 0 and next == 0 then
					return get(cb, get_opts)
				end
				local level = math.max(vim.fn.indent(prev), vim.fn.indent(next))

				-- Snacks may pick a nested block here, so walk out to the blank line's level
				get(function(s)
					while s and s.indent > level do
						s = s:parent()
					end
					cb(s and s:with_edge())
				end, vim.tbl_extend("force", o, { edge = false, min_size = 1, max_size = 1 }))
			end
		end,
	},
	-- Detect each file's indent width, so guides and `==` follow the file's own style
	{ "tpope/vim-sleuth", lazy = false },
	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async",
		-- `keys` alone would lazy-load this, but its config sets the fold options
		lazy = false,
		keys = {
			{ "zR", function() require("ufo").openAllFolds() end },
			{ "zM", function() require("ufo").closeAllFolds() end },
		},
		config = function()
			-- Enable the margin column for folds
			vim.o.foldcolumn = '1'
			vim.o.foldlevel = 99
			vim.o.foldlevelstart = 99
			vim.o.foldenable = true

			-- Use Nerd Font chevrons for fold icons, and turn off the vertical separator line
			vim.o.fillchars = "eob: ,fold: ,foldopen:\u{EAB4},foldsep: ,foldclose:\u{EAB6},foldinner: "

			-- Compact status column spacing
			-- vim.o.statuscolumn = "%= %l %s%C"

			require("ufo").setup({
				open_fold_hl_timeout = 200,
				provider_selector = function(bufnr, filetype, buftype)
					return { "treesitter", "indent" }
				end,
			})
		end,
	},
	{
		'luukvbaal/statuscol.nvim',
		dependencies = { "lewis6991/gitsigns.nvim" },
		lazy = false,
		config = function()
			local builtin = require('statuscol.builtin')

			-- Show the open-fold icon only on the cursor line. Closed folds always keep theirs.
			local function foldfunc(args)
				-- No fold column in this window (statuscol leaves args.fold.close unset)
				if args.fold.width == 0 then
					return ""
				end
				local text = builtin.foldfunc(args)
				if args.relnum == 0 or text:find(args.fold.close, 1, true) then
					return text
				end
				return (" "):rep(args.fold.width)
			end

			require('statuscol').setup({
				setopt = true,
				relculright = true,
				segments = {
					{
						sign = {
							namespace = { "gitsigns" }, -- Matches the gitsigns namespace
							maxwidth = 1,
							colwidth = 1,
							auto = false,                -- Column disappears if no git changes exist
						},
						click = "v:lua.ScSa",         -- Links native click handlers to preview/stage hunks
					},
					{
						text = { builtin.lnumfunc },
						click = "v:lua.ScSa",         -- Links native click handlers to preview/stage hunks
					},
					{ text = { " " } },
					-- { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
					{ text = { " " } },
					{ text = { foldfunc }, click = "v:lua.ScFa" },
					{ sign = { name = { ".*" }, maxwidth = 2, colwidth = 1, auto = true }, click = "v:lua.ScSa" },
					{ text = { " " } }, -- Gap between the gutter and the code
				}
			})
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { 'nvim-tree/nvim-web-devicons' },
		opts = {

		}
	},
}
