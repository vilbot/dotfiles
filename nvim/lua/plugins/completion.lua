return {
	{
		'saghen/blink.cmp',
		version = 'v0.*',
		dependencies = { 'rafamadriz/friendly-snippets' },

		opts = function()
			return {
				fuzzy = {
					implementation = 'lua',
					sorts = (function()
						local k = require('blink.cmp.types').CompletionItemKind
						-- lower number = higher in the list
						local modified_priority = {
							[k.Field] = 1,
							[k.Property] = 1,
							[k.Method] = 2,
							[k.Variable] = 3,
							[k.Function] = 3,
							[k.EnumMember] = 4,
							[k.Constant] = 4,
							[k.Keyword] = 90,
							[k.Snippet] = 95,
							[k.Text] = 100,
						}
						local function modified_kind(kind)
							return modified_priority[kind] or 50
						end

						-- JS/TS servers offer every browser and library global, so sorting by kind
						-- would bury keywords: here the best text match goes first instead.
						local best_match_filetypes = {
							javascript = true,
							javascriptreact = true,
							typescript = true,
							typescriptreact = true,
						}
						-- Cached because sorting runs thousands of comparisons per keystroke
						local best_match_first = false
						vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
							callback = function()
								-- Skip special buffers, such as blink's own menu and docs windows
								if vim.bo.buftype == "" then
									best_match_first = best_match_filetypes[vim.bo.filetype] or false
								end
							end,
						})

						return {
							function(a, b)
								if not best_match_first and a.exact ~= b.exact then
									return a.exact
								end
							end,
							function(a, b)
								if best_match_first then
									local low1 = a.kind == k.Snippet or a.kind == k.Text
									local low2 = b.kind == k.Snippet or b.kind == k.Text
									if low1 ~= low2 then
										return low2
									end
									return nil
								end
								-- members/fields before snippets, keywords, text
								local kind1 = modified_kind(a.kind)
								local kind2 = modified_kind(b.kind)
								if kind1 ~= kind2 then
									return kind1 < kind2
								end
							end,
							'score',
							'sort_text',
						}
					end)(),
				},
				sources = {
					-- after a member-access operator, or mid-statement, only the LSP
					-- has anything meaningful to say -- snippets/buffer are noise there
					default = function()
						local col = vim.api.nvim_win_get_cursor(0)[2]
						local before = vim.api.nvim_get_current_line():sub(1, col)

						if before:match('[%w_%)%]"\']%s*%.%s*[%w_]*$')
							or before:match('->%s*[%w_]*$')
							or before:match('::%s*[%w_]*$')
							or before:match('[%w_]:%s*[%w_]*$')
						then
							return { 'lsp' }
						end

						-- not at the start of a statement -> no snippet templates
						if before:match('%S%s+[%w_]*$') then
							return { 'lsp', 'path', 'buffer' }
						end

						return { 'lsp', 'path', 'snippets', 'buffer' }
					end,
				},
				appearance = {
					-- 'mono' () for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
					-- Adjusts spacing to ensure icons are aligned
					nerd_font_variant = 'mono',
					use_nvim_cmp_as_default = true,
				},
				-- *blink-keymaps*
				keymap = {
					preset = 'default',
					['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback'},
					['<CR>']  = { 'select_and_accept', 'fallback'},
					['<C-n>'] = { 'show', 'select_next', 'fallback' },
					['<C-e>'] = { 'hide', 'show', 'fallback' },
				},
				completion = {
					list = {
						selection = {
							preselect = true, -- function() return not require('blink.cmp').snippet_active({ direction = 1 }) end,
							auto_insert = false,
						},
					},
					menu = {
						auto_show = true, -- function() return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) end,
						draw = {
							padding = { 0, 1 },
							components = {
								kind_icon = { text = function(ctx) return ' ' .. ctx.kind_icon .. ctx.icon_gap .. ' ' end }
							},
						},
						border = "rounded",
						winhighlight = 'Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
					},
					documentation = {
						auto_show = true,
						auto_show_delay_ms = 1000,
						window = {
							border = "rounded",
							winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc',
						},
					},
					ghost_text = {
						enabled = false --function() return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) end,
					},
				},
				signature = {
					enabled = false,
					trigger = {
						enabled = true,
						show_on_insert = true,
					},
				},
			}
		end,
	},
	{
		"kawre/neotab.nvim",
		event = "InsertEnter",
		opts = {
			-- configuration goes here
		},
	},
	{ "windwp/nvim-autopairs", config = function () require("nvim-autopairs").setup({}) end },
	-- Closes tags as you type them, and renames the closing tag along with the opening one
	{ "windwp/nvim-ts-autotag", lazy = false, opts = {} },
}
